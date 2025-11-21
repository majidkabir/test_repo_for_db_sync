SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/    
/* Stored Proc : nsp_GetPickSlipOrders03h                                   */    
/* Creation Date:11-JAN-2021                                                */    
/* Copyright: IDS                                                           */    
/* Written by:                                                              */    
/*                                                                          */    
/* Purpose: WMS-15992 SG - MHAP - Picking List CR                           */    
/*                                                                          */    
/*                                                                          */    
/* Usage:                                                                   */    
/*                                                                          */    
/* Local Variables:                                                         */    
/*                                                                          */    
/* Called By: r_dw_print_pickorder03h                                       */    
/*                                                                          */    
/* PVCS Version: 2.0                                                        */    
/*                                                                          */    
/* Version: 5.4                                                             */    
/*                                                                          */    
/* Data Modifications:                                                      */    
/*                                                                          */    
/* Updates:                                                                 */    
/* Date        Author      Ver   Purposes                                   */    
/* 2021-07-07  WLChooi     1.1   WMS-17430 - Add Storerkey (WL01)           */
/****************************************************************************/    
    
CREATE PROC [dbo].[nsp_GetPickSlipOrders03h] (@c_loadkey NVARCHAR(10))    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   -- Added by YokeBeen on 30-Jul-2004 (SOS#25474) - (YokeBeen01)    
   -- Added SKU.SUSR3 (Agency) & ORDERS.InvoiceNo.    
    
DECLARE  @c_pickheaderkey        NVARCHAR(10),    
         @n_continue             INT,    
         @c_errmsg               NVARCHAR(255),    
         @b_success              INT,    
         @n_err                  INT,    
         @c_sku                  NVARCHAR(22),    
         @n_qty                  INT,    
         @c_loc                  NVARCHAR(10),    
         @n_cases                INT,    
         @n_perpallet            INT,    
         @c_storer               NVARCHAR(15),    
         @c_orderkey             NVARCHAR(10),    
         @c_ConsigneeKey         NVARCHAR(15),    
         @c_Company              NVARCHAR(45),    
         @c_Addr1                NVARCHAR(45),    
         @c_Addr2                NVARCHAR(45),    
         @c_Addr3                NVARCHAR(45),    
         @c_PostCode             NVARCHAR(15),    
         @c_Route                NVARCHAR(10),    
         @c_Route_Desc           NVARCHAR(60),   
         @c_TrfRoom              NVARCHAR(5),       
         @c_Notes1               NVARCHAR(200),    
         @c_Notes2               NVARCHAR(200),  
         @c_SkuDesc              NVARCHAR(60),    
         @n_CaseCnt              INT,    
         @n_PalletCnt            INT,    
         @c_ReceiptTm            NVARCHAR(20),    
         @c_PrintedFlag          NVARCHAR(1),    
         @c_UOM                  NVARCHAR(10),    
         @n_UOM3                 INT,    
         @c_Lot                  NVARCHAR(10),    
         @c_StorerKey            NVARCHAR(15),    
         @c_Zone                 NVARCHAR(1),    
         @n_PgGroup              INT,    
         @n_TotCases             INT,    
         @n_RowNo                INT,    
         @c_PrevSKU              NVARCHAR(20),    
         @n_SKUCount             INT,    
         @c_Carrierkey           NVARCHAR(60),    
         @c_VehicleNo            NVARCHAR(10),    
         @c_firstorderkey        NVARCHAR(10),    
         @c_superorderflag       NVARCHAR(1),    
         @c_firsttime            NVARCHAR(1),    
         @c_logicalloc           NVARCHAR(18),    
         @c_Lottable01           NVARCHAR(18),    
         @c_Lottable02           NVARCHAR(18),    
         @c_Lottable03           NVARCHAR(18),    
         @d_Lottable04           DATETIME,    
         @d_Lottable05           DATETIME,    
         @n_packpallet           INT,    
         @n_packcasecnt          INT,    
         @c_externorderkey       NVARCHAR(50),   --tlting_ext  
         @n_pickslips_required   INT,    
         @dt_deliverydate        DATETIME    
       , @n_TBLSkuPattern        INT                
       , @n_SortBySkuLoc         INT                
       , @c_PalletID             NVARCHAR(30)     
       , @c_ExtraInfo            NVARCHAR(255) = ''    
       , @n_SortByLoc            INT                      
          
DECLARE  @c_PrevOrderKey NVARCHAR(10),    
         @n_Pallets      INT,    
         @n_Cartons      INT,    
         @n_Eaches       INT,    
         @n_UOMQty       INT,    
         @c_Susr3        NVARCHAR(18),          
         @c_InvoiceNo    NVARCHAR(10)             
    
DECLARE @n_starttcnt INT    
SELECT  @n_starttcnt = @@TRANCOUNT    
    
WHILE @@TRANCOUNT > 0    
BEGIN    
   COMMIT TRAN    
END    
    
SET @n_pickslips_required = 0 -- (Leong01)    
  
SET @c_ExtraInfo = N'ôPLEASE USE/CHANGE TO BLACK CARTONö for HNWI customer'  

    
BEGIN TRAN    
   CREATE TABLE #temp_pick    
         (PickSlipNo        NVARCHAR(10) NULL,    
          LoadKey           NVARCHAR(10),    
          OrderKey          NVARCHAR(10),    
          ConsigneeKey      NVARCHAR(15),    
          Company           NVARCHAR(45),    
          Addr1             NVARCHAR(45) NULL,    
          Addr2             NVARCHAR(45) NULL,    
          Addr3             NVARCHAR(45) NULL,    
          PostCode          NVARCHAR(15) NULL,    
          Route             NVARCHAR(10) NULL,    
          Route_Desc        NVARCHAR(60) NULL,   
          TrfRoom           NVARCHAR(5) NULL,    
          Notes1            NVARCHAR(200) NULL,    
          Notes2            NVARCHAR(200) NULL,  
          LOC               NVARCHAR(10) NULL,    
          SKU               NVARCHAR(22),    
          SkuDesc           NVARCHAR(60),    
          Qty               INT,    
          TempQty1          INT,    
          TempQty2          INT,    
          PrintedFlag       NVARCHAR(1) NULL,    
          Zone              NVARCHAR(1),    
          PgGroup           INT,    
          RowNum            INT,    
          Lot               NVARCHAR(10),    
          Carrierkey        NVARCHAR(60) NULL,    
          VehicleNo         NVARCHAR(10) NULL,    
          Lottable01        NVARCHAR(18) NULL,    
          Lottable02        NVARCHAR(18) NULL,    
          Lottable03        NVARCHAR(18) NULL,    
          Lottable04        DATETIME NULL,    
          Lottable05        DATETIME NULL,    
          packpallet        INT,    
          packcasecnt       INT,    
          externorderkey    NVARCHAR(50) null,   --tlting_ext  
          LogicalLoc        NVARCHAR(18) NULL,    
          DeliveryDate      DATETIME NULL,    
          Uom               NVARCHAR(10),           
          Susr3             NVARCHAR(18) NULL,           
          InvoiceNo         NVARCHAR(10) NULL,           
          Ovas              char (30) NULL           
      ,   SortBySkuLoc      INT        NULL             
      ,   ShowAltSku        INT NULL             
      ,   AltSku            NVARCHAR(20) NULL          
      ,   ShowExtOrdBarcode INT NULL                    
      ,   HideSusr3         INT NULL                   
      ,   ShowField         INT NULL                   
      ,   ODUdef02          NVARCHAR(30)               
      ,   PickZone          NVARCHAR(10)                
      ,   ShowPalletID      INT NULL                  
      ,   PalletID          NVARCHAR(30)            
      ,   ShowSKUBusr10     INT                      
      ,   SKUBusr10         NVARCHAR(30)             
      ,   ShowExtraInfo     INT                       
      ,   ShowExtraSKUInfo  INT                       
      ,   RetailSKU         NVARCHAR(20)              
      ,   ManufacturerSKU   NVARCHAR(20)             
      ,   SortByLoc         INT        NULL             
      ,   ShowPickdetailID  NVARCHAR(10) 
      ,   mbolkey           NVARCHAR(20) NULL
      ,   Containerkey      NVARCHAR(20) NULL 
      ,   Storerkey         NVARCHAR(15) NULL   --WL01       
      )    
  
   SELECT Storerkey    
         ,TBLSkuPattern = ISNULL(MAX(CASE WHEN Code = 'TBLSKUPATTERN' THEN 1 ELSE 0 END),0)    
         ,SortBySkuLoc  = ISNULL(MAX(CASE WHEN Code = 'SortBySkuLoc'  THEN 1 ELSE 0 END),0)    
         ,ShowAltSku   =  ISNULL(MAX(CASE WHEN Code = 'ShowAltSku'  THEN 1 ELSE 0 END),0)             
         ,ShowExtOrdBarcode = ISNULL(MAX(CASE WHEN Code = 'ShowExtOrdKeyBarcode'  THEN 1 ELSE 0 END),0)        
         ,HideSusr3       = ISNULL(MAX(CASE WHEN Code = 'HIDESUSR3'  THEN 1 ELSE 0 END),0)        
         ,ShowField       = ISNULL(MAX(CASE WHEN Code = 'SHOWFIELD'  THEN 1 ELSE 0 END),0)        
         ,PageBreakByPickZone = ISNULL(MAX(CASE WHEN Code = 'PageBreakByPickZone'  THEN 1 ELSE 0 END),0)        
         ,ShowPalletID =  ISNULL(MAX(CASE WHEN Code = 'ShowPalletID'  THEN 1 ELSE 0 END),0)      
         ,showskubusr10 = ISNULL(MAX(CASE WHEN Code = 'SHOWSKUBUSR10'  THEN 1 ELSE 0 END),0)     
         ,ShowExtraInfo = ISNULL(MAX(CASE WHEN Code = 'ShowExtraInfo'  THEN 1 ELSE 0 END),0)      
         ,ShowExtraSKUInfo = ISNULL(MAX(CASE WHEN Code = 'ShowExtraSKUInfo'  THEN 1 ELSE 0 END),0)      
         ,SORTBYLOC = ISNULL(MAX(CASE WHEN Code = 'SORTBYLOC'  THEN 1 ELSE 0 END),0)    
   INTO #TMP_RPTCFG    
   FROM CODELKUP WITH (NOLOCK)    
   WHERE ListName = 'REPORTCFG'    
   AND Long       = 'r_dw_print_pickorder03'    
   AND (Short IS NULL OR Short <> 'N')    
   GROUP BY Storerkey    

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order    
   IF EXISTS( SELECT 1 FROM PickHeader (NOLOCK)    
              WHERE ExternOrderKey = @c_loadkey    
              AND   Zone = '3' )    
   BEGIN    
      SELECT @c_firsttime = 'N'    
      SELECT @c_PrintedFlag = 'Y'    
   END    
   ELSE    
   BEGIN    
      SELECT @c_firsttime = 'Y'    
      SELECT @c_PrintedFlag = 'N'  
   END -- Record Not Exists    
    
   INSERT INTO #Temp_Pick    
      (PickSlipNo,   LoadKey,     OrderKey,       ConsigneeKey,    
      Company,      Addr1,       Addr2,          PgGroup,    
      Addr3,        PostCode,    Route,          Route_Desc,    
      TrfRoom,      Notes1,      RowNum,         Notes2,    
      LOC,          SKU,         SkuDesc,        Qty,    
      TempQty1,     TempQty2,    PrintedFlag,    Zone,    
      Lot,          CarrierKey,  VehicleNo,      Lottable01,    
      Lottable02,   Lottable03,  Lottable04,     Lottable05,    
      packpallet,   packcasecnt, externorderkey, LogicalLoc,    
      DeliveryDate, UOM,         
      Susr3,        InvoiceNo,      
      Ovas                     
   ,  SortBySkuLoc,ShowAltSku,Altsku,ShowExtOrdBarcode,HideSusr3,ShowField,ODUdef02             
   ,  PickZone                                                                             
   ,  ShowPalletID     
   ,  PalletID       
   ,  ShowSKUBusr10,SKUBusr10            
   ,  ShowExtraInfo    
   ,  ShowExtraSKUInfo    
   ,  RetailSKU           
   ,  ManufacturerSKU     
   ,  SortByLoc         
   ,  ShowPickdetailID,mbolkey ,Containerkey 
   ,  Storerkey   --WL01
   )    
   SELECT (SELECT PICKHEADERKEY FROM PICKHEADER (NOLOCK)    
           WHERE ExternOrderKey = @c_LoadKey    
             AND OrderKey = PickDetail.OrderKey    
             AND Zone = '3'),    
         @c_LoadKey as LoadKey,    
         PickDetail.OrderKey,    
         ISNULL(ORDERS.BillToKey, '') AS ConsigneeKey,    
         ISNULL(ORDERS.c_Company, '') AS Company,    
         ISNULL(ORDERS.c_Address1, '') AS Addr1,    
         ISNULL(ORDERS.c_Address2, '') AS Addr2,    
         0 AS PgGroup,    
         ISNULL(ORDERS.c_Address3, '') AS Addr3,    
         ISNULL(ORDERS.c_Zip, '') AS PostCode,    
         ISNULL(ORDERS.Route, '') AS Route,    
         ISNULL(RouteMaster.Descr, '') Route_Desc,    
         ORDERS.Door AS TrfRoom,     
         CONVERT(NVARCHAR(200), ISNULL(ORDERS.Notes, '')) Notes1,   
         0 AS RowNo,     
         CONVERT(NVARCHAR(200), ISNULL(ORDERS.Notes2, '')) Notes2,  
         PickDetail.loc,          
         CASE WHEN ISNULL(TBLSkuPattern,0) = 0 THEN PickDetail.sku    
              WHEN ISNULL(TBLSkuPattern,0) = 1 AND SKU.ItemClass like '%FT%'    
              THEN SUBSTRING(SKU.Style,5,6) + '-' + ISNULL(RTRIM(SKU.Measurement),'') + '-' + SUBSTRING(SKU.Sku,12,1) + '-' + ISNULL(RTRIM(SKU.Size),'')    
              ELSE SUBSTRING(SKU.Style,5,6) + '-' + ISNULL(RTRIM(SKU.Color ),'') + '-' + SUBSTRING(SKU.Sku,12,1) + '-' + ISNULL(RTRIM(SKU.Size),'')    
         END AS 'SKU',     
         ISNULL(Sku.Descr, '') SkuDesc,    
         SUM(PickDetail.qty) AS Qty,    
         CASE PickDetail.UOM    
            WHEN '1' THEN PACK.Pallet    
            WHEN '2' THEN PACK.CaseCnt    
            WHEN '3' THEN PACK.InnerPack    
         ELSE 1  END AS UOMQty,    
         0 AS TempQty2,    
         ISNULL((SELECT DISTINCT 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_LoadKey    
                 AND Zone = '3'), 'N') AS PrintedFlag,    
         '3' Zone,    
         PickDetail.Lot,    
         '' CarrierKey,    
         '' AS VehicleNo,    
         Lotattribute.Lottable01,    
         Lotattribute.Lottable02,    
         Lotattribute.Lottable03,    
         ISNULL(Lotattribute.Lottable04, '19000101') Lottable04,    
         ISNULL(Lotattribute.Lottable05, '19000101') Lottable05,    
         PACK.Pallet,    
         PACK. CaseCnt,    
         ORDERS.ExternOrderKey AS ExternOrderKey,    
         ISNULL(LOC.LogicalLocation, '') AS LogicalLocation,    
         ISNULL(ORDERS.DeliveryDate, '19000101') DeliveryDate,    
         PACK.PackUOM3,    
         CASE WHEN ISNULL(HideSusr3,0) = 1 THEN '' ELSE SKU.SUSR3 END,                  
         ORDERS.InvoiceNo,            
         CASE WHEN SKU.SUSR4 = 'SSCC' THEN       
                   '**Scan Serial No** ' + RTRIM(ISNULL(SKU.Ovas,''))    
              ELSE    
              SKU.Ovas    
         END    
      ,  ISNULL(SortBySkuLoc,0)                  
      ,  ISNULL(ShowAltsku,0)                    
      ,  ISNULL(SKU.AltSku,'')                   
      ,  ISNULL(ShowExtOrdBarcode,0)             
      ,  ISNULL(HideSusr3,0)                      
      ,  ISNULL(ShowField,0)                      
      ,  ISNULL(ORDERDETAIL.userdefine02,'')                  
      ,  PickZone = CASE WHEN ISNULL(RC.PageBreakByPickZone,0) = 1 THEN LOC.PickZone ELSE '' END        
      ,  ISNULL(ShowPalletID,0)        
      ,  Pickdetail.ID --WL01  
      ,  ISNULL(RC.showskubusr10,0)            
      ,  ISNULL(Sku.busr10,'')                 
      ,  ISNULL(RC.ShowExtraInfo,0)             
      ,  ISNULL(RC.ShowExtraSKUInfo,0)          
      ,  SKU.RetailSKU                          
      ,  SKU.ManufacturerSKU                    
      ,  ISNULL(SortByLoc,0)                    
      ,  ISNULL(CLR.Short,'N') AS ShowPickdetailID   
      ,  ISNULL(MB.mbolkey,'')
      ,  ISNULL(CONT.ContainerKey,'') 
      ,  ORDERS.StorerKey   --WL01
   FROM LOADPLANDETAIL (NOLOCK)    
   JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = LoadPlanDetail.Orderkey)     
   JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)     
   JOIN Storer (NOLOCK) ON (ORDERS.StorerKey = Storer.StorerKey)    
   LEFT OUTER JOIN RouteMaster ON (RouteMaster.Route = ORDERS.Route)       
   JOIN PickDetail (NOLOCK) ON (PickDetail.OrderKey = ORDERDETAIL.Orderkey and PickDetail.OrderLineNumber = ORDERDETAIL.OrderLineNumber )    
   JOIN LotAttribute (NOLOCK) ON (PickDetail.Lot = LotAttribute.Lot)    
   JOIN Sku (NOLOCK)  ON (Sku.StorerKey = PickDetail.StorerKey AND Sku.Sku = PickDetail.Sku)       
   JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)      
   JOIN LOC (NOLOCK) ON (PICKDETAIL.LOC = LOC.LOC)    
   LEFT JOIN #TMP_RPTCFG RC ON (ORDERS.Storerkey = RC.Storerkey)          
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) 
   ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'ShowPickdetailID' AND CLR.Code2 = 'r_dw_print_pickorder03'                                            
   AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_print_pickorder03' AND ISNULL(CLR.Short,'') <> 'N')   
   LEFT JOIN MBOL MB WITH (NOLOCK) ON MB.mbolkey = ORDERS.mbolkey
   LEFT JOIN CONTAINER CONT WITH (NOLOCK) ON CONT.OtherReference = MB.mbolkey
   WHERE PickDetail.Status >= '0'    
    AND LoadPlanDetail.LoadKey = @c_LoadKey    
   GROUP BY PickDetail.OrderKey,    
            ISNULL(ORDERS.BillToKey, ''),    
            ISNULL(ORDERS.c_Company, ''),    
            ISNULL(ORDERS.C_Address1,''),                ISNULL(ORDERS.C_Address2,''),    
            ISNULL(ORDERS.C_Address3,''),    
            ISNULL(ORDERS.C_Zip,''),    
            ISNULL(ORDERS.Route,''),    
            ISNULL(RouteMaster.Descr, ''),    
            ORDERS.Door,      
            CONVERT(NVARCHAR(200), ISNULL(ORDERS.Notes,  '')),  
            CONVERT(NVARCHAR(200), ISNULL(ORDERS.Notes2, '')),   
            PickDetail.loc,        
            CASE WHEN ISNULL(TBLSkuPattern,0) = 0 THEN PickDetail.sku    
                 WHEN ISNULL(TBLSkuPattern,0) = 1 AND SKU.ItemClass like '%FT%'    
                 THEN SUBSTRING(SKU.Style,5,6) + '-' + ISNULL(RTRIM(SKU.Measurement),'') + '-' + SUBSTRING(SKU.Sku,12,1) + '-' + ISNULL(RTRIM(SKU.Size),'')    
                 ELSE SUBSTRING(SKU.Style,5,6) + '-' + ISNULL(RTRIM(SKU.Color ),'') + '-' + SUBSTRING(SKU.Sku,12,1) + '-' + ISNULL(RTRIM(SKU.Size),'')    
            END,      
            ISNULL(Sku.Descr,''),    
            CASE PickDetail.UOM    
                WHEN '1' THEN PACK.Pallet    
                WHEN '2' THEN PACK.CaseCnt    
                WHEN '3' THEN PACK.InnerPack    
                ELSE 1  END,    
            Pickdetail.Lot,    
            LotAttribute.Lottable01,    
            LotAttribute.Lottable02,    
            LotAttribute.Lottable03,    
            ISNULL (LotAttribute.Lottable04, '19000101'),    
            ISNULL (LotAttribute.Lottable05, '19000101'),    
            PACK.Pallet,    
            PACK.CaseCnt,    
            ORDERS.ExternOrderKey,    
            ISNULL(LOC.LogicalLocation, ''),    
            ISNULL(ORDERS.DeliveryDate, '19000101'),    
            PACK.PackUOM3, 
            SKU.SUSR3,             
            ORDERS.InvoiceNo,        
            CASE WHEN SKU.SUSR4 = 'SSCC' THEN  
                    '**Scan Serial No** ' + RTRIM(ISNULL(SKU.Ovas,''))    
                   ELSE    
                   SKU.Ovas    
            END    
         ,  ISNULL(SortBySkuLoc,0)                           
         ,  ISNULL(ShowAltsku,0)                      
         ,  ISNULL(SKU.AltSku,'')                     
         ,  ISNULL(ShowExtOrdBarcode,0)               
         ,  ISNULL(HideSusr3,0)                       
         ,  ISNULL(ShowField,0)                      
         ,  ISNULL(ORDERDETAIL.userdefine02,'')                  
         ,  CASE WHEN ISNULL(RC.PageBreakByPickZone,0) = 1 THEN LOC.PickZone ELSE '' END                
         ,  ISNULL(ShowPalletID,0)        
         ,  Pickdetail.ID --WL01  
         ,  ISNULL(RC.showskubusr10,0)               
         ,  ISNULL(Sku.busr10,'')                    
         ,  ISNULL(RC.ShowExtraInfo,0)                
         ,  ISNULL(RC.ShowExtraSKUInfo,0)             
         ,  SKU.RetailSKU                             
         ,  SKU.ManufacturerSKU                       
         ,  ISNULL(SortByLoc,0)                      
         ,  ISNULL(CLR.Short,'N')      
         ,  ISNULL(MB.mbolkey,'')
         ,  ISNULL(CONT.ContainerKey,'') 
         ,  ORDERS.StorerKey   --WL01              
  
   BEGIN TRAN    
   -- Uses PickType as a Printed Flag       
   UPDATE PickHeader    
      SET PickType = '1',    
          TrafficCop = NULL    
   WHERE ExternOrderKey = @c_loadkey    
   AND Zone = '3'  
   AND PickType = '0'    
    
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
    
      BEGIN TRAN    
      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)    
      SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +    
                   dbo.fnc_LTrim( dbo.fnc_RTrim(    
                   STR(    
                        CAST(@c_pickheaderkey AS INT) + ( SELECT COUNT(DISTINCT orderkey)    
                                                          FROM #TEMP_PICK as Rank    
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
        AND PICKHEADER.OrderKey = #TEMP_PICK.OrderKey    
        AND PICKHEADER.Zone = '3'    
        AND ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = '' 
    
      UPDATE PICKDETAIL    
      SET PickSlipNo = #TEMP_PICK.PickSlipNo,    
          TrafficCop = NULL    
      FROM #TEMP_PICK    
      WHERE #TEMP_PICK .OrderKey = PICKDETAIL.OrderKey    
        AND ISNULL(RTRIM(PICKDETAIL.PickSlipNo),'') = '' 
    
      WHILE @@TRANCOUNT > 0    
      BEGIN    
         COMMIT TRAN    
      END    
   END    
     GOTO SUCCESS    
    
FAILURE:    
   DELETE FROM #TEMP_PICK    
SUCCESS:    
   SELECT     
         PickSlipNo        
      ,  LoadKey          
      ,  OrderKey         
      ,  ConsigneeKey     
      ,  Company          
      ,  Addr1            
      ,  Addr2            
      ,  Addr3            
      ,  PostCode         
      ,  [Route]            
      ,  Route_Desc       
      ,  TrfRoom          
      ,  Notes1           
      ,  Notes2           
      ,  LOC              
      ,  SKU              
      ,  SkuDesc          
      ,  Qty              
      ,  TempQty1         
      ,  TempQty2         
      ,  PrintedFlag      
      ,  Zone             
      ,  PgGroup          
      ,  RowNum           
      ,  Lot              
      ,  Carrierkey       
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
      ,  Uom                                                           
      ,  Susr3                                                         
      ,  InvoiceNo                                                     
      ,  Ovas      
      ,  SortBySkuLoc                                                  
      ,  ShowAltSku                                                    
      ,  AltSku                                                        
      ,  ShowExtOrdBarcode                                      
      ,  HideSusr3                                              
      ,  ShowField                                              
      ,  ODUdef02                                               
      ,  PickZone      
      ,  ShowPalletID  
      ,  PalletID    
      ,  ShowSKUBusr10    
      ,  SKUBusr10         
      ,  CASE WHEN ISNULL(ShowExtraInfo,0) = 1 THEN @c_ExtraInfo ELSE '' END AS ExtraInfo     
      ,  CASE WHEN ISNULL(ShowExtraSKUInfo,0) = 1 THEN RetailSKU ELSE '' END AS RetailSKU     
      ,  CASE WHEN ISNULL(ShowExtraSKUInfo,0) = 1 THEN ManufacturerSKU ELSE '' END AS ManufacturerSKU     
      ,  ShowPickdetailID   
      ,  mbolkey
      ,  Containerkey
      ,  Storerkey   --WL01
   FROM #TEMP_PICK       
   ORDER BY Company    
         ,  Orderkey    
         ,  PickZone                                                   
         ,  SUSR3    
         ,  CASE WHEN SortBySkuLoc = 1 AND Sortbyloc = 0 THEN Sku ELSE '' END                
         ,  CASE WHEN SortBySkuLoc = 1 OR Sortbyloc = 1 THEN '' ELSE LogicalLoc END         
         ,  Loc    
         ,  CASE WHEN SortBySkuLoc = 1 THEN '' ELSE Sku END    
         ,  Lottable01       
   DROP Table #TEMP_PICK    
    
   WHILE @@TRANCOUNT < @n_starttcnt    
   BEGIN    
      BEGIN TRAN    
   END    
END    

GO