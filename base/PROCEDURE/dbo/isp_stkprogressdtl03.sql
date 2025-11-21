SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_STKProgressDTL03                                */  
/* Creation Date: 25-SEP-2012                                            */  
/* Copyright: LF                                                         */  
/* Written by: YTWan                                                     */  
/*                                                                       */  
/* Purpose: SOS#255776: Stock Take Progress Report                       */  
/*                                                                       */  
/* Called By: Call from StockTake Parameters RCM Print Progress report   */
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/*************************************************************************/  

CREATE PROC [dbo].[isp_STKProgressDTL03]  
         @c_StockTakeKeys  NVARCHAR(4000)
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_ExecStatement   NVARCHAR(4000)
         , @c_ExecArgument    NVARCHAR(4000)

   SET @c_ExecStatement = ''
   SET @c_ExecArgument  = ''

   CREATE TABLE #StockTake (
         Stocktakekey   NVARCHAR(10) NOT NULL    DEFAULT ('')
      ,  FinalizeStage  INT                     DEFAULT (0) )

   SET @c_ExecStatement = N' INSERT INTO #STOCKTAKE ( StocktakeKey, FinalizeStage )' 
                        +  ' SELECT StockTakeKey, FinalizeStage' 
                        +  ' FROM STOCKTAKESHEETPARAMETERS WITH (NOLOCK)'
                        +  ' WHERE Stocktakekey IN ( ' + @c_StockTakeKeys + ')'

   EXEC (@c_ExecStatement) 

   SELECT TMP.Cnt
         ,TMP.CCKey
         ,CCKeyCnt = COUNT ( DISTINCT TMP.CCKey )
   FROM
   (
   SELECT Cnt = 1
         ,CCKey = CASE WHEN MAX(CC.Finalizeflag) = 'N' THEN CC.CCKey ELSE NULL END 
   FROM #STOCKTAKE ST   WITH (NOLOCK)
   JOIN CCDETAIL   CC   WITH (NOLOCK) ON (ST.StockTakeKey = CC.CCKey)
   GROUP BY CC.CCKey
   --HAVING MAX(CC.Finalizeflag) = 'N'
   UNION
   SELECT Cnt = 2
         ,CCKey = CASE WHEN MAX(CC.Finalizeflag_Cnt2) = 'N' THEN CC.CCKey ELSE NULL END 
   FROM #STOCKTAKE ST   WITH (NOLOCK)
   LEFT JOIN CCDETAIL   CC   WITH (NOLOCK) ON (ST.StockTakeKey = CC.CCKey)
   WHERE ST.FinalizeStage >= '2'
   GROUP BY CC.CCKey
   --HAVING MAX(CC.Finalizeflag_Cnt2) = 'N'
   UNION
   SELECT Cnt = 3
         ,CCKey = CASE WHEN MAX(CC.Finalizeflag_Cnt3) = 'N' THEN CC.CCKey ELSE NULL END 
   FROM #STOCKTAKE ST   WITH (NOLOCK)
   LEFT JOIN CCDETAIL   CC   WITH (NOLOCK) ON (ST.StockTakeKey = CC.CCKey)
   WHERE ST.FinalizeStage = '3'
   GROUP BY CC.CCKey
   --HAVING MAX(CC.Finalizeflag_Cnt3) = 'N'
   ) TMP 
   GROUP BY TMP.Cnt, TMP.CCKey
   ORDER BY TMP.Cnt, TMP.CCKey
   RETURN
END

GO