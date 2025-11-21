SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_MB_DELORDER_013                            */
/* Creation Date: 18-Aug-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23404 - SG - PMI - Delivery Note Report [CR]            */
/*                                                                      */
/* Called By: RPT_MB_DELORDER_013                                       */
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
CREATE   PROC [dbo].[isp_RPT_MB_DELORDER_013]
(@c_Mbolkey NVARCHAR(10))
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
         , @n_PrtAll   INT = 0

   CREATE TABLE #TMP_ORD
   (
      Orderkey NVARCHAR(10)
    , Sorting  NVARCHAR(500)
   )

   INSERT INTO #TMP_ORD (Orderkey, Sorting)
   SELECT DISTINCT POD.OrderKey, ISNULL(STORER.B_Contact2,'')
   FROM POD (NOLOCK)
   JOIN ORDERS (NOLOCK) ON ORDERS.Orderkey = POD.Orderkey
   JOIN STORER (NOLOCK) ON ORDERS.ConsigneeKey = STORER.StorerKey
   WHERE POD.Mbolkey = @c_Mbolkey 
   AND POD.RedeliveryDate IS NOT NULL
   AND POD.[Status] = '4'

   IF NOT EXISTS ( SELECT 1
                   FROM #TMP_ORD )
   BEGIN
      SET @n_PrtAll = 0

      IF NOT EXISTS ( SELECT 1
                      FROM POD (NOLOCK)
                      WHERE POD.Mbolkey = @c_Mbolkey 
                      AND POD.RedeliveryDate IS NOT NULL )
      BEGIN
         SET @n_PrtAll = 1
      END

      IF NOT EXISTS ( SELECT 1
                      FROM POD (NOLOCK)
                      WHERE POD.Mbolkey = @c_Mbolkey )
      BEGIN
         SET @n_PrtAll = 1
      END

      IF @n_PrtAll = 1
      BEGIN
         INSERT INTO #TMP_ORD (Orderkey, Sorting)
         SELECT DISTINCT MD.OrderKey, ISNULL(ST.B_Contact2,'')
         FROM MBOLDETAIL MD (NOLOCK)
         JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = MD.Orderkey
         JOIN STORER ST (NOLOCK) ON OH.ConsigneeKey = ST.StorerKey
         WHERE MD.MbolKey = @c_Mbolkey
      END
   END

   SELECT T.Orderkey
   FROM #TMP_ORD T (NOLOCK)
   GROUP BY T.Orderkey, T.Sorting
   ORDER BY T.Sorting

   IF OBJECT_ID('tempdb..#TMP_ORD') IS NOT NULL
      DROP TABLE #TMP_ORD

END -- procedure     

GO