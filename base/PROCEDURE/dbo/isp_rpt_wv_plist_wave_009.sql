SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_009                             */
/* Creation Date: 14-JULY-2022                                             */
/* Copyright: MAERSK                                                       */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-20001                                                      */
/*                                                                         */
/* Called By: RPT_WV_PLIST_WAVE_009                                        */
/*                                                                         */
/* GitLab Version: 1.4                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author   Ver  Purposes                                     */
/* 15-Jul-2022  WLChooi  1.0  DevOps Combine Script                        */
/* 05-Sep-2023  WLChooi  1.1  UWP-7481 - Add Externorderkey (WL01)         */
/* 22-Sep-2023  WLChooi  1.2  UWP-7690 & UWP-7693 - Show Pickdetail (WL02) */
/* 09-Nov-2023  CSCHONG  1.3  WMS-23953 add new field with config (CS01)   */
/* 18-Dec-2023  WLChooi  1.4  UWP-12105 - Global Timezone (GTZ01)          */
/***************************************************************************/
CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_009]
(
   @c_Wavekey       NVARCHAR(10)
 , @c_PreGenRptData NVARCHAR(10) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_pickheaderkey   NVARCHAR(10)
         , @n_continue        INT
         , @c_errmsg          NVARCHAR(255)
         , @b_success         INT
         , @n_err             INT
         , @c_sku             NVARCHAR(20)
         , @n_qty             INT
         , @c_loc             NVARCHAR(10)
         , @n_cases           INT
         , @n_perpallet       INT
         , @c_orderkey        NVARCHAR(10)
         , @c_storer          NVARCHAR(15)
         , @c_storercompany   NVARCHAR(45)
         , @c_ConsigneeKey    NVARCHAR(15)
         , @c_Company         NVARCHAR(45)
         , @c_Addr1           NVARCHAR(45)
         , @c_Addr2           NVARCHAR(45)
         , @c_Addr3           NVARCHAR(45)
         , @c_PostCode        NVARCHAR(15)
         , @c_Route           NVARCHAR(10)
         , @c_Route_Desc      NVARCHAR(60) -- RouteMaster.Desc
         , @c_TrfRoom         NVARCHAR(10) -- ORDERS.Door
         , @c_Notes1          NVARCHAR(60)
         , @c_Notes2          NVARCHAR(60)
         , @c_SkuDesc         NVARCHAR(60)
         , @n_CaseCnt         INT
         , @n_PalletCnt       INT
         , @n_InnerPack       INT
         , @c_ReceiptTm       NVARCHAR(20)
         , @c_PrintedFlag     NVARCHAR(1)
         , @c_UOM             NVARCHAR(10)
         , @n_UOM3            INT
         , @c_Lot             NVARCHAR(10)
         , @c_StorerKey       NVARCHAR(15)
         , @c_Zone            NVARCHAR(1)
         , @n_PgGroup         INT
         , @n_TotCases        INT
         , @n_RowNo           INT
         , @c_PrevSKU         NVARCHAR(20)
         , @n_SKUCount        INT
         , @c_Carrierkey      NVARCHAR(60)
         , @c_VehicleNo       NVARCHAR(10)
         , @c_firstorderkey   NVARCHAR(10)
         , @c_superorderflag  NVARCHAR(1)
         , @c_firsttime       NVARCHAR(1)
         , @c_logicalloc      NVARCHAR(18)
         , @c_Lottable02      NVARCHAR(18)
         , @c_Lottable03      NVARCHAR(18)
         , @c_Lottable04      NVARCHAR(10)
         , @c_labelPrice      NVARCHAR(5)
         , @c_Externorderkey  NVARCHAR(50)
         , @c_externpokey     NVARCHAR(20)
         , @c_invoiceno       NVARCHAR(10)
         , @d_deliverydate    DATETIME
         , @c_rdd             NVARCHAR(10)
         , @c_putawayzone     NVARCHAR(10)
         , @c_zonedesc        NVARCHAR(60)
         , @c_busr8           NVARCHAR(30)
         , @c_AltSku          NVARCHAR(20)
         , @c_Susr1           NVARCHAR(20)
         , @c_Susr2           NVARCHAR(20)
         , @n_StartTCnt       INT
         , @c_Facility        NVARCHAR(5)   --GTZ01
         , @c_WavePSlipQRCode NVARCHAR(10)
         , @c_qrcode          NVARCHAR(1)
         , @c_showecomfield   NVARCHAR(1)
         , @c_Trackingno      NVARCHAR(30)
         , @c_Buyerpo         NVARCHAR(20)
         , @c_Style           NVARCHAR(50)
         , @c_Color           NVARCHAR(50)
         , @c_Size            NVARCHAR(50)
         , @c_AutoScanIn      NVARCHAR(10)
         , @c_PickMethod      NVARCHAR(10)
         , @n_TTLEA           INT           = 0
         , @n_TTLCASES        INT           = 0
         , @n_TTLQTY          INT           = 0
         , @c_Priority        NVARCHAR(10)  = N''
         , @c_loadkey         NVARCHAR(20)  = N''
         , @c_OHTYPE          NVARCHAR(10)  = N''
         , @c_ODUpdateSource  NVARCHAR(20)  = N''
         , @c_ODPackkey       NVARCHAR(10)  = N''
         , @c_ODUOM           NVARCHAR(10)  = N''
         , @c_ODNotes         NVARCHAR(500) = N''
         , @c_OrdGrp          NVARCHAR(20)  = N''
         , @c_OHUDF03         NVARCHAR(20)  = N''
         , @n_ShowExtOrdKey   INT           = 0   --WL01
         , @n_ShowPDUOM       INT           = 0   --WL02
         , @n_ShowCCompany    INT           = 0   --CS01
         , @c_CCompany        NVARCHAR(45)  = N'' --CS01

   SET @n_StartTCnt = @@TRANCOUNT

   DECLARE @c_PrevOrderKey NVARCHAR(10)
         , @n_Pallets      INT
         , @n_Cartons      INT
         , @n_Eaches       INT
         , @n_UOMQty       INT

   CREATE TABLE #temp_wavepick37
   (
      wavekey        NVARCHAR(10)
    , PrnDate        DATETIME      NULL
    , PickSlipNo     NVARCHAR(10)
    , Zone           NVARCHAR(1)
    , printedflag    NVARCHAR(1)
    , Storerkey      NVARCHAR(15)  NULL
    , LOC            NVARCHAR(10)  NULL
    , Lot            NVARCHAR(10)
    , OHType         NVARCHAR(10)
    , Loadkey        NVARCHAR(20)
    , SkuDesc        NVARCHAR(60)  NULL
    , Lottable04     NVARCHAR(10)  NULL
    , Qty            INT
    , ODUpdateSource NVARCHAR(20)
    , Susr1          NVARCHAR(20)
    , Susr2          NVARCHAR(20)
    , SKU            NVARCHAR(20)  NULL
    , rpttitle       NVARCHAR(80)
    , OrderKey       NVARCHAR(10)
    , OrdGrp         NVARCHAR(20)  NULL
    , ODNotes        NVARCHAR(500) NULL
    , Packkey        NVARCHAR(10)
    , UOM            NVARCHAR(10)  NULL
    , UOMQty         INT
    , TTLEA          INT
    , TTLCASE        INT
    , TTLQTY         INT
    , OHUDF03        NVARCHAR(20)
    , ShowExtOrdKey  INT NULL   --WL01
    , ExternOrderkey NVARCHAR(50) NULL   --WL01
    , CCompany       NVARCHAR(45) NULL   --CS01
   )

   SELECT @n_continue = 1
   SELECT @n_RowNo = 0
   SELECT @c_firstorderkey = N'N'

   SELECT @c_PreGenRptData = IIF(ISNULL(@c_PreGenRptData, '') IN ( '', '0' ), '', @c_PreGenRptData)

   -- Use Zone as a UOM Picked that refer to pickdetail.pickmethod
   IF EXISTS (  SELECT 1
                FROM PICKHEADER (NOLOCK)
                WHERE WaveKey = @c_Wavekey AND OrderKey IN (  SELECT OrderKey
                                                              FROM ORDERS oh WITH (NOLOCK)
                                                              WHERE oh.UserDefine09 = @c_Wavekey ))
   BEGIN
      SELECT @c_firsttime = N'N'
      SELECT @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_firsttime = N'Y'
      SELECT @c_PrintedFlag = 'N'
   END -- Record Not Exists

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN

   --WL02 S
   SELECT TOP 1 @c_Storerkey = OH.Storerkey
              , @c_Facility = OH.Facility   --GTZ01
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = WD.Orderkey
   WHERE WD.Wavekey = @c_Wavekey

   SELECT @n_ShowExtOrdKey = ISNULL(MAX(CASE WHEN Code = 'ShowExtOrdKey' THEN 1 ELSE 0 END), 0)
        , @n_ShowPDUOM = ISNULL(MAX(CASE WHEN Code = 'ShowPDUOM' THEN 1 ELSE 0 END), 0)
        , @n_ShowCCompany = ISNULL(MAX(CASE WHEN Code = 'ShowCCompany' THEN 1 ELSE 0 END), 0)     --CS01
   FROM CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'REPORTCFG' 
   AND Long = 'RPT_WV_PLIST_WAVE_009' 
   AND (Short IS NULL OR Short <> 'N')
   AND Storerkey = @c_StorerKey
   --WL02 E
   
   --WL02 S
   IF @n_ShowPDUOM = 1
   BEGIN
      DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PICKDETAIL.Sku
           , PICKDETAIL.Loc
           , SUM(PICKDETAIL.Qty)
           , PACK.Qty
           , PICKDETAIL.Storerkey
           , PICKDETAIL.OrderKey
           , PICKDETAIL.UOM
           , PICKDETAIL.PickMethod
           , PICKDETAIL.Lot
           , PICKDETAIL.UOMQty
      FROM PICKDETAIL WITH (NOLOCK)
      JOIN WAVEDETAIL WITH (NOLOCK) ON PICKDETAIL.OrderKey = WAVEDETAIL.OrderKey
      JOIN PACK WITH (NOLOCK) ON PICKDETAIL.PackKey = PACK.PackKey
      JOIN LOC WITH (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
      JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = WAVEDETAIL.OrderKey AND ORDERS.OrderKey = PICKDETAIL.OrderKey
      JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = PICKDETAIL.Storerkey AND SKU.Sku = PICKDETAIL.Sku
      WHERE WAVEDETAIL.WaveKey = @c_Wavekey AND PICKDETAIL.UOM <> '1'
      GROUP BY PICKDETAIL.Sku
             , PICKDETAIL.Loc
             , PACK.Qty
             , PICKDETAIL.Storerkey
             , PICKDETAIL.OrderKey
             , PICKDETAIL.UOM
             , PICKDETAIL.PickMethod
             , PICKDETAIL.Lot
             , PICKDETAIL.UOMQty
      UNION ALL
      SELECT PICKDETAIL.Sku
           , PICKDETAIL.Loc
           , SUM(PICKDETAIL.Qty)
           , PACK.Qty
           , PICKDETAIL.Storerkey
           , PICKDETAIL.OrderKey
           , PICKDETAIL.UOM
           , PICKDETAIL.PickMethod
           , PICKDETAIL.Lot
           , SUM(PICKDETAIL.UOMQty)
      FROM PICKDETAIL WITH (NOLOCK)
      JOIN WAVEDETAIL WITH (NOLOCK) ON PICKDETAIL.OrderKey = WAVEDETAIL.OrderKey
      JOIN PACK WITH (NOLOCK) ON PICKDETAIL.PackKey = PACK.PackKey
      JOIN LOC WITH (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
      JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = WAVEDETAIL.OrderKey AND ORDERS.OrderKey = PICKDETAIL.OrderKey
      JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = PICKDETAIL.Storerkey AND SKU.Sku = PICKDETAIL.Sku
      WHERE WAVEDETAIL.WaveKey = @c_Wavekey AND PICKDETAIL.UOM = '1'
      GROUP BY PICKDETAIL.Sku
             , PICKDETAIL.Loc
             , PACK.Qty
             , PICKDETAIL.Storerkey
             , PICKDETAIL.OrderKey
             , PICKDETAIL.UOM
             , PICKDETAIL.PickMethod
             , PICKDETAIL.Lot
      ORDER BY PICKDETAIL.OrderKey
   END
   ELSE
   BEGIN
      DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PICKDETAIL.Sku
           , PICKDETAIL.Loc
           , SUM(PICKDETAIL.Qty)
           , PACK.Qty
           , PICKDETAIL.Storerkey
           , PICKDETAIL.OrderKey
           , PICKDETAIL.UOM
           , PICKDETAIL.PickMethod
           , PICKDETAIL.Lot
           , PICKDETAIL.UOMQty
      FROM PICKDETAIL WITH (NOLOCK)
      JOIN WAVEDETAIL WITH (NOLOCK) ON PICKDETAIL.OrderKey = WAVEDETAIL.OrderKey
      JOIN PACK WITH (NOLOCK) ON PICKDETAIL.PackKey = PACK.PackKey
      JOIN LOC WITH (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
      JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = WAVEDETAIL.OrderKey AND ORDERS.OrderKey = PICKDETAIL.OrderKey
      JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = PICKDETAIL.Storerkey AND SKU.Sku = PICKDETAIL.Sku
      WHERE WAVEDETAIL.WaveKey = @c_Wavekey
      GROUP BY PICKDETAIL.Sku
             , PICKDETAIL.Loc
             , PACK.Qty
             , PICKDETAIL.Storerkey
             , PICKDETAIL.OrderKey
             , PICKDETAIL.UOM
             , PICKDETAIL.PickMethod
             , PICKDETAIL.Lot
             , PICKDETAIL.UOMQty
      ORDER BY PICKDETAIL.OrderKey
   END
   --WL02 E

   OPEN pick_cur

   SELECT @c_PrevOrderKey = N''
   FETCH NEXT FROM pick_cur
   INTO @c_sku
      , @c_loc
      , @n_qty
      , @n_UOM3
      , @c_StorerKey
      , @c_orderkey
      , @c_UOM
      , @c_PickMethod
      , @c_Lot
      , @n_UOMQty

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN --While
      IF @c_orderkey <> @c_PrevOrderKey
      BEGIN
         --SET @c_facility= '' 
         --SELECT @c_Facility = Facility
         --FROM ORDERS WITH (NOLOCK)
         --WHERE Orderkey = @c_OrderKey

         IF dbo.fnc_RTRIM(@c_orderkey) = '' OR dbo.fnc_RTRIM(@c_orderkey) IS NULL
         BEGIN --if @c_orderkey = ''
            SELECT @c_ConsigneeKey = N''
                 , @c_Externorderkey = N''
                 , @c_loadkey = N''
                 , @c_Priority = N''
                 , @c_OHTYPE = N''
                 , @c_ODUpdateSource = N''
                 , @c_ODPackkey = N''
                 , @c_ODUOM = N''
                 , @c_ODNotes = N''
                 , @c_OrdGrp = N''
                 , @c_OHUDF03 = N''
                 , @c_CCompany = N''    --CS01
         END --if @c_orderkey=''
         ELSE
         BEGIN --if @c_orderkey <> ''
            SELECT @c_ConsigneeKey = ORDERS.ConsigneeKey
                 , @c_Externorderkey = ORDERS.ExternOrderKey
                 , @c_loadkey = ORDERS.LoadKey
                 , @c_Priority = ORDERS.Priority
                 , @c_OHTYPE = ORDERS.Type
                 , @c_OrdGrp = ORDERS.OrderGroup
                 , @c_OHUDF03 = ORDERS.UserDefine03
                 , @c_CCompany = CASE WHEN @n_ShowCCompany = 1 THEN ORDERS.c_company ELSE '' END      --CS01
            FROM ORDERS (NOLOCK)
            WHERE ORDERS.OrderKey = @c_orderkey AND ORDERS.StorerKey = @c_StorerKey

            SELECT TOP 1 @c_ODUpdateSource = OD.UpdateSource
                       , @c_ODPackkey = OD.PackKey
                       , @c_ODUOM = OD.UOM
                       , @c_ODNotes = ISNULL(OD.Notes, '')
            FROM dbo.ORDERDETAIL OD WITH (NOLOCK)
            WHERE OD.OrderKey = @c_orderkey AND OD.StorerKey = @c_StorerKey AND OD.Sku = @c_sku
         END -- IF @c_OrderKey <> ''


         IF  NOT EXISTS (  SELECT 1
                           FROM PICKHEADER (NOLOCK)
                           WHERE WaveKey = @c_Wavekey AND OrderKey = @c_orderkey AND Zone = @c_PickMethod)
         AND @c_PreGenRptData = 'Y'
         BEGIN --Not Exist in PickHeader
            EXECUTE nspg_GetKey 'PICKSLIP'
                              , 9
                              , @c_pickheaderkey OUTPUT
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

            SELECT @c_pickheaderkey = N'P' + @c_pickheaderkey

            BEGIN TRAN

            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, StorerKey, ConsigneeKey, WaveKey, Priority
                                  , PickType, Zone, LoadKey, TrafficCop)
            VALUES (@c_pickheaderkey, @c_orderkey, @c_Externorderkey, @c_StorerKey, @c_ConsigneeKey, @c_Wavekey
                  , @c_Priority, '5', @c_PickMethod, @c_loadkey, '')

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               ROLLBACK TRAN
               GOTO QUIT
            END
            ELSE
            BEGIN
               WHILE @@TRANCOUNT > 0
               COMMIT TRAN
            END

            SELECT @c_firstorderkey = N'Y'
         END --NOT EXIST in PICKHEADER
         ELSE
         BEGIN -- EXIST in PickHeader
            SELECT @c_pickheaderkey = PickHeaderKey
            FROM PICKHEADER (NOLOCK)
            WHERE WaveKey = @c_Wavekey AND Zone = @c_PickMethod AND OrderKey = @c_orderkey
         END -- Exist in PickHeader
      END -- @c_OrderKey <> @c_PrevOrderKey

      SELECT @c_SkuDesc = ISNULL(DESCR, '')
           , @c_Susr1 = ISNULL(SUSR1, '')
           , @c_Susr2 = ISNULL(SUSR2, '')
      FROM SKU (NOLOCK)
      WHERE StorerKey = @c_StorerKey AND Sku = @c_sku

      SELECT @c_Lottable04 = CONVERT(NVARCHAR(10), [dbo].[fnc_ConvSFTimeZone](@c_StorerKey, @c_Facility, Lottable04), 23)   --GTZ01
      FROM LOTATTRIBUTE (NOLOCK)
      WHERE Lot = @c_Lot

      SELECT @n_RowNo = @n_RowNo + 1
      SELECT @n_Pallets = 0
           , @n_Cartons = 0
           , @n_Eaches = 0

      SET @n_TTLEA = 0
      SET @n_TTLCASES = 0
      SET @n_TTLQTY = 0

      IF @c_ODUOM = 'EA'
      BEGIN
         SELECT @n_TTLEA = SUM(PD.Qty)
         FROM PICKDETAIL PD WITH (NOLOCK)
         JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON  OD.OrderKey = PD.OrderKey
                                               AND OD.StorerKey = PD.Storerkey
                                               AND OD.Sku = PD.Sku
                                               AND OD.OrderLineNumber = PD.OrderLineNumber
         WHERE PD.Storerkey = @c_StorerKey AND PD.OrderKey = @c_orderkey AND OD.UOM = 'EA'
      END

      IF @c_ODUOM = 'CASE'
      BEGIN
         SELECT @n_TTLCASES = SUM(PD.UOMQty)
         FROM PICKDETAIL PD WITH (NOLOCK)
         JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON  OD.OrderKey = PD.OrderKey
                                               AND OD.StorerKey = PD.Storerkey
                                               AND OD.Sku = PD.Sku
                                               AND OD.OrderLineNumber = PD.OrderLineNumber
         WHERE PD.Storerkey = @c_StorerKey AND PD.OrderKey = @c_orderkey AND OD.UOM = 'CASE'
      END

      SELECT @n_TTLQTY = SUM(PD.Qty)
      FROM PICKDETAIL PD WITH (NOLOCK)
      WHERE PD.Storerkey = @c_StorerKey AND PD.OrderKey = @c_orderkey

      --WL02 S - Move up
      --WL01 S
      --SELECT @n_ShowExtOrdKey = ISNULL(MAX(CASE WHEN Code = 'ShowExtOrdKey' THEN 1 ELSE 0 END), 0)
      --FROM CODELKUP WITH (NOLOCK)
      --WHERE LISTNAME = 'REPORTCFG' 
      --AND Long = 'RPT_WV_PLIST_WAVE_009' 
      --AND (Short IS NULL OR Short <> 'N')
      --AND Storerkey = @c_StorerKey
      --WL01 E
      --WL02 E - Move up

     --WL02 S
     IF @n_ShowPDUOM = 1
      BEGIN
         SELECT @c_ODPackkey = PACK.PackKey
         FROM SKU (NOLOCK)
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         WHERE SKU.Storerkey = @c_Storerkey
         AND SKU.SKU = @c_SKU
      END
      --WL02 E

      INSERT INTO #temp_wavepick37 (wavekey, PrnDate, PickSlipNo, Zone, printedflag, Storerkey, LOC, Lot, OHType
                                  , Loadkey, SkuDesc, Lottable04, Qty, ODUpdateSource, Susr1, Susr2, SKU, rpttitle
                                  , OrderKey, OrdGrp, ODNotes, Packkey, UOM, UOMQty, TTLEA, TTLCASE, TTLQTY, OHUDF03
                                  , ShowExtOrdKey, ExternOrderkey,CCompany )   --WL01    --CS01
      VALUES (@c_Wavekey, CONVERT(CHAR(16), [dbo].[fnc_ConvSFTimeZone](@c_StorerKey, @c_Facility, GETDATE()), 120), @c_pickheaderkey, @c_PickMethod, @c_PrintedFlag   --GTZ01
            , @c_StorerKey, @c_loc, @c_Lot, @c_OHTYPE, @c_loadkey, @c_SkuDesc, @c_Lottable04, @n_qty, @c_ODUpdateSource
            , @c_Susr1, @c_Susr2, @c_sku, 'PickSlip by Orders', @c_orderkey, @c_OrdGrp, @c_ODNotes, @c_ODPackkey
            , IIF(@n_ShowPDUOM = 1, @c_UOM, @c_ODUOM), @n_UOMQty, @n_TTLEA, @n_TTLCASES, @n_TTLQTY, @c_OHUDF03   --WL02
            , @n_ShowExtOrdKey, @c_Externorderkey,@c_CCompany)   --WL01        --CS01

      SELECT @c_PrevOrderKey = @c_orderkey

      FETCH NEXT FROM pick_cur
      INTO @c_sku
         , @c_loc
         , @n_qty
         , @n_UOM3
         , @c_StorerKey
         , @c_orderkey
         , @c_UOM
         , @c_PickMethod
         , @c_Lot
         , @n_UOMQty
   END

   CLOSE pick_cur
   DEALLOCATE pick_cur

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN

   SUCCESS:
   IF ISNULL(@c_PreGenRptData, '') = ''
   BEGIN
      SELECT *
      FROM #temp_wavepick37
      ORDER BY PickSlipNo
             , OrderKey
             , SKU
   END

   QUIT:
   IF OBJECT_ID('tempdb..#temp_wavepick37') IS NOT NULL
      DROP TABLE #temp_wavepick37

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN TRAN

   IF @n_continue = 3 -- Error Occured - Process And Return  
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_WV_PLIST_WAVE_009'
      -- RAISERROR (@c_errmsg, 16, 1) WITH SETERROR      
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO