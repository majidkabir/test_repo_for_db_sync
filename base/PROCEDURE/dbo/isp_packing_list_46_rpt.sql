SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_packing_list_46_rpt                                 */
/* Creation Date: 14-MAY-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4953 - CN_BTSEcom_PackingList_New                       */
/*        :                                                             */
/* Called By:                                                           */
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
CREATE PROC [dbo].[isp_packing_list_46_rpt]
           @c_StorerKey       NVARCHAR(15)
         , @c_Loadkey         NVARCHAR(10)
         , @c_Orderkey        NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_Title           NVARCHAR(10)
         , @c_TitleDesc       NVARCHAR(500)
         , @c_FooterDesc1     NVARCHAR(60)
         , @c_FooterDesc2     NVARCHAR(60)
         , @c_FooterDesc3     NVARCHAR(60)
         , @c_FooterDesc4     NVARCHAR(60)

         , @c_Single_Flag     NCHAR(1)

   SET @n_StartTCnt = @@TRANCOUNT

   CREATE TABLE #TMP_ORDERS 
         (  
            Orderkey NVARCHAR(10) NOT NULL PRIMARY KEY
         ,  Loadkey  NVARCHAR(10) NULL DEFAULT ('')
         )

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
      FROM LOADPLAN LP WITH (NOLOCK)
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

   SET @c_Single_Flag = ''
   SELECT TOP 1 @c_Single_Flag = OH.ECOM_SINGLE_FLAG
   FROM #TMP_ORDERS TMP
   JOIN ORDERS OH WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey)
   ORDER BY OH.ECOM_SINGLE_FLAG DESC


   SET @c_Title      = ''
   SET @c_TitleDesc  = ''     
   SET @c_FooterDesc1= ''
   SET @c_FooterDesc2= ''
   SET @c_FooterDesc3= ''
   SET @c_FooterDesc4= ''

   SELECT @c_Title       = ISNULL(RTRIM(CL.Short), '')
         ,@c_TitleDesc   = ISNULL(RTRIM(CL.Long), '') 
         ,@c_FooterDesc1 = ISNULL(RTRIM(CL.UDF01), '') 
         ,@c_FooterDesc2 = ISNULL(RTRIM(CL.UDF02), '') 
         ,@c_FooterDesc3 = ISNULL(RTRIM(CL.UDF03), '') 
         ,@c_FooterDesc4 = ISNULL(RTRIM(CL.UDF04), '')   
   FROM CODELKUP CL WITH (NOLOCK)  
   WHERE CL.ListName = 'BTSEPKLST'
   AND   CL.Code ='01'

   SELECT  SortBy  = ROW_NUMBER() OVER (ORDER BY LP.Loadkey
                                                ,CASE WHEN @c_Single_Flag = 'S' THEN '' ELSE OH.Orderkey END
                                                ,ISNULL(RTRIM(LOC.LogicalLocation),'')
                                                ,PD.Loc
                                                ,OD.Storerkey
                                                ,ISNULL(RTRIM(SKU.RetailSku),'')
                                     )
         , RowNo  = ROW_NUMBER() OVER ( PARTITION BY 
                                                 LP.Loadkey
                                                ,OH.Orderkey
                                        ORDER BY LP.Loadkey
                                                ,CASE WHEN @c_Single_Flag = 'S' THEN '' ELSE OH.Orderkey END
                                                ,ISNULL(RTRIM(LOC.LogicalLocation),'')
                                                ,PD.Loc
                                                ,OD.Storerkey
                                                ,ISNULL(RTRIM(SKU.RetailSku),'')
                                     )
         , Title       = @c_Title
         , TitleDesc   = @c_TitleDesc 
         , FooterDesc1 = @c_FooterDesc1
         , FooterDesc2 = @c_FooterDesc2
         , FooterDesc3 = @c_FooterDesc3
         , FooterDesc4 = @c_FooterDesc4
         , LP.Loadkey
         , OH.Orderkey
         , C_Company = ISNULL(RTRIM(OH.C_Company),'') 
         , C_Contact1  = ISNULL(RTRIM(OH.C_Contact1),'') + ' '  
         , C_Address1 = LEFT(ISNULL(RTRIM(OH.C_State),'') + ' '
                     + ISNULL(RTRIM(OH.C_City),'') + ' '
                     + ISNULL(RTRIM(OH.C_Address1),'') + ' '
                     + ISNULL(RTRIM(OH.C_Address2),'') + ' '    
                     + ISNULL(RTRIM(OH.C_Address3),'') + ' '    
                     + ISNULL(RTRIM(OH.C_Address4),''),26)
         , C_Address2 = SUBSTRING(ISNULL(RTRIM(OH.C_State),'') + ' '
                     + ISNULL(RTRIM(OH.C_City),'') + ' '
                     + ISNULL(RTRIM(OH.C_Address1),'') + ' '
                     + ISNULL(RTRIM(OH.C_Address2),'') + ' '    
                     + ISNULL(RTRIM(OH.C_Address3),'') + ' '    
                     + ISNULL(RTRIM(OH.C_Address4),''),27, 26)
         , C_Phone1  = ISNULL(RTRIM(OH.C_Phone1),'') + ' '  
         , Salesman  = ISNULL(RTRIM(OH.Salesman),'') 
         , OH.OrderDate  
         , OD.Storerkey
         , AltSKU = ISNULL(RTRIM(SKU.RetailSku),'')
         , Style  = ISNULL(RTRIM(SKU.Style),'')
         , Size   = ISNULL(RTRIM(SKU.Size),'')
         , ExternLineNo = CASE WHEN LEN(ISNULL(RTRIM(OD.ExternLineNo),'')) > 1 
                               THEN LEFT(ISNULL(RTRIM(OD.ExternLineNo),''), LEN(RTRIM(OD.ExternLineNo)) - 1)
                               ELSE ''
                               END
         , Qty = ISNULL(SUM(PD.Qty),0)
         , Price   = ISNULL(OD.UnitPrice, 0.00) * ISNULL(SUM(PD.Qty),0)
         , PD.Loc
         , Promotion      = ISNULL(RTRIM(OH.Notes),'')
         , DeliveryCharge = ISNULL(RTRIM(OH.UserDefine01),'')
         , ActualPay      = ISNULL(OH.InvoiceAmount,0.00)
   FROM #TMP_ORDERS LP
   JOIN ORDERS   OH WITH (NOLOCK) ON (LP.Orderkey = OH.Orderkey)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                                     AND(OD.OrderLineNumber = PD.OrderLineNumber)
   JOIN SKU       SKU  WITH (NOLOCK) ON (OD.Storerkey= SKU.Storerkey)
                                     AND(OD.Sku = SKU.Sku)
   JOIN LOC       LOC  WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
   WHERE LP.Loadkey = @c_Loadkey -- '0001718666'
   GROUP BY  LP.Loadkey
         , OH.Orderkey
         , ISNULL(RTRIM(OH.C_Company),'') 
         , ISNULL(RTRIM(OH.C_State),'') 
         , ISNULL(RTRIM(OH.C_City),'') 
         , ISNULL(RTRIM(OH.C_Address1),'') 
         , ISNULL(RTRIM(OH.C_Address2),'') 
         , ISNULL(RTRIM(OH.C_Address3),'') 
         , ISNULL(RTRIM(OH.C_Address4),'') 
         , ISNULL(RTRIM(OH.C_Contact1),'') 
         , ISNULL(RTRIM(OH.C_Phone1),'') 
         , OH.OrderDate  
         , ISNULL(RTRIM(OH.Salesman),'')  
         , OH.OrderDate  
         , OD.Storerkey
         , CASE WHEN LEN(ISNULL(RTRIM(OD.ExternLineNo),'')) > 1 
                THEN LEFT(ISNULL(RTRIM(OD.ExternLineNo),''), LEN(RTRIM(OD.ExternLineNo)) - 1)
                ELSE ''
                END
         , ISNULL(OD.UnitPrice, 0.00)
         , PD.Loc
         , ISNULL(RTRIM(SKU.RetailSku),'')
         , ISNULL(RTRIM(SKU.Style),'')
         , ISNULL(RTRIM(SKU.Size),'')
         , ISNULL(RTRIM(OH.Notes),'')
         , ISNULL(RTRIM(OH.UserDefine01),'')
         , ISNULL(OH.InvoiceAmount,0.00)
         , ISNULL(RTRIM(LOC.LogicalLocation),'')
   ORDER By SortBy

   DROP TABLE #TMP_ORDERS
END -- procedure

GO