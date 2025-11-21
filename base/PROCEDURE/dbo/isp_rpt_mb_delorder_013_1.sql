SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_MB_DELORDER_013_1                          */
/* Creation Date: 18-Aug-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23404 - SG - PMI - Delivery Note Report [CR]            */
/*                                                                      */
/* Called By: RPT_MB_DELORDER_013_1                                     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 18-Aug-2023  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_MB_DELORDER_013_1]
(@c_Orderkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue INT = 1
         , @c_errmsg   NVARCHAR(255)
         , @b_success  INT
         , @n_err      INT

   ;WITH CTE AS (
   SELECT OH.Orderkey
        , ISNULL(C1.DESCR,'') AS DESCR
        , CAST(SUM(OD.EnteredQTY) / PK.OtherUnit1 AS INT) AS OrdQtyCtn
        , CAST((SUM(OD.EnteredQTY) - SUM(ISNULL(PD.Qty, 0))) / PK.OtherUnit1 AS INT) AS OOSQtyCtn
        , OH.ExternOrderKey
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   OUTER APPLY ( SELECT SUM(PICKDETAIL.Qty) AS Qty
                 FROM PICKDETAIL (NOLOCK)
                 WHERE PICKDETAIL.Orderkey = OD.Orderkey
                 AND PICKDETAIL.OrderLineNumber = OD.OrderLineNumber
                 AND PICKDETAIL.Sku = OD.Sku ) AS PD
   JOIN SKU S (NOLOCK) ON S.StorerKey = OD.Storerkey AND S.Sku = OD.Sku
   JOIN PACK PK (NOLOCK) ON PK.PackKey = S.PACKKey
   LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.Consigneekey
   OUTER APPLY ( SELECT TOP 1 ISNULL(CL.[Description],'') AS DESCR
                 FROM CODELKUP CL (NOLOCK)
                 WHERE CL.LISTNAME = 'GROUPSKU' 
                 AND CL.code2 = OD.ALTSKU 
                 AND CL.Storerkey = OD.StorerKey
                 AND CL.Code = IIF(ISNULL(ST.[Secondary],'') = '', 'PMIDN', ST.[Secondary]) ) AS C1
   WHERE OH.[Type] = 'CCB2B' AND OH.OrderKey = @c_Orderkey
   AND OH.[Status] >= '5'
   GROUP BY OH.OrderKey
          , ISNULL(C1.DESCR,'')
          , PK.OtherUnit1
          , OH.ExternOrderKey )
   SELECT Orderkey
        , DESCR
        , OrdQtyCtn
        , OOSQtyCtn
        , ExternOrderKey
   FROM CTE
   WHERE (OOSQtyCtn > 0)
   ORDER BY CTE.DESCR

   IF OBJECT_ID('tempdb..#TMP_ORD') IS NOT NULL
      DROP TABLE #TMP_ORD

END -- procedure     

GO