SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PrintshipLabel_invoicepdf_RDT                       */
/* Creation Date: 27-OCT-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-18166 - RG-Skechers_B2C_Shopify_InvoicePDF_Creation     */
/*        :                                                             */
/* Called By: r_dw_print_shiplabel_invoicepdf_rdt                       */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 27-OCT-2021 CSCHONG  1.1   Devops Scripts combine                    */
/************************************************************************/
CREATE PROC [dbo].[isp_PrintshipLabel_invoicepdf_RDT]
            @c_externOrderKey     NVARCHAR(50)  

AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF     

   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT  
   
         , @c_moneysymbol    NVARCHAR(5)  
         , @c_VATSymbol      NVARCHAR(5)  
        -- , @n_    DATETIME  
         , @n_TTLUnitPrice   DECIMAL(10,2)
         , @n_TTLTax01       DECIMAL(10,2)
         , @n_TTLPrice       DECIMAL(10,2)
         , @c_footerRemarks  NVARCHAR(500)
  
         , @n_Leadtime        INT  
         , @n_Leadtime1       INT  
         , @n_Leadtime2       INT 
         , @n_MaxLine         INT 
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
            
   SET @n_Maxline = 17    
   SET @c_moneysymbol = N'฿'    
   SET @c_VATSymbol = 'VAT'
   SET @n_TTLUnitPrice = 0.00
   SET @n_TTLTax01     = 0.00
   SET @n_TTLPrice     = 0.00
   SET @c_footerRemarks = 'If you have any questions, please send an email to hello@skechers.co.th'
  
  
   CREATE TABLE #PRNSHIPINVRPT  
      (  Facility          NVARCHAR(5)      
      ,  DeliveryNote      NVARCHAR(20)   
     -- ,  contact1          NVARCHAR(45)   
      ,  contact2          NVARCHAR(30)   
      ,  C_phone1          NVARCHAR(45) NULL  
      ,  OHNotes2          NVARCHAR(4000)     
      ,  Orderkey          NVARCHAR(10)  
      ,  ExternOrderkey    NVARCHAR(50)   
      ,  c_city            NVARCHAR(45)     
      ,  c_state           NVARCHAR(45)    
      ,  C_Company         NVARCHAR(45)   
      ,  C_Address1        NVARCHAR(45)    
      ,  C_Address2        NVARCHAR(45)   
      ,  C_Address3        NVARCHAR(45)   
      ,  C_Address4        NVARCHAR(45)   
      ,  C_contact1        NVARCHAR(45)   
      ,  c_zip             NVARCHAR(45)   
      ,  ST_Address4       NVARCHAR(45)    
      ,  ST_city           NVARCHAR(45)     
      ,  ST_state          NVARCHAR(45)   
      ,  ST_zip            NVARCHAR(45)   
      ,  ST_country        NVARCHAR(45)   
      ,  C_phone2          NVARCHAR(45)   
    --  ,  ST_VAT            NVARCHAR(36)   
   --   ,  ST_Phone1         NVARCHAR(45)   
      ,  OHNotes           NVARCHAR(4000)   
      ,  Storerkey         NVARCHAR(15)  
      ,  Sku               NVARCHAR(20)   
      ,  SKUDescr          NVARCHAR(60)   
      ,  ODTax01           DECIMAL(10,2)  
      ,  UNITPRICE         DECIMAL(10,2)  
      ,  OIFPayableAmt     DECIMAL(10,2)   
      ,  PQTY              INT          
   --   ,  EcomOrderId       NVARCHAR(45)   
      ,  ST_Address1       NVARCHAR(45)   
      ,  ST_Address2       NVARCHAR(45)   
      ,  ST_Address3       NVARCHAR(45)   
      ,  Pageno            INT
      ,  ODLineNum         NVARCHAR(10)
  --    ,  OrderDate         DATETIME    NULL  
   --   ,  DeliveryDate      DATETIME    NULL 
    --  ,  TTLUnitPrice      FLOAT
    --  ,  TTLTax01          FLOAT
    --  ,  TTLPrice          FLOAT
    ----  ,  PTerm             NVARCHAR(20) NULL

      )  
  
  INSERT INTO #PRNSHIPINVRPT  
   (  Facility            
      ,  DeliveryNote    
   --   ,  contact1     
      ,  contact2           
      ,  C_phone1   
      ,  OHNotes2             
      ,  Orderkey            
      ,  ExternOrderkey      
      ,  c_city             
      ,  c_state        
      ,  C_Company           
      ,  C_Address1          
      ,  C_Address2    
      ,  C_Address3        
      ,  C_Address4              
      ,  C_contact1               
      ,  c_zip            
      ,  ST_Address4           
      ,  ST_city           
      ,  ST_state          
      ,  ST_zip     
      ,  ST_country       
      ,  C_phone2              
   --   ,  ST_VAT               
   --   ,  ST_Phone1            
      ,  OHNotes              
      ,  Storerkey           
      ,  Sku                 
      ,  SKUDescr            
      ,  ODTax01            
      ,  UNITPRICE             
      ,  OIFPayableAmt     
      ,  PQTY     
    --  ,  EcomOrderId   
      ,  ST_Address1        
      ,  ST_Address2         
      ,  ST_Address3          
      ,  Pageno   
      --,  OrderDate
      --,  Deliverydate  
      --,  TTLUnitPrice
      --,  TTLTax01
      --,  OHEditWho   
      --,  PTerm   
      ,  ODLineNum     
      )  
   SELECT ORDERS.Facility  
  , DeliveryNote = ISNULL(RTRIM(orders.deliverynote),'')  
 -- , contact1 = ISNULL(RTRIM(orders.c_contact1),'')  
  , contact2 = ISNULL(RTRIM(orders.c_contact2),'')    
  , C_phone1 = orders.C_phone1
  , OHNotes2= ISNULL(RTRIM(orders.notes2),'')  
  , ORDERS.Orderkey  
  , ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
  , C_City =  ISNULL(RTRIM(ORDERS.c_city),'')      
  , c_state = ISNULL(RTRIM(orders.c_state),'')
  , C_Company = ISNULL(RTRIM(ORDERS.C_Company),'')  
  , C_Address1 = ISNULL(RTRIM(ORDERS.C_Address1),'')  
  , C_Address2 = ISNULL(RTRIM(ORDERS.C_Address2),'')  
  , C_Address3 = ISNULL(RTRIM(ORDERS.C_Address3),'')  
  , C_Address4= ISNULL(RTRIM(ORDERS.C_Address4),'')  
  , C_contact1 = ISNULL(RTRIM(ORDERS.C_contact1),'')  
  , c_zip= ISNULL(RTRIM(ORDERS.c_zip),'')  
  , ST_Address4 = ISNULL(RTRIM(ST.Address4),'')
  , ST_city = ISNULL(RTRIM(ST.City),'')  
  , ST_state = ISNULL(RTRIM(ST.state),'')  
  , ST_zip = ISNULL(RTRIM(ST.zip),'')  
  , ST_country = ISNULL(RTRIM(ST.Country),'')  
  , C_phone2= ISNULL(RTRIM(ORDERS.C_phone2),'')  
--  , ST_VAT = ISNULL(RTRIM(ST.VAT),'')  
--  , ST_Phone1= ISNULL(RTRIM(ST.Phone1),'')  
  , OHNotes = ISNULL(RTRIM(ORDERS.Notes),'')  
  , ORDERDETAIL.Storerkey  
  , ORDERDETAIL.Sku AS sku   
  , SKUDescr = ISNULL(RTRIM(SKU.Descr),'')  
  , ODTax01 = SUM(CAST(ORDERDETAIL.tax01 AS decimal(10,2)))
  , UNITPRICE  = SUM(ORDERDETAIL.OriginalQty * CAST(ORDERDETAIL.unitprice AS decimal(10,2)))
  , OIFPayableAmt = OIF.PayableAmount
  , sum(ORDERDETAIL.OriginalQty)
--  , EcomOrderId = ISNULL(OIF.EcomOrderId,'')  
  , ST_Address1 = ISNULL(RTRIM(ST.Address1),'') 
  , ST_Address2 = ISNULL(RTRIM(ST.Address2),'')
  , ST_Address3 = ISNULL(RTRIM(ST.Address3),'')
  , pageno = 1 --(Row_Number() OVER (PARTITION BY ORDERS.externorderkey ORDER BY ORDERS.externorderkey,ORDERDETAIL.Sku Asc)-1)/@n_maxLine + 1   
  --, ORDERS.OrderDate  
  --, ORDERS.DeliveryDate  
  --, ExtPrice =  ORDERDETAIL.ExtendedPrice  
  --, INVAmt   = ORDERS.InvoiceAmount
  --, OHEditWho = ORDERS.EditWho
  --, Pterm = ISNULL(orders.PmtTerm,'') 
  , ODLineNum = ORDERDETAIL.orderlinenumber
 FROM ORDERS     WITH (NOLOCK) 
-- JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)  
 JOIN ORDERDETAIL (NOLOCK) ON ORDERS.orderkey = ORDERDETAIL.orderkey  
 JOIN SKU        WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)  
          AND(ORDERDETAIL.Sku = SKU.Sku)  
 --JOIN PACK       WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)   
 LEFT JOIN  STORER ST WITH (NOLOCK) ON ST.Storerkey = ORDERS.StorerKey   
 JOIN ORDERINFO OIF WITH (NOLOCK) ON OIF.orderkey = ORDERS.Orderkey
 WHERE ORDERS.externorderkey = @c_externOrderKey  
 GROUP BY ORDERS.Facility  
  , ISNULL(RTRIM(orders.deliverynote),'')   
  , ISNULL(RTRIM(orders.c_contact1),'')
  , ISNULL(RTRIM(orders.c_contact2),'')   
  , orders.C_phone1
  , ISNULL(RTRIM(orders.notes2),'')  
  , ORDERS.Orderkey  
  , ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
  , ISNULL(RTRIM(ORDERS.c_city),'')  
  , ISNULL(RTRIM(orders.c_state),'')
  , ISNULL(RTRIM(ORDERS.C_Company),'')  
  , ISNULL(RTRIM(ORDERS.C_Address1),'')  
  , ISNULL(RTRIM(ORDERS.C_Address2),'')  
  , ISNULL(RTRIM(ORDERS.C_Address3),'')  
  , ISNULL(RTRIM(ORDERS.C_Address4),'')  
  , ISNULL(RTRIM(ORDERS.C_contact1),'')  
  , ISNULL(RTRIM(ORDERS.c_zip),'')  
  , ISNULL(RTRIM(ST.Address4),'')
  , ISNULL(RTRIM(ST.city),'')
  , ISNULL(RTRIM(ST.state),'')  
  , ISNULL(RTRIM(ST.zip),'')  
  , ISNULL(RTRIM(ST.Country),'')  
  , ISNULL(RTRIM(ORDERS.C_phone2),'')  
 -- , ISNULL(RTRIM(ST.VAT),'') 
 -- , ISNULL(RTRIM(ST.Phone1),'')  
  , ISNULL(RTRIM(ORDERS.Notes),'')  
  , ORDERDETAIL.Storerkey  
  , ISNULL(RTRIM(SKU.Descr),'')  
 -- , ISNULL(PACK.CaseCnt,0)  
  , OIF.PayableAmount 
 -- , ISNULL(OIF.EcomOrderId,'')  
  , ORDERDETAIL.Sku 
  ,ISNULL(RTRIM(ST.Address1),'') 
  ,ISNULL(RTRIM(ST.Address2),'') 
  ,ISNULL(RTRIM(ST.Address3),'')  --,(ORDERDETAIL.OriginalQty)
 -- ,ORDERDETAIL.unitprice,ORDERDETAIL.ExtendedPrice,ORDERS.InvoiceAmount,ORDERS.EditWho,ISNULL(orders.PmtTerm,'')   
  --, PACK.PACKUOM1,PACK.PACKUOM2,PACK.PACKUOM3,PACK.PACKUOM4
 -- ,PACK.CASECNT,PACK.INNERPACK,PACK.qty,PACK.Pallet
  ,ORDERDETAIL.orderlinenumber
  
 
   SELECT @n_TTLTax01 = SUM(ODTax01)
       --  ,@n_TTLPrice = SUM(
   FROM #PRNSHIPINVRPT
  
   SELECT   
         Facility            
      ,  DeliveryNote    
    --  ,  contact1     
      ,  contact2           
    --  ,  ShipDate   
      ,  C_phone1--FORMAT(cast(oifudf03 as decimal(10,2)),'##,###,##0.00','en-US') as oifudf03   --CS01
    --  ,  BuyerPO             
      ,  Orderkey            
      ,  ExternOrderkey      
      ,  c_city             
      ,  c_state       
      ,  C_Company           
      ,  C_Address1          
      ,  C_Address2    
      ,  C_Address3        
      ,  C_Address4              
      ,  C_contact1               
      ,  c_zip            
      ,  ST_Address4           
      ,  ST_city           
      ,  ST_state          
      ,  ST_zip     
      ,  ST_country       
      ,  C_phone2                 
     -- ,  ST_VAT               
   --   ,  ST_Phone1            
      ,  OHNotes              
      ,  Storerkey           
      ,  Sku                 
      ,  SKUDescr            
      ,  ODTax01            
      ,  UnitPrice          
      ,  OIFPayableAmt    
      ,  PQTY       
   --   ,  EcomOrderId   
      ,  ST_Address1        
      ,  ST_Address2         
      ,  ST_Address3          
      ,  Pageno  
      ,  OHNotes2  
      ,  @n_TTLTax01 AS TTLTAX01 
      ,  @c_moneysymbol AS moneysymbol
      ,  @c_VATSymbol AS VATSymbol
      ,  @c_footerRemarks AS FooterRemarks
      ,  ODLineNum   
      , @c_moneysymbol + SPACE(1) + CAST(ODTax01 AS NVARCHAR(10))+SPACE(1) + @c_VATSymbol AS msodtax1  
      , @c_moneysymbol + SPACE(1) + CAST(UNITPRICE AS NVARCHAR(10)) AS msunitprice
      , @c_moneysymbol + SPACE(1) + CAST(OIFPayableAmt AS NVARCHAR(10)) AS msOIFPayableAmt
      , @c_moneysymbol + SPACE(1) + CAST(@n_TTLTax01 AS NVARCHAR(10)) AS msTTLTax01
      , @c_moneysymbol + SPACE(1) + DeliveryNote AS msDeliveryNote
      FROM #PRNSHIPINVRPT     
      ORDER BY Orderkey  
            ,  ODLineNum
            ,  Storerkey       
            ,  Sku  
  
QUIT:  
  
END -- procedure  


GO