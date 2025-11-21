SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_LP_PLISTN_023                               */
/* Creation Date: 25-Jan-2023                                            */
/* Copyright: LFL                                                        */
/* Written by: Adarsh                                                    */
/*                                                                       */
/* Purpose: WMS-21518-Migrate WMS Report To LogiReport                   */
/*                                                                       */
/* Called By: RPT_LP_PLISTN_023                                          */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/* 25-Jan-2023  WLChooi  1.0  DevOps Combine Script                      */
/* 29-MAY-2023  CSCHONG  1.1  WMS-22544 add new field (CS01)             */
/* 19-JUN-2023  CSCHONG  1.2  WMS-22544 add pageno (CS02)                */
/*************************************************************************/

CREATE   PROC [dbo].[isp_RPT_LP_PLISTN_023]
(
   @c_Loadkey       NVARCHAR(10)
 , @c_PreGenRptData NVARCHAR(10) = ''
)
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
         , @c_Route_Desc         NVARCHAR(60)
         , @c_TrfRoom            NVARCHAR(5)
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
         , @c_externorderkey     NVARCHAR(30)
         , @n_pickslips_required INT
         , @c_areakey            NVARCHAR(10)
         , @c_skugroup           NVARCHAR(10)

   DECLARE @c_PrevOrderKey       NVARCHAR(10)
         , @n_Pallets            INT
         , @n_Cartons            INT
         , @n_Eaches             INT
         , @n_UOMQty             INT
         , @n_TTLPAGE            INT = 1               --CS02 S
         , @n_Maxline            INT = 13              --CS02  
         , @c_RptPage            NVARCHAR(50) = ''     --CS02
         , @c_GetPickslipno      NVARCHAR(20)
         , @c_GetLoadkey         NVARCHAR(20)
         , @c_GetOrderkey        NVARCHAR(20)
         , @c_GetRptGrp          NVARCHAR(5)       
         , @c_Getshowfullroute   NVARCHAR(10)
         , @n_TTLQty             INT
         , @n_GTTLQty            INT
         , @n_MinPageNo          INT     
         , @n_MaxPageNo          INT                    --CS02 E

   IF ISNULL(@c_PreGenRptData, '') IN ( '0', '' )
      SET @c_PreGenRptData = ''

   CREATE TABLE #TEMP_PICK78
   (
      PickSlipNo     NVARCHAR(10) NULL
    , LoadKey        NVARCHAR(10)
    , OrderKey       NVARCHAR(10)
    , ConsigneeKey   NVARCHAR(15)
    , Company        NVARCHAR(45)
    , Addr1          NVARCHAR(45) NULL
    , Addr2          NVARCHAR(45) NULL
    , Addr3          NVARCHAR(45) NULL
    , PostCode       NVARCHAR(15) NULL
    , Route          NVARCHAR(10) NULL
    , Route_Desc     NVARCHAR(60) NULL
    , TrfRoom        NVARCHAR(5)  NULL
    , Notes1         NVARCHAR(60) NULL
    , Notes2         NVARCHAR(60) NULL
    , LOC            NVARCHAR(10) NULL
    , ID             NVARCHAR(18) NULL
    , SKU            NVARCHAR(20)
    , SkuDesc        NVARCHAR(60)
    , Qty            INT
    , TempQty1       INT
    , TempQty2       INT
    , PrintedFlag    NVARCHAR(1)  NULL
    , Zone           NVARCHAR(1)
    , PgGroup        INT
    , RowNum         INT
    , Lot            NVARCHAR(10)
    , Carrierkey     NVARCHAR(60) NULL
    , VehicleNo      NVARCHAR(10) NULL
    , Lottable02     NVARCHAR(18) NULL
    , Lottable04     DATETIME     NULL
    , packpallet     INT
    , packcasecnt    INT
    , packinner      INT
    , packeaches     INT
    , externorderkey NVARCHAR(30) NULL
    , LogicalLoc     NVARCHAR(18) NULL
    , Areakey        NVARCHAR(10) NULL
    , UOM            NVARCHAR(10)
    , Pallet_cal     INT
    , Cartons_cal    INT
    , inner_cal      INT
    , Each_cal       INT
    , Total_cal      INT
    , DeliveryDate   DATETIME     NULL
    , RetailSku      NVARCHAR(20) NULL
    , BuyerPO        NVARCHAR(20) NULL
    , InvoiceNo      NVARCHAR(10) NULL
    , OrderDate      DATETIME     NULL
    , Susr4          NVARCHAR(18) NULL
    , vat            NVARCHAR(18) NULL
    , OVAS           NVARCHAR(30) NULL
    , SKUGROUP       NVARCHAR(10) NULL
    , ContainerType  NVARCHAR(20) NULL
    , RptGrp         NVARCHAR(1)  NULL
    , ShowFullRoute  NVARCHAR(10) NULL
    , ShowUnitPrice  NVARCHAR(1)  NULL    --CS01 S
    , PriceTitle     NVARCHAR(10) NULL
    , UnitPrice      FLOAT                --CS01 S        
   )


   --CS02 S

 CREATE TABLE #TEMP_PICK78_final
   (
      PickSlipNo     NVARCHAR(10) NULL
    , LoadKey        NVARCHAR(10)
    , OrderKey       NVARCHAR(10)
    , ConsigneeKey   NVARCHAR(15)
    , Company        NVARCHAR(45)
    , Addr1          NVARCHAR(45) NULL
    , Addr2          NVARCHAR(45) NULL
    , Addr3          NVARCHAR(45) NULL
    , PostCode       NVARCHAR(15) NULL
    , Route          NVARCHAR(10) NULL
    , Route_Desc     NVARCHAR(60) NULL
    , TrfRoom        NVARCHAR(5)  NULL
    , Notes1         NVARCHAR(60) NULL
    , Notes2         NVARCHAR(60) NULL
    , LOC            NVARCHAR(10) NULL
    , ID             NVARCHAR(18) NULL
    , SKU            NVARCHAR(20)
    , SkuDesc        NVARCHAR(60)
    , Qty            INT
    , TempQty1       INT
    , TempQty2       INT
    , PrintedFlag    NVARCHAR(1)  NULL
    , Zone           NVARCHAR(1)
    , PgGroup        INT
    , RowNum         INT
    , Lot            NVARCHAR(10)
    , Carrierkey     NVARCHAR(60) NULL
    , VehicleNo      NVARCHAR(10) NULL
    , Lottable02     NVARCHAR(18) NULL
    , Lottable04     DATETIME     NULL
    , packpallet     INT
    , packcasecnt    INT
    , packinner      INT
    , packeaches     INT
    , externorderkey NVARCHAR(30) NULL
    , LogicalLoc     NVARCHAR(18) NULL
    , Areakey        NVARCHAR(10) NULL
    , UOM            NVARCHAR(10)
    , Pallet_cal     INT
    , Cartons_cal    INT
    , inner_cal      INT
    , Each_cal       INT
    , Total_cal      INT
    , DeliveryDate   DATETIME     NULL
    , RetailSku      NVARCHAR(20) NULL
    , BuyerPO        NVARCHAR(20) NULL
    , InvoiceNo      NVARCHAR(10) NULL
    , OrderDate      DATETIME     NULL
    , Susr4          NVARCHAR(18) NULL
    , vat            NVARCHAR(18) NULL
    , OVAS           NVARCHAR(30) NULL
    , SKUGROUP       NVARCHAR(10) NULL
    , ContainerType  NVARCHAR(20) NULL
    , RptGrp         NVARCHAR(1)  NULL
    , ShowFullRoute  NVARCHAR(10) NULL
    , ShowUnitPrice  NVARCHAR(1)  NULL    --CS01 S
    , PriceTitle     NVARCHAR(10) NULL
    , UnitPrice      FLOAT                   
    , PageNo         INT
    , TTLPage        INT                  
    --, TTLQty         INT
    , GTTLQty        INT                  --CS01 E       
   )

   --CS02 E

   INSERT INTO #TEMP_PICK78 (PickSlipNo, LoadKey, OrderKey, ConsigneeKey, Company, Addr1, Addr2, PgGroup, Addr3
                           , PostCode, Route, Route_Desc, TrfRoom, Notes1, RowNum, Notes2, LOC, ID, SKU, SkuDesc, Qty
                           , TempQty1, TempQty2, PrintedFlag, Zone, Lot, Carrierkey, VehicleNo, Lottable02, Lottable04
                           , packpallet, packcasecnt, packinner, packeaches, externorderkey, LogicalLoc, Areakey, UOM
                           , Pallet_cal, Cartons_cal, inner_cal, Each_cal, Total_cal, DeliveryDate, RetailSku, BuyerPO
                           , InvoiceNo, OrderDate, Susr4, vat, OVAS, SKUGROUP, ContainerType, RptGrp, ShowFullRoute
                           , ShowUnitPrice,PriceTitle,UnitPrice)                       --CS01
   SELECT (  SELECT PickHeaderKey
             FROM PICKHEADER (NOLOCK)
             WHERE ExternOrderKey = @c_Loadkey AND OrderKey = PICKDETAIL.OrderKey AND Zone = '3')
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
        , PICKDETAIL.Sku
        , ISNULL(SKU.DESCR, '') SkuDescr
        , SUM(PICKDETAIL.Qty) AS Qty
        , 1 AS UOMQTY
        , 0 AS TempQty2
        , ISNULL((  SELECT DISTINCT 'Y'
                    FROM PICKHEADER (NOLOCK)
                    WHERE ExternOrderKey = @c_Loadkey AND Zone = '3')
               , 'N') AS PrintedFlag
        , '3' Zone
        , PICKDETAIL.Lot
        , '' CarrierKey
        , '' AS VehicleNo
        , LOTATTRIBUTE.Lottable02
        , ISNULL(LOTATTRIBUTE.Lottable04, '19000101') Lottable04
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
        , ISNULL(ORDERS.DeliveryDate, '19000101') DeliveryDate
        , ISNULL(SKU.RETAILSKU, '') RetailSku
        , ISNULL(ORDERS.BuyerPO, '') BuyerPO
        , ISNULL(ORDERS.InvoiceNo, '') InvoiceNo
        , ISNULL(ORDERS.OrderDate, '19000101') OrderDate
        , SKU.SUSR4
        , st.VAT
        , SKU.OVAS
        , SKU.SKUGROUP
        , ORDERS.ContainerType
        , Rptgrp = CASE WHEN SKU.SKUGROUP = 'F' THEN '1'
                        ELSE '2' END
        , ISNULL(CL.Short, 'N') AS ShowFullRoute
        , ISNULL(CL1.Short, 'N') AS ShowUnitPrice    --CS01  S
        , 'Price' AS PriceTitle
        , SUM(ORDERDETAIL.unitprice)                 --CS01 E
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
   LEFT OUTER JOIN CODELKUP CL (NOLOCK) ON  CL.LISTNAME = 'REPORTCFG'
                                        AND CL.Storerkey = ORDERS.StorerKey
                                        AND CL.Code = 'ShowFullRoute'
                                        AND CL.Long = 'RPT_LP_PLISTN_023'
   LEFT OUTER JOIN CODELKUP CL1 (NOLOCK) ON  CL1.LISTNAME = 'REPORTCFG'
                                        AND CL1.Storerkey = ORDERS.StorerKey
                                        AND CL1.Code = 'SHOWUNITPRICE'
                                        AND CL1.Long = 'RPT_LP_PLISTN_023'
   WHERE PICKDETAIL.Status < '5' AND LoadPlanDetail.LoadKey = @c_Loadkey
   GROUP BY PICKDETAIL.OrderKey
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
          , PICKDETAIL.Sku
          , ISNULL(SKU.DESCR, '')
          , PICKDETAIL.Lot
          , LOTATTRIBUTE.Lottable02
          , ISNULL(LOTATTRIBUTE.Lottable04, '19000101')
          , PACK.Pallet
          , PACK.CaseCnt
          , PACK.InnerPack
          , PACK.Qty
          , ORDERS.ExternOrderKey
          , ISNULL(LOC.LogicalLocation, '')
          , ISNULL(AreaDetail.AreaKey, '00')
          , ISNULL(ORDERDETAIL.UOM, '')
          , ISNULL(ORDERS.DeliveryDate, '19000101')
          , ISNULL(SKU.RETAILSKU, '')
          , ISNULL(ORDERS.BuyerPO, '')
          , ISNULL(ORDERS.InvoiceNo, '')
          , ISNULL(ORDERS.OrderDate, '19000101')
          , SKU.SUSR4
          , st.VAT
          , SKU.OVAS
          , SKU.SKUGROUP
          , ORDERS.ContainerType
          , CASE WHEN SKU.SKUGROUP = 'F' THEN '1'
                 ELSE '2' END
          , ISNULL(CL.Short, 'N')
          , ISNULL(CL1.Short, 'N')                   --CS01  S
       --   , ORDERDETAIL.unitprice                  --CS01 E

   UPDATE #TEMP_PICK78
   SET Cartons_cal = CASE packcasecnt
                          WHEN 0 THEN 0
                          ELSE FLOOR(Total_cal / packcasecnt)END


   UPDATE #TEMP_PICK78
   SET inner_cal = CASE packinner
                        WHEN 0 THEN 0
                        ELSE FLOOR(Total_cal / packinner) - ((packcasecnt * Cartons_cal) / packinner) END


   UPDATE #TEMP_PICK78
   SET Each_cal = Total_cal - (packcasecnt * Cartons_cal) - (packinner * inner_cal)

   IF @c_PreGenRptData = '' AND EXISTS (SELECT 1 FROM #TEMP_PICK78 WHERE PickSlipNo IS NULL)
   BEGIN
       SET @c_PreGenRptData = 'Y'
   END

   IF @c_PreGenRptData = 'Y'
   BEGIN
      BEGIN TRAN

      UPDATE PICKHEADER WITH (ROWLOCK)
      SET PickType = '1'
        , TrafficCop = NULL
      WHERE ExternOrderKey = @c_Loadkey AND Zone = '3'
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
      SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
      FROM #TEMP_PICK78
      WHERE PickSlipNo IS NULL
      IF @@ERROR <> 0
      BEGIN
         GOTO FAILURE
      END
      ELSE IF @n_pickslips_required > 0
      BEGIN
         EXECUTE nspg_GetKey 'PICKSLIP'
                           , 9
                           , @c_pickheaderkey OUTPUT
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
                           , 0
                           , @n_pickslips_required
         --             
         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
         SELECT 'P'
                + RIGHT(REPLICATE('0', 9)
                        + dbo.fnc_LTRIM(
                             dbo.fnc_RTRIM(
                                STR(CAST(@c_pickheaderkey AS INT) + (  SELECT COUNT(DISTINCT OrderKey)
                                                                       FROM #TEMP_PICK78 AS Rank
                                                                       WHERE Rank.OrderKey < #TEMP_PICK78.OrderKey)))), 9)
              , OrderKey
              , LoadKey
              , '0'
              , '3'
              , ''
         FROM #TEMP_PICK78
         WHERE PickSlipNo IS NULL
         GROUP BY LoadKey
                , OrderKey

         UPDATE #TEMP_PICK78
         SET PickSlipNo = PICKHEADER.PickHeaderKey
         FROM PICKHEADER (NOLOCK)
         WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK78.LoadKey
         AND   PICKHEADER.OrderKey = #TEMP_PICK78.OrderKey
         AND   PICKHEADER.Zone = '3'
         AND   #TEMP_PICK78.PickSlipNo IS NULL
      END
   END

       SET @c_PreGenRptData = '' 

   GOTO SUCCESS

   FAILURE:
      GOTO QUIT_SP

   SUCCESS:
   IF ISNULL(@c_PreGenRptData,'') = ''
   BEGIN
        
       --CS02 S

        INSERT INTO #TEMP_PICK78_final
      (
          PickSlipNo,
          LoadKey,
          OrderKey,
          ConsigneeKey,
          Company,
          Addr1,
          Addr2,
          Addr3,
          PostCode,
          Route,
          Route_Desc,
          TrfRoom,
          Notes1,
          Notes2,
          LOC,
          ID,
          SKU,
          SkuDesc,
          Qty,
          TempQty1,
          TempQty2,
          PrintedFlag,
          Zone,
          PgGroup,
          RowNum,
          Lot,
          Carrierkey,
          VehicleNo,
          Lottable02,
          Lottable04,
          packpallet,
          packcasecnt,
          packinner,
          packeaches,
          externorderkey,
          LogicalLoc,
          Areakey,
          UOM,
          Pallet_cal,
          Cartons_cal,
          inner_cal,
          Each_cal,
          Total_cal,
          DeliveryDate,
          RetailSku,
          BuyerPO,
          InvoiceNo,
          OrderDate,
          Susr4,
          vat,
          OVAS,
          SKUGROUP,
          ContainerType,
          RptGrp,
          ShowFullRoute,
          ShowUnitPrice,
          PriceTitle,
          UnitPrice,
          PageNo,
          TTLPage,
          GTTLQty 
      )
     SELECT P78.*,(Row_Number() OVER (PARTITION BY loadkey,orderkey,rptgrp,ShowFullRoute ORDER BY loadkey,orderkey,rptgrp,ShowFullRoute) - 1 ) / @n_MaxLine + 1 AS pageno,0,0
     FROM #TEMP_PICK78 P78


     DECLARE CUR_RptPageLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
     SELECT DISTINCT PickSlipNo,LoadKey,OrderKey,RptGrp,ShowFullRoute
     FROM #TEMP_PICK78_final

      OPEN CUR_RptPageLoop

      FETCH NEXT FROM CUR_RptPageLoop INTO @c_GetPickslipno,@c_GetLoadkey,@c_GetOrderkey,@c_GetRptGrp,@c_Getshowfullroute

      WHILE @@FETCH_STATUS <> -1
      BEGIN

      SET @n_MinPageNo = 0
      SET @n_MaxPageNo = 0
      SET @c_RptPage = ''

      SELECT @n_MinPageNo = MIN(PageNo)
            ,@n_MaxPageNo = MAX(PageNo)
            ,@n_GTTLQty   = SUM(Qty)
      FROM #TEMP_PICK78_final
      WHERE PickSlipNo = @c_GetPickslipno
      AND   loadkey = @c_GetLoadkey
      AND OrderKey = @c_GetOrderkey
      AND RptGrp = @c_GetRptGrp
      AND ShowFullRoute = @c_Getshowfullroute


      SET @c_RptPage = 'Page ' + CAST(@n_MinPageNo AS NVARCHAR(5)) + ' of '  + CAST(@n_MaxPageNo AS NVARCHAR(5))

      UPDATE #TEMP_PICK78_final
      SET TTLPage = @n_MaxPageNo
          ,GTTLQty = @n_GTTLQty
    --     ,RptPage = @c_RptPage
      WHERE PickSlipNo = @c_GetPickslipno
      AND   loadkey = @c_GetLoadkey
      AND OrderKey = @c_GetOrderkey
      AND RptGrp = @c_GetRptGrp
      AND ShowFullRoute = @c_Getshowfullroute


      FETCH NEXT FROM CUR_RptPageLoop INTO @c_GetPickslipno,@c_GetLoadkey,@c_GetOrderkey,@c_GetRptGrp,@c_Getshowfullroute
 
      END -- While
      CLOSE CUR_RptPageLoop
      DEALLOCATE CUR_RptPageLoop

       --CS02 E

   SELECT P78F.*,P78GT.TTLQty
   FROM #TEMP_PICK78_final P78F
   CROSS APPLY (SELECT P78.LoadKey,P78.OrderKey,P78.RptGrp,P78.Areakey,SUM(QTY) AS TTLQty
                FROM #TEMP_PICK78 P78 
                WHERE P78.LoadKey = P78F.LoadKey AND P78.OrderKey = P78F.OrderKey
                      AND P78.RptGrp = P78F.RptGrp AND P78.Areakey = P78F.Areakey
                GROUP BY P78.LoadKey,P78.OrderKey,P78.RptGrp,P78.Areakey) AS P78GT 
   END

   QUIT_SP:
   IF OBJECT_ID('tempdb..#TEMP_PICK78') IS NOT NULL
      DELETE FROM #TEMP_PICK78

   --CS02 S

   IF OBJECT_ID('tempdb..#TEMP_PICK78_final') IS NOT NULL
      DELETE FROM #TEMP_PICK78_final
   --CS02 E

END

GO