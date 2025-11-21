SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_ptl_variance_report_01_rdt                      */
/* Creation Date: 21-May-2023                                            */
/* Copyright: MAERSK                                                     */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-22521 - CN PVH Variance Report                           */
/*                                                                       */
/* Called By: r_dw_ptl_variance_report_01_rdt                            */
/*                                                                       */
/* GitLab Version: 1.1                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 21-May-2023 WLChooi 1.0   DevOps Combine Script                       */
/* 31-May-2023 WLChooi 1.1   WMS-22521 - Codelkup to control length of   */
/*                           position (WL01)                             */
/*************************************************************************/

CREATE   PROC [dbo].[isp_ptl_variance_report_01_rdt]
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

   --WL01 S
   DECLARE @n_Length INT = 2

   SELECT @n_Length = CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CL.Short ELSE 2 END
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.Listname = 'VARIANCRPT'
   AND CL.Storerkey = @c_Storerkey

   IF ISNULL(@n_Length, 0) = 0
      SET @n_Length = 2
   --WL01 E

   SELECT OH.LoadKey
        , PD.OrderKey
        , PTL.BatchKey
        , TRIM(PD.Sku) AS SKU
        , TRIM(PD.Loc) AS Loc
        , PD.Qty
        , RIGHT(TRIM(PTL.Position), @n_Length) AS Position   --WL01
        , PD.CaseID
   FROM PICKDETAIL PD (NOLOCK)
   JOIN RDT.rdtPTLPieceLog PTL (NOLOCK) ON PD.PickSlipNo = PTL.BatchKey AND PD.OrderKey = PTL.OrderKey
   JOIN ORDERS OH (NOLOCK) ON PD.OrderKey = OH.OrderKey
   WHERE PD.Storerkey = @c_Storerkey
   AND   PTL.Station = @c_Station
   AND   EXISTS (  SELECT 1
                   FROM PICKDETAIL PD2 (NOLOCK)
                   WHERE OH.StorerKey = PD2.Storerkey AND OH.OrderKey = PD2.OrderKey AND PD2.CaseID <> 'SORTED')
   ORDER BY PTL.Position
          , TRIM(PD.Sku)
END

GO