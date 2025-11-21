SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Delivery_Note53_RDT                                 */
/* Creation Date: 24-MAR-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-16527 - [KR] DW Delivery Note for B2C and Retail        */
/*        :                                                             */
/* Called By: r_dw_delivery_note53_rdt                                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_Delivery_Note53_RDT]
         @c_PickSlipNo  NVARCHAR(10)
        ,@c_rpttype     NVARCHAR(1) = 'H'
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
         , @c_C33             NVARCHAR(30) 
         , @c_C34             NVARCHAR(30)  
         , @c_C35             NVARCHAR(30)  
         , @c_C36             NVARCHAR(30) 
         , @c_C37             NVARCHAR(30) 
         , @c_C38             NVARCHAR(30) 
         , @c_C39             NVARCHAR(30) 
         , @c_C40             NVARCHAR(30)   
         , @c_C41             NVARCHAR(30)   
         , @c_C42             NVARCHAR(30)   
         , @c_C43             NVARCHAR(30)   
         , @c_C44             NVARCHAR(30)   
         , @c_C45             NVARCHAR(30)   

   DECLARE @n_MaxLineno       INT = 18
         , @n_MaxRec          INT  
         , @n_CurrentRec      INT
         , @c_GetLoadkey      NVARCHAR(10) 
         , @c_GetOrderkey     NVARCHAR(10) 
         , @c_logicalname     NVARCHAR(20) 


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
      ,  C_State           NVARCHAR(45)   NULL
      ,  C_Address4        NVARCHAR(45)   NULL
      ,  C_Contact2        NVARCHAR(30)   NULL 
      ,  B_Address         NVARCHAR(95)   NULL
      ,  B_ZipCity         NVARCHAR(65)   NULL
      ,  B_State           NVARCHAR(45)   NULL      
      ,  ShipmentDate      DATETIME       NULL
      ,  OrderType         NVARCHAR(10)   NULL 
      ,  SalesMan          NVARCHAR(30)   NULL
      ,  Sku               NVARCHAR(20)   NULL
      ,  SkuDescr          NVARCHAR(100)  NULL
      ,  UOM               NVARCHAR(10)   NULL
      ,  QtyToProcess      NVARCHAR(18)   NULL
      ,  QtyShipped        INT            NULL
      ,  Summary           NVARCHAR(250)  NULL --OHNotes
      ,  TotalQtyShipped   NVARCHAR(18)   NULL
      ,  M_Company         NVARCHAR(45)   NULL  
      ,  BuyerPO           NVARCHAR(20)   NULL 
      ,  OHUDF03           NVARCHAR(20)   NULL
      ,  SBUSR2            NVARCHAR(30)   NULL
      ,  QtyShippedUOM     NVARCHAR(18)   NULL
      ,  Logicalname       NVARCHAR(20)   NULL
      
      )  

   CREATE TABLE #TMP_ORDERS 
         (  
            Orderkey NVARCHAR(10) NOT NULL PRIMARY KEY
         ,  Loadkey  NVARCHAR(10) NULL DEFAULT ('')
         ,  Pickslipno        NVARCHAR(20) NULL DEFAULT ('')
         )

   SET @c_Storerkey = ''
   SET @c_Loadkey   = ''
   SET @c_Orderkey  = ''

   SELECT @c_Storerkey = PH.Storerkey 
         ,@c_Loadkey   = OH.Loadkey
         ,@c_Orderkey  = PH.Orderkey
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = PH.Orderkey
   WHERE PH.PickSlipNo = @c_PickSlipNo 

   IF ISNULL(RTRIM(@c_Orderkey),'') = ''
   BEGIN
      INSERT INTO #TMP_ORDERS
         (  
            Orderkey
         ,  Loadkey 
         ,  Pickslipno
         ) 
      SELECT DISTINCT
            LPD.Orderkey
         ,  LPD.Loadkey
         ,  @c_PickSlipNo
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
         ,  Pickslipno
         ) 
      VALUES  
         (  
            @c_Orderkey
         ,  @c_Loadkey 
         ,  @c_PickSlipNo
         ) 
   END

   SET @c_ShippingAgent = ''

   SELECT @c_ShippingAgent = ISNULL(RTRIM(CL.UDF05),'')
   FROM ORDERS OH WITH (NOLOCK)
   JOIN CODELKUP CL WITH (NOLOCK) ON CL.ListName = 'CartnTrack'
   AND   CL.Code     = OH.shipperkey --'YTC1'
   AND   CL.Storerkey= @c_Storerkey   
   WHERE OH.Orderkey = @c_Orderkey

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
         ,@c_C33= ISNULL(MAX(CASE WHEN CL.Code = 'C33' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C34= ISNULL(MAX(CASE WHEN CL.Code = 'C34' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'') 
         ,@c_C35= ISNULL(MAX(CASE WHEN CL.Code = 'C35' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C36= ISNULL(MAX(CASE WHEN CL.Code = 'C36' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C37= ISNULL(MAX(CASE WHEN CL.Code = 'C37' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C38= ISNULL(MAX(CASE WHEN CL.Code = 'C38' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C39= ISNULL(MAX(CASE WHEN CL.Code = 'C39' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')
         ,@c_C40= ISNULL(MAX(CASE WHEN CL.Code = 'C40' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')  
         ,@c_C41= ISNULL(MAX(CASE WHEN CL.Code = 'C41' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')   
         ,@c_C42= ISNULL(MAX(CASE WHEN CL.Code = 'C42' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')  
         ,@c_C43= ISNULL(MAX(CASE WHEN CL.Code = 'C43' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'') 
         ,@c_C44= ISNULL(MAX(CASE WHEN CL.Code = 'C44' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')  
         ,@c_C45= ISNULL(MAX(CASE WHEN CL.Code = 'C45' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')  
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'DNCONST'
   AND CL.Storerkey = @c_Storerkey  

    SET @c_logicalname = ''
    
    SELECT @c_logicalname = PT.logicalName
    FROM dbo.PackTask PT WITH (NOLOCK)
    JOIN #TMP_ORDERS TORD ON TORD.Orderkey = PT.Orderkey

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
         ,  C_State      
         ,  C_Address4 
         ,  C_Contact2      
         ,  B_Address      
         ,  B_ZipCity      
         ,  B_State      
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
         ,  BuyerPO   
         ,  OHUDF03
         ,  SBUSR2
         ,  QtyShippedUOM
         ,  Logicalname
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
         , C_State = ISNULL(RTRIM(OH.C_State),'')
         , C_Address4= ISNULL(RTRIM(OH.C_Address4),'')
         , C_Contact2= ISNULL(RTRIM(OH.C_Contact2),'')  
         , B_Address = ISNULL(RTRIM(OH.B_Address1),'') + ' '
                     + ISNULL(RTRIM(OH.B_Address2),'')  
         , B_ZipCity = ISNULL(RTRIM(OH.B_Zip),'') + ' '
                     + ISNULL(RTRIM(OH.B_City),'') 
         , B_State = ISNULL(RTRIM(OH.B_State),'')
         , ShipmentDate = OH.EditDate
         , OrderType = ISNULL(RTRIM(OH.[Type]),'')
         , Salesman  = ISNULL(RTRIM(OH.Salesman),'')
         , Sku    = RTRIM(OD.Sku)
         , Descr  = ISNULL(RTRIM(SKU.Busr4),'') + ' ' + ISNULL(RTRIM(SKU.Descr),'') 
         , OD.UOM
         , QtyToProcess = CONVERT(NVARCHAR(8),ISNULL(OD.OriginalQty,0)) + ' ' + OD.UOM
         , QtyShipped   = SUM(OD.QtyPicked + OD.QtyAllocated +OD.shippedqty)--CASE WHEN OH.[Status] = '9' THEN ISNULL(SUM(OD.ShippedQty),0) ELSE ISNULL(SUM(OD.QtyPicked),0) END --WL03
         , Summary= ISNULL(RTRIM(OH.notes),'') + ISNULL(RTRIM(OH.notes2),'')
         , TotalQtyShipped = ''
         , M_Company= ISNULL(RTRIM(OH.M_Company),'')  
         , BuyerPO = ISNULL(OH.BuyerPO,'')            
         , OHUDF03 =ISNULL(RTRIM(OD.UserDefine03),'') + ' ' + ISNULL(OD.notes,'')
         , SBUSR2 = ISNULL(RTRIM(SKU.Busr2),'')
         , QtyShippedUOM = CONVERT(NVARCHAR(8),ISNULL(SUM(OD.QtyPicked + OD.QtyAllocated +OD.shippedqty),0)) + ' ' + OD.UOM
         , Logicalname = @c_logicalname
   FROM #TMP_ORDERS LP
   JOIN ORDERS      OH WITH (NOLOCK) ON (LP.Orderkey = OH.Orderkey)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   JOIN SKU       SKU  WITH (NOLOCK) ON (OD.Storerkey= SKU.Storerkey)
                                     AND(OD.Sku = SKU.Sku)
  -- LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'DWSKUGROUP' AND C.Long = SKU.Busr2 AND C.UDF01 <> 'Box' 
   WHERE OD.OriginalQty > 0 
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
         ,  ISNULL(RTRIM(OH.C_State),'')
         ,  ISNULL(RTRIM(OH.C_Address4),'')
         ,  ISNULL(RTRIM(OH.C_Contact2),'') 
         ,  ISNULL(RTRIM(OH.B_Address1),'')  
         ,  ISNULL(RTRIM(OH.B_Address2),'')  
         ,  ISNULL(RTRIM(OH.B_Zip),'')  
         ,  ISNULL(RTRIM(OH.B_City),'') 
         ,  ISNULL(RTRIM(OH.B_State),'')
         ,  OH.EditDate
         ,  ISNULL(RTRIM(OH.[Type]),'')
         ,  ISNULL(RTRIM(OH.Salesman),'')
         ,  RTRIM(OD.Sku)
         ,  ISNULL(RTRIM(SKU.Busr4),'')
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  CONVERT(NVARCHAR(8),ISNULL(OD.OriginalQty,0))
         ,  OD.UOM
         ,  ISNULL(RTRIM(SKU.Busr2),'')
         ,  ISNULL(RTRIM(OH.M_Company),'') 
         ,  ISNULL(OH.BuyerPO,'')  
         ,  OH.[Status] 
         ,  ISNULL(RTRIM(OH.notes),'') 
         , ISNULL(RTRIM(OH.notes2),'')     
         , ISNULL(RTRIM(OD.UserDefine03),'') + ' ' + ISNULL(OD.notes,'')

   UPDATE INV
      SET TotalQtyShipped = ( SELECT RTRIM(CONVERT(NVARCHAR(8), SUM(QtyShipped))) + ' ' + MAX(TMP.UOM) 
                              FROM #TMP_INV TMP WHERE TMP.orderkey = INV.Orderkey) 
   FROM #TMP_INV INV    

IF @c_rpttype = 'H'
BEGIN
   GOTO Header
END
ELSE
BEGIN
     GOTO Detail
END

Header:
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
         ,  C_State      
         ,  C_Address4
         ,  C_Contact2     
         ,  B_Address      
         ,  B_ZipCity      
         ,  B_State      
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
         ,  M_Company 
         ,  C44= @c_C44              
         ,  C45= @c_C45  
         ,  BuyerPO    
         ,  OHUDF03
         ,  SBUSR2 
         ,  C33= @c_C33             
         ,  C34= @c_C34             
         ,  C35= @c_C35   
         ,  C36= @c_C36            
         ,  C37= @c_C37             
         ,  C38= @c_C38   
         ,  C39= @c_C39             
         ,  C40= @c_C40             
         ,  C41= @c_C41   
         ,  C42= @c_C42             
         ,  C43= @c_C43  
         ,  QtyShippedUOM
         , Logicalname
         ,Pickslipno = @c_PickSlipNo
   FROM #TMP_INV  
   ORDER BY RowRef

GOTO QUIT_SP

DETAIL:

SELECT SBUSR2,QtyShippedUOM,@c_C20 AS c20, @c_C21 AS c21
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
         ,  C33= @c_C33             
         ,  C34= @c_C34             
         ,  C35= @c_C35   
         ,  C36= @c_C36            
         ,  C37= @c_C37             
         ,  C38= @c_C38   
         ,  C39= @c_C39             
         ,  C40= @c_C40             
         ,  C41= @c_C41   
         ,  C42= @c_C42             
         ,  C43= @c_C43   
FROM #TMP_INV
JOIN #TMP_ORDERS ON #TMP_ORDERS.Orderkey = #TMP_INV.OrderKey
ORDER BY RowRef

GOTO QUIT_SP

QUIT_SP:

   DROP TABLE #TMP_INV
   DROP TABLE #TMP_ORDERS
END -- procedure

GO