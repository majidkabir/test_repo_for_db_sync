SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/      
/* Stored Proc : isp_GetPickSlipOrders56                                   */      
/* Creation Date:                                                          */      
/* Copyright: LF                                                           */      
/* Written by:                                                             */      
/*                                                                         */      
/* Purpose: SOS322295 - SG Prestige Pick Slip                              */      
/*                                                                         */      
/*                                                                         */      
/* Usage:                                                                  */      
/*                                                                         */      
/* Local Variables:                                                        */      
/*                                                                         */      
/* Called By: r_dw_print_pickorder56                                       */      
/*                                                                         */      
/* PVCS Version: 1.4                                                       */      
/*                                                                         */      
/* Version: 5.4                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date        Author  Ver  Purposes                                       */    
/* 2015-Apr-27 CSCHONG 1.0  SOS339329 (CS01)                               */  
/* 2015-Aug-24 CSCHONG 1.1  SOS339780 (CS02)                               */   
/* 2015-Oct-28 CSCHONG 1.2  SOS355799 (CS03)                               */   
/* 2015-Nov-16 CSCHONG 1.3  SOS355799 change Lottale02 to lotttab01 (CS04) */  
/* 2016-AUG-29 WAN02   1.4  SOS#375410 Picklist Revision (Mandom)          */  
/* 2016-DEC-08 CSCHONG 1.5  WMS-770 Add new field and logic (CS05)         */  
/* 2017-Jan-20 CSCHONG 1.6  IN00247699 Fix duplicate report desc (CS05a)   */  
/* 2017-FEB-06 CSCHONG 1.7  WMS-770-revise report layout (CS06)            */  
/* 2022-JUL-14 MINGLE  1.8  WMS-20212-add pickzone (ML01)                  */  
/***************************************************************************/      
      
CREATE PROC [dbo].[isp_GetPickSlipOrders56] (@c_loadkey NVARCHAR(10))       
 AS      
BEGIN    
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF      
       
   DECLARE @c_pickheaderkey NVARCHAR(10),    
           @n_continue INT,    
           @c_errmsg NVARCHAR(255),    
           @b_success INT,    
           @n_err INT,    
           @c_sku NVARCHAR(20),    
           @n_qty INT,    
           @c_loc NVARCHAR(10),    
           @n_cases INT,    
           @n_perpallet INT,    
           @c_storer NVARCHAR(15),    
           @c_orderkey NVARCHAR(10),    
           @c_ConsigneeKey NVARCHAR(15),    
           @c_Company NVARCHAR(45),    
           @c_Addr1 NVARCHAR(45),    
           @c_Addr2 NVARCHAR(45),    
           @c_Addr3 NVARCHAR(45),    
           @c_PostCode NVARCHAR(15),    
           @c_Route NVARCHAR(10),    
           @c_Route_Desc NVARCHAR(60),    
           @c_TrfRoom NVARCHAR(5),    
           @c_Notes1 NVARCHAR(60),    
           @c_Notes2 NVARCHAR(60),    
           @c_SkuDesc NVARCHAR(60),    
           @n_CaseCnt INT,    
           @n_PalletCnt INT,    
           @c_ReceiptTm NVARCHAR(20),    
           @c_PrintedFlag NVARCHAR(1),    
           @c_UOM NVARCHAR(10),    
           @n_UOM3 INT,    
           @c_Lot NVARCHAR(10),    
           @c_StorerKey NVARCHAR(15),    
           @c_Zone NVARCHAR(1),    
           @n_PgGroup INT,    
          @n_TotCases INT,    
           @n_RowNo INT,    
           @c_PrevSKU NVARCHAR(20),    
           @n_SKUCount INT,    
           @c_Carrierkey NVARCHAR(60),    
           @c_VehicleNo NVARCHAR(10),    
           @c_firstorderkey NVARCHAR(10),    
           @c_superorderflag NVARCHAR(1),    
           @c_firsttime NVARCHAR(1),    
           @c_logicalloc NVARCHAR(18),    
           @c_Lottable02 NVARCHAR(10),    
           @d_Lottable04 DATETIME,    
           @n_packpallet INT,    
           @n_packcasecnt INT,    
           @c_externorderkey NVARCHAR(30),    
           @n_pickslips_required INT,    
           @c_areakey NVARCHAR(10),    
           @c_skugroup NVARCHAR(10)       
       
   DECLARE @c_PrevOrderKey     NVARCHAR(10),    
           @n_Pallets          INT,    
           @n_Cartons          INT,    
           @n_Eaches           INT,    
           @n_UOMQty           INT      
             
   /*CS05a Start*/  
    DECLARE @c_getPickslipno NVARCHAR(10)  
           ,@c_getloadkey NVARCHAR(20)  
           ,@c_getorderkey NVARCHAR(50)  
           ,@c_Rptdescr NVARCHAR(150)  
     
   /*CS05a END*/          
    
   DECLARE @n_starttcnt INT    
   SELECT  @n_starttcnt = @@TRANCOUNT    
    
   WHILE @@TRANCOUNT > 0    
   BEGIN    
      COMMIT TRAN    
   END    
    
 SET @n_pickslips_required = 0 -- (Leong01)    
     
   BEGIN TRAN      
   CREATE TABLE #TEMP_PICK    
   (    
      PickSlipNo         NVARCHAR(10) NULL,    
      LoadKey            NVARCHAR(10),    
      OrderKey           NVARCHAR(10),    
      ConsigneeKey       NVARCHAR(15),    
      Company            NVARCHAR(45),    
      Addr1              NVARCHAR(45) NULL,    
      Addr2              NVARCHAR(45) NULL,    
      Addr3              NVARCHAR(45) NULL,    
      PostCode           NVARCHAR(15) NULL,    
      ROUTE              NVARCHAR(10) NULL,    
      Route_Desc         NVARCHAR(60) NULL,    
      TrfRoom            NVARCHAR(5) NULL,    
      Notes1             NVARCHAR(60) NULL,    
      Notes2             NVARCHAR(60) NULL,    
      LOC                NVARCHAR(10) NULL,    
      ID                 NVARCHAR(18) NULL,    
      SKU                NVARCHAR(20),    
      SkuDesc            NVARCHAR(60),    
      Qty                INT,    
      TempQty1           INT,    
      TempQty2           INT,    
      PrintedFlag        NVARCHAR(1) NULL,    
      Zone               NVARCHAR(1),    
      PgGroup            INT,    
      RowNum             INT,    
      Lot                NVARCHAR(10),    
      Carrierkey         NVARCHAR(60) NULL,    
      VehicleNo          NVARCHAR(10) NULL,    
      Lottable02         NVARCHAR(18) NULL,    
      Lottable04         DATETIME NULL,    
      packpallet         INT,    
      packcasecnt        INT,    
      packinner          INT,    
      packeaches         INT,    
      externorderkey     NVARCHAR(30) NULL,    
      LogicalLoc         NVARCHAR(18) NULL,    
      Areakey            NVARCHAR(10) NULL,    
      UOM                NVARCHAR(10),    
      Pallet_cal         INT,    
      Cartons_cal        INT,    
      inner_cal          INT,    
      Each_cal           INT,    
      Total_cal          INT,    
      DeliveryDate       DATETIME NULL,    
      RetailSku          NVARCHAR(20) NULL,    
      BuyerPO            NVARCHAR(20) NULL,    
      InvoiceNo          NVARCHAR(10) NULL,    
      OrderDate          DATETIME NULL,    
      Susr4              NVARCHAR(18) NULL,    
      vat                NVARCHAR(18) NULL,    
      OVAS               NVARCHAR(30) NULL,    
      SKUGROUP           NVARCHAR(10) NULL,    
      Storerkey          NVARCHAR(15) NULL,    
      Country            NVARCHAR(20) NULL,    
      Brand              NVARCHAR(50) NULL,    
      QtyOverAllocate    INT NULL, --NJOW01    
      QtyPerCarton       NVARCHAR(30) NULL,         --(Wan01)   
      ConsSUSR3        NVARCHAR(20) NULL,  
      ConsSUSR4        NVARCHAR(20) NULL,  
      ConsNotes1       NVARCHAR(255) NULL,  
      SensorTag NVARCHAR(10) NULL,  
      Style            NVARCHAR(20) NULL,            --(CS02)  
      MANUFACTURERSKU  NVARCHAR(20) NULL,             --(CS02)  
      ShowSkuField     INT          NULL,             --(CS02)  
      stdcude          float,                         --(CS02)  
      GrossWgt         float                          --(CS02)  
   ,  ShowItemClass    INT NULL                       --(Wan02)   
   ,  ItemClass        NVARCHAR(10) NULL              --(Wan02)   
   ,  ShowExtraField   INT                            --(CS05)  
   ,  RptDescr         NVARCHAR(100) NULL              --(CS05)  
   ,  SensorTagReq     NVARCHAR(5) NULL               --(CS05)  
   ,  BrandDesc        NVARCHAR(150) NULL             --(CS05)  
   ,  SKUGRP           NVARCHAR(50) NULL              --(CS05)    
   ,  Lottable03       NVARCHAR(18) NULL              --(CS06)  
   ,  LLIID            NVARCHAR(18) NULL              --(CS06)  
   ,  PickZone         NVARCHAR(10) NULL              --(ML01)  
   )    
       
   --NJOW01 Start    
   SELECT TOP 1 @c_storerkey = Storerkey    
   FROM ORDERS (NOLOCK)    
   WHERE Loadkey = @c_Loadkey    
       
   SELECT DISTINCT PD.Pickdetailkey, TP.Orderkey    
   INTO #EARLYPICK    
   FROM PICKDETAIL PD (NOLOCK)    
   JOIN (SELECT P.Orderkey, P.Pickdetailkey, P.Lot, P.Loc, P.ID    
         FROM ORDERS O (NOLOCK)     
         JOIN PICKDETAIL P (NOLOCK) ON O.Orderkey = P.Orderkey    
         JOIN SKUXLOC SL (NOLOCK) ON P.Storerkey = SL.Storerkey AND P.Sku = SL.Sku AND P.Loc = SL.Loc           
         --WHERE  P.Status < '5'    
         where SL.LocationType IN ('PICK','CASE')    
         AND O.LoadKey = @c_LoadKey) TP ON PD.Lot = TP.Lot AND PD.Loc = TP.Loc AND PD.ID = TP.ID     
                                        AND PD.Pickdetailkey <= TP.Pickdetailkey     
  WHERE PD.Status <= '9'         
  AND PD.Storerkey = @c_Storerkey    
      
  SELECT EP.Orderkey, LLI.Lot, LLI.Loc, LLI.Id, (LLI.Qty - SUM(PD.Qty)) AS QtyOverAllocate    
  INTO #TMP_OVERALLOCATE    
  FROM #EARLYPICK EP    
  JOIN PICKDETAIL PD (NOLOCK) ON EP.Pickdetailkey = PD.Pickdetailkey    
  JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.Id = LLI.Id    
  GROUP BY EP.Orderkey, LLI.Lot, LLI.Loc, LLI.Id, LLI.Qty    
  HAVING LLI.Qty - SUM(PD.Qty) < 0    
  --NJOW01 End    
  
    --(CS02) - START  
   SELECT Storerkey,  
         ShowSkufield   =  ISNULL(MAX(CASE WHEN Code = 'SHOWSKUFIELD'  THEN 1 ELSE 0 END),0)   
         ,ShowPriceTag   =  ISNULL(MAX(CASE WHEN Code = 'SHOWPRICETAG'  THEN 1 ELSE 0 END),0)   --CS03   
         ,ShowItemClass  =  ISNULL(MAX(CASE WHEN Code = 'ShowItemClass'  THEN 1 ELSE 0 END),0)  --Wan02   
         ,ShowExtraField =  ISNULL(MAX(CASE WHEN Code = 'ShowExtraField'  THEN 1 ELSE 0 END),0)  --CS05   
   INTO #TMP_RPTCFG  
   FROM CODELKUP WITH (NOLOCK)  
   WHERE ListName = 'REPORTCFG'  
   AND Long      = 'r_dw_print_pickorder56'  
   AND (Short IS NULL OR Short <> 'N')  
   GROUP BY Storerkey  
   --(CS02) - END  
  
                      
   INSERT INTO #TEMP_PICK    
     (    
       PickSlipNo,    
       LoadKey,    
       OrderKey,    
       ConsigneeKey,    
       Company,    
       Addr1,    
       Addr2,    
       PgGroup,    
       Addr3,    
       PostCode,    
       ROUTE,    
       Route_Desc,    
       TrfRoom,    
       Notes1,    
       RowNum,    
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
       Lot,    
       CarrierKey,    
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
       Vat,    
       OVAS,    
       SKUGROUP,    
       Storerkey,    
       Country,    
       Brand,    
       QtyOverAllocate, --NJOW01    
       QtyPerCarton,     -- (Wan01)    
       ConsSUSR3,      ConsSUSR4,       ConsNotes1,  SensorTag,  
       Style,MANUFACTURERSKU,showskufield, stdcude ,GrossWgt                           --(CS02)  
      ,ShowItemClass                                                                   --(Wan02)  
      ,ItemClass                                                                       --(Wan02)  
      ,ShowExtraField,RptDescr,SensorTagReq,BrandDesc,SKUGRP,Lottable03,LLIID            --(CS05)   --(CS06)  
		,PickZone --ML01  
      )  
   SELECT (    
              SELECT PICKHEADERKEY    
              FROM   PICKHEADER WITH (NOLOCK)    
              WHERE  ExternOrderKey     = @c_LoadKey    
                     AND OrderKey       = PickDetail.OrderKey    
                     AND ZONE           = '3'    
          ),    
          @c_LoadKey                     AS LoadKey,    
          PickDetail.OrderKey,    
          ISNULL(ORDERS.ConsigneeKey, '') AS ConsigneeKey,    
          ISNULL(ORDERS.c_Company, '')   AS Company,    
          ISNULL(ORDERS.C_Address1, '')  AS Addr1,    
          ISNULL(ORDERS.C_Address2, '')  AS Addr2,    
          0                              AS PgGroup,    
          ISNULL(ORDERS.C_Address3, '')  AS Addr3,    
          ISNULL(ORDERS.C_Zip, '')       AS PostCode,    
          ISNULL(ORDERS.Route, '')       AS ROUTE,    
          ISNULL(RouteMaster.Descr, '')     Route_Desc,    
          CONVERT(NVARCHAR(5), ORDERS.Door)  AS TrfRoom,    
          CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')) Notes1,    
          0                              AS RowNo,    
          CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) Notes2,    
          PickDetail.loc,    
          PickDetail.id,    
          UPPER(PickDetail.sku),    
    --PickDetail.sku,  
          ISNULL(Sku.Descr, '')             SkuDescr,    
          SUM(PickDetail.qty)            AS Qty,    
          1                              AS UOMQTY,    
          0                              AS TempQty2,    
          ISNULL(    
              (    
                  SELECT DISTINCT 'Y'    
                  FROM   PickHeader(NOLOCK)    
                  WHERE  ExternOrderKey     = @c_Loadkey    
                         AND Zone           = '3'    
              ),    
              'N'    
          )                              AS PrintedFlag,    
          '3' Zone,    
          '' AS PickdetailLot,    
          '' CarrierKey,    
          '' AS                             VehicleNo,    
          --CASE WHEN ISNULL(orders.c_country,'') = 'TH' THEN LotAttribute.Lottable01 ELSE LotAttribute.Lottable02 END Lottable02,   --(CS01)  --CS04  
          LotAttribute.Lottable01 Lottable02 , --CS04  
          ISNULL(LotAttribute.Lottable04, '19000101') Lottable04,    
          PACK.Pallet,    
          PACK.CaseCnt,    
          pack.innerpack,    
          PACK.Qty,    
          ORDERS.ExternOrderKey          AS ExternOrderKey,    
          ISNULL(LOC.LogicalLocation, '') AS LogicalLocation,    
          ISNULL(AreaDetail.AreaKey, '00') AS Areakey,    
          ISNULL(OrderDetail.UOM, '')    AS UOM,    
          Pallet_cal = CASE Pack.Pallet    
                            WHEN 0 THEN 0    
                            ELSE FLOOR(SUM(PickDetail.qty) / Pack.Pallet)    
                       END,    
          Cartons_cal = 0,    
          inner_cal   = 0,    
          Each_cal    = 0,    
          Total_cal   = SUM(pickdetail.qty),    
          ISNULL(ORDERS.DeliveryDate, '19000101') DeliveryDate,    
          ISNULL(Sku.RetailSku, '')         RetailSku,    
          ISNULL(ORDERS.BuyerPO, '')        BuyerPO,    
          ISNULL(ORDERS.InvoiceNo, '')      InvoiceNo,    
          ISNULL(ORDERS.OrderDate, '19000101') OrderDate,    
          SKU.Susr4,    
          ST.vat,    
          SKU.OVAS,    
          SKU.SKUGROUP,    
          ORDERS.Storerkey,    
          CASE     
               WHEN ORDERS.C_ISOCntryCode IN ('ID', 'IN', 'KR', 'PH', 'TH', 'TW', 'VN') THEN     
                    'EXPORT'    
               ELSE ISNULL(ORDERS.C_ISOCntryCode, '')    
          END,    
          ISNULL(BRAND.BrandName, ''),    
          /*CASE WHEN SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) < 0 THEN    
                    SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) * -1    
               ELSE 0 END AS QtyOverAllocate  --NJOW01*/    
          (SUM(ISNULL(lli.QtyOverAllocate,0)) * -1) AS QtyOverAllocate,  --NJOW01    
--(Wan01) - START    
          RTRIM(PACK.Packkey) + ' = ' + CONVERT(VARCHAR(10), PACK.CaseCnt ),    
--(Wan01) - END   
--CS03 Start    
          CASE WHEN ISNULL(rc.ShowPricetag,'0') = '1' THEN   
               CASE WHEN orders.Userdefine02='Y' THEN 'PRICE TAG' ELSE '' END  
          ELSE ISNULL(st.Susr3,'') END , --CS03 END  
          ISNULL(st.Susr4,''),  
          LEFT(ISNULL(st.Notes1,''),255),  
          CASE WHEN ISNULL(st.Susr4,'') = 'SECURITY TAG' AND Sku.Price > 50 THEN 'YES' ELSE '' END ,  
          sku.style,sku.MANUFACTURERSKU,ISNULL(RC.showskufield,0),sku.STDCUBE,sku.GrossWgt   --(CS02)  
         ,ShowItemClass = ISNULL(RTRIM(RC.showitemclass),0)                                 --(Wan02)   
         ,ItemClass = ISNULL(RTRIM(SKU.itemclass),'')                                        --(Wan02)  
         ,ShowExtraField = ISNULL(RTRIM(RC.showextrafield),0)                               --(CS05)  
         /*CS05 start*/  
         --,RptDescr =  CASE SC1.ConfigKey   
         --               WHEN 'PriceTag' THEN 'PriceTag'   
         --               WHEN 'AllowPartialAllocation' THEN 'Partial'  
         --               WHEN 'DeliverWithSalesInvoice' THEN 'Invoice'  
         --               WHEN 'DeliverWithDeliveryOrder' THEN 'Delivery Order'  
         --               ELSE '' END  
         --,PriceTag.RptDescr      --(CS05a)  
         ,''                       --(CS05a)  
         , SensorTagReq = CASE WHEN SC2.configkey='SensorTag' AND Sku.Price >= 50 THEN 'Y' ELSE '' END     
         ,BrandDesc  = CL.[Description]                                                                                                    
         ,SKUGRP = CASE WHEN Substring(ISNULL(CL1.[Description],'SS-'),1,3) <> 'SS-' THEN 'SS-' + ISNULL(CL1.[Description],'') ELSE ISNULL(CL1.[Description],'') END   
         /*CS05 END*/   
         ,LotAttribute.Lottable03 Lottable03,ISNULL(LLID.id,'')  --CS06   
			,LOC.PickZone --ML01  
   FROM   pickdetail(NOLOCK)    
          JOIN orders(NOLOCK)    
               ON  pickdetail.orderkey = orders.orderkey    
          JOIN lotattribute(NOLOCK)    
               ON  pickdetail.lot = lotattribute.lot    
          JOIN loadplandetail(NOLOCK)    
               ON  pickdetail.orderkey = loadplandetail.orderkey    
          JOIN orderdetail(NOLOCK)    
               ON  pickdetail.orderkey = orderdetail.orderkey    
               AND pickdetail.orderlinenumber = orderdetail.orderlinenumber    
          JOIN storer(NOLOCK)    
               ON  pickdetail.storerkey = storer.storerkey    
          JOIN sku(NOLOCK)    
               ON  pickdetail.sku = sku.sku    
               AND pickdetail.storerkey = sku.storerkey    
          JOIN pack(NOLOCK)    
               ON  pickdetail.packkey = pack.packkey    
          JOIN loc(NOLOCK)    
               ON  pickdetail.loc = loc.loc    
          LEFT JOIN routemaster(NOLOCK)    
               ON  orders.route = routemaster.route    
          LEFT JOIN areadetail(NOLOCK)    
               ON  loc.putawayzone = areadetail.putawayzone    
          LEFT JOIN storer st(NOLOCK)    
               ON  orders.consigneekey = st.storerkey    
          LEFT JOIN (    
                   SELECT O.Orderkey,    
                          MAX(SUBSTRING(LTRIM(ISNULL(CL.Description, '')), 6, 50)) AS     
                          BrandName    
                   FROM   ORDERS O(NOLOCK)    
                          JOIN ORDERDETAIL OD(NOLOCK)    
                               ON  O.Orderkey = OD.Orderkey    
                          JOIN SKU(NOLOCK)    
                               ON  OD.Storerkey = SKU.Storerkey    
                               AND OD.Sku = SKU.Sku    
                          LEFT JOIN CODELKUP CL(NOLOCK)    
         ON  SKU.ItemClass = CL.Code    
                               AND CL.Listname = 'ITEMCLASS'    
                   WHERE  O.Loadkey = @c_Loadkey    
                   GROUP BY    
                          O.Orderkey    
                   HAVING COUNT(    
                              DISTINCT SUBSTRING(LTRIM(ISNULL(CL.Description, '')), 6, 50)    
                          ) = 1    
               ) BRAND    
               ON  ORDERS.Orderkey = BRAND.Orderkey    
          LEFT JOIN #TMP_OVERALLOCATE lli (NOLOCK)    
               ON pickdetail.Lot = lli.Lot    
               AND pickdetail.Loc = lli.Loc    
               AND pickdetail.ID = lli.ID    
               AND pickdetail.Orderkey = lli.Orderkey   
          LEFT JOIN LOTXLOCXID  LLID (NOLOCK)  ON pickdetail.Lot = LLID.Lot    
               AND pickdetail.Loc = LLID.Loc    
               AND pickdetail.ID = LLID.ID     
          LEFT JOIN #TMP_RPTCFG RC ON (ORDERS.Storerkey = RC.Storerkey)        --(CS02)   
         -- LEFT JOIN StorerConfig SC1 ON SC1.storerkey = ORDERS.ConsigneeKey    --(CS05)  
          LEFT JOIN Storerconfig SC2 ON SC2.storerkey = ORDERS.ConsigneeKey AND SC2.Configkey = 'SensorTag'   --(CS05)  
          /*CS05a start*/  
     --     LEFT JOIN (SELECT orderkey,RptDescr = STUFF(  
     --        (SELECT ',' + CASE SC1.ConfigKey   
     --                   WHEN 'PriceTag' THEN 'PriceTag'   
     --                   WHEN 'AllowPartialAllocation' THEN 'Partial'  
     --                   WHEN 'DeliverWithSalesInvoice' THEN 'Invoice'  
     --                   WHEN 'DeliverWithDeliveryOrder' THEN 'Delivery Order'  
     --                   ELSE '' END  
     --          FROM ORDERS ORD (NOLOCK)  
     --LEFT JOIN StorerConfig sc1 WITH (NOLOCK) ON sc1.StorerKey=ord.ConsigneeKey  
     --WHERE ord.loadkey=@c_Loadkey  
     --AND sc1.configkey <> 'SensorTag'  
     --ORDER BY  CASE SC1.ConfigKey   
     --                   WHEN 'PriceTag' THEN 'PriceTag'   
     --                   WHEN 'AllowPartialAllocation' THEN 'Partial'  
     --                   WHEN 'DeliverWithSalesInvoice' THEN 'Invoice'  
     --                   WHEN 'DeliverWithDeliveryOrder' THEN 'Delivery Order'  
     --                   ELSE '' END desc  
     --         FOR XML PATH (''))  
     --        , 1, 1, '') from orders t2  
     --        WHERE loadkey=@c_Loadkey  ) PriceTag ON PriceTag.orderkey=ORDERS.OrderKey      
     /*CS05a End*/    
      LEFT JOIN CODELKUP CL WITH (NOLOCK)  ON CL.Code=SKU.itemclass AND CL.LISTNAME='ITEMCLASS' AND CL.Storerkey=orders.storerkey     
      LEFT JOIN CODELKUP CL1 WITH (NOLOCK)  ON CL1.Code=SKU.SKUGroup AND CL1.LISTNAME='SKUGroup' AND CL1.Storerkey=orders.storerkey     
   --WHERE  PickDetail.Status < '5'    
          where LoadPlanDetail.LoadKey = @c_LoadKey    
   GROUP BY    
          PickDetail.OrderKey,    
          ISNULL(ORDERS.ConsigneeKey, ''),    
          ISNULL(ORDERS.c_Company, ''),    
          ISNULL(ORDERS.C_Address1, ''),    
          ISNULL(ORDERS.C_Address2, ''),    
          ISNULL(ORDERS.C_Address3, ''),    
          ISNULL(ORDERS.C_Zip, ''),    
          ISNULL(ORDERS.Route, ''),    
          ISNULL(RouteMaster.Descr, ''),    
          CONVERT(NVARCHAR(5), ORDERS.Door),    
          CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')),    
          CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')),    
          PickDetail.loc,    
          PickDetail.id,    
          PickDetail.sku,    
          ISNULL(Sku.Descr, ''),    
          --Pickdetail.Lot,    
          --CASE WHEN ISNULL(orders.c_country,'') = 'TH' THEN LotAttribute.Lottable01 ELSE LotAttribute.Lottable02 END,--LotAttribute.Lottable02,  --(CS01) --CS04  
          LotAttribute.Lottable01,               --CS04  
          ISNULL(LotAttribute.Lottable04, '19000101'),    
          PACK.Pallet,    
          PACK.CaseCnt,    
          pack.innerpack,    
          PACK.Qty,    
          ORDERS.ExternOrderKey,    
          ISNULL(LOC.LogicalLocation, ''),    
          ISNULL(AreaDetail.AreaKey, '00'),    
          ISNULL(OrderDetail.UOM, ''),    
          ISNULL(ORDERS.DeliveryDate, '19000101'),    
          ISNULL(Sku.RetailSku, ''),    
          ISNULL(ORDERS.BuyerPO, ''),    
          ISNULL(ORDERS.InvoiceNo, ''),    
          ISNULL(ORDERS.OrderDate, '19000101'),    
          SKU.Susr4,    
          ST.vat,    
          SKU.OVAS,    
          SKU.SKUGROUP,    
          ORDERS.Storerkey,    
          CASE     
               WHEN ORDERS.C_ISOCntryCode IN ('ID', 'IN', 'KR', 'PH', 'TH', 'TW', 'VN') THEN     
                    'EXPORT'    
               ELSE ISNULL(ORDERS.C_ISOCntryCode, '')    
          END,    
          ISNULL(BRAND.BrandName, ''),     
--(Wan01) - START    
          RTRIM(PACK.Packkey) + ' = ' + CONVERT(VARCHAR(10), PACK.CaseCnt ),    
--(Wan01) - END                 
          ISNULL(st.Susr3,''),  
          ISNULL(st.Susr4,''),  
          LEFT(ISNULL(st.Notes1,''),255),  
          CASE WHEN ISNULL(st.Susr4,'') = 'SECURITY TAG' AND Sku.Price > 50 THEN 'YES' ELSE '' END,  
          sku.style,sku.MANUFACTURERSKU,ISNULL(RC.showskufield,0),sku.STDCUBE,sku.GrossWgt,  
         ISNULL(rc.ShowPricetag,'0'),Orders.userdefine02    --CS03     
         ,ISNULL(RTRIM(RC.showitemclass),0)                                     --(Wan02)   
         ,ISNULL(RTRIM(SKU.itemclass),'')                                        --(Wan02)       
         ,ISNULL(RTRIM(RC.showextrafield),0)                                   --(CS05)  
         /*CS05 start*/  
         --, CASE SC1.ConfigKey   
         --               WHEN 'PriceTag' THEN 'PriceTag'   
         --               WHEN 'AllowPartialAllocation' THEN 'Partial'  
         --               WHEN 'DeliverWithSalesInvoice' THEN 'Invoice'  
         --               WHEN 'DeliverWithDeliveryOrder' THEN 'Delivery Order'  
         --               ELSE '' END  
         --,PriceTag.RptDescr                                                            --(CS05a)  
         , CASE WHEN SC2.configkey='SensorTag' AND Sku.Price >= 50 THEN 'Y' ELSE '' END   
         ,  CL.[Description]  
         , CL1.[Description]  
         /*CS05 END*/   
         ,LotAttribute.Lottable03,LLID.id                   --(CS06)  
			,LOC.PickZone --ML01  
           
           
   /*CS05a Start*/  
       DECLARE CUR_RPTDESCR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT pickslipno,LoadKey,OrderKey     
   FROM   #TEMP_PICK  
   WHERE loadkey = @c_loadkey    
    
   OPEN CUR_RPTDESCR     
       
   FETCH NEXT FROM CUR_RPTDESCR INTO @c_getPickslipno  ,@c_getloadkey,  @c_getorderkey  
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      
    SELECT @c_RptDescr = STUFF(  
             (SELECT ',' + CASE SC1.ConfigKey   
                        WHEN 'PriceTag' THEN 'PriceTag'   
                        WHEN 'AllowPartialAllocation' THEN 'Partial'  
                        WHEN 'DeliverWithSalesInvoice' THEN 'Invoice'  
                        WHEN 'DeliverWithDeliveryOrder' THEN 'Delivery Order'  
                        ELSE '' END  
               FROM ORDERS ORD (NOLOCK)  
     LEFT JOIN StorerConfig sc1 WITH (NOLOCK) ON sc1.StorerKey=ord.ConsigneeKey  
     WHERE ord.loadkey=@c_getloadkey  
     AND ord.orderkey = @c_getorderkey  
     AND sc1.configkey <> 'SensorTag'  
               ORDER BY  CASE SC1.ConfigKey   
                        WHEN 'PriceTag' THEN 'PriceTag'   
                        WHEN 'AllowPartialAllocation' THEN 'Partial'  
                        WHEN 'DeliverWithSalesInvoice' THEN 'Invoice'  
                        WHEN 'DeliverWithDeliveryOrder' THEN 'Delivery Order'  
                        ELSE '' END desc  
              FOR XML PATH (''))  
             , 1, 1, '') from orders t2  
             WHERE loadkey=@c_getloadkey AND orderkey = @c_getorderkey  
             ORDER BY orderkey  
  
  UPDATE #TEMP_PICK  
  SET rptdescr = @c_Rptdescr  
  WHERE PickSlipNo=@c_getPickslipno  
  AND LoadKey = @c_getloadkey  
  AND OrderKey = @c_getorderkey  
  
   SET @c_RptDescr = ''  
  
  
   FETCH NEXT FROM CUR_RPTDESCR INTO @c_getPickslipno  ,@c_getloadkey,  @c_getorderkey  
   END      
     
   CLOSE CUR_RPTDESCR  
   DEALLOCATE CUR_RPTDESCR  
     
   /*CS05a END*/                                        
                
   UPDATE #temp_pick    
   SET    cartons_cal = CASE packcasecnt    
                             WHEN 0 THEN 0    
         ELSE FLOOR(total_cal / packcasecnt)    
                        END      
       
   UPDATE #temp_pick    
   SET    inner_cal = CASE packinner    
                           WHEN 0 THEN 0    
                           ELSE FLOOR(total_cal / packinner) -((packcasecnt * cartons_cal) / packinner)    
                      END      
       
   UPDATE #temp_pick    
   SET    each_cal = total_cal -(packcasecnt * cartons_cal) -(packinner * inner_cal)     
       
   --NJOW01 Start     
   SELECT tp.Orderkey,     
          SUM(tp.QtyOverAllocate) AS TotalQtyOverAllocate     
--          CASE WHEN (tp.company LIKE '%TAKA%' OR tp.company LIKE 'OG%' OR tp.company LIKE '%BHG%')     
--                    AND o.facility = 'SL01'     
--                    AND tp.Notes1 NOT LIKE '%FOC%' AND tp.Notes1 NOT LIKE '%NPT%'    
--                    AND (tp.Invoiceno LIKE '17%' OR tp.InvoiceNo LIKE '47%') THEN    
--                'Y'    
--          ELSE 'N' END AS PriceTag    
       ,  ISNULL(RTRIM(CL.Description),'') AS PriceTag    
   INTO #temp_ordsum    
   FROM #temp_pick tp    
--(Wan01) - START    
   LEFT JOIN STORER   CS WITH (NOLOCK) ON (tp.consigneekey = CS.Storerkey)    
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.Listname = 'TitleRem' AND CS.Fax2 = CL.Code AND CL.Storerkey = @c_Storerkey)    
   GROUP BY tp.Orderkey    
         ,  ISNULL(RTRIM(CL.Description),'')     
--   JOIN Orders o (NOLOCK) ON tp.Orderkey = o.Orderkey    
--   GROUP BY tp.Orderkey, tp.company, o.facility, tp.notes1, tp.invoiceno    
--(Wan01) - END    
       
   SELECT DISTINCT #temp_pick.Loc    
   INTO #temp_highbayloc    
   FROM #temp_pick    
   JOIN LOC (NOLOCK) ON #temp_pick.Loc = LOC.Loc    
--(Wan01) - START    
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'HighLight' AND LOC.PickZone = CL.Code AND CL.Storerkey = @c_Storerkey)    
   WHERE CL.Short = 'Y'    
--   WHERE LOC.Facility IN('SL01', 'SP01', 'SA01', 'SC01')     
--   AND LOC.LocationCategory <> 'BINS'     
--   AND ((LOC.PutawayZone LIKE 'LANDCOME%' AND LOC.LocLevel >= 4)     
--       OR (LOC.PutawayZone NOT LIKE 'LANDCOME%' AND LOC.LocLevel >= 5))     
--(Wan01) - END        
   --NJOW01 End    
                       
   BEGIN TRAN        
       
   UPDATE PickHeader WITH (ROWLOCK)    
   SET    PickType = '1',    
          TrafficCop = NULL,    
          EditDate = GETDATE(),    
          EditWho  = SUSER_NAME()    
   WHERE  ExternOrderKey = @c_LoadKey    
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
  ELSE BEGIN        
      IF @@TRANCOUNT > 0         
      BEGIN        
          COMMIT TRAN        
      END        
      ELSE BEGIN        
          SELECT @n_continue = 3        
          ROLLBACK TRAN        
      END        
  END        
    
  WHILE @@TRANCOUNT > 0    
  BEGIN    
     COMMIT TRAN    
  END    
    
   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)    
   FROM   #TEMP_PICK    
   WHERE ISNULL(RTRIM(PickSlipNo),'') = '' -- (Leong01)    
       
   IF @@ERROR <> 0    
   BEGIN    
       GOTO FAILURE    
   END    
   ELSE     
   IF @n_pickslips_required > 0    
   BEGIN    
      BEGIN TRAN    
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required      
      COMMIT TRAN    
    
      BEGIN TRAN    
    
       INSERT INTO PICKHEADER    
         (    
           PickHeaderKey,    
           OrderKey,    
           ExternOrderKey,    
           PickType,    
           Zone,    
           TrafficCop    
         )    
       SELECT 'P' + RIGHT (    
                  REPLICATE('0', 9) +    
                  dbo.fnc_LTrim(    
                      dbo.fnc_RTrim(    
                          STR(    
                              CAST(@c_pickheaderkey AS INT) + (    
                                  SELECT COUNT(DISTINCT orderkey)    
                                  FROM   #TEMP_PICK AS RANK    
                                  WHERE  RANK.OrderKey < #TEMP_PICK.OrderKey    
                                  AND ISNULL(RTRIM(Rank.PickSlipNo),'') = ''  -- (Leong01)    
                              )    
                          ) -- str    
                      )    
                  ) -- dbo.fnc_RTrim      
                  ,    
                  9    
              ),    
              OrderKey,    
              LoadKey,    
              '0',    
              '3',    
              ''    
       FROM   #TEMP_PICK    
       WHERE ISNULL(RTRIM(PickSlipNo),'') = '' -- (Leong01)    
       GROUP BY    
              LoadKey,    
              OrderKey    
           
       UPDATE #TEMP_PICK    
       SET    PickSlipNo = PICKHEADER.PickHeaderKey    
       FROM   PICKHEADER(NOLOCK)    
       WHERE  PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey    
              AND PICKHEADER.OrderKey = #TEMP_PICK.OrderKey    
              AND PICKHEADER.Zone = '3'    
              AND   ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = '' -- (Leong01)    
    
      WHILE @@TRANCOUNT > 0    
      BEGIN    
         COMMIT TRAN    
      END                  
   END    
       
   GOTO SUCCESS     
       
   FAILURE:      
   DELETE     
   FROM   #TEMP_PICK     
       
   SUCCESS:    
       
   SELECT    
--(Wan01) - START              
         #TEMP_PICK.PickSlipNo       
      ,  #TEMP_PICK.LoadKey              
      ,  #TEMP_PICK.OrderKey             
      ,  #TEMP_PICK.ConsigneeKey         
      ,  #TEMP_PICK.Company              
      ,  #TEMP_PICK.Addr1                
      ,  #TEMP_PICK.Addr2                
      ,  #TEMP_PICK.Addr3                
      ,  #TEMP_PICK.PostCode             
      ,  #TEMP_PICK.ROUTE                
      ,  #TEMP_PICK.Route_Desc           
      ,  #TEMP_PICK.TrfRoom              
      ,  #TEMP_PICK.Notes1               
      ,  #TEMP_PICK.Notes2               
      ,  UPPER(#TEMP_PICK.LOC) AS LOC      
      ,  #TEMP_PICK.ID                   
      ,  #TEMP_PICK.SKU                  
      ,  #TEMP_PICK.SkuDesc              
      ,  #TEMP_PICK.Qty                  
      ,  #TEMP_PICK.TempQty1             
      ,  #TEMP_PICK.TempQty2             
      ,  #TEMP_PICK.PrintedFlag          
      ,  #TEMP_PICK.Zone                 
      ,  #TEMP_PICK.PgGroup              
      ,  #TEMP_PICK.RowNum               
      ,  #TEMP_PICK.Lot                  
      ,  #TEMP_PICK.Carrierkey           
      ,  #TEMP_PICK.VehicleNo            
      ,  #TEMP_PICK.Lottable02           
      ,  #TEMP_PICK.Lottable04           
      ,  #TEMP_PICK.packpallet           
      ,  #TEMP_PICK.packcasecnt          
      ,  #TEMP_PICK.packinner            
      ,  #TEMP_PICK.packeaches           
      ,  #TEMP_PICK.externorderkey       
      ,  #TEMP_PICK.LogicalLoc           
      ,  #TEMP_PICK.Areakey     
      ,  #TEMP_PICK.UOM                  
      ,  #TEMP_PICK.Pallet_cal           
      ,  #TEMP_PICK.Cartons_cal          
      ,  #TEMP_PICK.inner_cal            
      ,  #TEMP_PICK.Each_cal             
      ,  #TEMP_PICK.Total_cal            
      ,  #TEMP_PICK.DeliveryDate         
,  #TEMP_PICK.RetailSku            
      ,  #TEMP_PICK.BuyerPO              
      ,  #TEMP_PICK.InvoiceNo            
      ,  #TEMP_PICK.OrderDate            
      ,  #TEMP_PICK.Susr4                
      ,  #TEMP_PICK.vat                  
      ,  #TEMP_PICK.OVAS                 
      ,  #TEMP_PICK.SKUGROUP             
      ,  #TEMP_PICK.Storerkey            
      ,  #TEMP_PICK.Country              
      ,  #TEMP_PICK.Brand                
      ,  #TEMP_PICK.QtyOverAllocate      
--(Wan01) - END        
      ,  #TEMP_ORDSUM.totalqtyoverallocate,    
          CASE WHEN ISNULL(#TEMP_HIGHBAYLOC.Loc,'') <> '' THEN    
               'Y'    
          ELSE 'N' END AS Highbayloc,    
          #TEMP_ORDSUM.PriceTag,    
          #TEMP_PICK.QtyPerCarton,          --(Wan01)       
          #TEMP_PICK.ConsSUSR3,  
          #TEMP_PICK.ConsSUSR4,  
          #TEMP_PICK.ConsNotes1,  
          #TEMP_PICK.SensorTag,  
          #TEMP_PICK.Style,                    --(CS02)  
          #TEMP_PICK.MANUFACTURERSKU,           --(CS02)  
          #TEMP_PICK.ShowSkufield,              --(CS02)    
          (#TEMP_PICK.Stdcude*#TEMP_PICK.Qty) /1000000 As [VolV3] ,   --(CS02)    
           (#TEMP_PICK.grosswgt*#TEMP_PICK.Qty) /1000 As [Wgt]  --(CS02)    
         ,#TEMP_PICK.ShowItemClass              --(Wan02)    
         ,#TEMP_PICK.ItemClass                  --(Wan02)        
         ,#TEMP_PICK.ShowExtraField,#TEMP_PICK.RptDescr,#TEMP_PICK.SensorTagReq,#TEMP_PICK.BrandDesc,#TEMP_PICK.SKUGRP    --(CS05)    
         ,#TEMP_PICK.Lottable03 ,#TEMP_PICK.LLIID                                                                         --(CS06)  
			,#TEMP_PICK.PickZone --ML01  
   FROM   #TEMP_PICK    
   JOIN   #TEMP_ORDSUM ON #TEMP_PICK.Orderkey = #TEMP_ORDSUM.Orderkey     
   LEFT JOIN #TEMP_HIGHBAYLOC ON #TEMP_PICK.Loc = #TEMP_HIGHBAYLOC.Loc    
       
   DROP TABLE #TEMP_PICK    
       
   WHILE @@TRANCOUNT < @n_starttcnt    
  BEGIN    
     BEGIN TRAN    
  END            
END

GO