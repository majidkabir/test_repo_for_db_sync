SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Proc : isp_GetPickSlipOrders114                                  */  
/* Creation Date: 27-Nov-2020                                              */  
/* Copyright: LFL                                                          */  
/* Written by: WLChooi                                                     */  
/*                                                                         */  
/* Purpose: WMS-15752 - MANDOM Picking Slip Break By Pickzone              */  
/*          Copy from nsp_GetPickSlipOrders08 and modify                   */  
/*                                                                         */  
/* Called By: r_dw_print_pickorder114                                      */  
/*                                                                         */  
/* GitLab Version: 1.0                                                     */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Author      Ver   Purposes                                  */  
/* 17-Mar-2022 Mingle      1.1   WMS-19194 - Add new field(ML01)           */  
/* 14-Dec-2022 CHONGCS     1.2   WMS-21300 new field and page break (CS01) */
/***************************************************************************/  
CREATE   PROC [dbo].[isp_GetPickSlipOrders114] (@c_loadkey NVARCHAR(10))  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
DECLARE @c_pickheaderkey      NVARCHAR(10),  
        @n_continue           INT,  
        @c_errmsg             NVARCHAR(255),  
        @b_success            INT,  
        @n_err                INT,  
        @n_pickslips_required INT  
  
DECLARE @c_PrevOrderKey NVARCHAR(10),  
        @n_Pallets      INT,  
        @n_Cartons      INT,  
        @n_Eaches       INT,  
        @n_UOMQty       INT  
  
DECLARE @n_starttcnt INT  
SELECT  @n_starttcnt = @@TRANCOUNT  
  
WHILE @@TRANCOUNT > 0  
BEGIN  
   COMMIT TRAN  
END  
  
SET @n_pickslips_required = 0  
  
BEGIN TRAN  
  
   CREATE TABLE #TEMP_PICK  
       ( PickSlipNo       NVARCHAR(10) NULL,  
         LoadKey          NVARCHAR(10),  
         OrderKey         NVARCHAR(10),  
         ConsigneeKey     NVARCHAR(15),  
         Company          NVARCHAR(45),  
         Addr1            NVARCHAR(45) NULL,  
         Addr2            NVARCHAR(45) NULL,  
         Addr3            NVARCHAR(45) NULL,  
         PostCode         NVARCHAR(15) NULL,  
         Route            NVARCHAR(10) NULL,  
         Route_Desc       NVARCHAR(60) NULL, -- RouteMaster.Desc  
         TrfRoom          NVARCHAR(5) NULL,  -- LoadPlan.TrfRoom  
         Notes1           NVARCHAR(60) NULL,  
         Notes2           NVARCHAR(60) NULL,  
         LOC              NVARCHAR(10) NULL,  
         ID               NVARCHAR(18) NULL,  
         SKU              NVARCHAR(20),  
         SKUDesc          NVARCHAR(60),  
         Qty              INT,  
         TempQty1         INT,  
         TempQty2         INT,  
         PrintedFlag      NVARCHAR(1) NULL,  
         Zone             NVARCHAR(1),  
         PgGroup          INT,  
         RowNum           INT,  
         Lot              NVARCHAR(10),  
         Carrierkey       NVARCHAR(60) NULL,  
         VehicleNo        NVARCHAR(10) NULL,  
         Lottable02       NVARCHAR(18) NULL,  
         Lottable04       DATETIME NULL,  
         packpallet       INT,  
         packcasecnt      INT,  
         packinner        INT,     
         packeaches       INT,        
         externorderkey   NVARCHAR(50) NULL,  
         LogicalLOC       NVARCHAR(18) NULL,  
         Areakey    NVARCHAR(10) NULL,  
         UOM              NVARCHAR(10),       
         Pallet_cal       INT,  
         Cartons_cal      INT,  
         inner_cal        INT,      
         Each_cal         INT,  
         Total_cal        INT,  
         DeliveryDate     DATETIME NULL,  
         RetailSKU        NVARCHAR(20) NULL,  
         BuyerPO          NVARCHAR(20) NULL,  
         InvoiceNo        NVARCHAR(10) NULL,  
         OrderDate        DATETIME NULL,  
         Susr4            NVARCHAR(18) NULL,  
         vat              NVARCHAR(18) NULL,  
         OVAS             NVARCHAR(30) NULL,  
         SKUGROUP         NVARCHAR(10) NULL,  
         Lottable06       NVARCHAR(30) NULL,  
         ShowLot06        NVARCHAR(1)  NULL,  
         ShowSKUBusr10    NVARCHAR(1)  NULL,  
         SKUBusr10        NVARCHAR(30) NULL,  
         ShowPickDetailID NVARCHAR(10) NULL,  
         BatchNameField   NVARCHAR(25) NULL,  
         LOCPickzone      NVARCHAR(10) NULL,  
         ConsigneeSKU     NVARCHAR(20),  
         RepOvasWithConSKU NVARCHAR(1)  NULL,
         locaisle          NVARCHAR(10) NULL,    --CS01
         locaisleseq       NVARCHAR(20)          --CS01
  
   )  
   INSERT INTO #TEMP_PICK  
        (PickSlipNo,    LoadKey,          OrderKey,     ConsigneeKey,  
         Company,       Addr1,            Addr2,        PgGroup,  
         Addr3,         PostCode,         Route,  
         Route_Desc,    TrfRoom,          Notes1,       RowNum,  
         Notes2,        LOC,              ID,           SKU,  
         SKUDesc,       Qty,              TempQty1,  
         TempQty2,      PrintedFlag,      Zone,  
         Lot,           CarrierKey,       VehicleNo,    Lottable02,  
         Lottable04,    packpallet,       packcasecnt,  packinner,  
         packeaches,    externorderkey,   LogicalLOC,   Areakey,    UOM,  
         Pallet_cal,    Cartons_cal,      inner_cal,    Each_cal,   Total_cal,  
         DeliveryDate,  RetailSKU,        BuyerPO,      InvoiceNo,  OrderDate,  
         Susr4,         Vat,              OVAS,         SKUGROUP,Lottable06,  
         ShowLot06,ShowSKUBusr10,SKUBusr10, ShowPickDetailID,BatchNameField,  
         LOCPickzone,ConsigneeSKU,RepOvasWithConSKU,locaisle,locaisleseq )          --CS01  
   SELECT  
         (SELECT PICKHEADERKEY FROM PICKHEADER  
          WHERE ExternOrderKey = @c_LoadKey  
          AND OrderKey = PickDetail.OrderKey  
          AND ZONE = '3'),  
         @c_LoadKey AS LoadKey,  
         PickDetail.OrderKey,  
         ISNULL(Orders.ConsigneeKey, '') AS ConsigneeKey,  
         ISNULL(Orders.c_Company, '')  AS Company,  
         ISNULL(Orders.C_Address1,'') AS Addr1,  
         ISNULL(Orders.C_Address2,'')  AS Addr2,  
         0 AS PgGroup,  
         ISNULL(Orders.C_Address3,'') AS Addr3,  
         ISNULL(Orders.C_Zip,'') AS PostCode,  
         ISNULL(Orders.Route,'') AS Route,  
         ISNULL(RouteMaster.Descr, '') Route_Desc,  
         Orders.Door AS TrfRoom,  
         CONVERT(NVARCHAR(60), ISNULL(Orders.Notes,  '')) Notes1,  
         0 AS RowNo,  
         CONVERT(NVARCHAR(60), ISNULL(Orders.Notes2, '')) Notes2,  
         PickDetail.LOC,  
         PickDetail.id,  
         PickDetail.SKU,  
         ISNULL(SKU.Descr,'') SKUDescr,  
         SUM(PickDetail.qty) AS Qty,  
         --CASE PickDetail.UOM  
         --     WHEN '1' THEN PACK.Pallet  
         --     WHEN '2' THEN PACK.CaseCnt  
         --     WHEN '3' THEN PACK.InnerPack  
         --     ELSE 1  END AS UOMQty,  
         1 AS UOMQTY,  
         0 AS TempQty2,  
         ISNULL((SELECT DISTINCT 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_Loadkey AND  Zone = '3'), 'N') AS PrintedFlag,  
         '3' Zone,  
         PickDetail.Lot,  
        '' CarrierKey,  
        '' AS VehicleNo,  
        LotAttribute.Lottable02,  
        ISNULL(LotAttribute.Lottable04, '19000101') Lottable04,  
        PACK.Pallet,  
        PACK.CaseCnt,  
        pack.innerpack,  
        PACK.Qty,  
        Orders.ExternOrderKey AS ExternOrderKey,  
        ISNULL(LOC.LogicalLOCation, '') AS LogicalLOCation,  
        ISNULL(AreaDetail.AreaKey, '00') AS Areakey,      
        ISNULL(OrderDetail.UOM, '') AS UOM,  
        Pallet_cal = CASE Pack.Pallet WHEN 0 THEN 0  
         ELSE FLOOR(SUM(PickDetail.qty) / Pack.Pallet)  
        END,  
        Cartons_cal = 0,  
        inner_cal = 0,  
        Each_cal = 0,  
        Total_cal = sum(PickDetail.qty),  
        ISNULL(Orders.DeliveryDate, '19000101') DeliveryDate,  
        ISNULL(SKU.RetailSKU,'') RetailSKU,      
        ISNULL(Orders.BuyerPO,'') BuyerPO,       
        ISNULL(Orders.InvoiceNo,'') InvoiceNo,   
        ISNULL(Orders.OrderDate, '19000101') OrderDate,  
        SKU.Susr4,  
        ST.vat,  
        SKU.OVAS,  
        SKU.SKUGROUP,  
        LotAttribute.Lottable06,                                                                                                                           
        CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowLot06,        
        CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowSKUBusr10,   
        ISNULL(SKU.busr10,'') as SKUBusr10,                                            
        ISNULL(CLR2.Short,'N') AS ShowPickDetailID,  
        CASE WHEN ISNULL(CLR3.Code,'') <> '' THEN 'Custom Lot' ELSE 'Batch No' END as BatchNameField,  
        ISNULL(LTRIM(RTRIM(LOC.Pickzone)),'') AS Pickzone,  
        ConsigneeSKU.ConsigneeSKU,   --ML01  
        ISNULL(CLR4.SHORT,'') AS RepOvasWithConSKU,   --ML01
        ISNULL(CLR5.code2,''),ISNULL(CLR5.Short,'00')          --cs01
   FROM PickDetail (NOLOCK)  
   JOIN Orders (NOLOCK) ON PickDetail.orderkey = Orders.orderkey  
   JOIN LotAttribute (NOLOCK) ON PickDetail.lot = LotAttribute.lot  
   JOIN LoadPlanDetail (NOLOCK) ON PickDetail.orderkey = LoadPlanDetail.orderkey  
   JOIN OrderDetail (NOLOCK) ON PickDetail.orderkey = OrderDetail.orderkey AND PickDetail.orderlinenumber = OrderDetail.orderlinenumber  
   JOIN Storer (NOLOCK) ON PickDetail.Storerkey = Storer.Storerkey  
   JOIN SKU (NOLOCK) ON PickDetail.SKU = SKU.SKU AND PickDetail.Storerkey = SKU.Storerkey  
   JOIN pack (NOLOCK) ON PickDetail.packkey = pack.packkey  
   JOIN LOC (NOLOCK) ON PickDetail.LOC = LOC.LOC  
   LEFT JOIN ConsigneeSKU (NOLOCK) ON ConsigneeSKU.ConsigneeKey = ORDERS.ConsigneeKey AND ConsigneeSKU.SKU = ORDERDETAIL.Sku AND ConsigneeSKU.StorerKey = ORDERS.StorerKey   --ML01  
   LEFT OUTER JOIN RouteMaster (NOLOCK) ON Orders.route = RouteMaster.route  
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON LOC.putawayzone = AreaDetail.putawayzone  
   LEFT OUTER JOIN Storer ST (NOLOCK) ON Orders.consigneekey = ST.Storerkey  
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'showlot06'                                              
                                         AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_print_pickorder114' AND ISNULL(CLR.Short,'') <> 'N')     
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (Orders.Storerkey = CLR1.Storerkey AND CLR1.Code = 'SHOWSKUBUSR10'                                              
                                         AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_print_pickorder114' AND ISNULL(CLR1.Short,'') <> 'N')     
   LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (Orders.Storerkey = CLR2.Storerkey AND CLR2.Code = 'ShowPickDetailID' AND CLR2.Code2 = 'r_dw_print_pickorder114'                                              
                                         AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_print_pickorder114' AND ISNULL(CLR2.Short,'') <> 'N')    
   LEFT OUTER JOIN Codelkup CLR3 (NOLOCK) ON (Orders.Storerkey = CLR1.Storerkey AND CLR3.Code = 'RPTCOLUMNNAME'                                              
                                         AND CLR3.Listname = 'REPORTCFG' AND CLR3.Long = 'r_dw_print_pickorder114' AND ISNULL(CLR3.Short,'') <> 'N')    
   LEFT OUTER JOIN Codelkup CLR4 (NOLOCK) ON (Orders.Storerkey = CLR4.Storerkey AND CLR4.Code = 'RepOvasWithConSKU'                                              
                                         AND CLR4.Listname = 'REPORTCFG' AND CLR4.Long = 'r_dw_print_pickorder114' AND ISNULL(CLR4.Short,'') <> 'N')  
   LEFT OUTER JOIN CODELKUP CLR5 (NOLOCK) ON (Orders.Storerkey = CLR5.Storerkey AND CLR5.Code2 = loc.LocAisle                                              
                                         AND CLR5.Listname = 'RPTPKSLIP' )
   WHERE PickDetail.Status < '5'  
   AND LoadPlanDetail.LoadKey = @c_LoadKey  
   GROUP BY PickDetail.OrderKey,  
   ISNULL(Orders.ConsigneeKey, ''),  
   ISNULL(Orders.c_Company, ''),  
   ISNULL(Orders.C_Address1,''),  
   ISNULL(Orders.C_Address2,''),  
   ISNULL(Orders.C_Address3,''),  
   ISNULL(Orders.C_Zip,''),  
   ISNULL(Orders.Route,''),  
   ISNULL(RouteMaster.Descr, ''),  
   Orders.Door,  
   CONVERT(NVARCHAR(60), ISNULL(Orders.Notes,  '')),  
   CONVERT(NVARCHAR(60), ISNULL(Orders.Notes2, '')),  
   PickDetail.LOC,  
   PickDetail.id,  
   PickDetail.SKU,  
   ISNULL(SKU.Descr,''),  
   --CASE PickDetail.UOM  
   --     WHEN '1' THEN PACK.Pallet  
   --     WHEN '2' THEN PACK.CaseCnt  
   --     WHEN '3' THEN PACK.InnerPack  
   --     ELSE 1  END,  
   PickDetail.Lot,  
   LotAttribute.Lottable02,  
   ISNULL(LotAttribute.Lottable04, '19000101'),  
   PACK.Pallet,  
   PACK.CaseCnt,  
   pack.innerpack,  
   PACK.Qty,  
   Orders.ExternOrderKey,  
   ISNULL(LOC.LogicalLOCation, ''),  
   ISNULL(AreaDetail.AreaKey, '00'),  
   ISNULL(OrderDetail.UOM, ''),  
   ISNULL(Orders.DeliveryDate, '19000101'),  
   ISNULL(SKU.RetailSKU,''),     
   ISNULL(Orders.BuyerPO,''),    
   ISNULL(Orders.InvoiceNo,''),  
   ISNULL(Orders.OrderDate, '19000101'),  
   SKU.Susr4,  
   ST.vat,  
   SKU.OVAS,  
   SKU.SKUGROUP,  
   LotAttribute.Lottable06,  
   CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END,   
   CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END,  
   ISNULL(SKU.busr10,''),  
   ISNULL(CLR2.Short,'N'),         
   CASE WHEN ISNULL(CLR3.Code,'') <> '' THEN 'Custom Lot' ELSE 'Batch No' END,  
   ISNULL(LTRIM(RTRIM(LOC.Pickzone)),''),  
   ConsigneeSKU.ConsigneeSKU,   --ML01  
   ISNULL(CLR4.SHORT,''),   --ML01  
   ISNULL(CLR5.code2,''),ISNULL(CLR5.Short,'00')         --cs01
  
   UPDATE #temp_pick  
      SET cartons_cal = CASE packcasecnt  
                           WHEN 0 THEN 0  
                           --ELSE FLOOR(total_cal/packcasecnt) - ((packpallet*pallet_cal)/packcasecnt)  
                           ELSE FLOOR(total_cal/packcasecnt)  
                        END  
  
   -- UPDATE inner qty  
   UPDATE #temp_pick  
      SET inner_cal = CASE packinner  
                        WHEN 0 THEN 0  
                        --ELSE FLOOR(total_cal/packinner) -  
                        --  ((packpallet*pallet_cal)/packinner) - ((packcasecnt*cartons_cal)/packinner)  
                        ELSE FLOOR(total_cal/packinner) - ((packcasecnt*cartons_cal)/packinner)  
                      END  
  
   -- UPDATE each qty  
   UPDATE #temp_pick  
   --SET each_cal = total_cal - (packpallet*pallet_cal) - (packcasecnt*cartons_cal) - (packinner*inner_cal)  
   SET each_cal = total_cal - (packcasecnt*cartons_cal) - (packinner*inner_cal)  
  
   BEGIN TRAN  
   -- Uses PickType AS a Printed Flag  
   UPDATE PickHeader WITH (ROWLOCK)  
      SET PickType = '1', TrafficCop = NULL  
   WHERE ExternOrderKey = @c_LoadKey  
   AND Zone = '3'  
  
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
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
  
   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)  
   FROM #TEMP_PICK  
   WHERE ISNULL(RTRIM(PickSlipNo),'') = ''  
  
   IF @@ERROR <> 0  
   BEGIN  
      GOTO FAILURE  
   END  
   ELSE IF @n_pickslips_required > 0  
   BEGIN  
      BEGIN TRAN  
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required  
      COMMIT TRAN  
              --SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +  
              --dbo.fnc_LTrim( dbo.fnc_RTrim(  
              --   STR(  
              --      CAST(@c_pickheaderkey AS INT) + ( SELECT COUNT(DISTINCT orderkey)  
              --                                        FROM #TEMP_PICK AS Rank  
              --                                        WHERE Rank.OrderKey < #TEMP_PICK.OrderKey )  
              --       ) -- str  
              --       )) -- dbo.fnc_RTrim  
              --    , 9)  
              -- , OrderKey, LoadKey, '0', '8', ''  
              --FROM #TEMP_PICK WHERE PickSlipNo IS NULL  
              --GROUP By LoadKey, OrderKey  
  
      BEGIN TRAN  
      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)  
      SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +  
                           dbo.fnc_LTrim( dbo.fnc_RTrim(  
                           STR(  
                              CAST(@c_pickheaderkey AS INT) + ( SELECT COUNT(DISTINCT orderkey)  
                                                                FROM #TEMP_PICK AS Rank  
                                                                WHERE Rank.OrderKey < #TEMP_PICK.OrderKey  
                                                                  AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' )  
                              ) -- str  
                         )) -- dbo.fnc_RTrim  
                         , 9)  
      , OrderKey, LoadKey, '0', '3', ''  
      FROM #TEMP_PICK WHERE ISNULL(RTRIM(PickSlipNo),'') = ''  
      GROUP By LoadKey, OrderKey  
  
      UPDATE #TEMP_PICK  
      SET PickSlipNo = PICKHEADER.PickHeaderKey  
      FROM PICKHEADER (NOLOCK)  
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey  
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey  
      AND   PICKHEADER.Zone = '3'  
      AND   ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = ''  
  
      WHILE @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
  
   GOTO SUCCESS  
  
FAILURE:  
   DELETE FROM #TEMP_PICK  
  
SUCCESS:  

   SELECT *
,DENSE_RANK() OVER ( PARTITION BY PickSlipNo,LoadKey,OrderKey,Company ORDER BY Company, Orderkey, LOCPickzone,CASE WHEN locaisleseq ='00' THEN 999 ELSE CAST(locaisleseq AS INT) END  ) AS recgrp 
INTO #TEMP_PICKRESULT
   FROM #TEMP_PICK  
   ORDER BY Company, Orderkey, LOCPickzone, 
            locaisleseq  ,Areakey, LogicalLOC, LOC, SKU  --CS01


SELECT PickSlipNo,    LoadKey,          OrderKey,     ConsigneeKey,  
         Company,       Addr1,            Addr2,       -- PgGroup,  
         Addr3,         PostCode,         Route,  
         Route_Desc,    TrfRoom,          Notes1,      -- RowNum,  
         Notes2,        LOC,              ID,           SKU,  
         SKUDesc,       Qty,              TempQty1,  
         TempQty2,      PrintedFlag,      Zone,  PgGroup, RowNum,  
         Lot,           CarrierKey,       VehicleNo,    Lottable02,  
         Lottable04,    packpallet,       packcasecnt,  packinner,  
         packeaches,    externorderkey,   LogicalLOC,   Areakey,    UOM,  
         Pallet_cal,    Cartons_cal,      inner_cal,    Each_cal,   Total_cal,  
         DeliveryDate,  RetailSKU,        BuyerPO,      InvoiceNo,  OrderDate,  
         Susr4,         Vat,              OVAS,         SKUGROUP,Lottable06,  
         ShowLot06,ShowSKUBusr10,SKUBusr10, ShowPickDetailID,BatchNameField,  
         LOCPickzone,ConsigneeSKU,RepOvasWithConSKU,locaisle,locaisleseq,recgrp,TPTTL.ttlpage AS ttlpage 
FROM #TEMP_PICKRESULT TP
CROSS APPLY (SELECT pickslipno PSN,loadkey LK,orderkey ordkey,MAX(recgrp) AS ttlpage
             FROM #TEMP_PICKRESULT TPS 
             WHERE  TPS.pickslipno =  TP.PickSlipNo AND TPS.LoadKey=TP.LoadKey AND TPS.OrderKey=TP.OrderKey
             GROUP BY TPS.PickSlipNo,TPS.LoadKey,TPS.OrderKey) TPTTL
   ORDER BY Company, Orderkey, LOCPickzone, 
            locaisleseq  ,Areakey, LogicalLOC, LOC, SKU
--GROUP BY 
--         PickSlipNo,    LoadKey,          OrderKey,     ConsigneeKey,  
--         Company,       Addr1,            Addr2,        PgGroup,  
--         Addr3,         PostCode,         Route,  
--         Route_Desc,    TrfRoom,          Notes1,       RowNum,  
--         Notes2,        LOC,              ID,           SKU,  
--         SKUDesc,       Qty,              TempQty1,  
--         TempQty2,      PrintedFlag,      Zone,  
--         Lot,           CarrierKey,       VehicleNo,    Lottable02,  
--         Lottable04,    packpallet,       packcasecnt,  packinner,  
--         packeaches,    externorderkey,   LogicalLOC,   Areakey,    UOM,  
--         Pallet_cal,    Cartons_cal,      inner_cal,    Each_cal,   Total_cal,  
--         DeliveryDate,  RetailSKU,        BuyerPO,      InvoiceNo,  OrderDate,  
--         Susr4,         Vat,              OVAS,         SKUGROUP,Lottable06,  
--         ShowLot06,ShowSKUBusr10,SKUBusr10, ShowPickDetailID,BatchNameField,  
--         LOCPickzone,ConsigneeSKU,RepOvasWithConSKU,locaisle,locaisleseq,recgrp
--ORDER BY  Company, Orderkey, LOCPickzone, 
--            locaisleseq  ,Areakey, LogicalLOC, LOC, SKU  --CS01
     
   IF OBJECT_ID('tempdb..#TEMP_PICK') IS NOT NULL  
      DROP TABLE #TEMP_PICK  

   IF OBJECT_ID('tempdb..#TEMP_PICKRESULT') IS NOT NULL  
      DROP TABLE #TEMP_PICKRESULT 
  
   WHILE @@TRANCOUNT < @n_starttcnt  
   BEGIN  
      BEGIN TRAN  
   END  
END  

GO