SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_RPT_RP_LP_PLIST_001                            */    
/* Creation Date: 2023-03-01                                            */    
/* Copyright: IDS                                                       */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose:WMS-21847 SG û MNC û Non MTO Picking Slip                    */  
/*                                                                      */    
/* Input Parameters:  @c_loadKey  - loadkey                             */    
/*                    @c_orderkey - orderkey                            */   
/*                                                                      */    
/* Output Parameters:  None                                             */    
/*                                                                      */    
/* Return Status:  None                                                 */    
/*                                                                      */    
/* Usage: RPT_RP_LP_PLIST_001                                           */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.3                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author     Purposes                                     */    
/* 2023-03-01   CHONGCS   Devops Scripts Combine                        */       
/* 2023-05-17   CHONGCS   WMS-22497 pagenumber by orderkey (CS01)       */                  
/************************************************************************/    
CREATE    PROC [dbo].[isp_RPT_RP_LP_PLIST_001] ( 
                                            @c_loadKey     NVARCHAR(10) = '',  
                                            @c_orderkey    NVARCHAR(10) = ''  
  
)    
 AS    
BEGIN    
    SET NOCOUNT ON    
    SET QUOTED_IDENTIFIER OFF    
    SET CONCAT_NULL_YIELDS_NULL OFF    
    
    DECLARE @n_continue       INT    
         ,  @c_errmsg         NVARCHAR(255)    
         ,  @b_success        INT    
         ,  @n_err            INT    
         ,  @n_StartTCnt      INT    
    
         ,  @c_SQL            NVARCHAR(MAX)    
         ,  @c_Storerkey      NVARCHAR(15) 
         ,  @n_NoOfLine       INT           --CS01   
         ,  @n_RowNum         INT           --CS01   
         ,  @n_initialflag    INT = 1       --CS01
         ,  @n_TTLPage        INT = 1       --CS01 
         ,  @n_ctnord         INT = 1       --CS01
         ,  @c_ChgGrp         NVARCHAR(1) = 'N'   --CS01 
         ,  @n_PgGroup        INT            --CS01   
         ,  @c_PrevOrderKey   NVARCHAR(10)   --CS01 
       
    
   SET @n_StartTCnt = @@TRANCOUNT    
  
DECLARE    @c_Type        NVARCHAR(1) = '1'                            
         , @c_DataWindow  NVARCHAR(60) = 'RPT_RP_LP_PLIST_001'        
         , @c_RetVal      NVARCHAR(255)       
  
  
SET @c_RetVal = ''     
SET @n_NoOfLine = 5     --CS01
  
  
               SELECT TOP 1 @c_Storerkey = O.StorerKey  
               FROM ORDERS O WITH (NOLOCK)  
               WHERE (O.LoadKey = @c_LoadKey or O.OrderKey = @c_OrderKey)  
    
IF ISNULL(@c_Storerkey,'') <> ''        
BEGIN        
        
EXEC [dbo].[isp_GetCompanyInfo]        
         @c_Storerkey  = @c_Storerkey        
      ,  @c_Type       = @c_Type        
      ,  @c_DataWindow = @c_DataWindow        
      ,  @c_RetVal     = @c_RetVal           OUTPUT        
         
END    

   CREATE TABLE #temp_PLIST_001    
   (          
      LoadKey            NVARCHAR(10),        
      OrderKey           NVARCHAR(10),     
      OrderKey_Barcode   NVARCHAR(10) NULL,     
      externorderkey     NVARCHAR(50) NULL,    
      InvoiceNo          NVARCHAR(20) NULL,     
      DeliveryDate       NVARCHAR(10) NULL,      
      ConsigneeKey       NVARCHAR(45) NULL,    
      Company            NVARCHAR(100) NULL,      
      Addr1              NVARCHAR(45) NULL,        
      Addr2              NVARCHAR(45) NULL,        
      Addr3              NVARCHAR(45) NULL,  
      PostCode           NVARCHAR(45) NULL,
      ROUTE              NVARCHAR(10) NULL, 
      Route_Desc         NVARCHAR(60) NULL,      
      TrfRoom            NVARCHAR(10) NULL,  
      Notes1             NVARCHAR(200) NULL, 
      Notes2             NVARCHAR(200) NULL, 
      CarrierKey         NVARCHAR(45) NULL, 
      VehicleNo          NVARCHAR(45) NULL,
      SKU                NVARCHAR(20),        
      SkuDesc            NVARCHAR(60),     
      SUSR3              NVARCHAR(18) NULL,  
      OrderQty           INT,    
      UOM                NVARCHAR(10) NULL, 
      PACKKEY            NVARCHAR(10) NULL, 
      Location           NVARCHAR(10) NULL,   
      FamilyGroup        NVARCHAR(30) NULL, 
      Box                NVARCHAR(30) NULL, 
      Powers             NVARCHAR(20) NULL,  
      CYC                NVARCHAR(30) NULL,  
      Axis               NVARCHAR(10) NULL, 
      Type               NVARCHAR(10) NULL, 
      OHAddDate          NVARCHAR(10) NULL, 
      Retailsku          NVARCHAR(20) NULL,    
      ORDGRP             NVARCHAR(20) NULL,     
      Logo               NVARCHAR(255) NULL,   
      skugroup           NVARCHAR(10) NULL,      
      skugrpbarcode      NVARCHAR(20) NULL,  
      RowNum             INT, 
      PgGroup            INT,        
      TTLPAGE            INT                   
   )   
     
 INSERT INTO #temp_PLIST_001
 (
     LoadKey,
     OrderKey,
     OrderKey_Barcode,
     externorderkey,
     InvoiceNo,
     DeliveryDate,
     ConsigneeKey,
     Company,
     Addr1,
     Addr2,
     Addr3,
     PostCode,
     ROUTE,
     Route_Desc,
     TrfRoom,
     Notes1,
     Notes2,
     CarrierKey,
     VehicleNo,
     SKU,
     SkuDesc,
     SUSR3,
     OrderQty,
     UOM,
     PACKKEY,
     Location,
     FamilyGroup,
     Box,
     Powers,
     CYC,
     Axis,
     Type,
     OHAddDate,
     Retailsku,
     ORDGRP,
     Logo,
     skugroup,
     skugrpbarcode,
     RowNum,
     PgGroup,
     TTLPAGE
 )
 
         SELECT   O.LoadKey,  
                  O.Orderkey,  
                  OrderKey_Barcode =  O.Orderkey ,   
                  O.ExternOrderKey,   
                  O.InvoiceNo,  
                  CONVERT(NVARCHAR(10),O.deliverydate,103) DeliveryDate,  
                  ISNULL(O.BillToKey, '') AS ConsigneeKey,    
                  ISNULL(O.c_Company, '') AS Company,    
                  ISNULL(O.c_Address1, '') AS Addr1,    
                  ISNULL(O.c_Address2, '') AS Addr2,    
                  ISNULL(O.c_Address3, '') AS Addr3,    
                  ISNULL(O.c_Zip, '') AS PostCode,    
                  ISNULL(UPPER(O.Route), '') AS Route,    
                  ISNULL(RM.Descr, '') Route_Desc,    
                  O.Door AS TrfRoom,    
                  CONVERT(NVARCHAR(200), ISNULL(O.Notes, '')) Notes1,    
                  CONVERT(NVARCHAR(200), ISNULL(O.Notes2, '')) Notes2,    
                 '' CarrierKey,    
                  '' AS VehicleNo,  
                  OD.SKU,    
                  ISNULL(S.Descr, '') SkuDesc,    
                  S.SUSR3,  
                  SUM(OD.ORIGINALQTY) AS OrderQty,    
                  OD.UOM,  
                  OD.PACKKEY,  
                  Location = IsNull(INV.Loc, ''),  
                   FamilyGroup = S.BUSR10,  
                  Box = S.BUSR5,  
                  Powers = RTRIM(S.Style),  
                  CYC = S.Size,  
                  Axis = S.Measurement,  
                  Type =  O.Type,  
                  CONVERT(NVARCHAR(10),O.adddate,103) AS OHAddDate,  
                  S.RETAILSKU, ISNULL(O.OrderGroup,'') AS ORDGRP,  
                  ISNULL(@c_Retval,'')    AS Logo,  
                  S.SKUGROUP AS skugroup,  
                  CASE WHEN  S.SKUGROUP <>'Rx' THEN  S.RETAILSKU ELSE '' END AS skugrpbarcode,
                 (ROW_NUMBER() OVER (PARTITION BY O.Orderkey  ORDER BY O.LoadKey,   --CS01
                      O.OrderKey,  
                      IsNull(INV.Loc, ''),  
                      S.BUSR10,S.Size,S.Measurement,  
         CASE WHEN ISNULL(S.Style,'') <> '' AND ISNUMERIC(S.Style) = 1 THEN CAST(RTRIM(S.Style) AS DECIMAL(10,2)) ELSE 0.00 END desc,  
                      s.SKUGROUP DESC  ))  AS RowNum   ,1,1
            FROM dbo.ORDERS O WITH (NOLOCK)  INNER JOIN dbo.V_ORDERDETAIL OD WITH (NOLOCK) ON (OD.STORERKEY = O.StorerKey and OD.Orderkey = O.Orderkey)    
            INNER JOIN dbo.Sku S WITH (NOLOCK) ON (S.StorerKey = OD.StorerKey AND S.Sku = OD.Sku)    
            INNER JOIN dbo.Pack P WITH (NOLOCK) ON (P.PackKey = S.PackKey)   
            LEFT OUTER JOIN dbo.RouteMaster RM WITH (NOLOCK) ON (RM.Route = O.Route)    
  
            LEFT OUTER JOIN  
  
            (Select LLID.StorerKey, LLID.SKU, MIN(LLID.Loc) Loc  
            From [BI].[V_Inv_LotByLocByID] LLID with (nolock) Inner Join dbo.LOC L with (nolock) ON L.Loc = LLID.Loc  
            Where LLID.storerkey = @c_Storerkey  
            and L.hostwhcode = 'FWDPICK'  
            Group By LLID.StorerKey, LLID.SKU) INV ON INV.StorerKey = O.StorerKey and INV.SKU = OD.SKU  
            --WHERE (O.LoadKey LIKE '%' + @c_LoadKey or O.OrderKey LIKE '%' + @c_OrderKey)  
            WHERE (O.LoadKey = @c_LoadKey or O.OrderKey = @c_OrderKey)  
            --AND O.OrderKey = CASE WHEN ISNULL(@c_OrderKey,'') <> '' THEN @c_OrderKey ELSE O.OrderKey END
            GROUP BY O.LoadKey,   
                  O.OrderKey,  
                   O.ExternOrderKey,   
                  O.InvoiceNo,  
                   CONVERT(NVARCHAR(10),O.deliverydate,103),  
                  ISNULL(O.BillToKey, ''),    
                  ISNULL(O.c_Company, ''),    
                  ISNULL(O.c_Address1, ''),    
                  ISNULL(O.c_Address2, ''),    
                  ISNULL(O.c_Address3, ''),    
                  ISNULL(O.c_Zip, ''),    
                  ISNULL(UPPER(O.Route), '') ,    
                  ISNULL(RM.Descr, ''),    
                  O.Door,    
                  CONVERT(NVARCHAR(200), ISNULL(O.Notes, '')),    
                  CONVERT(NVARCHAR(200), ISNULL(O.Notes2, '')),    
                  OD.SKU,    
                  ISNULL(S.Descr, ''),    
                  S.SUSR3,  
                  OD.UOM,  
                  OD.PACKKEY,  
                  ISNULL(INV.Loc, ''),  
                  S.BUSR10,     
                  S.BUSR5,  
                  S.Style,  
                  S.Size,  
                  S.Measurement,  
                  O.Type,  
                  CONVERT(NVARCHAR(10),O.adddate,103),  
                  S.RETAILSKU , ISNULL(O.OrderGroup,''),  
                  S.SKUGROUP   
             ORDER BY O.LoadKey,   
                      O.OrderKey,  
                      IsNull(INV.Loc, ''),  
                      S.BUSR10,S.Size,S.Measurement,  
         CASE WHEN ISNULL(S.Style,'') <> '' AND ISNUMERIC(S.Style) = 1 THEN CAST(RTRIM(S.Style) AS DECIMAL(10,2)) ELSE 0.00 END desc,  
                      s.SKUGROUP DESC  


  --CS01 S
   SELECT @c_PrevOrderKey = N''
   SELECT @n_PgGroup = 1  
   SET    @n_TTLPAGE = 1
   SET    @c_ChgGrp  = 'N'

 DECLARE Page_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT OrderKey,RowNum   
   FROM #temp_PLIST_001 (NOLOCK)    
   WHERE LoadKey = @c_LoadKey   
   ORDER BY OrderKey    
    
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
      FROM #temp_PLIST_001
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
 
      UPDATE #temp_PLIST_001   
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



    SELECT LoadKey,
           OrderKey,
           OrderKey_Barcode,
           externorderkey,
           InvoiceNo,
           DeliveryDate,
           ConsigneeKey,
           Company,
           Addr1,
           Addr2,
           Addr3,
           PostCode,
           ROUTE,
           Route_Desc,
           TrfRoom,
           Notes1,
           Notes2,
           CarrierKey,
           VehicleNo,
           SKU,
           SkuDesc,
           SUSR3,
           OrderQty,
           UOM,
           PACKKEY,
           Location,
           FamilyGroup,
           Box,
           Powers,
           CYC,
           Axis,
           Type,
           OHAddDate,
           Retailsku,
           ORDGRP,
           Logo,
           skugroup,
           skugrpbarcode,
           RowNum,
           PgGroup,
           TTLPAGE
    FROM #temp_PLIST_001
    ORDER BY LoadKey,   
             OrderKey,  
             Location,  
             FamilyGroup,CYC,Axis,  
             CASE WHEN ISNULL(Powers,'') <> '' AND ISNUMERIC(Powers) = 1 THEN CAST(RTRIM(Powers) AS DECIMAL(10,2)) ELSE 0.00 END desc,  
             SKUGROUP DESC 
   --CS01 E
 QUIT_SP:    
    
   WHILE @@TRANCOUNT < @n_StartTCnt    
      BEGIN TRAN    
    
   /* #INCLUDE <SPTPA01_2.SQL> */    
   IF @n_continue=3  -- Error Occured - Process And Return    
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_RP_LP_PLIST_001'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         COMMIT TRAN    
      END    
   END    
    
END    

GO