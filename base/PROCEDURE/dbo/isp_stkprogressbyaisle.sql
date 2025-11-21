SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_STKProgressByAisle                              */  
/* Creation Date: 21-SEP-2012                                            */  
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

CREATE PROC [dbo].[isp_STKProgressByAisle]  
      @c_StockTakeKeys  NVARCHAR(4000)
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_ExecStatement   NVARCHAR(4000)
         , @c_ExecArgument    NVARCHAR(4000)

   DECLARE @n_LocCnt          FLOAT
         , @n_LocCnt1         FLOAT
         , @n_LocCnt2         FLOAT
         , @n_LocCnt3         FLOAT
         , @n_CCCnt           FLOAT
         , @n_FinalizeCnt1    FLOAT
         , @n_FinalizeCnt2    FLOAT
         , @n_FinalizeCnt3    FLOAT
         , @n_TotalStockTake  FLOAT
         , @n_TotalPosted     FLOAT

   SET @c_ExecStatement = ''
   SET @c_ExecArgument  = ''

   SET @n_LocCnt         = 0
   SET @n_CCCnt          = 0
   SET @n_FinalizeCnt1   = 0
   SET @n_FinalizeCnt2   = 0
   SET @n_FinalizeCnt3   = 0
   SET @n_TotalStockTake = 0
 

   CREATE TABLE #TEMP_STOCKTAKE (
         Stocktakekey   NVARCHAR(10) NOT NULL   DEFAULT ('')
      ,  Password       NVARCHAR(10) )

   SET @c_ExecStatement = N' INSERT INTO #TEMP_STOCKTAKE ( StocktakeKey, Password )' 
                        +  ' SELECT StockTakeKey' 
                        +  ',ISNULL(RTRIM(Password),'''')'
                        +  ' FROM STOCKTAKESHEETPARAMETERS WITH (NOLOCK)'
                        +  ' WHERE Stocktakekey IN ( ' + @c_StockTakeKeys + ')'

   EXEC (@c_ExecStatement) 

   SELECT @n_TotalStockTake = COUNT(1)
         ,@n_TotalPosted    = SUM(CASE WHEN Password = 'POSTED' THEN 1 ELSE 0 END) 
   FROM #TEMP_STOCKTAKE ST 

   SELECT @n_LocCnt         = COUNT(DISTINCT ISNULL(RTRIM(CC.LOC),''))
         ,@n_CCCnt          = COUNT(DISTINCT CC.CCkey)
   FROM #TEMP_STOCKTAKE ST 
   JOIN CCDETAIL CC WITH (NOLOCK) ON (CC.CCKey = ST.StockTakeKey)

   SELECT @n_LocCnt1        = COUNT(DISTINCT ISNULL(RTRIM(CC.LOC),'')) 
   FROM #TEMP_STOCKTAKE ST 
   JOIN CCDETAIL CC WITH (NOLOCK) ON (CC.CCKey = ST.StockTakeKey)
   WHERE CC.Counted_Cnt1 = '1'

   SELECT @n_LocCnt2        = COUNT(DISTINCT ISNULL(RTRIM(CC.LOC),''))
   FROM #TEMP_STOCKTAKE ST 
   JOIN CCDETAIL CC WITH (NOLOCK) ON (CC.CCKey = ST.StockTakeKey)
   WHERE CC.Counted_Cnt2 = '1'

   SELECT @n_LocCnt3        = COUNT(DISTINCT ISNULL(RTRIM(CC.LOC),''))
   FROM #TEMP_STOCKTAKE ST 
   JOIN CCDETAIL CC WITH (NOLOCK) ON (CC.CCKey = ST.StockTakeKey)
   WHERE CC.Counted_Cnt3 = '1'

   SELECT @n_FinalizeCnt1   = COUNT(DISTINCT CC.CCkey)  
   FROM #TEMP_STOCKTAKE ST 
   JOIN CCDETAIL CC WITH (NOLOCK) ON (CC.CCKey = ST.StockTakeKey)
   WHERE CC.FinalizeFlag = 'Y' 

   SELECT @n_FinalizeCnt2   = COUNT(DISTINCT CC.CCkey)
   FROM #TEMP_STOCKTAKE ST 
   JOIN CCDETAIL CC WITH (NOLOCK) ON (CC.CCKey = ST.StockTakeKey)
   WHERE CC.FinalizeFlag_Cnt2 = 'Y'

   SELECT @n_FinalizeCnt3   = COUNT(DISTINCT CC.CCkey)
   FROM #TEMP_STOCKTAKE ST 
   JOIN CCDETAIL CC WITH (NOLOCK) ON (CC.CCKey = ST.StockTakeKey)
   WHERE CC.FinalizeFlag_Cnt3 = 'Y'

   SELECT Cnt
         ,NoOfLocCntText = 'Number of Locations counted in Count ' + CONVERT( NVARCHAR(1), Cnt)
         ,NoOfLocCntKeys = CONVERT(VARCHAR(5), CASE WHEN Cnt = 1 THEN @n_LocCnt1
                                                    WHEN Cnt = 2 THEN @n_LocCnt2
                                                    ELSE @n_LocCnt3 END) 
                              + ' of ' + CONVERT(VARCHAR(5), @n_LocCnt) 
         ,NoOfLocCntPctg      = CONVERT( DECIMAL(5,2), CASE WHEN Cnt = 1 THEN @n_LocCnt1
                                                       WHEN Cnt = 2 THEN @n_LocCnt2
                                                       ELSE @n_LocCnt3 END / CASE WHEN @n_LocCnt = 0 THEN 1.00 ELSE @n_LocCnt END
                              * 100)

         ,SysQty      = SUM(SysQty)
         ,Qty         = SUM(Qty)
         ,QtyVarPctg  = CONVERT(DECIMAL(5,2),ISNULL((SUM(Qty) - SUM(SysQty)) / CASE WHEN SUM(SysQty) = 0 THEN 1.00 ELSE SUM(SysQty) END * 100,0.00))
         ,SysQtyValue = SUM(SysQtyValue)
         ,QtyValue    = SUM(QtyValue)
         ,VarValue    = SUM(QtyValue) - SUM(SysQtyValue)
         ,LocAisle
         ,NoOfLocAisleCntKeys = CONVERT(VARCHAR(5), (SELECT COUNT(DISTINCT LOC.Loc)
                                                     FROM #TEMP_STOCKTAKE ST    
                                                     JOIN CCDETAIL WITH (NOLOCK) ON (ST.StockTakeKey = CCDETAIL.CCKey)
                                                     JOIN LOC WITH (NOLOCK) ON (CCDETAIL.Loc = LOC.Loc)
                                                     WHERE LOC.LocAisle = TMP1.LocAisle
                                                     AND  '1' = CASE WHEN Cnt = 1 THEN CCDETAIL.Counted_Cnt1
                                                                     WHEN Cnt = 2 THEN CCDETAIL.Counted_Cnt2 
                                                                     ELSE CCDETAIL.Counted_Cnt3 END))
                              + ' of ' + CONVERT(VARCHAR(5), CASE WHEN Cnt = 1 THEN @n_LocCnt1
                                                                  WHEN Cnt = 2 THEN @n_LocCnt2
                                                                  ELSE @n_LocCnt3 END) 
         ,NoOfLocAisleCntPctg = CONVERT(DECIMAL(5,2), (SELECT COUNT(DISTINCT LOC.Loc)
                                                      FROM #TEMP_STOCKTAKE ST    
                                                      JOIN CCDETAIL WITH (NOLOCK) ON (ST.StockTakeKey = CCDETAIL.CCKey)
                                                      JOIN LOC WITH (NOLOCK) ON (CCDETAIL.Loc = LOC.Loc)
                                                      WHERE LOC.LocAisle = TMP1.LocAisle
                                                      AND '1' = CASE WHEN Cnt = 1 THEN CCDETAIL.Counted_Cnt1
                                                                     WHEN Cnt = 2 THEN CCDETAIL.Counted_Cnt2 
                                                                     ELSE CCDETAIL.Counted_Cnt3 END) 
                                                   /  CASE WHEN Cnt = 1 THEN CASE WHEN @n_LocCnt1 = 0 THEN 1.00 ELSE @n_LocCnt1 END
                                                           WHEN Cnt = 2 THEN CASE WHEN @n_LocCnt2 = 0 THEN 1.00 ELSE @n_LocCnt2 END
                                                           ELSE CASE WHEN @n_LocCnt3 = 0 THEN 1.00 ELSE @n_LocCnt3 END END

                                 * 100)
         ,NoOfRefKeysText1= 'Number of RefKeys Finalized Count 1'    
         ,NoOfRefKeys1    = CONVERT(VARCHAR(5), @n_FinalizeCnt1)   + ' of ' + CONVERT(VARCHAR(5), @n_CCCnt) 
         ,NoOfRefKeysPctg1= CONVERT(DECIMAL(5,2), @n_FinalizeCnt1 / CASE WHEN @n_CCCnt = 0 THEN 1.00 ELSE @n_CCCnt END * 100) 
         ,NoOfRefKeysText2= 'Number of RefKeys Finalized Count 2'    
         ,NoOfRefKeys2    = CONVERT(VARCHAR(5), @n_FinalizeCnt2)   + ' of ' + CONVERT(VARCHAR(5), @n_CCCnt) 
         ,NoOfRefKeysPctg2= CONVERT(DECIMAL(5,2), @n_FinalizeCnt2 / CASE WHEN @n_CCCnt = 0 THEN 1.00 ELSE @n_CCCnt END * 100)
         ,NoOfRefKeysText3= 'Number of RefKeys Finalized Count 3'    
         ,NoOfRefKeys3    = CONVERT(VARCHAR(5), @n_FinalizeCnt3)   + ' of ' + CONVERT(VARCHAR(5), @n_CCCnt) 
         ,NoOfRefKeysPctg3= CONVERT(DECIMAL(5,2), @n_FinalizeCnt3 / CASE WHEN @n_CCCnt = 0 THEN 1.00 ELSE @n_CCCnt END * 100)
         ,NoOfPostedText = 'Number of posted Cycle Count Ref Keys' 
         ,NoOfPosted     =  CONVERT(VARCHAR(5), @n_TotalPosted) + ' of ' + CONVERT(VARCHAR(5), @n_TotalStockTake)
         ,NoOfPostedPctg =  CONVERT(DECIMAL(5,2), @n_TotalPosted/CASE WHEN @n_TotalStockTake = 0 THEN 1 ELSE @n_TotalStockTake END * 100)
         ,PrintedBy      =  SUser_Name()
   FROM 
   (
   SELECT  LocAisle    = ISNULL(RTRIM(LOC.LocAisle),'')
         , Cnt         = 1
         , Counted     = CASE WHEN Counted_Cnt1 = '1' THEN COUNT(DISTINCT CC.LOC)  ELSE 0 END
         , SysQty      = SUM(CC.SystemQty)
         , Qty         = SUM(CC.Qty)
         , SysQtyValue = SUM(CC.SystemQty * ISNULL(SKU.Price,0))
         , QtyValue    = SUM(CC.Qty * ISNULL(SKU.Price,0))
   FROM #TEMP_STOCKTAKE ST    
   JOIN CCDETAIL   CC   WITH (NOLOCK) ON (ST.StockTakeKey = CC.CCKey)
   JOIN LOC        LOC  WITH (NOLOCK) ON (CC.Loc = LOC.Loc)
   LEFT JOIN SKU        SKU  WITH (NOLOCK) ON (CC.Storerkey = SKU.Storerkey) AND (CC.Sku = SKU.Sku)
   GROUP BY ISNULL(RTRIM(LOC.LocAisle),''), Counted_Cnt1
   UNION 
   SELECT  LocAisle    = ISNULL(RTRIM(LOC.LocAisle),'')
         , Cnt         = 2
         , Counted     = CASE WHEN Counted_Cnt2 = '1' THEN COUNT(DISTINCT CC.LOC)  ELSE 0 END
         , SysQty      = SUM(CC.SystemQty)
         , Qty         = SUM(CC.Qty_Cnt2)
         , SysQtyValue = SUM(CC.SystemQty * ISNULL(SKU.Price,0))
         , QtyValue    = SUM(CC.Qty_Cnt2  * ISNULL(SKU.Price,0))
   FROM #TEMP_STOCKTAKE ST   
   JOIN CCDETAIL   CC   WITH (NOLOCK) ON (ST.StockTakeKey = CC.CCKey)
   JOIN LOC        LOC  WITH (NOLOCK) ON (CC.Loc = LOC.Loc)
   LEFT JOIN SKU        SKU  WITH (NOLOCK) ON (CC.Storerkey = SKU.Storerkey) AND (CC.Sku = SKU.Sku)
   GROUP BY ISNULL(RTRIM(LOC.LocAisle),''),  Counted_Cnt2 
   UNION
   SELECT  LocAisle    = ISNULL(RTRIM(LOC.LocAisle),'')
         , Cnt         = 3
         , Counted     = CASE WHEN Counted_Cnt3 = '1' THEN COUNT(DISTINCT CC.LOC)  ELSE 0 END
         , SysQty      = SUM(CC.SystemQty)
         , Qty         = SUM(CC.Qty_Cnt3)
         , SysQtyValue = SUM(CC.SystemQty * ISNULL(SKU.Price,0))
         , QtyValue    = SUM(CC.Qty_Cnt3  * ISNULL(SKU.Price,0))
   FROM #TEMP_STOCKTAKE ST  
   JOIN CCDETAIL   CC   WITH (NOLOCK) ON (ST.StockTakeKey = CC.CCKey)
   JOIN LOC        LOC  WITH (NOLOCK) ON (CC.Loc = LOC.Loc)
   LEFT JOIN SKU        SKU  WITH (NOLOCK) ON (CC.Storerkey = SKU.Storerkey) AND (CC.Sku = SKU.Sku)
   GROUP BY ISNULL(RTRIM(LOC.LocAisle),''),  Counted_Cnt3 
   ) TMP1
   GROUP BY TMP1.CNT, TMP1.LocAisle
   ORDER BY TMP1.CNT, TMP1.LocAisle

   RETURN
END

GO