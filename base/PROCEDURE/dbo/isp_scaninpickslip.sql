SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_ScanInPickslip                                    */
/* Creation Date: 10-Nov-2006                                              */
/* Copyright: IDS                                                          */
/* Written by: June                                                        */
/*                                                                         */
/* Purpose: Replace ntrPickingInfoAdd Trigger, use Stored Proc             */
/*      to improve performance.                                            */
/*                                                                         */
/* Called By: nep_n_cst_policy_scaninpickslip                              */
/*                                                                         */
/* PVCS Version: 1.7                                                       */
/*                                                                         */
/* Version: 6.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 01-Oct-2007  YokeBeen  1.1   SOS#83917 - Discrete Pick Ticket &         */
/*                              SOS#84285 - Consolidated Pick Ticket of    */
/*                              USA. PickHeader.Zone -> Conso = 'C'        */
/*                                                   -> Discrete = 'D'     */
/*                              - (YokeBeen01)                             */
/* 17-Jul-2008  YokeBeen  1.2   SOS#111333 - New trigger point for IDSTW   */
/*                              LOR for the Pick Confirmation Outbound.    */
/*                              Records to be triggered when               */
/*                              ORDERS.Status = "3".                       */
/*                              Tablename = "PICKINPROG". - (YokeBeen02)   */
/* 18-Nov-2008 Shong      1.3   Include Column Name with Insert TraceInfo  */
/* 28-Oct-2009 Shong      1.4   Insert into PickDet_Log if StorerConfig    */
/*                              ScanInPickLog.                             */
/* 02-Feb-2010 MCTang     1.4   SOS#159235 - Assign Orders.Type to Keys for*/
/*                              'ScanInLog' IF 'WitronOL' is OFF (MC01)    */
/* 18-May-2010 MCTang     1.5   Add new trigger point 'PICKINMAIL'(MC02)   */
/* 02-Apr-2012 Audrey     1.6   SOS240265 - Add filter order.status >0,    */
/*                              Orderdetail.status >0 &                    */
/*                              loadplandetail.status>0 for consol pickslip*/
/*                              (ang01)                                    */
/* 25-03-2014  Leong      1.7   SOS#305979 - Add TraceInfo                 */
/* 09-09-2014  TLTING     2.0   Doc Status Tracking Log TLTING01           */
/* 04-01-2015  TLTING     2.1   Perfromance Tune                           */
/* 07-04-2015  TLTING01   2.2   Bug fix                                    */
/* 11-03-2020  MCTang     2.3   Add scanin2log (MC03)                      */
/* 11-05-2020  MCTang     2.3   Add scanin3log (MC04)                      */
/* 24-Jan-2022 MCTang     2.4   Add scanin4log & scanin5log (MC05)         */
/***************************************************************************/
CREATE PROCEDURE [dbo].[isp_ScanInPickslip]
   @c_PickSlipNo NVARCHAR(10),
   @c_PickerID   NVARCHAR(18),
   @n_err        INT = 0            OUTPUT,
   @c_errmsg     NVARCHAR(255) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   set ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success              INT       -- Populated by calls to stored procedures - was the proc successful?
         , @n_err2                 INT       -- For Additional Error Detection
         , @n_Continue             INT
         , @n_StartTcnt            INT                -- Holds the current transaction count
         , @c_preprocess           NVARCHAR(250)      -- preprocess
         , @c_pstprocess           NVARCHAR(250)      -- post process
         , @n_cnt                  INT
         , @c_authority_scaninlog  NVARCHAR(1)  -- SOS41737
         , @c_authority_scanin2log NVARCHAR(1)  -- (MC03)
         , @c_authority_scanin3log NVARCHAR(1)  -- (MC04)
         , @c_authority_scanin4log NVARCHAR(1)  -- (MC05)
         , @c_authority_scanin5log NVARCHAR(1)  -- (MC05)
         , @c_storerkey            NVARCHAR(15) -- SOS41737
         , @c_cfgvalue             NVARCHAR(1)  -- SOS41737
         , @c_authority_pickinprog NVARCHAR(1)  -- (YokeBeen02)
         , @c_authority_PickInMail NVARCHAR(1)

   DECLARE @n_maxchildSP       INT
         , @n_ChildSP          INT
         , @c_ParentSP         NVARCHAR(10)
         , @c_PickSlipType     NVARCHAR(10)
         , @c_OrderKey         NVARCHAR(10)
         , @c_LPOrderKey       NVARCHAR(10)
         , @c_LoadKey          NVARCHAR(10)
         , @c_xdorderkey       NVARCHAR(10)
         , @c_orderlinenumber  NVARCHAR(5)
         , @n_rowno            INT
         , @n_rowcount         INT
         , @c_prevorderkey     NVARCHAR(10)     -- tlting01
         , @c_prevloadkey      NVARCHAR(10)
         , @c_prevloadorderkey NVARCHAR(10)
         , @c_usrstorerkey     NVARCHAR(15)
         , @c_usrfacility      NVARCHAR(5)
         , @cExecStatements    nvarchar(4000)
         , @b_debug            NVARCHAR(1)
         , @c_OrderType        NVARCHAR(10)   --MC01

   SELECT @n_Continue = 1, @n_StartTcnt = @@TRANCOUNT
   SET    @b_debug = 0

   -- (June01) - Start
   -- TraceInfo
   DECLARE  @c_starttime DATETIME,
            @c_endtime   DATETIME,
            @c_step1     DATETIME,
            @c_step2     DATETIME,
            @c_step3     DATETIME,
            @c_step4     DATETIME,
            @c_step5     DATETIME

   -- SOS#305979
   DECLARE @d_Trace_StartTime DATETIME
         , @d_Trace_EndTime   DATETIME
         , @c_Trace_UserName  NVARCHAR(20)

   SET @d_Trace_StartTime = GETDATE()
   SET @d_Trace_EndTime   = GETDATE()
   SET @c_Trace_UserName  = SUSER_SNAME()

   IF @b_debug = 1
   BEGIN
      SET @c_starttime = GETDATE()
   END
   -- TraceInfo
   -- (June01) - END

   BEGIN TRAN

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF ISNULL(dbo.fnc_RTrim(@c_PickSlipNo),'') = ''
      BEGIN
         SELECT @n_Continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=12800
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                          + ': Error Printing Pickslip. Please Call PFC team. (isp_ScanInPickslip) ( '
                          + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
      END
   END

   /*
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF @c_SecurityDB > '' AND @c_UserID > ''
      BEGIN
         -- Step 1
         IF @b_debug = 1
         BEGIN
            SET @c_step1 = GETDATE()
         END

         SELECT @cExecStatements = ''
         SELECT @cExecStatements = N'SELECT @c_usrstorerkey = Usr_Storerkey, @c_usrfacility = Usr_Facility '
                                 + ' FROM ' +  dbo.fnc_RTrim(@c_SecurityDB)
                                 + '..PL_USR (NOLOCK) '
                                 + 'WHERE usr_login = @c_UserID '
         EXEC sp_executesql @cExecStatements, N'@c_usrstorerkey NVARCHAR(15) OUTPUT, @c_usrfacility NVARCHAR(5) OUTPUT, @c_UserID NVARCHAR(40) '
                          , @c_usrstorerkey OUTPUT, @c_usrfacility OUTPUT, @c_UserID

         IF @c_usrstorerkey > '' OR @c_usrfacility > ''
         BEGIN
            SELECT @c_PickSlipType = ZONE
            FROM   PickHeader (NOLOCK)
            WHERE  PickHeaderKey = @c_PickSlipNo
         END

         -- Check for Storer Restriction
         IF @c_usrstorerkey > ''
         BEGIN
            IF (@c_PickSlipType = 'XD' OR @c_PickSlipType = 'LB' OR @c_PickSlipType = 'LP')
            BEGIN
               IF (SELECT  ORDERS.Storerkey
                     FROM   PickHeader (NOLOCK)
                     JOIN   RefKeyLookup (NOLOCK) ON PickHeader.PickHeaderKey = RefKeyLookup.PickSlipNo
                     JOIN   ORDERS (NOLOCK) ON RefKeyLookup.OrderKey = ORDERS.OrderKey
                     WHERE  PickHeaderKey = @c_PickSlipNo
                     AND    Zone IN ('XD', 'LB', 'LP')) <> @c_usrstorerkey
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))+': User Not Allow to Access Storer Other Than '+ dbo.fnc_RTrim(@c_usrstorerkey) + ' (isp_ScanInPickslip)' + ' (' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END
            ELSE
            BEGIN -- Normal OR Conso P/S
               IF (SELECT ORDERS.Storerkey
                  FROM  PickHeader(NOLOCK)
                  JOIN  ORDERS (NOLOCK) ON PickHeader.OrderKey = ORDERS.OrderKey
                  WHERE PickHeaderKey = @c_PickSlipNo
                  AND   PickHeader.OrderKey > ''
                  AND   Zone NOT IN ('XD', 'LB', 'LP')
                  UNION
                  SELECT ORDERS.Storerkey
                  FROM  PickHeader(NOLOCK)
                  JOIN  ORDERS (NOLOCK) ON PickHeader.ExternOrderkey = ORDERS.Loadkey
                  WHERE PickHeaderKey = @c_PickSlipNo
                  AND   PickHeader.ExternOrderkey > ''
                  AND   pickheader.OrderKey = ''
                  AND   Zone NOT IN ('XD', 'LB', 'LP')) <> @c_usrstorerkey
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))+': User Not Allow to Access Storer Other Than '+ dbo.fnc_RTrim(@c_usrstorerkey) + ' (isp_ScanInPickslip)' + ' (' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END -- Normal OR Conso P/S
         END -- Check for Storer Restriction

         -- Check for Facility Restriction
         IF @c_usrfacility > ''
         BEGIN
            IF (@c_PickSlipType = 'XD' OR @c_PickSlipType = 'LB' OR @c_PickSlipType = 'LP')
            BEGIN
               IF (SELECT  ORDERS.Facility
                     FROM   PickHeader(NOLOCK)
                     JOIN   RefKeyLookup (NOLOCK) ON PickHeader.PickHeaderKey = RefKeyLookup.PickSlipNo
                     JOIN   ORDERS (NOLOCK) ON RefKeyLookup.OrderKey = ORDERS.OrderKey
                     WHERE  PickHeaderKey = @c_PickSlipNo
                     AND    Zone IN ('XD', 'LB', 'LP')) <> @c_usrfacility
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))+': User Not Allow to Access Facility Other Than '+ dbo.fnc_RTrim(@c_usrfacility) + ' (isp_ScanInPickslip)' + ' (' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END
            ELSE
            BEGIN -- Normal OR Conso P/S
               IF (SELECT ORDERS.Facility
                     FROM  PickHeader(NOLOCK)
                     JOIN  ORDERS (NOLOCK) ON PickHeader.OrderKey = ORDERS.OrderKey
                     WHERE PickHeaderKey = @c_PickSlipNo
                     AND   PickHeader.OrderKey > ''
                     AND   Zone NOT IN ('XD', 'LB', 'LP')
                     UNION
                     SELECT ORDERS.Facility
                     FROM  PickHeader(NOLOCK)
                     JOIN  ORDERS (NOLOCK) ON PickHeader.ExternOrderkey = ORDERS.Loadkey
                     WHERE PickHeaderKey = @c_PickSlipNo
                     AND   PickHeader.ExternOrderkey > ''
                     AND   pickheader.OrderKey = ''
                     AND   Zone NOT IN ('XD', 'LB', 'LP')) <> @c_usrfacility
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))+': User Not Allow to Access Facility Other Than '+ dbo.fnc_RTrim(@c_usrfacility) + ' (isp_ScanInPickslip)' + ' (' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END -- Normal OR Conso P/S
         END -- Check for Facility Restriction

         IF @b_debug = 1
         BEGIN
            SET @c_step1 = GETDATE() - @c_step1
         END
      END -- @c_SecurityDB > '' AND @c_UserID > ''
   END
   */

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE C_PickInfo_Add_01 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Zone,
                ExternOrderKey,
         ISNULL(OrderKey, '')
         FROM PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @c_PickSlipNo

      OPEN C_PickInfo_Add_01
      FETCH NEXT FROM C_PickInfo_Add_01 INTO @c_PickSlipType, @c_LoadKey, @c_LPOrderKey

      -- Step 2
      IF @b_debug = 1
      BEGIN
         SET @c_step2 = GETDATE()
      END

      WHILE @@FETCH_STATUS <> -1 AND (@n_Continue = 1 OR @n_Continue = 2)
      BEGIN
         IF EXISTS ( SELECT 1 FROM Orders O WITH (NOLOCK)
                     JOIN StorerConfig S WITH (NOLOCK)
                     ON (O.StorerKey = S.StorerKey)
                     AND S.ConfigKey = 'PICKINMAIL' AND ISNULL(RTRIM(S.SValue),'') = '1'
                     AND O.OrderKey = ISNULL(RTRIM(@c_LPOrderKey),'') )
         BEGIN
            EXEC isp_InsertTraceInfo -- SOS#305979
                 @c_TraceCode = 'PICKINMAIL'
               , @c_TraceName = 'isp_ScanInPickslip'
               , @c_StartTime = @d_Trace_StartTime
               , @c_EndTime   = @d_Trace_EndTime
               , @c_Step1     = @c_PickSlipNo
               , @c_Step2     = @c_PickSlipType
               , @c_Step3     = @c_LoadKey
               , @c_Step4     = @c_LPOrderKey
               , @c_Step5     = @c_PickerID
               , @c_Col1      = @c_Trace_UserName
               , @c_Col2      = ''
               , @c_Col3      = ''
               , @c_Col4      = ''
               , @c_Col5      = ''
               , @b_Success   = 1
               , @n_Err       = 0
               , @c_ErrMsg    = ''
         END

         IF ISNULL(dbo.fnc_RTrim(@c_PickSlipType),'') = ''
            BREAK

         IF @c_PickSlipType = '1' AND LEFT(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_PickSlipNo)), 1) = 'C'
         BEGIN
            -- Step 3
            IF @b_debug = 1
            BEGIN
               SET @c_step3 = GETDATE()
            END

            -- Added for SOS#41737
            -- MC01
            /*
            SELECT DISTINCT @c_storerkey = STORERKEY
            FROM  ORDERS WITH (NOLOCK)
            WHERE Loadkey = @c_LoadKey
            */

            SELECT @c_storerkey = MIN(STORERKEY)
                 , @c_OrderType = MIN(TYPE)
            FROM  ORDERS WITH (NOLOCK)
            WHERE Loadkey = @c_LoadKey

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
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                + ': Retrieve of Right (ScanInLog) Failed (isp_ScanInPickslip) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
            END

            IF @c_authority_scaninlog = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
               FROM StorerConfig WITH (NOLOCK)
               WHERE Storerkey = @c_StorerKey
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
               END
            END
            -- END SOS#41737

            --(MC03) - S
            SET @c_authority_scanin2log = ''
            EXECUTE dbo.nspGetRight '',
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'ScanIn2Log',   -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_scanin2log OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                + ': Retrieve of Right (ScanIn2Log) Failed (isp_ScanInPickslip) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
            END

            IF @c_authority_scanin2log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
               FROM StorerConfig WITH (NOLOCK)
               WHERE Storerkey = @c_StorerKey
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
               END
            END
            --(MC03) - E

            --(MC04) - S
            SET @c_authority_scanin3log = ''
            EXECUTE dbo.nspGetRight '',
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'ScanIn3Log',   -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_scanin3log OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                + ': Retrieve of Right (ScanIn3Log) Failed (isp_ScanInPickslip) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
            END

            IF @c_authority_scanin3log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
               FROM StorerConfig WITH (NOLOCK)
               WHERE Storerkey = @c_StorerKey
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
               END
            END
            --(MC04) - E

            --(MC05) - S
            SET @c_authority_scanin4log = ''
            EXECUTE dbo.nspGetRight '',
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'Scanin4Log',   -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_scanin4log OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                + ': Retrieve of Right (Scanin4Log) Failed (isp_ScanInPickslip) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
            END

            IF @c_authority_scanin4log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
               FROM StorerConfig WITH (NOLOCK)
               WHERE Storerkey = @c_StorerKey
               AND Configkey = 'WitronOL'

               IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
               BEGIN
                  SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
               END

               EXEC dbo.ispGenTransmitLog3 'Scanin4Log', @c_LPOrderKey, @c_cfgvalue , @c_StorerKey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
               END
            END

            SET @c_authority_scanin5log = ''
            EXECUTE dbo.nspGetRight '',
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'Scanin5Log',   -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_scanin5log OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                + ': Retrieve of Right (Scanin5Log) Failed (isp_ScanInPickslip) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
            END

            IF @c_authority_scanin5log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
               FROM StorerConfig WITH (NOLOCK)
               WHERE Storerkey = @c_StorerKey
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
               END
            END
            --(MC05) - E

            -- (MC02)
            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
               EXECUTE dbo.nspGetRight '',
                        @c_StorerKey,   -- Storer
                        '',             -- Sku
                        'PICKINMAIL',   -- ConfigKey
                        @b_success              OUTPUT,
                        @c_authority_PickInMail OUTPUT,
                        @n_err                  OUTPUT,
                        @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                   + ': Retrieve of Right (PICKINMAIL) Failed (isp_ScanInPickslip) ( '
                                   + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END

               IF @c_authority_PickInMail = '1'
               BEGIN
                  EXEC dbo.ispGenTransmitLog3 'PICKINMAIL', @c_LPOrderKey, '', @c_StorerKey, ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  END
               END
            END -- IF @n_Continue = 1 OR @n_Continue = 2
            -- (MC02)

            IF @b_debug = 1
            BEGIN
               SET @c_step3 = GETDATE() - @c_step3
            END
         END -- PS Type = '1' AND 1st Char of PS# = 'C'

         -- Consolidated PickSlip Zone = '5'
         IF @c_PickSlipType IN ('5','6','7','9','C') -- (YokeBeen01)
         BEGIN
            SELECT @c_OrderKey = ''
            -- Step 3
            IF @b_debug = 1
            BEGIN
               SET @c_step3 = GETDATE()
            END

            DECLARE C_PKI_LoadPlanDet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LOADPLANDETAIL.OrderKey
               FROM   LOADPLANDETAIL WITH (NOLOCK)
               WHERE  LOADPLANDETAIL.LoadKey = @c_LoadKey
               ORDER BY LOADPLANDETAIL.OrderKey

            OPEN C_PKI_LoadPlanDet
            FETCH NEXT FROM C_PKI_LoadPlanDet INTO @c_OrderKey

            WHILE @@FETCH_STATUS <> -1 AND (@n_Continue = 1 OR @n_Continue = 2)
            BEGIN
               IF ISNULL(dbo.fnc_RTrim(@c_OrderKey),'') = ''
               BREAK

               /* Comment this for Performance Purposes
               UPDATE PICKDETAIL
               SET STATUS = '3'
               FROM PICKDETAIL
               WHERE OrderKey = @c_OrderKey
               AND   Status < '3'
               */
               -- ScanInPickLog
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  EXEC dbo.isp_InsertPickDet_Log
                       @cOrderKey = @c_OrderKey,
                       @cOrderLineNumber='',
                       @n_err=@n_err OUTPUT,
                       @c_errmsg=@c_errmsg OUTPUT,
                       @cPickSlipNo = @c_PickSlipNo

               END -- (continue =1)

               IF EXISTS ( SELECT 1 FROM ORDERS with (NOLOCK)
                              WHERE OrderKey = @c_OrderKey AND   Status >'0' AND Status < '3' )
               BEGIN               
                  UPDATE ORDERS WITH (ROWLOCK)
                  SET Status = '3',
                      EditWho = sUser_sName(),
                      EditDate = GETDATE(),
                      TrafficCop = NULL
                  WHERE OrderKey = @c_OrderKey
                  AND   Status >'0' AND Status < '3'  --ang01
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=22807
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))
                                      + ': Update Failed On Table ORDERS. (isp_ScanInPickslip) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                  END
               END

               -- TLTING01 - Insert Document Tracking Log - for Interface trigger
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK)   
                                  WHERE TableName = 'STSORDERS' AND DocumentNo = @c_OrderKey AND DocStatus = '3')    
                  BEGIN  
                     EXEC ispGenDocStatusLog 'STSORDERS', @c_StorerKey, @c_OrderKey, '', '', '3'  
                                    , @b_success OUTPUT  
                                    , @n_err OUTPUT  
                                    , @c_errmsg OUTPUT  
                     IF NOT @b_success=1  
                     BEGIN  
                        SELECT @n_continue=3  
                     END      
                  END
               END
               
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  IF EXISTS ( SELECT 1 FROM ORDERDETAIL with (NOLOCK) 
                              WHERE ORDERDETAIL.LoadKey = @c_LoadKey
                                 AND   ORDERDETAIL.OrderKey = @c_OrderKey
                                 AND   ORDERDETAIL.Status >'0' AND ORDERDETAIL.Status < '3' )
                  BEGIN               
                     UPDATE ORDERDETAIL WITH (ROWLOCK)
                     SET Status = '3',
                         EditWho = sUser_sName(),
                         EditDate = GETDATE(),
                         TrafficCop = NULL
                     WHERE ORDERDETAIL.LoadKey = @c_LoadKey
                     AND   ORDERDETAIL.OrderKey = @c_OrderKey
                     AND   ORDERDETAIL.Status >'0' AND ORDERDETAIL.Status < '3'  --ang01
   
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_Continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=22809
                        SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                        +': Update Failed On Table ORDERDETAIL. (isp_ScanInPickslip)' + ' ( '
                                        + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                     END
                  END
               END

               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  IF EXISTS ( SELECT 1 FROM LOADPLANDETAIL with (NOLOCK)
                              WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey
                              AND   LOADPLANDETAIL.Status <> '3'  AND LOADPLANDETAIL.Status < '5' )
                  BEGIN  
                     UPDATE LOADPLANDETAIL WITH (ROWLOCK)
                     SET Status = '3',
                         EditWho = sUser_sName(),
                         EditDate = GETDATE(),
                         TrafficCop = NULL
                     WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey
                     AND LOADPLANDETAIL.Status <> '3'          -- tlting01
                     AND LOADPLANDETAIL.Status < '5'
                     --AND   LOADPLANDETAIL.Status > '0' AND LOADPLANDETAIL.Status < '5'--ang01
   
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_Continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=22801
                        SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                         + ': Update Failed On Table LOADPLANDETAIL. (isp_ScanInPickslip) ( '
                                         + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                     END
                  END
               END

               -- Added for SOS#41737
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  SELECT @c_storerkey = STORERKEY
                       , @c_OrderType = TYPE     --(MC01)
                  FROM   ORDERS WITH (NOLOCK)
                  WHERE  OrderKey = @c_OrderKey

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
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                      + ': Retrieve of Right (ScanInLog) Failed (isp_ScanInPickslip) ( '
                                      + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END

                  IF @c_authority_scaninlog = '1'
                  BEGIN
                     SELECT @c_cfgvalue = svalue
                     FROM   StorerConfig WITH (NOLOCK)
                     WHERE  Storerkey = @c_StorerKey
                     AND    Configkey = 'WitronOL'

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
               END -- (continue =1)
               -- END SOS#41737

               --MC03 - S
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  SELECT @c_storerkey = STORERKEY
                       , @c_OrderType = TYPE     --(MC01)
                  FROM   ORDERS WITH (NOLOCK)
                  WHERE  OrderKey = @c_OrderKey

                  SET @c_authority_scanin2log = ''
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
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                      + ': Retrieve of Right (ScanIn2Log) Failed (isp_ScanInPickslip) ( '
                                      + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END

                  IF @c_authority_scanin2log = '1'
                  BEGIN
                     SELECT @c_cfgvalue = svalue
                     FROM   StorerConfig WITH (NOLOCK)
                     WHERE  Storerkey = @c_StorerKey
                     AND    Configkey = 'WitronOL'

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
               END -- (continue =1)
               --MC03 - E

               --(MC04) - S
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  SELECT @c_storerkey = STORERKEY
                       , @c_OrderType = TYPE     --(MC01)
                  FROM   ORDERS WITH (NOLOCK)
                  WHERE  OrderKey = @c_OrderKey

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
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                      + ': Retrieve of Right (ScanIn3Log) Failed (isp_ScanInPickslip) ( '
                                      + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END

                  IF @c_authority_scanin3log = '1'
                  BEGIN
                     SELECT @c_cfgvalue = svalue
                     FROM   StorerConfig WITH (NOLOCK)
                     WHERE  Storerkey = @c_StorerKey
                     AND    Configkey = 'WitronOL'

                     IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                     BEGIN
                        SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                     END

                     EXEC dbo.ispGenTransmitLog3 'ScanIn3Log', @c_OrderKey, @c_cfgvalue, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_Continue = 3
                     END
                  END
               END -- (continue =1)
               --(MC04) - E

               --(MC05) - S
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  SET @c_authority_scanin4log = ''
                  EXECUTE dbo.nspGetRight '',
                           @c_StorerKey,   -- Storer
                           '',             -- Sku
                           'Scanin4Log',   -- ConfigKey
                           @b_success              OUTPUT,
                           @c_authority_scanin4log OUTPUT,
                           @n_err                  OUTPUT,
                           @c_errmsg               OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                      + ': Retrieve of Right (Scanin4Log) Failed (isp_ScanInPickslip) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                  END

                  IF @c_authority_scanin4log = '1'
                  BEGIN
                     SELECT @c_cfgvalue = svalue
                     FROM StorerConfig WITH (NOLOCK)
                     WHERE Storerkey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                     IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                     BEGIN
                        SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                     END

                     EXEC dbo.ispGenTransmitLog3 'Scanin4Log', @c_OrderKey, @c_cfgvalue , @c_StorerKey, ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_Continue = 3
                     END
                  END

                  SET @c_authority_scanin5log = ''
                  EXECUTE dbo.nspGetRight '',
                           @c_StorerKey,   -- Storer
                           '',             -- Sku
                           'Scanin5Log',   -- ConfigKey
                           @b_success              OUTPUT,
                           @c_authority_scanin5log OUTPUT,
                           @n_err                  OUTPUT,
                           @c_errmsg               OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                      + ': Retrieve of Right (Scanin5Log) Failed (isp_ScanInPickslip) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                  END

                  IF @c_authority_scanin5log = '1'
                  BEGIN
                     SELECT @c_cfgvalue = svalue
                     FROM StorerConfig WITH (NOLOCK)
                     WHERE Storerkey = @c_StorerKey
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
                     END
                  END
               END
               --(MC05) - E

               -- (MC02)
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  EXECUTE dbo.nspGetRight '',
                           @c_StorerKey,   -- Storer
                           '',             -- Sku
                           'PICKINMAIL',   -- ConfigKey
                           @b_success              OUTPUT,
                           @c_authority_PickInMail OUTPUT,
                           @n_err                  OUTPUT,
                           @c_errmsg               OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                      + ': Retrieve of Right (PICKINMAIL) Failed (isp_ScanInPickslip) ( '
                                      + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END

                  IF @c_authority_PickInMail = '1'
                  BEGIN
                     EXEC dbo.ispGenTransmitLog3 'PICKINMAIL', @c_OrderKey, '', @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_Continue = 3
                     END
                  END
               END -- IF @n_Continue = 1 OR @n_Continue = 2
               -- (MC02)

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
                     INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
                     SELECT PickHeaderKey, GETDATE(), @c_PickerID, NULL
                     FROM PICKHEADER WITH (NOLOCK)
                     WHERE OrderKey IN ( SELECT DISTINCT PICKHEADER.OrderKey
                     FROM ORDERS WITH (NOLOCK)
                     JOIN PICKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PICKHEADER.OrderKey)
                     WHERE ORDERS.LoadKey = @c_LoadKey
                     AND PICKHEADER.OrderKey = @c_OrderKey
                     AND PICKHEADER.Zone = 'D' )
                  END
               END
               -- (YokeBeen01) - END

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
               -- (YokeBeen02) END

               FETCH NEXT FROM C_PKI_LoadPlanDet INTO @c_OrderKey
            END --while loop loadplan detail
            CLOSE C_PKI_LoadPlanDet
            DEALLOCATE C_PKI_LoadPlanDet

            IF @b_debug = 1
            BEGIN
               SET @c_step3 = GETDATE() - @c_step3
            END
         END -- conso pickslip
         ELSE IF @c_PickSlipType IN ('8', '3', 'D') -- (YokeBeen01)
         BEGIN
            IF @b_debug = 1
            BEGIN
               SET @c_step3 = GETDATE()
            END

            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
               EXEC dbo.isp_InsertPickDet_Log
                    @cOrderKey = @c_LPOrderKey,
                    @cOrderLineNumber='',
                    @n_err=@n_err OUTPUT,
                    @c_errmsg=@c_errmsg OUTPUT,
                    @cPickSlipNo = @c_PickSlipNo

            END -- (continue =1)

            -- TLTING01 MOve up
            -- Added for SOS#41737
            SELECT @c_storerkey = STORERKEY
                 , @c_OrderType = TYPE     --(MC01)
            FROM   ORDERS WITH (NOLOCK)
            WHERE OrderKey = @c_LPOrderKey
            
            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
               -- tlting perfromance tune
               IF EXISTS ( SELECT 1 FROM ORDERS (NOLOCK) 
                        WHERE OrderKey = @c_LPOrderKey AND Status < '3' )
               BEGIN
                  UPDATE ORDERS WITH (ROWLOCK)
                  SET Status = '3',
                      EditWho = sUser_sName(),
                      EditDate = GETDATE(),
                      TrafficCop = NULL
                  WHERE OrderKey = @c_LPOrderKey
                    AND Status < '3'
   
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=22807
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                      + ': Update Failed On Table ORDERS. (isp_ScanInPickslip) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                  END
               END
            END

            -- TLTING01 - Insert Document Tracking Log - for Interface trigger
            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK)   
                               WHERE TableName = 'STSORDERS' AND DocumentNo = @c_LPOrderKey AND DocStatus = '3')    
               BEGIN  
                  EXEC ispGenDocStatusLog 'STSORDERS', @c_StorerKey, @c_LPOrderKey, '', '', '3'  
                                 , @b_success OUTPUT  
                                 , @n_err OUTPUT  
                                 , @c_errmsg OUTPUT  
                  IF NOT @b_success=1  
                  BEGIN  
                     SELECT @n_continue=3  
                  END      
               END
            END
            
            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
               IF EXISTS ( SELECT 1 FROM ORDERDETAIL with (NOLOCK)
                           WHERE ORDERDETAIL.OrderKey = @c_LPOrderKey AND ORDERDETAIL.Status < '3' )
               BEGIN
                  UPDATE ORDERDETAIL WITH (ROWLOCK)
                  SET Status = '3',
                      EditWho = sUser_sName(),
                      EditDate = GETDATE(),
                      TrafficCop = NULL
                  WHERE ORDERDETAIL.OrderKey = @c_LPOrderKey
                    AND ORDERDETAIL.Status < '3'
   
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=22809
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                      + ': Update Failed On Table ORDERDETAIL. (isp_ScanInPickslip) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                  END
               END
            END

            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
               IF  EXISTS ( SELECT 1 from LOADPLANDETAIL with (NOLOCK)
                           WHERE LOADPLANDETAIL.OrderKey = @c_LPOrderKey AND LOADPLANDETAIL.Status < '5' )
               BEGIN
                  UPDATE LOADPLANDETAIL WITH (ROWLOCK)
                  SET Status = '3',
                      EditWho = sUser_sName(),
                      EditDate = GETDATE(),
                      TrafficCop = NULL
                  WHERE LOADPLANDETAIL.OrderKey = @c_LPOrderKey
                    AND LOADPLANDETAIL.Status < '5'
   
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=22801
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                      + ': Update Failed On Table LOADPLANDETAIL. (isp_ScanInPickslip) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
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
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                + ': Retrieve of Right (ScanInLog) Failed (isp_ScanInPickslip) ( '
                                + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END

            IF @c_authority_scaninlog = '1'
            BEGIN
               SET @c_cfgvalue = ''
               SELECT @c_cfgvalue = svalue
               FROM StorerConfig WITH (NOLOCK)
               WHERE Storerkey = @c_StorerKey
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
               END
            END
            -- END SOS#41737

            --MC03 - S
            SET @c_authority_scanin2log = ''
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
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                + ': Retrieve of Right (ScanIn2Log) Failed (isp_ScanInPickslip) ( '
                                + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END

            IF @c_authority_scanin2log = '1'
            BEGIN
               SET @c_cfgvalue = ''
               SELECT @c_cfgvalue = svalue
               FROM StorerConfig WITH (NOLOCK)
               WHERE Storerkey = @c_StorerKey
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
               END
            END
            --MC03 - E

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
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                + ': Retrieve of Right (ScanIn3Log) Failed (isp_ScanInPickslip) ( '
                                + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END

            IF @c_authority_scanin3log = '1'
            BEGIN
               SET @c_cfgvalue = ''
               SELECT @c_cfgvalue = svalue
               FROM StorerConfig WITH (NOLOCK)
               WHERE Storerkey = @c_StorerKey
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
               END
            END
            --(MC04) - E

            --(MC05) - S
            SET @c_authority_scanin4log = ''
            EXECUTE dbo.nspGetRight '',
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'Scanin4Log',   -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_scanin4log OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                + ': Retrieve of Right (Scanin4Log) Failed (isp_ScanInPickslip) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
            END

            IF @c_authority_scanin4log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
               FROM StorerConfig WITH (NOLOCK)
               WHERE Storerkey = @c_StorerKey
               AND Configkey = 'WitronOL'

               IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
               BEGIN
                  SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
               END

               EXEC dbo.ispGenTransmitLog3 'Scanin4Log', @c_LPOrderKey, @c_cfgvalue , @c_StorerKey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
               END
            END

            SET @c_authority_scanin5log = ''
            EXECUTE dbo.nspGetRight '',
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'Scanin5Log',   -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_scanin5log OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                + ': Retrieve of Right (Scanin5Log) Failed (isp_ScanInPickslip) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
            END

            IF @c_authority_scanin5log = '1'
            BEGIN
               SELECT @c_cfgvalue = svalue
               FROM StorerConfig WITH (NOLOCK)
               WHERE Storerkey = @c_StorerKey
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
               END
            END
            --(MC05) - E

            -- (MC02)
            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
               EXECUTE dbo.nspGetRight '',
                        @c_StorerKey,   -- Storer
                        '',             -- Sku
                        'PICKINMAIL',   -- ConfigKey
                        @b_success              OUTPUT,
                        @c_authority_PickInMail OUTPUT,
                        @n_err                  OUTPUT,
                        @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                   + ': Retrieve of Right (PICKINMAIL) Failed (isp_ScanInPickslip) ( '
                                   + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END

               IF @c_authority_PickInMail = '1'
               BEGIN
                  EXEC dbo.ispGenTransmitLog3 'PICKINMAIL', @c_LPOrderKey, '', @c_StorerKey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  END
               END
            END -- IF @n_Continue = 1 OR @n_Continue = 2
            -- (MC02)

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
                     EXEC dbo.ispGenTransmitLog3 'PICKINPROG', @c_LPOrderKey, '', @c_StorerKey, ''
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
            -- (YokeBeen02) END

            IF @b_debug = 1
            BEGIN
               SET @c_step3 = GETDATE() - @c_step3
            END
         END -- Normal Pick Slip

         -- CrossDock PickSlip Zone = 'XD'
         IF @c_PickSlipType = 'XD'
            OR @c_PickSlipType = 'LB'
            OR @c_PickSlipType = 'LP' -- SOS37177 & SOS37178 by Ong 7JUL2005
         BEGIN
            IF @b_debug = 1
            BEGIN
               SET @c_step3 = GETDATE()
            END
            --tlting01
            SET @c_prevorderkey = ''
            
            DECLARE uniqorder_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT DISTINCT OrderKey, ORDERLINENUMBER
               FROM  RefKeyLookup WITH (NOLOCK)
               WHERE PICKSLIPNO = @c_PickSlipNo
               ORDER BY OrderKey, ORDERLINENUMBER -- Added by Shong on 06-Aug-2004

            OPEN uniqorder_cur
            FETCH NEXT FROM uniqorder_cur INTO @c_xdorderkey, @c_orderlinenumber

            WHILE @@FETCH_STATUS = 0
            BEGIN
               SELECT @c_loadkey = Loadkey
               FROM   ORDERDETAIL WITH (NOLOCK)
               WHERE OrderKey = @c_xdorderkey
               AND   OrderLinenumber = @c_orderlinenumber

               -- Added for SOS#41737
               SELECT @c_storerkey = STORERKEY
                    , @c_OrderType = TYPE     --(MC01)
               FROM  ORDERS WITH (NOLOCK)
               WHERE OrderKey = @c_xdorderkey


               IF @c_prevorderkey <> @c_xdorderkey
               BEGIN
                  SELECT @c_prevorderkey = @c_xdorderkey

                  IF @n_Continue = 1 OR @n_Continue = 2
                  BEGIN
                     EXEC dbo.isp_InsertPickDet_Log
                           @cOrderKey = @c_xdorderkey,
                           @cOrderLineNumber='',
                           @n_err=@n_err OUTPUT,
                           @c_errmsg=@c_errmsg OUTPUT,
                           @cPickSlipNo = @c_PickSlipNo
                  END -- (continue =1)

                  IF EXISTS ( SELECT 1 FROM ORDERS with (NOLOCK)
                              WHERE OrderKey = @c_xdorderkey AND Status < '3' )
                  BEGIN
                     UPDATE ORDERS WITH (ROWLOCK)
                     SET Status = '3',
                         EditWho = sUser_sName(),
                         EditDate = GETDATE(),
                         TrafficCop = NULL
                     WHERE OrderKey = @c_xdorderkey
                       AND Status < '3'
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_Continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=22807
                        SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                         + ': Update Failed On Table ORDERS. (isp_ScanInPickslip) ( '
                                         + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                     END
                  END
               END

               -- TLTING01 - Insert Document Tracking Log - for Interface trigger
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK)   
                                  WHERE TableName = 'STSORDERS' AND DocumentNo = @c_xdorderkey AND DocStatus = '3')    
                  BEGIN  
                     EXEC ispGenDocStatusLog 'STSORDERS', @c_storerkey, @c_xdorderkey, '', '', '3'  
                                    , @b_success OUTPUT  
                                    , @n_err OUTPUT  
                                    , @c_errmsg OUTPUT  
                     IF NOT @b_success=1  
                     BEGIN  
                        SELECT @n_continue=3  
                     END      
                  END
               END
               
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  IF EXISTS ( SELECT 1 FROM ORDERDETAIL with (NOLOCK)
                              WHERE OrderKey = @c_xdorderkey
                              AND OrderLinenumber = @c_orderlinenumber AND Status < '3' )
                  BEGIN                              
                     UPDATE ORDERDETAIL WITH (ROWLOCK)
                     SET Status = '3',
                         EditWho = sUser_sName(),
                         EditDate = GETDATE(),
                         TrafficCop = NULL
                     WHERE OrderKey = @c_xdorderkey
                       AND OrderLinenumber = @c_orderlinenumber
                       AND Status < '3'
   
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_Continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=22809
                        SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                         + ': Update Failed On Table ORDERDETAIL. (isp_ScanInPickslip) ( '
                                         + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                     END
                  END
               END

               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  IF (@c_prevloadkey <> @c_loadkey) OR (@c_prevloadorderkey <> @c_xdorderkey)
                  BEGIN
                     SELECT @c_prevloadkey = @c_loadkey
                     SELECT @c_prevloadorderkey = @c_xdorderkey

                     IF EXISTS ( SELECT 1 FROM LOADPLANDETAIL with (NOLOCK)
                                 WHERE LOADKEY = @c_loadkey AND OrderKey = @c_xdorderkey AND Status < '5' )
                     BEGIN            
                        UPDATE LOADPLANDETAIL WITH (ROWLOCK)
                        SET Status = '3',
                            EditWho = sUser_sName(),
                            EditDate = GETDATE(),
                            TrafficCop = NULL
                        WHERE LOADKEY = @c_loadkey
                          AND OrderKey = @c_xdorderkey
                          AND Status < '5'
   
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_Continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=22801
                           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                            + ': Update Failed On Table LOADPLANDETAIL. (isp_ScanInPickslip) ( '
                                            + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                        END
                     END

                     IF @n_Continue = 1 OR @n_Continue = 2
                     BEGIN
                        IF EXISTS ( SELECT 1 FROM LoadPlan with (NOLOCK)
                                    WHERE LOADKEY = @c_loadkey AND Status < '3' )
                        BEGIN            
                           UPDATE LoadPlan WITH (ROWLOCK)
                           SET Status = '3',
                               EditWho = sUser_sName(),
                               EditDate = GETDATE(),
                               TrafficCop = NULL
                           WHERE LOADKEY = @c_loadkey
                             AND Status < '3'
   
                           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                           IF @n_err <> 0
                           BEGIN
                              SELECT @n_Continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=22801
                              SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                               + ': Update Failed On Table LOADPLANDETAIL. (isp_ScanInPickslip) ( '
                                               + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                           END
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
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                   + ': Retrieve of Right (ScanInLog) Failed (isp_ScanInPickslip) ( '
                                   + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END

               IF @c_authority_scaninlog = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                    FROM StorerConfig WITH (NOLOCK)
                   WHERE Storerkey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  -- (MC01) S
                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END
                  -- (MC01) E

                  EXEC dbo.ispGenTransmitLog3 'ScanInLog', @c_xdorderkey, @c_cfgvalue, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  END
               END
               -- END SOS#41737

               --(MC03) - S
               SET @c_authority_scanin2log = ''
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
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                   + ': Retrieve of Right (ScanIn2Log) Failed (isp_ScanInPickslip) ( '
                                   + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END

               IF @c_authority_scanin2log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                    FROM StorerConfig WITH (NOLOCK)
                   WHERE Storerkey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  -- (MC01) S
                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END
                  -- (MC01) E

                  EXEC dbo.ispGenTransmitLog3 'ScanIn2Log', @c_xdorderkey, @c_cfgvalue, @c_StorerKey, ''
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
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                   + ': Retrieve of Right (ScanIn3Log) Failed (isp_ScanInPickslip) ( '
                                   + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END

               IF @c_authority_scanin3log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                    FROM StorerConfig WITH (NOLOCK)
                   WHERE Storerkey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  -- (MC01) S
                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END
                  -- (MC01) E

                  EXEC dbo.ispGenTransmitLog3 'ScanIn3Log', @c_xdorderkey, @c_cfgvalue, @c_StorerKey, ''
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
               EXECUTE dbo.nspGetRight '',
                        @c_StorerKey,   -- Storer
                        '',             -- Sku
                        'Scanin4Log',   -- ConfigKey
                        @b_success              OUTPUT,
                        @c_authority_scanin4log OUTPUT,
                        @n_err                  OUTPUT,
                        @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                   + ': Retrieve of Right (Scanin4Log) Failed (isp_ScanInPickslip) ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
               END

               IF @c_authority_scanin4log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                  FROM StorerConfig WITH (NOLOCK)
                  WHERE Storerkey = @c_StorerKey
                  AND Configkey = 'WitronOL'

                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END

                  EXEC dbo.ispGenTransmitLog3 'Scanin4Log', @c_xdorderkey, @c_cfgvalue , @c_StorerKey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  END
               END

               SET @c_authority_scanin5log = ''
               EXECUTE dbo.nspGetRight '',
                        @c_StorerKey,   -- Storer
                        '',             -- Sku
                        'Scanin5Log',   -- ConfigKey
                        @b_success              OUTPUT,
                        @c_authority_scanin5log OUTPUT,
                        @n_err                  OUTPUT,
                        @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                   + ': Retrieve of Right (Scanin5Log) Failed (isp_ScanInPickslip) ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
               END

               IF @c_authority_scanin5log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                  FROM StorerConfig WITH (NOLOCK)
                  WHERE Storerkey = @c_StorerKey
                  AND Configkey = 'WitronOL'

                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END

                  EXEC dbo.ispGenTransmitLog3 'Scanin5Log', @c_xdorderkey, @c_cfgvalue , @c_StorerKey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  END
               END
               --(MC05) - E

               -- (MC02)
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  EXECUTE dbo.nspGetRight '',
                           @c_StorerKey,   -- Storer
                           '',             -- Sku
                           'PICKINMAIL',   -- ConfigKey
                           @b_success              OUTPUT,
                           @c_authority_PickInMail OUTPUT,
                           @n_err                  OUTPUT,
                           @c_errmsg               OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                      + ': Retrieve of Right (PICKINMAIL) Failed (isp_ScanInPickslip) ( '
                                      + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END

                  IF @c_authority_PickInMail = '1'
                  BEGIN
                     EXEC dbo.ispGenTransmitLog3 'PICKINMAIL', @c_xdorderkey, '', @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_Continue = 3
                     END
                  END
               END -- IF @n_Continue = 1 OR @n_Continue = 2
               -- (MC02)

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
                        EXEC dbo.ispGenTransmitLog3 'PICKINPROG', @c_xdorderkey, '', @c_StorerKey, ''
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
               -- (YokeBeen02) END

               FETCH NEXT FROM uniqorder_cur INTO @c_xdorderkey, @c_orderlinenumber
            END -- END while loop
            CLOSE uniqorder_cur
            DEALLOCATE uniqorder_cur

            IF @b_debug = 1
            BEGIN
               SET @c_step3 = GETDATE() - @c_step3
            END
         END -- crossdock pickslip

         IF @c_PickSlipType <> 'XD' AND @c_PickSlipType <> 'LB' AND @c_PickSlipType <> 'LP' -- SOS37177 & SOS37178 by Ong 7JUL2005
         BEGIN
            IF @b_debug = 1
            BEGIN
               SET @c_step3 = GETDATE()
            END

            IF EXISTS ( SELECT 1 FROM LoadPlan with (NOLOCK)
                        WHERE LoadPlan.LoadKey = @c_Loadkey  AND LoadPlan.Status < '3' )
            BEGIN            
               UPDATE LoadPlan WITH (ROWLOCK)
               SET Status = '3',
                   EditWho = sUser_sName(),
                   EditDate = GETDATE(),
                   TrafficCop = NULL
               FROM  LoadPlan
               WHERE LoadPlan.LoadKey = @c_Loadkey
                 AND LoadPlan.Status < '3'
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=32803
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                   + ': Update Failed On Table LoadPlan. (isp_ScanInPickslip) ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
               END
            END

            IF @b_debug = 1
            BEGIN
               SET @c_step3 = GETDATE() - @c_step3
            END
         END

         -- for watsons's pickslip : zone = 'W'
         -- wally : 23.oct.03
         -- startW
         IF (@n_Continue = 1 OR @n_Continue = 2) AND @c_PickSlipType = 'W'
         BEGIN
            IF @b_debug = 1
            BEGIN
               SET @c_step3 = GETDATE()
            END

            SELECT @c_orderkey = ''

            DECLARE C_PI_PickDetail CURSOR LOCAl FAST_FORWARD READ_ONLY FOR
               SELECT DISTINCT OrderKey
               FROM Pickdetail WITH (NOLOCK)
               WHERE Pickslipno = @c_PickSlipNo
               ORDER BY OrderKey

            OPEN C_PI_PickDetail
            FETCH NEXT FROM C_PI_PickDetail INTO @c_orderkey

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF ISNULL(@c_orderkey, 0) = 0
               BREAK

               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  EXEC dbo.isp_InsertPickDet_Log
                       @cOrderKey = @c_xdorderkey,
                       @cOrderLineNumber='',
                       @n_err=@n_err OUTPUT,
                       @c_errmsg=@c_errmsg OUTPUT,
                       @cPickSlipNo = @c_PickSlipNo

               END -- (continue =1)

               IF EXISTS ( SELECT 1 FROM Orders with (NOLOCK)
                           WHERE OrderKey = @c_orderkey AND Status < '3' )
               BEGIN            
                  UPDATE Orders WITH (ROWLOCK)
                  SET TrafficCop = NULL,
                      EditWho = sUser_sName(),
                      EditDate = GETDATE(),
                      Status = '3'
                  WHERE OrderKey = @c_orderkey
                  SELECT @n_err = @@error
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=32804
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                      + ': Update Failed On Table Orders. (isp_ScanInPickslip) ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                  END
               END

               SELECT @c_storerkey = STORERKEY
                    , @c_OrderType = TYPE     --(MC01)
               FROM  ORDERS WITH (NOLOCK)
               WHERE OrderKey = @c_orderkey

               -- TLTING01 - Insert Document Tracking Log - for Interface trigger
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK)   
                                  WHERE TableName = 'STSORDERS' AND DocumentNo = @c_orderkey AND DocStatus = '3')    
                  BEGIN  
                     EXEC ispGenDocStatusLog 'STSORDERS', @c_StorerKey, @c_orderkey, '', '', '3'  
                                    , @b_success OUTPUT  
                                    , @n_err OUTPUT  
                                    , @c_errmsg OUTPUT  
                     IF NOT @b_success=1  
                     BEGIN  
                        SELECT @n_continue=3  
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
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                   + ': Retrieve of Right (ScanInLog) Failed (isp_ScanInPickslip) ( '
                                   + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END

               IF @c_authority_scaninlog = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                    FROM StorerConfig WITH (NOLOCK)
                   WHERE Storerkey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  -- (MC01) S
                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END
                  -- (MC01) E

                  EXEC dbo.ispGenTransmitLog3 'ScanInLog', @c_orderkey, @c_cfgvalue, @c_StorerKey, ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  END
               END
               -- END SOS#41737

               --(MC03) - S
               SET @c_authority_scanin2log = ''
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
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                   + ': Retrieve of Right (ScanIn2Log) Failed (isp_ScanInPickslip) ( '
                                   + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END

               IF @c_authority_scanin2log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                    FROM StorerConfig WITH (NOLOCK)
                   WHERE Storerkey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  -- (MC01) S
                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END
                  -- (MC01) E

                  EXEC dbo.ispGenTransmitLog3 'ScanIn2Log', @c_orderkey, @c_cfgvalue, @c_StorerKey, ''
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
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                   + ': Retrieve of Right (ScanIn3Log) Failed (isp_ScanInPickslip) ( '
                                   + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END

               IF @c_authority_scanin3log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                    FROM StorerConfig WITH (NOLOCK)
                   WHERE Storerkey = @c_StorerKey
                     AND Configkey = 'WitronOL'

                  -- (MC01) S
                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END
                  -- (MC01) E

                  EXEC dbo.ispGenTransmitLog3 'ScanIn3Log', @c_orderkey, @c_cfgvalue, @c_StorerKey, ''
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
               EXECUTE dbo.nspGetRight '',
                        @c_StorerKey,   -- Storer
                        '',             -- Sku
                        'Scanin4Log',   -- ConfigKey
                        @b_success              OUTPUT,
                        @c_authority_scanin4log OUTPUT,
                        @n_err                  OUTPUT,
                        @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                    + ': Retrieve of Right (Scanin4Log) Failed (isp_ScanInPickslip) ( '
                                    + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
               END

               IF @c_authority_scanin4log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                  FROM StorerConfig WITH (NOLOCK)
                  WHERE Storerkey = @c_StorerKey
                  AND Configkey = 'WitronOL'

                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END

                  EXEC dbo.ispGenTransmitLog3 'Scanin4Log', @c_orderkey, @c_cfgvalue , @c_StorerKey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  END
               END

               SET @c_authority_scanin5log = ''
               EXECUTE dbo.nspGetRight '',
                        @c_StorerKey,   -- Storer
                        '',             -- Sku
                        'Scanin5Log',   -- ConfigKey
                        @b_success              OUTPUT,
                        @c_authority_scanin5log OUTPUT,
                        @n_err                  OUTPUT,
                        @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                    + ': Retrieve of Right (Scanin5Log) Failed (isp_ScanInPickslip) ( '
                                    + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
               END

               IF @c_authority_scanin5log = '1'
               BEGIN
                  SELECT @c_cfgvalue = svalue
                  FROM StorerConfig WITH (NOLOCK)
                  WHERE Storerkey = @c_StorerKey
                  AND Configkey = 'WitronOL'

                  IF ISNULL(RTRIM(@c_cfgvalue), '0') = '0'
                  BEGIN
                     SET @c_cfgvalue = ISNULL(RTRIM(@c_OrderType), '')
                  END

                  EXEC dbo.ispGenTransmitLog3 'Scanin5Log', @c_orderkey, @c_cfgvalue , @c_StorerKey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                  END
               END
               --(MC05) - E

               -- (MC02)
               IF @n_Continue = 1 OR @n_Continue = 2
               BEGIN
                  EXECUTE dbo.nspGetRight '',
                           @c_StorerKey,   -- Storer
                           '',             -- Sku
                           'PICKINMAIL',   -- ConfigKey
                           @b_success              OUTPUT,
                           @c_authority_PickInMail OUTPUT,
                           @n_err                  OUTPUT,
                           @c_errmsg               OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                      + ': Retrieve of Right (PICKINMAIL) Failed (isp_ScanInPickslip) ( '
                                      + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END

                  IF @c_authority_PickInMail = '1'
                  BEGIN
                     EXEC dbo.ispGenTransmitLog3 'PICKINMAIL', @c_orderkey, '', @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_Continue = 3
                     END
                  END
               END -- IF @n_Continue = 1 OR @n_Continue = 2
               -- (MC02)

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
               -- (YokeBeen02) END

               FETCH NEXT FROM C_PI_PickDetail INTO @c_orderkey
            END
            CLOSE C_PI_PickDetail
            DEALLOCATE C_PI_PickDetail

            IF @b_debug = 1
            BEGIN
               SET @c_step3 = GETDATE() - @c_step3
            END
         END
         -- for watsons's pickslip : zone = 'W'
         FETCH NEXT FROM C_PickInfo_Add_01 INTO @c_PickSlipType, @c_LoadKey, @c_LPOrderKey
      END -- while pickslip no
      CLOSE C_PickInfo_Add_01
      DEALLOCATE C_PickInfo_Add_01

      IF @b_debug = 1
      BEGIN
         SET @c_step2 = GETDATE() - @c_step2
      END
   END

   -- Insert PickingInfo detail
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      -- Step 4
      IF @b_debug = 1
      BEGIN
         SET @c_step4 = GETDATE()
      END

      IF EXISTS (SELECT 1 FROM PICKINGINFO WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
      BEGIN
         UPDATE PickingInfo WITH (ROWLOCK)
         SET TrafficCop = NULL
         WHERE  PickSlipNo = @c_PickSlipNo

         SELECT @n_err = @@error
         IF @n_err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=32804
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                             + ': Update Failed On PickingInfo table. (isp_ScanInPickslip) ( '
                             + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
         END

         IF @n_Continue = 1 OR @n_Continue = 2
         BEGIN
            DELETE PickingInfo WITH (ROWLOCK)
            WHERE  PickSlipNo = @c_PickSlipNo

            SELECT @n_err = @@error
            IF @n_err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=32804
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                + ': Delete Failed On PickingInfo table. (isp_ScanInPickslip) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
            END
         END -- Delete

         IF @b_debug = 1
         BEGIN
            PRINT 'Re-scan PickSlip Done !'
         END
      END -- Update

      IF @n_Continue = 1 OR @n_Continue = 2
      BEGIN
         INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, TrafficCop )
         VALUES (@c_PickSlipNo, GETDATE(), @c_PickerID, 'U')

         SELECT @n_err = @@error
         IF @n_err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=32804
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                             + ': Insert Failed On PickingInfo table. (isp_ScanInPickslip) ( '
                             + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
         END

         IF @b_debug = 1
         BEGIN
            PRINT 'Insert PickingInfo ! ' + @c_PickSlipNo
         END
      END

      IF @b_debug = 1
      BEGIN
         SET @c_step4 = GETDATE() - @c_step4
      END
   END -- Insert PickingInfo


   -- Insert Parent PickInfo
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      -- Step 5
      IF @b_debug = 1
      BEGIN
         SET @c_step5 = GETDATE()
      END

      SELECT @c_PickSlipType = ZONE
      FROM   PickHeader WITH (NOLOCK)
      WHERE  PickHeaderKey = @c_PickSlipNo

      IF @c_PickSlipType = '1' AND LEFT(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_PickSlipNo)), 1) = 'C'
      BEGIN
         SELECT @n_maxchildSP = COUNT(C.Pickheaderkey), @c_ParentSP = MAX(C.Consigneekey)
         FROM  PICKHEADER C WITH (NOLOCK)
         JOIN  PICKHEADER P WITH (NOLOCK) ON (C.Consigneekey  = P.Consigneekey)
         WHERE P.Pickheaderkey = @c_PickSlipNo

         SELECT @n_ChildSP = COUNT(PickingInfo.PickSlipNo)
         FROM  PickingInfo WITH (NOLOCK)
         JOIN  PICKHEADER WITH (NOLOCK) ON (PickingInfo.PickslipNo  = PICKHEADER.Pickheaderkey)
         WHERE PICKHEADER.Consigneekey = @c_ParentSP

         IF @n_ChildSP = @n_maxchildSP
         BEGIN -- Create Parent PickInfo
            INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate, TrafficCop)
            VALUES (@c_ParentSP, GETDATE(), @c_PickerID , NULL, 'U')

            SELECT @n_err = @@error
            IF @n_err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=32804
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                + ': Insert Failed On PickingInfo table. (isp_ScanInPickslip) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
            END
         END
      END
      ELSE IF @c_PickSlipType IN ('8', '3')
      BEGIN
         -- Start - Add by June 28.May.03 (SOS11482)
         IF EXISTS (SELECT 1 FROM PICKHEADER WITH (NOLOCK) WHERE Consigneekey = @c_PickSlipNo)
         BEGIN
            INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate, TrafficCop)
            SELECT PickHeaderKey, GETDATE(), @c_PickerID, NULL, 'U'
            FROM   PICKHEADER WITH (NOLOCK)
            WHERE  Consigneekey = @c_PickSlipNo

            SELECT @n_err = @@error
            IF @n_err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=32804
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(dbo.fnc_RTrim(@n_err),0))
                                + ': Insert Failed On PickingInfo table. (isp_ScanInPickslip) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
            END
         END -- END (SOS11482)
      END
   END

   IF @b_debug = 1
   BEGIN
      SET @c_step5 = GETDATE() - @c_step5

      -- (June01) - Start
      -- To turn this on only when need to trace on the performance.
      -- insert into table, TraceInfo for tracing purpose.
      BEGIN TRAN
      SET @c_endtime = GETDATE()
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5) VALUES
                            ('isp_ScanInPickSlip  - PS# = ' + dbo.fnc_RTrim(@c_PickSlipNo)+' Type = '+dbo.fnc_RTrim(@c_PickSlipType)
                            , @c_starttime, @c_endtime
                            , CONVERT(CHAR(12),@c_endtime-@c_starttime ,114)
                            , CONVERT(CHAR(12),@c_step1,114)
                            , CONVERT(CHAR(12),@c_step2,114)
                            , CONVERT(CHAR(12),@c_step3,114)
                            , CONVERT(CHAR(12),@c_step4,114)
                            , CONVERT(CHAR(12),@c_step5,114))
      COMMIT TRAN
      -- (June01) - END
   END

   /* #INCLUDE <TRMBOHU2.SQL> */
   /***** END Add by DLIM *****/
   IF @n_Continue = 3  -- Error Occured - Process AND Return
   BEGIN
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTcnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_ScanInPickslip'
      -- RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- main



GO