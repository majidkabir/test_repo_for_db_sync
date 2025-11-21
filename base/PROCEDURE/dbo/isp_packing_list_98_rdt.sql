SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_packing_list_98_rdt                                 */
/* Creation Date: 24-MAR-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CHONG                                                    */
/*                                                                      */
/* Purpose: WMS-16528 - [KR] DW Packing List for B2C and Retail         */
/*        :                                                             */
/* Called By: r_dw_packing_list_98_rdt                                  */
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
CREATE PROC [dbo].[isp_packing_list_98_rdt]
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
                                     
   DECLARE @c_C1              NVARCHAR(80)  
         , @c_C2              NVARCHAR(80)  
         , @c_C3              NVARCHAR(80)  
         , @c_C4              NVARCHAR(80)  
         , @c_C5              NVARCHAR(80)  
         , @c_C6              NVARCHAR(80)  
         , @c_C7              NVARCHAR(80)  
         , @c_C8              NVARCHAR(80)  
         , @c_C9              NVARCHAR(80)  
         , @c_C10             NVARCHAR(80)  
         , @c_C11             NVARCHAR(80)  
         , @c_C12             NVARCHAR(80)  
         , @c_C13             NVARCHAR(80)  
         , @c_C14             NVARCHAR(80)  
         , @c_C15             NVARCHAR(80)  
         , @c_C16             NVARCHAR(80)  
         , @c_C17             NVARCHAR(80)  
         , @c_C18             NVARCHAR(80)  
         , @c_C19             NVARCHAR(80)  
         , @c_C20             NVARCHAR(80)  
         , @c_C21             NVARCHAR(80)  
         , @c_C22             NVARCHAR(80)  
         , @c_C23             NVARCHAR(80)  
         , @c_C24             NVARCHAR(80)  
         , @c_C25             NVARCHAR(80)  
         , @c_C26             NVARCHAR(80)  
         , @c_C27             NVARCHAR(80)  
         , @c_C28             NVARCHAR(250)  
         , @c_C29             NVARCHAR(250)  
         , @c_C30             NVARCHAR(80)  
         , @c_C31             NVARCHAR(80)  
         , @c_C32             NVARCHAR(80) 
         , @c_C44             NVARCHAR(80)   
         , @c_C45             NVARCHAR(80)   
         , @c_C46             NVARCHAR(80)   

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
      ,  SH_Company        NVARCHAR(45)   NULL
      ,  SH_MarketSegment  NVARCHAR(20)   NULL
      ,  SH_Address        NVARCHAR(95)   NULL
      ,  SH_ZipCity        NVARCHAR(65)   NULL
      ,  SH_State          NVARCHAR(45)   NULL
      ,  CartonNo          INT   NULL
      ,  SL_Company        NVARCHAR(45)   NULL
      ,  SBUSR897          NVARCHAR(95)   NULL
      ,  SBUSR10           INT            NULL
      ,  SKUGWGT           FLOAT   NULL      
      ,  ShipmentDate      DATETIME       NULL
      ,  Sku               NVARCHAR(20)   NULL
      ,  SkuDescr          NVARCHAR(100)  NULL
      ,  UOM               NVARCHAR(10)   NULL
      ,  Qty               INT  NULL
      ,  TTLQty            INT            NULL 
      )  

   CREATE TABLE #TMP_ORDERS 
         (  
            Orderkey NVARCHAR(10) NOT NULL PRIMARY KEY
         ,  Loadkey  NVARCHAR(10) NULL DEFAULT ('')
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
         ,@c_C44= ISNULL(MAX(CASE WHEN CL.Code = 'C44' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')  
         ,@c_C45= ISNULL(MAX(CASE WHEN CL.Code = 'C45' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')  
         ,@c_C46= ISNULL(MAX(CASE WHEN CL.Code = 'C46' THEN ISNULL(RTRIM(CL.Long),'') ELSE '' END),'')  
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'PLCONST'

   INSERT INTO #TMP_INV
         (
            SortBy         
         ,  PageGroup      
         ,  Storerkey      
         ,  Loadkey        
         ,  OrderKey       
         ,  Consigneekey   
         ,  ExternOrderkey 
         ,  SH_Company     
         ,  SH_MarketSegment       
         ,  SH_Address      
         ,  SH_ZipCity      
         ,  SH_State      
         ,  CartonNo 
         ,  SL_Company      
         ,  SBUSR897      
         ,  SBUSR10      
         ,  SKUGWGT      
         ,  ShipmentDate         
         ,  Sku            
         ,  SkuDescr    
         ,  UOM   
         ,  Qty   
         ,  TTLQty 
       
         )  
   SELECT  SortBy  = ROW_NUMBER() OVER (ORDER BY ISNULL(RTRIM(PD.CartonNo),''),LP.Loadkey
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
         , SH_Company     = ISNULL(RTRIM(ST.Company),'')   
         , SH_MarketSegment  = ISNULL(RTRIM(ST.MarketSegment),'')  
         , SH_Address = ISNULL(RTRIM(ST.Address1),'') + ' '
                     + ISNULL(RTRIM(ST.Address2),'')  
         , SH_ZipCity = ISNULL(RTRIM(ST.Zip),'') + ' '
                     + ISNULL(RTRIM(ST.City),'') 
         , SH_State = ISNULL(RTRIM(ST.State),'')
         , CartonNo= ISNULL(RTRIM(PD.CartonNo),'')
         , SL_Company= ISNULL(RTRIM(ST.Company),'')  
         , SBUSR897 = ISNULL(RTRIM(SKU.BUSR8),'') + '*'
                     + ISNULL(RTRIM(SKU.BUSR9),'') + '*'
                     + ISNULL(RTRIM(SKU.BUSR7),'') 
         , SBUSR10 = CASE WHEN ISNUMERIC(ISNULL(RTRIM(SKU.BUSR10),'0')) = 1 THEN CAST(ISNULL(RTRIM(SKU.BUSR10),0) AS INT) ELSE 0 END 
         , SKUGWGT = ISNULL(RTRIM(SKU.GrossWgt),'')
         , ShipmentDate = OH.EditDate
         , Sku    = RTRIM(OD.Sku)
         , Descr  = ISNULL(RTRIM(SKU.Descr),'') 
         , OD.UOM
         , Qty = SUM(PD.qty)
         , TTLQty   = 0
   FROM #TMP_ORDERS LP
   JOIN ORDERS      OH WITH (NOLOCK) ON (LP.Orderkey = OH.Orderkey)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   JOIN SKU       SKU  WITH (NOLOCK) ON (OD.Storerkey= SKU.Storerkey)
                                     AND(OD.Sku = SKU.Sku)
   JOIN dbo.STORER ST WITH (NOLOCK) ON ST.StorerKey = OH.StorerKey
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.OrderKey = LP.Orderkey
   JOIN dbo.Packdetail PD WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
   GROUP BY OH.Storerkey
         ,  LP.Loadkey
         ,  OH.Orderkey
         ,  ISNULL(RTRIM(OH.Consigneekey),'')
         ,  ISNULL(RTRIM(OH.ExternOrderkey),'')
         ,  ISNULL(RTRIM(ST.Company),'')   
         ,  ISNULL(RTRIM(ST.MarketSegment),'')  
         ,  ISNULL(RTRIM(ST.Address1),'')  
         ,  ISNULL(RTRIM(ST.Address2),'')  
         ,  ISNULL(RTRIM(OH.C_Zip),'')  
         ,  ISNULL(RTRIM(OH.C_City),'') 
         ,  ISNULL(RTRIM(ST.State),'')
         ,  ISNULL(RTRIM(PD.CartonNo),'')
         ,  ISNULL(RTRIM(ST.Company),'') 
         ,  ISNULL(RTRIM(SKU.BUSR8),'')
         ,  ISNULL(RTRIM(SKU.BUSR9),'')
         ,  ISNULL(RTRIM(SKU.BUSR7),'')
         ,  ISNULL(RTRIM(SKU.BUSR10),'') 
         ,  ISNULL(RTRIM(SKU.GrossWgt),'')
         ,  OH.EditDate
         ,  ISNULL(RTRIM(OH.[Type]),'')
         ,  ISNULL(RTRIM(OH.Salesman),'')
         ,  RTRIM(OD.Sku)
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  CONVERT(NVARCHAR(8),ISNULL(OD.OriginalQty,0))
         ,  OD.UOM
         ,  ISNULL(RTRIM(SKU.Busr2),'')
         ,  ISNULL(RTRIM(OH.M_Company),'') 
         ,  ISNULL(OH.BuyerPO,'')  
         ,  OH.[Status] 
         , ISNULL(RTRIM(ST.Zip),'') 
         , ISNULL(RTRIM(ST.City),'') 
         , SKU.BUSR10

   UPDATE INV
      SET   TTLQty = ( SELECT SUM(Qty) 
                       FROM #TMP_INV TMP WHERE TMP.orderkey = INV.Orderkey) 
   FROM #TMP_INV INV    
   

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
         ,  SH_Company     
         ,  SH_MarketSegment       
         ,  SH_Address      
         ,  SH_ZipCity      
         ,  SH_State      
         ,  CartonNo
         ,  SL_Company     
         ,  SBUSR897      
         ,  SBUSR10      
         ,  SKUGWGT      
         ,  ShipmentDate 
         ,  @c_ShippingAgent       
         ,  Sku            
         ,  SkuDescr       
         ,  Qty   
         ,  TTLQty   
         ,  C44= @c_C44            
         ,  C45= @c_C45   
         ,  C46= @c_C46
   FROM #TMP_INV  
   ORDER BY RowRef

   DROP TABLE #TMP_INV
   DROP TABLE #TMP_ORDERS
END -- procedure

GO