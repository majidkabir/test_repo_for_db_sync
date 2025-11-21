SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store Procedure: isp_ABC_Dashboard_01                                   */
/* Creation Date: 17-MAY-2013                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  SKU ABC Dashboard                                             */
/*                                                                         */
/* Called By:  r_dw_abc_dashboard_01                                       */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/***************************************************************************/
CREATE PROC [dbo].[isp_ABC_Dashboard_01]
         @c_Storerkey            NVARCHAR(15)
       , @c_SkuGroup             NVARCHAR(10)
       , @c_ItemClass            NVARCHAR(10)
       , @c_Susr3                NVARCHAR(18)
       , @c_Busr1                NVARCHAR(30)
       , @c_Class                NVARCHAR(10)
       , @c_Busr5                NVARCHAR(30) 
       , @c_Type                 NVARCHAR(10) 
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  @c_SQL                  NVARCHAR(MAX)
   DECLARE  @n_SkuA                 FLOAT
          , @n_SkuB                 FLOAT
          , @n_SkuC                 FLOAT
          , @n_SkuD                 FLOAT
          , @n_SkuNA                FLOAT
          , @n_TotalABC             FLOAT
          , @n_OriginTotalABC       FLOAT
                                      
   DECLARE  @n_AnalysisA            FLOAT
          , @n_AnalysisB            FLOAT
          , @n_AnalysisC            FLOAT
          , @n_AnalysisD            FLOAT
          , @n_AnalysisNA           FLOAT
          , @n_AnalysisTotalABC     FLOAT
                                      
          , @n_AvgDailyPickA        FLOAT
          , @n_AvgDailyPickB        FLOAT
          , @n_AvgDailyPickC        FLOAT
          , @n_AvgDailyPickD        FLOAT
          , @n_AvgDailyPickNA       FLOAT
          , @n_MinAvgDailyPickA     FLOAT
          , @n_MinAvgDailyPickB     FLOAT
          , @n_MinAvgDailyPickC     FLOAT
          , @n_MinAvgDailyPickD     FLOAT
          , @n_MinAvgDailyPickNA    FLOAT
          , @n_MaxAvgDailyPickA     FLOAT
          , @n_MaxAvgDailyPickB     FLOAT
          , @n_MaxAvgDailyPickC     FLOAT
          , @n_MaxAvgDailyPickD     FLOAT
          , @n_MaxAvgDailyPickNA    FLOAT

          , @n_PAnalysisA           FLOAT
          , @n_PAnalysisB           FLOAT
          , @n_PAnalysisC           FLOAT
          , @n_PAnalysisD           FLOAT
          , @n_PAnalysisNA          FLOAT
          , @n_PAvgDailyPickA       FLOAT
          , @n_PAvgDailyPickB       FLOAT
          , @n_PAvgDailyPickC       FLOAT
          , @n_PAvgDailyPickD       FLOAT
          , @n_PAvgDailyPickNA      FLOAT
          , @n_PMinAvgDailyPickA    FLOAT
          , @n_PMinAvgDailyPickB    FLOAT
          , @n_PMinAvgDailyPickC    FLOAT
          , @n_PMinAvgDailyPickD    FLOAT
          , @n_PMinAvgDailyPickNA   FLOAT
          , @n_PMaxAvgDailyPickA    FLOAT
          , @n_PMaxAvgDailyPickB    FLOAT
          , @n_PMaxAvgDailyPickC    FLOAT
          , @n_PMaxAvgDailyPickD    FLOAT
          , @n_PMaxAvgDailyPickNA   FLOAT

          , @n_CAnalysisA           FLOAT
          , @n_CAnalysisB           FLOAT
          , @n_CAnalysisC           FLOAT
          , @n_CAnalysisD           FLOAT
          , @n_CAnalysisNA          FLOAT
          , @n_CAvgDailyPickA       FLOAT
          , @n_CAvgDailyPickB       FLOAT
          , @n_CAvgDailyPickC       FLOAT
          , @n_CAvgDailyPickD       FLOAT
          , @n_CAvgDailyPickNA      FLOAT
          , @n_CMinAvgDailyPickA    FLOAT
          , @n_CMinAvgDailyPickB    FLOAT
          , @n_CMinAvgDailyPickC    FLOAT
          , @n_CMinAvgDailyPickD    FLOAT
          , @n_CMinAvgDailyPickNA   FLOAT
          , @n_CMaxAvgDailyPickA    FLOAT
          , @n_CMaxAvgDailyPickB    FLOAT
          , @n_CMaxAvgDailyPickC    FLOAT
          , @n_CMaxAvgDailyPickD    FLOAT
          , @n_CMaxAvgDailyPickNA   FLOAT

          , @n_BAnalysisA           FLOAT
          , @n_BAnalysisB           FLOAT
          , @n_BAnalysisC           FLOAT
          , @n_BAnalysisD           FLOAT
          , @n_BAnalysisNA          FLOAT
          , @n_BAvgDailyPickA       FLOAT
          , @n_BAvgDailyPickB       FLOAT
          , @n_BAvgDailyPickC       FLOAT
          , @n_BAvgDailyPickD       FLOAT
          , @n_BAvgDailyPickNA      FLOAT
          , @n_BMinAvgDailyPickA    FLOAT
          , @n_BMinAvgDailyPickB    FLOAT
          , @n_BMinAvgDailyPickC    FLOAT
          , @n_BMinAvgDailyPickD    FLOAT
          , @n_BMinAvgDailyPickNA   FLOAT
          , @n_BMaxAvgDailyPickA    FLOAT
          , @n_BMaxAvgDailyPickB    FLOAT
          , @n_BMaxAvgDailyPickC    FLOAT
          , @n_BMaxAvgDailyPickD    FLOAT
          , @n_BMaxAvgDailyPickNA   FLOAT
                                      
   DECLARE  @n_TMSkuMoveA           FLOAT
          , @n_TMSkuMoveB           FLOAT
          , @n_TMSkuMoveC           FLOAT
          , @n_TMSkuMoveD           FLOAT
          , @n_TMSkuMoveNA          FLOAT
          , @n_TMSkuMoveTotalABC    FLOAT

   SET @n_SkuA                = 0.00
   SET @n_SkuB                = 0.00
   SET @n_SkuC                = 0.00
   SET @n_SkuD                = 0.00
   SET @n_SkuNA               = 0.00
   SET @n_TotalABC            = 0.00
   SET @n_OriginTotalABC      = 0.00
                                    
   SET @n_AnalysisA           = 0.00
   SET @n_AnalysisB           = 0.00
   SET @n_AnalysisC           = 0.00
   SET @n_AnalysisD           = 0.00
   SET @n_AnalysisNA          = 0.00
   SET @n_AnalysisTotalABC    = 0.00
                                    
   SET @n_AvgDailyPickA       = 0.00
   SET @n_AvgDailyPickB       = 0.00
   SET @n_AvgDailyPickC       = 0.00
   SET @n_AvgDailyPickD       = 0.00
   SET @n_AvgDailyPickNA      = 0.00
   SET @n_MinAvgDailyPickA    = 0.00
   SET @n_MinAvgDailyPickB    = 0.00
   SET @n_MinAvgDailyPickC    = 0.00
   SET @n_MinAvgDailyPickD    = 0.00
   SET @n_MinAvgDailyPickNA   = 0.00
   SET @n_MaxAvgDailyPickA    = 0.00
   SET @n_MaxAvgDailyPickB    = 0.00
   SET @n_MaxAvgDailyPickC    = 0.00
   SET @n_MaxAvgDailyPickD    = 0.00
   SET @n_MaxAvgDailyPickNA   = 0.00
                                    
   SET @n_PAnalysisA          = 0.00
   SET @n_PAnalysisB          = 0.00
   SET @n_PAnalysisC          = 0.00
   SET @n_PAnalysisD          = 0.00
   SET @n_PAnalysisNA         = 0.00
   SET @n_PAvgDailyPickA      = 0.00
   SET @n_PAvgDailyPickB      = 0.00
   SET @n_PAvgDailyPickC      = 0.00
   SET @n_PAvgDailyPickD      = 0.00
   SET @n_PAvgDailyPickNA     = 0.00
   SET @n_PMinAvgDailyPickA   = 0.00
   SET @n_PMinAvgDailyPickB   = 0.00
   SET @n_PMinAvgDailyPickC   = 0.00
   SET @n_PMinAvgDailyPickD   = 0.00
   SET @n_PMinAvgDailyPickNA  = 0.00
   SET @n_PMaxAvgDailyPickA   = 0.00
   SET @n_PMaxAvgDailyPickB   = 0.00
   SET @n_PMaxAvgDailyPickC   = 0.00
   SET @n_PMaxAvgDailyPickD   = 0.00
   SET @n_PMaxAvgDailyPickNA  = 0.00
                                    
   SET @n_CAnalysisA          = 0.00
   SET @n_CAnalysisB          = 0.00
   SET @n_CAnalysisC          = 0.00
   SET @n_CAnalysisD          = 0.00
   SET @n_CAnalysisNA         = 0.00
   SET @n_CAvgDailyPickA      = 0.00
   SET @n_CAvgDailyPickB      = 0.00
   SET @n_CAvgDailyPickC      = 0.00
   SET @n_CAvgDailyPickD      = 0.00
   SET @n_CAvgDailyPickNA     = 0.00
   SET @n_CMinAvgDailyPickA   = 0.00
   SET @n_CMinAvgDailyPickB   = 0.00
   SET @n_CMinAvgDailyPickC   = 0.00
   SET @n_CMinAvgDailyPickD   = 0.00
   SET @n_CMinAvgDailyPickNA  = 0.00
   SET @n_CMaxAvgDailyPickA   = 0.00
   SET @n_CMaxAvgDailyPickB   = 0.00
   SET @n_CMaxAvgDailyPickC   = 0.00
   SET @n_CMaxAvgDailyPickD   = 0.00
   SET @n_CMaxAvgDailyPickNA  = 0.00
                                    
   SET @n_BAnalysisA          = 0.00
   SET @n_BAnalysisB          = 0.00
   SET @n_BAnalysisC          = 0.00
   SET @n_BAnalysisD          = 0.00
   SET @n_BAnalysisNA         = 0.00
   SET @n_BAvgDailyPickA      = 0.00
   SET @n_BAvgDailyPickB      = 0.00
   SET @n_BAvgDailyPickC      = 0.00
   SET @n_BAvgDailyPickD      = 0.00
   SET @n_BAvgDailyPickNA     = 0.00
   SET @n_BMinAvgDailyPickA   = 0.00
   SET @n_BMinAvgDailyPickB   = 0.00
   SET @n_BMinAvgDailyPickC   = 0.00
   SET @n_BMinAvgDailyPickD   = 0.00
   SET @n_BMinAvgDailyPickNA  = 0.00
   SET @n_BMaxAvgDailyPickA   = 0.00
   SET @n_BMaxAvgDailyPickB   = 0.00
   SET @n_BMaxAvgDailyPickC   = 0.00
   SET @n_BMaxAvgDailyPickD   = 0.00
   SET @n_BMaxAvgDailyPickNA  = 0.00
                                    
   SET @n_TMSkuMoveA          = 0.00
   SET @n_TMSkuMoveB          = 0.00
   SET @n_TMSkuMoveC          = 0.00
   SET @n_TMSkuMoveD          = 0.00
   SET @n_TMSkuMoveNA         = 0.00

   CREATE TABLE #TMP_SKU 
         (
            Storerkey               NVARCHAR(15)
         ,  Sku                     NVARCHAR(20)
         )
         
   CREATE TABLE #TMP_SKUABC
         (  ABC                     NVARCHAR(5)
         ,  TotalABC                FLOAT       NULL
         ,  CurrentABC              FLOAT       NULL
         ,  PerctgABC               FLOAT       NULL
         ,  ProposedABC             FLOAT       NULL
         ,  PrectgProposedABC       FLOAT       NULL
         ,  AvgDailyPck             FLOAT       NULL
         ,  MinAvgDailyPck          FLOAT       NULL
         ,  MaxAvgDailyPck          FLOAT       NULL
         ,  TMSkuMoveABC            FLOAT       NULL
         ,  TMSkuMoveTotalABC       FLOAT       NULL   
         )

   
--   INSERT INTO #TMP_SKU
--   SELECT Storerkey
--         ,Sku
--   FROM SKU WITH (NOLOCK)
--   WHERE SKU.Storerkey = CASE WHEN @c_Storerkey = 'ALL' THEN SKU.Storerkey ELSE @c_Storerkey END
--   AND   ISNULL(RTRIM(SKU.SkuGroup),'')  = CASE WHEN @c_SkuGroup  = 'ALL' THEN ISNULL(RTRIM(SKU.SkuGroup),'')  ELSE @c_SkuGroup  END
--   AND   ISNULL(RTRIM(SKU.ItemClass),'') = CASE WHEN @c_ItemClass = 'ALL' THEN ISNULL(RTRIM(SKU.ItemClass),'') ELSE @c_ItemClass END
--   AND   ISNULL(RTRIM(SKU.SUSR3),'')     = CASE WHEN @c_SUSR3     = 'ALL' THEN ISNULL(RTRIM(SKU.SUSR3),'')     ELSE @c_SUSR3     END
--   AND   ISNULL(RTRIM(SKU.BUSR1),'')     = CASE WHEN @c_BUSR1     = 'ALL' THEN ISNULL(RTRIM(SKU.BUSR1),'')     ELSE @c_BUSR1     END
--   AND   ISNULL(RTRIM(SKU.Class),'')     = CASE WHEN @c_Class     = 'ALL' THEN ISNULL(RTRIM(SKU.Class),'')     ELSE @c_Class     END
--   AND   ISNULL(RTRIM(SKU.BUSR5),'')     = CASE WHEN @c_BUSR5     = 'ALL' THEN ISNULL(RTRIM(SKU.BUSR5),'')     ELSE @c_BUSR5     END

   SET @c_SQL = N'INSERT INTO #TMP_SKU ' 
              +  'SELECT Storerkey '
              +  ',Sku '
              +  'FROM SKU WITH (NOLOCK) '
              +  'WHERE 1 = 1 '
              +  CASE WHEN @c_Storerkey <> 'ALL' THEN 'AND SKU.Storerkey = N''' + @c_Storerkey + ''' ' ELSE '' END  
              +  CASE WHEN @c_SkuGroup  <> 'ALL' THEN 'AND SKU.SkuGroup  = N''' + @c_SkuGroup  + ''' ' ELSE '' END  
              +  CASE WHEN @c_ItemClass <> 'ALL' THEN 'AND SKU.ItemClass = N''' + @c_ItemClass + ''' ' ELSE '' END  
              +  CASE WHEN @c_SUSR3     <> 'ALL' THEN 'AND SKU.SUSR3 = N''' + @c_SUSR3 + ''' ' ELSE '' END  
              +  CASE WHEN @c_BUSR1     <> 'ALL' THEN 'AND SKU.BUSR1 = N''' + @c_BUSR1 + ''' ' ELSE '' END  
              +  CASE WHEN @c_Class     <> 'ALL' THEN 'AND SKU.Class = N''' + @c_Class + ''' ' ELSE '' END 
              +  CASE WHEN @c_BUSR5     <> 'ALL' THEN 'AND SKU.BUSR5 = N''' + @c_BUSR5 + ''' ' ELSE '' END  

   EXEC (@c_SQL)


   SELECT @n_SkuA = ISNULL(SUM(CASE WHEN SKU.ABC = 'A' THEN 1 ELSE 0 END),0)
         ,@n_SkuB = ISNULL(SUM(CASE WHEN SKU.ABC = 'B' THEN 1 ELSE 0 END),0)
         ,@n_SkuC = ISNULL(SUM(CASE WHEN SKU.ABC = 'C' THEN 1 ELSE 0 END),0)
         ,@n_SkuD = ISNULL(SUM(CASE WHEN SKU.ABC = 'D' THEN 1 ELSE 0 END),0)
         ,@n_SkuNA= ISNULL(SUM(CASE WHEN SKU.ABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE 1 END),0)
         ,@n_TotalABC = ISNULL(COUNT(1),0)
   FROM SKU WITH (NOLOCK)
   JOIN #TMP_SKU TMP ON (SKU.Storerkey = TMP.Storerkey) AND (SKU.Sku = TMP.Sku)

   SELECT @n_AnalysisA = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewABC = 'A' THEN 1 ELSE 0 END),0)
         ,@n_AnalysisB = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewABC = 'B' THEN 1 ELSE 0 END),0)
         ,@n_AnalysisC = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewABC = 'C' THEN 1  ELSE 0 END),0)
         ,@n_AnalysisD = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewABC = 'D' THEN 1 ELSE 0 END),0)
         ,@n_AnalysisNA= ISNULL(SUM(CASE WHEN ABCANALYSIS.NewABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE 1 END),0)
         ,@n_AvgDailyPickA = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewABC = 'A' THEN ABCANALYSIS.AvgDailyPick ELSE 0 END),0)
         ,@n_AvgDailyPickB = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewABC = 'B' THEN ABCANALYSIS.AvgDailyPick ELSE 0 END),0)
         ,@n_AvgDailyPickC = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewABC = 'C' THEN ABCANALYSIS.AvgDailyPick ELSE 0 END),0)
         ,@n_AvgDailyPickD = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewABC = 'D' THEN ABCANALYSIS.AvgDailyPick ELSE 0 END),0)
         ,@n_AvgDailyPickNA= ISNULL(AVG(CASE WHEN ABCANALYSIS.NewABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE ABCANALYSIS.AvgDailyPick END),0)
         ,@n_MinAvgDailyPickA = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewABC = 'A' THEN ABCANALYSIS.AvgDailyPick ELSE NULL END),0)
         ,@n_MinAvgDailyPickB = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewABC = 'B' THEN ABCANALYSIS.AvgDailyPick ELSE NULL END),0)
         ,@n_MinAvgDailyPickC = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewABC = 'C' THEN ABCANALYSIS.AvgDailyPick ELSE NULL END),0)
         ,@n_MinAvgDailyPickD = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewABC = 'D' THEN ABCANALYSIS.AvgDailyPick ELSE NULL END),0)
         ,@n_MinAvgDailyPickNA= ISNULL(MIN(CASE WHEN ABCANALYSIS.NewABC IN ('A', 'B', 'C', 'D') THEN NULL ELSE ABCANALYSIS.AvgDailyPick END),0)
         ,@n_MaxAvgDailyPickA = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewABC = 'A' THEN ABCANALYSIS.AvgDailyPick ELSE 0 END),0)
         ,@n_MaxAvgDailyPickB = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewABC = 'B' THEN ABCANALYSIS.AvgDailyPick ELSE 0 END),0)
         ,@n_MaxAvgDailyPickC = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewABC = 'C' THEN ABCANALYSIS.AvgDailyPick ELSE 0 END),0)
         ,@n_MaxAvgDailyPickD = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewABC = 'D' THEN ABCANALYSIS.AvgDailyPick ELSE 0 END),0)
         ,@n_MaxAvgDailyPickNA= ISNULL(MAX(CASE WHEN ABCANALYSIS.NewABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE ABCANALYSIS.AvgDailyPick END),0)

         ,@n_PAnalysisA = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewPieceABC = 'A' THEN 1 ELSE 0 END),0)
         ,@n_PAnalysisB = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewPieceABC = 'B' THEN 1 ELSE 0 END),0)
         ,@n_PAnalysisC = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewPieceABC = 'C' THEN 1 ELSE 0 END),0)
         ,@n_PAnalysisD = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewPieceABC = 'D' THEN 1 ELSE 0 END),0)
         ,@n_PAnalysisNA= ISNULL(SUM(CASE WHEN ABCANALYSIS.NewPieceABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE 1 END),0)
         ,@n_PAvgDailyPickA = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewPieceABC = 'A' THEN ABCANALYSIS.AvgDailyPiecePick ELSE 0 END),0)
         ,@n_PAvgDailyPickB = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewPieceABC = 'B' THEN ABCANALYSIS.AvgDailyPiecePick ELSE 0 END),0)
         ,@n_PAvgDailyPickC = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewPieceABC = 'C' THEN ABCANALYSIS.AvgDailyPiecePick ELSE 0 END),0)
         ,@n_PAvgDailyPickD = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewPieceABC = 'D' THEN ABCANALYSIS.AvgDailyPiecePick ELSE 0 END),0)
         ,@n_PAvgDailyPickNA= ISNULL(AVG(CASE WHEN ABCANALYSIS.NewPieceABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE ABCANALYSIS.AvgDailyPiecePick END),0)
         ,@n_PMinAvgDailyPickA = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewPieceABC = 'A' THEN ABCANALYSIS.AvgDailyPiecePick ELSE NULL END),0)
         ,@n_PMinAvgDailyPickB = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewPieceABC = 'B' THEN ABCANALYSIS.AvgDailyPiecePick ELSE NULL END),0)
         ,@n_PMinAvgDailyPickC = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewPieceABC = 'C' THEN ABCANALYSIS.AvgDailyPiecePick ELSE NULL END),0)
         ,@n_PMinAvgDailyPickD = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewPieceABC = 'D' THEN ABCANALYSIS.AvgDailyPiecePick ELSE NULL END),0)
         ,@n_PMinAvgDailyPickNA= ISNULL(MIN(CASE WHEN ABCANALYSIS.NewPieceABC IN ('A', 'B', 'C', 'D') THEN NULL ELSE ABCANALYSIS.AvgDailyPiecePick END),0)
         ,@n_PMaxAvgDailyPickA = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewPieceABC = 'A' THEN ABCANALYSIS.AvgDailyPiecePick ELSE 0 END),0)
         ,@n_PMaxAvgDailyPickB = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewPieceABC = 'B' THEN ABCANALYSIS.AvgDailyPiecePick ELSE 0 END),0)
         ,@n_PMaxAvgDailyPickC = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewPieceABC = 'C' THEN ABCANALYSIS.AvgDailyPiecePick ELSE 0 END),0)
         ,@n_PMaxAvgDailyPickD = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewPieceABC = 'D' THEN ABCANALYSIS.AvgDailyPiecePick ELSE 0 END),0)
         ,@n_PMaxAvgDailyPickNA= ISNULL(MAX(CASE WHEN ABCANALYSIS.NewPieceABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE ABCANALYSIS.AvgDailyPiecePick END),0)

         ,@n_CAnalysisA = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewCaseABC = 'A' THEN 1 ELSE 0 END),0)
         ,@n_CAnalysisB = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewCaseABC = 'B' THEN 1 ELSE 0 END),0)
         ,@n_CAnalysisC = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewCaseABC = 'C' THEN 1 ELSE 0 END),0)
         ,@n_CAnalysisD = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewCaseABC = 'D' THEN 1 ELSE 0 END),0)
         ,@n_CAnalysisNA= ISNULL(SUM(CASE WHEN ABCANALYSIS.NewCaseABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE 1 END),0)
         ,@n_CAvgDailyPickA = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewCaseABC = 'A' THEN ABCANALYSIS.AvgDailyCasePick ELSE 0 END),0)
         ,@n_CAvgDailyPickB = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewCaseABC = 'B' THEN ABCANALYSIS.AvgDailyCasePick ELSE 0 END),0)
         ,@n_CAvgDailyPickC = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewCaseABC = 'C' THEN ABCANALYSIS.AvgDailyCasePick ELSE 0 END),0)
         ,@n_CAvgDailyPickD = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewCaseABC = 'D' THEN ABCANALYSIS.AvgDailyCasePick ELSE 0 END),0)
         ,@n_CAvgDailyPickNA= ISNULL(AVG(CASE WHEN ABCANALYSIS.NewCaseABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE ABCANALYSIS.AvgDailyCasePick END),0)
         ,@n_CMinAvgDailyPickA = ISNULL( MIN(CASE WHEN ABCANALYSIS.NewCaseABC = 'A' THEN ABCANALYSIS.AvgDailyCasePick ELSE NULL END),0)
         ,@n_CMinAvgDailyPickB = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewCaseABC = 'B' THEN ABCANALYSIS.AvgDailyCasePick ELSE NULL END),0)
         ,@n_CMinAvgDailyPickC = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewCaseABC = 'C' THEN ABCANALYSIS.AvgDailyCasePick ELSE NULL END),0)
         ,@n_CMinAvgDailyPickD = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewCaseABC = 'D' THEN ABCANALYSIS.AvgDailyCasePick ELSE NULL END),0)
         ,@n_CMinAvgDailyPickNA= ISNULL(MIN(CASE WHEN ABCANALYSIS.NewCaseABC IN ('A', 'B', 'C', 'D') THEN NULL ELSE ABCANALYSIS.AvgDailyCasePick END),0)
         ,@n_CMaxAvgDailyPickA = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewCaseABC = 'A' THEN ABCANALYSIS.AvgDailyCasePick ELSE 0 END),0)
         ,@n_CMaxAvgDailyPickB = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewCaseABC = 'B' THEN ABCANALYSIS.AvgDailyCasePick ELSE 0 END),0)
         ,@n_CMaxAvgDailyPickC = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewCaseABC = 'C' THEN ABCANALYSIS.AvgDailyCasePick ELSE 0 END),0)
         ,@n_CMaxAvgDailyPickD = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewCaseABC = 'D' THEN ABCANALYSIS.AvgDailyCasePick ELSE 0 END),0)
         ,@n_CMaxAvgDailyPickNA= ISNULL(MAX(CASE WHEN ABCANALYSIS.NewCaseABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE ABCANALYSIS.AvgDailyCasePick END),0)

         ,@n_BAnalysisA = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewBulkABC = 'A' THEN 1 ELSE 0 END),0)
         ,@n_BAnalysisB = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewBulkABC = 'B' THEN 1 ELSE 0 END),0)
         ,@n_BAnalysisC = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewBulkABC = 'C' THEN 1 ELSE 0 END),0)
         ,@n_BAnalysisD = ISNULL(SUM(CASE WHEN ABCANALYSIS.NewBulkABC = 'D' THEN 1 ELSE 0 END),0)
         ,@n_BAnalysisNA= ISNULL(SUM(CASE WHEN ABCANALYSIS.NewBulkABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE 1 END),0)
         ,@n_BAvgDailyPickA = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewBulkABC = 'A' THEN ABCANALYSIS.AvgDailyBulkPick ELSE 0 END),0)
         ,@n_BAvgDailyPickB = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewBulkABC = 'B' THEN ABCANALYSIS.AvgDailyBulkPick ELSE 0 END),0)
         ,@n_BAvgDailyPickC = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewBulkABC = 'C' THEN ABCANALYSIS.AvgDailyBulkPick ELSE 0 END),0)
         ,@n_BAvgDailyPickD = ISNULL(AVG(CASE WHEN ABCANALYSIS.NewBulkABC = 'D' THEN ABCANALYSIS.AvgDailyBulkPick ELSE 0 END),0)
         ,@n_BAvgDailyPickNA= ISNULL(AVG(CASE WHEN ABCANALYSIS.NewBulkABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE ABCANALYSIS.AvgDailyBulkPick END),0)
         ,@n_BMinAvgDailyPickA = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewBulkABC = 'A' THEN ABCANALYSIS.AvgDailyBulkPick ELSE NULL END),0)
         ,@n_BMinAvgDailyPickB = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewBulkABC = 'B' THEN ABCANALYSIS.AvgDailyBulkPick ELSE NULL END),0)
         ,@n_BMinAvgDailyPickC = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewBulkABC = 'C' THEN ABCANALYSIS.AvgDailyBulkPick ELSE NULL END),0)
         ,@n_BMinAvgDailyPickD = ISNULL(MIN(CASE WHEN ABCANALYSIS.NewBulkABC = 'D' THEN ABCANALYSIS.AvgDailyBulkPick ELSE NULL END),0)
         ,@n_BMinAvgDailyPickNA= ISNULL(MIN(CASE WHEN ABCANALYSIS.NewBulkABC IN ('A', 'B', 'C', 'D') THEN NULL ELSE ABCANALYSIS.AvgDailyBulkPick END),0)
         ,@n_BMaxAvgDailyPickA = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewBulkABC = 'A' THEN ABCANALYSIS.AvgDailyBulkPick ELSE 0 END),0)
         ,@n_BMaxAvgDailyPickB = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewBulkABC = 'B' THEN ABCANALYSIS.AvgDailyBulkPick ELSE 0 END),0)
         ,@n_BMaxAvgDailyPickC = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewBulkABC = 'C' THEN ABCANALYSIS.AvgDailyBulkPick ELSE 0 END),0)
         ,@n_BMaxAvgDailyPickD = ISNULL(MAX(CASE WHEN ABCANALYSIS.NewBulkABC = 'D' THEN ABCANALYSIS.AvgDailyBulkPick ELSE 0 END),0)
         ,@n_BMaxAvgDailyPickNA= ISNULL(MAX(CASE WHEN ABCANALYSIS.NewBulkABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE ABCANALYSIS.AvgDailyBulkPick END),0)
   FROM #TMP_SKU TMP
   JOIN SKU WITH (NOLOCK) ON (SKU.Storerkey = TMP.Storerkey) AND (SKU.Sku = TMP.Sku)
   JOIN ABCANALYSIS WITH (NOLOCK) ON (SKU.Storerkey = ABCANALYSIS.Storerkey) AND (SKU.Sku = ABCANALYSIS.Sku)


   SELECT @n_TMSkuMoveA = ISNULL(SUM(CASE WHEN SKU.ABC = 'A' THEN 1 ELSE 0 END),0)
         ,@n_TMSkuMoveB = ISNULL(SUM(CASE WHEN SKU.ABC = 'B' THEN 1 ELSE 0 END),0)
         ,@n_TMSkuMoveC = ISNULL(SUM(CASE WHEN SKU.ABC = 'C' THEN 1 ELSE 0 END),0)
         ,@n_TMSkuMoveD = ISNULL(SUM(CASE WHEN SKU.ABC = 'D' THEN 1 ELSE 0 END),0)
         ,@n_TMSkuMoveNA= ISNULL(SUM(CASE WHEN SKU.ABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE 1 END),0)
         ,@n_TMSkuMoveTotalABC = ISNULL(COUNT(1),0)
   FROM #TMP_SKU TMP
   JOIN SKU WITH (NOLOCK) ON (SKU.Storerkey = TMP.Storerkey) AND (SKU.Sku = TMP.Sku)
   JOIN TASKDETAIL WITH (NOLOCK) ON (SKU.Storerkey = TASKDETAIL.Storerkey) AND (SKU.Sku = TASKDETAIL.Sku)

   SET @n_OriginTotalABC = @n_TotalABC
   IF @n_TotalABC = 0.00
   BEGIN
      SET @n_TotalABC = 1
   END

   IF @c_type = 'ALL' 
   BEGIN
      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('A', @n_OriginTotalABC, @n_SkuA,  CEILING((@n_SkuA / @n_TotalABC) * 100), @n_AnalysisA, CEILING((@n_AnalysisA / @n_TotalABC) * 100) 
             ,@n_AvgDailyPickA, @n_MinAvgDailyPickA, @n_MaxAvgDailyPickA, @n_TMSkuMoveA, @n_TMSkuMoveTotalABC )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('B', @n_OriginTotalABC, @n_SkuB,  CEILING((@n_SkuB / @n_TotalABC) * 100), @n_AnalysisB, CEILING((@n_AnalysisB / @n_TotalABC) * 100) 
             ,@n_AvgDailyPickB, @n_MinAvgDailyPickB, @n_MaxAvgDailyPickB, @n_TMSkuMoveB, @n_TMSkuMoveTotalABC )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('C', @n_OriginTotalABC, @n_SkuC,  CEILING((@n_SkuC / @n_TotalABC) * 100), @n_AnalysisC, CEILING((@n_AnalysisC / @n_TotalABC) * 100)  
             ,@n_AvgDailyPickC, @n_MinAvgDailyPickC, @n_MaxAvgDailyPickC, @n_TMSkuMoveC, @n_TMSkuMoveTotalABC )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('D', @n_OriginTotalABC, @n_SkuD,  CEILING((@n_SkuD / @n_TotalABC) * 100), @n_AnalysisD, CEILING((@n_AnalysisD / @n_TotalABC) * 100)  
             ,@n_AvgDailyPickD, @n_MinAvgDailyPickD, @n_MaxAvgDailyPickD, @n_TMSkuMoveD, @n_TMSkuMoveTotalABC )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('N/A', @n_OriginTotalABC, @n_SkuNA,  CEILING((@n_SkuNA / @n_TotalABC) * 100), @n_AnalysisNA, CEILING((@n_AnalysisNA / @n_TotalABC) * 100)   
             ,@n_AvgDailyPickNA, @n_MinAvgDailyPickNA, @n_MaxAvgDailyPickNA, @n_TMSkuMoveNA, @n_TMSkuMoveTotalABC )

      GOTO QUIT
   END

   IF @c_type = 'EA' 
   BEGIN
      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('A', @n_OriginTotalABC, @n_SkuA,  CEILING((@n_SkuA / @n_TotalABC) * 100), @n_PAnalysisA, CEILING((@n_PAnalysisA / @n_TotalABC) * 100)  
             ,@n_PAvgDailyPickA, @n_PMinAvgDailyPickA, @n_PMaxAvgDailyPickA, 0, 0 )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('B', @n_OriginTotalABC, @n_SkuB,  CEILING((@n_SkuB / @n_TotalABC) * 100), @n_PAnalysisB, CEILING((@n_PAnalysisB / @n_TotalABC) * 100)   
             ,@n_PAvgDailyPickB, @n_PMinAvgDailyPickB, @n_PMaxAvgDailyPickB, 0, 0 )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('C', @n_OriginTotalABC, @n_SkuC,  CEILING((@n_SkuC / @n_TotalABC) * 100), @n_PAnalysisC, CEILING((@n_PAnalysisC / @n_TotalABC) * 100)  
             ,@n_PAvgDailyPickC, @n_PMinAvgDailyPickC, @n_PMaxAvgDailyPickC, 0, 0 )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('D', @n_OriginTotalABC, @n_SkuD,  CEILING((@n_SkuD / @n_TotalABC) * 100), @n_PAnalysisD, CEILING((@n_PAnalysisD / @n_TotalABC) * 100)   
             ,@n_PAvgDailyPickD, @n_PMinAvgDailyPickD, @n_PMaxAvgDailyPickD, 0, 0 )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('N/A', @n_OriginTotalABC, @n_SkuNA,  CEILING((@n_SkuNA / @n_TotalABC) * 100), @n_PAnalysisNA, CEILING((@n_PAnalysisNA / @n_TotalABC) * 100)   
             ,@n_PAvgDailyPickNA, @n_PMinAvgDailyPickNA, @n_PMaxAvgDailyPickNA, 0, 0 )

      GOTO QUIT
   END

   IF @c_type = 'CS' 
   BEGIN
      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('A', @n_OriginTotalABC, @n_SkuA,  CEILING((@n_SkuA / @n_TotalABC) * 100), @n_CAnalysisA, CEILING((@n_CAnalysisA / @n_TotalABC) * 100)  
             ,@n_CAvgDailyPickA, @n_CMinAvgDailyPickA, @n_CMaxAvgDailyPickA, 0, 0 )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('B', @n_OriginTotalABC, @n_SkuB,  CEILING((@n_SkuB / @n_TotalABC) * 100), @n_CAnalysisB, CEILING((@n_CAnalysisB / @n_TotalABC) * 100)  
             ,@n_CAvgDailyPickB, @n_CMinAvgDailyPickB, @n_CMaxAvgDailyPickB, 0, 0 )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('C', @n_OriginTotalABC, @n_SkuC,  CEILING((@n_SkuC / @n_TotalABC) * 100), @n_CAnalysisC, CEILING((@n_CAnalysisC / @n_TotalABC) * 100)   
             ,@n_CAvgDailyPickC, @n_CMinAvgDailyPickC, @n_CMaxAvgDailyPickC, 0, 0 )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('D', @n_OriginTotalABC, @n_SkuD,  CEILING((@n_SkuD / @n_TotalABC) * 100), @n_CAnalysisD, CEILING((@n_CAnalysisD / @n_TotalABC) * 100)   
             ,@n_CAvgDailyPickD, @n_CMinAvgDailyPickD, @n_CMaxAvgDailyPickD, 0, 0 )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('N/A', @n_OriginTotalABC, @n_SkuNA,  CEILING((@n_SkuNA / @n_TotalABC) * 100), @n_CAnalysisNA, CEILING((@n_CAnalysisNA / @n_TotalABC) * 100)  
             ,@n_CAvgDailyPickNA, @n_CMinAvgDailyPickNA, @n_CMaxAvgDailyPickNA, 0, 0 )

      GOTO QUIT
   END 

   IF @c_type = 'PL' 
   BEGIN
      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('A', @n_OriginTotalABC, @n_SkuA,  CEILING((@n_SkuA / @n_TotalABC) * 100), @n_BAnalysisA, CEILING((@n_BAnalysisA / @n_TotalABC) * 100)  
             ,@n_BAvgDailyPickA, @n_BMinAvgDailyPickA, @n_BMaxAvgDailyPickA, 0, 0 )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('B', @n_OriginTotalABC, @n_SkuB,  CEILING((@n_SkuB / @n_TotalABC) * 100), @n_BAnalysisB, CEILING((@n_BAnalysisB / @n_TotalABC) * 100)  
             ,@n_BAvgDailyPickB, @n_BMinAvgDailyPickB, @n_BMaxAvgDailyPickB, 0, 0 )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('C', @n_OriginTotalABC, @n_SkuC,  CEILING((@n_SkuC / @n_TotalABC) * 100), @n_BAnalysisC, CEILING((@n_BAnalysisC / @n_TotalABC) * 100)  
             ,@n_BAvgDailyPickC, @n_BMinAvgDailyPickC, @n_BMaxAvgDailyPickC, 0, 0 )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,  ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('D', @n_OriginTotalABC, @n_SkuD,  CEILING((@n_SkuD / @n_TotalABC) * 100), @n_BAnalysisD, CEILING((@n_BAnalysisD / @n_TotalABC) * 100)   
             ,@n_BAvgDailyPickD, @n_BMinAvgDailyPickD, @n_BMaxAvgDailyPickD, 0, 0 )

      INSERT INTO #TMP_SKUABC (ABC, TotalABC, CurrentABC, PerctgABC,   ProposedABC, PrectgProposedABC, AvgDailyPck, MinAvgDailyPck, MaxAvgDailyPck, TMSkuMoveABC, TMSkuMoveTotalABC )
      VALUES ('N/A', @n_OriginTotalABC, @n_SkuNA,  CEILING((@n_SkuNA / @n_TotalABC) * 100), @n_BAnalysisNA, CEILING((@n_BAnalysisNA / @n_TotalABC) * 100)  
             ,@n_BAvgDailyPickNA, @n_BMinAvgDailyPickNA, @n_BMaxAvgDailyPickNA, 0, 0 )

      GOTO QUIT
   END

   QUIT:
   SELECT ABC  
         ,TotalABC                      
         ,CurrentABC               
         ,PerctgABC                
         ,ProposedABC               
         ,PrectgProposedABC        
         ,AvgDailyPck              
         ,MinAvgDailyPck           
         ,MaxAvgDailyPck           
         ,TMSkuMoveABC                
         ,TMSkuMoveTotalABC 
   FROM #TMP_SKUABC 
END

GO