SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_RPT_LP_LOADSHEET_007                            */
/* Creation Date: 02-Mar-2023                                            */
/* Copyright: LFL                                                        */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-21877 - [CN] ROAM_Replenishment Report_New               */
/*                                                                       */
/* Called By: RPT_LP_LOADSHEET_007                                       */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 02-Mar-2023 WLChooi 1.0   DevOps Combine Script                       */
/*************************************************************************/
CREATE   PROC [dbo].[isp_RPT_LP_LOADSHEET_007]
(@c_LoadKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   DECLARE @n_Continue     INT
         , @b_Debug        INT
         , @n_StartTranCnt INT

   DECLARE @c_SKU       NVARCHAR(30)
         , @c_Storerkey NVARCHAR(15)

   SELECT @n_StartTranCnt = @@TRANCOUNT
        , @n_Continue = 1

   CREATE TABLE #Temp_RoamReplen
   (
      StorerKey     NVARCHAR(10) NULL
    , SKU           NVARCHAR(20) NULL
    , Descr         NVARCHAR(50) NULL
    , OrdTotalBySKU NVARCHAR(30) NULL
    , Level1        NVARCHAR(30) NULL
    , NeedBySKU     NVARCHAR(30) NULL
    , CtnNo         NVARCHAR(10) NULL
    , Fromloc       NVARCHAR(30) NULL
    , AvailableQty  INT          NULL
    , MinLott05     DATETIME     NULL
   )

   DECLARE cur_SKU CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT OD.StorerKey
        , OD.Sku
   FROM LoadPlanDetail LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   WHERE LPD.LoadKey = @c_LoadKey
   AND OH.[Status] = '0'
   GROUP BY OD.StorerKey
          , OD.Sku

   OPEN cur_SKU
   FETCH NEXT FROM cur_SKU
   INTO @c_Storerkey
      , @c_SKU

   WHILE @@FETCH_STATUS = 0
   BEGIN
      --To sum total qty by cursor sku
      WITH OrderSum AS
      (
         SELECT OH.StorerKey
              , OD.Sku
              , S.DESCR
              , SUM(OD.OriginalQty) AS OpenQty
         FROM LoadPlanDetail LPD (NOLOCK)
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
         JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
         JOIN SKU S (NOLOCK) ON S.Sku = OD.Sku AND S.StorerKey = OD.StorerKey
         WHERE OD.StorerKey = @c_Storerkey AND OD.Sku = @c_SKU 
         AND OH.[Status] = '0'
         GROUP BY OH.StorerKey
                , OD.Sku
                , S.DESCR
      )
         --To sum total available qty in LocLevel = '2' by cursor sku
         , InvByLocLevel2 AS
      (
         SELECT LLI.StorerKey
              , LLI.Sku
              , Loc.Loc
              , LLI.ID
              , SUM(LLI.Qty - LLI.QtyAllocated - QtyPicked - LLI.QtyExpected) AS Qty2
         FROM LOTxLOCxID LLI (NOLOCK)
         JOIN LOC Loc (NOLOCK) ON LLI.Loc = Loc.Loc
         JOIN LOTATTRIBUTE LA (NOLOCK) ON (LLI.Sku = LA.Sku AND LLI.Lot = LA.Lot)
         WHERE LLI.StorerKey = @c_Storerkey AND LLI.Sku = @c_SKU AND Loc.LocLevel = '2' 
         AND Loc.LocationFlag IN ('NONE')
         AND Loc.LocationFlag <> 'HOLD'
         GROUP BY LLI.StorerKey
                , LLI.Sku
                , Loc.Loc
                , LLI.ID
         HAVING SUM(LLI.Qty - LLI.QtyAllocated - QtyPicked - LLI.QtyExpected) > 0
      )
         --1.To sum total available qty in LocLevel = '0'  partiton by sku,order by qty desc  by cursor sku
         --2.To sum Accum qty in LocLevel = '0' order by LLI.Minlot,LLI.Qty2 asc
         , InvByLocLevel0 AS
      (
         SELECT LLI.StorerKey
              , LLI.Sku
              , LLI.Loc
              , LLI.ID
              , LLI.Qty0
              , LLI.Minlot
              , LLI.Rn
              , SUM(LLI.Qty0) OVER (ORDER BY LLI.Minlot
                                           , LLI.Qty0 ASC) AS Accum
         FROM (  SELECT LLI.StorerKey
                      , LLI.Sku
                      , LLI.Loc
                      , CASE WHEN ISNULL(LLI.Id, '') = '' THEN N'此Level0库位无ID/UCC,请核实!'
                             ELSE ISNULL(LLI.Id, '')END AS ID
                      , SUM(LLI.Qty - LLI.QtyAllocated - QtyPicked - LLI.QtyExpected) AS Qty0
                      , MIN(LA.Lottable05) AS Minlot
                      , ROW_NUMBER() OVER (PARTITION BY LLI.Sku
                                           ORDER BY SUM(LLI.Qty - LLI.QtyAllocated - QtyPicked - LLI.QtyExpected) DESC) AS Rn
                 FROM LOTxLOCxID LLI (NOLOCK)
                 JOIN LOC Loc (NOLOCK) ON LLI.Loc = Loc.Loc
                 JOIN LOTATTRIBUTE LA (NOLOCK) ON (LLI.Sku = LA.Sku AND LLI.Lot = LA.Lot)
                 WHERE LLI.StorerKey = @c_Storerkey
                 AND   LLI.Sku = @c_SKU
                 AND   Loc.LocLevel IN ('0','1')
                 AND   Loc.LocationFlag IN ('NONE')
                 AND   Loc.LocationFlag <> 'HOLD'
                 GROUP BY LLI.StorerKey
                        , LLI.Sku
                        , LLI.Loc
                        , LLI.Id
                 HAVING SUM(LLI.Qty - LLI.QtyAllocated - QtyPicked - LLI.QtyExpected) > 0) LLI
      )
      INSERT INTO #Temp_RoamReplen (StorerKey, SKU, Descr, OrdTotalBySKU, Level1, NeedBySKU, CtnNo, Fromloc
                                  , AvailableQty, MinLott05)
      SELECT OrderSum.StorerKey
           , OrderSum.Sku
           , OrderSum.DESCR
           , OrderSum.OpenQty
           , MAX(ISNULL(InvByLocLevel0.Accum, 0))
           , OrderSum.OpenQty - MAX(ISNULL(InvByLocLevel0.Accum, 0)) AS NeedBySku
           , CASE WHEN ISNULL(InvByLocLevel2.ID, '') = '' THEN N'Level2也无库存'
                  ELSE InvByLocLevel2.ID END AS [CtnNo]
           , CASE WHEN ISNULL(InvByLocLevel2.Loc, '') = '' THEN N'Level2也无库存'
                  ELSE InvByLocLevel2.Loc END AS [Fromloc]
           , ISNULL(InvByLocLevel2.Qty2, 0) AS [AvailableQty]
           , NULL AS Minlot5
      FROM OrderSum
      LEFT JOIN InvByLocLevel0 ON OrderSum.StorerKey = InvByLocLevel0.StorerKey AND OrderSum.Sku = InvByLocLevel0.Sku
      LEFT JOIN InvByLocLevel2 ON OrderSum.StorerKey = InvByLocLevel2.StorerKey AND OrderSum.Sku = InvByLocLevel2.Sku
      WHERE OrderSum.OpenQty > ISNULL(InvByLocLevel0.Accum, 0)
      GROUP BY OrderSum.StorerKey
             , OrderSum.Sku
             , OrderSum.DESCR
             , OrderSum.OpenQty
             , CASE WHEN ISNULL(InvByLocLevel2.ID, '') = '' THEN N'Level2也无库存'
                    ELSE InvByLocLevel2.ID END
             , CASE WHEN ISNULL(InvByLocLevel2.Loc, '') = '' THEN N'Level2也无库存'
                    ELSE InvByLocLevel2.Loc END
             , ISNULL(InvByLocLevel2.Qty2, 0)

      FETCH NEXT FROM cur_SKU
      INTO @c_Storerkey
         , @c_SKU
   END
   CLOSE cur_SKU
   DEALLOCATE cur_SKU

   SELECT StorerKey
        , SKU
        , Descr
        , OrdTotalBySKU
        , Level1
        , NeedBySKU
        , CtnNo
        , Fromloc
        , AvailableQty
        , MinLott05
   FROM #Temp_RoamReplen
   ORDER BY SKU

   IF OBJECT_ID('tempdb..#Temp_RoamReplen') IS NOT NULL
      DROP TABLE #Temp_RoamReplen

   IF CURSOR_STATUS('LOCAL', 'cur_SKU') IN ( 0, 1 )
   BEGIN
      CLOSE cur_SKU
      DEALLOCATE cur_SKU
   END
END

GO