SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_ScanOutPickSlip                                */
/* Creation Date: 10.11.2006                                            */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose: Replace isp_ScanOutPickSlip Trigger, use Stored Proc        */
/*          to improve performance.                                     */
/*                                                                      */
/* Called By: nep_n_cst_policy_scanoutpickslip                          */
/*                                                                      */
/* PVCS Version: 3.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.   Purposes                               */
/* 01-Oct-2007  YokeBeen         SOS#83917 - Discrete Pick Ticket &     */
/*                               SOS#84285 - Consolidated Pick Ticket   */
/*                               of USA.                                */
/*                               PickHeader.Zone -> Conso = 'C'         */
/*                                               -> Discrete = 'D'      */
/*                               - (YokeBeen01)                         */
/* 30-Jul-2008  MCTANG    1.1    SOS#110279 - Vital Pack Confirm.       */
/* 18-Nov-2008  Yokebeen  1.1    Fix error with insertion into TraceInfo*/
/*                               - (YokeBeen13)                         */
/* 25-nov-2008  KC        1.2    Incorporate SQL2005 Std - WITH (NOLOCK)*/
/* 03-Mar-2009  James     1.3    SOS130270 - Add Configkey              */
/*                               'DisAllowScanOutPartialPick' to prevent*/
/*                               scanout partially picked order(james01)*/
/* 11-Oct-2010  Leong     1.4    SOS# 224203 - Include ConfigKey        */
/*                                             'PackIsCompulsory' to    */
/*                                             ensure packing is done.  */
/* 25-May-2011  Ung       1.5    SOS216105 Configurable SP to calc      */
/*                               carton, cube and weight                */
/* 11-Nov-2011  SpChin    1.6    SOS230343 - Revised logic for          */
/*                                           SOS# 224203                */
/* 09-Feb-2012  Shong     1.7    Performance Tuning                     */
/* 23-Apr-2012  NJOW01    1.8    241032-Calculation by coefficient      */
/* 27-Spe-2012  MCTang    1.9    252143-Add SCANOUTLOG (MC01)           */
/* 07-Nov-2013  Shong     2.0    Include EditDate When Update           */
/* 19-Aug-2015  Shong01   2.1    Added Backend Pick Confirm             */
/* 10-Nov-2015  TLTING1   2.2    Deadlock Tune                          */
/* 22-Sep-2016  SHONG02   2.3    Only allow backend pack confirm for    */
/*                               ECOM Orders                            */
/* 07-OCT-2016  Wan01     2.3    Fixed missing ELSE & Infinity Loop     */
/* 18-Oct-2016  NJOW02    2.3    Fix order status cater for multi       */
/*                               pickslip order                         */
/* 02-Nov-2016  TLTING0   2.4    Performance Tuning.                    */
/* 09-Jan-2017  Leong     2.4    IN00237542 - Bug Fix.                  */
/* 18-Jul-2017  Shong     2.5    Performance Tuning (SWT01)             */
/* 23-Oct-2017  Shong     2.6    Performance Tuning (SWT02)             */
/* 31-Oct-2017  TLTING02  2.7    Pack Confirm short pick PDet.status=4  */
/* 20-Sep-2018  Wan03     2.8    Fixed due to Orderdetail.loadkey is empty*/
/* 26-Sep-2018  TLTING02  2.9    Performance Tuning                     */
/* 2020-09-04   Wan04     3.0    WMS-15010 - WMS-15010_CN AutoMbol WMS2WCS*/
/*                               trigger rule                           */
/* 27-Apr-2021  LZG       3.1    INC1482668 - Added ISNULL check (ZG01) */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_ScanOutPickSlip]
       @c_PickSlipNo    NVARCHAR(10),
       @n_err           int = 0        OUTPUT,
       @c_errmsg        NVARCHAR(255) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue    int
   , @n_starttcnt          int
   , @b_Success            int
   , @n_cnt                int
   , @c_rfbatchpickenabled NVARCHAR(1)
   , @c_OrderKey           NVARCHAR(10)
   , @c_tablename          NVARCHAR(15)
   , @c_OrderLineNumber    NVARCHAR(5)
   , @c_Storerkey          NVARCHAR(15)
   , @c_authority          NVARCHAR(1)
   , @b_debug              int
   , @c_PickDetailKey      NVARCHAR(18)
   , @c_LoadKey            NVARCHAR(10)
   , @c_PickOrderKey       NVARCHAR(10)
   , @c_WaveKey            NVARCHAR(10)
   , @n_RF_BatchPicking    int
   , @c_TicketType         NVARCHAR(10)
   , @c_NextOrderKey       NVARCHAR(10)
   , @c_loritf             NVARCHAR(1)
   , @c_PickSlipType       NVARCHAR(10)
   , @c_usrstorerkey       NVARCHAR(15)
   , @c_usrfacility        NVARCHAR(5)
   , @cExecStatements      nvarchar(4000)
   , @cStatus              NVARCHAR(1) -- SOS# 224203
   , @cCtnTyp1             NVARCHAR(10)     -- SOS216105
   , @cCtnTyp2             NVARCHAR(10)     -- SOS216105
   , @cCtnTyp3             NVARCHAR(10)     -- SOS216105
   , @cCtnTyp4             NVARCHAR(10)     -- SOS216105
   , @cCtnTyp5             NVARCHAR(10)     -- SOS216105
   , @nCtnCnt1             int             -- SOS216105
   , @nCtnCnt2             int             -- SOS216105
   , @nCtnCnt3             int             -- SOS216105
   , @nCtnCnt4             int             -- SOS216105
   , @nCtnCnt5             int             -- SOS216105
   , @nTotalCube           float           -- SOS216105
   , @nTotalWeight         float           -- SOS216105
   , @cSP_Carton           SYSNAME         -- SOS216105
   , @cSP_Cube             SYSNAME         -- SOS216105
   , @cSP_Weight           SYSNAME         -- SOS216105
   , @cSQL                 NVARCHAR( 4000)  -- SOS216105
   , @cParam               NVARCHAR( 1000)  -- SOS216105
   , @cSValue              NVARCHAR( 10)   -- SOS216105
   , @nPackIsCompulsory    INT             --SOS230343
   , @cChildPickSlipNo     NVARCHAR(10)
   , @n_Coefficient_carton float  --NJOW01
   , @n_Coefficient_cube   float  --NJOW01
   , @n_Coefficient_weight float  --NJOW01
   , @c_BackendPickCfm     NVARCHAR(1) -- SHONG01
   , @c_DocType            NVARCHAR(1)
   , @c_PickDet_Status     NVARCHAR(10) = ''  --SWT02
   , @c_PickDet_ShpFlg     NVARCHAR(1)  = ''  --SWT02
   , @c_Status             NVARCHAR(10) = ''  --SWT02
   , @c_LoadLineNumber     NVARCHAR(5)  = ''  --SWT02
   , @c_EComPack           NCHAR(1) = ''
   , @c_SQLcon             NVARCHAR(1000) = ''
   , @c_SQLcon2            NVARCHAR(1000) = ''

   , @c_AutoMBOLPack       NVARCHAR(30) = '' --Wan04
   , @c_Facility           NVARCHAR(5)  = '' --Wan04
   
   SELECT @b_debug = 0
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   -- (June01) - Start
   -- TraceInfo
   DECLARE    @c_starttime    datetime,
              @c_endtime      datetime,
              @c_step1        datetime,
              @c_step2        datetime,
              @c_step3        datetime,
              @c_step4        datetime,
              @c_step5        datetime
   SET @c_starttime = getdate()
   -- (June01) - End

   IF NOT EXISTS( SELECT 1 FROM PickingInfo AS pi1 WITH (NOLOCK)
                  WHERE pi1.PickSlipNo = @c_PickSlipNo )
   BEGIN
      INSERT INTO PickingInfo
      (
         PickSlipNo,
         ScanInDate,
         PickerID,
         ScanOutDate,
         TrafficCop,
         ArchiveCop,
         AddWho,
         EditWho
      )
      VALUES
      (
         @c_PickSlipNo,
         GETDATE(),
         SUSER_SNAME(),
         NULL,
         'U',
         NULL,
         SUSER_SNAME(),
         GETDATE()
      )
   END

   IF EXISTS( SELECT 1 FROM NSQLCONFIG WITH (NOLOCK) WHERE CONFIGKEY = N'RF_BATCH_PICK' AND NSQLVALUE = '1')
      SELECT @n_RF_BatchPicking = 1
   ELSE
      SELECT @n_RF_BatchPicking = 0

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE C_PkngInfoPickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PICKHEADER.ZONE,
                PICKHEADER.ExternOrderKey,
                ISNULL(PICKHEADER.OrderKey, '')
         FROM   PICKINGINFO WITH (NOLOCK)
         JOIN   PICKHEADER WITH (NOLOCK) ON PickHeaderKey = PICKINGINFO.PickSlipNo
         WHERE  PICKINGINFO.PickSlipNo = @c_PickSlipNo
         ORDER BY PICKINGINFO.PickSlipNo, PICKHEADER.ExternOrderKey, ISNULL(PICKHEADER.OrderKey, '')

      OPEN C_PkngInfoPickSlip

      WHILE 1=1
      BEGIN
         FETCH NEXT FROM C_PkngInfoPickSlip INTO @c_TicketType, @c_LoadKey, @c_OrderKey

         IF @@FETCH_STATUS = -1
            BREAK

         IF @b_debug = 1
         BEGIN
            Print 'Loop 1 - Picking Info, PickSlip No = ' + RTRIM(@c_PickSlipNo)
         END

         -- SOS230343 (Start)
         SET @nPackIsCompulsory = 0
         IF ISNULL(RTRIM(@c_LoadKey),'') <> ''
         BEGIN
            --tlting0
            SELECT @nPackIsCompulsory = 1 FROM StorerConfig S WITH (NOLOCK)
            JOIN ( SELECT TOP 1 O.StorerKey FROM Orders O WITH (NOLOCK)
                   JOIN dbo.LoadPlanDetail LD (NOLOCK) ON LD.OrderKey = O.OrderKey
                   WHERE LD.LoadKey = ISNULL(RTRIM(@c_LoadKey),'') ) AS A ON A.StorerKey = S.StorerKey
            WHERE S.ConfigKey = N'PackIsCompulsory'
            AND S.Svalue = '1'
         END
         ELSE
         BEGIN
            SELECT @nPackIsCompulsory = 1 FROM StorerConfig S WITH (NOLOCK)
              JOIN Orders O WITH (NOLOCK) ON (S.StorerKey = O.StorerKey)
             WHERE O.OrderKey = ISNULL(RTRIM(@c_OrderKey),'')
               AND S.ConfigKey = N'PackIsCompulsory'
               AND S.Svalue = '1'
         END

         IF ISNULL(@nPackIsCompulsory, 0) = 1 --ConfigKey turn on
         BEGIN
            SET @cStatus = ''
            SELECT @cStatus = Status
            FROM PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo

            IF ISNULL(RTRIM(@cStatus),'') = ''
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61791
               SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                               +': Cannot Scan Out PickSlip. Packing Not Done Yet (isp_ScanOutPickSlip). ' + master.dbo.fnc_GetCharASCII(13)
                               + 'OrderKey = ' + ISNULL(LTRIM(RTRIM(@c_OrderKey)),'')
                               + ', LoadKey = ' + ISNULL(LTRIM(RTRIM(@c_LoadKey)),'')
                               + ', PickSlipNo = ' + ISNULL(LTRIM(RTRIM(@c_PickSlipNo)),'')
               GOTO EXIT_SP
            END

            IF ISNULL(RTRIM(@cStatus),'') <> '9'
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61792
               SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                               +': Cannot Scan Out PickSlip. Packing Not Confirm Yet (isp_ScanOutPickSlip). ' + master.dbo.fnc_GetCharASCII(13)
                               + 'OrderKey = ' + ISNULL(LTRIM(RTRIM(@c_OrderKey)),'')
                               + ', LoadKey = ' + ISNULL(LTRIM(RTRIM(@c_LoadKey)),'')
                               + ', PickSlipNo = ' + ISNULL(LTRIM(RTRIM(@c_PickSlipNo)),'')
               GOTO EXIT_SP
            END
         END
         -- SOS230343 (End)

         -- SOS130270 Add Configkey to prevent scan out partially picked orders (james01)
         IF EXISTS (SELECT 1 FROM StorerConfig S WITH (NOLOCK)
            JOIN Orders O WITH (NOLOCK) ON (S.StorerKey = O.StorerKey)
            WHERE O.OrderKey = @c_OrderKey
               AND S.ConfigKey = N'DisAllowScanOutPartialPick'
               AND S.Svalue = '1')
         BEGIN
            IF EXISTS (SELECT 1 FROM PickDetail PD WITH (NOLOCK)
               JOIN Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
               WHERE O.OrderKey = @c_OrderKey
               AND PD.Status = '4'
               AND PD.Qty > 0)
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61781
               SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                               +': Scan out is not allowed if exists partial picked. (isp_ScanOutPickSlip).'
                               + ' OrderKey = ' + ISNULL(LTRIM(RTRIM(@c_OrderKey)),'')
               GOTO EXIT_SP
            END
         END
         -- SOS130270 Add Configkey to prevent scan out partially picked orders (james01)

         IF @c_TicketType NOT IN ('XD','LB','LP')
         BEGIN
            IF ISNULL(RTRIM(@c_OrderKey),'') = ''
            BEGIN
               -- Conso PickSlip - Loop for Order
               SELECT @c_NextOrderKey = SPACE(10)

               DECLARE C_PkngInfonNxtOrdKy CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT LOADPLANDETAIL.OrderKey, ORDERS.StorerKey, ORDERS.DocType
                  FROM   LOADPLANDETAIL WITH (NOLOCK)
                  JOIN   ORDERS WITH (NOLOCK) ON LOADPLANDETAIL.OrderKey = ORDERS.OrderKey
                  WHERE  LOADPLANDETAIL.LoadKey = @c_LoadKey
                  ORDER BY LOADPLANDETAIL.OrderKey
            END
            ELSE
            BEGIN
               DECLARE C_PkngInfonNxtOrdKy CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT ORDERS.OrderKey, ORDERS.StorerKey, ORDERS.DocType
                  FROM   ORDERS WITH (NOLOCK)
                  WHERE  ORDERS.OrderKey = @c_OrderKey
                  ORDER BY ORDERS.OrderKey
            END

            -- Step 1
            SET @c_step1 = GETDATE()

            OPEN C_PkngInfonNxtOrdKy

            FETCH NEXT FROM C_PkngInfonNxtOrdKy INTO @c_NextOrderKey, @c_Storerkey, @c_DocType
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF @b_debug = 1
               BEGIN
                  Print 'Loop 2 - Loadplan Detail, OrderKey = ' + RTRIM(@c_NextOrderKey)                  
               END
                              
               SET @c_BackendPickCfm = '0'
               IF EXISTS(SELECT 1
                         FROM   dbo.StorerConfig  (NOLOCK)
                         WHERE  StorerKey = @c_Storerkey
                         AND    ConfigKey = N'BackendPickConfirm' AND  sValue = '1' )
               BEGIN
                  SET @c_BackendPickCfm = '1'
               END

               -- TLTING02 START
               -- ECOM Packing
               SET @c_EComPack = '0'
               IF EXISTS ( SELECT 1 FROM Packtask (NOLOCK) WHERE Orderkey = @c_NextOrderKey )
               BEGIN
                  SET @c_EComPack = '1'
               END
                

               SELECT @cSQL = '', @cParam = '', @c_SQLcon='', @c_SQLcon2 =''
               SELECT @cSQL = ' SET NOCOUNT ON ' + CHAR(13) +
                              ' DECLARE @c_PickDet_Status NVARCHAR(10) = '''', @c_PickDet_ShpFlg NCHAR(10) = '''' ' + CHAR(13) +
                              ', @c_PickDetailKey NVARCHAR(10) = '''' '+ CHAR(13)

               IF ISNULL(RTRIM(@c_LoadKey),'') <> ''
               BEGIN
                  SET @cSQL = @cSQL + CHAR(13) + 
                            'DECLARE CUR_UPDATE_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' + CHAR(13) +
                              'SELECT PickDetailKey ' + CHAR(13) +
                              'FROM  PICKDETAIL WITH (NOLOCK) ' + CHAR(13) +
                              --'JOIN  ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey AND ' + CHAR(13) +  --(Wan02)
                              --'      ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber) ' + CHAR(13) +                     --(Wan02)
                              'JOIN  ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = PICKDETAIL.OrderKey ) ' + CHAR(13) +              --(Wan02)
                              'WHERE PICKDETAIL.ShipFlag <> ''P'' ' +  CHAR(13) 

                  SET @c_SQLcon = @c_SQLcon + 
                                  'AND   ORDERS.OrderKey = @c_NextOrderKey ' +  CHAR(13) +                                          --(Wan02)
                                  'AND   ORDERS.LoadKey = @c_LoadKey ' +  CHAR(13)                                                  --(Wan02)
               END
               ELSE
               BEGIN
                  SET @cSQL = @cSQL + CHAR(13) +
                              'DECLARE CUR_UPDATE_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' +  CHAR(13) +
                              'SELECT PickDetailKey ' +  CHAR(13) +
                              'FROM  PICKDETAIL WITH (NOLOCK) ' +  CHAR(13) +
                              'WHERE PICKDETAIL.ShipFlag <> ''P'' ' +  CHAR(13) 

                  SET @c_SQLcon = @c_SQLcon + 
                                  'AND PICKDETAIL.OrderKey = @c_NextOrderKey ' +  CHAR(13) 
               END


               IF @c_TicketType = '9' AND @n_RF_BatchPicking = 1 -- IN00237542
               BEGIN
                  SET @c_SQLcon = @c_SQLcon + 
                              'AND   (PICKDETAIL.PickMethod = ''8'' OR PICKDETAIL.PickMethod = '''') ' +  CHAR(13) 
               END
               ELSE
               BEGIN
                  SET @c_SQLcon = @c_SQLcon  
               END

               IF @c_EComPack = '1' 
               BEGIN
                     SET @c_SQLcon = @c_SQLcon + 
                                 'AND   PICKDETAIL.Status < ''5''  ' +  CHAR(13) 

                     SET @c_SQLcon2 = 'IF @c_PickDet_Status < ''5'' AND @c_PickDet_ShpFlg NOT IN (''P'',''Y'') ' +  CHAR(13) 
               END
               ELSE
               BEGIN
                     SET @c_SQLcon = @c_SQLcon + 
                                 'AND   PICKDETAIL.Status < ''4''  ' 

                     SET @c_SQLcon2 = 'IF @c_PickDet_Status < ''4'' AND @c_PickDet_ShpFlg NOT IN (''P'',''Y'') ' +  CHAR(13) 
               END

               SET @cSQL = @cSQL +
                            @c_SQLcon +
                            'OPEN CUR_UPDATE_PICKDETAIL ' +  CHAR(13) +
                            ' FETCH FROM CUR_UPDATE_PICKDETAIL INTO @c_PickDetailKey ' +  CHAR(13) +
                            'WHILE @@FETCH_STATUS = 0 ' +  CHAR(13) +
                            'BEGIN ' +  CHAR(13) +
                            'SET @c_PickDet_Status = '''' ' +  CHAR(13) +
                            'SET @c_PickDet_ShpFlg = '''' ' +  CHAR(13) +
                            'SELECT @c_PickDet_Status = [Status], @c_PickDet_ShpFlg = ShipFlag ' +  CHAR(13) +
                            'FROM PICKDETAIL WITH(NOLOCK) ' +  CHAR(13) +
                            'WHERE PickDetailKey = @c_PickDetailKey ' +  CHAR(13) +
                            '' +  CHAR(13) +
                            @c_SQLcon2  +
                            'BEGIN ' +  CHAR(13) +
                            '  IF @c_BackendPickCfm = ''1'' AND @c_DocType = ''E'' ' +  CHAR(13) +
                            '  BEGIN ' +  CHAR(13) +                  
                            '     UPDATE PICKDETAIL  ' +  CHAR(13) +
                            '     SET ShipFlag = ''P'', EditDate = GETDATE(), EditWho = SUSER_SNAME() ' +  CHAR(13) +
                            '     WHERE PickDetailKey = @c_PickDetailKey ' +  CHAR(13) +
                            '  END ' +  CHAR(13) +
                            '  ELSE ' +  CHAR(13) +
                            '  BEGIN ' +  CHAR(13) +
                            '     UPDATE PICKDETAIL  ' +  CHAR(13) +
                            '     SET Status = ''5'', EditDate = GETDATE(), EditWho = SUSER_SNAME() ' +  CHAR(13) +
                            '     WHERE PickDetailKey = @c_PickDetailKey ' +  CHAR(13) +
                            '  END ' +  CHAR(13) +             
                            'END ' +  CHAR(13) +
                            ' SELECT @n_err = @@ERROR  ' +  CHAR(13) +
                            ' IF @n_err <> 0 ' +  CHAR(13) +
                            ' BEGIN ' +  CHAR(13) +
                            '    SELECT @n_err = 61790 ' +  CHAR(13) +
                            '    SELECT @c_errmsg=''NSQL61790: Update Failed On Table PICKDETAIL. (isp_ScanOutPickSlip)'' ' + CHAR(13) +
                            '    Break ' +  CHAR(13) +
                            ' END ' +  CHAR(13) +
                            '   FETCH FROM CUR_UPDATE_PICKDETAIL INTO @c_PickDetailKey ' +  CHAR(13) +
                            'END ' +  CHAR(13) +
                            'CLOSE CUR_UPDATE_PICKDETAIL ' +  CHAR(13) +
                            'DEALLOCATE CUR_UPDATE_PICKDETAIL ' 

               IF @b_debug = 1
               BEGIN
                  Print 'SQL = ' +  CHAR(13) + RTRIM(@cSQL)
               END

               SET @cParam = '@c_NextOrderKey NVARCHAR(10), @c_LoadKey Nvarchar(10), @c_BackendPickCfm Nchar(1), @c_DocType Nchar(1), ' +
                              '@n_err INT, @c_errmsg NVARCHAR(255) ' 
               EXEC sp_executesql @cSQL, @cParam, @c_NextOrderKey, @c_LoadKey, @c_BackendPickCfm, @c_DocType, @n_err, @c_errmsg
               IF ISNULL(@n_err, 0) <> 0     -- ZG01
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 61790
                  SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTrim(@n_err),0))
                                    +': Update Failed On Table PICKDETAIL. (isp_ScanOutPickSlip)' + ' ( '
                                    + ' SQLSvr MESSAGE=' + ISNULL(LTrim(RTrim(@c_errmsg)),'') + ' ) '
                  GOTO EXIT_SP
               END
                
               IF @c_BackendPickCfm = '1'
               BEGIN
                  EXEC dbo.isp_ConfirmPick
                        @c_OrderKey   = @c_NextOrderKey
                        , @c_LoadKey  = @c_LoadKey
                        , @b_Success  = @b_Success OUTPUT
                        , @n_err      = @n_err     OUTPUT
                        , @c_errmsg   = @c_errmsg  OUTPUT
                  
                  GOTO SKIP_ORDER_UPDATE 
               END

               SET @c_step3 = GETDATE() - @c_step3

               IF @n_continue = 1 OR @n_continue = 2
               BEGIN
                  IF EXISTS(SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @c_NextOrderKey) AND
                  NOT EXISTS(SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @c_NextOrderKey AND Status < '5')
                  BEGIN
                     -- SWT02
                     SET @c_Status = ''                     
                     SELECT @c_Status = o.[Status]
                     FROM ORDERS AS o WITH(NOLOCK)
                     WHERE o.OrderKey = @c_NextOrderKey
                     
                     IF @c_Status < '5' AND @c_Status <> ''
                     BEGIN
                        UPDATE ORDERS 
                           SET Status = '5',
                               EditDate = GetDate(),
                               EditWho  = sUser_sName()
                        WHERE  OrderKey = @c_NextOrderKey
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @n_err = 61782
                           SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))
                                             +': Update Failed On Table ORDERS. (isp_ScanOutPickSlip)' + ' ( '
                                             + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                           GOTO EXIT_SP
                        END                        
                     END
                  END
               END -- IF @n_continue = 1 OR @n_continue = 2

               IF @n_continue = 1 OR @n_continue = 2
               BEGIN
                  -- SWT02
                  DECLARE CUR_ORDER_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT OrderLineNumber
                  FROM ORDERDETAIL WITH (NOLOCK)
                  WHERE OrderKey = @c_NextOrderKey 
                  AND   [Status] < '5'
      
                  OPEN CUR_ORDER_LINES
      
                  FETCH FROM CUR_ORDER_LINES INTO @c_OrderLineNumber
      
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     UPDATE ORDERDETAIL      
                        SET [Status] = '5', EditDate = GETDATE(), EditWho=sUser_sName(), TrafficCop = NULL     
                     WHERE OrderKey = @c_NextOrderKey   
                     AND   OrderLineNumber = @c_OrderLineNumber
         
                     IF @@ERROR <> 0    
                     BEGIN    
                        SELECT @n_continue = 3
                        SELECT @n_err = 61783
                        SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))
                                          +': Update Failed On Table ORDERDETAIL. (isp_ScanOutPickSlip)' + ' ( '
                                          + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                        GOTO EXIT_SP      
                     END    
      
                     FETCH FROM CUR_ORDER_LINES INTO @c_OrderLineNumber
                  END      
                  CLOSE CUR_ORDER_LINES
                  DEALLOCATE CUR_ORDER_LINES             
                           
              
               END

               SKIP_ORDER_UPDATE:
               IF @n_continue = 1 OR @n_continue = 2
               BEGIN
                  IF ISNULL(RTRIM(@c_LoadKey),'') <> ''
                  BEGIN
                     -- SWT02
                     SET @c_LoadLineNumber = ''
                     
                     SELECT @c_LoadLineNumber = LoadLineNumber
                     FROM LOADPLANDETAIL WITH (NOLOCK) 
                     WHERE Loadkey = @c_LoadKey
                     AND OrderKey = @c_NextOrderKey
                     AND STATUS < '5' 
                     
                     IF @c_LoadLineNumber <> ''
                     BEGIN
                        UPDATE LOADPLANDETAIL 
                           SET STATUS = '5',
                                 EditDate = GetDate(),
                                 EditWho   = sUser_sName(),
                                 TrafficCop = null
                        WHERE Loadkey  = @c_LoadKey
                          AND LoadLineNumber = @c_LoadLineNumber

                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @n_err = 61784
                           SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))
                                             +': Update Failed On Table LOADPLANDETAIL. (isp_ScanOutPickSlip)'
                                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                           GOTO EXIT_SP
                        END
                     END
                  END
               END

               IF @c_TicketType IN ('8','7','9') -- SWT02
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.StorerConfig with (NOLOCK) WHERE Storerkey = @c_Storerkey
                             AND Configkey = N'ULVITF'  AND  sValue = '1' )
                  BEGIN
                     IF NOT EXISTS (SELECT 1 FROM dbo.StorerConfig (NOLOCK)
                                    WHERE StorerKey = @c_Storerkey AND Configkey = N'ULVPODITF'  AND  sValue = '1' )
                     BEGIN
                        SELECT @c_tablename = CASE TYPE WHEN 'WT' THEN 'ULVNSO'
                                                        WHEN 'W'  THEN 'ULVHOL'
                                                        WHEN 'WC' THEN 'ULVINVTRF'
                                                        WHEN 'WD' THEN 'ULVDAMWD'
                                                        ELSE 'ULVPCF'
                                              END
                        FROM ORDERS WITH (NOLOCK)
                        WHERE ORDERKEY = @c_NextOrderKey

                        SELECT @c_OrderLineNumber = ''

                        DECLARE C_PkngInfOrdLnNr CURSOR LOCAL FAST_FORWARD READ_ONLY
                           FOR   SELECT ORDERDETAIL.Orderlinenumber
                           FROM  ORDERDETAIL WITH (NOLOCK)
                           WHERE Orderkey = @c_NextOrderKey
                           AND   Status = '5'
                           ORDER BY ORDERDETAIL.Orderlinenumber

                        OPEN C_PkngInfOrdLnNr

                        WHILE (1 = 1) AND (@n_continue = 1 OR @n_continue = 2)
                        BEGIN
                           FETCH NEXT FROM C_PkngInfOrdLnNr INTO @c_OrderLineNumber

                           IF @@FETCH_STATUS = -1
                              BREAK

                           EXEC dbo.ispGenTransmitLog2  @c_Tablename, @c_NextOrderKey, @c_OrderLineNumber, @c_Storerkey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

                           IF NOT @b_success = 1
                           BEGIN
                              SELECT @n_continue=3
                              GOTO EXIT_SP
                           END
                        END -- While Loop Order Line
                        CLOSE C_PkngInfOrdLnNr
                        DEALLOCATE C_PkngInfOrdLnNr
                     END -- ULVPODITF turn on
                  END -- if ULVITF Turn on
               END -- IF @c_TicketType = '8' OR @c_TicketType = '7'

               IF EXISTS( SELECT 1 FROM StorerConfig (NOLOCK) WHERE Storerkey = @c_Storerkey
                          AND Configkey = N'PICKLOG'  AND  sValue = '1' )
               BEGIN
                  EXEC dbo.ispGenTransmitLog 'PICK', @c_NextOrderKey, '', @c_PickSlipNo, ''
                     , @b_success OUTPUT
                     , @n_err     OUTPUT
                     , @c_errmsg  OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61785
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                     +': Insert Into TransmitLog Table (PICK) Failed (isp_ScanOutPickSlip)' + ' ( '
                                     + ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                     GOTO EXIT_SP
                  END
               END -- Interface ConfigKey 'PICKLOG'

               IF EXISTS( SELECT 1 FROM StorerConfig (NOLOCK) WHERE Storerkey = @c_Storerkey
                          AND Configkey = N'CDSORD'  AND  sValue = '1'  )
               BEGIN
                  EXEC dbo.ispGenTransmitLog 'CDSORD', @c_NextOrderKey, '', '', ''
                     , @b_success OUTPUT
                     , @n_err     OUTPUT
                     , @c_errmsg  OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61786
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                     +': Insert Into TransmitLog Table (CDSORD) Failed (isp_ScanOutPickSlip)' + ' ( '
                                     + ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                     GOTO EXIT_SP
                  END
               END -- Interface ConfigKey 'CDSORD'

               IF EXISTS( SELECT 1 FROM StorerConfig (NOLOCK) WHERE Storerkey = @c_Storerkey
                          AND Configkey = N'LORITF'  AND  sValue = '1'  )
               BEGIN
                  EXEC dbo.ispGenTransmitLog 'LORPICK', @c_NextOrderKey, '', '', ''
                     , @b_success OUTPUT
                     , @n_err     OUTPUT
                     , @c_errmsg  OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61787
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                     +': Insert Into TransmitLog Table (LORPICK) Failed (isp_ScanOutPickSlip)' + ' ( '
                                     + ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                     GOTO EXIT_SP
                  END
               END -- Interface ConfigKey 'LORITF'

               -- Added by MCTANG on 30-Jul-2008 (SOS#110279 - Vital Pack Confirm) - Start
               IF EXISTS( SELECT 1 FROM StorerConfig (NOLOCK) WHERE Storerkey = @c_Storerkey
                          AND Configkey = N'VPACKLOG'  AND  sValue = '1'  )
               BEGIN
                  EXEC dbo.ispGenVitalLog 'VPACKLOG', @c_NextOrderKey, '', @c_Storerkey, ''
                     , @b_success OUTPUT
                     , @n_err     OUTPUT
                     , @c_errmsg  OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61788
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                     +': Insert Into TransmitLog Table (VPACKLOG) Failed (isp_ScanOutPickSlip)' + ' ( '
                                     + ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                     GOTO EXIT_SP
                  END
               END -- Interface ConfigKey 'VPACKLOG'
               -- Added by MCTANG on 30-Jul-2008 (SOS#110279 - Vital Pack Confirm) - End

               -- (MC01) - S
               IF EXISTS( SELECT 1 FROM StorerConfig (NOLOCK) WHERE Storerkey = @c_Storerkey
                          AND Configkey = N'SCANOUTLOG'  AND  sValue = '1'  )
               BEGIN

                  EXEC dbo.ispGenTransmitLog3 'SCANOUTLOG', @c_NextOrderKey, '', @c_Storerkey, ''
                     , @b_success OUTPUT
                     , @n_err     OUTPUT
                     , @c_errmsg  OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61788
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                                     +': Insert Into TransmitLog3 Table (SCANOUTLOG) Failed (isp_ScanOutPickSlip)' + ' ( '
                                     + ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                     GOTO EXIT_SP
                  END
               END -- Interface ConfigKey 'SCANOUTLOG'
               -- (MC01) - E

               FETCH NEXT FROM C_PkngInfonNxtOrdKy INTO @c_NextOrderKey, @c_Storerkey, @c_DocType
            END -- While loop Order Key
            CLOSE C_PkngInfonNxtOrdKy
            DEALLOCATE C_PkngInfonNxtOrdKy

            SET @c_step1 = GETDATE() - @c_step1

            --- End Order Key Loop ---------------------------------------------------------------------

         END -- IF @c_TicketType <> 'XD' AND @c_TicketType <> 'LB'
         ELSE
         BEGIN          
            SET @c_step1 = GETDATE()
            
            IF @c_TicketType IN ('XD','LB','LP')
            BEGIN
               SELECT @c_PickDetailKey = SPACE(18)

               DECLARE C_PkngInfPckDtlKy CURSOR LOCAL FAST_FORWARD READ_ONLY
                  FOR  SELECT RefKeyLookup.PickDetailKey
                  FROM  RefKeyLookup WITH (NOLOCK)
                  WHERE PickslipNo = @c_PickSlipNo
                  ORDER BY RefKeyLookup.PickDetailKey

               OPEN C_PkngInfPckDtlKy
               FETCH NEXT FROM C_PkngInfPckDtlKy INTO @c_PickDetailKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  SET @c_PickDet_Status = '5'
                  
                  SELECT @c_PickDet_Status = p.[Status]
                  FROM PICKDETAIL AS p WITH(NOLOCK)
                  WHERE p.PickDetailKey = @c_PickDetailKey
                  
                  IF @c_PickDet_Status < '4'
                  BEGIN
                     UPDATE PICKDETAIL  
                        SET STATUS = '5', EditDate = GETDATE(), EditWho = SUSER_SNAME()
                     WHERE  PickDetailKey = @c_PickDetailKey
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 61789
                        SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))
                                          +': Update Failed On Table PICKDETAIL. (isp_ScanOutPickSlip)' + ' ( '
                                          + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                        GOTO EXIT_SP
                     END                     
                  END                    

                  FETCH NEXT FROM C_PkngInfPckDtlKy INTO @c_PickDetailKey
               END -- WHILE pickdetail
               CLOSE C_PkngInfPckDtlKy
               DEALLOCATE C_PkngInfPckDtlKy


               IF @n_continue = 1 OR @n_continue = 2
               BEGIN
                  --NJOW02
                  DECLARE cur_Orders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT Orderkey
                     FROM ( SELECT DISTINCT PICKDETAIL.Orderkey
                            FROM PICKDETAIL (NOLOCK)
                            JOIN RefKeyLookup WITH (NOLOCK) ON RefKeyLookup.PickDetailKey = PickDetail.PickDetailKey
                            WHERE RefKeyLookup.PickslipNo = @c_PickSlipNo
                            AND   PickDetail.Status = '5' ) AS A
                     WHERE NOT EXISTS (SELECT 1 FROM PICKDETAIL PD (NOLOCK) WHERE PD.Orderkey = A.Orderkey AND PD.Status < '5')
                     ORDER BY Orderkey

                  OPEN cur_Orders

                  FETCH NEXT FROM cur_Orders INTO @c_NextOrderKey

                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     SET @c_Status = '5'
                     
                     SELECT @c_Status = [Status]
                     FROM ORDERS AS o WITH(NOLOCK)
                     WHERE o.OrderKey = @c_NextOrderKey
                     IF @c_Status < '5'
                     BEGIN
                        UPDATE Orders  
                           SET Status = '5', EditDate = GetDate(),
                        EditWho  = sUser_sName(), Trafficcop = NULL
                        WHERE Orderkey = @c_NextOrderKey

                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @n_err = 61790
                           SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(dbo.fnc_RTrim(@n_err),0))
                                           +': Update Failed On Table ORDERS. (isp_ScanOutPickSlip)' + ' ( '
                                           + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '
                           GOTO EXIT_SP
                        END                        
                     END
                     FETCH NEXT FROM cur_Orders INTO @c_NextOrderKey
                  END
                  CLOSE cur_Orders
                  DEALLOCATE cur_Orders
               END
            END -- @c_TicketType = 'XD' OR @c_TicketType = 'LB'
            SET @c_step1 = GETDATE() - @c_step1
         END

         -- SOS216105 start. Configurable SP to calc carton, cube and weight
         -- Update for non-packing picklist. Packing picklist is updated at ntrPackHeaderUpdate
         SET @c_step2 = GETDATE()
         IF NOT EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
         BEGIN
            SET @cSValue = ''

            SELECT @cSValue = SValue
            FROM StorerConfig WITH (NOLOCK)
            WHERE StorerKey = @c_Storerkey AND ConfigKey = N'CMSNoPackingFormula'

            IF @cSValue <> '' AND @cSValue IS NOT NULL
            BEGIN
               SET @cCtnTyp1 = ''
               SET @cCtnTyp2 = ''
               SET @cCtnTyp3 = ''
               SET @cCtnTyp4 = ''
               SET @cCtnTyp5 = ''
               SET @nCtnCnt1 = 0
               SET @nCtnCnt2 = 0
               SET @nCtnCnt3 = 0
               SET @nCtnCnt4 = 0
               SET @nCtnCnt5 = 0
               SET @nTotalCube = 0
               SET @nTotalWeight = 0

               -- Get customize stored procedure
               SELECT
                  @cSP_Carton = Long,
                  @cSP_Cube = Notes,
                  @cSP_Weight = Notes2,
                  @n_Coefficient_carton = CASE WHEN ISNUMERIC(UDF01) = 1 THEN
                                              CONVERT(float,UDF01) ELSE 1 END,  --NJOW01
                  @n_Coefficient_cube = CASE WHEN ISNUMERIC(UDF02) = 1 THEN
                                               CONVERT(float,UDF02) ELSE 1 END,  --NJOW01
                  @n_Coefficient_weight = CASE WHEN ISNUMERIC(UDF03) = 1 THEN
                                               CONVERT(float,UDF03) ELSE 1 END  --NJOW01
               FROM CodeLkup WITH (NOLOCK)
               WHERE ListName = N'CMSStrateg'
                  AND Code = @cSValue

               -- Run carton SP
               SET @n_err = 0
               IF OBJECT_ID( @cSP_Carton, 'P') IS NOT NULL
               BEGIN
                  SET @cSQL = 'EXEC ' + @cSP_Carton + ' @cPickSlipNo, @cOrderKey, ' +
                     '@cCtnTyp1 OUTPUT, @cCtnTyp2 OUTPUT, @cCtnTyp3 OUTPUT, @cCtnTyp4 OUTPUT, @cCtnTyp5 OUTPUT, ' +
                     '@nCtnCnt1 OUTPUT, @nCtnCnt2 OUTPUT, @nCtnCnt3 OUTPUT, @nCtnCnt4 OUTPUT, @nCtnCnt5 OUTPUT'
                  SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), ' +
                     '@cCtnTyp1 NVARCHAR( 10) OUTPUT, @cCtnTyp2 NVARCHAR( 10) OUTPUT, @cCtnTyp3 NVARCHAR( 10) OUTPUT, @cCtnTyp4 NVARCHAR( 10) OUTPUT, @cCtnTyp5 NVARCHAR( 10) OUTPUT, ' +
                     '@nCtnCnt1 INT OUTPUT, @nCtnCnt2 INT OUTPUT, @nCtnCnt3 INT OUTPUT, @nCtnCnt4 INT OUTPUT, @nCtnCnt5 INT OUTPUT'
                  EXEC sp_executesql @cSQL, @cParam, @c_PickSlipNo, @c_OrderKey,
                     @cCtnTyp1 OUTPUT, @cCtnTyp2 OUTPUT, @cCtnTyp3 OUTPUT, @cCtnTyp4 OUTPUT, @cCtnTyp5 OUTPUT,
                     @nCtnCnt1 OUTPUT, @nCtnCnt2 OUTPUT, @nCtnCnt3 OUTPUT, @nCtnCnt4 OUTPUT, @nCtnCnt5 OUTPUT
                  SET @n_err = @@ERROR

                  --NJOW01
                  SET @nCtnCnt1 = CONVERT(int, ISNULL(@nCtnCnt1,0) * @n_Coefficient_carton)
                  SET @nCtnCnt2 = CONVERT(int, ISNULL(@nCtnCnt2,0) * @n_Coefficient_carton)
                  SET @nCtnCnt3 = CONVERT(int, ISNULL(@nCtnCnt3,0) * @n_Coefficient_carton)
                  SET @nCtnCnt4 = CONVERT(int, ISNULL(@nCtnCnt4,0) * @n_Coefficient_carton)
                  SET @nCtnCnt5 = CONVERT(int, ISNULL(@nCtnCnt5,0) * @n_Coefficient_carton)
               END

               -- Run cube SP
               IF @n_err = 0 AND OBJECT_ID( @cSP_Cube, 'P') IS NOT NULL
               BEGIN
                  SET @cSQL = 'EXEC ' + @cSP_Cube + ' @cPickSlipNo, @cOrderKey, @nTotalCube OUTPUT, @nCurrentTotalCube, @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5'
                  SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), @nTotalCube FLOAT OUTPUT, @nCurrentTotalCube FLOAT, @nCtnCnt1 INT, @nCtnCnt2 INT, @nCtnCnt3 INT, @nCtnCnt4 INT, @nCtnCnt5 INT'
                  EXEC sp_executesql @cSQL, @cParam, @c_PickSlipNo, @c_OrderKey, @nTotalCube OUTPUT, NULL, @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5
                  SET @n_err = @@ERROR

                  --NJOW01
                  SET @nTotalCube = ISNULL(@nTotalCube,0) * @n_Coefficient_cube
               END

               -- Run weight SP
               IF @n_err = 0 AND OBJECT_ID( @cSP_Weight, 'P') IS NOT NULL
               BEGIN
                  SET @cSQL = 'EXEC ' + @cSP_Weight + ' @cPickSlipNo, @cOrderKey, @nTotalWeight OUTPUT'
                  SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), @nTotalWeight FLOAT OUTPUT'
                  EXEC sp_executesql @cSQL, @cParam, @c_PickSlipNo, @c_OrderKey, @nTotalWeight OUTPUT
                  SET @n_err = @@ERROR

                  --NJOW01
                  SET @nTotalWeight = ISNULL(@nTotalWeight,0) * @n_Coefficient_weight
               END

               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Failed exec customize stored procedure. (ntrPickingInfoUpdate)' + LTRIM(RTRIM(@c_errmsg))
                  GOTO EXIT_SP
               END

               -- If conso pick list, update LoadPlan
               IF @c_OrderKey = ''
               BEGIN
                  UPDATE LOADPLAN 
                  SET
                     CtnTyp1 = @cCtnTyp1,
                     CtnTyp2 = @cCtnTyp2,
                     CtnTyp3 = @cCtnTyp3,
                     CtnTyp4 = @cCtnTyp4,
                     CtnTyp5 = @cCtnTyp5,
                     CtnCnt1 = @nCtnCnt1,
                     CtnCnt2 = @nCtnCnt2,
                     CtnCnt3 = @nCtnCnt3,
                     CtnCnt4 = @nCtnCnt4,
                     CtnCnt5 = @nCtnCnt5,
                     TotCtnWeight = @nTotalWeight,
                     TotCtnCube   = @nTotalCube,
                     EditDate = GETDATE(), EditWho = SUSER_SNAME()
                  FROM LoadPlan
                  WHERE LoadKey = @c_LoadKey
                  IF @@ERROR <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Failed update loadplan. (ntrPickingInfoUpdate)' + LTRIM(RTRIM(@c_errmsg))
                     GOTO EXIT_SP
                  END
               END

               -- If discrete pick list, update MBOLDetail (due to populated MBOL, then pick confirm later)
               IF @c_OrderKey <> ''
               BEGIN
                  -- Update carton type, count if user not key-in own value
                  IF EXISTS ( SELECT 1 FROM MBOLDetail (NOLOCK) WHERE OrderKey = @c_OrderKey
                              AND CtnCnt1 = 0 AND CtnCnt2 = 0 AND CtnCnt3 = 0 AND CtnCnt4 = 0
                              AND CtnCnt5 = 0 AND TotalCartons = 0  )
                  AND (@nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5) > 0
                  BEGIN
                     UPDATE MBOLDetail SET
                        CtnCnt1 = @nCtnCnt1,
                        CtnCnt2 = @nCtnCnt2,
                        CtnCnt3 = @nCtnCnt3,
                        CtnCnt4 = @nCtnCnt4,
                        CtnCnt5 = @nCtnCnt5,
                        TotalCartons = @nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5,
                        EditDate = GETDATE(), EditWho = SUSER_SNAME()
                     WHERE OrderKey = @c_OrderKey
                        AND CtnCnt1 = 0
                        AND CtnCnt2 = 0
                        AND CtnCnt3 = 0
                        AND CtnCnt4 = 0
                        AND CtnCnt5 = 0
                        AND TotalCartons = 0
                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Failed update MBOLDetail. (ntrPickingInfoUpdate)' + LTRIM(RTRIM(@c_errmsg))
                        GOTO EXIT_SP
                     END
                  END

                  -- Update cube if user not key-in own value
                  IF EXISTS ( SELECT 1 from  MBOLDetail (NOLOCK) WHERE OrderKey = @c_OrderKey AND Cube = 0 )
                  AND @nTotalCube > 0
                  BEGIN
                     UPDATE MBOLDetail SET Cube = @nTotalCube, EditDate = GETDATE(), EditWho = SUSER_SNAME()
                     WHERE OrderKey = @c_OrderKey AND Cube = 0
                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Failed update MBOLDetail. (ntrPickingInfoUpdate)' + LTRIM(RTRIM(@c_errmsg))
                        GOTO EXIT_SP
                     END
                  END

                  IF EXISTS ( SELECT 1 FROM MBOLDetail (NOLOCK) WHERE OrderKey = @c_OrderKey AND Weight = 0   )
                  AND @nTotalWeight > 0
                  BEGIN 
                     -- Update weight if user not key-in own value
                     UPDATE MBOLDetail SET Weight = @nTotalWeight, EditDate = GETDATE(), EditWho = SUSER_SNAME()
                     WHERE OrderKey = @c_OrderKey AND Weight = 0
                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Failed update MBOLDetail. (ntrPickingInfoUpdate)' + LTRIM(RTRIM(@c_errmsg))
                        GOTO EXIT_SP
                     END
                  END
               END
               -- SOS216105 end. Configurable SP to calc carton, cube and weight
            END
         END
         SET @c_step2 = GETDATE() - @c_step2
      END -- while loop picking info
      CLOSE C_PkngInfoPickSlip
      DEALLOCATE C_PkngInfoPickSlip
   END -- @n_continue = 1 OR @n_continue = 2

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_step3 = GETDATE()  
      UPDATE PickingInfo  
      SET    ScanOutDate = GETDATE(),
             TrafficCop = 'U'
      WHERE  PickSlipNo  = @c_pickslipno

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 61790
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTRIM(@n_err),0))
                         +': Update Failed On Table PICKINGINFO. (isp_ScanOutPickSlip)' + ' ( '
                         + ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
         GOTO EXIT_SP
      END
      SET @c_step3 = GETDATE() - @c_step3
   END -- @n_continue = 1 OR @n_continue = 2
   
   --(Wan04) - START
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_Orderkey = PH.Orderkey
            ,@c_Loadkey  = PH.Loadkey
            ,@c_Storerkey= PH.Storerkey
      FROM PACKHEADER PH WITH (NOLOCK) 
      WHERE PH.PickSlipNo = @c_PickslipNo
      
      IF @c_Orderkey <> ''
      BEGIN 
         SELECT @c_Facility = OH.Facility
         FROM ORDERS OH WITH (NOLOCK)
         WHERE OH.Orderkey = @c_Orderkey
      END
      ELSE
      BEGIN
         SELECT @c_Facility = LP.Facility
         FROM LOADPLAN LP WITH (NOLOCK)
         WHERE LP.Loadkey = @c_Loadkey
      END

      EXEC nspGetRight
            @c_Facility   = @c_Facility  
         ,  @c_StorerKey  = @c_StorerKey 
         ,  @c_sku        = ''       
         ,  @c_ConfigKey  = 'AutoMBOLPack' 
         ,  @b_Success    = @b_Success             OUTPUT
         ,  @c_authority  = @c_AutoMBOLPack        OUTPUT 
         ,  @n_err        = @n_err                 OUTPUT
         ,  @c_errmsg     = @c_errmsg              OUTPUT

      IF @b_Success = 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 61795   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_ScanOutPickSlip)'   
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
         GOTO EXIT_SP  
      END

      IF @c_AutoMBOLPack = '1'
      BEGIN
         EXEC dbo.isp_QCmd_SubmitAutoMbolPack
           @c_PickSlipNo= @c_PickSlipNo
         , @b_Success   = @b_Success    OUTPUT    
         , @n_Err       = @n_Err        OUTPUT    
         , @c_ErrMsg    = @c_ErrMsg     OUTPUT 
         
         IF @b_Success = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 61796   
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_QCmd_SubmitAutoMbolPack. (isp_ScanOutPickSlip)'   
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
            GOTO EXIT_SP  
         END   
      END
   END
   --(Wan04) - END
   EXIT_SP:
   -- To turn this on only when need to trace on the performance.
   -- insert into table, TraceInfo for tracing purpose.

   --IF @b_debug = 1
   --BEGIN
   --   IF @n_continue = 1 OR @n_continue = 2
   --   BEGIN
   --      SET @c_endtime = GETDATE()
   --      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1,
   --                  Col2, Col3, Col4, Col5) -- (YokeBeen13)
   --      VALUES ( 'isp_ScanOutPickSlip'
   --             , @c_starttime
   --             , @c_endtime
   --             , CONVERT(CHAR(12),@c_endtime-@c_starttime ,114)
   --             , ISNULL(CONVERT(CHAR(12),@c_step1,114), '00:00:00:000')
   --             , ISNULL(CONVERT(CHAR(12),@c_step2,114), '00:00:00:000')
   --             , ISNULL(CONVERT(CHAR(12),@c_step3,114), '00:00:00:000')
   --             , ISNULL(CONVERT(CHAR(12),@c_step4,114), '00:00:00:000')
   --             , ISNULL(CONVERT(CHAR(12),@c_step5,114), '00:00:00:000')
   --             , @c_PickSlipNo
   --             , @c_TicketType
   --             , ''
   --             , ''
   --             , '' )
   --   END
   --END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      WHILE @@TRANCOUNT < @n_starttcnt
         BEGIN TRAN
   END

   /* #INCLUDE <TRMBOHA2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR

         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ScanOutPickSlip'
         -- RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
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