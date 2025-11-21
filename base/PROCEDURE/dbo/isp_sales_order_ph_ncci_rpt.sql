SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_sales_order_ph_ncci_rpt                             */
/* Creation Date: 22-SEP-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-15198 - PH_Novateur_SalesOrder_RCM_CR                   */
/*        :                                                             */
/* Called By: r_dw_sales_order_ph_ncci_rpt                              */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 05-NOV-2020 CSCHONG  1.1   WMS-15198 revised field logic (CS01)      */
/************************************************************************/
CREATE PROC [dbo].[isp_sales_order_ph_ncci_rpt]  
            @c_OrderKey     NVARCHAR(10)  
           ,@c_RePrint      NVARCHAR(5) = 'N'
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF     
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT  
   
       --  , @c_Orderkey        NVARCHAR(10)  
         , @c_Consigneekey    NVARCHAR(15)  
         , @c_TransMehtod     NVARCHAR(30)  
         , @d_ShipDate4ETA    DATETIME  
         , @d_ETA             DATETIME  
         , @c_Rptsku          NVARCHAR(5)    
  
         , @n_Leadtime        INT  
         , @n_Leadtime1       INT  
         , @n_Leadtime2       INT 
         , @n_MaxLine         INT 
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
     
   SET @c_Rptsku = ''            
   SET @n_Maxline = 17        
  
  
   CREATE TABLE #SONCCIRPT  
      (  Facility          NVARCHAR(5)      
      ,  DeliveryNote      NVARCHAR(20)     
      ,  OHUDF02           NVARCHAR(30)   
      ,  shipperkey        NVARCHAR(30)   
     -- ,  ShipDate          DATETIME    NULL  
      ,  OIFUDF03          NVARCHAR(30) NULL  
      ,  OHNotes2          NVARCHAR(4000)     
      ,  Orderkey          NVARCHAR(10)  
      ,  ExternOrderkey    NVARCHAR(50)
      ,  ExternPOkey       NVARCHAR(20)   
      --,  OrderDate         DATETIME    NULL  
      --,  DeliveryDate      DATETIME    NULL  
      ,  OHUDF04           NVARCHAR(50)    
      ,  C_Company         NVARCHAR(45)   
      ,  C_Address1        NVARCHAR(45)    
      ,  C_Address2        NVARCHAR(45)   
      ,  C_Address3        NVARCHAR(45)   
      ,  C_Address4        NVARCHAR(45)   
      ,  C_contact1        NVARCHAR(45)   
      ,  c_vat             NVARCHAR(30)   
      ,  Salesman          NVARCHAR(30)    
      ,  UOM               NVARCHAR(10)     
      ,  B_Address1        NVARCHAR(45)   
      ,  B_Address2        NVARCHAR(45)   
      ,  B_Address3        NVARCHAR(45)   
      ,  B_Address4        NVARCHAR(45)   
      ,  ST_VAT            NVARCHAR(36)   
      ,  ST_Phone1         NVARCHAR(45)   
      ,  OHNotes           NVARCHAR(4000)   
      ,  Storerkey         NVARCHAR(15)  
      ,  Sku               NVARCHAR(20)   
      ,  SKUDescr          NVARCHAR(60)   
      ,  UOMQTY            FLOAT  
      ,  UNITPRICE         FLOAT  
      ,  ODUDF02           FLOAT   
      ,  PQTY              INT      
      ,  EcomOrderId       NVARCHAR(45)   
      ,  ST_Address1       NVARCHAR(45)   
      ,  ST_Address2       NVARCHAR(45)   
      ,  ST_Address3       NVARCHAR(45)   
      ,  Pageno            INT
      ,  OrderDate         DATETIME    NULL  
      ,  DeliveryDate      DATETIME    NULL 
      ,  ExtPrice          FLOAT
      ,  InvAmt            FLOAT
      ,  OHEditWho         NVARCHAR(50)
      ,  PTerm             NVARCHAR(20) NULL
      ,  ODLineNum         NVARCHAR(10)
      )  
  
  INSERT INTO #SONCCIRPT  
   (  Facility            
      ,  DeliveryNote    
      ,  OHUDF02     
      ,  shipperkey           
    --  ,  ShipDate   
      ,  OIFUDF03   
      ,  OHNotes2             
      ,  Orderkey            
      ,  ExternOrderkey      
      ,  ExternPOkey         
      --,  OrderDate           
      --,  DeliveryDate        
      ,  OHUDF04        
      ,  C_Company           
      ,  C_Address1          
      ,  C_Address2    
      ,  C_Address3        
      ,  C_Address4              
      ,  C_contact1               
      ,  c_vat            
      ,  Salesman           
      ,  UOM           
      ,  B_Address1          
      ,  B_Address2     
      ,  B_Address3       
      ,  B_Address4              
      ,  ST_VAT               
      ,  ST_Phone1            
      ,  OHNotes              
      ,  Storerkey           
      ,  Sku                 
      ,  SKUDescr            
      ,  UOMQTY            
      ,  UNITPRICE             
      ,  ODUDF02     
      ,  PQTY     
      ,  EcomOrderId   
      ,  ST_Address1        
      ,  ST_Address2         
      ,  ST_Address3          
      ,  Pageno   
      ,  OrderDate
      ,  Deliverydate  
      ,  ExtPrice
      ,  INVAmt
      ,  OHEditWho   
      ,  PTerm   
      ,  ODLineNum     
      )  
   SELECT ORDERS.Facility  
  , DeliveryNote = ISNULL(RTRIM(orders.deliverynote),'')  
  , OHUDF06 = ISNULL(RTRIM(orders.userdefine02),'')  
  , shipperkey = ISNULL(RTRIM(orders.shipperkey),'')  
  --    , ShipDate = MBOL.ShipDate    
  , OIFUDF03 = CASE WHEN ISNUMERIC(OIF.OrderInfo03) = 1 THEN CAST(CAST(OIF.OrderInfo03 as decimal(10,2)) as nvarchar(20)) ELSE ISNULL(OIF.OrderInfo03,'')  END  --CS01
  , OHNotes2= ISNULL(RTRIM(orders.notes2),'')  
  , ORDERS.Orderkey  
  , ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
  , ExternPOkey =  ISNULL(RTRIM(ORDERS.ExternPOkey),'')      
  --, ORDERS.OrderDate  
  --, ORDERS.DeliveryDate  
  , OHUDF04 = ISNULL(RTRIM(orders.userdefine05),'')
  , C_Company = ISNULL(RTRIM(ORDERS.C_Company),'')  
  , C_Address1 = ISNULL(RTRIM(ORDERS.C_Address1),'')  
  , C_Address2 = ISNULL(RTRIM(ORDERS.C_Address2),'')  
  , C_Address3 = ISNULL(RTRIM(ORDERS.C_Address3),'')  
  , C_Address4= ISNULL(RTRIM(ORDERS.C_Address4),'')  
  , C_contact1 = ISNULL(RTRIM(ORDERS.C_contact1),'')  
  , c_vat= ISNULL(RTRIM(ORDERS.c_vat),'')  
  , Salesman = ISNULL(RTRIM(ORDERS.Salesman),'')  
  , UOM = ISNULL(RTRIM(ORDERDETAIL.UOM),'')  
  , B_Address1 = ISNULL(RTRIM(ORDERS.B_Address1),'')  
  , B_Address2 = ISNULL(RTRIM(ORDERS.B_Address2),'')  
  , B_Address3 = ISNULL(RTRIM(ORDERS.B_Address3),'')  
  , B_Address4= ISNULL(RTRIM(ORDERS.B_Address4),'')  
  , ST_VAT = ISNULL(RTRIM(ST.VAT),'')  
  , ST_Phone1= ISNULL(RTRIM(ST.Phone1),'')  
  , OHNotes = ISNULL(RTRIM(ORDERS.Notes),'')  
  , ORDERDETAIL.Storerkey  
  , ORDERDETAIL.Sku AS sku   
  , SKUDescr = ISNULL(RTRIM(SKU.Descr),'')  
  , UOMQty = CASE WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'') = PACK.PACKUOM1 THEN (ORDERDETAIL.OriginalQty)/NULLIF(PACK.CASECNT,0) 
           WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'')= PACK.PACKUOM2 THEN (ORDERDETAIL.OriginalQty)/NULLIF(PACK.INNERPACK,0)  
           WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'') = PACK.PACKUOM3 THEN (ORDERDETAIL.OriginalQty)/NULLIF(PACK.Qty,0) 
           WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'') = PACK.PACKUOM4 THEN (ORDERDETAIL.OriginalQty)/NULLIF(PACK.Pallet,0) ELSE 0 END   
  , UNITPRICE  = ORDERDETAIL.unitprice
  , ODUDF02 = CASE WHEN ISNUMERIC(ISNULL(RTRIM(ORDERDETAIL.userdefine02),'')) = 1 THEN CAST(ISNULL(RTRIM(ORDERDETAIL.userdefine02),'0') AS FLOAT) ELSE 1 END 
  , (ORDERDETAIL.OriginalQty)
  , EcomOrderId = ISNULL(OIF.EcomOrderId,'')  
  , ST_Address1 = ISNULL(RTRIM(ST.Address1),'') 
  , ST_Address2 = ISNULL(RTRIM(ST.Address2),'')
  , ST_Address3 = ISNULL(RTRIM(ST.Address3),'')
  , pageno = (Row_Number() OVER (PARTITION BY ORDERS.Orderkey ORDER BY ORDERS.Orderkey,ORDERDETAIL.Sku Asc)-1)/@n_maxLine + 1   
  , ORDERS.OrderDate  
  , ORDERS.DeliveryDate  
  , ExtPrice =  ORDERDETAIL.ExtendedPrice  
  , INVAmt   = ORDERS.InvoiceAmount
  , OHEditWho = ORDERS.EditWho
  , Pterm = ISNULL(orders.PmtTerm,'') 
  , ODLineNum = ORDERDETAIL.orderlinenumber
 FROM ORDERS     WITH (NOLOCK) 
 JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)  
 JOIN ORDERDETAIL (NOLOCK) ON ORDERS.orderkey = ORDERDETAIL.orderkey 
      --ON PICKDETAIL.orderkey = ORDERDETAIL.orderkey and
      --   PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber 
 --JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot= LOTATTRIBUTE.Lot)  
 JOIN SKU        WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)  
          AND(ORDERDETAIL.Sku = SKU.Sku)  
 JOIN PACK       WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)   
 LEFT JOIN  STORER ST WITH (NOLOCK) ON ST.Storerkey = ORDERS.StorerKey   
 JOIN ORDERINFO OIF WITH (NOLOCK) ON OIF.orderkey = ORDERS.Orderkey
 JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORDERS.Orderkey
 WHERE ORDERS.Orderkey = @c_Orderkey  
 --AND PICKDETAIL.Status >= '5'  
AND PH.ManifestPrinted  = CASE WHEN @c_Reprint = 'Y' THEN 'Y' ELSE '0' END
 GROUP BY ORDERS.Facility  
  , ISNULL(RTRIM(orders.deliverynote),'')   
  , ISNULL(RTRIM(orders.userdefine02),'')
  , ISNULL(RTRIM(orders.shipperkey),'')  
    --  , MBOL.ShipDate   
  , CASE WHEN ISNUMERIC(OIF.OrderInfo03) = 1 THEN CAST(CAST(OIF.OrderInfo03 as decimal(10,2)) as nvarchar(20)) ELSE ISNULL(OIF.OrderInfo03,'')  END   --CS01
  , ISNULL(RTRIM(orders.notes2),'')  
  , ORDERS.Orderkey  
  , ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
  , ISNULL(RTRIM(ORDERS.ExternPOkey),'')  
  , ORDERS.OrderDate  
  , ORDERS.DeliveryDate  
  , ISNULL(RTRIM(orders.userdefine05),'')
  , ISNULL(RTRIM(ORDERS.C_Company),'')  
  , ISNULL(RTRIM(ORDERS.C_Address1),'')  
  , ISNULL(RTRIM(ORDERS.C_Address2),'')  
  , ISNULL(RTRIM(ORDERS.C_Address3),'')  
  , ISNULL(RTRIM(ORDERS.C_Address4),'')  
  , ISNULL(RTRIM(ORDERS.C_contact1),'')  
  , ISNULL(RTRIM(ORDERS.c_vat),'')  
  , ISNULL(RTRIM(ORDERS.Salesman),'')  
  , ISNULL(RTRIM(ORDERDETAIL.UOM),'')
  , ISNULL(RTRIM(ORDERS.B_Address1),'')  
  , ISNULL(RTRIM(ORDERS.B_Address2),'')  
  , ISNULL(RTRIM(ORDERS.B_Address3),'')  
  , ISNULL(RTRIM(ORDERS.B_Address4),'')  
  , ISNULL(RTRIM(ST.VAT),'') 
  , ISNULL(RTRIM(ST.Phone1),'')  
  , ISNULL(RTRIM(ORDERS.Notes),'')  
  , ORDERDETAIL.Storerkey  
  --, PICKDETAIL.Sku  
  , ISNULL(RTRIM(SKU.Descr),'')  
  , ISNULL(PACK.CaseCnt,0)  
  , CASE WHEN ISNUMERIC(ISNULL(RTRIM(ORDERDETAIL.userdefine02),'')) = 1 THEN CAST(ISNULL(RTRIM(ORDERDETAIL.userdefine02),'0') AS FLOAT) ELSE 1 END 
  , ISNULL(OIF.EcomOrderId,'')  
  , ORDERDETAIL.Sku 
  ,ISNULL(RTRIM(ST.Address1),'') 
  ,ISNULL(RTRIM(ST.Address2),'') 
  ,ISNULL(RTRIM(ST.Address3),'')  ,(ORDERDETAIL.OriginalQty)
  ,ORDERDETAIL.unitprice,ORDERDETAIL.ExtendedPrice,ORDERS.InvoiceAmount,ORDERS.EditWho,ISNULL(orders.PmtTerm,'')   
  , PACK.PACKUOM1,PACK.PACKUOM2,PACK.PACKUOM3,PACK.PACKUOM4
  ,PACK.CASECNT,PACK.INNERPACK,PACK.qty,PACK.Pallet,ORDERDETAIL.orderlinenumber
  
 
  
   SELECT   
         Facility            
      ,  DeliveryNote    
      ,  OHUDF02     
      ,  shipperkey           
    --  ,  ShipDate   
      ,  FORMAT(cast(oifudf03 as decimal(10,2)),'##,###,##0.00','en-US') as oifudf03   --CS01
    --  ,  BuyerPO             
      ,  Orderkey            
      ,  ExternOrderkey      
      ,  ExternPOkey             
      ,  OHUDF04       
      ,  C_Company           
      ,  C_Address1          
      ,  C_Address2    
      ,  C_Address3        
      ,  C_Address4              
      ,  C_contact1               
      ,  c_vat            
      ,  Salesman           
      ,  UOM           
      ,  B_Address1          
      ,  B_Address2     
      ,  B_Address3       
      ,  B_Address4              
      ,  ST_VAT               
      ,  ST_Phone1            
      ,  OHNotes              
      ,  Storerkey           
      ,  Sku                 
      ,  SKUDescr            
      ,  UOMQTY            
      ,  UnitPrice           
      ,  ODUDF02    
      ,  PQTY       
      ,  EcomOrderId   
      ,  ST_Address1        
      ,  ST_Address2         
      ,  ST_Address3          
      ,  Pageno  
      ,  OHNotes2  
      ,  Orderdate 
      ,  DeliveryDate
      ,  ExtPrice
      ,  InvAmt
      ,  OHEditWho
      ,  Pterm
      ,  ODLineNum
      FROM #SONCCIRPT     
      ORDER BY Orderkey  
            ,  ODLineNum
            ,  Storerkey       
            ,  Sku  
  
QUIT:  
  
END -- procedure  


GO