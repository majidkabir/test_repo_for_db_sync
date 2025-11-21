SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Delivery_Receipt10                                  */
/* Creation Date: 04-MAY-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-15908 - PH_YLEO_DELIVERY_RECEIPT_REPORT                 */
/*        :                                                             */
/* Called By: r_dw_delivery_receipt10                                   */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 24-Jul-2021 CSCHONG  1.0   WMS-15908 revised field logic (CS01)      */
/* 26-Jul-2021 CSCHONG  1.1   WMS-15908 fix page break sorting issue(CS02)*/
/************************************************************************/
CREATE PROC [dbo].[isp_Delivery_Receipt10]
            @c_OrderKey     NVARCHAR(10)  

AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF     
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT  
   
         , @c_Consigneekey    NVARCHAR(15)  
         , @c_TransMehtod     NVARCHAR(30)  
         , @d_ShipDate4ETA    DATETIME  
         , @d_ETA             DATETIME  
         , @c_Rptsku          NVARCHAR(5)    
  
         , @n_Leadtime        INT  
         , @n_Leadtime1       INT  
         , @n_Leadtime2       INT 
         , @n_MaxLine         INT 
         , @c_GetOrdKey       NVARCHAR(20)     
         , @c_Getstorerkey    NVARCHAR(20)
         , @c_GetSKU          NVARCHAR(20)
         , @c_GetSN           NVARCHAR(50)
         , @n_seqno           INT             
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
     
   SET @c_Rptsku = ''            
   SET @n_Maxline = 25--17     --CS02        
    
  
   CREATE TABLE #DR10  
      (  ODNotes            NVARCHAR(500)     
      ,  DRDate            NVARCHAR(10) 
      ,  shipperkey        NVARCHAR(30)   
      ,  DRTerm            NVARCHAR(50) NULL      
      ,  Orderkey          NVARCHAR(10)  
      ,  ExternOrderkey    NVARCHAR(50) 
      ,  PrepareBy         NVARCHAR(50)   
      ,  ApprovedBy        NVARCHAR(50)      
      ,  C_Address1        NVARCHAR(45)    
      ,  C_Address2        NVARCHAR(45)   
      ,  C_Address3        NVARCHAR(45)   
      ,  C_Address4        NVARCHAR(45)   
      ,  C_contact1        NVARCHAR(45)   
      ,  c_vat             NVARCHAR(30)   
      ,  C_City            NVARCHAR(45)
      ,  C_State           NVARCHAR(45)
      ,  C_Zip             NVARCHAR(45)  
      ,  Storerkey         NVARCHAR(15)  
      ,  Sku               NVARCHAR(20)   
      ,  SKUDescr          NVARCHAR(60)     
      ,  QTY               NVARCHAR(10)        
      ,  Pageno            INT
      ,  PrefixQty         NVARCHAR(50)
      ,  ShowField         NVARCHAR(5)
      ,  ExtLineno         INT

      )  
  
  INSERT INTO #DR10  
   (     ODNotes    
      ,  DRDate
      ,  shipperkey            
      ,  DRTerm           
      ,  Orderkey            
      ,  ExternOrderkey      
      ,  PrepareBy            
      ,  ApprovedBy                 
      ,  C_Address1          
      ,  C_Address2    
      ,  C_Address3        
      ,  C_Address4              
      ,  C_contact1               
      ,  c_vat            
      ,  C_City           
      ,  C_State           
      ,  C_Zip                      
      ,  Storerkey           
      ,  Sku                 
      ,  SKUDescr              
      ,  QTY              
      ,  Pageno    
      ,  PrefixQty
      ,  ShowField
      ,  ExtLineno
      )  
   SELECT 
    ODNotes = CASE WHEN ISNULL(RTRIM(orderdetail.notes),'') <> '' THEN ISNULL(RTRIM(orderdetail.notes),'') ELSE ISNULL(RTRIM(c.Description),'') END  
  , DRDate = CONVERT(NVARCHAR(10),getdate(),101)               
  , shipperkey = ISNULL(RTRIM(orders.shipperkey),'')   
  , RDTerm = 'Pre-Paid'
  , ORDERS.Orderkey  
  , ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
  , PrepareBy =  'LF'    
  , ApprovedBy = 'LF'
  , C_Address1 = ISNULL(RTRIM(ORDERS.C_Address1),'')  
  , C_Address2 = ISNULL(RTRIM(ORDERS.C_Address2),'')  
  , C_Address3 = ISNULL(RTRIM(ORDERS.C_Address3),'')  
  , C_Address4= ISNULL(RTRIM(ORDERS.C_Address4),'')  
  , C_contact1 = ISNULL(RTRIM(ORDERS.C_contact1),'')  
  , c_vat= ISNULL(RTRIM(ORDERS.c_vat),'')  
  , C_City = ISNULL(RTRIM(ORDERS.C_City),'') 
  , C_State = ISNULL(RTRIM(ORDERS.C_State),'')  
  , C_Zip = ISNULL(RTRIM(ORDERS.C_Zip),'') 
  , ORDERs.Storerkey  
  , ORDERDETAIL.Sku AS sku   
  , SKUDescr = ISNULL(RTRIM(SKU.Descr),'')  
  --, SUM(Orderdetail.QtyAllocated + Orderdetail.QtyPicked + Orderdetail.ShippedQty)    --CS01
  , Qty = CASE WHEN ORDERDETAIL.Userdefine02 = ('K') THEN
                        CASE WHEN SUM(Orderdetail.QtyAllocated + Orderdetail.QtyPicked + Orderdetail.ShippedQty) > 0 THEN '' 
                                 ELSE CAST(SUM(Orderdetail.QtyAllocated + Orderdetail.QtyPicked + Orderdetail.ShippedQty) AS NVARCHAR(10)) END 
          ELSE CAST(SUM(Orderdetail.QtyAllocated + Orderdetail.QtyPicked + Orderdetail.ShippedQty) AS NVARCHAR(10)) END
  , pageno = 1--(Row_Number() OVER (PARTITION BY ORDERS.Orderkey ORDER BY ORDERS.Orderkey, ORDERDETAIL.orderlinenumber,PICKDETAIL.Sku Asc)-1)/@n_maxLine + 1   
  , PrefixQty = CASE WHEN ORDERDETAIL.Userdefine02 NOT IN ('N', 'PN') THEN
                        CASE WHEN SUM(Orderdetail.QtyAllocated + Orderdetail.QtyPicked + Orderdetail.ShippedQty) = 0 THEN '(OOS-To Follow)' ELSE '' END ELSE '' END
  , ShowField = CASE WHEN  ISNULL(C.UDF01,'N') = 'N' THEN CASE WHEN  ISNULL(Sku.busr5,'N') = 'Y' THEN 'Y' ELSE 'N' END ELSE 'Y' END 
  , ExtLineno = CAST(Orderdetail.externlineno AS INT)
 FROM ORDERS     WITH (NOLOCK) 
 JOIN ORDERDETAIL (NOLOCK) ON ORDERDETAIL.Orderkey = ORDERS.Orderkey
 JOIN SKU        WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)  
          AND(ORDERDETAIL.Sku = SKU.Sku)  
 LEFT JOIN dbo.CODELKUP C WITH (NOLOCK) ON C.listname = 'YLLinetype' AND C.code = ORDERDETAIL.Userdefine02 
                                         AND C.Storerkey=ORDERDETAIL.storerkey AND C.UDF01='Y'
 WHERE ORDERS.Orderkey = @c_Orderkey  
 GROUP BY CASE WHEN ISNULL(RTRIM(orderdetail.notes),'') <> '' THEN ISNULL(RTRIM(orderdetail.notes),'') ELSE ISNULL(RTRIM(c.Description),'') END  
  , ISNULL(RTRIM(orders.shipperkey),'')    
  , ORDERS.Orderkey  
  , ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
  , ISNULL(RTRIM(ORDERS.C_Address1),'')  
  , ISNULL(RTRIM(ORDERS.C_Address2),'')  
  , ISNULL(RTRIM(ORDERS.C_Address3),'')  
  , ISNULL(RTRIM(ORDERS.C_Address4),'')  
  , ISNULL(RTRIM(ORDERS.C_contact1),'')  
  , ISNULL(RTRIM(ORDERS.c_vat),'')  
  , ISNULL(RTRIM(ORDERS.Salesman),'')  
  , ISNULL(RTRIM(ORDERS.C_City),'') 
  , ISNULL(RTRIM(ORDERS.C_State),'')  
  , ISNULL(RTRIM(ORDERS.C_Zip),'') 
  , ORDERS.Storerkey   
  , ORDERDETAIL.Sku
  , ISNULL(RTRIM(SKU.Descr),'')   
  , CASE WHEN  ISNULL(C.UDF01,'N') = 'N' THEN CASE WHEN  ISNULL(Sku.busr5,'N') = 'Y' THEN 'Y' ELSE 'N' END ELSE 'Y' END 
  , CAST(Orderdetail.externlineno AS INT),ORDERDETAIL.Userdefine02
   ORDER BY ORDERS.Orderkey,CAST(Orderdetail.externlineno AS INT)
 
  
   SELECT    
         
         #DR10.ODNotes   
      ,  #DR10.DRDate  
      ,  #DR10.shipperkey             
      ,  #DR10.DRTerm              
      ,  #DR10.Orderkey            
      ,  #DR10.ExternOrderkey      
      ,  #DR10.PrepareBy             
      ,  #DR10.ApprovedBy                  
      ,  #DR10.C_Address1          
      ,  #DR10.C_Address2    
      ,  #DR10.C_Address3        
      ,  #DR10.C_Address4              
      ,  #DR10.C_contact1               
      ,  #DR10.c_vat            
      ,  #DR10.C_City           
      ,  #DR10.C_State           
      ,  #DR10.C_Zip                        
      ,  #DR10.Storerkey           
      ,  #DR10.Sku                 
      ,  #DR10.SKUDescr              
      ,  (#DR10.QTY) as QTY           
      ,   (Row_Number() OVER (PARTITION BY #DR10.Orderkey ORDER BY #DR10.Orderkey,#DR10.ExtLineno,#DR10.Sku Asc)-1)/@n_maxLine + 1 as Pageno  --CS02
      ,  #DR10.PrefixQty 
      ,  #DR10.ShowField 
      FROM #DR10  #DR10   
      WHERE #DR10.ShowField='Y'
      group by  #DR10.ODNotes   
      ,  #DR10.DRDate  
      ,  #DR10.shipperkey             
      ,  #DR10.DRTerm              
      ,  #DR10.Orderkey            
      ,  #DR10.ExternOrderkey      
      ,  #DR10.PrepareBy             
      ,  #DR10.ApprovedBy                  
      ,  #DR10.C_Address1          
      ,  #DR10.C_Address2    
      ,  #DR10.C_Address3        
      ,  #DR10.C_Address4              
      ,  #DR10.C_contact1               
      ,  #DR10.c_vat            
      ,  #DR10.C_City           
      ,  #DR10.C_State           
      ,  #DR10.C_Zip                        
      ,  #DR10.Storerkey           
      ,  #DR10.Sku                 
      ,  #DR10.SKUDescr              
      ,  (#DR10.QTY)         
      ,  #DR10.PrefixQty  
      ,  #DR10.ShowField 
       ,  #DR10.ExtLineno
      ORDER BY #DR10.Orderkey  
            ,  #DR10.Storerkey       
            --,  CASE WHEN #DR10.Sku <> '' THEN 1 ELSE 0 END desc   
            , #DR10.ShowField desc     
            ,  #DR10.ExtLineno
QUIT:  
  
END -- procedure  


GO