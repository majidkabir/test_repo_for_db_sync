SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_GetPickSlipWave17                              */  
/* Creation Date: 20-JUN-2016                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-9631 - SG - THG - Pick Slip from Wave                   */  
/*                                                                      */  
/* Called By: RCM - Generate Pickslip                                   */  
/*          : Datawindow - r_dw_print_wave_pickslip_17                  */  
/* copy from Datawindow - r_dw_print_wave_pickslip_12                   */
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Purposes                                       */ 
/* 17-SEP-2019  LZG      INC0858321 - Performance tuning (ZG01)         */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GetPickSlipWave17] (  
@c_wavekey_type          NVARCHAR(13)  
)  
AS  
  
BEGIN  
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE @n_StartTCnt       INT  
         , @n_Continue        INT             
         , @b_Success         INT  
         , @n_Err             INT  
         , @c_Errmsg          NVARCHAR(255)  
           
   DECLARE @c_Wavekey         NVARCHAR(10)  
         , @c_Type            NVARCHAR(2)  
         , @c_Loadkey         NVARCHAR(10)  
         , @c_PickSlipNo      NVARCHAR(10)  
         , @c_RPickSlipNo   NVARCHAR(10)  
         , @c_PrintedFlag     NVARCHAR(1)   
   
   DECLARE @c_PickHeaderkey   NVARCHAR(10)   
         , @c_Storerkey       NVARCHAR(15)   
         , @c_ST_Company      NVARCHAR(45)  
         , @c_Orderkey        NVARCHAR(10)  
         , @c_OrderType       NVARCHAR(10)  
         , @c_Stop            NVARCHAR(10)  
         , @c_ExternOrderkey  NVARCHAR(50)     
  
         , @c_BuyerPO         NVARCHAR(20)  
         , @c_OrderGroup      NVARCHAR(20)  
         , @c_Sectionkey      NVARCHAR(10)  
         , @c_DeliveryDate    NVARCHAR(10)  
         , @c_Consigneekey    NVARCHAR(15)  
         , @c_C_Company       NVARCHAR(45)  
                             
  
         , @n_TotalCBM        FLOAT     
         , @n_TotalGrossWgt   FLOAT  
         , @n_noOfTotes       INT  
  
         , @c_PAZone             NVARCHAR(10) 
         , @c_PrevPAZone         NVARCHAR(10) 
         , @c_PADescr            NVARCHAR(60)   
         , @c_LogicalLoc         NVARCHAR(18)  
         , @c_Sku                NVARCHAR(20)  
         , @c_SkuDescr           NVARCHAR(60)  
         , @c_HazardousFlag      NVARCHAR(30)  
         , @c_Loc                NVARCHAR(10)  
         , @c_ID                 NVARCHAR(18)      
         , @c_DropID             NVARCHAR(20)   
         , @n_Qty                INT  
         , @c_UserDefine02       NVARCHAR(18) 
         , @n_NoOfLine           INT
         , @c_GetStorerkey       NVARCHAR(15)  
         , @c_pickZone           NVARCHAR(10)
         , @c_PZone              NVARCHAR(10)
         , @n_MaxRow             INT
         , @n_RowNo              INT
         , @n_CntRowNo           INT
         , @c_OrdKey             NVARCHAR(20)
         , @c_OrdLineNo          NVARCHAR(5)
         , @c_GetWavekey         NVARCHAR(10)
         , @c_GetPickSlipNo      NVARCHAR(10)    
         , @c_GetPickZone        NVARCHAR(10)
         , @c_GetOrdKey          NVARCHAR(20)
         , @c_GetLoadkey         NVARCHAR(10)
         , @c_PickDetailKey      NVARCHAR(18) 
         , @c_GetPickDetailKey   NVARCHAR(18) 
         , @c_ExecStatement      NVARCHAR(4000)
         , @c_GetPHOrdKey        NVARCHAR(20)
         , @c_GetWDOrdKey        NVARCHAR(20)
		 , @n_TTLPQty            INT 
        
  
  
   SET @n_StartTCnt  =  @@TRANCOUNT  
   SET @n_Continue   =  1  
  
   SET @c_PickHeaderkey = ''  
   SET @c_Storerkey     = ''  
   SET @c_ST_Company    = ''  
   SET @c_Orderkey      = ''  
   SET @c_OrderType     = ''  
   SET @c_Stop   = ''  
   SET @c_ExternOrderkey= ''  
  
   SET @c_BuyerPO       = ''  
   SET @c_Consigneekey  = ''  
   SET @c_C_Company     = ''       
   SET @c_RPickSlipNo   = ''                
  
   SET @n_TotalCBM      = 0.00  
   SET @n_TotalGrossWgt = 0.00  
   SET @n_noOfTotes     = 0  
                        
   SET @c_Sku           = ''  
   SET @c_SkuDescr      = ''  
   SET @c_HazardousFlag = ''  
   SET @c_Loc           = ''  
   SET @c_ID            = ''  
   SET @c_DropID        = ''  
   
   SET @c_PZone         = ''
  
  
   SET @n_Qty           = 0  
   SET @c_PADescr       = ''  
   SET @c_UserDefine02  = ''  
   SET @n_NoOfLine      =  1
   SET @c_GetStorerkey  = ''
   SET @n_CntRowNo      = 1
   --SET @n_MaxRow =  1
  
  
   WHILE @@TranCount > 0    
   BEGIN    
      COMMIT TRAN    
   END   
  
         
   CREATE TABLE #TMP_PICK  
   (  PickSlipNo         NVARCHAR(10) NULL,  
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
      Zone               NVARCHAR(10) NULL,  
      PgGroup            INT,  
      RowNum             INT,  
      Lot                NVARCHAR(10) NULL,  
      Carrierkey         NVARCHAR(60) NULL,  
      VehicleNo          NVARCHAR(10) NULL,  
      Lottable02         NVARCHAR(18) NULL,  
      Lottable04         DATETIME NULL,  
      packpallet         INT DEFAULT(0),  
      packcasecnt        INT DEFAULT(0),  
      packinner          INT DEFAULT(0),  
      packeaches         INT DEFAULT(0),  
      externorderkey     NVARCHAR(50) NULL,    
      LogicalLoc         NVARCHAR(18) NULL,  
      Areakey            NVARCHAR(10) NULL,  
      UOM                NVARCHAR(10) NULL,  
      Pallet_cal         INT DEFAULT(0),  
      Cartons_cal        INT DEFAULT(0),  
      inner_cal          INT DEFAULT(0),  
      Each_cal           INT  DEFAULT(0),  
      Total_cal          INT DEFAULT(0),  
      DeliveryDate       DATETIME NULL,  
      RetailSku          NVARCHAR(20) NULL,  
      BuyerPO            NVARCHAR(20) NULL,  
      InvoiceNo          NVARCHAR(20) NULL,  
      OrderDate          DATETIME NULL,  
      Susr4              NVARCHAR(18) NULL,  
      vat                NVARCHAR(18) NULL,  
      OVAS               NVARCHAR(30) NULL,  
      SKUGROUP           NVARCHAR(10) NULL,  
      Storerkey         NVARCHAR(15) NULL,  
      Country            NVARCHAR(20) NULL,  
      Brand              NVARCHAR(50) NULL,  
      QtyOverAllocate    INT NULL,  
      QtyPerCarton       NVARCHAR(30) NULL,            
      ConsSUSR3          NVARCHAR(20) NULL,
      ConsSUSR4          NVARCHAR(20) NULL,
      ConsNotes1         NVARCHAR(255) NULL,
      SensorTag          NVARCHAR(10) NULL,
      Style            NVARCHAR(20) NULL,            
      MANUFACTURERSKU  NVARCHAR(20) NULL,             
      ShowSkuField     INT          NULL,             
      stdcude          FLOAT DEFAULT(0),                         
      GrossWgt         FLOAT DEFAULT(0),
      OrderGrp         NVARCHAR(20) NULL,
      Wavekey          NVARCHAR(10) NULL,
      PAZone           NVARCHAR(10) NULL,
      Pickdetailkey    NVARCHAR(20) NULL,
      ALTSKU           NVARCHAR(20),
      CLKUPSHORT      NVARCHAR(1) NULL,
	  WVUDF02         NVARCHAR(30) NULL )      
      
      
   CREATE TABLE #TEMP_PICKBYZONE
   (  Pickslipno NVARCHAR(10), 
      PUTAZone   NVARCHAR(10) NULL  
      )   
  
   SET @c_Wavekey = SUBSTRING(@c_wavekey_type, 1, 10)  
   SET @c_Type    = SUBSTRING(@c_wavekey_type, 11,2)  
   
   
   SELECT TOP 1 @c_GetStorerkey = ORD.Storerkey
   FROM WAVEDETAIL WD  WITH (NOLOCK)
   JOIN ORDERS ORD WITH (NOLOCK) ON WD.Orderkey = ORD.OrderKey
   WHERE WD.Wavekey = @c_Wavekey  
   
   
   SELECT @n_NoOfLine = ISNULL(CONVERT(INT,short),1) 
   FROM codelkup (NOLOCK)
   WHERE listname = 'NIKEWAV' 
   AND code = 'PICKSLIP' 
   AND storerkey = @c_GetStorerkey 
   
   
   /*SELECT DISTINCT PD.Pickdetailkey, TP.Orderkey  
   INTO #EARLYPICK  
   FROM PICKDETAIL PD (NOLOCK)  
   JOIN (SELECT P.Orderkey, P.Pickdetailkey, P.Lot, P.Loc, P.ID  
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON  O.OrderKey=WD.OrderKey
         JOIN PICKDETAIL P (NOLOCK) ON O.Orderkey = P.Orderkey  
         JOIN SKUXLOC SL (NOLOCK) ON P.Storerkey = SL.Storerkey AND P.Sku = SL.Sku AND P.Loc = SL.Loc           -- ZG01
         WHERE  P.Status < '5'  
         AND SL.LocationType IN ('PICK','CASE')  
         AND WD.wavekey = @c_waveKey) TP ON PD.Lot = TP.Lot AND PD.Loc = TP.Loc AND PD.ID = TP.ID   
                                        AND PD.Pickdetailkey <= TP.Pickdetailkey   
  WHERE PD.Status < '9'       
  AND PD.Storerkey = @c_GetStorerkey  */
  
  SELECT P.Orderkey, P.Pickdetailkey, P.Lot, P.Loc, P.ID INTO #SUB_EARLYPICK
         FROM WAVEDETAIL WD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON  O.OrderKey=WD.OrderKey  
         JOIN PICKDETAIL P (NOLOCK) ON O.Orderkey = P.Orderkey    
         JOIN SKUXLOC SL (NOLOCK) ON P.Storerkey = SL.Storerkey AND P.Sku = SL.Sku AND P.Loc = SL.Loc           -- ZG01
         WHERE  P.Status < '5'    
         AND SL.LocationType IN ('PICK','CASE')    
         AND WD.wavekey = @c_waveKey

   SELECT DISTINCT PD.Pickdetailkey, TP.Orderkey    
   INTO #EARLYPICK    
   FROM PICKDETAIL PD (NOLOCK)    
   JOIN #SUB_EARLYPICK TP ON PD.Lot = TP.Lot AND PD.Loc = TP.Loc AND PD.ID = TP.ID     
                                        AND PD.Pickdetailkey <= TP.Pickdetailkey     
  WHERE PD.Status < '9'         
  AND PD.Storerkey = @c_GetStorerkey    
    
  SELECT EP.Orderkey, LLI.Lot, LLI.Loc, LLI.Id, (LLI.Qty - SUM(PD.Qty)) AS QtyOverAllocate  
  INTO #TMP_OVERALLOCATE  
  FROM #EARLYPICK EP  
  JOIN PICKDETAIL PD (NOLOCK) ON EP.Pickdetailkey = PD.Pickdetailkey  
  JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.Id = LLI.Id  
  GROUP BY EP.Orderkey, LLI.Lot, LLI.Loc, LLI.Id, LLI.Qty  
  HAVING LLI.Qty - SUM(PD.Qty) < 0  
  
   SELECT Storerkey,
         ShowSkufield   =  ISNULL(MAX(CASE WHEN Code = 'SHOWSKUFIELD'  THEN 1 ELSE 0 END),0)     
   INTO #TMP_RPTCFG
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND Long      = 'r_dw_print_wave_pickslip_17'
   AND (Short IS NULL OR Short <> 'N')
   GROUP BY Storerkey
   
   
    INSERT INTO #TMP_PICK  
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
                QtyOverAllocate,  
                QtyPerCarton,     
                ConsSUSR3,      ConsSUSR4,       ConsNotes1,  SensorTag,
                Style,MANUFACTURERSKU,showskufield, stdcude ,GrossWgt,OrderGrp,wavekey,PAZone,Pickdetailkey,
                ALTSKU,CLKUPSHORT,WVUDF02)  
                
          SELECT DISTINCT RefKeyLookup.PickSlipNo,  
          orders.loadkey                   AS LoadKey,  
          '',--PickDetail.OrderKey,  
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
          --CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')) 
		  '' as Notes1,  
          0                              AS RowNo,  
          --CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) 
		  '' as Notes2,  
          PickDetail.loc,  
          PickDetail.id,  
          PickDetail.sku,  
          ISNULL(Sku.Descr, '')             SkuDescr,  
          SUM(PickDetail.qty)            AS Qty,  
          1                              AS UOMQTY,  
          0                              AS TempQty2,  
          ISNULL((SELECT Distinct 'Y' FROM pickdetail WITH (NOLOCK) WHERE pickdetail.PickSlipNo = RefKeyLookup.PickSlipNo)
          , 'N') AS PrintedFlag,  
          loc.PickZone AS Zone, 
          '' AS PickdetailLot,  
          '' CarrierKey,  
          '' AS                     VehicleNo,  
          LotAttribute.Lottable01  Lottable02,   
          ISNULL(LotAttribute.Lottable04, '19000101') Lottable04,  
          PACK.Pallet,  
          PACK.CaseCnt,  
          pack.innerpack,  
          PACK.Qty,  
          '' AS ExternOrderKey,--ORDERS.ExternOrderKey          AS ExternOrderKey,  
          ISNULL(LOC.LogicalLocation, '') AS LogicalLocation,  
          '' AS Areakey,   --ISNULL(AreaDetail.AreaKey, '00') AS Areakey,  
          ISNULL(OrderDetail.UOM, '')    AS UOM,  
          Pallet_cal = CASE Pack.Pallet  
                            WHEN 0 THEN 0  
                            ELSE FLOOR(SUM(PickDetail.qty) / Pack.Pallet)  
                       END,  
          Cartons_cal = 0,  
          inner_cal   = 0,  
          Each_cal    = 0,  
          Total_cal   = SUM(pickdetail.qty),  
         -- ISNULL(ORDERS.DeliveryDate, '19000101') DeliveryDate,  
		  NULL AS DeliveryDate,
          ISNULL(Sku.RetailSku, '')         RetailSku,  
          ISNULL(ORDERS.BuyerPO, '')        BuyerPO,  
          ISNULL(ORDERS.InvoiceNo, '')      InvoiceNo,  
          NULL as OrderDate,--ISNULL(ORDERS.OrderDate, '19000101') OrderDate,  
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
          (SUM(ISNULL(lli.QtyOverAllocate,0)) * -1) AS QtyOverAllocate,  
          RTRIM(PACK.Packkey) + ' = ' + CONVERT(VARCHAR(10), PACK.CaseCnt ),  
          ISNULL(st.Susr3,''),
          ISNULL(st.Susr4,''),
          LEFT(ISNULL(st.Notes1,''),255),
          CASE WHEN ISNULL(st.Susr4,'') = 'SECURITY TAG' AND Sku.Price > 50 THEN 'YES' ELSE '' END ,
          sku.style,sku.MANUFACTURERSKU,ISNULL(RC.showskufield,0),sku.STDCUBE,sku.GrossWgt
          ,UPPER(orders.OrderGroup),wd.WaveKey,Loc.Pickzone AS Pzone,pickdetail.PickDetailKey
        ,ISNULL(SKU.ALTSKU,'') 
        ,ISNULL(C.SHORT,'N')
		,ISNULL(WV.Userdefine02,'') 
   FROM WAVEDETAIL      WD  WITH (NOLOCK) 
   JOIN WAVE  WV WITH (NOLOCK) ON WV.WaveKey=WD.WaveKey
   JOIN pickdetail WITH (NOLOCK)  ON pickdetail.OrderKey = WD.OrderKey --AND  pickdetail.WaveKey=wd.WaveKey
   LEFT JOIN Pickheader WITH (NOLOCK) ON PickHeader.ExternOrderkey = pickdetail.PickSlipNo
   JOIN orders WITH (NOLOCK)  
        ON  pickdetail.orderkey = orders.orderkey  
   JOIN lotattribute WITH (NOLOCK)  
        ON  pickdetail.lot = lotattribute.lot  
   JOIN loadplandetail WITH (NOLOCK)  
        ON  pickdetail.orderkey = loadplandetail.orderkey  
   JOIN orderdetail WITH (NOLOCK)  
        ON  pickdetail.orderkey = orderdetail.orderkey  
        AND pickdetail.orderlinenumber = orderdetail.orderlinenumber  
   JOIN storer WITH (NOLOCK)  
        ON  pickdetail.storerkey = storer.storerkey  
   JOIN sku(NOLOCK)  
        ON  pickdetail.sku = sku.sku  
        AND pickdetail.storerkey = sku.storerkey  
   JOIN pack WITH (NOLOCK)  
        ON  pickdetail.packkey = pack.packkey  
   JOIN loc WITH (NOLOCK)  
        ON  pickdetail.loc = loc.loc  
   LEFT JOIN routemaster WITH (NOLOCK)  
        ON  orders.route = routemaster.route  
   --LEFT JOIN areadetail WITH (NOLOCK)  
   --     ON  loc.putawayzone = areadetail.putawayzone  
   LEFT JOIN storer st WITH  (NOLOCK)  
        ON  orders.consigneekey = st.storerkey  
   LEFT JOIN (  
              SELECT O.Orderkey,  
                     MAX(SUBSTRING(LTRIM(ISNULL(CL.Description, '')), 6, 50)) AS   
                     BrandName,MAX(o.OrderGroup) AS OrdGroup  
              FROM   ORDERS O WITH (NOLOCK)  
                     JOIN ORDERDETAIL OD WITH (NOLOCK)  
                          ON  O.Orderkey = OD.Orderkey  
                     JOIN SKU(NOLOCK)  
                          ON  OD.Storerkey = SKU.Storerkey  
                          AND OD.Sku = SKU.Sku  
                     LEFT JOIN CODELKUP CL WITH (NOLOCK)  
                          ON  SKU.ItemClass = CL.Code  
                          AND CL.Listname = 'ITEMCLASS'  
                     LEFT JOIN  WAVEDETAIL  WD  WITH (NOLOCK)     
                     ON WD.OrderKey = O.Orderkey 
              WHERE  WD.wavekey = @c_Wavekey  
              GROUP BY  
                     O.Orderkey  
              HAVING COUNT(  
                         DISTINCT SUBSTRING(LTRIM(ISNULL(CL.Description, '')), 6, 50)  
                     ) = 1  
          ) BRAND  
               ON  ORDERS.Orderkey = BRAND.Orderkey  
          LEFT JOIN #TMP_OVERALLOCATE lli WITH (NOLOCK)  
               ON pickdetail.Lot = lli.Lot  
               AND pickdetail.Loc = lli.Loc  
               AND pickdetail.ID = lli.ID  
               AND pickdetail.Orderkey = lli.Orderkey 
          LEFT JOIN #TMP_RPTCFG RC ON (ORDERS.Storerkey = RC.Storerkey)        
          left outer join RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey) 
          LEFT JOIN CODELKUP C (NOLOCK) ON (C.Storerkey = Storer.Storerkey) AND C.Long = 'r_dw_print_wave_pickslip_17' 
                                 AND C.Listname = 'REPORTCFG' AND C.Code = 'SHOWUPC'
      WHERE  PickDetail.Status < '5'  
          AND WD.WaveKey = @c_waveKey  
   GROUP BY RefKeyLookup.PickSlipNo,orders.loadkey ,
          --PickDetail.OrderKey,  
          ISNULL(ORDERS.ConsigneeKey, ''),  
          ISNULL(ORDERS.c_Company, ''),  
          ISNULL(ORDERS.C_Address1, ''),  
          ISNULL(ORDERS.C_Address2, ''),  
          ISNULL(ORDERS.C_Address3, ''),  
          ISNULL(ORDERS.C_Zip, ''),  
          ISNULL(ORDERS.Route, ''),  
          ISNULL(RouteMaster.Descr, ''),  
          CONVERT(NVARCHAR(5), ORDERS.Door),  
         -- CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')),  
         -- CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')),  
          PickDetail.loc,  
          PickDetail.id,  
          PickDetail.sku,  
          ISNULL(Sku.Descr, ''),  
          loc.pickzone,
          LotAttribute.Lottable01 ,
          ISNULL(LotAttribute.Lottable04, '19000101'),  
          PACK.Pallet,  
          PACK.CaseCnt,  
          pack.innerpack,  
          PACK.Qty,  
         -- ORDERS.ExternOrderKey,  
          ISNULL(LOC.LogicalLocation, ''),  
          --ISNULL(AreaDetail.AreaKey, '00'),  
          ISNULL(OrderDetail.UOM, ''),  
          --ISNULL(ORDERS.DeliveryDate, '19000101'),  
          ISNULL(Sku.RetailSku, ''),  
          ISNULL(ORDERS.BuyerPO, ''),  
          ISNULL(ORDERS.InvoiceNo, ''),  
          --ISNULL(ORDERS.OrderDate, '19000101'),  
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
          RTRIM(PACK.Packkey) + ' = ' + CONVERT(VARCHAR(10), PACK.CaseCnt ),              
          ISNULL(st.Susr3,''),
          ISNULL(st.Susr4,''),
          LEFT(ISNULL(st.Notes1,''),255),
          CASE WHEN ISNULL(st.Susr4,'') = 'SECURITY TAG' AND Sku.Price > 50 THEN 'YES' ELSE '' END,
          sku.style,sku.MANUFACTURERSKU,ISNULL(RC.showskufield,0),sku.STDCUBE,sku.GrossWgt,BRAND.OrdGroup 
          ,wd.WaveKey,Loc.Pickzone ,pickdetail.PickDetailKey
        ,ISNULL(SKU.ALTSKU,'') 
        ,ISNULL(C.SHORT,'N') 
		,ISNULL(WV.Userdefine02,'') 
		,UPPER(orders.OrderGroup)
		ORDER BY RefKeyLookup.PickSlipNo,orders.loadkey ,
          PickDetail.sku
               
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END
     
      SET @c_OrderKey = ''  
      SET @c_Pickzone = ''
      SET @c_PrevPAzone = ''
      SET @c_PickDetailKey = ''  
      SET @n_continue = 1
    
   DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT loadkey  
         , orderkey 
         , PAZone
        --, MAX(RowNo) 
        ,PickDetailKey
   FROM #TMP_PICK  
   WHERE  ISNULL(PickSlipNo,'') = ''
   ORDER BY PAZone,PickDetailKey        
  
   OPEN CUR_LOAD  
     
   FETCH NEXT FROM CUR_LOAD INTO @c_loadkey,@c_orderkey   
                              ,  @c_PZone
                             -- ,  @n_MaxRow
                             ,@c_GetPickDetailKey
  
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN  
      
      
     IF ISNULL(@c_OrderKey, '0') = '0'  
            BREAK  
                  
     IF @c_PrevPAZone <> @c_PZone 
         
      BEGIN 
            
         SET @c_RPickSlipNo = ''
         
         EXECUTE nspg_GetKey       
                  'PICKSLIP'    
               ,  9    
               ,  @c_RPickSlipNo   OUTPUT    
               ,  @b_Success       OUTPUT    
               ,  @n_err           OUTPUT    
               ,  @c_errmsg        OUTPUT 
                        
         IF @b_success = 1   
         BEGIN                 
         SET @c_RPickSlipNo = 'P' + @c_RPickSlipNo          
                      
               INSERT INTO PICKHEADER      
                        (  PickHeaderKey    
                        ,  Wavekey    
                        ,  Orderkey    
                        ,  ExternOrderkey  
						,  Storerkey  
                        ,  Loadkey    
                        ,  PickType    
                        ,  Zone    
                        ,  consoorderkey
                        ,  TrafficCop    
                        )      
               VALUES      
                        (  @c_RPickSlipNo    
                        ,  @c_Wavekey    
                        ,  '' 
                        ,  @c_RPickSlipNo 
						,  @c_GetStorerkey  
                        ,  @c_Loadkey    
                        ,  '0'     
                        ,  'LP'  
                        ,  @c_PZone  
                        ,  ''    
                        )          
             
                     SET @n_err = @@ERROR      
                     IF @n_err <> 0      
                     BEGIN      
                        SET @n_continue = 3      
                        SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                        SET @n_err = 81008  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                        SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipWave17)'   
                                     + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
                        GOTO QUIT     
                     END  
               
          END
          ELSE   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @n_err = 63502
               SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PSNO Failed. (isp_GetPickSlipWave17)'  
               BREAK   
            END 
            
          END    
          
           IF @n_Continue = 1  
         BEGIN        
            SET @c_ExecStatement = N'DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                    'SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber ' +   
                                    'FROM   PickDetail WITH (NOLOCK) ' +
                                    'JOIN   OrderDetail WITH (NOLOCK) ' +                                       
                                    'ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND ' + 
                                    'PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber) ' +
                                    'JOIN   LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) ' +
                                    'WHERE  PickDetail.pickdetailkey = ''' + @c_GetPickDetailKey + '''' +
                                    ' AND    OrderDetail.LoadKey  = ''' + @c_LoadKey  + ''' ' +
                                    ' AND LOC.Pickzone = ''' + RTRIM(@c_Pzone) + ''' ' +  
                                    ' ORDER BY PickDetail.PickDetailKey '  
   
            EXEC(@c_ExecStatement)
            OPEN C_PickDetailKey  
     
            FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrdLineNo   
     
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)   
               BEGIN   
                  INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)  
                  VALUES (@c_PickDetailKey, @c_RPickSlipNo, @c_OrderKey, @c_OrdLineNo, @c_Loadkey)

                  SELECT @n_err = @@ERROR  
                  IF @n_err <> 0   
                  BEGIN  
                     SELECT @n_continue = 3
                     SELECT @n_err = 63503
                      SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookup Failed. (isp_GetPickSlipWave17)'    
                     GOTO QUIT
                  END                          
               END   
     
               FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrdLineNo   
            END   
            CLOSE C_PickDetailKey   
            DEALLOCATE C_PickDetailKey        
         END   
                
         UPDATE #TMP_PICK  
            SET PickSlipNo = @c_RPickSlipNo  
         WHERE OrderKey = @c_OrderKey  
         AND   PAzone = @c_Pzone
         AND   ISNULL(PickSlipNo,'') = '' 
         AND Pickdetailkey = @c_GetPickDetailKey

         SELECT @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @n_err = 63504
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #TMP_PICK Failed. (isp_GetPickSlipWave17)'    
            GOTO QUIT
         END

                  UPDATE PICKDETAIL WITH (ROWLOCK)      
                   SET  PickSlipNo = @c_RPickSlipNo     
                   ,EditWho = SUSER_NAME()    
                   ,EditDate= GETDATE()     
                   ,TrafficCop = NULL     
               FROM ORDERS     OH WITH (NOLOCK)    
               JOIN PICKDETAIL PD ON (OH.Orderkey = PD.Orderkey) 
               JOIN LOC L ON L.LOC = PD.Loc   
                --WHERE PD.OrderKey = @c_OrderKey  
                WHERE  L.Pickzone = @c_PZone
                AND   ISNULL(PickSlipNo,'') = ''  
                AND Pickdetailkey = @c_GetPickDetailKey

  
               SET @n_err = @@ERROR      
               IF @n_err <> 0      
               BEGIN      
                  SET @n_continue = 3      
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 81009 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (isp_GetPickSlipWave17)'   
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
                  GOTO QUIT     
               END  
         
               WHILE @@TRANCOUNT > 0  
               BEGIN  
                  COMMIT TRAN  
               END  
  
         
         WHILE @@TRANCOUNT > 0  
         BEGIN  
            COMMIT TRAN  
         END            
		   
         SET @c_PrevPAzone = @c_Pzone                 
             
      FETCH NEXT FROM CUR_LOAD INTO @c_loadkey,@c_Orderkey  
                                 ,  @c_PZone
                               --  ,  @n_MaxRow
                                 , @c_GetPickDetailKey
   END  
   CLOSE CUR_LOAD  
   DEALLOCATE CUR_LOAD  
   
   DECLARE CUR_WaveOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
     SELECT DISTINCT   
          WD.Wavekey  
         ,LPD.LoadKey  
         ,PDET.OrderKey
         ,WD.Orderkey
      FROM WAVEDETAIL      WD  WITH (NOLOCK)  
      JOIN LOADPLANDETAIL  LPD WITH (NOLOCK) ON (WD.Orderkey = LPD.Orderkey)  
      JOIN PICKDETAIL AS PDET ON PDET.OrderKey = WD.OrderKey
      JOIN LOC L WITH (NOLOCK) ON L.LOC = PDET.Loc
      LEFT JOIN PICKHEADER PH  WITH (NOLOCK) ON (WD.WaveKey = PH.Wavekey)  
                                          AND(LPD.Loadkey = PH.ExternOrderkey)    
                                          AND(LPD.Loadkey = PH.Loadkey)                                         
                                          AND(PH.Zone = 'LP')  
     WHERE WD.WaveKey = @c_Wavekey                                        
                                          
      OPEN CUR_WaveOrder 
      
      FETCH NEXT FROM CUR_WaveOrder INTO @c_GetWavekey,@c_GetLoadkey,@c_GetPHOrdKey,@c_GetWDOrdKey
      
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN    
         
         IF RTRIM(@c_GetPHOrdKey) = '' OR @c_GetPHOrdKey IS NULL  
         BEGIN  
         BEGIN TRAN
         EXECUTE nspg_GetKey       
                  'PICKSLIP'    
               ,  9    
               ,  @c_Pickslipno OUTPUT    
               ,  @b_Success    OUTPUT    
               ,  @n_err        OUTPUT    
               ,  @c_errmsg     OUTPUT          
                          
         SET @c_Pickslipno = 'P' + @c_Pickslipno    
         
         
         IF NOT EXISTS (SELECT 1 FROM PICKHEADER (NOLOCK) 
                        WHERE wavekey      = @c_Wavekey 
                        AND loadkey        = @c_GetLoadkey
                        AND Orderkey       = @c_GetPHOrdKey)
         BEGIN
         INSERT INTO PICKHEADER      
                  (  PickHeaderKey    
                  ,  Wavekey    
                  ,  Orderkey    
                  ,  ExternOrderkey    
                  ,  Loadkey    
                  ,  PickType    
                  ,  Zone    
                  ,  consoorderkey
                  ,  TrafficCop    
                  )      
         VALUES      
                  (  @c_Pickslipno    
                  ,  @c_Wavekey    
                  ,  @c_GetWDOrdKey   
                  ,  @c_Pickslipno   
                  ,  @c_Loadkey    
                  ,  '0'     
                  ,  '3'  
                  ,  ''  
                  ,  ''    
                  )          
             
               SET @n_err = @@ERROR      
               IF @n_err <> 0      
               BEGIN      
                  SET @n_continue = 3      
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 81008  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipWave17)'   
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
                  GOTO QUIT     
               END      

        END   
        
        
         WHILE @@TRANCOUNT > 0  
         BEGIN  
            COMMIT TRAN  
         END   
      END  

      
      FETCH NEXT FROM  CUR_WaveOrder INTO @c_GetWavekey,@c_GetLoadkey,@c_GetPHOrdKey,@c_GetWDOrdKey
      END  
      
      CLOSE CUR_WaveOrder  
      DEALLOCATE CUR_WaveOrder    

	  
	  UPDATE PICKDETAIL WITH (ROWLOCK)      
       SET  PickSlipNo = TP.Pickslipno     
          ,EditWho = SUSER_NAME()    
          ,EditDate= GETDATE()     
         ,TrafficCop = NULL     
		FROM #TMP_PICK     TP WITH (NOLOCK)    
		JOIN PICKDETAIL PD ON (TP.Pickdetailkey = PD.Pickdetailkey) 
		--JOIN LOC L ON L.LOC = PD.Loc   
		--WHERE PD.OrderKey = @c_OrderKey  
		--WHERE  L.Pickzone = @c_PZone
		WHERE ISNULL(PD.PickSlipNo,'') = ''  
		--AND Pickdetailkey = @c_GetPickDetailKey                                                 
   
    GOTO QUIT    
     
QUIT:  
  
   IF CURSOR_STATUS('LOCAL' , 'CUR_LOAD') in (0 , 1)  
   BEGIN  
      CLOSE CUR_LOAD  
      DEALLOCATE CUR_LOAD  
   END  
  
   IF CURSOR_STATUS('LOCAL' , 'CUR_PICK') in (0 , 1)  
   BEGIN  
      CLOSE CUR_PICK  
      DEALLOCATE CUR_PICK  
   END  
  
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN   
      IF @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END   
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipWave17'    
   END  
    
   SELECT tp.Orderkey,   
          SUM(tp.QtyOverAllocate) AS TotalQtyOverAllocate   
       ,  ISNULL(RTRIM(CL.Description),'') AS PriceTag  
   INTO #tmp_ordsum  
   FROM #TMP_PICK tp    
   LEFT JOIN STORER   CS WITH (NOLOCK) ON (tp.consigneekey = CS.Storerkey)  
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.Listname = 'TitleRem' AND CS.Fax2 = CL.Code AND CL.Storerkey = @c_GetStorerkey)  
   GROUP BY tp.Orderkey  
         ,  ISNULL(RTRIM(CL.Description),'')   
 

     
   SELECT DISTINCT #tmp_pick.Loc  
   INTO #tmp_highbayloc  
   FROM #TMP_PICK  
   JOIN LOC (NOLOCK) ON #tmp_pick.Loc = LOC.Loc  
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'HighLight' AND LOC.PickZone = CL.Code AND CL.Storerkey = @c_GetStorerkey)  
   WHERE CL.Short = 'Y'  
  
   SELECT              
         #TMP_PICK.PickSlipNo     
      ,  #TMP_PICK.LoadKey            
      ,  #TMP_PICK.OrderKey           
      ,  #TMP_PICK.ConsigneeKey       
      ,  #TMP_PICK.Company            
      ,  #TMP_PICK.Addr1              
      ,  #TMP_PICK.Addr2              
      ,  #TMP_PICK.Addr3              
      ,  #TMP_PICK.PostCode           
      ,  #TMP_PICK.ROUTE              
      ,  #TMP_PICK.Route_Desc         
      ,  #TMP_PICK.TrfRoom            
      ,  #TMP_PICK.Notes1             
      ,  #TMP_PICK.Notes2             
      ,  UPPER(#TMP_PICK.LOC) AS LOC    
      ,  #TMP_PICK.ID                 
      ,  #TMP_PICK.SKU                
      ,  #TMP_PICK.SkuDesc            
      ,  SUM(#TMP_PICK.Qty) As Qty                
      ,  #TMP_PICK.TempQty1           
      ,  #TMP_PICK.TempQty2           
      ,  #TMP_PICK.PrintedFlag        
      ,  #TMP_PICK.Zone               
      ,  #TMP_PICK.PgGroup            
      ,  #TMP_PICK.RowNum             
      ,  #TMP_PICK.Lot                
      ,  #TMP_PICK.Carrierkey         
      ,  #TMP_PICK.VehicleNo          
      ,  #TMP_PICK.Lottable02         
      ,  #TMP_PICK.Lottable04         
      ,  #TMP_PICK.packpallet         
      ,  #TMP_PICK.packcasecnt        
      ,  #TMP_PICK.packinner          
      ,  #TMP_PICK.packeaches         
      ,  #TMP_PICK.externorderkey     
      ,  #TMP_PICK.LogicalLoc         
      ,  #TMP_PICK.Areakey   
      ,  #TMP_PICK.UOM                
      ,  #TMP_PICK.Pallet_cal         
      ,  #TMP_PICK.Cartons_cal        
      ,  #TMP_PICK.inner_cal          
      ,  #TMP_PICK.Each_cal           
      ,  #TMP_PICK.Total_cal          
      ,  #TMP_PICK.DeliveryDate       
      ,  #TMP_PICK.RetailSku          
      ,  #TMP_PICK.BuyerPO            
      ,  #TMP_PICK.InvoiceNo          
      ,  #TMP_PICK.OrderDate          
      ,  #TMP_PICK.Susr4              
      ,  #TMP_PICK.vat                
      ,  #TMP_PICK.OVAS               
      ,  #TMP_PICK.SKUGROUP           
      ,  #TMP_PICK.Storerkey          
      ,  #TMP_PICK.Country            
      ,  #TMP_PICK.Brand              
      ,  #TMP_PICK.QtyOverAllocate       
      ,  #TMP_ORDSUM.totalqtyoverallocate,  
         CASE WHEN ISNULL(#TMP_HIGHBAYLOC.Loc,'') <> '' THEN  
               'Y'  
          ELSE 'N' END AS Highbayloc,  
          #TMP_ORDSUM.PriceTag,  
          #TMP_PICK.QtyPerCarton,         
          #TMP_PICK.ConsSUSR3,
          #TMP_PICK.ConsSUSR4,
          #TMP_PICK.ConsNotes1,
          #TMP_PICK.SensorTag,
          #TMP_PICK.Style,                    
          #TMP_PICK.MANUFACTURERSKU,          
          #TMP_PICK.ShowSkufield,              
          (#TMP_PICK.Stdcude*#TMP_PICK.Qty) /1000000 As [VolV3] ,   
          (#TMP_PICK.grosswgt*#TMP_PICK.Qty) /1000 As [Wgt],
         #TMP_PICK.OrderGrp, 
		 #TMP_PICK.Wavekey,#TMP_Pick.PAZone,
         #TMP_PICK.ALTSKU,
         #TMP_PICK.CLKUPSHORT, 
		 #TMP_PICK.WVUDF02             
   FROM   #TMP_PICK  
   JOIN   #TMP_ORDSUM ON #TMP_PICK.Orderkey = #TMP_ORDSUM.Orderkey   
   LEFT JOIN #TMP_HIGHBAYLOC ON #TMP_PICK.Loc = #TMP_HIGHBAYLOC.Loc 
   --ORDER BY  #TMP_PICK.PickSlipNo,#TMP_Pick.PAZone,UPPER(#TMP_PICK.LOC),  #TMP_PICK.SKU
   Group BY #TMP_PICK.PickSlipNo     
      ,  #TMP_PICK.LoadKey            
      ,  #TMP_PICK.OrderKey           
      ,  #TMP_PICK.ConsigneeKey       
      ,  #TMP_PICK.Company            
      ,  #TMP_PICK.Addr1              
      ,  #TMP_PICK.Addr2              
      ,  #TMP_PICK.Addr3              
      ,  #TMP_PICK.PostCode           
      ,  #TMP_PICK.ROUTE              
      ,  #TMP_PICK.Route_Desc         
      ,  #TMP_PICK.TrfRoom            
      ,  #TMP_PICK.Notes1             
      ,  #TMP_PICK.Notes2             
      ,  UPPER(#TMP_PICK.LOC)    
      ,  #TMP_PICK.ID                 
      ,  #TMP_PICK.SKU                
      ,  #TMP_PICK.SkuDesc            
    --  ,  #TMP_PICK.Qty                
      ,  #TMP_PICK.TempQty1           
      ,  #TMP_PICK.TempQty2           
      ,  #TMP_PICK.PrintedFlag        
      ,  #TMP_PICK.Zone               
      ,  #TMP_PICK.PgGroup            
      ,  #TMP_PICK.RowNum             
      ,  #TMP_PICK.Lot                
      ,  #TMP_PICK.Carrierkey         
      ,  #TMP_PICK.VehicleNo          
      ,  #TMP_PICK.Lottable02         
      ,  #TMP_PICK.Lottable04         
      ,  #TMP_PICK.packpallet         
      ,  #TMP_PICK.packcasecnt        
      ,  #TMP_PICK.packinner          
      ,  #TMP_PICK.packeaches         
      ,  #TMP_PICK.externorderkey     
      ,  #TMP_PICK.LogicalLoc         
      ,  #TMP_PICK.Areakey   
      ,  #TMP_PICK.UOM                
      ,  #TMP_PICK.Pallet_cal         
      ,  #TMP_PICK.Cartons_cal        
      ,  #TMP_PICK.inner_cal          
      ,  #TMP_PICK.Each_cal           
      ,  #TMP_PICK.Total_cal          
      ,  #TMP_PICK.DeliveryDate       
      ,  #TMP_PICK.RetailSku          
      ,  #TMP_PICK.BuyerPO            
      ,  #TMP_PICK.InvoiceNo          
      ,  #TMP_PICK.OrderDate          
      ,  #TMP_PICK.Susr4              
      ,  #TMP_PICK.vat                
      ,  #TMP_PICK.OVAS               
      ,  #TMP_PICK.SKUGROUP           
      ,  #TMP_PICK.Storerkey          
      ,  #TMP_PICK.Country            
      ,  #TMP_PICK.Brand              
      ,  #TMP_PICK.QtyOverAllocate       
      ,  #TMP_ORDSUM.totalqtyoverallocate,  
         CASE WHEN ISNULL(#TMP_HIGHBAYLOC.Loc,'') <> '' THEN  
               'Y'  
          ELSE 'N' END ,  
          #TMP_ORDSUM.PriceTag,  
          #TMP_PICK.QtyPerCarton,         
          #TMP_PICK.ConsSUSR3,
          #TMP_PICK.ConsSUSR4,
          #TMP_PICK.ConsNotes1,
          #TMP_PICK.SensorTag,
          #TMP_PICK.Style,                    
          #TMP_PICK.MANUFACTURERSKU,          
          #TMP_PICK.ShowSkufield,              
          (#TMP_PICK.Stdcude*#TMP_PICK.Qty) /1000000  ,   
          (#TMP_PICK.grosswgt*#TMP_PICK.Qty) /1000 ,
         #TMP_PICK.OrderGrp, 
		 #TMP_PICK.Wavekey,#TMP_Pick.PAZone,
         #TMP_PICK.ALTSKU,
         #TMP_PICK.CLKUPSHORT, 
		 #TMP_PICK.WVUDF02 
   ORDER BY #TMP_PICK.PickSlipNo,#TMP_PICK.LogicalLoc,UPPER(#TMP_PICK.LOC),  #TMP_PICK.SKU
     
  --SELECT '1' AS PickSlipNo
  
  DROP TABLE #TMP_PICK  
  
  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN   
   END  
     
   RETURN  
END  

GO