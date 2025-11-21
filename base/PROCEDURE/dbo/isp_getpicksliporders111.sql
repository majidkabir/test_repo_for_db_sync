SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Stored Proc : isp_GetPickSlipOrders111                                   */
/* Creation Date: 2020-04-08                                                */
/* Copyright: LFL                                                           */
/* Written by: WLChooi                                                      */
/*                                                                          */
/* Purpose: WMS-12809 - SG - MHD - Pickslip with SKU Image and SKU Notes    */
/*                                                                          */
/* Usage: Copy from nsp_GetPickSlipOrders03 and modify                      */
/*                                                                          */
/* Local Variables:                                                         */
/*                                                                          */
/* Called By: r_dw_print_pickorder111                                       */
/*                                                                          */
/* PVCS Version: 1.2                                                        */
/*                                                                          */
/* Version: 5.4                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date        Author      Ver   Purposes                                   */
/* 20-09-2021  MINGLE      1.1   WMS-17845 SG - MHD - Pickslip SKU          */
/*						                                    Description [CR]      */
/* 09-May-2023 WLChooi     1.2   WMS-22504 - Add new column (WL01)          */
/* 09-May-2023 WLChooi     1.2   DevOps Combine Script                      */
/****************************************************************************/

CREATE   PROC [dbo].[isp_GetPickSlipOrders111]
(@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_pickheaderkey      NVARCHAR(10)
         , @n_continue           INT
         , @c_errmsg             NVARCHAR(255)
         , @b_success            INT
         , @n_err                INT
         , @c_sku                NVARCHAR(22)
         , @n_qty                INT
         , @c_loc                NVARCHAR(10)
         , @n_cases              INT
         , @n_perpallet          INT
         , @c_storer             NVARCHAR(15)
         , @c_orderkey           NVARCHAR(10)
         , @c_ConsigneeKey       NVARCHAR(15)
         , @c_Company            NVARCHAR(45)
         , @c_Addr1              NVARCHAR(45)
         , @c_Addr2              NVARCHAR(45)
         , @c_Addr3              NVARCHAR(45)
         , @c_PostCode           NVARCHAR(15)
         , @c_Route              NVARCHAR(10)
         , @c_Route_Desc         NVARCHAR(60) -- RouteMaster.Desc      
         , @c_TrfRoom            NVARCHAR(5) -- LoadPlan.TrfRoom       
         , @c_Notes1             NVARCHAR(200)
         , @c_Notes2             NVARCHAR(200)
         , @c_SkuDesc            NVARCHAR(60)
         , @n_CaseCnt            INT
         , @n_PalletCnt          INT
         , @c_ReceiptTm          NVARCHAR(20)
         , @c_PrintedFlag        NVARCHAR(1)
         , @c_UOM                NVARCHAR(10)
         , @n_UOM3               INT
         , @c_Lot                NVARCHAR(10)
         , @c_StorerKey          NVARCHAR(15)
         , @c_Zone               NVARCHAR(1)
         , @n_PgGroup            INT
         , @n_TotCases           INT
         , @n_RowNo              INT
         , @c_PrevSKU            NVARCHAR(20)
         , @n_SKUCount           INT
         , @c_Carrierkey         NVARCHAR(60)
         , @c_VehicleNo          NVARCHAR(10)
         , @c_firstorderkey      NVARCHAR(10)
         , @c_superorderflag     NVARCHAR(1)
         , @c_firsttime          NVARCHAR(1)
         , @c_logicalloc         NVARCHAR(18)
         , @c_Lottable01         NVARCHAR(18)
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable03         NVARCHAR(18)
         , @d_Lottable04         DATETIME
         , @d_Lottable05         DATETIME
         , @n_packpallet         INT
         , @n_packcasecnt        INT
         , @c_externorderkey     NVARCHAR(50)
         , @n_pickslips_required INT
         , @dt_deliverydate      DATETIME
         , @n_TBLSkuPattern      INT
         , @n_SortBySkuLoc       INT
         , @c_PalletID           NVARCHAR(30)
         , @c_ExtraInfo          NVARCHAR(255) = N''
         , @n_SortByLoc          INT
         , @c_ConsigneeList      NVARCHAR(500)   --WL01
         , @c_Remark             NVARCHAR(50)    --WL01

   DECLARE @c_PrevOrderKey NVARCHAR(10)
         , @n_Pallets      INT
         , @n_Cartons      INT
         , @n_Eaches       INT
         , @n_UOMQty       INT
         , @c_Susr3        NVARCHAR(18)
         , @c_InvoiceNo    NVARCHAR(10)

   DECLARE @n_starttcnt INT
   SELECT @n_starttcnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SET @n_pickslips_required = 0

   SET @c_ExtraInfo = N'ôPLEASE USE/CHANGE TO BLACK CARTONö for HNWI customer'

   BEGIN TRAN
   CREATE TABLE #temp_pick
   (
      PickSlipNo        NVARCHAR(10)  NULL
    , LoadKey           NVARCHAR(10)
    , OrderKey          NVARCHAR(10)
    , ConsigneeKey      NVARCHAR(15)
    , Company           NVARCHAR(45)
    , Addr1             NVARCHAR(45)  NULL
    , Addr2             NVARCHAR(45)  NULL
    , Addr3             NVARCHAR(45)  NULL
    , PostCode          NVARCHAR(15)  NULL
    , Route             NVARCHAR(10)  NULL
    , Route_Desc        NVARCHAR(60)  NULL -- RouteMaster.Desc      
    , TrfRoom           NVARCHAR(5)   NULL -- LoadPlan.TrfRoom       
    , Notes1            NVARCHAR(200) NULL
    , Notes2            NVARCHAR(100) NULL
    , LOC               NVARCHAR(10)  NULL
    , SKU               NVARCHAR(22)
    , SkuDesc           NVARCHAR(60)
    , Qty               INT
    , TempQty1          INT
    , TempQty2          INT
    , PrintedFlag       NVARCHAR(1)   NULL
    , Zone              NVARCHAR(1)
    , PgGroup           INT
    , RowNum            INT
    , Lot               NVARCHAR(10)
    , Carrierkey        NVARCHAR(60)  NULL
    , VehicleNo         NVARCHAR(10)  NULL
    , Lottable01        NVARCHAR(18)  NULL
    , Lottable02        NVARCHAR(18)  NULL
    , Lottable03        NVARCHAR(18)  NULL
    , Lottable04        DATETIME      NULL
    , Lottable05        DATETIME      NULL
    , packpallet        INT
    , packcasecnt       INT
    , externorderkey    NVARCHAR(50)  NULL
    , LogicalLoc        NVARCHAR(18)  NULL
    , DeliveryDate      DATETIME      NULL
    , Uom               NVARCHAR(10)
    , Susr3             NVARCHAR(18)  NULL
    , InvoiceNo         NVARCHAR(10)  NULL
    , Ovas              CHAR(30)      NULL
    , SortBySkuLoc      INT           NULL
    , ShowAltSku        INT           NULL
    , AltSku            NVARCHAR(20)  NULL
    , ShowExtOrdBarcode INT           NULL
    , HideSusr3         INT           NULL
    , ShowField         INT           NULL
    , ODUdef02          NVARCHAR(30)
    , PickZone          NVARCHAR(10)
    , ShowPalletID      INT           NULL
    , PalletID          NVARCHAR(30)
    , ShowSKUBusr10     INT
    , SKUBusr10         NVARCHAR(30)
    , ShowExtraInfo     INT
    , ShowExtraSKUInfo  INT
    , RetailSKU         NVARCHAR(20)
    , ManufacturerSKU   NVARCHAR(20)
    , SortByLoc         INT           NULL
    , SKUBUSR4          NVARCHAR(200)
    , SKUNotes1         NVARCHAR(255)
    , SKUNotes2         NVARCHAR(255)
    , Remark            NVARCHAR(50)   --WL01
   )

   SELECT Storerkey
        , TBLSkuPattern = ISNULL(MAX(CASE WHEN Code = 'TBLSKUPATTERN' THEN 1
                                          ELSE 0 END)
                               , 0)
        , SortBySkuLoc = ISNULL(MAX(CASE WHEN Code = 'SortBySkuLoc' THEN 1
                                         ELSE 0 END)
                              , 0)
        , ShowAltSku = ISNULL(MAX(CASE WHEN Code = 'ShowAltSku' THEN 1
                                       ELSE 0 END)
                            , 0)
        , ShowExtOrdBarcode = ISNULL(MAX(CASE WHEN Code = 'ShowExtOrdKeyBarcode' THEN 1
                                              ELSE 0 END)
                                   , 0)
        , HideSusr3 = ISNULL(MAX(CASE WHEN Code = 'HIDESUSR3' THEN 1
                                      ELSE 0 END)
                           , 0)
        , ShowField = ISNULL(MAX(CASE WHEN Code = 'SHOWFIELD' THEN 1
                                      ELSE 0 END)
                           , 0)
        , PageBreakByPickZone = ISNULL(MAX(CASE WHEN Code = 'PageBreakByPickZone' THEN 1
                                                ELSE 0 END)
                                     , 0)
        , ShowPalletID = ISNULL(MAX(CASE WHEN Code = 'ShowPalletID' THEN 1
                                         ELSE 0 END)
                              , 0)
        , showskubusr10 = ISNULL(MAX(CASE WHEN Code = 'SHOWSKUBUSR10' THEN 1
                                          ELSE 0 END)
                               , 0)
        , ShowExtraInfo = ISNULL(MAX(CASE WHEN Code = 'ShowExtraInfo' THEN 1
                                          ELSE 0 END)
                               , 0)
        , ShowExtraSKUInfo = ISNULL(MAX(CASE WHEN Code = 'ShowExtraSKUInfo' THEN 1
                                             ELSE 0 END)
                                  , 0)
        , SORTBYLOC = ISNULL(MAX(CASE WHEN Code = 'SORTBYLOC' THEN 1
                                      ELSE 0 END)
                           , 0)
   INTO #TMP_RPTCFG
   FROM CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'REPORTCFG' AND Long = 'r_dw_print_pickorder111' AND (Short IS NULL OR Short <> 'N')
   GROUP BY Storerkey

   --WL01 S
   DECLARE @T_Consignee TABLE (Storerkey NVARCHAR(15), Consignee NVARCHAR(15), Remark NVARCHAR(50) )

   SELECT @c_StorerKey = ORDERS.StorerKey
   FROM LOADPLANDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = LOADPLANDETAIL.OrderKey
   WHERE LOADPLANDETAIL.LoadKey = @c_loadkey

   SELECT @c_ConsigneeList = ISNULL(CODELKUP.Notes,'')
        , @c_Remark        = ISNULL(CODELKUP.Notes2,'')
   FROM CODELKUP (NOLOCK)
   WHERE LISTNAME = 'REPORTCFG' 
   AND Long = 'r_dw_print_pickorder111'
   AND Storerkey = @c_StorerKey
   AND (Short IS NULL OR Short <> 'N')
   AND CODE = 'ShowRemark'

   INSERT INTO @T_Consignee (Storerkey, Consignee, Remark)
   SELECT @c_StorerKey, ColValue, @c_Remark
   FROM dbo.fnc_DelimSplit(',',@c_ConsigneeList) FDS
   --WL01 E

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order      
   IF EXISTS (  SELECT 1
                FROM PICKHEADER (NOLOCK)
                WHERE ExternOrderKey = @c_loadkey AND Zone = '3')
   BEGIN
      SELECT @c_firsttime = N'N'
      SELECT @c_PrintedFlag = N'Y'
   END
   ELSE
   BEGIN
      SELECT @c_firsttime = N'Y'
      SELECT @c_PrintedFlag = N'N'
   END -- Record Not Exists      

   INSERT INTO #temp_pick (PickSlipNo, LoadKey, OrderKey, ConsigneeKey, Company, Addr1, Addr2, PgGroup, Addr3, PostCode
                         , Route, Route_Desc, TrfRoom, Notes1, RowNum, Notes2, LOC, SKU, SkuDesc, Qty, TempQty1
                         , TempQty2, PrintedFlag, Zone, Lot, Carrierkey, VehicleNo, Lottable01, Lottable02, Lottable03
                         , Lottable04, Lottable05, packpallet, packcasecnt, externorderkey, LogicalLoc, DeliveryDate
                         , Uom, Susr3, InvoiceNo, Ovas, SortBySkuLoc, ShowAltSku, AltSku, ShowExtOrdBarcode, HideSusr3
                         , ShowField, ODUdef02, PickZone, ShowPalletID, PalletID, ShowSKUBusr10, SKUBusr10
                         , ShowExtraInfo, ShowExtraSKUInfo, RetailSKU, ManufacturerSKU, SortByLoc, SKUBUSR4, SKUNotes1
                         , SKUNotes2, Remark) --WL01
   SELECT (  SELECT PickHeaderKey
             FROM PICKHEADER (NOLOCK)
             WHERE ExternOrderKey = @c_loadkey AND OrderKey = PICKDETAIL.OrderKey AND Zone = '3')
        , @c_loadkey AS LoadKey
        , PICKDETAIL.OrderKey
        , ISNULL(ORDERS.BillToKey, '') AS ConsigneeKey
        , ISNULL(ORDERS.C_Company, '') AS Company
        , ISNULL(ORDERS.C_Address1, '') AS Addr1
        , ISNULL(ORDERS.C_Address2, '') AS Addr2
        , 0 AS PgGroup
        , ISNULL(ORDERS.C_Address3, '') AS Addr3
        , ISNULL(ORDERS.C_Zip, '') AS PostCode
        , ISNULL(ORDERS.Route, '') AS Route
        , ISNULL(RouteMaster.Descr, '') Route_Desc
        , ORDERS.Door AS TrfRoom
        , CONVERT(NVARCHAR(200), ISNULL(ORDERS.Notes, '')) Notes1
        , 0 AS RowNo
        , CONVERT(NVARCHAR(200), ISNULL(ORDERS.Notes2, '')) Notes2
        , PICKDETAIL.Loc
        , CASE WHEN ISNULL(TBLSkuPattern, 0) = 0 THEN PICKDETAIL.Sku
               WHEN ISNULL(TBLSkuPattern, 0) = 1 AND SKU.itemclass LIKE '%FT%' THEN
                  SUBSTRING(SKU.Style, 5, 6) + '-' + ISNULL(RTRIM(SKU.Measurement), '') + '-'
                  + SUBSTRING(SKU.Sku, 12, 1) + '-' + ISNULL(RTRIM(SKU.Size), '')
               ELSE
                  SUBSTRING(SKU.Style, 5, 6) + '-' + ISNULL(RTRIM(SKU.Color), '') + '-' + SUBSTRING(SKU.Sku, 12, 1)
                  + '-' + ISNULL(RTRIM(SKU.Size), '')END AS 'SKU'
        , ISNULL(SKU.DESCR, '') SkuDesc
        , SUM(PICKDETAIL.Qty) AS Qty
        , CASE PICKDETAIL.UOM
               WHEN '1' THEN PACK.Pallet
               WHEN '2' THEN PACK.CaseCnt
               WHEN '3' THEN PACK.InnerPack
               ELSE 1 END AS UOMQty
        , 0 AS TempQty2
        , ISNULL((  SELECT DISTINCT 'Y'
                    FROM PICKHEADER (NOLOCK)
                    WHERE ExternOrderKey = @c_loadkey AND Zone = '3')
               , 'N') AS PrintedFlag
        , '3' Zone
        , PICKDETAIL.Lot
        , '' CarrierKey
        , '' AS VehicleNo
        , LOTATTRIBUTE.Lottable01
        , LOTATTRIBUTE.Lottable02
        , LOTATTRIBUTE.Lottable03
        , ISNULL(LOTATTRIBUTE.Lottable04, '19000101') Lottable04
        , ISNULL(LOTATTRIBUTE.Lottable05, '19000101') Lottable05
        , PACK.Pallet
        , PACK.CaseCnt
        , ORDERS.ExternOrderKey AS ExternOrderKey
        , ISNULL(LOC.LogicalLocation, '') AS LogicalLocation
        , ISNULL(ORDERS.DeliveryDate, '19000101') DeliveryDate
        , PACK.PackUOM3
        , CASE WHEN ISNULL(HideSusr3, 0) = 1 THEN ''
               ELSE SKU.SUSR3 END
        , ORDERS.InvoiceNo
        , CASE WHEN SKU.SUSR4 = 'SSCC' THEN '**Scan Serial No** ' + RTRIM(ISNULL(SKU.OVAS, ''))
               ELSE SKU.OVAS END
        , ISNULL(SortBySkuLoc, 0)
        , ISNULL(ShowAltSku, 0)
        , ISNULL(SKU.ALTSKU, '')
        , ISNULL(ShowExtOrdBarcode, 0)
        , ISNULL(HideSusr3, 0)
        , ISNULL(ShowField, 0)
        , ISNULL(ORDERDETAIL.UserDefine02, '')
        , PickZone = CASE WHEN ISNULL(RC.PageBreakByPickZone, 0) = 1 THEN LOC.PickZone
                          ELSE '' END
        , ISNULL(ShowPalletID, 0)
        , PICKDETAIL.ID
        , ISNULL(RC.showskubusr10, 0)
        , ISNULL(SKU.BUSR10, '')
        , ISNULL(RC.ShowExtraInfo, 0)
        , ISNULL(RC.ShowExtraSKUInfo, 0)
        , SKU.RETAILSKU
        , SKU.MANUFACTURERSKU
        , ISNULL(SORTBYLOC, 0)
        , ISNULL(SKU.BUSR4, '') AS SKUBUSR4
        , LEFT(ISNULL(SKU.NOTES1, ''), 255) AS SKUNotes1
        , LEFT(ISNULL(SKU.NOTES2, ''), 255) AS SKUNotes2
        , ISNULL(TC.Remark,'') AS Remark   --WL01
   FROM LoadPlanDetail (NOLOCK)
   JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = LoadPlanDetail.OrderKey)
   JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
   LEFT OUTER JOIN RouteMaster ON (RouteMaster.Route = ORDERS.Route)
   JOIN PICKDETAIL (NOLOCK) ON (   PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey
                               AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
   JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
   JOIN SKU (NOLOCK) ON (SKU.StorerKey = PICKDETAIL.Storerkey AND SKU.Sku = PICKDETAIL.Sku)
   JOIN PACK (NOLOCK) ON (SKU.PACKKey = PACK.PackKey)
   JOIN LOC (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
   LEFT JOIN #TMP_RPTCFG RC ON (ORDERS.StorerKey = RC.Storerkey)
   LEFT JOIN @T_Consignee TC ON (TC.Consignee = ORDERS.ConsigneeKey AND TC.Storerkey = ORDERS.StorerKey)   --WL01
   WHERE PICKDETAIL.Status >= '0' AND LoadPlanDetail.LoadKey = @c_loadkey
   GROUP BY PICKDETAIL.OrderKey
          , ISNULL(ORDERS.BillToKey, '')
          , ISNULL(ORDERS.C_Company, '')
          , ISNULL(ORDERS.C_Address1, '')
          , ISNULL(ORDERS.C_Address2, '')
          , ISNULL(ORDERS.C_Address3, '')
          , ISNULL(ORDERS.C_Zip, '')
          , ISNULL(ORDERS.Route, '')
          , ISNULL(RouteMaster.Descr, '')
          , ORDERS.Door
          , CONVERT(NVARCHAR(200), ISNULL(ORDERS.Notes, ''))
          , CONVERT(NVARCHAR(200), ISNULL(ORDERS.Notes2, ''))
          , PICKDETAIL.Loc
          , CASE WHEN ISNULL(TBLSkuPattern, 0) = 0 THEN PICKDETAIL.Sku
                 WHEN ISNULL(TBLSkuPattern, 0) = 1 AND SKU.itemclass LIKE '%FT%' THEN
                    SUBSTRING(SKU.Style, 5, 6) + '-' + ISNULL(RTRIM(SKU.Measurement), '') + '-'
                    + SUBSTRING(SKU.Sku, 12, 1) + '-' + ISNULL(RTRIM(SKU.Size), '')
                 ELSE
                    SUBSTRING(SKU.Style, 5, 6) + '-' + ISNULL(RTRIM(SKU.Color), '') + '-' + SUBSTRING(SKU.Sku, 12, 1)
                    + '-' + ISNULL(RTRIM(SKU.Size), '')END
          , ISNULL(SKU.DESCR, '')
          , CASE PICKDETAIL.UOM
                 WHEN '1' THEN PACK.Pallet
                 WHEN '2' THEN PACK.CaseCnt
                 WHEN '3' THEN PACK.InnerPack
                 ELSE 1 END
          , PICKDETAIL.Lot
          , LOTATTRIBUTE.Lottable01
          , LOTATTRIBUTE.Lottable02
          , LOTATTRIBUTE.Lottable03
          , ISNULL(LOTATTRIBUTE.Lottable04, '19000101')
          , ISNULL(LOTATTRIBUTE.Lottable05, '19000101')
          , PACK.Pallet
          , PACK.CaseCnt
          , ORDERS.ExternOrderKey
          , ISNULL(LOC.LogicalLocation, '')
          , ISNULL(ORDERS.DeliveryDate, '19000101')
          , PACK.PackUOM3
          , SKU.SUSR3
          , ORDERS.InvoiceNo
          , CASE WHEN SKU.SUSR4 = 'SSCC' THEN '**Scan Serial No** ' + RTRIM(ISNULL(SKU.OVAS, ''))
                 ELSE SKU.OVAS END
          , ISNULL(SortBySkuLoc, 0)
          , ISNULL(ShowAltSku, 0)
          , ISNULL(SKU.ALTSKU, '')
          , ISNULL(ShowExtOrdBarcode, 0)
          , ISNULL(HideSusr3, 0)
          , ISNULL(ShowField, 0)
          , ISNULL(ORDERDETAIL.UserDefine02, '')
          , CASE WHEN ISNULL(RC.PageBreakByPickZone, 0) = 1 THEN LOC.PickZone
                 ELSE '' END
          , ISNULL(ShowPalletID, 0)
          , PICKDETAIL.ID
          , ISNULL(RC.showskubusr10, 0)
          , ISNULL(SKU.BUSR10, '')
          , ISNULL(RC.ShowExtraInfo, 0)
          , ISNULL(RC.ShowExtraSKUInfo, 0)
          , SKU.RETAILSKU
          , SKU.MANUFACTURERSKU
          , ISNULL(SORTBYLOC, 0)
          , ISNULL(SKU.BUSR4, '')
          , LEFT(ISNULL(SKU.NOTES1, ''), 255)
          , LEFT(ISNULL(SKU.NOTES2, ''), 255)
          , ISNULL(TC.Remark,'')   --WL01

   BEGIN TRAN
   -- Uses PickType as a Printed Flag         
   UPDATE PICKHEADER
   SET PickType = '1'
     , TrafficCop = NULL
   WHERE ExternOrderKey = @c_loadkey AND Zone = '3' AND PickType = '0'

   SELECT @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      IF @@TRANCOUNT >= 1
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      IF @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      -- SELECT @c_PrintedFlag = "Y"      
      END
      ELSE
      BEGIN
         SELECT @n_continue = 3
         ROLLBACK TRAN
      END
   END

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
   FROM #temp_pick
   WHERE ISNULL(RTRIM(PickSlipNo), '') = ''

   IF @@ERROR <> 0
   BEGIN
      GOTO FAILURE
   END
   ELSE IF @n_pickslips_required > 0
   BEGIN
      BEGIN TRAN
      EXECUTE nspg_GetKey 'PICKSLIP'
                        , 9
                        , @c_pickheaderkey OUTPUT
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
                        , 0
                        , @n_pickslips_required
      COMMIT TRAN

      BEGIN TRAN
      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
      SELECT 'P'
             + RIGHT(REPLICATE('0', 9)
                     + dbo.fnc_LTRIM(
                          dbo.fnc_RTRIM(
                             STR(
                                CAST(@c_pickheaderkey AS INT)
                                + (  SELECT COUNT(DISTINCT OrderKey)
                                     FROM #temp_pick AS Rank
                                     WHERE Rank.OrderKey < #temp_pick.OrderKey
                                     AND   ISNULL(RTRIM(Rank.PickSlipNo), '') = '')) -- str      
                          )) -- dbo.fnc_RTrim      
         , 9)
           , OrderKey
           , LoadKey
           , '0'
           , '3'
           , ''
      FROM #temp_pick
      WHERE ISNULL(RTRIM(PickSlipNo), '') = ''
      GROUP BY LoadKey
             , OrderKey

      UPDATE #temp_pick
      SET PickSlipNo = PICKHEADER.PickHeaderKey
      FROM PICKHEADER (NOLOCK)
      WHERE PICKHEADER.ExternOrderKey = #temp_pick.LoadKey
      AND   PICKHEADER.OrderKey = #temp_pick.OrderKey
      AND   PICKHEADER.Zone = '3'
      AND   ISNULL(RTRIM(#temp_pick.PickSlipNo), '') = ''

      UPDATE PICKDETAIL
      SET PickSlipNo = #temp_pick.PickSlipNo
        , TrafficCop = NULL
      FROM #temp_pick
      WHERE #temp_pick.OrderKey = PICKDETAIL.OrderKey AND ISNULL(RTRIM(PICKDETAIL.PickSlipNo), '') = ''

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END
   GOTO SUCCESS

   FAILURE:
   DELETE FROM #temp_pick
   SUCCESS:
   SELECT PickSlipNo
        , LoadKey
        , OrderKey
        , ConsigneeKey
        , Company
        , Addr1
        , Addr2
        , Addr3
        , PostCode
        , [Route]
        , Route_Desc
        , TrfRoom
        , Notes1
        , Notes2
        , LOC
        , SKU
        , SkuDesc
        , Qty
        , TempQty1
        , TempQty2
        , PrintedFlag
        , Zone
        , PgGroup
        , RowNum
        , Lot
        , Carrierkey
        , VehicleNo
        , Lottable01
        , Lottable02
        , Lottable03
        , Lottable04
        , Lottable05
        , packpallet
        , packcasecnt
        , externorderkey
        , LogicalLoc
        , DeliveryDate
        , Uom
        , Susr3
        , InvoiceNo
        , Ovas
        , SortBySkuLoc
        , ShowAltSku
        , AltSku
        , ShowExtOrdBarcode
        , HideSusr3
        , ShowField
        , ODUdef02
        , PickZone
        , ShowPalletID
        , PalletID
        , ShowSKUBusr10
        , SKUBusr10
        , CASE WHEN ISNULL(ShowExtraInfo, 0) = 1 THEN CASE WHEN ISNULL(Remark,'') = '' THEN @c_ExtraInfo   --WL01
                                                           ELSE '' END   --WL01
               ELSE '' END AS ExtraInfo
        , CASE WHEN ISNULL(ShowExtraSKUInfo, 0) = 1 THEN RetailSKU
               ELSE '' END AS RetailSKU
        , CASE WHEN ISNULL(ShowExtraSKUInfo, 0) = 1 THEN ManufacturerSKU
               ELSE '' END AS ManufacturerSKU
        , SKUBUSR4
        , SKUNotes1
        , SKUNotes2
        , Remark = ISNULL(Remark,'')   --WL01
   FROM #temp_pick
   ORDER BY Company
          , OrderKey
          , PickZone
          , Susr3
          , CASE WHEN SortBySkuLoc = 1 AND SortByLoc = 0 THEN SKU
                 ELSE '' END
          , CASE WHEN SortBySkuLoc = 1 OR SortByLoc = 1 THEN ''
                 ELSE LogicalLoc END
          , LOC
          , CASE WHEN SortBySkuLoc = 1 THEN ''
                 ELSE SKU END
          , Lottable01
   --DROP Table #TEMP_PICK      

   WHILE @@TRANCOUNT < @n_starttcnt
   BEGIN
      BEGIN TRAN
   END

   IF OBJECT_ID('tempdb..#TEMP_PICK') IS NOT NULL
      DROP TABLE #temp_pick
END

GO