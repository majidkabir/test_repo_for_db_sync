SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_packing_list_101_ByteDance                          */
/* Creation Date: 24-FEB-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-18985 CN_Converse_PackList_ByteDance_CR                 */
/*        :                                                             */
/* Called By: r_dw_packing_list_101_ByteDance                           */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 24-FEB-2022 CSCHONG  1.0   Devops Scripts Combine                    */
/* 22-Apr-2022 WLChooi  1.1   WMS-19530 Add codelkup show address (WL01)*/
/* 14-Jul-2022 WLChooi  1.2   WMS-20244 Modify SKU Logic (WL02)         */
/************************************************************************/
CREATE PROC [dbo].[isp_packing_list_101_ByteDance]
           @c_PickSlipNo      NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @n_NoOfLine        INT
         , @c_Orderkey        NVARCHAR(20)
         , @c_OHUDF03         NVARCHAR(50)
         , @c_storerkey       NVARCHAR(20)
         , @c_rpttype         NVARCHAR(20)
         , @c_OIFNotes        NVARCHAR(120) = ''
         , @c_showqrcode      NVARCHAR(1) = 'Y'
         , @c_CONRTNADD       NVARCHAR(500) = '' --WL01

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_NoOfLine = 3
   SET @c_Orderkey = ''


   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)
              WHERE Orderkey = @c_PickSlipNo)
   BEGIN
      SET @c_Orderkey = @c_PickSlipNo
   END
   ELSE
   BEGIN
      SELECT DISTINCT @c_Orderkey = OrderKey
      FROM PackHeader AS ph WITH (NOLOCK)
      WHERE ph.PickSlipNo=@c_PickSlipNo
   END


   SELECT  @c_OHUDF03 = OH.Userdefine03
          ,@c_storerkey = OH.Storerkey      
   FROM ORDERS OH WITH (NOLOCK)
   WHERE OH.Orderkey = @c_Orderkey

   SELECT @c_rpttype = RTRIM(C.short)
   FROM Codelkup  C WITH (nolock)
   WHERE c.listname = 'CONVSTORE'
   AND C.code = @c_OHUDF03
   AND C.storerkey = @c_storerkey

   --WL01 S
   SELECT @c_CONRTNADD = ISNULL(C.notes,'')
   FROM Codelkup C WITH (NOLOCK)
   WHERE C.listname = 'CONVSTORE'
   AND C.code = 'CONVSTORERTNADD'
   AND C.storerkey = @c_storerkey
   --WL01 E

   --IF ISNULL(@c_rpttype,'') = ''
   --BEGIN
   --   SET @c_rpttype = 'ByteDance'
   --END


   SELECT @c_OIFNotes = ISNULL(OIF.notes,'')
   FROM dbo.OrderInfo OIF WITH (NOLOCK)
   WHERE OIF.OrderKey = @c_Orderkey


   IF ISNULL(@c_OIFNotes,'') = ''
   BEGIN
      SET @c_showqrcode = 'N'
   END

   SELECT  SortBy = ROW_NUMBER() OVER ( ORDER BY ISNULL(PH.PickSlipNo,'')
                                                ,OH.Storerkey
                                                ,OH.Orderkey
                                                --,ISNULL(RTRIM(SKU.Manufacturersku),RTRIM(SKU.sku))   --WL02 S
                                                ,CASE WHEN ISNULL(SKU.Manufacturersku,'') = '' 
                                                      THEN CASE WHEN SKU.RETAILSKU LIKE '69%' THEN SKU.RETAILSKU
                                                                WHEN SKU.ALTSKU LIKE '69%' THEN SKU.ALTSKU
                                                                ELSE SKU.SKU END
                                                      ELSE SKU.Manufacturersku END   --WL02 E
                                     )
         , RowNo  = ROW_NUMBER() OVER ( PARTITION BY ISNULL(PH.PickSlipNo,'')
                                        ORDER BY ISNULL(PH.PickSlipNo,'')
                                                ,OH.Storerkey
                                                ,OH.Orderkey
                                                --,ISNULL(RTRIM(SKU.Manufacturersku),RTRIM(SKU.sku))   --WL02 S
                                                ,CASE WHEN ISNULL(SKU.Manufacturersku,'') = '' 
                                                      THEN CASE WHEN SKU.RETAILSKU LIKE '69%' THEN SKU.RETAILSKU
                                                                WHEN SKU.ALTSKU LIKE '69%' THEN SKU.ALTSKU
                                                                ELSE SKU.SKU END
                                                      ELSE SKU.Manufacturersku END   --WL02 E
                                      )
         , PrintTime      = GETDATE()
         , OH.Storerkey
         , ISNULL(PH.PickSlipNo,'')
         , OH.Loadkey
         , OH.Orderkey
         , OHUDF03 = ISNULL(RTRIM(OH.UserDefine03),'')
         , ExternOrderkey = ISNULL(RTRIM(UPPER(OH.ExternOrderkey)),'')
         , SSUSR5  = ISNULL(RTRIM(SKU.SUSR5),'')  --18
         , C_Contact1= ISNULL(RTRIM(OH.C_Contact1),'')
         , C_Phone1  = ISNULL(RTRIM(OH.C_Phone1),'')
         , C_Address = ISNULL(RTRIM(OH.C_State),'') + ' '
                     + ISNULL(RTRIM(OH.B_Address1),'') + ' '
                     + ISNULL(RTRIM(OH.C_Address2),'')
         --, C_Address = ISNULL(RTRIM(OH.C_Address2),'')
         --, Manufacturersku  = ISNULL(RTRIM(SKU.Manufacturersku),RTRIM(SKU.sku))   --WL02 S
         , Manufacturersku  = CASE WHEN ISNULL(SKU.Manufacturersku,'') = '' 
                                   THEN CASE WHEN SKU.RETAILSKU LIKE '69%' THEN SKU.RETAILSKU
                                             WHEN SKU.ALTSKU LIKE '69%' THEN SKU.ALTSKU
                                             ELSE SKU.SKU END
                                   ELSE SKU.Manufacturersku END   --WL02 E
         , RecGrp  =  (ROW_NUMBER() OVER ( PARTITION BY ISNULL(PH.PickSlipNo,''),OH.Orderkey
                                        ORDER BY ISNULL(PH.PickSlipNo,'')
                                                ,OH.Storerkey
                                                ,OH.Orderkey
                                                --,ISNULL(RTRIM(SKU.Manufacturersku),RTRIM(SKU.sku))   --WL02 S
                                                ,CASE WHEN ISNULL(SKU.Manufacturersku,'') = '' 
                                                      THEN CASE WHEN SKU.RETAILSKU LIKE '69%' THEN SKU.RETAILSKU
                                                                WHEN SKU.ALTSKU LIKE '69%' THEN SKU.ALTSKU
                                                                ELSE SKU.SKU END
                                                      ELSE SKU.Manufacturersku END)-1)/@n_NoOfLine   --WL02 E
         , SkuDesr = ISNULL(RTRIM(SKU.Descr),'')
         , Qty = ISNULL(SUM(OD.originalqty),0)
         , TrackingNo = OH.TrackingNo
         , AddDate = CONVERT(NVARCHAR(10),OH.AddDate,120)
         , SKUSize = CASE sku.Busr8 WHEN '20' THEN SKU.Size WHEN '10' THEN sku.Measurement
                     WHEN '30' THEN CASE WHEN ISNULL(sku.Measurement,'') = '' THEN SKU.Size ELSE sku.Measurement END ELSE sku.Busr8 END
         , RptType = @c_rpttype
         , showqrcode = @c_showqrcode
         , qrvalue = @c_OIFNotes
         , CONRTNADD = @c_CONRTNADD   --WL01
   FROM ORDERS     OH WITH (NOLOCK)
   LEFT JOIN PACKHEADER PH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey
   --JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
   JOIN SKU       SKU WITH (NOLOCK) ON (OD.Storerkey= SKU.Storerkey)
                                    AND(OD.Sku = SKU.Sku)
   WHERE OH.orderkey = @c_Orderkey
   GROUP BY ISNULL(PH.PickSlipNo,'')
         ,  OH.Storerkey
         ,  OH.Loadkey
         ,  OH.Orderkey
         ,  ISNULL(RTRIM(OH.UserDefine03),'')
         ,  ISNULL(RTRIM(UPPER(OH.ExternOrderkey)),'')
         ,  ISNULL(RTRIM(SKU.SUSR5),'')
         ,  ISNULL(RTRIM(OH.C_Contact1),'')
         ,  ISNULL(RTRIM(OH.C_Phone1),'')
         ,  ISNULL(RTRIM(OH.C_State),'')
         ,  ISNULL(RTRIM(OH.B_Address1),'')
         ,  ISNULL(RTRIM(OH.C_Address2),'')
         --,ISNULL(RTRIM(SKU.Manufacturersku),RTRIM(SKU.sku))   --WL02 S
         ,  CASE WHEN ISNULL(SKU.Manufacturersku,'') = '' 
                 THEN CASE WHEN SKU.RETAILSKU LIKE '69%' THEN SKU.RETAILSKU
                           WHEN SKU.ALTSKU LIKE '69%' THEN SKU.ALTSKU
                           ELSE SKU.SKU END
                 ELSE SKU.Manufacturersku END   --WL02 E
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  OH.TrackingNo
         ,  CONVERT(NVARCHAR(10),OH.AddDate,120)
         , CASE sku.Busr8 WHEN '20' THEN SKU.Size WHEN '10' THEN sku.Measurement
                     WHEN '30' THEN CASE WHEN ISNULL(sku.Measurement,'') = '' THEN SKU.Size ELSE sku.Measurement END ELSE sku.Busr8 END

END -- procedure

GO