SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_putaway_suggest_loc_ikea_rpt                      */
/* Creation Date: 30-Aug-2021                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-17838 - [CN] IKEA_Suggest loc_View report_CR               */
/*                                                                         */
/* Called By: r_dw_putaway_suggest_loc_ikea_rpt                            */
/*                                                                         */
/* GitLab Version: 1.1                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 13-Oct-2021  WLChooi 1.1   DevOps Combine Script                        */
/* 13-Oct-2021  WLChooi 1.1   WMS-17838 Add SKUInfo.ExtendedField05 (WL01) */
/***************************************************************************/  
CREATE PROC [dbo].[isp_putaway_suggest_loc_ikea_rpt]  
(     @c_Storerkey   NVARCHAR(15)  = 'IKEA'  
  ,   @c_Facility    NVARCHAR(5)
  ,   @c_Loc         NVARCHAR(20)
)  
AS 
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug           INT
         , @n_Continue        INT 
         , @n_StartTCnt       INT 

   DECLARE @n_CountLoc        INT
         , @c_LocationType    NVARCHAR(10) = 'PICK'
         , @c_SuggestedLoc    NVARCHAR(20) = ''
         , @c_SKU             NVARCHAR(20) = ''
         , @c_ExtendedField05 NVARCHAR(255) = ''   --WL01

   SET @b_Debug     = '0' 
   SET @n_Continue  = 1  
   SET @n_StartTCnt = @@TRANCOUNT  

   CREATE TABLE #TMP_LLI (
      SKU            NVARCHAR(20)
    , LOC            NVARCHAR(20)
    , Qty            INT
    , FromLocQty     INT
   )

   CREATE NONCLUSTERED INDEX IDX_TMP_LLI ON #TMP_LLI (LOC)

   CREATE TABLE #TMP_RESULT (
      FromLoc         NVARCHAR(20)
    , SKU             NVARCHAR(20)
    , SuggestedLoc    NVARCHAR(20) 
    , ExtendedField05 NVARCHAR(255)   --WL01
   )

   CREATE TABLE #TMP_FromLoc (
      SKU            NVARCHAR(20)
    , FromLocQty     INT
   )

   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN 
      INSERT INTO #TMP_FromLoc (SKU, FromLocQty)
      SELECT LTLCI.SKU, SUM(LTLCI.Qty) AS Qty
      FROM LOTxLOCxID LTLCI (NOLOCK)
      JOIN LOC L (NOLOCK) ON L.Loc = LTLCI.Loc
      WHERE LTLCI.LOC = @c_Loc
      AND LTLCI.StorerKey = @c_Storerkey
      AND L.Facility = @c_Facility
      GROUP BY LTLCI.SKU
      HAVING SUM(LTLCI.Qty) > 0

      INSERT INTO #TMP_LLI (SKU, LOC, Qty)
      SELECT LLI.SKU, LLI.LOC, SUM(LLI.Qty) AS Qty
      FROM LOTxLOCxID LLI (NOLOCK)
      JOIN LOC L (NOLOCK) ON L.LOC = LLI.LOC
      WHERE LLI.StorerKey = @c_Storerkey
      AND L.LocationType = @c_LocationType
      AND L.Facility = @c_Facility
      GROUP BY LLI.SKU, LLI.LOC

      DECLARE CUR_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT TL.SKU, COUNT(DISTINCT TL.LOC)
         FROM #TMP_LLI TL
         GROUP BY TL.SKU
      
      OPEN CUR_SKU

      FETCH NEXT FROM CUR_SKU INTO @c_SKU, @n_CountLoc
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @n_CountLoc <= 1
         BEGIN
            SELECT TOP 1 @c_SuggestedLoc = TL.LOC
            FROM #TMP_LLI TL
            WHERE TL.SKU = @c_SKU
         END
         ELSE
         BEGIN
            SELECT TOP 1 @c_SuggestedLoc = TL.LOC
            FROM #TMP_LLI TL
            WHERE TL.SKU = @c_SKU
            ORDER BY TL.Qty DESC
         END

         --WL01 S
         SELECT @c_ExtendedField05 = ISNULL(SI.ExtendedField05,'')
         FROM SkuInfo SI (NOLOCK)
         WHERE SI.SKU = @c_SKU AND SI.Storerkey = @c_Storerkey

         INSERT INTO #TMP_RESULT(FromLoc, SKU, SuggestedLoc, ExtendedField05)
         SELECT @c_Loc, @c_SKU, @c_SuggestedLoc, ISNULL(@c_ExtendedField05,'')
         --WL01 E

         FETCH NEXT FROM CUR_SKU INTO @c_SKU, @n_CountLoc
      END
      CLOSE CUR_SKU
      DEALLOCATE CUR_SKU 
   END

   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN  
      SELECT TR.FromLoc, TR.SKU, TR.SuggestedLoc, TFL.FromLocQty AS Qty
           , TR.ExtendedField05   --WL01
      FROM #TMP_RESULT TR
      JOIN #TMP_FromLoc TFL ON TFL.SKU = TR.SKU
      GROUP BY TR.FromLoc, TR.SKU, TR.SuggestedLoc, TFL.FromLocQty
             , TR.ExtendedField05   --WL01
      --ORDER BY TR.SKU   --WL01
      ORDER BY TR.SuggestedLoc, TR.SKU   --WL01
   END

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_LLI') IS NOT NULL
      DROP TABLE #TMP_LLI

   IF OBJECT_ID('tempdb..#TMP_FromLoc') IS NOT NULL
      DROP TABLE #TMP_FromLoc

   IF OBJECT_ID('tempdb..#TMP_RESULT') IS NOT NULL
      DROP TABLE #TMP_RESULT

   IF CURSOR_STATUS('LOCAL', 'CUR_SKU') IN (0 , 1)
   BEGIN
      CLOSE CUR_SKU
      DEALLOCATE CUR_SKU   
   END
END

GO