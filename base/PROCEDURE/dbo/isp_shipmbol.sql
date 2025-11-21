SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ShipMBOL                                       */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 28-Jun-2002  June       Added for IDSV5 (extract FROM IDSHK).        */
/* 16-Nov-2002  Wally      Added 1 field to populate: poddef08 =        */
/*                         mboldetail.ITS.                              */
/*              SHONG      For New POD Version.                         */
/* 12-Feb-2003  SHONG      Do not insert INTO POD when POD records is   */
/*                         exists. Use left outer join.                 */
/* 09-Apr-2003  Vicky      CDC Migration.                               */
/* 16-Oct-2003  YokeBeen   - (SOS#15350/15353).                         */
/* 31-Mar-2004  June       - (SOS#21700) IDSPH ULP - 1 Order Populated  */
/*                           INTO multiple MBOL.                        */
/* 09-Apr-2004  Maryvong   - (NZMM - FBR18999 Shipment Confirmation     */
/*                            Export).                                  */
/* 17-Aug-2005  YokeBeen   - SQL2K Upgrading Project-V6.0               */
/*                           Added dbo. for all the EXECUTE statement.  */
/*                           Removed SET ANSI_WARNINGS OFF.             */
/*                           - (YokeBeen01).                            */
/* 19-Aug-2005 June        SOS39663 - IDSPH ULP v54 bug fixed           */
/* 27-Oct-2006 June        Add Storerkey in POD table                   */
/* 15-Nov-2006 June        SOS39706 - IDSPH ULP v54 bug fixed.          */
/*                         (Original fixed at 22-Aug-2005. Conso version*/
/*                          from PVCS at 15-Nov-2006.                   */
/* 15-Nov-2006  Shong     Pass in StorerKey into the Insert POD Check   */
/* 13-Feb-2008  June      SOS95698 - Add SpecialHandling in POD table   */
/* 27-Aug-2008  Shong     SOS114620 - Include the Type 2 Orders when    */
/*                        MBOL Ship.                                    */
/* 22-Sep-2008  Shong     SOS117003 - Type 2 Orders Is UserDefine08 = 2 */
/* 28-Jul-2010  James     If config 'MBOLSHIPCLOSETOTE' turned on then  */
/*                        update DropID.Status = '9' (james01)          */
/* 30-Jul-2010  Shong     'MBOLSHIPCLOSETOTE' Should not checking Pack  */
/*                        Status (Shong01)                              */
/* 25-Sep-2010  James     Only ship tote (DropID.Status = '9') for      */
/*                        store Orders (proj diana) (james02)    */
/* 28-Dec-2011  TLTING01  SOS231886 StorerConfig for X POD Actual       */
/*                        Develiry Date                                 */
/* 20-Jul-2011  YTWan     AutoCreateASN during shipment. (Wan01)        */
/* 24-May-2012  TLTING02  PerformanceTune                               */
/* 20-DEC-2013  YTWan     SOS#294825 ANF - MBOL Creation. (Wan02)       */
/* 05-Jan-2014  TLTING03  Performance tune - Add index to temp #table   */
/* 30-NOV-2017  JYHBIN    INC0060084 Added storerkey                    */
/* 29-JAN-2018  Wan03     WMS-3662 - Add Externloadkey to WMS POD module*/
/* 09-FEB-2018  CHEEMUN   INC0128904- LEFT JOIN Loadplan                */
/* 25-Jul-2018  TLTING03  Missing NOLOCK                                */
/* 04-Oct-2018  TLTING    Performance tune                              */
/* 13-Nov-2018  SHONG     Fixing Insert duplicate POD                   */
/* 28-Jan-2019  TLTING_ext enlarge externorderkey field length      */
/* 25-Feb-2019  WLCHOOI   Change the name of the temp tables due to     */
/*                        issues when testing PostMBOLShip (WL01)       */
/* 14-Mar-2019  NJOW01    WMS-8263 MBOL Ship close serial no status     */
/* 10-Mar-2022  Wan04     LFWM-3393 - PROD - CN  MBOL unable mark ship  */
/*                        -Fixed EXIT SP Transcount <> START SP Transcount*/
/*                        -When SCE SP issue BEGIN TRAN for Shipment    */
/* 20-SEP-2022  NJOW02    WMS-20699 Update MBOL Carrierkey to POD PODDEF06*/
/* 20-SEP-2022  NJOW02    DEVOPS Combine Script                         */
/* 17-May-2023  WLChooi   WMS-22541 - Add PreMBOLShipSP (WL02)          */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_ShipMBOL]
       @c_MBOLKey       NVARCHAR(10),
       @b_Success       int = 1        OUTPUT,
       @n_err           int = 0        OUTPUT,
       @c_errmsg        NVARCHAR(255) = '' OUTPUT
AS
BEGIN -- main
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0

   DECLARE   @n_continue           int
   ,         @n_starttcnt          int       -- Holds the current transaction count
   ,         @c_preprocess         NVARCHAR(250) -- preprocess
   ,         @c_pstprocess         NVARCHAR(250) -- post process
   ,         @n_cnt                int
   ,         @c_facility           NVARCHAR(5)
   ,         @c_OWITF              NVARCHAR(1)
   ,         @c_realtmship         NVARCHAR(1)
   ,         @c_authority          NVARCHAR(1)
   ,         @c_OrderKeyShip       NVARCHAR(10)
   ,         @c_asn                NVARCHAR(1)   -- Added By Vicky
   ,         @c_ulpitf             NVARCHAR(1)   -- Added By Vicky
   ,         @c_externorderkey     NVARCHAR(50)  --tlting_ext   -- Added By Vicky
   ,         @c_lastload           NVARCHAR(1)   -- Added By Vicky
   ,         @c_short              char (10)
   ,         @c_trmlogkey          NVARCHAR(10)
   ,         @c_NIKEREGITF         NVARCHAR(1)   -- Added by YokeBeen (SOS#15350/15353)
   ,         @c_LoadKey            NVARCHAR(10)
   ,         @c_OrdIssued          NVARCHAR(1)
   ,         @c_LongConfig         NVARCHAR(250)
   ,         @c_NZShort            char (10)   -- Added by Maryvong (NZMM - FBR18999 Shipment Confirmation Export)
   ,         @cStatus              NVARCHAR(10)
   ,         @n_PackedQty          INT -- (Shong01)
   ,         @n_PickedQty          INT -- (Shong01)
   ,         @c_PickSlipNO         NVARCHAR(10) -- (Shong01)
   ,         @c_authorityPOD       NVARCHAR(1)
   ,         @c_authorityTote      NVARCHAR(1)
   ,         @c_ispProc            NVARCHAR(30)  --(Wan01)


   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   DECLARE @c_PickDetailKey     NVARCHAR(10),
           @c_PickDetailKeyship NVARCHAR(10),           
           @c_PostMBOLShipSP        NVARCHAR(10)   --(Wan02)

   --NJOW02
   DECLARE @c_UpdMBCarrierToPODDEF06 NVARCHAR(10) 
         , @c_option1                NVARCHAR(50) 
         , @c_option2                NVARCHAR(50) 
         , @c_option3                NVARCHAR(50)
         , @c_option4                NVARCHAR(50)
         , @c_option5                NVARCHAR(4000)

   -- tlting02
   CREATE TABLE #StorerCfg1
   (  Rowref INT NOT NULL IDENTITY(1,1) Primary KEY,
      StorerKey  NVARCHAR(15),
      ConfigKey  NVARCHAR(30) )

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @cStatus = Status
      FROM MBOL (NOLOCK)
      WHERE MBOLkey = @c_MBOLKey

      IF @cStatus = '9'
      BEGIN
         SELECT @n_continue=3
         SELECT @n_err=72800
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE rejected. MBOL.Status = ''SHIPPED''. (isp_ShipMBOL)'
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @c_ConfigKey  NVARCHAR(30)

      SELECT M.* INTO #t_MBOLDetail1
      FROM   MBOLDETAIL M (NOLOCK)
      WHERE  (M.MBOLKey = @c_MBOLKey)

      -- tlting
      CREATE INDEX IX_tt_MBOLDetail_key1 ON #t_MBOLDetail1 (MBOLKey, MbolLineNumber)
      CREATE INDEX IX_tt_MBOLDetail_key2 ON #t_MBOLDetail1 (MBOLKey, OrderKey)

      SELECT DISTINCT O.Storerkey, O.ExternOrderkey, O.Orderkey, O.type, O.Route, O.Facility, O.Loadkey, O.Issued, O.BuyerPO, O.InvoiceNo
             , O.SpecialHandling -- SOS95698
      INTO   #t_Orders1
      FROM   MBOLDETAIL M (NOLOCK)
      JOIN   ORDERS O (NOLOCK) ON (O.OrderKey = M.OrderKey)
      WHERE  M.MBOLKey = @c_MBOLKey
      AND    O.[Status] NOT IN ('9', 'CANC')
      -- End : SOS39663

      -- tlting
      CREATE INDEX IX_tt_Orders_key1 ON #t_Orders1 (OrderKey)
      CREATE INDEX IX_tt_Orders_key2 ON #t_Orders1 (Loadkey, OrderKey)

      -- Added By SHONG on 27th-Aug-2008
      -- SOS#
      INSERT INTO #t_Orders1 (Storerkey, ExternOrderkey, Orderkey, type, Route, Facility, Loadkey, Issued, BuyerPO, InvoiceNo
                           , SpecialHandling)
      SELECT DISTINCT O.Storerkey, O.ExternOrderkey, O.Orderkey, O.type, O.Route, O.Facility, '' As Loadkey, O.Issued, O.BuyerPO, O.InvoiceNo
             , O.SpecialHandling
      FROM   MBOLDETAIL M (NOLOCK)
      JOIN   ORDERS O (NOLOCK) ON (O.OrderKey = M.OrderKey AND O.Mbolkey = M.Mbolkey)
      LEFT OUTER JOIN #t_Orders1 TmpOrd ON TmpOrd.OrderKey = O.OrderKey
      WHERE  M.MBOLKey = @c_MBOLKey
       --    SOS#117003, Type 2 Orders is UserDefine08 = '2'
       --    AND   O.Type = '2'
       AND   O.UserDefine08 = '2'
       AND   TmpOrd.OrderKey IS NULL

      -- tlting02
      INSERT INTO #StorerCfg1 (StorerKey, ConfigKey)
      SELECT O.StorerKey, S.ConfigKey
      FROM   #t_MBOLDetail1 M
      JOIN   #t_Orders1 O (NOLOCK) ON (O.OrderKey = M.OrderKey)
      JOIN   StorerConfig S (NOLOCK) ON (S.StorerKey = O.StorerKey)
      WHERE  S.sValue = '1'
   END

   CREATE INDEX IX_StorerCfg_01 on #StorerCfg1 (ConfigKey)    -- tlting02

   -- Clean all the tran_count
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   DECLARE @c_PickOrderKey    NVARCHAR(10),
           @c_XmitLogKey      NVARCHAR(10),
           @c_PickOrderLine   NVARCHAR(5),
           @c_StorerKey       NVARCHAR(20),
           @c_OrderKey        NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @c_OrderType       NVARCHAR(10),
           @c_OrdRoute        NVARCHAR(10)

   -- tlting01
   IF @n_continue = 1 OR @n_continue=2
   BEGIN -- 00A
      SET @c_authority = ''
      SET @c_authorityPOD = ''
      SET @c_authorityTote = ''

      SELECT Top 1 @c_StorerKey = O.StorerKey,
                   @c_Facility  = Facility
      FROM   #t_MBOLDetail1 MD with (NOLOCK)
      JOIN   #t_Orders1 O with (NOLOCK) ON  O.Orderkey =  MD.OrderKey
      WHERE  MD.MBOLKEY = @c_MBOLKEY

 
      SELECT @b_success = 0
      EXECUTE nspGetRight 
              @c_Facility  = @c_facility, -- facility
              @c_StorerKey = @c_storerkey, -- Storerkey -- SOS40271
              @c_sku       = NULL,         -- Sku
              @c_ConfigKey = 'POD',        -- Configkey
              @b_Success   = @b_success    OUTPUT,
              @c_authority = @c_authorityPOD  OUTPUT,
              @n_err       = @n_err        OUTPUT,
              @c_errmsg    = @c_errmsg     OUTPUT,                                     
              @c_Option1   = @c_Option1    OUTPUT, --NJOW02
              @c_Option2   = @c_Option2    OUTPUT,
              @c_Option3   = @c_Option3    OUTPUT,
              @c_Option4   = @c_Option4    OUTPUT,                            
              @c_Option5   = @c_Option5    OUTPUT                    
       
      --NJOW02                                                     
      SET @c_UpdMBCarrierToPODDEF06 = 'N'
      SELECT @c_UpdMBCarrierToPODDEF06 = dbo.fnc_GetParamValueFromString('@c_UpdMBCarrierToPODDEF06', @c_Option5, @c_UpdMBCarrierToPODDEF06)               

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'isp_ShipMBOL' + RTrim(@c_errmsg)
      END

      SELECT @b_success = 0
      EXECUTE dbo.nspGetRight @c_facility,
               @c_Storerkey, -- Storerkey
               NULL,         -- Sku
               'PODXDeliverDate',        -- Configkey
               @b_success    output,
               @c_authority  output,
               @n_err        output,
               @c_errmsg     output

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'isp_ShipMBOL' + RTrim(@c_errmsg)
      END

      SELECT @b_success = 0
      EXECUTE dbo.nspGetRight @c_facility,
              @c_Storerkey, -- Storerkey
               NULL,         -- Sku
               'MBOLSHIPCLOSETOTE',        -- Configkey
               @b_success    output,
               @c_authorityTote  output,
               @n_err        output,
               @c_errmsg     output

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'isp_ShipMBOL' + RTrim(@c_errmsg)
      END

   END -- 00A

   --WL02 S
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @b_Success = 0

      EXECUTE dbo.ispPreMBOLShipWrapper
              @c_MBOLKey = @c_MBOLKey
            , @b_Success = @b_Success     OUTPUT
            , @n_Err     = @n_err         OUTPUT
            , @c_ErrMsg  = @c_errmsg      OUTPUT
            , @b_debug   = 0

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @b_Success = 0
         SET @n_err  = 60546
         SET @c_errmsg = 'Execute ispPreMBOLShipWrapper Failed'
      END
   END
   --WL02 E

   IF @n_continue = 1 OR @n_continue=2
   BEGIN -- 01
      SELECT @c_OrderKey = SPACE(10)

      WHILE 1=1 AND @n_continue = 1
      BEGIN
         SELECT @c_OrderKey = MIN(OrderKey)
         FROM   #t_MBOLDetail1 (NOLOCK)
         WHERE  MBOLKEY = @c_MBOLKEY
         AND    OrderKey > @c_OrderKey

         -- Added By Vicky 09 Apr 2003
         -- CDC Migration
         IF RTrim(@c_OrderKey) IS NULL OR RTrim(@c_OrderKey) = ''
         BREAK

         SELECT @c_ExternOrderKey = ExternOrderKey,
                @c_Storerkey = Storerkey,
                @c_OrderType = ISNULL(RTrim(type), ''),
                @c_OrdRoute  = Route,
                @c_Facility  = Facility,
                @c_Loadkey   = LoadKey,
                @c_OrdIssued = Issued
         FROM   #t_Orders1 (NOLOCK)
         WHERE  Orderkey =  @c_OrderKey

         IF @b_debug = 1
         BEGIN
            SELECT 'Start order -  ' + @c_OrderKey
         END


         -- Auto Create ASN
         --(Wan01) - START
         IF EXISTS(SELECT 1 FROM #StorerCfg1 (NOLOCK) WHERE storerkey = @c_storerkey
                      AND configkey = 'AutoCreateASN')
         BEGIN -- svalue
            SET @c_ispProc = ''

            --SELECT @c_ispProc = ISNULL(RTRIM(Long),'')
            --FROM CODELKUP WITH (NOLOCK)
            --WHERE ListName = 'ORDTYP2ASN' AND Code = @c_OrderType

            SELECT TOP 1 @c_ispProc = ISNULL(RTRIM(Long),'')
                     FROM CODELKUP WITH (NOLOCK)
                     WHERE ListName = 'ORDTYP2ASN' AND Code = @c_OrderType
            AND (StorerKey = @c_StorerKey OR Storerkey = '') -- INC0060084 jyhbin
            ORDER BY StorerKey DESC

            IF @c_ispProc <> '' AND @c_ispProc IS NOT NULL
            BEGIN
               IF NOT EXISTS ( SELECT 1 FROM TransmitLog WITH (NOLOCK) WHERE TableName = N'AutoCreateASN'
                               AND Key1 = @c_OrderKey AND Key3 = @c_storerkey )
               BEGIN
                  EXEC @c_ispProc @c_OrderKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                     CONTINUE
                  END

                  SET @b_success = 1
                  EXECUTE nspg_getkey
                  'transmitlogkey'
                  , 10
                  , @c_trmlogkey OUTPUT
                  , @b_success   OUTPUT
                  , @n_err       OUTPUT
                  , @c_errmsg    OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SET @n_continue = 3
                     SET @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain transmitlogkey. (isp_ShipMBOL)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
                     CONTINUE
                  END
                  ELSE
                  BEGIN
                     INSERT INTO Transmitlog (transmitlogkey, tablename, key1, key2, key3, transmitflag)
                     VALUES (@c_trmlogkey, 'AutoCreateASN', @c_OrderKey, '', @c_storerkey, '9')
                  END
               END
            END

         END
         --(Wan01) - END

         IF EXISTS(SELECT 1 FROM #StorerCfg1 (NOLOCK) WHERE storerkey = @c_storerkey
                      AND configkey = 'REALTIMESHIP')
         BEGIN -- svalue
            SELECT @c_realtmship  = '1'
         END

         IF @b_debug = 1
         BEGIN
            SELECT 'Ship order -  '
         END

         IF EXISTS(SELECT 1 FROM #StorerCfg1 (NOLOCK) WHERE storerkey = @c_storerkey AND configkey = 'ULPITF')
         BEGIN
             EXEC dbo.isp_Ship_ULP_Order  -- (YokeBeen01)
                  @c_MBOLKey      = @c_MBOLKey,
                  @c_OrderKey     = @c_OrderKey,
                  @c_RealTmShip   = @c_realtmship,
                  @b_Success     = @b_Success  OUTPUT,
                  @n_err            = @n_err      OUTPUT,
                  @c_errmsg         = @c_errmsg   OUTPUT
         END -- ulpitf
         ELSE
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT 'ShipOrder - ' + @c_OrderKey
            END

            EXEC dbo.isp_ShipOrder  -- (YokeBeen01)
                  @c_MBOLKey        = @c_MBOLKey,
                  @c_OrderKey       = @c_OrderKey,
                  @c_RealTmShip     = @c_realtmship,
                  @b_Success        = @b_Success  OUTPUT,
                  @n_err            = @n_err      OUTPUT,
                  @c_errmsg         = @c_errmsg   OUTPUT
         END

         -- Generate POD Records Here...................
         -- 15-Nov-2006  Shong

         IF @c_authorityPOD = '1'
         BEGIN -- Added for IDSV5 by June 28.Jun.02, (extract FROM IDSHK) *** End
            IF @b_debug = 1
            BEGIN
               SELECT 'Insert Details of MBOL INTO POD Table'
            END

            -- Changed by June 31.Mar.2004 - SOS21700, (IDSPH ULP) - 1 Order Populated INTO multiple MBOL
            IF NOT EXISTS(SELECT 1 FROM POD (NOLOCK) WHERE OrderKey = @c_OrderKey AND Mbolkey = @c_mbolkey)
            BEGIN
               -- Modify by SHONG For New POD Version
               -- wally 16.nov.2002
               -- added 1 field to populate: poddef08 = mboldetail.ITS
               -- Modify By SHONG on 12-Feb-2003
               -- Do not insert INTO POD when POD records is exists
               -- Use left outer join
               BEGIN TRAN

               INSERT INTO POD
                     (MBOLKey,        MBOLLineNumber,     LoadKey,     Externloadkey,    --(Wan03)
                     OrderKey,        BuyerPO,            ExternOrderKey,
                     InvoiceNo,       status,             ActualDeliveryDate,
                     InvDespatchDate, poddef08,           Storerkey,
                     SpecialHandling, PODDef06) -- SOS95698

               SELECT  #t_MBOLDetail1.MBOLKey, #t_MBOLDetail1.MBOLLineNumber,
                     #t_MBOLDetail1.LoadKey,
                     ISNULL(LOADPLAN.Externloadkey, ''),                                 --(Wan03)--INC0128904
                     #t_Orders1.OrderKey,
                     #t_Orders1.BuyerPO,
                     #t_Orders1.ExternOrderKey,
               CASE WHEN wts.cnt = 1 THEN #t_MBOLDetail1.userdefine01
                     ELSE #t_Orders1.InvoiceNo
               END, -- pod.invoiceno
               '0',
               CASE WHEN @c_authority = '1' THEN NULL ELSE GETDATE() END, -- tlting01
               GETDATE(),
               #t_MBOLDetail1.its,
               #t_Orders1.Storerkey,
               #t_Orders1.SpecialHandling, -- SOS95698
               CASE WHEN @c_UpdMBCarrierToPODDEF06 = 'Y' THEN ISNULL(MB.CarrierKey,'') ELSE '' END  --NJOW02               
               FROM #t_MBOLDetail1 (NOLOCK)
               JOIN MBOL MB (NOLOCK) ON #t_MBOLDetail1.Mbolkey = MB.Mbolkey  --NJOW02
               JOIN #t_Orders1 (NOLOCK) ON (#t_MBOLDetail1.OrderKey = #t_Orders1.OrderKey
                                           AND #t_MBOLDetail1.Loadkey = #t_Orders1.Loadkey) -- SOS39663
               JOIN ORDERS SO WITH (NOLOCK) ON (#t_Orders1.OrderKey = SO.OrderKey)         --(WAN03)
               LEFT JOIN LOADPLAN LOADPLAN WITH (NOLOCK) ON (LOADPLAN.LoadKey = SO.LoadKey)    --(WAN03)--INC0128904
               -- for WATSONS-PH: use pod.invoiceno for shipping manifest#
               LEFT OUTER JOIN (SELECT storerkey, 1 AS cnt
                    FROM storerconfig (NOLOCK)
                    WHERE configkey = 'WTS-ITF' AND svalue = '1') AS wts
               ON #t_Orders1.storerkey = wts.storerkey
               WHERE #t_Orders1.OrderKey = @c_OrderKey
               AND  #t_MBOLDetail1.Mbolkey = @c_Mbolkey -- Add by June 31.Mar.2004 - SOS21700, IDSPH ULP
               AND NOT EXISTS(SELECT 1 FROM POD WITH (NOLOCK)
                              WHERE POD.Mbolkey = #t_MBOLDetail1.Mbolkey
                              AND POD.Mbollinenumber = #t_MBOLDetail1.Mbollinenumber)

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On Table POD. (isp_ShipMBOL)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
                  ROLLBACK TRAN
               END
               ELSE
               BEGIN
                  WHILE @@TRANCOUNT > 0
                  BEGIN
                     COMMIT TRAN
                  END
               END
            END
         END -- AuthorityPOD = 1
         IF @b_debug = 1
         BEGIN
            SELECT 'UPDATE DropID '
         END
         -- Close Tote (james01)
         IF @c_authorityTote = '1'
         BEGIN
            --tlting04
            UPDATE DropID WITH (ROWLOCK) SET
               Status = '9'
            FROM dbo.PackDetail PD (NOLOCK)
            JOIN dbo.PackHeader PH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
            JOIN dbo.DropID DropID ON (PD.DropID = DropID.DropID)
            JOIN dbo.Orders O (NOLOCK) ON (PH.OrderKey = O.OrderKey)
            WHERE O.StorerKey = @c_Storerkey
               AND O.OrderKey = @c_OrderKey
               AND O.UserDefine01 = '' -- (james02)
               -- AND PH.Status = '9' (Shong01)

            IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'isp_ShipMBOL - Close Tote Failed'
            END

            -- (Shong01) Start
            SELECT @n_PickedQty = SUM(Qty)
            FROM PICKDETAIL WITH (NOLOCK)
            WHERE OrderKey = @c_OrderKey
            AND   (STATUS = '5' OR ShipFlag = 'P')

            SELECT @n_PackedQty = SUM(PD.Qty),
                   @c_PickSlipNO = PH.PickSlipNo
            FROM  PACKHEADER PH WITH (NOLOCK)
            JOIN  PackDetail pd WITH (NOLOCK) ON pd.PickSlipNo = PH.PickSlipNo
            WHERE PH.OrderKey = @c_OrderKey
            GROUP BY PH.PickSlipNo

            IF @n_PickedQty = @n_PackedQty
            BEGIN
               UPDATE PackHeader  with (ROWLOCK)
               SET STATUS='9', ArchiveCop=NULL
               WHERE OrderKey = @c_OrderKey
               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE PackHeader Failed. (isp_ShipMBOL)'
                  ROLLBACK TRAN
               END

               UPDATE PickingInfo with (ROWLOCK)
               SET ScanOutDate=GETDATE(), TrafficCop=NULL
               WHERE PickSlipNo = @c_PickSlipNO
               AND   ScanOutDate IS NULL
               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE PickingInfo Failed. (isp_ShipMBOL)'
                  ROLLBACK TRAN
               END
            END
            -- (Shong01) End
         END -- authorityTote
      END -- WHILE orderkey

      IF @b_debug = 1
      BEGIN
         SELECT ' Finish While Order '
      END

      IF EXISTS(SELECT 1 FROM #StorerCfg1 (NOLOCK) WHERE storerkey = @c_storerkey
                                                   AND configkey = 'WTS-ITF')
      BEGIN -- svalue
         EXEC dbo.ispGenTransmitLog2 'WTS-PICK', @c_mbolkey, '', '', ''    -- (YokeBeen01)
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

      END -- svalue
   END -- 01
--   /****  To Update Status of ORDERS to '9' During Shipment of MBOL ****/
--   -- SOS 6862 : End

   --NJOW01
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      EXECUTE dbo.ispMBOLShipCloseSerialNo
              @c_MBOLKey  = @c_MBOLKey
            , @b_Success = @b_Success     OUTPUT
            , @n_Err     = @n_err         OUTPUT
            , @c_ErrMsg  = @c_errmsg      OUTPUT

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @b_Success = 0
         SET @n_err  = 60544
         SET @c_errmsg = 'Execute ispMBOLShipCloseSerialNo Failed'
      END
   END

   IF @b_debug = 1
   BEGIN
      SELECT 'Start PostMBOLShipWrapper  '
   END

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN;

   WHILE @@TRANCOUNT < @n_starttcnt
      BEGIN TRAN

   --(Wan02) - START
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @b_Success = 0

      EXECUTE dbo.ispPostMBOLShipWrapper
              @c_MBOLKey  = @c_MBOLKey
            , @b_Success = @b_Success     OUTPUT
            , @n_Err     = @n_err         OUTPUT
            , @c_ErrMsg  = @c_errmsg      OUTPUT
            , @b_debug   = 0

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @b_Success = 0
         SET @n_err  = 60545
         SET @c_errmsg = 'Execute ispPostMBOLShipWrapper Failed'
      END
   END
   --(Wan02) - END

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN;

   WHILE @@TRANCOUNT < @n_starttcnt
      BEGIN TRAN

   /* #INCLUDE <TRMBOHU2.SQL> */

   --Drop all the temp tables
   IF OBJECT_ID('tempdb..#StorerCfg1','u') IS NOT NULL
       DROP TABLE #StorerCfg1

   IF OBJECT_ID('tempdb..#t_Orders1','u') IS NOT NULL
       DROP TABLE #t_Orders1

   IF OBJECT_ID('tempdb..#t_MBOLDetail1 ','u') IS NOT NULL
       DROP TABLE #t_MBOLDetail1

 /***** End Add by DLIM *****/
   IF @n_continue=3  -- Error Occured - Process AND Return
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_ShipMBOL'     -- (YokeBeen01)
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      --RETURN             --(Wan04)
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      --RETURN             --(Wan04)
   END
   --(Wan04) - START
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   --(Wan04) - END
END -- main

GO