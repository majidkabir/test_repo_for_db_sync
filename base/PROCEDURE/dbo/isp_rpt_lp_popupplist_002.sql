SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*****************************************************************************/
/* Stored Procedure: isp_RPT_LP_POPUPPLIST_002                               */
/* Creation Date: 19-MAY-2022                                                */
/* Copyright: MAERSK                                                         */
/* Written by: WZPang                                                        */
/*                                                                           */
/* Purpose: WMS-23271 - Convert to LogiReport-r_dw_print_pickorder52(MY)     */
/*                                                                           */
/* Called By: RPT_LP_POPUPPLIST_002                                          */
/*                                                                           */
/* PVCS Version: 1.3                                                         */
/*                                                                           */
/* Version: 7.0                                                              */
/*                                                                           */
/* Data Modifications:                                                       */
/*                                                                           */
/* Updates:                                                                  */
/* Date         Author   Ver  Purposes                                       */
/* 19-May-2022  WZPang   1.0  DevOps Combine Script                          */
/* 24-Aug-2023  WLChooi  1.1  UWP-6883 - Bug Fix (WL01)                      */
/* 15-Sep-2023  WLChooi  1.2  WMS-23640 - Show Style & Size (WL02)           */
/* 26-Sep-2023  WLChooi  1.3  UWP-8577 - Show ExtField04 (WL03)              */
/* 19-Sep-2023  Calvin   1.4  INC6339467 Expand var to fit sif.ext04 (CLVN01)*/
/* 05-Sep-2024  XLL      1.5  UWP-24051 - Global Timezone(XLL01)             */
/*****************************************************************************/
CREATE     PROC [dbo].[isp_RPT_LP_POPUPPLIST_002]
(@c_Loadkey NVARCHAR(10))
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS ON

   DECLARE @c_pickheaderkey      NVARCHAR(10)
         , @n_continue           INT
         , @c_errmsg             NVARCHAR(255)
         , @b_success            INT
         , @n_err                INT
         , @c_sku                NVARCHAR(20)
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
         , @c_Notes1             NVARCHAR(60)
         , @c_Notes2             NVARCHAR(60)
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
         , @c_Lottable02         NVARCHAR(10)
         , @d_Lottable04         DATETIME
         , @n_packpallet         INT
         , @n_packcasecnt        INT
         , @c_externorderkey     NVARCHAR(50)
         , @n_pickslips_required INT
         , @c_areakey            NVARCHAR(10)
         , @c_skugroup           NVARCHAR(10)
         , @c_Pickzone           NVARCHAR(10)
         , @c_PrevPickzone       NVARCHAR(10)
         , @c_Pickslipno         NVARCHAR(10)
         , @c_Pickdetailkey      NVARCHAR(10)
         , @c_ExecStatement      NVARCHAR(4000)
         , @c_OrderLineNumber    NVARCHAR(5)
         , @c_Type               NVARCHAR(1)   = N'1'
         , @c_DataWindow         NVARCHAR(60)  = N'RPT_LP_POPUPPLIST_002'
         , @c_RetVal             NVARCHAR(255)

   DECLARE @c_PrevOrderKey NVARCHAR(10)
         , @n_Pallets      INT
         , @n_Cartons      INT
         , @n_Eaches       INT
         , @n_UOMQty       INT

   SELECT @c_StorerKey = ORDERS.StorerKey
   FROM ORDERS (NOLOCK)
   JOIN LoadPlanDetail (NOLOCK) ON LoadPlanDetail.OrderKey = ORDERS.OrderKey
   WHERE LoadPlanDetail.LoadKey = @c_Loadkey

   EXEC [dbo].[isp_GetCompanyInfo] @c_Storerkey = @c_StorerKey
                                 , @c_Type = @c_Type
                                 , @c_DataWindow = @c_DataWindow
                                 , @c_RetVal = @c_RetVal OUTPUT

   CREATE TABLE #TEMP_PICK
   (
      PickSlipNo            NVARCHAR(10) NULL
    , LoadKey               NVARCHAR(10)
    , OrderKey              NVARCHAR(10)
    , ConsigneeKey          NVARCHAR(15)
    , Company               NVARCHAR(45)
    , Addr1                 NVARCHAR(45) NULL
    , Addr2                 NVARCHAR(45) NULL
    , Addr3                 NVARCHAR(45) NULL
    , PostCode              NVARCHAR(15) NULL
    , Route                 NVARCHAR(10) NULL
    , Route_Desc            NVARCHAR(60) NULL
    , TrfRoom               NVARCHAR(5)  NULL
    , Notes1                NVARCHAR(60) NULL
    , Notes2                NVARCHAR(60) NULL
    , LOC                   NVARCHAR(10) NULL
    , ID                    NVARCHAR(18) NULL
    , SKU                   NVARCHAR(50)   --WL02
    , SkuDesc               NVARCHAR(60)
    , Qty                   INT
    , TempQty1              INT
    , TempQty2              INT
    , PrintedFlag           NVARCHAR(1)  NULL
    , Zone                  NVARCHAR(2)
    , PgGroup               INT
    , RowNum                INT
    , Lot                   NVARCHAR(10)
    , Carrierkey            NVARCHAR(60) NULL
    , VehicleNo             NVARCHAR(10) NULL
    , Lottable02            NVARCHAR(18) NULL
    , Lottable04            DATETIME     NULL
    , packpallet            INT
    , packcasecnt           INT
    , packinner             INT
    , packeaches            INT
    , externorderkey        NVARCHAR(50) NULL
    , LogicalLoc            NVARCHAR(18) NULL
    , Areakey               NVARCHAR(10) NULL
    , UOM                   NVARCHAR(10)
    , Pallet_cal            INT
    , Cartons_cal           INT
    , inner_cal             INT
    , Each_cal              INT
    , Total_cal             INT
    , DeliveryDate          NVARCHAR(10) NULL
    , RetailSku             NVARCHAR(20) NULL
    , BuyerPO               NVARCHAR(20) NULL
    , InvoiceNo             NVARCHAR(10) NULL
    , OrderDate             DATETIME     NULL
    , Susr4                 NVARCHAR(18) NULL
    , vat                   NVARCHAR(18) NULL
    , OVAS                  NVARCHAR(30) NULL
    , SKUGROUP              NVARCHAR(30) NULL --(CLVN01)
    , ContainerType         NVARCHAR(20) NULL
    , Pickzone              NVARCHAR(10) NULL
    , Priority              NVARCHAR(250)
    , ExtendRouteDescLength NVARCHAR(10)
    , Logo                  NVARCHAR(50)
    , SKUTitle              NVARCHAR(50)   --WL02
    , SKUGroupTitle         NVARCHAR(50)   --WL03
    , CurrentDateTime       DATETIME     NULL --XLL01
   )

   INSERT INTO #TEMP_PICK (PickSlipNo, LoadKey, OrderKey, ConsigneeKey, Company, Addr1, Addr2, PgGroup, Addr3, PostCode
                         , Route, Route_Desc, TrfRoom, Notes1, RowNum, Notes2, LOC, ID, SKU, SkuDesc, Qty, TempQty1
                         , TempQty2, PrintedFlag, Zone, Lot, Carrierkey, VehicleNo, Lottable02, Lottable04, packpallet
                         , packcasecnt, packinner, packeaches, externorderkey, LogicalLoc, Areakey, UOM, Pallet_cal
                         , Cartons_cal, inner_cal, Each_cal, Total_cal, DeliveryDate, RetailSku, BuyerPO, InvoiceNo
                         , OrderDate, Susr4, vat, OVAS, SKUGROUP, ContainerType, Pickzone, Priority
                         , ExtendRouteDescLength, Logo, SKUTitle, SKUGroupTitle,CurrentDateTime)   --WL02   --WL03  --XLL01
   SELECT RefKeyLookup.Pickslipno
        , @c_Loadkey AS LoadKey
        , PICKDETAIL.OrderKey
        , ISNULL(ORDERS.ConsigneeKey, '') AS ConsigneeKey
        , ISNULL(ORDERS.C_Company, '') AS Company
        , ISNULL(ORDERS.C_Address1, '') AS Addr1
        , ISNULL(ORDERS.C_Address2, '') AS Addr2
        , 0 AS PgGroup
        , ISNULL(ORDERS.C_Address3, '') AS Addr3
        , ISNULL(ORDERS.C_Zip, '') AS PostCode
        , ISNULL(ORDERS.Route, '') AS Route
        , ISNULL(RouteMaster.Descr, '') Route_Desc
        , ORDERS.Door AS TrfRoom
        , CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')) Notes1
        , 0 AS RowNo
        , CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) Notes2
        , PICKDETAIL.Loc
        , PICKDETAIL.ID
        , IIF(ISNULL(CL2.Short, 'N') = 'Y', ISNULL(TRIM(SKU.Style),'') + ' - ' + ISNULL(TRIM(SKU.Size),''), PICKDETAIL.Sku) AS Sku   --WL02
        , ISNULL(SKU.DESCR, '') SkuDescr
        , SUM(PICKDETAIL.Qty) AS Qty
        , 1 AS UOMQTY
        , 0 AS TempQty2
        , ISNULL(
          (  SELECT DISTINCT 'Y'
             FROM PICKHEADER WITH (NOLOCK)
             WHERE PickHeaderKey = RefKeyLookup.Pickslipno AND OrderKey = PICKDETAIL.OrderKey AND Zone = 'LP')
        , 'N') AS PrintedFlag
        , 'LP' Zone
        , PICKDETAIL.Lot
        , '' CarrierKey
        , '' AS VehicleNo
        , LOTATTRIBUTE.Lottable02
        , ISNULL([dbo].[fnc_ConvSFTimeZone](PICKDETAIL.Storerkey, ORDERS.Facility, LOTATTRIBUTE.Lottable04), '19000101') --XLL01
        , PACK.Pallet
        , PACK.CaseCnt
        , PACK.InnerPack
        , PACK.Qty
        , ORDERS.ExternOrderKey AS ExternOrderKey
        , ISNULL(LOC.LogicalLocation, '') AS LogicalLocation
        , ISNULL(AreaDetail.AreaKey, '00') AS Areakey
        , ISNULL(ORDERDETAIL.UOM, '') AS UOM
        , Pallet_cal = CASE PACK.Pallet
                            WHEN 0 THEN 0
                            ELSE FLOOR(SUM(PICKDETAIL.Qty) / PACK.Pallet)END
        , Cartons_cal = 0
        , inner_cal = 0
        , Each_cal = 0
        , Total_cal = SUM(PICKDETAIL.Qty)
        , CONVERT(
             NVARCHAR(10)
           , CASE WHEN ORDERS.DocType = 'E' OR ISNULL(ORDERS.UserDefine03, '') = '' THEN
                     ISNULL([dbo].[fnc_ConvSFTimeZone](PICKDETAIL.Storerkey, ORDERS.Facility, ORDERS.DeliveryDate), '19000101') -- XLL01
                  ELSE IIF(ISDATE(ORDERS.UserDefine03) = 1, CAST(ORDERS.UserDefine03 AS DATETIME), '19000101') END   --WL01
           , 103)       
        , CASE WHEN ISNULL(SKU.RETAILSKU, '') = '' THEN ISNULL(SKU.ALTSKU, '')
               ELSE SKU.RETAILSKU END AS RetailSku
        , ISNULL(ORDERS.BuyerPO, '') BuyerPO
        , ISNULL(ORDERS.InvoiceNo, '') InvoiceNo
        , ISNULL([dbo].[fnc_ConvSFTimeZone](PICKDETAIL.Storerkey, ORDERS.Facility, ORDERS.OrderDate), '19000101') OrderDate --XLL01
        , SKU.SUSR4
        , st.VAT
        , SKU.OVAS
        , IIF(ISNULL(CL3.Short, 'N') = 'Y', SIF.ExtendedField04, SKU.SKUGROUP) AS SKUGROUP   --WL03
        , ORDERS.ContainerType
        , LOC.Pickzone
        , CASE WHEN ISNULL(CODELKUP.Long, '') = '' THEN ORDERS.Priority
               ELSE CODELKUP.Long END
        , ISNULL(CL1.Short, 'N') AS ExtendRouteDescLength
        , ISNULL(@c_RetVal, '') AS Logo
        , IIF(ISNULL(CL2.Short, 'N') = 'Y', 'Style - Size', 'Sku') AS SKUTitle   --WL02
        , IIF(ISNULL(CL3.Short, 'N') = 'Y', 'ExtendedField04', 'SKU Group') AS SKUGroupTitle   --WL03
        , [dbo].[fnc_ConvSFTimeZone](PICKDETAIL.Storerkey, ORDERS.Facility, GETDATE())  AS CurrentDateTime  --XLL01
   FROM PICKDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey
   JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
   JOIN LoadPlanDetail (NOLOCK) ON PICKDETAIL.OrderKey = LoadPlanDetail.OrderKey
   JOIN ORDERDETAIL (NOLOCK) ON  PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey
                             AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber
   JOIN STORER (NOLOCK) ON PICKDETAIL.Storerkey = STORER.StorerKey
   JOIN SKU (NOLOCK) ON PICKDETAIL.Sku = SKU.Sku AND PICKDETAIL.Storerkey = SKU.StorerKey
   JOIN PACK (NOLOCK) ON PICKDETAIL.PackKey = PACK.PackKey
   JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc
   LEFT OUTER JOIN RouteMaster (NOLOCK) ON ORDERS.Route = RouteMaster.Route
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON LOC.PutawayZone = AreaDetail.PutawayZone
   LEFT OUTER JOIN STORER st (NOLOCK) ON ORDERS.ConsigneeKey = st.StorerKey
   LEFT OUTER JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailkey = PICKDETAIL.PickDetailKey)
   LEFT JOIN CODELKUP WITH (NOLOCK) ON CODELKUP.LISTNAME = 'ORDRPRIOR' AND CODELKUP.Code = ORDERS.Priority
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON  CL1.LISTNAME = 'REPORTCFG'
                                        AND CL1.Code = 'ExtendRouteDescLength'
                                        AND CL1.Storerkey = ORDERS.StorerKey
                                        AND CL1.Long = 'RPT_LP_POPUPPLIST_002'
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON  CL2.LISTNAME = 'REPORTCFG'           --WL02
                                        AND CL2.Code = 'ShowStyleSize'           --WL02
                                        AND CL2.Storerkey = ORDERS.StorerKey     --WL02
                                        AND CL2.Long = 'RPT_LP_POPUPPLIST_002'   --WL02
   LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON  CL3.LISTNAME = 'REPORTCFG'           --WL03
                                        AND CL3.Code = 'ShowExtField04'          --WL03
                                        AND CL3.Storerkey = ORDERS.StorerKey     --WL03
                                        AND CL3.Long = 'RPT_LP_POPUPPLIST_002'   --WL03
   LEFT JOIN SKUINFO SIF WITH (NOLOCK) ON SKU.StorerKey = SIF.Storerkey AND SKU.SKU = SIF.SKU   --WL03
   WHERE PICKDETAIL.Status < '5' AND LoadPlanDetail.LoadKey = @c_Loadkey
   GROUP BY RefKeyLookup.Pickslipno
          , PICKDETAIL.OrderKey
          , ISNULL(ORDERS.ConsigneeKey, '')
          , ISNULL(ORDERS.C_Company, '')
          , ISNULL(ORDERS.C_Address1, '')
          , ISNULL(ORDERS.C_Address2, '')
          , ISNULL(ORDERS.C_Address3, '')
          , ISNULL(ORDERS.C_Zip, '')
          , ISNULL(ORDERS.Route, '')
          , ISNULL(RouteMaster.Descr, '')
          , ORDERS.Door
          , CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, ''))
          , CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, ''))
          , PICKDETAIL.Loc
          , PICKDETAIL.ID
          , IIF(ISNULL(CL2.Short, 'N') = 'Y', ISNULL(TRIM(SKU.Style),'') + ' - ' + ISNULL(TRIM(SKU.Size),''), PICKDETAIL.Sku)   --WL02
          , ISNULL(SKU.DESCR, '')
          , PICKDETAIL.Lot
          , LOTATTRIBUTE.Lottable02
          , ISNULL([dbo].[fnc_ConvSFTimeZone](PICKDETAIL.Storerkey, ORDERS.Facility, LOTATTRIBUTE.Lottable04), '19000101')  --XLL01
          , PACK.Pallet
          , PACK.CaseCnt
          , PACK.InnerPack
          , PACK.Qty
          , ORDERS.ExternOrderKey
          , ISNULL(LOC.LogicalLocation, '')
          , ISNULL(AreaDetail.AreaKey, '00')
          , ISNULL(ORDERDETAIL.UOM, '')
          , CONVERT(
               NVARCHAR(10)
             , CASE WHEN ORDERS.DocType = 'E' OR ISNULL(ORDERS.UserDefine03, '') = '' THEN
                       ISNULL([dbo].[fnc_ConvSFTimeZone](PICKDETAIL.Storerkey, ORDERS.Facility, ORDERS.DeliveryDate), '19000101') --XLL01
                    ELSE IIF(ISDATE(ORDERS.UserDefine03) = 1, CAST(ORDERS.UserDefine03 AS DATETIME), '19000101') END   --WL01
             , 103)
          , CASE WHEN ISNULL(SKU.RETAILSKU, '') = '' THEN ISNULL(SKU.ALTSKU, '')
                 ELSE SKU.RETAILSKU END
          , ISNULL(ORDERS.BuyerPO, '')
          , ISNULL(ORDERS.InvoiceNo, '')
          , ISNULL([dbo].[fnc_ConvSFTimeZone](PICKDETAIL.Storerkey, ORDERS.FACILITY, ORDERS.OrderDate), '19000101') --XLL01
          , SKU.SUSR4
          , st.VAT
          , SKU.OVAS
          , IIF(ISNULL(CL3.Short, 'N') = 'Y', SIF.ExtendedField04, SKU.SKUGROUP)   --WL03
          , ORDERS.ContainerType
          , LOC.Pickzone
          , CASE WHEN ISNULL(CODELKUP.Long, '') = '' THEN ORDERS.Priority
                 ELSE CODELKUP.Long END
          , ISNULL(CL1.Short, 'N')
          , IIF(ISNULL(CL2.Short, 'N') = 'Y', 'Style - Size', 'Sku')   --WL02
          , IIF(ISNULL(CL3.Short, 'N') = 'Y', 'ExtendedField04', 'SKU Group')   --WL03
          , PICKDETAIL.Storerkey  --XLL01
          , ORDERS.Facility --XLL01

   UPDATE #TEMP_PICK
   SET Cartons_cal = CASE packcasecnt
                          WHEN 0 THEN 0
                          ELSE FLOOR(Total_cal / packcasecnt)END


   UPDATE #TEMP_PICK
   SET inner_cal = CASE packinner
                        WHEN 0 THEN 0
                        ELSE FLOOR(Total_cal / packinner) - ((packcasecnt * Cartons_cal) / packinner) END


   UPDATE #TEMP_PICK
   SET Each_cal = Total_cal - (packcasecnt * Cartons_cal) - (packinner * inner_cal)

   BEGIN TRAN

   UPDATE PICKHEADER WITH (ROWLOCK)
   SET PickType = '1'
     , TrafficCop = NULL
   WHERE ExternOrderKey = @c_Loadkey AND Zone = 'LP'
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
      END
      ELSE
      BEGIN
         SELECT @n_continue = 3
         ROLLBACK TRAN
      END
   END

   SET @c_orderkey = N''
   SET @c_Pickzone = N''
   SET @c_PrevOrderKey = N''
   SET @c_PrevPickzone = N''
   SET @c_Pickdetailkey = N''
   SET @n_continue = 1

   DECLARE C_Orderkey_Pickzone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT OrderKey
                 , Pickzone
   FROM #TEMP_PICK
   WHERE ISNULL(PickSlipNo, '') = ''
   ORDER BY OrderKey
          , Pickzone

   OPEN C_Orderkey_Pickzone

   FETCH NEXT FROM C_Orderkey_Pickzone
   INTO @c_orderkey
      , @c_Pickzone

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN -- while 1     
      IF ISNULL(@c_orderkey, '0') = '0'
         BREAK

      IF EXISTS (  SELECT 1
                   FROM RefKeyLookup WITH (NOLOCK)
                   WHERE OrderKey = @c_orderkey)
      BEGIN
         SELECT TOP 1 @c_Pickslipno = Pickslipno
         FROM RefKeyLookup WITH (NOLOCK)
         WHERE OrderKey = @c_orderkey

         UPDATE #TEMP_PICK
         SET PickSlipNo = @c_Pickslipno
         WHERE OrderKey = @c_orderkey AND Pickzone = @c_Pickzone AND ISNULL(PickSlipNo, '') = ''

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63505
            SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                               + N': Update #Temp_Pick Failed. (isp_RPT_LP_POPUPLIST_002)'
            GOTO FAILURE
         END
      END
      ELSE
      BEGIN
         IF @c_PrevOrderKey <> @c_orderkey
         --OR @c_PrevPickzone <> @c_Pickzone     
         BEGIN
            --            BEGIN TRAN    
            SET @c_Pickslipno = N''

            EXECUTE nspg_GetKey 'PICKSLIP'
                              , 9
                              , @c_Pickslipno OUTPUT
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

            IF @b_success = 1
            BEGIN
               SELECT @c_Pickslipno = N'P' + @c_Pickslipno
               INSERT PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, Zone, PickType, WaveKey)
               VALUES (@c_Pickslipno, @c_orderkey, @c_Loadkey, 'LP', '0', @c_Pickslipno)

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 63501
                  SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                     + N': Insert into PICKHEADER Failed. (isp_RPT_LP_POPUPLIST_002)'
                  GOTO FAILURE
               END
            END -- @b_success = 1        
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63502
               SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                  + N': Get PSNO Failed. (isp_RPT_LP_POPUPLIST_002)'
               BREAK
            END
         END
      END

      IF @n_continue = 1
      BEGIN
         SET @c_ExecStatement = N'DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR '
                                + N'SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber '
                                + N'FROM   PickDetail WITH (NOLOCK) ' + N'JOIN   OrderDetail WITH (NOLOCK) '
                                + N'ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND '
                                + N'PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber) '
                                + N'JOIN   LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) '
                                + N'WHERE  OrderDetail.OrderKey = ''' + @c_orderkey + N'''' + N' AND LOC.Pickzone = '''
                                + RTRIM(@c_Pickzone) + N''' ' + N' ORDER BY PickDetail.PickDetailKey '

         EXEC (@c_ExecStatement)
         OPEN C_PickDetailKey

         FETCH NEXT FROM C_PickDetailKey
         INTO @c_Pickdetailkey
            , @c_OrderLineNumber

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF NOT EXISTS (  SELECT 1
                             FROM RefKeyLookup WITH (NOLOCK)
                             WHERE PickDetailkey = @c_Pickdetailkey)
            BEGIN
               INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
               VALUES (@c_Pickdetailkey, @c_Pickslipno, @c_orderkey, @c_OrderLineNumber, @c_Loadkey)

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 63503
                  SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                     + N': Insert RefKeyLookup Failed. (isp_RPT_LP_POPUPLIST_002)'
                  GOTO FAILURE
               END
            END

            FETCH NEXT FROM C_PickDetailKey
            INTO @c_Pickdetailkey
               , @c_OrderLineNumber
         END
         CLOSE C_PickDetailKey
         DEALLOCATE C_PickDetailKey
      END

      UPDATE #TEMP_PICK
      SET PickSlipNo = @c_Pickslipno
      WHERE OrderKey = @c_orderkey AND Pickzone = @c_Pickzone AND ISNULL(PickSlipNo, '') = ''

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63504
         SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                            + N': Update #Temp_Pick Failed. (isp_RPT_LP_POPUPLIST_002)'
         GOTO FAILURE
      END

      SET @c_PrevOrderKey = @c_orderkey
      SET @c_PrevPickzone = @c_Pickzone

      FETCH NEXT FROM C_Orderkey_Pickzone
      INTO @c_orderkey
         , @c_Pickzone
   END -- while 1       

   CLOSE C_Orderkey_Pickzone
   DEALLOCATE C_Orderkey_Pickzone

   GOTO SUCCESS

   FAILURE:
   DELETE FROM #TEMP_PICK
   SUCCESS:
   SELECT  PickSlipNo            
         , LoadKey              
         , OrderKey             
         , ConsigneeKey         
         , Company              
         , Addr1                
         , Addr2                
         , Addr3                
         , PostCode             
         , Route                
         , Route_Desc           
         , TrfRoom              
         , Notes1               
         , Notes2               
         , LOC                  
         , ID                   
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
         , Lottable02           
         , Lottable04           
         , packpallet           
         , packcasecnt          
         , packinner            
         , packeaches           
         , externorderkey       
         , LogicalLoc           
         , Areakey              
         , UOM                  
         , Pallet_cal           
         , Cartons_cal          
         , inner_cal            
         , Each_cal             
         , Total_cal            
         , DeliveryDate  
         , RetailSku            
         , BuyerPO              
         , InvoiceNo            
         , OrderDate           
         , Susr4                
         , vat                  
         , OVAS                 
         , SKUGROUP             
         , ContainerType        
         , Pickzone             
         , Priority             
         , ExtendRouteDescLength
         , Logo        
         , CASE WHEN OrderKey <> LEAD(OrderKey,1,0) OVER (ORDER BY Company
                                                                 , OrderKey
                                                                 , Pickzone
                                                                 , PickSlipNo
                                                                 , LogicalLoc
                                                                 , LOC
                                                                 , SKU ) THEN 'N' ELSE 'Y' END AS FillWholePage
         , SKUTitle   --WL02
         , SKUGroupTitle   --WL03
         , CurrentDateTime  --XLL01
   FROM #TEMP_PICK
   ORDER BY Company
          , OrderKey
          , Pickzone
          , PickSlipNo
          , LogicalLoc
          , LOC
          , SKU
          , CurrentDateTime
   IF OBJECT_ID('tempdb..#TEMP_PICKSLIPNO') IS NOT NULL
      DROP TABLE #TEMP_PICK

END -- procedure
GO