SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_STKProgressDTL02                                */  
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

CREATE PROC [dbo].[isp_STKProgressDTL02]  
         @c_StockTakeKeys  NVARCHAR(4000)
      ,  @n_Cnt            INT
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
      ,  PopulateStage  INT                     DEFAULT (0))

   SET @c_ExecStatement = N' INSERT INTO #STOCKTAKE ( StocktakeKey, PopulateStage )' 
                        +  ' SELECT StockTakeKey, PopulateStage' 
                        +  ' FROM STOCKTAKESHEETPARAMETERS WITH (NOLOCK)'
                        +  ' WHERE Stocktakekey IN ( ' + @c_StockTakeKeys + ')'

   EXEC (@c_ExecStatement) 
  

   SELECT  LocAisle    = ISNULL(RTRIM(LOC.LocAisle),'')
         , Loc         = ISNULL(RTRIM(LOC.Loc),'')
   INTO #LocAisle
   FROM #STOCKTAKE ST   WITH (NOLOCK)
   JOIN CCDETAIL   CC   WITH (NOLOCK) ON (ST.StockTakeKey = CC.CCKey)
   JOIN LOC        LOC  WITH (NOLOCK) ON (CC.Loc = LOC.Loc)
   WHERE '0' = CASE WHEN @n_Cnt = 1 THEN Counted_Cnt1
                  WHEN @n_Cnt = 2 AND ST.PopulateStage >= 2 THEN Counted_Cnt2
                  WHEN @n_Cnt = 3 AND ST.PopulateStage =  2 THEN Counted_Cnt3
                  END

   SELECT LocAisle
         ,NoOfLoc = COUNT( DISTINCT Loc)
   FROM #LocAisle
   GROUP BY LocAisle
   
   RETURN
END

GO