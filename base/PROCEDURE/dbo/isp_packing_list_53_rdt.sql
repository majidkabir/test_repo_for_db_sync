SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_packing_list_53_rdt                                 */
/* Creation Date: 23-JUL-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-5695 - [JP] DW Delivery Note Data Window_PB             */
/*        :                                                             */
/* Called By: r_dw_packing_list_53_rdt                                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 14-Nov-2018 NJOW01   1.0   Add ORDERS.M_Company                      */
/* 03-Feb-2020 WLChooi  1.1   Add dummy SKU line to cater for WMS-11529 */
/*                            (WL01)                                    */
/* 11-Feb-2020 WLChooi  1.2   WMS-12039 - Comment out some part, add new*/
/*                            columns (WL02)                            */
/* 27-Feb-2020 WLChooi  1.3   WMS-12039 - Fix-Use Orders.Loadkey and Qty*/
/*                            and remove Summary (WL03)                 */
/************************************************************************/
CREATE PROC [dbo].[isp_packing_list_53_rdt]
         @c_PickSlipNo  NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Storerkey       NVARCHAR(15) 
         , @c_Orderkey        NVARCHAR(10) 
         , @c_Loadkey         NVARCHAR(10) 
         , @c_ShippingAgent   NVARCHAR(60) 
                                     
   DECLARE @c_C1              NVARCHAR(30)  
         , @c_C2              NVARCHAR(30)  
         , @c_C3              NVARCHAR(30)  
         , @c_C4              NVARCHAR(30)  
         , @c_C5              NVARCHAR(30)  
         , @c_C6              NVARCHAR(30)  
         , @c_C7              NVARCHAR(30)  
         , @c_C8              NVARCHAR(30)  
         , @c_C9              NVARCHAR(30)  
         , @c_C10             NVARCHAR(30)  
         , @c_C11             NVARCHAR(30)  
         , @c_C12             NVARCHAR(30)  
         , @c_C13             NVARCHAR(30)  
         , @c_C14             NVARCHAR(30)  
         , @c_C15             NVARCHAR(30)  
         , @c_C16             NVARCHAR(30)  
         , @c_C17             NVARCHAR(30)  
         , @c_C18             NVARCHAR(30)  
         , @c_C19             NVARCHAR(30)  
         , @c_C20             NVARCHAR(30)  
         , @c_C21             NVARCHAR(30)  
         , @c_C22             NVARCHAR(30)  
         , @c_C23             NVARCHAR(30)  
         , @c_C24             NVARCHAR(30)  
         , @c_C25             NVARCHAR(30)  
         , @c_C26             NVARCHAR(30)  
         , @c_C27             NVARCHAR(30)  
         , @c_C28             NVARCHAR(250)  
         , @c_C29             NVARCHAR(250)  
         , @c_C30             NVARCHAR(30)  
         , @c_C31             NVARCHAR(30)  
         , @c_C32             NVARCHAR(30) 
         , @c_C44             NVARCHAR(30)   --WL02
         , @c_C45             NVARCHAR(30)   --WL02

   DECLARE @n_MaxLineno       INT = 18
         , @n_MaxRec          INT  
         , @n_CurrentRec      INT
         , @c_GetLoadkey      NVARCHAR(10) 
         , @c_GetOrderkey     NVARCHAR(10) 


 CREATE TABLE #TMP_INV
      (  RowRef            INT      IDENTITY(1,1)  PRIMARY KEY
      ,  SortBy            INT
      ,  PageGroup         INT
      ,  Storerkey         NVARCHAR(15)   NULL
      ,  Loadkey           NVARCHAR(10)   NULL
      ,  OrderKey          NVARCHAR(10)   NULL
      ,  Consigneekey      NVARCHAR(15)   NULL
      ,  ExternOrderkey    NVARCHAR(30)   NULL
      ,  C_Contact1        NVARCHAR(30)   NULL
      ,  C_Phone1          NVARCHAR(18)   NULL
      ,  C_Address         NVARCHAR(95)   NULL
      ,  C_ZipCity         NVARCHAR(65)   NULL
      ,  C_Country         NVARCHAR(30)   NULL
      ,  C_Address4        NVARCHAR(45)   NULL
      ,  B_Contact2        NVARCHAR(30)   NULL
      ,  B_Address         NVARCHAR(95)   NULL
      ,  B_ZipCity         NVARCHAR(65)   NULL
      ,  B_Country         NVARCHAR(30)   NULL      
      ,  ShipmentDate      DATETIME       NULL
      ,  OrderType         NVARCHAR(10)   NULL 
      ,  SalesMan          NVARCHAR(30)   NULL
      ,  Sku               NVARCHAR(20)   NULL
      ,  SkuDescr          NVARCHAR(100)  NULL
      ,  UOM               NVARCHAR(10)   NULL
      ,  QtyToProcess      NVARCHAR(18)   NULL
      ,  QtyShipped        INT            NULL 
      ,  Summary           NVARCHAR(30)   NULL 
      ,  TotalQtyShipped   NVARCHAR(18)   NULL
      ,  M_Company         NVARCHAR(45)   NULL  --NJOW01
      ,  BuyerPO           NVARCHAR(20)   NULL  --WL02
      )  

  --WL02
 /*CREATE TABLE #TMP_INV_Final
      (  RowRef            INT      IDENTITY(1,1)  PRIMARY KEY
      ,  SortBy            INT
      ,  PageGroup         INT
      ,  Storerkey         NVARCHAR(15)   NULL
      ,  Loadkey           NVARCHAR(10)   NULL
      ,  OrderKey          NVARCHAR(10)   NULL
      ,  Consigneekey      NVARCHAR(15)   NULL
      ,  ExternOrderkey    NVARCHAR(30)   NULL
      ,  C_Contact1        NVARCHAR(30)   NULL
      ,  C_Phone1          NVARCHAR(18)   NULL
      ,  C_Address         NVARCHAR(95)   NULL
      ,  C_ZipCity         NVARCHAR(65)   NULL
      ,  C_Country         NVARCHAR(30)   NULL
      ,  C_Address4        NVARCHAR(45)   NULL
      ,  B_Contact2        NVARCHAR(30)   NULL
      ,  B_Address         NVARCHAR(95)   NULL
      ,  B_ZipCity         NVARCHAR(65)   NULL
      ,  B_Country         NVARCHAR(30)   NULL      
      ,  ShipmentDate      DATETIME       NULL
      ,  OrderType         NVARCHAR(10)   NULL 
      ,  SalesMan          NVARCHAR(30)   NULL
      ,  Sku               NVARCHAR(20)   NULL
      ,  SkuDescr          NVARCHAR(100)  NULL
      ,  UOM               NVARCHAR(10)   NULL
      ,  QtyToProcess      NVARCHAR(18)   NULL
      ,  QtyShipped        INT            NULL 
      ,  Summary           NVARCHAR(30)   NULL 
      ,  TotalQtyShipped   NVARCHAR(18)   NULL
      ,  M_Company         NVARCHAR(45)   NULL 
      ,  RecGroup          INT            NULL
      ) */

   CREATE TABLE #TMP_ORDERS 
         (  
            Orderkey NVARCHAR(10) NOT NULL PRIMARY KEY
         ,  Loadkey  NVARCHAR(10) NULL DEFAULT ('')
         )

   SET @c_Storerkey = ''
   SET @c_Loadkey   = ''
   SET @c_Orderkey  = ''

   --WL03 START
   SELECT @c_Storerkey = PH.Storerkey 
         ,@c_Loadkey   = OH.Loadkey
         ,@c_Orderkey  = PH.Orderkey
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = PH.Orderkey
   WHERE PH.PickSlipNo = @c_PickSlipNo 
   --WL03 END

   IF ISNULL(RTRIM(@c_Orderkey),'') = ''
   BEGIN
      INSERT INTO #TMP_ORDERS
         (  
            Orderkey
         ,  Loadkey 
         ) 
      SELECT DISTINCT
            LPD.Orderkey
         ,  LPD.Loadkey
      FROM LOADPLAN        LP WITH (NOLOCK)
      JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LP.LoadKey = LPD.Loadkey)
      WHERE LP.Loadkey = @c_Loadkey
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_ORDERS
         (  
            Orderkey
         ,  Loadkey 
         ) 
      VALUES  
         (  
            @c_Orderkey
         ,  @c_Loadkey 
         ) 
   END

   SET @c_ShippingAgent = ''

   SELECT @c_ShippingAgent = ISNULL(RTRIM(CL.UDF05),'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'CartnTrack'
   AND   CL.Code     = 'YTC1'
   AND   CL.Storerkey= @c_Storerkey   

   SELECT @c_C1 = ISNULL(MAX(CASE WHEN CL.Code = 'C1'  THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C2 = ISNULL(MAX(CASE WHEN CL.Code = 'C2'  THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C3 = ISNULL(MAX(CASE WHEN CL.Code = 'C3'  THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C4 = ISNULL(MAX(CASE WHEN CL.Code = 'C4'  THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C5 = ISNULL(MAX(CASE WHEN CL.Code = 'C5'  THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C6 = ISNULL(MAX(CASE WHEN CL.Code = 'C6'  THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C7 = ISNULL(MAX(CASE WHEN CL.Code = 'C7'  THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C8 = ISNULL(MAX(CASE WHEN CL.Code = 'C8'  THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C9 = ISNULL(MAX(CASE WHEN CL.Code = 'C9'  THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C10= ISNULL(MAX(CASE WHEN CL.Code = 'C10' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C11= ISNULL(MAX(CASE WHEN CL.Code = 'C11' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C12= ISNULL(MAX(CASE WHEN CL.Code = 'C12' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C13= ISNULL(MAX(CASE WHEN CL.Code = 'C13' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C14= ISNULL(MAX(CASE WHEN CL.Code = 'C14' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C15= ISNULL(MAX(CASE WHEN CL.Code = 'C15' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C16= ISNULL(MAX(CASE WHEN CL.Code = 'C16' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C17= ISNULL(MAX(CASE WHEN CL.Code = 'C17' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C18= ISNULL(MAX(CASE WHEN CL.Code = 'C18' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C19= ISNULL(MAX(CASE WHEN CL.Code = 'C19' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C20= ISNULL(MAX(CASE WHEN CL.Code = 'C20' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C21= ISNULL(MAX(CASE WHEN CL.Code = 'C21' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C22= ISNULL(MAX(CASE WHEN CL.Code = 'C22' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C23= ISNULL(MAX(CASE WHEN CL.Code = 'C23' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C24= ISNULL(MAX(CASE WHEN CL.Code = 'C24' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C25= ISNULL(MAX(CASE WHEN CL.Code = 'C25' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C26= ISNULL(MAX(CASE WHEN CL.Code = 'C26' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C27= ISNULL(MAX(CASE WHEN CL.Code = 'C27' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C28= ISNULL(MAX(CASE WHEN CL.Code = 'C28' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C29= ISNULL(MAX(CASE WHEN CL.Code = 'C29' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C30= ISNULL(MAX(CASE WHEN CL.Code = 'C30' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C31= ISNULL(MAX(CASE WHEN CL.Code = 'C31' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C32= ISNULL(MAX(CASE WHEN CL.Code = 'C32' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C44= ISNULL(MAX(CASE WHEN CL.Code = 'C44' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')  --WL02
         ,@c_C45= ISNULL(MAX(CASE WHEN CL.Code = 'C45' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')  --WL02
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'DNCONST'

   INSERT INTO #TMP_INV
         (
            SortBy         
         ,  PageGroup      
         ,  Storerkey      
         ,  Loadkey        
         ,  OrderKey       
         ,  Consigneekey   
         ,  ExternOrderkey 
         ,  C_Contact1     
         ,  C_Phone1       
         ,  C_Address      
         ,  C_ZipCity      
         ,  C_Country      
         ,  C_Address4 
         ,  B_Contact2      
         ,  B_Address      
         ,  B_ZipCity      
         ,  B_Country      
         ,  ShipmentDate   
         ,  OrderType      
         ,  SalesMan       
         ,  Sku            
         ,  SkuDescr    
         ,  UOM   
         ,  QtyToProcess   
         ,  QtyShipped 
         ,  Summary        
         ,  TotalQtyShipped
         ,  M_Company --NJOW01
         ,  BuyerPO   --WL02
         )  
   SELECT  SortBy  = ROW_NUMBER() OVER (ORDER BY LP.Loadkey
                                                ,OH.Orderkey
                                                ,OH.Storerkey
                                                ,RTRIM(OD.Sku)
                                     )
         , PageGroup = RANK() OVER (   PARTITION BY 
                                                   LP.Loadkey
                                                ,  OH.Orderkey
                                       ORDER BY    LP.Loadkey
                                                ,  OH.Orderkey
                                         )

         , OH.Storerkey
         , LP.Loadkey
         , OH.Orderkey
         , Consigneekey   = ISNULL(RTRIM(OH.Consigneekey),'')
         , ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'')
         , C_Contact1= ISNULL(RTRIM(OH.C_Contact1),'')   
         , C_Phone1  = ISNULL(RTRIM(OH.C_Phone1),'')  
         , C_Address = ISNULL(RTRIM(OH.C_Address1),'') + ' '
                     + ISNULL(RTRIM(OH.C_Address2),'')  
         , C_ZipCity = ISNULL(RTRIM(OH.C_Zip),'') + ' '
                     + ISNULL(RTRIM(OH.C_City),'') 
         , C_Country = ISNULL(RTRIM(OH.C_Country),'')
         , C_Address4= ISNULL(RTRIM(OH.C_Address4),'')
         , B_Contact2= ISNULL(RTRIM(OH.B_Contact2),'')  
         , B_Address = ISNULL(RTRIM(OH.B_Address1),'') + ' '
                     + ISNULL(RTRIM(OH.B_Address2),'')  
         , B_ZipCity = ISNULL(RTRIM(OH.B_Zip),'') + ' '
                     + ISNULL(RTRIM(OH.B_City),'') 
         , B_Country = ISNULL(RTRIM(OH.B_Country),'')
         , ShipmentDate = OH.EditDate
         , OrderType = ISNULL(RTRIM(OH.[Type]),'')
         , Salesman  = ISNULL(RTRIM(OH.Salesman),'')
         , Sku    = RTRIM(OD.Sku)
         , Descr  = ISNULL(RTRIM(SKU.Busr4),'') + ' ' + ISNULL(RTRIM(SKU.Descr),'') 
         , OD.UOM
         , QtyToProcess = CONVERT(NVARCHAR(8),ISNULL(OD.OriginalQty,0)) + ' ' + OD.UOM
         , QtyShipped   = CASE WHEN OH.[Status] = '9' THEN ISNULL(SUM(OD.ShippedQty),0) ELSE ISNULL(SUM(OD.QtyPicked),0) END --WL03
         , Summary= '' --ISNULL(RTRIM(SKU.Busr2),'') --WL03
         , TotalQtyShipped = ''
         , M_Company= ISNULL(RTRIM(OH.M_Company),'')  --NJOW01
         , BuyerPO = ISNULL(OH.BuyerPO,'')            --WL02
   FROM #TMP_ORDERS LP
   JOIN ORDERS      OH WITH (NOLOCK) ON (LP.Orderkey = OH.Orderkey)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   JOIN SKU       SKU  WITH (NOLOCK) ON (OD.Storerkey= SKU.Storerkey)
                                     AND(OD.Sku = SKU.Sku)
   GROUP BY OH.Storerkey
         ,  LP.Loadkey
         ,  OH.Orderkey
         ,  ISNULL(RTRIM(OH.Consigneekey),'')
         ,  ISNULL(RTRIM(OH.ExternOrderkey),'')
         ,  ISNULL(RTRIM(OH.C_Contact1),'')   
         ,  ISNULL(RTRIM(OH.C_Phone1),'')  
         ,  ISNULL(RTRIM(OH.C_Address1),'')  
         ,  ISNULL(RTRIM(OH.C_Address2),'')  
         ,  ISNULL(RTRIM(OH.C_Zip),'')  
         ,  ISNULL(RTRIM(OH.C_City),'') 
         ,  ISNULL(RTRIM(OH.C_Country),'')
         ,  ISNULL(RTRIM(OH.C_Address4),'')
         ,  ISNULL(RTRIM(OH.B_Contact2),'') 
         ,  ISNULL(RTRIM(OH.B_Address1),'')  
         ,  ISNULL(RTRIM(OH.B_Address2),'')  
         ,  ISNULL(RTRIM(OH.B_Zip),'')  
         ,  ISNULL(RTRIM(OH.B_City),'') 
         ,  ISNULL(RTRIM(OH.B_Country),'')
         ,  OH.EditDate
         ,  ISNULL(RTRIM(OH.[Type]),'')
         ,  ISNULL(RTRIM(OH.Salesman),'')
         ,  RTRIM(OD.Sku)
         ,  ISNULL(RTRIM(SKU.Busr4),'')
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  CONVERT(NVARCHAR(8),ISNULL(OD.OriginalQty,0))
         ,  OD.UOM
         ,  ISNULL(RTRIM(SKU.Busr2),'')
         ,  ISNULL(RTRIM(OH.M_Company),'') --NJOW01
         ,  ISNULL(OH.BuyerPO,'')   --WL02
         ,  OH.[Status]  --WL03

   UPDATE INV
      SET Summary = (SELECT TOP 1 TMP.Summary FROM #TMP_INV TMP WHERE TMP.orderkey = INV.Orderkey) 
      ,   TotalQtyShipped = ( SELECT RTRIM(CONVERT(NVARCHAR(8), SUM(QtyShipped))) + ' ' + MAX(TMP.UOM) 
                              FROM #TMP_INV TMP WHERE TMP.orderkey = INV.Orderkey) 
   FROM #TMP_INV INV    

   --WL02 START - Below part not needed anymore
   --WL01 START
   /*DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
   SELECT DISTINCT Loadkey, OrderKey                
   FROM #TMP_INV                
                   
   OPEN CUR_LOOP                 
                   
   FETCH NEXT FROM CUR_LOOP INTO @c_GetLoadkey, @c_GetOrderkey                
   WHILE @@FETCH_STATUS <> -1                
   BEGIN
      INSERT INTO #TMP_INV_Final
         (
            SortBy         
         ,  PageGroup      
         ,  Storerkey      
         ,  Loadkey        
         ,  OrderKey       
         ,  Consigneekey   
         ,  ExternOrderkey 
         ,  C_Contact1     
         ,  C_Phone1       
         ,  C_Address      
         ,  C_ZipCity      
         ,  C_Country      
         ,  C_Address4 
         ,  B_Contact2      
         ,  B_Address      
         ,  B_ZipCity      
         ,  B_Country      
         ,  ShipmentDate   
         ,  OrderType      
         ,  SalesMan       
         ,  Sku            
         ,  SkuDescr    
         ,  UOM   
         ,  QtyToProcess   
         ,  QtyShipped 
         ,  Summary        
         ,  TotalQtyShipped
         ,  M_Company
         ,  RecGroup
         )                
      SELECT             
            SortBy         
         ,  PageGroup      
         ,  Storerkey      
         ,  Loadkey        
         ,  OrderKey       
         ,  Consigneekey   
         ,  ExternOrderkey 
         ,  C_Contact1     
         ,  C_Phone1       
         ,  C_Address      
         ,  C_ZipCity      
         ,  C_Country      
         ,  C_Address4 
         ,  B_Contact2      
         ,  B_Address      
         ,  B_ZipCity      
         ,  B_Country      
         ,  ShipmentDate   
         ,  OrderType      
         ,  SalesMan       
         ,  Sku            
         ,  SkuDescr    
         ,  UOM   
         ,  QtyToProcess   
         ,  QtyShipped 
         ,  Summary        
         ,  TotalQtyShipped
         ,  M_Company    
         , (Row_Number() OVER (PARTITION BY Loadkey, Orderkey ORDER BY Loadkey, Orderkey Asc)-1)/@n_MaxLineno + 1 AS recgroup                
      FROM  #TMP_INV               
      WHERE Loadkey = @c_GetLoadkey                
      AND OrderKey = @c_GetOrderkey                
      ORDER BY Loadkey,OrderKey        
                   
      SELECT @n_MaxRec = COUNT(RowRef)                 
      FROM #TMP_INV                 
      WHERE Loadkey = @c_GetLoadkey                
      AND OrderKey = @c_GetOrderkey                 
                   
      SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno                
                   
      WHILE(@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)             
      BEGIN                 
         INSERT INTO #TMP_INV_Final             
        (   SortBy         
         ,  PageGroup      
         ,  Storerkey      
         ,  Loadkey        
         ,  OrderKey       
         ,  Consigneekey   
         ,  ExternOrderkey 
         ,  C_Contact1     
         ,  C_Phone1       
         ,  C_Address      
         ,  C_ZipCity      
         ,  C_Country      
         ,  C_Address4 
         ,  B_Contact2      
         ,  B_Address      
         ,  B_ZipCity      
         ,  B_Country      
         ,  ShipmentDate   
         ,  OrderType      
         ,  SalesMan       
         ,  Sku            
         ,  SkuDescr    
         ,  UOM   
         ,  QtyToProcess   
         ,  QtyShipped 
         ,  Summary        
         ,  TotalQtyShipped
         ,  M_Company    
         )
         SELECT TOP 1            
            SortBy         
         ,  PageGroup      
         ,  Storerkey      
         ,  Loadkey        
         ,  OrderKey       
         ,  Consigneekey   
         ,  ExternOrderkey 
         ,  C_Contact1     
         ,  C_Phone1       
         ,  C_Address      
         ,  C_ZipCity      
         ,  C_Country      
         ,  C_Address4 
         ,  B_Contact2      
         ,  B_Address      
         ,  B_ZipCity      
         ,  B_Country      
         ,  ShipmentDate   
         ,  OrderType      
         ,  SalesMan       
         ,  ''            
         ,  ''    
         ,  UOM   
         ,  NULL  
         ,  NULL
         ,  Summary        
         ,  TotalQtyShipped
         ,  M_Company             
         FROM #TMP_INV_Final                 
         WHERE Loadkey = @c_GetLoadkey                
         AND OrderKey = @c_GetOrderkey             
         ORDER BY RowRef DESC                
                   
         SET @n_CurrentRec = @n_CurrentRec + 1                                 
      END                 
                   
      SET @n_MaxRec = 0                
      SET @n_CurrentRec = 0                
                   
      FETCH NEXT FROM CUR_LOOP INTO @c_GetLoadkey, @c_GetOrderkey                   
   END      
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP */              
   --WL01 END   
   --WL02 END - Below part not needed anymore          

QUIT_SP:
   SELECT   SortBy
         ,  PageGroup
         ,  C1 = @c_C1              
         ,  C2 = @c_C2              
         ,  C3 = @c_C3              
         ,  C4 = @c_C4              
         ,  C5 = @c_C5              
         ,  C6 = @c_C6              
         ,  C7 = @c_C7              
         ,  C8 = @c_C8              
         ,  C9 = @c_C9              
         ,  C10= @c_C10             
         ,  C11= @c_C11             
         ,  C12= @c_C12             
         ,  C13= @c_C13             
         ,  C14= @c_C14             
         ,  C15= @c_C15             
         ,  C16 = @c_C16             
         ,  C17= @c_C17             
         ,  C18= @c_C18             
         ,  C19= @c_C19             
         ,  C20= @c_C20             
         ,  C21= @c_C21             
         ,  C22= @c_C22             
         ,  C23= @c_C23             
         ,  C24= @c_C24             
         ,  C25= @c_C25             
         ,  C26= @c_C26             
         ,  C27= @c_C27             
         ,  C28= @c_C28             
         ,  C29= @c_C29             
         ,  C30= @c_C30             
         ,  C31= @c_C31             
         ,  C32= @c_C32             
         ,  Storerkey      
         ,  Loadkey        
         ,  OrderKey       
         ,  Consigneekey   
         ,  ExternOrderkey 
         ,  C_Contact1     
         ,  C_Phone1       
         ,  C_Address      
         ,  C_ZipCity      
         ,  C_Country      
         ,  C_Address4
         ,  B_Contact2     
         ,  B_Address      
         ,  B_ZipCity      
         ,  B_Country      
         ,  ShipmentDate 
         ,  @c_ShippingAgent  
         ,  OrderType      
         ,  SalesMan       
         ,  Sku            
         ,  SkuDescr       
         ,  QtyToProcess   
         ,  QtyShipped   
         ,  Summary        
         ,  TotalQtyShipped 
         ,  M_Company --NJOW01
         ,  C44= @c_C44  --WL02             
         ,  C45= @c_C45  --WL02 
         ,  BuyerPO      --WL02 
   FROM #TMP_INV  --WL01 --WL02
   ORDER BY RowRef
   --ORDER BY SortBy, Loadkey, Orderkey, CASE WHEN ISNULL(SKU,'') = '' THEN 1 ELSE 0 END, SKU, SkuDescr --WL01 --WL02

   DROP TABLE #TMP_INV
   DROP TABLE #TMP_ORDERS
END -- procedure

GO