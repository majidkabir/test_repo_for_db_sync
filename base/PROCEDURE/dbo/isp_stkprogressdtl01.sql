SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_STKProgressDTL01                                */  
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

CREATE PROC [dbo].[isp_STKProgressDTL01]  
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
       , PopulateStage  INT                     DEFAULT (0) )

   SET @c_ExecStatement = N' INSERT INTO #STOCKTAKE ( StocktakeKey, PopulateStage )' 
                        +  ' SELECT StockTakeKey, PopulateStage' 
                        +  ' FROM STOCKTAKESHEETPARAMETERS WITH (NOLOCK)'
                        +  ' WHERE Stocktakekey IN ( ' + @c_StockTakeKeys + ')'

   EXEC (@c_ExecStatement) 



      SELECT Cnt      = 1
            ,LocAisle = ISNULL(RTRIM(LOC.LocAisle),'')
            ,Loc      = ISNULL(RTRIM(LOC.Loc),'') 
      FROM #STOCKTAKE ST   WITH (NOLOCK)
      JOIN CCDETAIL   CC   WITH (NOLOCK) ON (ST.StockTakeKey = CC.CCKey)
      JOIN LOC        LOC  WITH (NOLOCK) ON (CC.Loc = LOC.Loc)
      WHERE CC.Counted_Cnt1 = '0'
      UNION
      SELECT Cnt      = 2
            ,LocAisle = ISNULL(RTRIM(LOC.LocAisle),'')
            ,Loc      = ISNULL(RTRIM(LOC.Loc),'')  
      FROM #STOCKTAKE ST   WITH (NOLOCK)
      JOIN CCDETAIL   CC   WITH (NOLOCK) ON (ST.StockTakeKey = CC.CCKey)
      JOIN LOC        LOC  WITH (NOLOCK) ON (CC.Loc = LOC.Loc)
      WHERE CC.Counted_Cnt2 = '0' 
      AND   ST.PopulateStage >= 2
      UNION
      SELECT Cnt      = 3
            ,LocAisle = ISNULL(RTRIM(LOC.LocAisle),'')
            ,Loc      = ISNULL(RTRIM(LOC.Loc),'')
      FROM #STOCKTAKE ST   WITH (NOLOCK)
      JOIN CCDETAIL   CC   WITH (NOLOCK) ON (ST.StockTakeKey = CC.CCKey)
      JOIN LOC        LOC  WITH (NOLOCK) ON (CC.Loc = LOC.Loc)
      WHERE CC.Counted_Cnt3 = '0'
      AND   ST.PopulateStage = 3
      ORDER BY Cnt, LocAisle, Loc

   RETURN
END

GO