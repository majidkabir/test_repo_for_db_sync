SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_034                             */
/* Creation Date: 03-Nov-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: UWP-10153 - New Pick Slip- Picking list                        */
/*          Copy from isp_RPT_WV_PLIST_WAVE_009                            */
/*                                                                         */
/* Called By: RPT_WV_PLIST_WAVE_034                                        */
/*                                                                         */
/* Github Version: 1.2                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author   Ver  Purposes                                     */
/* 03-Nov-2023  WLChooi  1.0  DevOps Combine Script                        */
/* 27-Feb-2024  SeanDeng 1.1  UWP-15685 - Global Timezone (SD01)           */
/* 10-Jan-2025  WLChooi  1.2  FCR-2215 - Add ShowMBOLInfo Codelkup to show */
/*                            MBOLKey & PlaceOfLoading (WL01)              */
/***************************************************************************/
CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_034]
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
         , @c_Orderkey        NVARCHAR(10)
         , @c_ConsigneeKey    NVARCHAR(15)
         , @c_SkuDesc         NVARCHAR(60)
         , @c_Printedflag     NVARCHAR(1)
         , @c_UOM             NVARCHAR(10)
         , @n_UOM3            INT
         , @c_Lot             NVARCHAR(10)
         , @c_StorerKey       NVARCHAR(15)
         , @c_Facility        NVARCHAR(5)   --SD01
         , @n_RowNo           INT
         , @c_firstorderkey   NVARCHAR(10)
         , @c_firsttime       NVARCHAR(1)
         , @c_Externorderkey  NVARCHAR(50)
         , @n_StartTCnt       INT
         , @c_PickMethod      NVARCHAR(10)
         , @n_TTLEA           INT           = 0
         , @n_TTLCASES        INT           = 0
         , @n_TTLQTY          INT           = 0
         , @c_Priority        NVARCHAR(10)  = N''
         , @c_Packkey         NVARCHAR(10)  = N''
         , @c_Company         NVARCHAR(100) = N''
         , @c_Address1        NVARCHAR(100) = N''
         , @c_ID              NVARCHAR(50)  = N''
         , @n_IDQty           INT           = 0
         , @c_Loadkey         NVARCHAR(10)  = N''
         , @c_PlaceOfLoading  NVARCHAR(30)  = N''   --WL01
         , @c_MBOLKey         NVARCHAR(10)  = N''   --WL01
         , @n_ShowMBOLInfo    INT           = 0     --WL01

   SET @n_StartTCnt = @@TRANCOUNT

   DECLARE @c_PrevOrderKey NVARCHAR(10)
         , @n_Pallets      INT
         , @n_Cartons      INT
         , @n_Eaches       INT
         , @n_UOMQty       INT

   CREATE TABLE #temp_wavepick37
   (
      Wavekey        NVARCHAR(10)
    , PrnDate        DATETIME      NULL
    , PickSlipNo     NVARCHAR(10)
    , Zone           NVARCHAR(1)
    , Printedflag    NVARCHAR(1)
    , Storerkey      NVARCHAR(15)  NULL
    , LOC            NVARCHAR(10)  NULL
    , Lot            NVARCHAR(10)
    , SkuDesc        NVARCHAR(60)  NULL
    , Qty            INT
    , SKU            NVARCHAR(20)  NULL
    , Rpttitle       NVARCHAR(80)
    , OrderKey       NVARCHAR(10)
    , Packkey        NVARCHAR(10)
    , UOM            NVARCHAR(10)  NULL
    , UOMQty         INT NULL   --WL01
    , TTLEA          INT NULL   --WL01
    , TTLCASE        INT NULL   --WL01
    , TTLQTY         INT NULL   --WL01
    , ExternOrderkey NVARCHAR(50)  NULL
    , C_Company      NVARCHAR(100)  NULL
    , C_Address1     NVARCHAR(100)  NULL
    , ID             NVARCHAR(50) NULL
    , IDQty          INT NULL
    , Loadkey        NVARCHAR(10)
    , Consigneekey   NVARCHAR(15)
    , PlaceOfLoading NVARCHAR(30) NULL   --WL01
    , MBOLKey        NVARCHAR(10) NULL   --WL01
   )

   DECLARE @TMP_PD AS TABLE ( Orderkey NVARCHAR(10), UOM NVARCHAR(10), UOMQty INT, Qty INT )

   SELECT @n_continue = 1
   SELECT @n_RowNo = 0
   SELECT @c_firstorderkey = N'N'

   SELECT @c_PreGenRptData = IIF(ISNULL(@c_PreGenRptData, '') IN ( '', '0' ), '', @c_PreGenRptData)

   IF EXISTS (  SELECT 1
                FROM PICKHEADER (NOLOCK)
                WHERE WaveKey = @c_Wavekey AND OrderKey IN (  SELECT OrderKey
                                                              FROM ORDERS oh WITH (NOLOCK)
                                                              WHERE oh.UserDefine09 = @c_Wavekey ))
   BEGIN
      SELECT @c_firsttime = N'N'
      SELECT @c_Printedflag = N'Y'
   END
   ELSE
   BEGIN
      SELECT @c_firsttime = N'Y'
      SELECT @c_Printedflag = N'N'
   END -- Record Not Exists

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN

   --SD01
   SELECT TOP 1 @c_Storerkey = OH.Storerkey
              , @c_Facility = OH.Facility   
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = WD.Orderkey
   WHERE WD.Wavekey = @c_Wavekey

   --WL01 S
   SELECT @n_ShowMBOLInfo = ISNULL(MAX(CASE WHEN Code = 'ShowMBOLInfo' AND Short = 'Y' THEN 1 ELSE 0 END) , 0)
   FROM CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'REPORTCFG' 
   AND Long = 'RPT_WV_PLIST_WAVE_034'
   AND Storerkey = @c_Storerkey
   --WL01 E

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
        , PICKDETAIL.ID
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
          , PICKDETAIL.ID
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
        , PICKDETAIL.ID
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
          , PICKDETAIL.ID
   ORDER BY PICKDETAIL.OrderKey

   OPEN pick_cur

   SELECT @c_PrevOrderKey = N''
   FETCH NEXT FROM pick_cur
   INTO @c_sku
      , @c_loc
      , @n_qty
      , @n_UOM3
      , @c_StorerKey
      , @c_Orderkey
      , @c_UOM
      , @c_PickMethod
      , @c_Lot
      , @n_UOMQty
      , @c_ID

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN --While
      IF @c_Orderkey <> @c_PrevOrderKey
      BEGIN
         IF TRIM(@c_Orderkey) = '' OR TRIM(@c_Orderkey) IS NULL
         BEGIN --if @c_Orderkey = ''
            SELECT @c_ConsigneeKey = N''
                 , @c_Externorderkey = N''
                 , @c_loadkey = N''
                 , @c_Priority = N''
                 , @c_Packkey = N''
                 , @c_Company = N''
                 , @c_Address1 = N''
         END --if @c_Orderkey=''
         ELSE
         BEGIN --if @c_Orderkey <> ''
            SELECT @c_ConsigneeKey = ORDERS.ConsigneeKey
                 , @c_Externorderkey = ORDERS.ExternOrderKey
                 , @c_loadkey = ORDERS.LoadKey
                 , @c_Priority = ORDERS.Priority
                 , @c_Company = ISNULL(ORDERS.C_Company,'')
                 , @c_Address1 = ISNULL(ORDERS.C_Address1,'')
            FROM ORDERS (NOLOCK)
            WHERE ORDERS.OrderKey = @c_Orderkey AND ORDERS.StorerKey = @c_StorerKey
         END -- IF @c_Orderkey <> ''

         IF  NOT EXISTS (  SELECT 1
                           FROM PICKHEADER (NOLOCK)
                           WHERE WaveKey = @c_Wavekey AND OrderKey = @c_Orderkey AND Zone = '3')
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
            VALUES (@c_pickheaderkey, @c_Orderkey, @c_Externorderkey, @c_StorerKey, @c_ConsigneeKey, @c_Wavekey
                  , @c_Priority, '5', '3', @c_loadkey, '')

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
            WHERE WaveKey = @c_Wavekey AND Zone = '3' AND OrderKey = @c_Orderkey
         END -- Exist in PickHeader
      END -- @c_Orderkey <> @c_PrevOrderKey

      SELECT @c_SkuDesc = ISNULL(SKU.DESCR, '')
           , @c_Packkey = PACK.PackKey
      FROM SKU (NOLOCK)
      JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
      WHERE SKU.StorerKey = @c_StorerKey AND SKU.Sku = @c_sku

      SELECT @n_RowNo = @n_RowNo + 1
      SELECT @n_Pallets = 0
           , @n_Cartons = 0
           , @n_Eaches = 0

      SET @n_TTLEA = 0
      SET @n_TTLCASES = 0
      SET @n_TTLQTY = 0

      IF NOT EXISTS ( SELECT 1
                      FROM @TMP_PD
                      WHERE Orderkey = @c_Orderkey )
      BEGIN
         INSERT INTO @TMP_PD (Orderkey, UOM, UOMQty, Qty)
         SELECT PD.OrderKey, PD.UOM, SUM(PD.UOMQty), SUM(PD.Qty)
         FROM PICKDETAIL PD WITH (NOLOCK)
         WHERE PD.OrderKey = @c_Orderkey 
         GROUP BY PD.OrderKey, PD.UOM
      END

      SELECT @n_TTLEA = SUM(PD.Qty)
      FROM @TMP_PD PD
      WHERE PD.OrderKey = @c_Orderkey 
      AND PD.UOM <> '1'

      SELECT @n_TTLCASES = SUM(PD.UOMQty)
      FROM @TMP_PD PD
      WHERE PD.OrderKey = @c_Orderkey 
      AND PD.UOM = '1'

      SELECT @n_TTLQTY = SUM(PD.Qty)
      FROM @TMP_PD PD
      WHERE PD.OrderKey = @c_Orderkey

      SELECT @n_IDQty = SUM(LLI.Qty)
      FROM PICKDETAIL PD (NOLOCK)
      INNER JOIN LOTxLOCxID LLI (NOLOCK) ON  PD.Lot = LLI.Lot
                                         AND PD.ID = LLI.Id
                                         AND PD.Storerkey = LLI.Storerkey
                                         AND PD.Sku = LLI.Sku
      WHERE PD.OrderKey = @c_Orderkey
      AND PD.ID = @c_ID

      SET @c_UOM = CASE @c_UOM WHEN '1' THEN 'PAL'
                               WHEN '6' THEN 'EA'
                               ELSE @c_UOM END

      --WL01 S
      IF @n_ShowMBOLInfo = 1
      BEGIN
         SELECT TOP 1 @c_PlaceOfLoading = ISNULL(MBOL.PlaceOfLoading, '')
                    , @c_MBOLKey = MBOL.MBOLKey
         FROM ORDERS WITH (NOLOCK)
         JOIN MBOL WITH (NOLOCK) ON ORDERS.MBOLKey = MBOL.MBOLKey
         WHERE ORDERS.Orderkey = @c_Orderkey
      END
      --WL01 E
      
      INSERT INTO #temp_wavepick37 (Wavekey, PrnDate, PickSlipNo, Zone, Printedflag
                                  , Storerkey, LOC, Lot, SkuDesc, Qty, SKU, Rpttitle
                                  , OrderKey, Packkey, UOM, UOMQty, TTLEA, TTLCASE, TTLQTY
                                  , ExternOrderkey, C_Company, C_Address1
                                  , ID, IDQty, Loadkey, Consigneekey
                                  , PlaceOfLoading, MBOLKey)   --WL01
      VALUES (@c_Wavekey, CONVERT(CHAR(16), [dbo].[fnc_ConvSFTimeZone](@c_StorerKey, @c_Facility, GETDATE()), 120), @c_pickheaderkey, '3', @c_Printedflag --SD01 
            , @c_StorerKey, @c_loc, @c_Lot, @c_SkuDesc, @n_qty, @c_sku, 'PickSlip by Orders'
            , @c_Orderkey, @c_Packkey, @c_UOM
            , @n_UOMQty, @n_TTLEA, @n_TTLCASES, @n_TTLQTY
            , @c_Externorderkey, @c_Company, @c_Address1
            , @c_ID, ISNULL(@n_IDQty,0), @c_Loadkey, @c_ConsigneeKey
            , @c_PlaceOfLoading, @c_MBOLKey)   --WL01

      SELECT @c_PrevOrderKey = @c_Orderkey

      FETCH NEXT FROM pick_cur
      INTO @c_sku
         , @c_loc
         , @n_qty
         , @n_UOM3
         , @c_StorerKey
         , @c_Orderkey
         , @c_UOM
         , @c_PickMethod
         , @c_Lot
         , @n_UOMQty
         , @c_ID
   END

   CLOSE pick_cur
   DEALLOCATE pick_cur

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN

   SUCCESS:
   IF ISNULL(@c_PreGenRptData, '') = ''
   BEGIN
      SELECT Wavekey
           , PrnDate
           , PickSlipNo
           , Zone
           , Printedflag
           , Storerkey
           , LOC
           , Lot
           , SkuDesc
           , Qty
           , SKU = TRIM(SKU)
           , Rpttitle
           , OrderKey
           , Packkey
           , UOM
           , UOMQty
           , TTLEA
           , TTLCASE
           , TTLQTY
           , ExternOrderkey
           , C_Company
           , C_Address1
           , ID
           , IDQty
           , TRIM(Wavekey) + TRIM(ISNULL(Pickslipno,'')) + TRIM(Orderkey) AS Group1
           , Loadkey
           , Consigneekey
           , PlaceOfLoading   --WL01
           , MBOLKey   --WL01
           , ShowMBOLInfo = @n_ShowMBOLInfo   --WL01
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_WV_PLIST_WAVE_034'
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