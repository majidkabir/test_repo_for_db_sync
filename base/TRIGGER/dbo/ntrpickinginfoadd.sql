SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrPickingInfoAdd                                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Trigger for PickingInfo table                              */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: When records updated                                      */
/*                                                                      */
/* Revision: 1.3                                                        */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 14-Nov-2005  Vicky     1.0   SOS41737 - Add in Configkey "ScanInLog" */
/*                              to insert record to Transmitlog3 when   */
/*                              scanning in is carried out              */
/* 10-Nov-2006  June      1.0   SOS#58619 - Include TrafficCop check    */
/* 13-Nov-2007  YokeBeen  1.0   SOS#84285 - Consolidated Pick Ticket of */
/*                              USA. PickHeader.Zone -> Conso = 'C'     */
/*                                                   -> Discrete = 'D'  */
/*                              - (YokeBeen01)                          */
/* 15-Sep-2007  Shong     1.0   - SOS#84285 Discrete Pickslip Type = 'D'*/
/* 17-Jul-2008  YokeBeen  1.1   SOS#111333 - New trigger point for IDSTW*/
/*                              LOR for the Pick Confirmation Outbound. */
/*                              Records to be triggered when            */
/*                              ORDERS.Status = "3".                    */
/*                              Tablename = "PICKINPROG". - (YokeBeen02)*/
/* 28-Oct-2009  Shong     1.2   Insert into PickDet_Log if StorerConfig */
/*                              ScanInPickLog.                          */
/* 02-Feb-2010  MCTang    1.2   SOS#159235 - Assign Orders.Type to Keys */
/*                              for 'ScanInLog' IF 'WitronOL' is OFF    */
/*                              (MC01)                                  */
/* 25-Mar-2014  Leong     1.3   SOS#305979 - Remove TrafficCop when     */
/*                                           update Orders.             */
/* 25-Sep-2017  TLTING    1.4   SET ANSI                                */
/* 11-03-2020   MCTang    1.5   Add scanin2log (MC03)                   */
/* 11-May-2020  MCTang    1.6   Add scanin3log (MC04)                   */
/* 26-Mar-2021  NJOW01    1.7   WMS-16663 add transmitlog2 interface    */
/* 09-Jul-2021  NJOW02    1.8   Fix null value comparison issue         */
/* 24-Jan-2022  MCTang    1.9   Add scanin4log & scanin5log (MC05)      */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrPickingInfoAdd]
ON  [dbo].[PickingInfo]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE   @b_Success              INT       -- Populated by calls to stored procedures - was the proc successful?
   ,         @n_err                  INT       -- Error number returned by stored procedure OR this trigger
   ,         @n_err2                 INT       -- For Additional Error Detection
   ,         @c_errmsg               NVARCHAR(250) -- Error message returned by stored procedure OR this trigger
   ,         @n_Continue             INT
   ,         @n_starttcnt            INT       -- Holds the current transaction count
   ,         @c_preprocess           NVARCHAR(250) -- preprocess
   ,         @c_pstprocess           NVARCHAR(250) -- post process
   ,         @n_cnt                  INT
   ,         @c_PickerID             NVARCHAR(18)
   ,         @c_authority_scaninlog  NVARCHAR(1)   -- SOS41737
   ,         @c_authority_scanin2log NVARCHAR(1)   -- MC03
   ,         @c_authority_scanin3log NVARCHAR(1)   -- MC04
   ,         @c_authority_scanin4log NVARCHAR(1)   -- MC05
   ,         @c_authority_scanin5log NVARCHAR(1)   -- MC05
   ,         @c_StorerKey            NVARCHAR(15)  -- SOS41737
   ,         @c_cfgvalue             NVARCHAR(1)   -- SOS41737
   ,         @c_authority_pickinprog NVARCHAR(1)   -- (YokeBeen02)
   ,         @c_OrderType            NVARCHAR(10)  -- MC01

   SELECT @n_Continue=1, @n_starttcnt=@@TRANCOUNT

   -- Start : SOS58619
   IF EXISTS (SELECT 1 FROM INSERTED WHERE Trafficcop = 'U')
   BEGIN
      SELECT @n_Continue = 4
   END
   -- End : SOS58619

   DECLARE @c_ScanInPickLog NVARCHAR(1)

   /* #INCLUDE <TRMBOA1.SQL> */
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM INSERTED WHERE ISNULL(Pickslipno,'') = '')
      BEGIN
          SELECT @n_Continue = 3
          SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12800
          SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                           + ': Error Printing Pickslip. Please Call PFC team. (ntrPickingInfoAdd) ( '
                           + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
      END
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE @c_pickslipno    NVARCHAR(10)
      DECLARE @n_MaxChildSP    INT,
              @n_ChildSP       INT,
              @c_ParentSP      NVARCHAR(10)
      DECLARE @c_PickSlipType  NVARCHAR(10),
              @c_OrderKey      NVARCHAR(10),
              @c_LPOrderKey    NVARCHAR(10),
              @c_LoadKey       NVARCHAR(10),
              @c_Facility      NVARCHAR(5),
              @c_WSSIOption1   NVARCHAR(50),
              @c_WSScanInLog   NVARCHAR(30)

      DECLARE @c_xdOrderKey        NVARCHAR(10),
              @c_OrderLineNumber   NVARCHAR(5),
              @n_rowno             INT,
              @n_rowcount          INT,
              @c_PrevOrderKey      NVARCHAR(5),
              @c_PrevLoadKey       NVARCHAR(10),
              @c_PrevLoadOrderKey  NVARCHAR(10)

      SELECT @c_pickslipno = ''

      DECLARE C_PickInfo_Add_01 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT INSERTED.PickSlipNo
       FROM   INSERTED
       WHERE ISNULL(ScanInDate,'') <> ''
       ORDER BY INSERTED.PickSlipNo

      OPEN C_PickInfo_Add_01

      FETCH NEXT FROM C_PickInfo_Add_01 INTO  @c_pickslipno

      WHILE @@FETCH_STATUS <> -1 AND (@n_Continue = 1 OR @n_Continue = 2)
      BEGIN
         IF ISNULL(RTRIM(@c_pickslipno),'') = ''
            BREAK

         SELECT @c_PickSlipType = ZONE,
                @c_LoadKey      = ExternOrderKey,
                @c_LPOrderKey   = ISNULL(OrderKey, '')
         FROM   PickHeader WITH (NOLOCK)
         WHERE  PickHeaderKey = @c_pickslipno

         IF @c_PickSlipType = '1' AND LEFT(RTRIM(LTrim(@c_pickslipno)), 1) = 'C'
         BEGIN
            SELECT @n_MaxChildSP = COUNT(C.Pickheaderkey), @c_ParentSP = MAX(C.Consigneekey)
            FROM   PICKHEADER C WITH (NOLOCK)
            JOIN   PICKHEADER P WITH (NOLOCK) ON (C.Consigneekey = P.Consigneekey)
            WHERE  P.Pickheaderkey = @c_pickslipno

            SELECT @n_ChildSP = COUNT(PickingInfo.PickSlipNo)
            FROM   PickingInfo WITH (NOLOCK)
            JOIN   PICKHEADER WITH (NOLOCK) ON (PickingInfo.PickslipNo = PICKHEADER.Pickheaderkey)
            WHERE  PICKHEADER.Consigneekey = @c_ParentSP

            IF @n_ChildSP = @n_MaxChildSP
            BEGIN -- Create Parent PickInfo
               SELECT @c_PickerID = PickerID FROM INSERTED

               INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
               VALUES (@c_ParentSP, GetDate(), @c_PickerID , NULL)
            END

            -- Added for SOS#41737
            -- MC01
            /*
            SELECT DISTINCT @c_StorerKey = StorerKey
            FROM ORDERS WITH (NOLOCK)
            WHERE Loadkey = @c_LoadKey
            */

            SELECT TOP 1 @c_StorerKey = StorerKey
                        , @c_OrderType = Type
            FROM  ORDERS WITH (NOLOCK)
            WHERE Loadkey = @c_LoadKey

            Execute dbo.nspGetRight '',
                  @c_StorerKey,   -- Storer
                  '',             -- Sku
                  'ScanInLog',     -- ConfigKey
                  @b_success              OUTPUT,
                  @c_authority_scaninlog  OUTPUT,
                  @n_err                  OUTPUT,
                  @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                + ': Retrieve of Right (ScanInLog) Failed (ntrPickingInfoAdd) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
            End

            IF @c_authority_scaninlog = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
                 FROM StorerConfig WITH (NOLOCK)
                WHERE StorerKey = @c_StorerKey
                  AND Configkey = 'WitronOL'

               -- (MC01) S
               IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
               BEGIN
                  SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
               END
               -- (MC01) E

               EXEC dbo.ispGenTransmitLog3 'ScanInLog', @c_LPOrderKey, @c_cfgvalue , @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
               End
            END

            --(MC03) - S
            Execute dbo.nspGetRight '',
                  @c_StorerKey,   -- Storer
                  '',             -- Sku
                  'ScanIn2Log',     -- ConfigKey
                  @b_success              OUTPUT,
                  @c_authority_scanin2log  OUTPUT,
                  @n_err                  OUTPUT,
                  @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                + ': Retrieve of Right (ScanIn2Log) Failed (ntrPickingInfoAdd) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
            End

            IF @c_authority_scanin2log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
                 FROM StorerConfig WITH (NOLOCK)
                WHERE StorerKey = @c_StorerKey
                  AND Configkey = 'WitronOL'

               -- (MC01) S
               IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
               BEGIN
                  SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
               END
               -- (MC01) E

               EXEC dbo.ispGenTransmitLog3 'ScanIn2Log', @c_LPOrderKey, @c_cfgvalue , @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
               End
            END
            --(MC03) - E

            --(MC04) - S
            SET @c_authority_scanin3log = ''
            Execute dbo.nspGetRight '',
                  @c_StorerKey,   -- Storer
                  '',             -- Sku
                  'ScanIn3Log',     -- ConfigKey
                  @b_success              OUTPUT,
                  @c_authority_scanin3log  OUTPUT,
                  @n_err                  OUTPUT,
                  @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                + ': Retrieve of Right (ScanIn3Log) Failed (ntrPickingInfoAdd) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
            End

            IF @c_authority_scanin3log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
                 FROM StorerConfig WITH (NOLOCK)
                WHERE StorerKey = @c_StorerKey
                  AND Configkey = 'WitronOL'

               IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
               BEGIN
                  SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
               END

               EXEC dbo.ispGenTransmitLog3 'ScanIn3Log', @c_LPOrderKey, @c_cfgvalue , @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
               End
            END
            --(MC04) - E

            --(MC05) - S
            SET @c_authority_scanin4log = ''
            Execute dbo.nspGetRight '',
                  @c_StorerKey,   -- Storer
                  '',             -- Sku
                  'ScanIn4Log',     -- ConfigKey
                  @b_success              OUTPUT,
                  @c_authority_scanin4log  OUTPUT,
                  @n_err                  OUTPUT,
                  @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                + ': Retrieve of Right (ScanIn4Log) Failed (ntrPickingInfoAdd) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
            End

            IF @c_authority_scanin4log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
                 FROM StorerConfig WITH (NOLOCK)
                WHERE StorerKey = @c_StorerKey
                  AND Configkey = 'WitronOL'

               IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
               BEGIN
                  SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
               END

               EXEC dbo.ispGenTransmitLog3 'ScanIn4Log', @c_LPOrderKey, @c_cfgvalue , @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
               End
            END

            SET @c_authority_scanin5log = ''
            Execute dbo.nspGetRight '',
                  @c_StorerKey,   -- Storer
                  '',             -- Sku
                  'Scanin5Log',     -- ConfigKey
                  @b_success              OUTPUT,
                  @c_authority_scanin5log  OUTPUT,
                  @n_err                  OUTPUT,
                  @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                + ': Retrieve of Right (Scanin5Log) Failed (ntrPickingInfoAdd) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
            End

            IF @c_authority_scanin5log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
                 FROM StorerConfig WITH (NOLOCK)
                WHERE StorerKey = @c_StorerKey
                  AND Configkey = 'WitronOL'

               IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
               BEGIN
                  SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
               END

               EXEC dbo.ispGenTransmitLog3 'Scanin5Log', @c_LPOrderKey, @c_cfgvalue , @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
               End
            END
            --(MC05) - E

         END -- PS Type = '1' AND 1st Char of PS# = 'C'

         -- Consolidated PickSlip Zone = '5'
         --IF @c_PickSlipType IN ('5','6','7','9','C') -- (YokeBeen01)
         IF @c_LPOrderKey = '' AND @c_PickSlipType NOT IN ('XD','LB','LP')
         BEGIN
            SELECT @c_OrderKey = ''

            DECLARE C_PKI_LoadPlanDet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LOADPLANDETAIL.OrderKey
            FROM   LOADPLANDETAIL WITH (NOLOCK)
            WHERE  LOADPLANDETAIL.LoadKey = @c_LoadKey
            ORDER BY LOADPLANDETAIL.OrderKey

            OPEN C_PKI_LoadPlanDet

            FETCH NEXT FROM C_PKI_LoadPlanDet INTO @c_OrderKey

            WHILE @@FETCH_STATUS <> -1 AND (@n_Continue = 1 OR @n_Continue = 2)
            BEGIN
               IF ISNULL(RTRIM(@c_OrderKey),'') = ''
                  BREAK

               SELECT @c_StorerKey = StorerKey
                    , @c_OrderType = Type  -- (MC01)
                    , @c_Facility = Facility --NJOW01
                 FROM ORDERS WITH (NOLOCK)
                WHERE OrderKey = @c_OrderKey

               /* Comment this for Performance Purposes
               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET STATUS = '3'
               FROM PICKDETAIL
               WHERE OrderKey = @c_OrderKey
               AND   Status < '3'
               */

               UPDATE ORDERS WITH (ROWLOCK)
               SET Status = '3',
                   EditWho = sUser_sName(),
                   EditDate = GetDate()
               --, TrafficCop = NULL -- SOS#305979
               WHERE OrderKey = @c_OrderKey
               AND   Status < '3'

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

               IF @n_err <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                   + ': Update Failed On Table ORDERS. (ntrPickingInfoAdd) ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
               END

               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  UPDATE ORDERDETAIL WITH (ROWLOCK)
                  SET Status = '3',
                      EditWho = sUser_sName(),
                      EditDate = GetDate(),
                      TrafficCop = NULL
                  WHERE ORDERDETAIL.OrderKey = @c_OrderKey
                  AND   ORDERDETAIL.Status < '3'

                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

                  IF @n_err <> 0
                  BEGIN
                      SELECT @n_Continue = 3
                      SELECT @c_errmsg = CONVERT(CHAR(250), @n_err),
                         @n_err = 12803 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(RTRIM(@n_err), 0))
                             +
                             ': Update Failed On Table ORDERDETAIL. (ntrPickingInfoAdd) ( '
                             + ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '')
                             + ' ) '
                  END
               END

               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  UPDATE LOADPLANDETAIL WITH (ROWLOCK)
                  SET Status = '3',
                      EditWho = sUser_sName(),
                      EditDate = GetDate(),
                      TrafficCop = NULL
                  WHERE LOADPLANDETAIL.OrderKey = @c_OrderKey
                  AND   LOADPLANDETAIL.Status < '5'

                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12804   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                      + ': Update Failed On Table LOADPLANDETAIL. (ntrPickingInfoAdd) ( '
                                      + ' SQLSvr MESSAGE=' + LTrim(RTRIM(@c_errmsg)) + ' ) '
                  END
               END

               -- Added for SOS#41737
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  EXECUTE dbo.nspGetRight '',
                          @c_StorerKey,   -- Storer
                          '',             -- Sku
                          'ScanInLog',    -- ConfigKey
                          @b_success              OUTPUT,
                          @c_authority_scaninlog  OUTPUT,
                          @n_err                  OUTPUT,
                          @c_errmsg               OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12805   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                      + ': Retrieve of Right (ScanInLog) Failed (ntrPickingInfoAdd) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
                  End

                  IF @c_authority_scaninlog = '1'
                  BEGIN
                     SELECT @c_cfgvalue = svalue
                       FROM StorerConfig WITH (NOLOCK)
                      WHERE StorerKey = @c_StorerKey
                        AND Configkey = 'WitronOL'

                     -- (MC01) S
                     IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                     BEGIN
                        SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                     END
                     -- (MC01) E

                     EXEC dbo.ispGenTransmitLog3 'ScanInLog', @c_OrderKey, @c_cfgvalue, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_Continue = 3
                     End
                  END
               END -- (continue =1)
               -- End SOS#41737

               --(MC03) - S
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  EXECUTE dbo.nspGetRight '',
                          @c_StorerKey,   -- Storer
                          '',             -- Sku
                          'ScanIn2Log',    -- ConfigKey
                          @b_success              OUTPUT,
                          @c_authority_scanin2log  OUTPUT,
                          @n_err                  OUTPUT,
                          @c_errmsg               OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12805   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                      + ': Retrieve of Right (ScanIn2Log) Failed (ntrPickingInfoAdd) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
                  End

                  IF @c_authority_scanin2log = '1'
                  BEGIN
                     SELECT @c_cfgvalue = svalue
                       FROM StorerConfig WITH (NOLOCK)
                      WHERE StorerKey = @c_StorerKey
                        AND Configkey = 'WitronOL'

                     -- (MC01) S
                     IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                     BEGIN
                        SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                     END
                     -- (MC01) E

                     EXEC dbo.ispGenTransmitLog3 'ScanIn2Log', @c_OrderKey, @c_cfgvalue, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_Continue = 3
                     End
                  END
               END -- (continue =1)
               --(MC03) - E

               --(MC04) - S
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  SET @c_authority_scanin3log = ''
                  EXECUTE dbo.nspGetRight '',
                          @c_StorerKey,   -- Storer
                          '',             -- Sku
                          'ScanIn3Log',    -- ConfigKey
                          @b_success              OUTPUT,
                          @c_authority_scanin3log  OUTPUT,
                          @n_err                  OUTPUT,
                          @c_errmsg               OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12805   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                      + ': Retrieve of Right (ScanIn3Log) Failed (ntrPickingInfoAdd) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
                  End

                  IF @c_authority_scanin3log = '1'
                  BEGIN
                     SELECT @c_cfgvalue = svalue
                       FROM StorerConfig WITH (NOLOCK)
                      WHERE StorerKey = @c_StorerKey
                        AND Configkey = 'WitronOL'

                     -- (MC01) S
                     IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                     BEGIN
                        SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                     END
                     -- (MC01) E

                     EXEC dbo.ispGenTransmitLog3 'ScanIn3Log', @c_OrderKey, @c_cfgvalue, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_Continue = 3
                     End
                  END
               END -- (continue =1)
               --(MC04) - E

               --(MC05) - S
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  SET @c_authority_scanin4log = ''
                  Execute dbo.nspGetRight '',
                        @c_StorerKey,   -- Storer
                        '',             -- Sku
                        'ScanIn4Log',     -- ConfigKey
                        @b_success              OUTPUT,
                        @c_authority_scanin4log  OUTPUT,
                        @n_err                  OUTPUT,
                        @c_errmsg               OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                      + ': Retrieve of Right (ScanIn4Log) Failed (ntrPickingInfoAdd) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
                  End

                  IF @c_authority_scanin4log = '1'
                  BEGIN
                     SELECT @c_cfgvalue = svalue
                       FROM StorerConfig WITH (NOLOCK)
                      WHERE StorerKey = @c_StorerKey
                        AND Configkey = 'WitronOL'

                     IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                     BEGIN
                        SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                     END

                     EXEC dbo.ispGenTransmitLog3 'ScanIn4Log', @c_OrderKey, @c_cfgvalue , @c_StorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT
                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_Continue = 3
                     End
                  END

                  SET @c_authority_scanin5log = ''
                  Execute dbo.nspGetRight '',
                        @c_StorerKey,   -- Storer
                        '',             -- Sku
                        'Scanin5Log',     -- ConfigKey
                        @b_success              OUTPUT,
                        @c_authority_scanin5log  OUTPUT,
                        @n_err                  OUTPUT,
                        @c_errmsg               OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                      + ': Retrieve of Right (Scanin5Log) Failed (ntrPickingInfoAdd) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
                  End

                  IF @c_authority_scanin5log = '1'
                  BEGIN
                     SELECT @c_cfgvalue = svalue
                       FROM StorerConfig WITH (NOLOCK)
                      WHERE StorerKey = @c_StorerKey
                        AND Configkey = 'WitronOL'

                     IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                     BEGIN
                        SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                     END

                     EXEC dbo.ispGenTransmitLog3 'Scanin5Log', @c_OrderKey, @c_cfgvalue , @c_StorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT
                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_Continue = 3
                     End
                  END
               END
               --(MC05) - E

               -- ScanInPickLog
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  EXEC dbo.isp_InsertPickDet_Log
                       @cOrderKey = @c_OrderKey,
                       @cOrderLineNumber='',
                       @n_err=@n_err OUTPUT,
                       @c_errmsg=@c_errmsg OUTPUT,
                       @cPickSlipNo = @c_pickslipno

               END -- (continue =1)

               -- (YokeBeen01) - Start
               IF @c_PickSlipType IN ('C')
               BEGIN
                  IF EXISTS (SELECT DISTINCT 1
                               FROM ORDERS WITH (NOLOCK)
                               JOIN PICKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PICKHEADER.OrderKey)
                              WHERE ORDERS.LoadKey = @c_LoadKey
                                AND PICKHEADER.OrderKey = @c_OrderKey
                                AND PICKHEADER.Zone = 'D' )
                  BEGIN
                     SELECT @c_PickerID = PickerID FROM INSERTED

                     INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
                     SELECT PickHeaderKey, GETDATE(), @c_PickerID, NULL
                       FROM PICKHEADER WITH (NOLOCK)
                      WHERE OrderKey IN ( SELECT DISTINCT PICKHEADER.OrderKey
                                            FROM ORDERS WITH (NOLOCK)
                                            JOIN PICKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PICKHEADER.OrderKey)
                                           WHERE ORDERS.LoadKey = @c_LoadKey
                                             AND ORDERS.OrderKey = @c_OrderKey   --tlting
                                             AND PICKHEADER.Zone = 'D' )
                  END
               END
               -- (YokeBeen01) - End

               -- (YokeBeen02) Start
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  SELECT @b_success = 0
                  EXECUTE dbo.nspGetRight  NULL,
                          @c_StorerKey,        -- Storer
                          '',                  -- Sku
                          'PICKINPROG',        -- ConfigKey
                          @b_success              OUTPUT,
                          @c_authority_pickinprog OUTPUT,
                          @n_err                  OUTPUT,
                          @c_errmsg               OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12806
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                      + ': Retrieve of Right (PICKINPROG) Failed (ntrPickingInfoAdd)'
                                      + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                  END
                  ELSE
                  BEGIN
                     IF @c_authority_pickinprog = '1'
                     BEGIN
                        EXEC dbo.ispGenTransmitLog3 'PICKINPROG', @c_OrderKey, '', @c_StorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_Continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12807
                           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                            + ': Insert into TransmitLog3 Failed (ntrPickingInfoAdd)'
                                            + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                        END
                     END
                  END -- IF @b_success <> 1
               END
               -- (YokeBeen02) End

               FETCH NEXT FROM C_PKI_LoadPlanDet INTO @c_OrderKey
            END --while loop loadplan detail
            CLOSE C_PKI_LoadPlanDet
            DEALLOCATE C_PKI_LoadPlanDet
         END -- conso pickslip
         ELSE
         BEGIN
            -- Start - Add by June 28.May.03 (SOS11482)
            IF @c_PickSlipType IN ('8', '3', 'D') -- SOS#84285
            BEGIN
               IF EXISTS (SELECT 1 FROM PICKHEADER WITH (NOLOCK) WHERE Consigneekey = @c_pickslipno)
               BEGIN
                  SELECT @c_PickerID = PickerID FROM INSERTED

                  INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
                  SELECT PickHeaderKey, GetDate(), @c_PickerID, NULL
                    FROM PICKHEADER WITH (NOLOCK)
                   WHERE Consigneekey = @c_Pickslipno
               END -- End (SOS11482)
            END

            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
               UPDATE ORDERS WITH (ROWLOCK)
                  SET Status = '3',
                      EditWho = sUser_sName(),
                      EditDate = GetDate()
                  --, TrafficCop = NULL -- SOS#305979
                WHERE OrderKey = @c_LPOrderKey
                  AND Status < '3'

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

               IF @n_err <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12808   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                  +': Update Failed On Table ORDERS. (ntrPickingInfoAdd)' + ' ( '
                                  + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
               END
            END

            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
               UPDATE ORDERDETAIL WITH (ROWLOCK)
                  SET Status = '3',
                      EditWho = sUser_sName(),
                      EditDate = GetDate(),
                      TrafficCop = NULL
                WHERE ORDERDETAIL.OrderKey = @c_LPOrderKey
                  AND ORDERDETAIL.Status < '3'

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

               IF @n_err <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12809   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                  +': Update Failed On Table ORDERDETAIL. (ntrPickingInfoAdd)' + ' ( '
                                  + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
               END
            END

            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
               UPDATE LOADPLANDETAIL WITH (ROWLOCK)
                  SET Status = '3',
                      EditWho = sUser_sName(),
                      EditDate = GetDate(),
                      TrafficCop = NULL
                WHERE LOADPLANDETAIL.OrderKey = @c_LPOrderKey
                  AND LOADPLANDETAIL.Status < '5'

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

               IF @n_err <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                  +': Update Failed On Table LOADPLANDETAIL. (ntrPickingInfoAdd)' + ' ( '
                                  + ' SQLSvr MESSAGE=' + LTrim(RTRIM(@c_errmsg)) + ' ) '
               END
            END

            -- Added for SOS#41737
            SELECT @c_StorerKey = StorerKey
                 , @c_OrderType = Type     --(MC01)
                 , @c_Facility = Facility --NJOW01                 
              FROM ORDERS WITH (NOLOCK)
             WHERE OrderKey = @c_LPOrderKey

            EXECUTE dbo.nspGetRight '',
                  @c_StorerKey,   -- Storer
                  '',             -- Sku
                  'ScanInLog',     -- ConfigKey
                  @b_success              OUTPUT,
                  @c_authority_scaninlog  OUTPUT,
                  @n_err                  OUTPUT,
                  @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12811   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                               +': Retrieve of Right (ScanInLog) Failed (ntrPickingInfoAdd)' + ' ( '
                               + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
            END

            IF @c_authority_scaninlog = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
                 FROM StorerConfig (NOLOCK)
                WHERE StorerKey = @c_StorerKey
                  AND Configkey = 'WitronOL'

               -- (MC01) S
               IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
               BEGIN
                  SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
               END
               -- (MC01) E

               EXEC dbo.ispGenTransmitLog3 'ScanInLog', @c_LPOrderKey, @c_cfgvalue, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
               End
            END
            -- End SOS#41737

            --(MC03) - S
            EXECUTE dbo.nspGetRight '',
                  @c_StorerKey,   -- Storer
                  '',             -- Sku
                  'ScanIn2Log',     -- ConfigKey
                  @b_success              OUTPUT,
                  @c_authority_scanin2log  OUTPUT,
                  @n_err                  OUTPUT,
                  @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12811   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                               +': Retrieve of Right (ScanIn2Log) Failed (ntrPickingInfoAdd)' + ' ( '
                               + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
            END

            IF @c_authority_scanin2log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
                 FROM StorerConfig (NOLOCK)
                WHERE StorerKey = @c_StorerKey
                  AND Configkey = 'WitronOL'

               -- (MC01) S
               IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
               BEGIN
                  SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
               END
               -- (MC01) E

               EXEC dbo.ispGenTransmitLog3 'ScanIn2Log', @c_LPOrderKey, @c_cfgvalue, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
               End
            END
            --(MC03) - E

            --(MC04) - S
            SET @c_authority_scanin3log = ''
            EXECUTE dbo.nspGetRight '',
                  @c_StorerKey,   -- Storer
                  '',             -- Sku
                  'ScanIn3Log',     -- ConfigKey
                  @b_success              OUTPUT,
                  @c_authority_scanin3log OUTPUT,
                  @n_err                  OUTPUT,
                  @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12811   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                               +': Retrieve of Right (ScanIn3Log) Failed (ntrPickingInfoAdd)' + ' ( '
                               + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
            END

            IF @c_authority_scanin3log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
                 FROM StorerConfig (NOLOCK)
                WHERE StorerKey = @c_StorerKey
                  AND Configkey = 'WitronOL'

               -- (MC01) S
               IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
               BEGIN
                  SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
               END
               -- (MC01) E

               EXEC dbo.ispGenTransmitLog3 'ScanIn3Log', @c_LPOrderKey, @c_cfgvalue, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
               End
            END
            --(MC04) - E

            --(MC05) - S
            SET @c_authority_scanin4log = ''
            Execute dbo.nspGetRight '',
                  @c_StorerKey,   -- Storer
                  '',             -- Sku
                  'ScanIn4Log',     -- ConfigKey
                  @b_success              OUTPUT,
                  @c_authority_scanin4log  OUTPUT,
                  @n_err                  OUTPUT,
                  @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                 + ': Retrieve of Right (ScanIn4Log) Failed (ntrPickingInfoAdd) ( '
                                 + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
            End

            IF @c_authority_scanin4log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
                  FROM StorerConfig WITH (NOLOCK)
                  WHERE StorerKey = @c_StorerKey
                  AND Configkey = 'WitronOL'

               IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
               BEGIN
                  SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
               END

               EXEC dbo.ispGenTransmitLog3 'ScanIn4Log', @c_LPOrderKey, @c_cfgvalue , @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
               End
            END

            SET @c_authority_scanin5log = ''
            Execute dbo.nspGetRight '',
                  @c_StorerKey,   -- Storer
                  '',             -- Sku
                  'Scanin5Log',     -- ConfigKey
                  @b_success              OUTPUT,
                  @c_authority_scanin5log  OUTPUT,
                  @n_err                  OUTPUT,
                  @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                 + ': Retrieve of Right (Scanin5Log) Failed (ntrPickingInfoAdd) ( '
                                 + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
            End

            IF @c_authority_scanin5log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
                  FROM StorerConfig WITH (NOLOCK)
                  WHERE StorerKey = @c_StorerKey
                  AND Configkey = 'WitronOL'

               IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
               BEGIN
                  SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
               END

               EXEC dbo.ispGenTransmitLog3 'Scanin5Log', @c_LPOrderKey, @c_cfgvalue , @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
               End
            END
            --(MC05) - E

            -- ScanInPickLog
            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
               EXEC dbo.isp_InsertPickDet_Log
                    @cOrderKey = @c_LPOrderKey,
                    @cOrderLineNumber='',
                    @n_err=@n_err OUTPUT,
                    @c_errmsg=@c_errmsg OUTPUT,
                    @cPickSlipNo = @c_pickslipno

            END -- (continue =1)

            -- (YokeBeen02) Start
            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
               SELECT @b_success = 0
               EXECUTE dbo.nspGetRight  NULL,
                       @c_StorerKey,        -- Storer
                       '',                  -- Sku
                       'PICKINPROG',        -- ConfigKey
                       @b_success              OUTPUT,
                       @c_authority_pickinprog OUTPUT,
                       @n_err                  OUTPUT,
                       @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12812
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                   + ': Retrieve of Right (PICKINPROG) Failed (ntrPickingInfoAdd)'
                                   + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
               END
               ELSE
               BEGIN
                  IF @c_authority_pickinprog = '1'
                  BEGIN
                     EXEC dbo.ispGenTransmitLog3 'PICKINPROG', @c_LPOrderKey, '', @c_StorerKey, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_Continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12813
                        SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                         + ': Insert into TransmitLog3 Failed (ntrPickingInfoAdd)'
                                         + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                     END
                  END
               END -- IF @b_success <> 1
            END
            -- (YokeBeen02) End
         END -- Normal Pick Slip

         -- CrossDock PickSlip Zone = 'XD'
         IF @c_PickSlipType = 'XD' OR
            @c_PickSlipType = 'LB' OR
            @c_PickSlipType = 'LP' -- SOS37177 & SOS37178 by Ong 7JUL2005
         BEGIN
            DECLARE uniqorder_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT OrderKey, ORDERLINENUMBER
            FROM RefKeyLookup WITH (NOLOCK)
            WHERE PICKSLIPNO = @c_Pickslipno
            ORDER BY OrderKey, ORDERLINENUMBER -- Added by Shong on 06-Aug-2004

            OPEN uniqorder_cur
            FETCH NEXT FROM uniqorder_cur INTO @c_xdOrderKey, @c_OrderLineNumber

            WHILE @@FETCH_STATUS = 0
            BEGIN
               SELECT @c_LoadKey = ORDERDETAIL.LoadKey,
                      @c_StorerKey = ORDERDETAIL.StorerKey,
                      @c_Facility = ORDERS.Facility --NJOW01
               FROM ORDERDETAIL WITH (NOLOCK)
               JOIN ORDERS WITH (NOLOCK) ON ORDERDETAIL.Orderkey = ORDERS.Orderkey
               WHERE ORDERDETAIL.OrderKey = @c_xdOrderKey
               AND ORDERDETAIL.OrderLinenumber = @c_OrderLineNumber

               IF ISNULL(@c_PrevOrderKey,'') <> ISNULL(@c_xdOrderKey,'')  --NJOW02
               BEGIN
                  SELECT @c_PrevOrderKey = @c_xdOrderKey

                  UPDATE ORDERS WITH (ROWLOCK)
                     SET Status = '3',
                         EditWho = sUser_sName(),
                         EditDate = GetDate()
                     --, TrafficCop = NULL -- SOS#305979
                   WHERE OrderKey = @c_xdOrderKey
                     AND status < '3'

                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12814   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                      + ': Update Failed On Table ORDERS. (ntrPickingInfoAdd) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
                  END
               END

               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  UPDATE ORDERDETAIL WITH (ROWLOCK)
                     SET Status = '3',
                         EditWho = sUser_sName(),
                         EditDate = GetDate(),
                         TrafficCop = NULL
                   WHERE OrderKey = @c_xdOrderKey
                     AND OrderLinenumber = @c_OrderLineNumber
                     AND Status < '3'

                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12815   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                      + ': Update Failed On Table ORDERDETAIL. (ntrPickingInfoAdd) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
                  END
               END

               -- ScanInPickLog
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  EXEC dbo.isp_InsertPickDet_Log
                       @cOrderKey = @c_xdOrderKey,
                       @cOrderLineNumber=@c_OrderLineNumber,
                       @n_err=@n_err OUTPUT,
                       @c_errmsg=@c_errmsg OUTPUT,
                       @cPickSlipNo = @c_pickslipno

               END -- (continue =1)

               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  IF (ISNULL(@c_PrevLoadKey,'') <> ISNULL(@c_LoadKey,'')) OR (ISNULL(@c_PrevLoadOrderKey,'') <> ISNULL(@c_xdOrderKey,'')) --NJOW02
                  BEGIN
                     SELECT @c_PrevLoadKey = @c_LoadKey
                     SELECT @c_PrevLoadOrderKey = @c_xdOrderKey

                     UPDATE LOADPLANDETAIL WITH (ROWLOCK)
                        SET Status = '3',
                            EditWho = sUser_sName(),
                            EditDate = GetDate(),
                            TrafficCop = NULL
                      WHERE LoadKey = @c_LoadKey
                        AND OrderKey = @c_xdOrderKey
                        AND Status < '5'

                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_Continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12816   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                         + ': Update Failed On Table LOADPLANDETAIL. (ntrPickingInfoAdd) ( '
                                         + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
                     END

                     IF @n_Continue = 1 OR @n_Continue = 2
                     BEGIN
                        UPDATE LoadPlan WITH (ROWLOCK)
                           SET Status = '3',
                               EditWho = sUser_sName(),
                               EditDate = GetDate(),
                               TrafficCop = NULL
                         WHERE LoadKey = @c_LoadKey
                           AND Status < '3'

                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_Continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12817   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                            + ': Update Failed On Table LOADPLANDETAIL. (ntrPickingInfoAdd) ( '
                                            + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
                        END
                     END
                  END
               END

               EXECUTE dbo.nspGetRight '',
                  @c_StorerKey,   -- Storer
                  '',             -- Sku
                  'ScanInLog',     -- ConfigKey
                  @b_success              OUTPUT,
                  @c_authority_scaninlog  OUTPUT,
                  @n_err                  OUTPUT,
                  @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12818   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                   + ': Retrieve of Right (ScanInLog) Failed (ntrPickingInfoAdd) ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
               END

               IF @c_authority_scaninlog = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                    FROM StorerConfig WITH (NOLOCK)
                   WHERE StorerKey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  -- (MC01) S
                  SELECT @c_OrderType = Type
                  FROM ORDERS WITH (NOLOCK)
                  WHERE Orderkey = @c_xdorderkey

                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END
                  -- (MC01) E

                  EXEC dbo.ispGenTransmitLog3 'ScanInLog', @c_xdOrderKey, @c_cfgvalue, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  End
               END
               -- End SOS#41737

               --(MC03) - S
               EXECUTE dbo.nspGetRight '',
                  @c_StorerKey,   -- Storer
                  '',             -- Sku
                  'ScanIn2Log',     -- ConfigKey
                  @b_success              OUTPUT,
                  @c_authority_scanin2log  OUTPUT,
                  @n_err                  OUTPUT,
                  @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12818   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                   + ': Retrieve of Right (ScanIn2Log) Failed (ntrPickingInfoAdd) ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
               END

               IF @c_authority_scanin2log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                    FROM StorerConfig WITH (NOLOCK)
                   WHERE StorerKey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  -- (MC01) S
                  SELECT @c_OrderType = Type
                  FROM ORDERS WITH (NOLOCK)
                  WHERE Orderkey = @c_xdorderkey

                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END
                  -- (MC01) E

                  EXEC dbo.ispGenTransmitLog3 'ScanIn2Log', @c_xdOrderKey, @c_cfgvalue, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  End
               END
               --(MC03) - E

               --(MC04) - S
               SET @c_authority_scanin3log = ''
               EXECUTE dbo.nspGetRight '',
                  @c_StorerKey,   -- Storer
                  '',             -- Sku
                  'ScanIn3Log',     -- ConfigKey
                  @b_success              OUTPUT,
                  @c_authority_scanin3log OUTPUT,
                  @n_err                  OUTPUT,
                  @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12818   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                   + ': Retrieve of Right (ScanIn3Log) Failed (ntrPickingInfoAdd) ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
               END

               IF @c_authority_scanin3log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                    FROM StorerConfig WITH (NOLOCK)
                   WHERE StorerKey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  -- (MC01) S
                  SELECT @c_OrderType = Type
                  FROM ORDERS WITH (NOLOCK)
                  WHERE Orderkey = @c_xdorderkey

                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END
                  -- (MC01) E

                  EXEC dbo.ispGenTransmitLog3 'ScanIn3Log', @c_xdOrderKey, @c_cfgvalue, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  End
               END
               --(MC04) - E

               --(MC05) - S
               SET @c_authority_scanin4log = ''
               Execute dbo.nspGetRight '',
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'ScanIn4Log',     -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_scanin4log  OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                    + ': Retrieve of Right (ScanIn4Log) Failed (ntrPickingInfoAdd) ( '
                                    + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
               End

               IF @c_authority_scanin4log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                     FROM StorerConfig WITH (NOLOCK)
                     WHERE StorerKey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END

                  EXEC dbo.ispGenTransmitLog3 'ScanIn4Log', @c_xdOrderKey, @c_cfgvalue , @c_StorerKey, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  End
               END

               SET @c_authority_scanin5log = ''
               Execute dbo.nspGetRight '',
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'Scanin5Log',     -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_scanin5log  OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                    + ': Retrieve of Right (Scanin5Log) Failed (ntrPickingInfoAdd) ( '
                                    + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
               End

               IF @c_authority_scanin5log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                     FROM StorerConfig WITH (NOLOCK)
                     WHERE StorerKey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END

                  EXEC dbo.ispGenTransmitLog3 'Scanin5Log', @c_xdOrderKey, @c_cfgvalue , @c_StorerKey, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  End
               END
               --(MC05) - E
               
               -- (YokeBeen02) Start
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  SELECT @b_success = 0
                  EXECUTE dbo.nspGetRight  NULL,
                          @c_StorerKey,        -- Storer
                          '',                  -- Sku
                          'PICKINPROG',        -- ConfigKey
                          @b_success              OUTPUT,
                          @c_authority_pickinprog OUTPUT,
                          @n_err                  OUTPUT,
                          @c_errmsg               OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12819
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                      + ': Retrieve of Right (PICKINPROG) Failed (ntrPickingInfoAdd)'
                                      + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                  END
                  ELSE
                  BEGIN
                     IF @c_authority_pickinprog = '1'
                     BEGIN
                        EXEC dbo.ispGenTransmitLog3 'PICKINPROG', @c_xdOrderKey, '', @c_StorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_Continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12820
                           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                            + ': Insert into TransmitLog3 Failed (ntrPickingInfoAdd)'
                                            + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                        END
                     END
                  END -- IF @b_success <> 1
               END
               -- (YokeBeen02) End
               FETCH NEXT FROM uniqorder_cur INTO @c_xdOrderKey, @c_OrderLineNumber
            END -- End while loop

            CLOSE uniqorder_cur
            DEALLOCATE uniqorder_cur
         END -- crossdock pickslip

         IF @c_PickSlipType <> 'XD' AND @c_PickSlipType <> 'LB' AND @c_PickSlipType <> 'LP' -- SOS37177 & SOS37178 by Ong 7JUL2005
         BEGIN
            UPDATE LoadPlan WITH (ROWLOCK)
               SET Status = '3',
                   EditWho = sUser_sName(),
                   EditDate = GetDate(),
                   TrafficCop = NULL
              FROM LoadPlan
             WHERE LoadPlan.LoadKey = @c_LoadKey
               AND LoadPlan.Status < '3'
         END

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12821   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                             + ': Update Failed On Table LoadPlan. (ntrPickingInfoAdd) ( '
                             + ' SQLSvr MESSAGE=' + LTrim(RTRIM(@c_errmsg)) + ' ) '
         END

         -- for watsons's pickslip : zone = 'W'
         -- wally : 23.oct.03
         -- startW
         IF (@n_Continue = 1 OR @n_Continue = 2) AND @c_PickSlipType = 'W'
         BEGIN
            SELECT @c_OrderKey = ''

            DECLARE C_PI_PickDetail CURSOR LOCAl FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT OrderKey
            FROM Pickdetail WITH (NOLOCK)
            WHERE Pickslipno = @c_pickslipno
            ORDER BY OrderKey

            OPEN C_PI_PickDetail

            FETCH NEXT FROM C_PI_PickDetail INTO @c_OrderKey

            -- while (1=1)
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               --select @c_OrderKey = min(OrderKey)
               --from pickdetail (nolock)
               --where pickslipno = @c_pickslipno
               --AND OrderKey > @c_OrderKey

               IF ISNULL(@c_OrderKey, 0) = 0
               BREAK

               UPDATE ORDERS WITH (ROWLOCK)
                  SET --trafficcop = NULL, -- SOS#305979
                      EditWho = sUser_sName(),
                      EditDate = GetDate(),
                      status = '3'
                WHERE OrderKey = @c_OrderKey

               SELECT @n_err = @@error

               IF @n_err <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12822   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                   + ': Update Failed On Table Orders. (ntrPickingInfoAdd) ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
               END

               SELECT @c_StorerKey = StorerKey
                    , @c_OrderType = Type      --(MC01)
               FROM ORDERS WITH (NOLOCK)
               WHERE OrderKey = @c_OrderKey

               EXECUTE dbo.nspGetRight '',
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'ScanInLog',     -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_scaninlog  OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                      SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12823   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                       + ': Retrieve of Right (ScanInLog) Failed (ntrPickingInfoAdd) ( '
                                       + ' SQLSvr MESSAGE=' + LTrim(RTRIM(@c_errmsg)) + ' ) '
               END

               IF @c_authority_scaninlog = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                    FROM StorerConfig WITH (NOLOCK)
                   WHERE StorerKey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  -- (MC01) S
                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END
                  -- (MC01) E

                  EXEC dbo.ispGenTransmitLog3 'ScanInLog', @c_OrderKey, @c_cfgvalue, @c_StorerKey, ''
                          , @b_success OUTPUT
                          , @n_err OUTPUT
                          , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  END
               END
               -- End SOS#41737

               --(MC03) - S
               EXECUTE dbo.nspGetRight '',
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'ScanIn2Log',     -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_scanin2log  OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                      SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12823   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                       + ': Retrieve of Right (ScanIn2Log) Failed (ntrPickingInfoAdd) ( '
                                       + ' SQLSvr MESSAGE=' + LTrim(RTRIM(@c_errmsg)) + ' ) '
               END

               IF @c_authority_scanin2log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                    FROM StorerConfig WITH (NOLOCK)
                   WHERE StorerKey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  -- (MC01) S
                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END
                  -- (MC01) E

                  EXEC dbo.ispGenTransmitLog3 'ScanIn2Log', @c_OrderKey, @c_cfgvalue, @c_StorerKey, ''
                          , @b_success OUTPUT
                          , @n_err OUTPUT
                          , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  END
               END
               --(MC03) - E

               --(MC04) - S
               SET @c_authority_scanin3log = ''
               EXECUTE dbo.nspGetRight '',
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'ScanIn3Log',     -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_scanin3log  OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                      SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12823   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                                       + ': Retrieve of Right (ScanIn3Log) Failed (ntrPickingInfoAdd) ( '
                                       + ' SQLSvr MESSAGE=' + LTrim(RTRIM(@c_errmsg)) + ' ) '
               END

               IF @c_authority_scanin3log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                    FROM StorerConfig WITH (NOLOCK)
                   WHERE StorerKey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  -- (MC01) S
                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END
                  -- (MC01) E

                  EXEC dbo.ispGenTransmitLog3 'ScanIn3Log', @c_OrderKey, @c_cfgvalue, @c_StorerKey, ''
                          , @b_success OUTPUT
                          , @n_err OUTPUT
                          , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  END
               END
               --(MC04) - E

               --(MC05) - S
               SET @c_authority_scanin4log = ''
               Execute dbo.nspGetRight '',
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'ScanIn4Log',     -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_scanin4log  OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                    + ': Retrieve of Right (ScanIn4Log) Failed (ntrPickingInfoAdd) ( '
                                    + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
               End

               IF @c_authority_scanin4log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                     FROM StorerConfig WITH (NOLOCK)
                     WHERE StorerKey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END

                  EXEC dbo.ispGenTransmitLog3 'ScanIn4Log', @c_OrderKey, @c_cfgvalue , @c_StorerKey, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  End
               END

               SET @c_authority_scanin5log = ''
               Execute dbo.nspGetRight '',
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'Scanin5Log',     -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_scanin5log  OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                    + ': Retrieve of Right (Scanin5Log) Failed (ntrPickingInfoAdd) ( '
                                    + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTRIM(@c_errmsg)),'') + ' ) '
               End

               IF @c_authority_scanin5log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                     FROM StorerConfig WITH (NOLOCK)
                     WHERE StorerKey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END

                  EXEC dbo.ispGenTransmitLog3 'Scanin5Log', @c_OrderKey, @c_cfgvalue , @c_StorerKey, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  End
               END
               --(MC05) - E
               
               -- (YokeBeen02) Start
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  SELECT @b_success = 0
                  EXECUTE dbo.nspGetRight  NULL,
                          @c_StorerKey,        -- Storer
                          '',                  -- Sku
                          'PICKINPROG',        -- ConfigKey
                          @b_success              OUTPUT,
                          @c_authority_pickinprog OUTPUT,
                          @n_err                  OUTPUT,
                          @c_errmsg               OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12824
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                      + ': Retrieve of Right (PICKINPROG) Failed (ntrPickingInfoAdd)'
                                      + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                  END
                  ELSE
                  BEGIN
                     IF @c_authority_pickinprog = '1'
                     BEGIN
                        EXEC dbo.ispGenTransmitLog3 'PICKINPROG', @c_OrderKey, '', @c_StorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_Continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12825
                           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                            + ': Insert into TransmitLog3 Failed (ntrPickingInfoAdd)'
                                            + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                        END
                     END
                  END -- IF @b_success <> 1
               END
               -- (YokeBeen02) End
               FETCH NEXT FROM C_PI_PickDetail INTO @c_OrderKey
            END
            CLOSE C_PI_PickDetail
            DEALLOCATE C_PI_PickDetail
         END
         -- endW
         
         --NJOW01 S                  
         IF LEFT(@c_Pickslipno,1) <> 'P'
         BEGIN
         	  SELECT TOP 1 @c_Storerkey = O.Storerkey,
         	               @c_Facility = O.Facility
         	  FROM STORERCONFIG SC (NOLOCK) 
         	  JOIN ORDERS O (NOLOCK) ON O.Storerkey = SC.Storerkey 
         	  JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = O.Orderkey     
         	  WHERE PD.Pickslipno = @c_Pickslipno
         	  AND SC.Configkey = 'WSScanInLog'       
         	  AND (SC.Facility = O.Facility OR ISNULL(SC.Facility,'') = '')
         	  AND SC.Svalue = '1'  	  
         	  AND O.Status <> '9'
         END
         
         SET @c_WSScanInLog = ''
         Execute nspGetRight                                
            @c_Facility  = @c_facility,                     
            @c_StorerKey = @c_StorerKey,                    
            @c_sku       = '',                          
            @c_ConfigKey = 'WSScanInLog', -- Configkey         
            @b_Success   = @b_success     OUTPUT,             
            @c_authority = @c_WSScanInLog OUTPUT,             
            @n_err       = @n_err         OUTPUT,             
            @c_errmsg    = @c_errmsg      OUTPUT,             
            @c_Option1 = @c_WSSIOption1 OUTPUT              
            
         IF ISNULL(@c_WSScanInLog,'') = '1' AND ISNULL(@c_WSSIOption1,'') <> '' AND
            NOT EXISTS(SELECT 1 FROM INSERTED WHERE Pickslipno = @c_Pickslipno AND PickerID = 'VoicePicking')        
         BEGIN         
         	  SET @b_success = 0
            EXEC dbo.ispGenTransmitLog2 @c_WSSIOption1, @c_pickslipno, '', @c_StorerKey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
            
            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12814
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Insert into TransmitLog2 Failed (ntrPickingInfoAdd)'
                                + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
            END         	
         END       
         --NJOW01 E

         FETCH NEXT FROM C_PickInfo_Add_01 INTO  @c_pickslipno
      END -- while pickslip no
      CLOSE C_PickInfo_Add_01
      DEALLOCATE C_PickInfo_Add_01
   END

   /* #INCLUDE <TRMBOHA2.SQL> */
   IF @n_Continue = 3  -- Error Occured - Process AND Return
   BEGIN
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPickingInfoAdd'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO