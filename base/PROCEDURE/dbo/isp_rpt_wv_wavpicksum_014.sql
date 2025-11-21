SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/***************************************************************************/        
/* Stored Procedure: isp_RPT_WV_WAVPICKSUM_014                             */        
/* Creation Date: 19-SEP-2023                                              */        
/* Copyright: Maersk                                                       */        
/* Written by: CSCHONG                                                     */        
/*                                                                         */        
/* Purpose: WMS-23714                                                      */        
/*                                                                         */        
/* Called By: RPT_WV_WAVPICKSUM_014                                        */        
/*                                                                         */        
/* GitLab Version: 1.0                                                     */        
/*                                                                         */        
/* Version: 1.0                                                            */        
/*                                                                         */        
/* Data Modifications:                                                     */        
/*                                                                         */        
/* Updates:                                                                */        
/* Date            Author   Ver  Purposes                                  */    
/* 19-SEP-2023     CSCHONG  1.0  DevOps Combine Script                     */       
/***************************************************************************/                  
                  
CREATE    PROC [dbo].[isp_RPT_WV_WAVPICKSUM_014]                             
      @c_Wavekey        NVARCHAR(10)           
                                     
AS                              
BEGIN                              
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF                      
                       
      
DECLARE @c_pickheaderkey       NVARCHAR(10),    
         @n_continue           INT,    
         @c_errmsg             NVARCHAR(255),    
         @b_success            INT,    
         @n_err                INT,    
         @c_sku                NVARCHAR(20),    
         @n_qty                INT,    
         @c_loc                NVARCHAR(10),    
         @n_cases              INT,    
         @n_perpallet          INT,    
         @c_storer             NVARCHAR(15),    
         @c_orderkey           NVARCHAR(10),    
         @c_ConsigneeKey       NVARCHAR(15),    
         @c_Company            NVARCHAR(45),    
         @c_Addr1              NVARCHAR(45),    
         @c_Addr2              NVARCHAR(45),    
         @c_Addr3              NVARCHAR(45),    
         @c_PostCode           NVARCHAR(15),    
         @c_Route              NVARCHAR(10),    
         @c_Route_Desc         NVARCHAR(60), -- RouteMaster.Desc    
         @c_TrfRoom            NVARCHAR(5),  -- LoadPlan.TrfRoom    
         @c_Notes1             NVARCHAR(200),    
         @c_Notes2             NVARCHAR(200),    
         @c_SkuDesc            NVARCHAR(60),    
         @n_CaseCnt            INT,    
         @n_PalletCnt          INT,    
         @c_ReceiptTm          NVARCHAR(20),    
         @c_PrintedFlag        NVARCHAR(1),    
         @c_UOM                NVARCHAR(10),    
         @n_UOM3               INT,    
         @c_Lot                NVARCHAR(10),    
         @c_StorerKey          NVARCHAR(15),    
         @c_Zone               NVARCHAR(1),    
         @n_PgGroup            INT,    
         @n_TotCases           INT,    
         @n_RowNo              INT,    
         @c_PrevSKU            NVARCHAR(20),    
         @n_SKUCount           INT,    
         @c_Carrierkey         NVARCHAR(60),    
         @c_VehicleNo          NVARCHAR(10),    
         @c_firstorderkey      NVARCHAR(10),    
         @c_superorderflag     NVARCHAR(1),    
         @c_firsttime          NVARCHAR(1),    
         @c_logicalloc         NVARCHAR(18),    
         @c_Lottable01         NVARCHAR(18),    
         @c_Lottable02         NVARCHAR(18),    
         @c_Lottable03         NVARCHAR(18),    
         @d_Lottable04         DATETIME,    
         @d_Lottable05         DATETIME,    
         @n_packpallet         INT,    
         @n_packcasecnt        INT,    
         @c_externorderkey     NVARCHAR(30),    
         @n_pickslips_required INT,    
         @dt_deliverydate      DATETIME,    
         @c_buyerpo            NVARCHAR(20),        
         @c_SHOWBUYERPO        NVARCHAR(5) ,    
         @c_PickSlipNo         NVARCHAR(10),    
         @c_PreGenRptData  NVARCHAR(10) = ''        
    
DECLARE @c_PrevOrderKey NVARCHAR(10),    
         @n_Pallets     INT,    
         @n_Cartons     INT,    
         @n_Eaches      INT,    
         @n_UOMQty      INT,    
         @c_InvoiceNo   NVARCHAR(10) ,
         @c_PgGroup     INT,    
         @n_TTLPage     INT = 1  
         , @n_NoOfLine               INT              
         , @n_RowNum                 INT             
         , @n_initialflag            INT = 1      
         , @n_ctnord                 INT = 1      
         , @c_ChgGrp                 NVARCHAR(1) = 'N'    
         , @n_maxRec                 INT                 


   IF @c_PreGenRptData = '0' SET @c_PreGenRptData = ''    
    
 DECLARE   @c_DataWindow    NVARCHAR(60) = 'RPT_LP_PLISTN_041'        
         , @c_RetVal        NVARCHAR(255)      
         , @c_GeStorerkey   NVARCHAR(15) = ''    
         , @c_Type          NVARCHAR(1) = '1'      
    

SET @n_NoOfLine = 4 
   
   SELECT TOP 1 @c_GeStorerkey = Storerkey    
   FROM ORDERS (NOLOCK)       
   WHERE Userdefine09 = @c_Wavekey    
    
    
 IF ISNULL(@c_GeStorerkey,'') <> ''        
   BEGIN        
        
         EXEC [dbo].[isp_GetCompanyInfo]        
                  @c_Storerkey  = @c_storerkey        
               ,  @c_Type       = @c_Type        
               ,  @c_DataWindow = @c_DataWindow        
               ,  @c_RetVal     = @c_RetVal           OUTPUT        
         
   END        
    
    
    
DECLARE @n_starttcnt INT    
    
SELECT @n_starttcnt = @@TRANCOUNT    
SELECT @n_pickslips_required = 0 
    
WHILE @@TRANCOUNT > 0    
BEGIN    
   COMMIT TRAN    
END    
    
--BEGIN TRAN    
   CREATE TABLE #temp_pick    
      (     PickSlipNo     NVARCHAR(10)   NULL                               
         ,  LoadKey        NVARCHAR(10)                                    
         ,  OrderKey       NVARCHAR(10)                                    
         ,  ConsigneeKey   NVARCHAR(15)                                    
         ,  Company        NVARCHAR(45)                                    
         ,  Addr1          NVARCHAR(45)   NULL                               
         ,  Addr2          NVARCHAR(45)   NULL                               
         ,  Addr3          NVARCHAR(45)   NULL                               
         ,  PostCode       NVARCHAR(15)   NULL                               
         ,  Route          NVARCHAR(10)   NULL                               
         ,  Route_Desc     NVARCHAR(60)   NULL  -- RouteMaster.Desc          
         ,  TrfRoom        NVARCHAR(5)    NULL  -- LoadPlan.TrfRoom          
         ,  Notes1         NVARCHAR(200)  NULL                               
         ,  Notes2         NVARCHAR(200)  NULL                               
         ,  LOC            NVARCHAR(10)   NULL                               
         ,  SKU            NVARCHAR(20)                                    
         ,  SkuDesc        NVARCHAR(60)                                    
         ,  Qty            INT                                             
         ,  TempQty1       INT                                             
         ,  TempQty2       INT                                             
         ,  PrintedFlag    NVARCHAR(1)    NULL                               
         ,  Zone           NVARCHAR(1)                                     
         ,  PgGroup        INT                                             
         ,  RowNum         INT                                             
         ,  Lot            NVARCHAR(10)                                    
         ,  Carrierkey     NVARCHAR(60)   NULL                               
         ,  VehicleNo      NVARCHAR(10)   NULL                               
         ,  Lottable01     NVARCHAR(18)   NULL                               
         ,  Lottable02     NVARCHAR(18)   NULL                 
         ,  Lottable03     NVARCHAR(18)   NULL                               
         ,  Lottable04     DATETIME       NULL                               
         ,  Lottable05     DATETIME       NULL                               
         ,  packpallet     INT                                             
         ,  packcasecnt    INT                                             
         ,  externorderkey NVARCHAR(50)   NULL                               
         ,  LogicalLoc     NVARCHAR(18)   NULL                               
         ,  DeliveryDate   DATETIME       NULL                               
         ,  Uom            NVARCHAR(10)                                    
         ,  InvoiceNo      NVARCHAR(10)   NULL                               
         ,  Ovas           CHAR(30)       NULL                               
         ,  Putawayzone    NVARCHAR(10)   NULL       
         ,  Storerkey      NVARCHAR(15)   NULL                               
         ,  PickByCase     INT            NULL             
         ,  SysQty         INT         
         ,  ORDGRP         NVARCHAR(20)   NULL    
         ,  LOTT12         NVARCHAR(30)   NULL    
         ,  LOTLot12       NVARCHAR(30)   NULL    
         ,  BatchNo        NVARCHAR(60)   NULL    
         ,  BatchNo2       NVARCHAR(60)   NULL    
         ,  SerialNo       NVARCHAR(60)   NULL     
         ,  SerialNo2      NVARCHAR(60)   NULL    
         ,  PackUOM1       NVARCHAR(20)   NULL    
         ,  PackUOM2       NVARCHAR(20)   NULL    
         ,  PackUOM3       NVARCHAR(20)   NULL     
         ,  PInnerPack     FLOAT       
         ,  PUOM3Qty       INT    
         ,  buyerpo        NVARCHAR(20)   NULL        
         ,  SHOWBUYERPO    NVARCHAR(5)    NULL       
         ,  SHOWFIELD      NVARCHAR(5)    NULL         
         ,  wavekey        NVARCHAR(20)   NULL
         ,  TTLPAGE        INT       
         )    
    
  
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order    
   IF EXISTS ( SELECT 1    
               FROM PickHeader (NOLOCK)    
               JOIN Orders (NOLOCK) ON PickHeader.ExternOrderKey = Orders.Loadkey AND PickHeader.Orderkey = Orders.Orderkey  
               WHERE Orders.UserDefine09 = @c_Wavekey    
               AND Zone = '3' )    
   BEGIN    
      SELECT @c_firsttime = 'N'    
      SELECT @c_PrintedFlag = 'Y'    
   END    
   ELSE    
   BEGIN    
      SELECT @c_firsttime = 'Y'    
      SELECT @c_PrintedFlag = 'N'    
    
      IF @c_PreGenRptData=''    
      BEGIN    
          SET @c_PreGenRptData='Y'    
      END    
    
   END -- Record Not Exists    
    
   INSERT INTO #Temp_Pick    
         (  PickSlipNo    
         ,  LoadKey    
         ,  OrderKey    
         ,  Storerkey    
         ,  ConsigneeKey    
         ,  Company    
         ,  Addr1    
         ,  Addr2    
         ,  PgGroup    
         ,  Addr3    
         ,  PostCode    
         ,  Route    
         ,  Route_Desc    
         ,  TrfRoom    
         ,  Notes1    
         ,  RowNum    
         ,  Notes2    
         ,  LOC    
         ,  SKU    
         ,  SkuDesc    
         ,  Qty    
         ,  TempQty1    
         ,  TempQty2    
         ,  PrintedFlag    
         ,  Zone    
         ,  Lot    
         ,  CarrierKey    
         ,  VehicleNo    
         ,  Lottable01    
         ,  Lottable02    
         ,  Lottable03    
         ,  Lottable04    
         ,  Lottable05    
         ,  packpallet    
         ,  packcasecnt    
         ,  externorderkey             
         ,  LogicalLoc    
         ,  DeliveryDate    
         ,  UOM    
         ,  InvoiceNo    
         ,  Ovas    
         ,  Putawayzone    
         ,  SysQty    
         ,  ORDGRP,LOTT12,LOTLot12,BatchNo,BatchNo2,SerialNo,SerialNo2    
         ,  PackUOM1,PackUOM2,PackUOM3,PInnerPack,PUOM3Qty    
         ,  buyerpo         
         ,  SHOWBUYERPO    
         ,  SHOWFIELD  
         ,  wavekey , TTLPAGE                --CS01    
         )    
   SELECT ( SELECT PickHeaderkey    
            FROM PICKHEADER (NOLOCK)    
            JOIN Orders (NOLOCK) ON PickHeader.ExternOrderKey = Orders.Loadkey AND PICKHEADER.OrderKey = Orders.Orderkey  
            WHERE Orders.UserDefine09 = @c_Wavekey    
            AND PICKHEADER.OrderKey = PickDetail.OrderKey    
            AND PICKHEADER.Zone = '3'        
          )    
         ,ORDERS.Loadkey                              AS LoadKey     
         ,PICKDETAIL.OrderKey    
         ,ORDERS.Storerkey                            AS Storerkey    
         ,ISNULL(RTRIM(ORDERS.BillToKey), '')         AS ConsigneeKey    
         ,ISNULL(RTRIM(ORDERS.c_Company), '')         AS Company    
         ,ISNULL(RTRIM(ORDERS.C_Address1), '')        AS Addr1    
         ,ISNULL(RTRIM(ORDERS.C_Address2), '')        AS Addr2    
         ,0                                           AS PgGroup    
         ,ISNULL(RTRIM(ORDERS.C_Address3), '')        AS Addr3    
         ,ISNULL(RTRIM(ORDERS.C_Zip), '')             AS PostCode    
         ,ISNULL(RTRIM(ORDERS.Route), '')             AS Route    
         ,ISNULL(RTRIM(ROUTEMASTER.Descr), '')        AS  Route_Desc    
         ,ISNULL(RTRIM(ORDERS.Door), '')              AS TrfRoom    
         ,CONVERT(NVARCHAR(200), ISNULL(RTRIM(ORDERS.Notes), ''))    AS Notes1    
         , (ROW_NUMBER() OVER (PARTITION BY Orders.UserDefine09,ORDERS.Loadkey,PICKDETAIL.OrderKey   ORDER BY 
                      Orders.UserDefine09,ORDERS.Loadkey,PICKDETAIL.OrderKey ))      AS RowNo    
         ,CONVERT(NVARCHAR(200), ISNULL(RTRIM(ORDERS.Notes2), ''))   AS Notes2    
         ,ISNULL(RTRIM(PICKDETAIL.loc), '')           AS loc    
         ,ISNULL(RTRIM(PICKDETAIL.sku), '')           AS Sku    
         ,ISNULL(RTRIM(SKU.Descr), '')                AS SkuDesc    
         ,ISNULL(SUM(PICKDETAIL.qty),0)               AS Qty    
         ,CASE PICKDETAIL.UOM    
            WHEN '1' THEN PACK.Pallet    
            WHEN '2' THEN PACK.CaseCnt    
            WHEN '3' THEN PACK.InnerPack    
            ELSE 1    
          END                                         AS UOMQty    
         ,0                                           AS TempQty2    
   
         ,ISNULL(( SELECT DISTINCT    
                   'Y'    
                   FROM PickHeader (NOLOCK)    
                   WHERE ExternOrderKey = ORDERS.Loadkey AND Orderkey = ORDERS.Orderkey  
                   AND Zone = '3'    
                 ), 'N')                              AS PrintedFlag    
         ,'3'                                         AS Zone    
         ,ISNULL(RTRIM(PICKDETAIL.Lot),'')            AS Lot    
         ,''                                          AS CarrierKey    
         ,''                                          AS VehicleNo    
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable01),'')   AS Lottable01    
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')   AS Lottable02    
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable03),'')   AS Lottable03    
         ,ISNULL(LOTATTRIBUTE.Lottable04, '19000101') AS Lottable04    
         ,ISNULL(LOTATTRIBUTE.Lottable05, '19000101') AS Lottable05    
         ,ISNULL(PACK.Pallet,0)                    AS Pallet    
         ,ISNULL(PACK.CaseCnt,0)                   AS CaseCnt    
         ,ISNULL(RTRIM(ORDERS.ExternOrderKey),'')  AS ExternOrderKey    
         ,ISNULL(RTRIM(LOC.LogicalLocation), '')   AS LogicalLocation    
         ,ISNULL(ORDERS.DeliveryDate, '19000101')  AS DeliveryDate    
         ,ISNULL(RTRIM(PACK.PackUOM3),'')          AS PackUOM3    
         ,ISNULL(RTRIM(ORDERS.InvoiceNo),'')       AS InvoiceNo    
         ,ISNULL(RTRIM(SKU.Ovas),'')               AS Ovas    
         ,ISNULL(RTRIM(LOC.Putawayzone),'')        AS Putawayzone    
         ,ISNULL(LOTxLOCxID.Qty,0)                 AS SysQty    
         ,ISNULL(ORDERS.Ordergroup,'')             AS ORDGRP    
         ,ISNULL(RTRIM(OD.Lottable12),'')   AS Lottable12    
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable12),'')   AS LOTLot12       
         ,(ISNULL(RTRIM(OD.Lottable08),'') +ISNULL(RTRIM(OD.Lottable09),'') ) AS BatchNo     
         ,(ISNULL(RTRIM(LOTATTRIBUTE.Lottable08),'') +ISNULL(RTRIM(LOTATTRIBUTE.Lottable09),'') ) AS BatchNo2       
         ,(ISNULL(RTRIM(OD.Lottable10),'') +ISNULL(RTRIM(OD.Lottable11),'') ) AS SerialNo    
         ,(ISNULL(RTRIM(LOTATTRIBUTE.Lottable10),'') +ISNULL(RTRIM(LOTATTRIBUTE.Lottable11),'') ) AS SerialNo2       
         ,PACK.PackUOM1 ,PACK.PackUOM2,PACK.PackUOM3,ISNULL(Pack.InnerPack,0),ISNULL(Pack.Qty,0)    
         ,ISNULL(ORDERS.buyerpo,'') AS buyerpo         
         ,ISNULL(CL.SHORT,'') AS SHOWBUYERPO    
         ,ISNULL(CL1.SHORT,'') AS SHOWFIELD    
         , Orders.UserDefine09 AS Wavekey
         , 0
         FROM LOADPLANDETAIL WITH (NOLOCK)    
         JOIN ORDERS        WITH (NOLOCK) ON ( ORDERS.Orderkey = LoadPlanDetail.Orderkey )    
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = ORDERS.orderkey    
         JOIN STORER        WITH (NOLOCK) ON ( ORDERS.StorerKey = Storer.StorerKey )    
         LEFT OUTER JOIN ROUTEMASTER WITH (NOLOCK) ON ( ROUTEMASTER.Route = ORDERS.Route )    
         JOIN PICKDETAIL    WITH (NOLOCK) ON ( PICKDETAIL.OrderKey = ORDERS.Orderkey AND PICKDETAIL.OrderLineNumber = OD.OrderLineNumber)    
         JOIN LOTATTRIBUTE  WITH (NOLOCK) ON ( PICKDETAIL.Lot = LOTATTRIBUTE.Lot )    
         JOIN SKU           WITH (NOLOCK) ON ( Sku.StorerKey = PICKDETAIL.StorerKey )    
                                          AND( Sku.Sku = PICKDETAIL.Sku )    
         JOIN PACK          WITH (NOLOCK) ON ( SKU.Packkey = PACK.Packkey )    
         JOIN LOC           WITH (NOLOCK) ON ( PICKDETAIL.LOC = LOC.LOC )    
         JOIN LOTxLOCxID    WITH (NOLOCK) ON ( PICKDETAIL.LOC = LOTxLOCxID.LOC AND PICKDETAIL.LOT = LOTxLOCxID.LOT AND PICKDETAIL.ID = LOTxLOCxID.ID )    
         LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'SHOWBUYERPO'       
                                             AND CL.LONG = 'RPT_WV_WAVPICKSUM_014' AND CL.STORERKEY = ORDERS.STORERKEY )    
         LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.LISTNAME = 'REPORTCFG' AND CL1.CODE = 'SHOWFIELD'       
                                              AND CL1.LONG = 'RPT_WV_WAVPICKSUM_014' AND CL1.STORERKEY = ORDERS.STORERKEY )    
         WHERE PICKDETAIL.Status >= '0'      
         AND Orders.UserDefine09 = @c_Wavekey    
         GROUP BY PICKDETAIL.OrderKey    
         ,ORDERS.Storerkey    
         ,ISNULL(RTRIM(ORDERS.BillToKey), '')    
         ,ISNULL(RTRIM(ORDERS.c_Company), '')    
         ,ISNULL(RTRIM(ORDERS.C_Address1), '')    
         ,ISNULL(RTRIM(ORDERS.C_Address2), '')    
         ,ISNULL(RTRIM(ORDERS.C_Address3), '')    
         ,ISNULL(RTRIM(ORDERS.C_Zip), '')    
         ,ISNULL(RTRIM(ORDERS.Route), '')    
         ,ISNULL(RTRIM(ROUTEMASTER.Descr), '')    
         ,ISNULL(RTRIM(ORDERS.Door), '')    
         ,CONVERT(NVARCHAR(200), ISNULL(RTRIM(ORDERS.Notes), ''))    
         ,CONVERT(NVARCHAR(200), ISNULL(RTRIM(ORDERS.Notes2), ''))    
         ,ISNULL(RTRIM(PICKDETAIL.loc), '')    
         ,ISNULL(RTRIM(PICKDETAIL.sku), '')    
         ,ISNULL(RTRIM(SKU.Descr), '')    
         ,CASE PICKDETAIL.UOM    
            WHEN '1' THEN PACK.Pallet    
            WHEN '2' THEN PACK.CaseCnt    
            WHEN '3' THEN PACK.InnerPack    
            ELSE 1    
          END    
         ,ISNULL(RTRIM(PICKDETAIL.Lot),'')    
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable01),'')    
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')    
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable03),'')    
         ,ISNULL(LOTATTRIBUTE.Lottable04, '19000101')    
         ,ISNULL(LOTATTRIBUTE.Lottable05, '19000101')    
         ,ISNULL(PACK.Pallet,0)    
         ,ISNULL(PACK.CaseCnt,0)    
         ,ISNULL(RTRIM(ORDERS.ExternOrderKey),'')    
         ,ISNULL(RTRIM(LOC.LogicalLocation), '')    
         ,ISNULL(ORDERS.DeliveryDate, '19000101')    
         ,ISNULL(RTRIM(PACK.PackUOM3),'')    
         ,ISNULL(RTRIM(ORDERS.InvoiceNo),'')    
         ,ISNULL(RTRIM(SKU.ovas),'')    
         ,ISNULL(RTRIM(LOC.Putawayzone),'')    
         ,ISNULL(LOTxLOCxID.Qty,0)    
         ,ISNULL(ORDERS.Ordergroup,'')              
         ,ISNULL(RTRIM(OD.Lottable12),'') ,ISNULL(RTRIM(OD.Lottable08),'')    
         ,ISNULL(RTRIM(OD.Lottable09),''),ISNULL(RTRIM(OD.Lottable10),''),ISNULL(RTRIM(OD.Lottable11),'')    
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable12),'') ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable08),'')      
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable09),''),ISNULL(RTRIM(LOTATTRIBUTE.Lottable10),''),ISNULL(RTRIM(LOTATTRIBUTE.Lottable11),'')      
         ,PACK.PackUOM1 ,PACK.PackUOM2,PACK.PackUOM3,ISNULL(Pack.InnerPack,0),ISNULL(Pack.Qty,0)     
         ,ISNULL(ORDERS.buyerpo,'')        
         ,ISNULL(CL.SHORT,'')             
         ,ISNULL(CL1.SHORT,'')     
         ,ORDERS.Loadkey --CCH  
         ,ORDERS.Orderkey --CCH  
         ,Orders.UserDefine09   --CS01
  
   IF @c_PreGenRptData = 'Y'    
   BEGIN    
      BEGIN TRAN    
      -- Uses PickType as a Printed Flag     
      UPDATE PickHeader    
         SET PickType = '1'    
            ,TrafficCop = NULL    
      WHERE Zone = '3'    
      AND PickType = '0'    
      AND EXISTS (SELECT 1 FROM ORDERS (NOLOCK)  
                  WHERE PickHeader.ExternOrderKey = Orders.Loadkey  
                  AND PickHeader.Orderkey = Orders.Orderkey  
                  AND Orders.UserDefine09 = @c_Wavekey)  
    
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
   ELSE    
   IF @n_pickslips_required > 0    
   BEGIN    
      BEGIN TRAN    
    
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT,    
                          @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, 0,    
                          @n_pickslips_required    
    
      COMMIT TRAN    
    
      BEGIN TRAN    
      INSERT INTO PICKHEADER    
         (  PickHeaderKey    
         ,  OrderKey    
         ,  ExternOrderKey    
         ,  PickType    
         ,  Zone    
         ,  TrafficCop    
         )    
      SELECT 'P' + RIGHT(REPLICATE('0', 9)    
                 + dbo.fnc_LTrim(dbo.fnc_RTrim(STR(CAST(@c_pickheaderkey AS INT)    
                 + ( SELECT    
                     COUNT(DISTINCT orderkey)    
                     FROM    
                     #TEMP_PICK AS Rank    
                     WHERE    
                     Rank.OrderKey < #TEMP_PICK.OrderKey    
                     AND ISNULL(RTRIM(Rank.PickSlipNo),'') = ''    
                   ))-- str    
                   ))-- dbo.fnc_RTrim    
                 , 9),    
               OrderKey,    
               LoadKey,    
               '0',    
               '3',    
               ''    
      FROM #TEMP_PICK    
      WHERE ISNULL(RTRIM(PickSlipNo),'') = ''    
      GROUP BY LoadKey,    
               OrderKey    
    
      UPDATE #TEMP_PICK    
         SET PickSlipNo = PICKHEADER.PickHeaderKey    
      FROM PICKHEADER (NOLOCK)    
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey    
        AND PICKHEADER.OrderKey = #TEMP_PICK.OrderKey    
        AND PICKHEADER.Zone = '3'    
        AND ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = ''    
    
      UPDATE PICKDETAIL    
         SET PickSlipNo = #TEMP_PICK.PickSlipNo,    
             TrafficCop = NULL    
      FROM #TEMP_PICK    
      WHERE #TEMP_PICK.OrderKey = PICKDETAIL.OrderKey    
        AND ISNULL(RTRIM(PICKDETAIL.PickSlipNo),'') = ''    
    
      WHILE @@TRANCOUNT > 0    
      BEGIN    
         COMMIT TRAN    
      END    
   END    
    
       GOTO SUCCESS        
   END    
   ELSE    
   BEGIN    
      GOTO SUCCESS        
   END    
    
   FAILURE:    
   DELETE FROM #TEMP_PICK    
    
   SUCCESS:    
    
   UPDATE #TEMP_PICK    
   SET PickByCase = ISNULL(CASE WHEN CODELKUP.Code = 'PickByCase' THEN 1 ELSE 0 END,0)    
   FROM #TEMP_PICK    
   LEFT JOIN CODELKUP WITH (NOLOCK) ON ( CODELKUP.ListName = 'REPORTCFG' )    
                                    AND( CODELKUP.Storerkey= #TEMP_PICK.Storerkey )    
                                    AND( CODELKUP.Long = 'RPT_LP_PLISTN_041')    
                                    AND( CODELKUP.Short <> 'N' OR  CODELKUP.Short IS NULL )    
    
   IF @c_PreGenRptData = 'Y'    
   BEGIN    
      -- Do Auto Scan-in when Configkey is setup.    
      SET @c_StorerKey = ''    
      SET @c_PickSlipNo = ''    
    
      SELECT DISTINCT @c_StorerKey = StorerKey    
        FROM #TEMP_PICK (NOLOCK)    
    
      IF EXISTS (SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN'    
                    AND SValue = '1' AND StorerKey = @c_StorerKey)    
      BEGIN    
         DECLARE C_AutoScanPickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT DISTINCT PickSlipNo    
           FROM #TEMP_PICK (NOLOCK)    
    
         OPEN C_AutoScanPickSlip    
         FETCH NEXT FROM C_AutoScanPickSlip INTO @c_PickSlipNo    
    
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            IF NOT EXISTS (SELECT 1 FROM PICKINGINFO (NOLOCK) Where PickSlipNo = @c_PickSlipNo)    
            BEGIN    
               INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID, ScanOutDate)    
               VALUES (@c_PickSlipNo, GetDate(), sUser_sName(), NULL)    
    
               IF @@ERROR <> 0    
               BEGIN    
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61900    
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) +    
                                     ': Insert PickingInfo Failed. (isp_RPT_WV_WAVPICKSUM_014)' + ' ( ' +    
                                     ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
               END    
            END -- PickSlipNo Does Not Exist    
    
            FETCH NEXT FROM C_AutoScanPickSlip INTO @c_PickSlipNo    
         END    
         CLOSE C_AutoScanPickSlip    
         DEALLOCATE C_AutoScanPickSlip    
      END -- Configkey is setup    
   END    
    
    
      IF @c_PreGenRptData='Y'    
      BEGIN    
          SET @c_PreGenRptData=''    
      END    
    
  --CS01 S
   SELECT @c_PrevOrderKey = N''
   SELECT @n_PgGroup = 1  
   SET    @n_TTLPAGE = 1
   SET    @c_ChgGrp  = 'N'
    DECLARE Page_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT OrderKey,RowNum   
   FROM #TEMP_PICK (NOLOCK)    
   WHERE wavekey = @c_Wavekey   
   ORDER BY loadkey,OrderKey    
    
   OPEN Page_cur    
    
   FETCH NEXT FROM Page_cur    
   INTO  @c_orderkey,@n_RowNum    
    
   WHILE (@@FETCH_STATUS <> -1)    
   BEGIN    
      IF @c_PrevOrderKey = '' 
      BEGIN 
             SET @c_PrevOrderKey = @c_orderkey
      END 
    
      IF (@c_orderkey <> @c_PrevOrderKey)   
      BEGIN    
             SET  @n_PgGroup = 1 
             SET  @n_initialflag =  1
      END    

      SELECT @n_ctnord = COUNT(orderkey)
      FROM #TEMP_PICK
      WHERE orderkey = @c_orderkey

      IF @n_RowNum%@n_NoOfLine = 0 
      BEGIN
          SET  @c_ChgGrp = 'Y' --@n_PgGroup = @n_PgGroup + 1
      END
      ELSE 
      BEGIN
          SET  @c_ChgGrp = 'N' 
      END


     IF (@n_ctnord/@n_NoOfLine) = 0
     BEGIN
         SET @n_TTLPAGE = 1
     END
     ELSE
     BEGIN
           IF @n_ctnord%@n_NoOfLine = 0
           BEGIN
                SET @n_TTLPAGE = (@n_ctnord/@n_NoOfLine) 
           END  
           ELSE
           BEGIN
                SET @n_TTLPAGE = (@n_ctnord/@n_NoOfLine) + 1
           END     
     END
 
      UPDATE #TEMP_PICK   
      SET pgGroup = @n_PgGroup
          ,TTLPAGE = @n_TTLPAGE
      WHERE orderkey = @c_orderkey AND RowNum = @n_RowNum


     IF @c_ChgGrp = 'Y'
     BEGIN
       SET @n_PgGroup = @n_PgGroup + 1  
     END

      SELECT @c_PrevOrderKey = @c_orderkey   
      SELECT @n_initialflag = @n_initialflag + 1
 
      FETCH NEXT FROM Page_cur    
      INTO @c_orderkey ,@n_RowNum     
   END    
   CLOSE Page_cur    
   DEALLOCATE Page_cur  
   --CS01 E

   IF ISNULL(@c_PreGenRptData,'') IN ('','0')    
   BEGIN    
   SELECT PickSlipNo    
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
         , SKU    
         , SkuDesc    
         , CASE WHEN PickByCase = 1 AND PackCaseCnt > 0 THEN (Qty % PackCaseCnt)    
                          ELSE Qty END AS Qty    
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
         , InvoiceNo    
         , Ovas    
         , Putawayzone    
         , PickByCase    
         , CASE WHEN PickByCase = 1 AND PackCaseCnt > 0 THEN FLOOR(Qty / PackCaseCnt)    
                          ELSE 0 END AS qtycase    
         , Qty AS qtypicked    
         , SysQty    
         , ORDGRP,LOTT12,lotlOT12,BatchNo,BatchNo2,SerialNo,SerialNo2    
         , PackUOM1 ,PackUOM2,PackUOM3,ISNULL(PInnerPack,0),ISNULL(PUOM3Qty,0)    
         , buyerpo         
         , SHOWBUYERPO     
         , SHOWFIELD    
         , ISNULL(@c_Retval,'') AS Logo    
         , TTLPAGE
   FROM #TEMP_PICK    
   END    
    
   IF OBJECT_ID('tempdb..#TEMP_PICK') IS NOT NULL    
      DROP TABLE #TEMP_PICK      
        

   IF OBJECT_ID('tempdb..#Page_cur') IS NOT NULL    
      DROP TABLE #Page_cur 

   WHILE @@TRANCOUNT < @n_starttcnt        
   BEGIN        
      BEGIN TRAN        
   END     
END 

GO