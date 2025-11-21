SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_ptl_variance_report_02_rdt                      */
/* Creation Date: 25-OCT-2023                                            */
/* Copyright: MAERSK                                                     */
/* Written by: CSCHONG                                                   */
/*                                                                       */
/* Purpose: WMS-23265 - [CN]ANTA_variance_report_add field               */
/*                                                                       */
/* Called By: r_dw_ptl_variance_report_02_rdt                            */
/*                                                                       */
/* GitLab Version: 1.1                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 25-OCT-2023 CACHONG 1.0   DevOps Combine Script                       */
/*************************************************************************/

CREATE   PROC [dbo].[isp_ptl_variance_report_02_rdt]
(
   @c_Storerkey NVARCHAR(15)
 , @c_Station   NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Length INT = 2

   SELECT @n_Length = CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CL.Short ELSE 2 END
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.Listname = 'VARIANCRPT'
   AND CL.Storerkey = @c_Storerkey

   IF ISNULL(@n_Length, 0) = 0
      SET @n_Length = 2


   SELECT OH.LoadKey
        , PD.OrderKey
        , PTL.BatchKey
        , TRIM(PD.Sku) AS SKU
        , TRIM(PD.Loc) AS Loc
        , PD.Qty
        , RIGHT(TRIM(PTL.Position), @n_Length) AS Position   
        , PD.CaseID
        , OH.ECOM_Platform  --30   
        , OH.ShipperKey
        , S.BUSR2 --30
        , S.Color
        , S.Size                 
   FROM PICKDETAIL PD (NOLOCK)
   JOIN RDT.rdtPTLPieceLog PTL (NOLOCK) ON PD.PickSlipNo = PTL.BatchKey AND PD.OrderKey = PTL.OrderKey
   JOIN ORDERS OH (NOLOCK) ON PD.OrderKey = OH.OrderKey
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.Storerkey AND S.sku = PD.sku   
   WHERE PD.Storerkey = @c_Storerkey
   AND   PTL.Station = @c_Station
   AND   EXISTS (  SELECT 1
                   FROM PICKDETAIL PD2 (NOLOCK)
                   WHERE OH.StorerKey = PD2.Storerkey AND OH.OrderKey = PD2.OrderKey AND PD2.CaseID <> 'SORTED')
   ORDER BY PTL.Position
          , TRIM(PD.Sku)
END

GO