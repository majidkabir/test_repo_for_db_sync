SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_carton_manifest_11_rdt                     */
/* Creation Date: 14-Sep-2020                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: PVH HK Carton Manifest                                       */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_carton_manifest_11_rdt      */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 2020-10-14   ML       1.1  Fix duplicated PackQty issue               */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_carton_manifest_11_rdt] (
           @as_pickslipno     NVARCHAR(20)
        ,  @as_startcartonno  NVARCHAR(20)
        ,  @as_endcartonno    NVARCHAR(20)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF


   SELECT PickslipNo   = RTRIM(ISNULL(PH.Pickslipno, ''))
        , CustPO       = ISNULL(MAX(CASE ISNULL(OH1.Type,OH2.Type)
                            WHEN '2' THEN 'L'
                            WHEN '3' THEN 'S'
                            WHEN '4' THEN 'R'
                         END + FORMAT(ISNULL(OH1.DeliveryDate,OH2.DeliveryDate),'yyyyMMdd')), '')
        , OrdExtOrdKey = ISNULL(RTRIM( MAX(CASE WHEN OH1.Orderkey IS NOT NULL
                              THEN IIF(OG1.UDF01='R', OH1.Loadkey, OH1.ExternOrderkey)
                              ELSE IIF(OG2.UDF01='R', OH2.Loadkey, OH2.ExternOrderkey)
                         END)), '')
        , CartonNo     = PD.CartonNo
        , PDLabelNo    = RTRIM(ISNULL(PD.Labelno    , ''))
        , SKUColor     = RTRIM(ISNULL(MAX(SKU.color), ''))
        , SKUStyle     = RTRIM(ISNULL(MAX(SKU.Style), ''))
        , SKUSize      = RTRIM(ISNULL(MAX(SKU.Size ), ''))
        , PDQty        = MAX( PD.qty  )
        , SMeasument   = RTRIM(ISNULL(MAX(SKU.Measurement), ''))
        , BUSR1        = RTRIM(ISNULL(MAX(SKU.BUSR1), ''))
        , Sku          = RTRIM(ISNULL(PD.SKU        , ''))
        , MaxCtn       = ISNULL(MAX(TTLCTN.TTL_Carton),0)

   FROM dbo.PACKHEADER PH (NOLOCK)
   JOIN (
      SELECT PickslipNo, CartonNo, LabelNo, Storerkey, Sku
           , Qty = SUM(Qty)
      FROM dbo.PACKDETAIL (NOLOCK)
      WHERE Pickslipno = @as_pickslipno
        AND CartonNo BETWEEN TRY_PARSE(ISNULL(@as_startcartonno,'') AS INT) AND TRY_PARSE(ISNULL(@as_endcartonno,'') AS INT)
      GROUP BY Pickslipno, CartonNo, Labelno, Storerkey, Sku
   ) PD ON PH.Pickslipno = PD.Pickslipno
   JOIN dbo.SKU            SKU(NOLOCK) ON SKU.Storerkey = PD.Storerkey and SKU.SKU = PD.SKU

   LEFT JOIN dbo.ORDERS    OH1(NOLOCK) ON PH.Orderkey = OH1.Orderkey AND ISNULL(PH.Orderkey,'')<>''
   LEFT JOIN dbo.CODELKUP  OG1(NOLOCK) ON OG1.LISTNAME  = 'ORDERGROUP' AND OG1.Code = OH1.OrderGroup AND OG1.Storerkey = OH1.Storerkey

   LEFT JOIN dbo.ORDERS    OH2(NOLOCK) ON PH.Loadkey = OH2.Loadkey AND ISNULL(PH.Orderkey,'')='' AND ISNULL(OH2.Loadkey,'')<>''
   LEFT JOIN dbo.CODELKUP  OG2(NOLOCK) ON OG2.LISTNAME  = 'ORDERGROUP' AND OG2.Code = OH2.OrderGroup AND OG2.Storerkey = OH2.Storerkey

   LEFT JOIN (
      SELECT PH.PickslipNo
           , TTL_Carton = COUNT(DISTINCT PD.CartonNo)
        FROM PACKHEADER PH(NOLOCK)
        JOIN PACKDETAIL PD(NOLOCK) ON PH.PickSlipNo=PD.PickSlipNo
		JOIN STORER     ST(NOLOCK) ON PH.Storerkey=ST.Storerkey
       WHERE PH.PickslipNo = @as_pickslipno
	     AND (ISNULL(ST.SUSR4,'')<>'Y' OR PH.Status='9')
       GROUP BY PH.PickSlipNo
   ) TTLCTN ON PH.PickslipNo = TTLCTN.PickslipNo

   WHERE PH.Pickslipno = @as_pickslipno

   GROUP BY PH.Pickslipno, PD.CartonNo, PD.Labelno, PD.Sku

   ORDER BY PickslipNo, CartonNo, SKUStyle, SKUColor, SKUSize

END

GO