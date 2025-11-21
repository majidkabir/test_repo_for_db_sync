SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_delivery_note48                                     */
/* Creation Date: 20-SEP-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-15197 - PH_Novateur_DeliveryNote_RCM_CR                 */
/*        :                                                             */
/* Called By: r_dw_delivery_note48                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 06-NOV-2020 CSCHONG  1.1   WMS-15197 revised field mapping (CS01)    */
/* 10-NOV-2020 CSCHONG  1.2   WMS-15197 fix sn length, taxqty issue (CS02)*/
/* 21-DEC-2020 LZG      1.3   INC1382606 - Misc fixes (ZG01)            */
/* 26-MAR-2021 LZG      1.4   INC1461268 - Used PickDetail.Qty (ZG02)   */
/* 24-JUN-2021 LZG      1.5   JSM-5938 - Sum split PickDetail lines     */
/*                                       Qty (ZG03)                     */
/************************************************************************/
CREATE PROC [dbo].[isp_delivery_note48]
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
         , @c_GetOrdKey       NVARCHAR(20)      --(CS02) START
         , @c_Getstorerkey    NVARCHAR(20)
         , @c_GetSKU          NVARCHAR(20)
         , @c_GetSN           NVARCHAR(50)
         , @n_seqno           INT              --(CS02) END
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
     
   SET @c_Rptsku = ''            
   SET @n_Maxline = 17        
    
  
   CREATE TABLE #DN48  
      (  Facility          NVARCHAR(5)      
      ,  DeliveryNote      NVARCHAR(20)     
      ,  OHUDF06           NVARCHAR(30)   
      ,  shipperkey        NVARCHAR(30)   
     -- ,  ShipDate          DATETIME    NULL  
      ,  PmtTerm           NVARCHAR(20) NULL  
      ,  BuyerPO           NVARCHAR(20)     
      ,  Orderkey          NVARCHAR(10)  
      ,  ExternOrderkey    NVARCHAR(50)
      ,  ExternPOkey       NVARCHAR(20)   
      --,  OrderDate         DATETIME    NULL  
      --,  DeliveryDate      DATETIME    NULL  
      ,  OHUDF05           NVARCHAR(50)    
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
      ,  UOMQTY            INT  
      ,  TAXQTY            FLOAT  
      ,  OHUDF03           FLOAT   
      ,  PQTY              INT      
      ,  EcomOrderId       NVARCHAR(45)   
      ,  ST_Address1       NVARCHAR(45)   
      ,  ST_Address2       NVARCHAR(45)   
      ,  ST_Address3       NVARCHAR(45)   
      ,  Pageno            INT
      ,  ODlinenumber      NVARCHAR(10)
      ,  snum              NVARCHAR(50)     --(CS02)
      )  
  
  INSERT INTO #DN48  
   (  Facility            
      ,  DeliveryNote    
      ,  OHUDF06     
      ,  shipperkey           
    --  ,  ShipDate   
      ,  PmtTerm   
      ,  BuyerPO             
      ,  Orderkey            
      ,  ExternOrderkey      
      ,  ExternPOkey         
      --,  OrderDate           
      --,  DeliveryDate        
      ,  OHUDF05        
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
      ,  TAXQTY             
      ,  OHUDF03     
      ,  PQTY     
      ,  EcomOrderId   
      ,  ST_Address1        
      ,  ST_Address2         
      ,  ST_Address3          
      ,  Pageno    
      ,  ODlinenumber      
      ,  snum                               --CS02      
      )  
   SELECT ORDERS.Facility  
  , DeliveryNote = ISNULL(RTRIM(orders.deliverynote),'')  
 -- , OHUDF06 = ISNULL(RTRIM(orders.userdefine06),'')                --CS01
  , OHUDF06 = CONVERT(NVARCHAR(10),getdate(),101)                    --CS01
  , shipperkey = ISNULL(RTRIM(orders.shipperkey),'')  
  --    , ShipDate = MBOL.ShipDate    
  , PmtTerm = ISNULL(orders.PmtTerm,'')  
  , BuyerPO= ISNULL(RTRIM(orders.BuyerPO),'')  
  , ORDERS.Orderkey  
  , ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
  , ExternPOkey =  ISNULL(RTRIM(ORDERS.ExternPOkey),'')      
  --, ORDERS.OrderDate  
  --, ORDERS.DeliveryDate  
  , OHUDF05 = ISNULL(RTRIM(orders.userdefine05),'')
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
  , PICKDETAIL.Storerkey  
  , PICKDETAIL.Sku AS sku   
  , SKUDescr = ISNULL(RTRIM(SKU.Descr),'')  
  , UOMQty = SUM(CASE WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'') = PACK.PACKUOM1 THEN (PICKDETAIL.Qty)/NULLIF(PACK.CASECNT,0)     -- ZG02
           WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'')= PACK.PACKUOM2 THEN (PICKDETAIL.Qty)/NULLIF(PACK.INNERPACK,0)           -- ZG02
           WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'') = PACK.PACKUOM3 THEN (PICKDETAIL.Qty)/NULLIF(PACK.Qty,0)                -- ZG02
           WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'') = PACK.PACKUOM4 THEN (PICKDETAIL.Qty)/NULLIF(PACK.Pallet,0) ELSE 0 END)  -- ZG02 
 -- , UOMQty = (ORDERDETAIL.OriginalQty)
  , TAXQTY  = SUM(PICKDETAIL.Qty)   
  , OHUDF03 = CASE WHEN ISNUMERIC(ISNULL(RTRIM(ORDERDETAIL.userdefine03),'')) = 1 THEN CAST(ISNULL(RTRIM(ORDERDETAIL.userdefine03),'0') AS decimal(10,2)) ELSE 1 END 
  , SUM(PICKDETAIL.Qty)    
  , EcomOrderId = ISNULL(OIF.EcomOrderId,'')  
  , ST_Address1 = ISNULL(RTRIM(ST.Address1),'') 
  , ST_Address2 = ISNULL(RTRIM(ST.Address2),'')
  , ST_Address3 = ISNULL(RTRIM(ST.Address3),'')
  , pageno = 1--(Row_Number() OVER (PARTITION BY ORDERS.Orderkey ORDER BY ORDERS.Orderkey, ORDERDETAIL.orderlinenumber,PICKDETAIL.Sku Asc)-1)/@n_maxLine + 1   
  , ODlinenumber = ORDERDETAIL.orderlinenumber
  , ''                                             --CS02
 FROM ORDERS     WITH (NOLOCK) 
 JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)  
 JOIN ORDERDETAIL (NOLOCK)
      ON PICKDETAIL.orderkey = ORDERDETAIL.orderkey and
         PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber 
-- JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot= LOTATTRIBUTE.Lot)  
 JOIN SKU        WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)  
          AND(PICKDETAIL.Sku = SKU.Sku)  
 JOIN PACK       WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)   
 LEFT JOIN  STORER ST WITH (NOLOCK) ON ST.Storerkey = ORDERS.StorerKey   
 LEFT JOIN ORDERINFO OIF WITH (NOLOCK) ON OIF.orderkey = ORDERS.Orderkey
 LEFT JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORDERS.Orderkey
 WHERE ORDERS.Orderkey = @c_Orderkey  
 --AND PICKDETAIL.Status >= '5'  
AND PH.ManifestPrinted  = CASE WHEN @c_Reprint = 'Y' THEN 'Y' ELSE '0' END
 GROUP BY ORDERS.Facility  
  , ISNULL(RTRIM(orders.deliverynote),'')   
 -- , ISNULL(RTRIM(orders.userdefine06),'')                    --CS01
  , ISNULL(RTRIM(orders.shipperkey),'')  
    --  , MBOL.ShipDate   
  , ISNULL(orders.PmtTerm,'')  
  , ISNULL(RTRIM(orders.BuyerPO),'')  
  , ORDERS.Orderkey  
  , ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
  , ISNULL(RTRIM(ORDERS.ExternPOkey),'')  
  --, ORDERS.OrderDate  
  --, ORDERS.DeliveryDate  
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
  , PICKDETAIL.Storerkey  
  --, PICKDETAIL.Sku  
  , ISNULL(RTRIM(SKU.Descr),'')  
  , ISNULL(PACK.CaseCnt,0)  
  , CASE WHEN ISNUMERIC(ISNULL(RTRIM(ORDERDETAIL.userdefine03),'')) = 1 THEN CAST(ISNULL(RTRIM(ORDERDETAIL.userdefine03),'0') AS decimal(10,2)) ELSE 1 END 
  , ISNULL(OIF.EcomOrderId,'')  
  , PICKDETAIL.Sku 
  ,ISNULL(RTRIM(ST.Address1),'') 
  ,ISNULL(RTRIM(ST.Address2),'') 
  ,ISNULL(RTRIM(ST.Address3),'')  
  ,(ORDERDETAIL.OriginalQty)
  , (PICKDETAIL.Qty)    
 ,  ORDERDETAIL.orderlinenumber 
  , PACK.PACKUOM1,PACK.PACKUOM2,PACK.PACKUOM3,PACK.PACKUOM4
  ,PACK.CASECNT,PACK.INNERPACK,PACK.qty,PACK.Pallet
   
   --CS02 START
   SET @n_seqno = 1

   DECLARE CUR_ORDSN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT  OD.Storerkey    
          ,OD.Orderkey    
          ,OD.SKU
          ,ISNULL(SN.serialno,'')     
   FROM  ORDERDETAIL OD (NOLOCK)     
   LEFT JOIN serialno SN WITH (NOLOCK)  ON SN.Orderkey = OD.Orderkey AND SN.sku = OD.sku AND SN.Storerkey = OD.Storerkey
   where OD.Orderkey = @c_orderkey
   
   OPEN CUR_ORDSN    
       
   FETCH FROM CUR_ORDSN INTO @c_GetStorerkey, @c_GetOrdKey, @c_getsku,@c_getsn    
       
   WHILE @@FETCH_STATUS = 0    
   BEGIN      

    -- ZG01 (Start)
    --IF @n_seqno = 1
    --BEGIN
    --      UPDATE #DN48
    --      SET snum = @c_GetSN
    --      where Orderkey = @c_GetOrdKey and Sku = @c_GetSKU and storerkey = @c_Getstorerkey
    --END
    --ELSE
    --BEGIN
         
         INSERT INTO #DN48 (Facility ,  DeliveryNote ,  OHUDF06  ,  shipperkey  ,  PmtTerm   
      ,  BuyerPO             
      ,  Orderkey            
      ,  ExternOrderkey      
      ,  ExternPOkey              
      ,  OHUDF05        
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
      ,  TAXQTY             
      ,  OHUDF03     
      ,  PQTY     
      ,  EcomOrderId   
      ,  ST_Address1        
      ,  ST_Address2         
      ,  ST_Address3          
      ,  Pageno    
      ,  ODlinenumber      
      ,  snum                               --CS02      
      )  
     SELECT TOP 1 Facility ,  DeliveryNote ,  OHUDF06  ,  shipperkey  ,  PmtTerm   
      ,  BuyerPO             
      ,  Orderkey            
      ,  ExternOrderkey      
      ,  ExternPOkey              
      ,  OHUDF05        
      ,  C_Company           
      ,  C_Address1          
      ,  C_Address2    
      ,  C_Address3        
      ,  C_Address4              
      ,  C_contact1               
      ,  c_vat            
      ,  Salesman           
      ,  0          
      ,  B_Address1          
      ,  B_Address2     
      ,  B_Address3       
      ,  B_Address4              
      ,  ST_VAT               
      ,  ST_Phone1            
      ,  OHNotes              
      ,  Storerkey           
      ,  ''                 
      ,  ''            
      ,  0            
      ,  0             
      ,  0     
      ,  0     
      ,  EcomOrderId   
      ,  ST_Address1        
      ,  ST_Address2         
      ,  ST_Address3          
      ,  Pageno    
      ,  ODlinenumber      
      ,  @c_GetSN  
    FROM #DN48
     where Orderkey = @c_GetOrdKey and Sku = @c_GetSKU and storerkey = @c_Getstorerkey
   
   -- END

   --SET @n_seqno = @n_seqno + 1
   -- ZG01 (End)

   FETCH FROM CUR_ORDSN INTO @c_GetStorerkey, @c_GetOrdKey, @c_getsku,@c_getsn    
   END -- While CUR_UPD_MBOLDETAIL    
              
   CLOSE CUR_ORDSN    
   DEALLOCATE CUR_ORDSN      
   --CS02 END     
  
   SELECT    
         DN48.Facility            
      ,  DN48.DeliveryNote    
      ,  convert(nvarchar(10),CAST(DN48.OHUDF06 as DATETIME),101) as OHUDF06     
      ,  DN48.shipperkey           
    --  ,  ShipDate   
      ,  DN48.PmtTerm   
    --  ,  BuyerPO             
      ,  DN48.Orderkey            
      ,  DN48.ExternOrderkey      
      ,  DN48.ExternPOkey             
      ,  DN48.OHUDF05        
      ,  DN48.C_Company           
      ,  DN48.C_Address1          
      ,  DN48.C_Address2    
      ,  DN48.C_Address3        
      ,  DN48.C_Address4              
      ,  DN48.C_contact1               
      ,  DN48.c_vat            
      ,  DN48.Salesman           
      ,  DN48.UOM           
      ,  DN48.B_Address1          
      ,  DN48.B_Address2     
      ,  DN48.B_Address3       
      ,  DN48.B_Address4              
      ,  DN48.ST_VAT               
      ,  DN48.ST_Phone1            
      ,  DN48.OHNotes              
      ,  DN48.Storerkey           
      ,  DN48.Sku                 
      ,  DN48.SKUDescr            
      ,  SUM(DN48.UOMQTY)                          -- ZG03
      ,  SUM(DN48.UOMQTY *DN48.OHUDF03) AS TAXQTY  -- ZG03
      ,  DN48.OHUDF03   
      ,  SUM(DN48.PQTY) as PQTY                    -- ZG03
      ,  DN48.EcomOrderId   
      ,  DN48.ST_Address1        
      ,  DN48.ST_Address2         
      ,  DN48.ST_Address3          
      --,   (Row_Number() OVER (PARTITION BY DN48.Orderkey ORDER BY DN48.Orderkey, DN48.ODlinenumber,DN48.Sku,ISNULL(DN48.SNUM,'') Asc)-1)/@n_maxLine + 1 as Pageno  --CS02
      ,   (Row_Number() OVER (PARTITION BY DN48.Orderkey ORDER BY DN48.Orderkey, DN48.ODlinenumber,CASE WHEN DN48.Sku <> '' THEN 1 ELSE 0 END desc,ISNULL(DN48.SNUM,'') Asc)-1)/@n_maxLine + 1 as Pageno  --CS02 -- ZG01
      ,  DN48.BuyerPO  
      ,  DN48.ODlinenumber
      ,  ISNULL(DN48.SNUM,'') AS SNUM              --CS02
      FROM #DN48  DN48   
     -- LEFT JOIN serialno SN WITH (NOLOCK)  ON SN.Orderkey = DN48.Orderkey AND SN.sku = DN48.sku AND SN.Storerkey = DN48.Storerkey
      group by DN48.Facility            
      ,  DN48.DeliveryNote    
      ,  convert(nvarchar(10),CAST(DN48.OHUDF06 as DATETIME),101)     
      ,  DN48.shipperkey           
    --  ,  ShipDate   
      ,  DN48.PmtTerm   
    --  ,  BuyerPO             
      ,  DN48.Orderkey            
      ,  DN48.ExternOrderkey      
      ,  DN48.ExternPOkey             
      ,  DN48.OHUDF05        
      ,  DN48.C_Company           
      ,  DN48.C_Address1          
      ,  DN48.C_Address2    
      ,  DN48.C_Address3        
      ,  DN48.C_Address4              
      ,  DN48.C_contact1               
      ,  DN48.c_vat            
      ,  DN48.Salesman           
      ,  DN48.UOM           
      ,  DN48.B_Address1          
      ,  DN48.B_Address2     
      ,  DN48.B_Address3       
      ,  DN48.B_Address4              
      ,  DN48.ST_VAT               
      ,  DN48.ST_Phone1            
      ,  DN48.OHNotes              
      ,  DN48.Storerkey           
      ,  DN48.Sku                 
      ,  DN48.SKUDescr            
      --,  DN48.UOMQTY                 -- ZG03
     -- ,  (DN48.UOMQTY *DN48.OHUDF03)              
      ,  DN48.OHUDF03   
      --,  PQTY                        -- ZG03
      ,  DN48.EcomOrderId   
      ,  DN48.ST_Address1        
      ,  DN48.ST_Address2         
      ,  DN48.ST_Address3          
     -- ,  Pageno  
      ,  DN48.BuyerPO  
      ,  DN48.ODlinenumber
      ,  ISNULL(DN48.SNUM,'')
      ORDER BY DN48.Orderkey  
            , DN48.ODLineNumber
            ,  DN48.Storerkey       
           -- ,  DN48.Sku  
            ,  CASE WHEN DN48.Sku <> '' THEN 1 ELSE 0 END desc        --CS02
  
QUIT:  
  
END -- procedure  


GO