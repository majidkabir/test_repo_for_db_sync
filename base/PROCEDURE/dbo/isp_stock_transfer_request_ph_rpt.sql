SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_stock_transfer_request_ph_rpt                       */
/* Creation Date: 23-SEP-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-15199 - PH_Novateur_StockTransferRequest_RCM_CR         */
/*        :                                                             */
/* Called By: r_stock_transfer_request_ph_rpt                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-11-13  WLChooi  v1.1  WMS-15688 - Modify Qty Column Logic (WL01)*/
/* 2020-11-25  WLChooi  v1.2  WMS-15747 - Modify From & To Whse (WL02)  */
/************************************************************************/
CREATE PROC [dbo].[isp_stock_transfer_request_ph_rpt]  
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
         , @c_Rptsku          NVARCHAR(5)    
         , @n_MaxLine         INT 
         , @n_TTLUOMQTY       INT
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
     
   SET @c_Rptsku = ''            
   SET @n_Maxline = 25        
   SET @n_TTLUOMQTY = 1 
  
   CREATE TABLE #STQRPT  
      (  Facility          NVARCHAR(5)      
    --  ,  DeliveryNote      NVARCHAR(20)     
      ,  OHUDF02           NVARCHAR(30)   
     -- ,  shipperkey        NVARCHAR(30)   
     -- ,  ShipDate          DATETIME    NULL  
     -- ,  OIFUDF03          NVARCHAR(30) NULL  
    --  ,  OHNotes2          NVARCHAR(4000)     
      ,  Orderkey          NVARCHAR(10)  
      ,  ExternOrderkey    NVARCHAR(50)
    --  ,  ExternPOkey       NVARCHAR(20)   
      --,  OrderDate         DATETIME    NULL  
      --,  DeliveryDate      DATETIME    NULL  
      ,  OHUDF01           NVARCHAR(50)    
      ,  C_Company         NVARCHAR(45)   
      ,  C_Address1        NVARCHAR(45)    
      ,  C_Address2        NVARCHAR(45)   
      ,  C_Address3        NVARCHAR(45)   
      ,  C_Address4        NVARCHAR(45)   
      ,  C_contact1        NVARCHAR(45)   
      ,  c_vat             NVARCHAR(30)   
    --  ,  Salesman          NVARCHAR(30)    
      ,  UOM               NVARCHAR(10)     
      --,  B_Address1        NVARCHAR(45)   
      --,  B_Address2        NVARCHAR(45)   
      --,  B_Address3        NVARCHAR(45)   
      --,  B_Address4        NVARCHAR(45)   
      ,  ST_VAT            NVARCHAR(36)   
      ,  ST_Phone1         NVARCHAR(45)   
      ,  OHNotes           NVARCHAR(4000)   
      ,  Storerkey         NVARCHAR(15)  
      ,  Sku               NVARCHAR(20)   
      ,  SKUDescr          NVARCHAR(60)   
      ,  UOMQTY            INT  
    --  ,  UNITPRICE         FLOAT  
   --   ,  ODUDF02           INT   
      ,  PQTY              INT      
    --  ,  EcomOrderId       NVARCHAR(45)   
      ,  ST_Address1       NVARCHAR(45)   
      ,  ST_Address2       NVARCHAR(45)   
      ,  ST_Address3       NVARCHAR(45)   
      ,  Pageno            INT
      ,  OrderDate         DATETIME    NULL  
      ,  DeliveryDate      DATETIME    NULL 
      --,  ExtPrice          FLOAT
      --,  InvAmt            FLOAT
      --,  OHEditWho         NVARCHAR(50)
      --,  PTerm             NVARCHAR(20) NULL
      ,  ODLineNum         NVARCHAR(10)
      ,  TTLUOMQTY          INT
      )  


  --CREATE TABLE #TMPSNSTQ (
  -- Storerkey  NVARCHAR(20),
  -- Orderkey   NVARCHAR(20),
  -- SKU        NVARCHAR(20),
  -- SN         NVARCHAR(30)
  --)

  
  INSERT INTO #STQRPT  
   (  Facility            
    --  ,  DeliveryNote    
      ,  OHUDF02     
     -- ,  shipperkey           
    --  ,  ShipDate   
      --,  OIFUDF03   
      --,  OHNotes2             
      ,  Orderkey            
      ,  ExternOrderkey      
     -- ,  ExternPOkey         
      --,  OrderDate           
      --,  DeliveryDate        
      ,  OHUDF01       
      ,  C_Company           
      ,  C_Address1          
      ,  C_Address2    
      ,  C_Address3        
      ,  C_Address4              
      ,  C_contact1               
      ,  c_vat            
    --  ,  Salesman           
      ,  UOM           
      --,  B_Address1          
      --,  B_Address2     
      --,  B_Address3       
      --,  B_Address4              
      ,  ST_VAT               
      ,  ST_Phone1            
      ,  OHNotes              
      ,  Storerkey           
      ,  Sku                 
      ,  SKUDescr            
      ,  UOMQTY            
     -- ,  UNITPRICE             
     -- ,  ODUDF02     
      ,  PQTY     
    --  ,  EcomOrderId   
      ,  ST_Address1        
      ,  ST_Address2         
      ,  ST_Address3          
      ,  Pageno   
      ,  OrderDate
      ,  Deliverydate  
      --,  ExtPrice
      --,  INVAmt
      --,  OHEditWho   
      --,  PTerm   
      ,  ODLineNum     
      )  
   SELECT ORDERS.Facility  
  --, DeliveryNote = ISNULL(RTRIM(orders.deliverynote),'')  
  , OHUDF02 = ISNULL(RTRIM(orders.userdefine03),'')   --WL02  
 -- , shipperkey = ISNULL(RTRIM(orders.shipperkey),'')  
  --    , ShipDate = MBOL.ShipDate    
  --, OIFUDF03 = ISNULL(OIF.OrderInfo03,'')  
  --, OHNotes2= ISNULL(RTRIM(orders.notes2),'')  
  , ORDERS.Orderkey  
  , ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
 -- , ExternPOkey =  ISNULL(RTRIM(ORDERS.ExternPOkey),'')      
  --, ORDERS.OrderDate  
  --, ORDERS.DeliveryDate  
  , OHUDF01 = ISNULL(RTRIM(orders.userdefine02),'')   --WL02  
  , C_Company = ISNULL(RTRIM(ORDERS.C_Company),'')  
  , C_Address1 = ISNULL(RTRIM(ORDERS.C_Address1),'')  
  , C_Address2 = ISNULL(RTRIM(ORDERS.C_Address2),'')  
  , C_Address3 = ISNULL(RTRIM(ORDERS.C_Address3),'')  
  , C_Address4= ISNULL(RTRIM(ORDERS.C_Address4),'')  
  , C_contact1 = ISNULL(RTRIM(ORDERS.C_contact1),'')  
  , c_vat= ISNULL(RTRIM(ORDERS.c_vat),'')  
  --, Salesman = ISNULL(RTRIM(ORDERS.Salesman),'')  
  , UOM = ISNULL(RTRIM(ORDERDETAIL.UOM),'')  
  --, B_Address1 = ISNULL(RTRIM(ORDERS.B_Address1),'')  
  --, B_Address2 = ISNULL(RTRIM(ORDERS.B_Address2),'')  
  --, B_Address3 = ISNULL(RTRIM(ORDERS.B_Address3),'')  
  --, B_Address4= ISNULL(RTRIM(ORDERS.B_Address4),'')  
  , ST_VAT = ISNULL(RTRIM(ST.VAT),'')  
  , ST_Phone1= ISNULL(RTRIM(ST.Phone1),'')  
  , OHNotes = ISNULL(RTRIM(ORDERS.Notes),'')  
  , ORDERDETAIL.Storerkey  
  , ORDERDETAIL.Sku AS sku   
  , SKUDescr = ISNULL(RTRIM(SKU.Descr),'')  
  , UOMQty = CASE WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'') = PACK.PACKUOM1 THEN (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty)/NULLIF(PACK.CASECNT,0)      --WL01
           WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'')= PACK.PACKUOM2 THEN (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty)/NULLIF(PACK.INNERPACK,0)            --WL01  
           WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'') = PACK.PACKUOM3 THEN (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty)/NULLIF(PACK.Qty,0)                 --WL01 
           WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'') = PACK.PACKUOM4 THEN (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty)/NULLIF(PACK.Pallet,0) ELSE 0 END   --WL01   
 -- , UNITPRICE  = ORDERDETAIL.unitprice
  --, ODUDF02 = CASE WHEN ISNUMERIC(ISNULL(RTRIM(ORDERDETAIL.userdefine02),'')) = 1 THEN CAST(ISNULL(RTRIM(ORDERDETAIL.userdefine02),'0') AS INT) ELSE 1 END 
  , SUM(ORDERDETAIL.OriginalQty)
 -- , EcomOrderId = ISNULL(OIF.EcomOrderId,'')  
  , ST_Address1 = ISNULL(RTRIM(ST.Address1),'') 
  , ST_Address2 = ISNULL(RTRIM(ST.Address2),'')
  , ST_Address3 = ISNULL(RTRIM(ST.Address3),'')
  , pageno = 1--(Row_Number() OVER (PARTITION BY ORDERS.Orderkey ORDER BY ORDERS.Orderkey,ORDERDETAIL.Sku Asc)-1)/@n_maxLine + 1   
  , ORDERS.OrderDate  
  , ORDERS.DeliveryDate  
  --, ExtPrice =  ORDERDETAIL.ExtendedPrice  
  --, INVAmt   = ORDERS.InvoiceAmount
  --, OHEditWho = ORDERS.EditWho
  --, Pterm = ISNULL(orders.PmtTerm,'') 
  , ODLineNum = ORDERDETAIL.orderlinenumber
 FROM ORDERS     WITH (NOLOCK) 
 --JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)  
 JOIN ORDERDETAIL (NOLOCK) ON ORDERS.orderkey = ORDERDETAIL.orderkey 
      --ON PICKDETAIL.orderkey = ORDERDETAIL.orderkey and
      --   PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber 
 --JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot= LOTATTRIBUTE.Lot)  
 JOIN SKU        WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)  
          AND(ORDERDETAIL.Sku = SKU.Sku)  
 JOIN PACK       WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)   
 LEFT JOIN  STORER ST WITH (NOLOCK) ON ST.Storerkey = ORDERS.StorerKey   
 --JOIN ORDERINFO OIF WITH (NOLOCK) ON OIF.orderkey = ORDERS.Orderkey
 JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORDERS.Orderkey
 WHERE ORDERS.Orderkey = @c_Orderkey  
 --AND PICKDETAIL.Status >= '5'  
AND PH.ManifestPrinted  = CASE WHEN @c_Reprint = 'Y' THEN 'Y' ELSE '0' END
 GROUP BY ORDERS.Facility  
--  , ISNULL(RTRIM(orders.deliverynote),'')   
  , ISNULL(RTRIM(orders.userdefine02),'')
 -- , ISNULL(RTRIM(orders.shipperkey),'')  
    --  , MBOL.ShipDate   
  --, ISNULL(OIF.OrderInfo03,'')   
  --, ISNULL(RTRIM(orders.notes2),'')  
  , ORDERS.Orderkey  
  , ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
 -- , ISNULL(RTRIM(ORDERS.ExternPOkey),'')  
  , ORDERS.OrderDate  
  , ORDERS.DeliveryDate  
  , ISNULL(RTRIM(orders.userdefine03),'')   --WL02  
  , ISNULL(RTRIM(ORDERS.C_Company),'')  
  , ISNULL(RTRIM(ORDERS.C_Address1),'')  
  , ISNULL(RTRIM(ORDERS.C_Address2),'')  
  , ISNULL(RTRIM(ORDERS.C_Address3),'')  
  , ISNULL(RTRIM(ORDERS.C_Address4),'')  
  , ISNULL(RTRIM(ORDERS.C_contact1),'')  
  , ISNULL(RTRIM(ORDERS.c_vat),'')  
--  , ISNULL(RTRIM(ORDERS.Salesman),'')  
  , ISNULL(RTRIM(ORDERDETAIL.UOM),'')
  --, ISNULL(RTRIM(ORDERS.B_Address1),'')  
  --, ISNULL(RTRIM(ORDERS.B_Address2),'')  
  --, ISNULL(RTRIM(ORDERS.B_Address3),'')  
  --, ISNULL(RTRIM(ORDERS.B_Address4),'')  
  , ISNULL(RTRIM(ST.VAT),'') 
  , ISNULL(RTRIM(ST.Phone1),'')  
  , ISNULL(RTRIM(ORDERS.Notes),'')  
  , ORDERDETAIL.Storerkey  
  --, PICKDETAIL.Sku  
  , ISNULL(RTRIM(SKU.Descr),'')  
  , ISNULL(PACK.CaseCnt,0)  
 -- , CASE WHEN ISNUMERIC(ISNULL(RTRIM(ORDERDETAIL.userdefine02),'')) = 1 THEN CAST(ISNULL(RTRIM(ORDERDETAIL.userdefine02),'0') AS INT) ELSE 1 END 
 -- , ISNULL(OIF.EcomOrderId,'')  
  , ORDERDETAIL.Sku 
  ,ISNULL(RTRIM(ST.Address1),'') 
  ,ISNULL(RTRIM(ST.Address2),'') 
  ,ISNULL(RTRIM(ST.Address3),'')  
  ,(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty)   --WL01
  --,ORDERDETAIL.unitprice,ORDERDETAIL.ExtendedPrice,ORDERS.InvoiceAmount,ORDERS.EditWho,ISNULL(orders.PmtTerm,'')   
  , PACK.PACKUOM1,PACK.PACKUOM2,PACK.PACKUOM3,PACK.PACKUOM4
  ,PACK.CASECNT,PACK.INNERPACK,PACK.qty,PACK.Pallet,ORDERDETAIL.orderlinenumber

--select * from #STQRPT
--select * from #TMPSNSTQ
  
  IF NOT EXISTS (Select 1 FROM #STQRPT WHERE Orderkey = @c_orderkey)
  BEGIN
     GOTO QUIT
  END
  --ELSE
  --BEGIN
   
  --  INSERT INTO #TMPSNSTQ (storerkey,orderkey,sku,SN)
  --  SELECT storerkey,orderkey,sku,serialno
  --  FROM serialno WITH (NOLOCK)
  --  WHERE Orderkey = @c_orderkey

  --END

      --SELECT DISTINCT STQ.Orderkey,STQ.sku,SN.serialno,(select sum(stq1.uomqty) FROM #STQRPT   STQ1 where orderkey = @c_orderkey)
      -- ,(Row_Number() OVER (PARTITION BY STQ.Orderkey ORDER BY STQ.Orderkey,STQ.Sku,SN.serialno Asc)-1)/@n_maxLine + 1 
      --FROM #STQRPT   STQ
      --LEFT JOIN serialno SN WITH (NOLOCK)  ON SN.Orderkey = STQ.Orderkey AND SN.sku = STQ.sku AND SN.Storerkey = STQ.Storerkey
      --WHERE STQ.Orderkey = @c_orderkey 
      --group by STQ.Orderkey,STQ.sku,SN.serialno
  
   SELECT   
         Facility            
      --,  DeliveryNote    
      ,  STQ.OHUDF02     
   --   ,  shipperkey           
    --  ,  ShipDate   
   --   ,  oifudf03   
    --  ,  BuyerPO             
      ,  STQ.Orderkey            
      ,  STQ.ExternOrderkey      
  --    ,  ExternPOkey             
      ,  STQ.OHUDF01      
      ,  STQ.C_Company           
      ,  STQ.C_Address1          
      ,  STQ.C_Address2    
      ,  STQ.C_Address3        
      ,  STQ.C_Address4              
      ,  STQ.C_contact1               
      ,  STQ.c_vat            
  --    ,  Salesman           
      ,  STQ.UOM           
      --,  B_Address1          
      --,  B_Address2     
      --,  B_Address3       
      --,  B_Address4              
      ,  STQ.ST_VAT               
      ,  STQ.ST_Phone1            
      ,  STQ.OHNotes              
      ,  STQ.Storerkey           
      ,  STQ.Sku                 
      ,  STQ.SKUDescr            
      ,  STQ.UOMQTY            
    --  ,  UnitPrice           
   --   ,  ODUDF02   
      ,  STQ.PQTY       
    --  ,  EcomOrderId   
      ,  STQ.ST_Address1        
      ,  STQ.ST_Address2         
      ,  STQ.ST_Address3          
      ,  (Row_Number() OVER (PARTITION BY STQ.Orderkey ORDER BY STQ.Orderkey,STQ.ODLineNum,STQ.Sku,SN.serialno Asc)-1)/@n_maxLine + 1   as Pageno  
   --   ,  OHNotes2  
      ,  STQ.Orderdate 
      ,  STQ.DeliveryDate
      --,  ExtPrice
      --,  InvAmt
      --,  OHEditWho
      --,  Pterm
      ,  STQ.ODLineNum
      ,  ISNULL(SN.serialno,'') AS SN
      ,(select sum(stq1.uomqty) FROM #STQRPT   STQ1 where orderkey = @c_orderkey) as TTLUOMQTY
      FROM #STQRPT   STQ
      --LEFT JOIN   #TMPSNSTQ SN ON SN.Orderkey = STQ.Orderkey AND SN.sku = STQ.sku AND SN.Storerkey = STQ.Storerkey
      LEFT JOIN serialno SN WITH (NOLOCK)  ON SN.Orderkey = STQ.Orderkey AND SN.sku = STQ.sku AND SN.Storerkey = STQ.Storerkey  
      WHERE STQ.Orderkey = @c_orderkey
      ORDER BY STQ.Orderkey  
            ,  STQ.ODLineNum
            ,  STQ.Storerkey       
            ,  STQ.Sku  
  
QUIT:  

DROP TABLE #STQRPT
--DROP TABLE #TMPSNSTQ
  
END -- procedure  


GO