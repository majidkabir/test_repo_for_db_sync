SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Stored Procedure: ispGenPartialSkuAdj_MultiCnt                            */
/* Creation Date  : 28-Feb-2013                                              */
/* Copyright      : IDS                                                      */
/* Written by     : YTWan                                                    */
/*                                                                           */
/* Purpose: SOS#269704-CC Parameters Partial Posting                         */
/*                                                                           */
/* Called from: 1 (Stock Take )                                              */
/*    1. From PowerBuilder                                                   */
/*    2. From scheduler                                                      */
/*    3. From others stored procedures or triggers                           */
/*    4. From interface program. DX, DTS                                     */
/*                                                                           */
/* PVCS Version: 2.1                                                         */
/*                                                                           */
/* Version: 5.4                                                              */
/*                                                                           */
/* Data Modifications:                                                       */
/*                                                                           */
/* Updates:                                                                  */
/* Date         Author    Ver.  Purposes                                     */
/* 21-May-2014  TKLIM     1.1   Added Lottables 06-15                        */
/*****************************************************************************/

CREATE PROC [dbo].[ispGenPartialSkuAdj_MultiCnt] (
      @c_StockTakeKey  NVARCHAR(10) 
   ,  @c_CountNo       NVARCHAR(1) 
   ,  @b_success       INT          OUTPUT
   ,  @n_err           INT          OUTPUT
   ,  @c_errmsg        NVARCHAR(255) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON        
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue           INT
         , @b_debug              INT
         , @b_isok               INT 
         , @n_StartTCnt          INT

   DECLARE @c_ExcludeQtyPicked   NVARCHAR(1)
 
   DECLARE @c_SQL                NVARCHAR(4000)
         , @c_SkuSQL             NVARCHAR(4000)
         , @c_LocSQL             NVARCHAR(4000)

   DECLARE @c_Facility           NVARCHAR(5)
         , @c_AdjustmentKey      NVARCHAR(10) 
         , @c_AdjType            NVARCHAR(10)
         , @c_AdjReasonCode      NVARCHAR(10)
         , @c_AdjDetailLine      NVARCHAR(5) 
         , @c_StorerKey          NVARCHAR(15) 
         , @c_PrevStorerKey      NVARCHAR(15) 
         , @c_Sku                NVARCHAR(20)
         , @c_Lot                NVARCHAR(10) 
         , @c_Loc                NVARCHAR(10)
         , @c_Id                 NVARCHAR(18) 
         , @c_Lottable01         NVARCHAR(18) 
         , @c_Lottable02         NVARCHAR(18) 
         , @c_Lottable03         NVARCHAR(18) 
         , @d_Lottable04         DATETIME 
         , @d_Lottable05         DATETIME 
         , @c_Lottable06         NVARCHAR(30)
         , @c_Lottable07         NVARCHAR(30)
         , @c_Lottable08         NVARCHAR(30)
         , @c_Lottable09         NVARCHAR(30)
         , @c_Lottable10         NVARCHAR(30)
         , @c_Lottable11         NVARCHAR(30)
         , @c_Lottable12         NVARCHAR(30)
         , @d_Lottable13         DATETIME
         , @d_Lottable14         DATETIME
         , @d_Lottable15         DATETIME
         , @n_Qty                INT  
         , @c_UOM                NVARCHAR(10) 
         , @c_PackKey            NVARCHAR(10)

   SET @b_Success       = 1  
   SET @n_err           = 0
   SET @c_errmsg        = ''
   SET @n_Continue      = 1
   SET @b_debug         = 0
   SET @b_isok          = 0
   SET @n_StartTCnt     = @@TRANCOUNT

   SET @c_ExcludeQtyPicked = ''

   SET @c_AdjustmentKey = ''
   SET @c_AdjType       = ''
   SET @c_AdjReasonCode = ''
   SET @c_AdjDetailLine = ''
   SET @c_StorerKey     = ''
   SET @c_PrevStorerKey = ''
   SET @c_Sku           = ''
   SET @c_Lot           = ''
   SET @c_Loc           = ''
   SET @c_ID            = ''
   SET @c_Lottable01    = ''
   SET @c_Lottable02    = ''
   SET @c_Lottable03    = ''
   SET @c_Lottable06    = ''
   SET @c_Lottable07    = ''
   SET @c_Lottable08    = ''
   SET @c_Lottable09    = ''
   SET @c_Lottable10    = ''
   SET @c_Lottable11    = ''
   SET @c_Lottable12    = ''
   SET @n_Qty           = 0
   SET @c_UOM           = ''
   SET @c_PackKey       = ''

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   BEGIN TRAN

   DECLARE @tAdjustment TABLE (AdjustmentKey Char(10))

   SELECT @c_ExcludeQtyPicked = ISNULL(RTRIM(ExcludeQtyPicked),'')
         ,@c_AdjReasonCode = ISNULL(RTRIM(AdjReasonCode),'') 
         ,@c_AdjType       = ISNULL(RTRIM(AdjType),'')  
   FROM StockTakeSheetParameters WITH (NOLOCK)
   WHERE StockTakeKey = @c_StockTakeKey

   IF @c_CountNo NOT IN ('1','2','3')
   BEGIN
      SET @n_continue = 3
      SET @n_err = 67101
      SET @c_errmsg = 'NSQL' + CONVERT(Char(5), @n_err) + ': Bad Count Number. (ispGenPartialSkuAdj_MultiCnt)'
      GOTO EXIT_SP
   END

   CREATE TABLE #Withdraw  (
         StorerKey   NVARCHAR(15) NULL ,
         Sku         NVARCHAR(20) NOT NULL ,
         Lot         NVARCHAR(10) NULL ,
         Id          NVARCHAR(18) NULL,
         Loc         NVARCHAR(10) NOT NULL ,
         Qty         Int          NOT NULL,
         Lottable01  NVARCHAR(18) NULL ,
         Lottable02  NVARCHAR(18) NULL ,
         Lottable03  NVARCHAR(18) NULL ,
         Lottable04  DATETIME     NULL ,
         Lottable05  DATETIME     NULL ,
         Lottable06  NVARCHAR(30) NULL ,
         Lottable07  NVARCHAR(30) NULL ,
         Lottable08  NVARCHAR(30) NULL ,
         Lottable09  NVARCHAR(30) NULL ,
         Lottable10  NVARCHAR(30) NULL ,
         Lottable11  NVARCHAR(30) NULL ,
         Lottable12  NVARCHAR(30) NULL ,
         Lottable13  DATETIME     NULL ,
         Lottable14  DATETIME     NULL ,
         Lottable15  DATETIME     NULL 
   )
   CREATE TABLE #Deposit (
         StorerKey   NVARCHAR(15) NULL ,
         Sku         NVARCHAR(20) NOT NULL ,
         Lot         NVARCHAR(10) NULL ,
         Id          NVARCHAR(18) NULL,
         Loc         NVARCHAR(10) NOT NULL ,
         Qty         Int          NOT NULL,
         Lottable01  NVARCHAR(18) NULL ,
         Lottable02  NVARCHAR(18) NULL ,
         Lottable03  NVARCHAR(18) NULL ,
         Lottable04  DATETIME     NULL ,
         Lottable05  DATETIME     NULL ,
         Lottable06  NVARCHAR(30) NULL ,
         Lottable07  NVARCHAR(30) NULL ,
         Lottable08  NVARCHAR(30) NULL ,
         Lottable09  NVARCHAR(30) NULL ,
         Lottable10  NVARCHAR(30) NULL ,
         Lottable11  NVARCHAR(30) NULL ,
         Lottable12  NVARCHAR(30) NULL ,
         Lottable13  DATETIME     NULL ,
         Lottable14  DATETIME     NULL ,
         Lottable15  DATETIME     NULL 
   )
   CREATE TABLE #Variance (
         StorerKey   NVARCHAR(15) NULL ,
         Sku         NVARCHAR(20) NOT NULL ,
         Lot         NVARCHAR(10) NULL ,
         Id          NVARCHAR(18) NULL,
         Loc         NVARCHAR(10) NOT NULL ,
         Qty         Int          NOT NULL,
         Lottable01  NVARCHAR(18) NULL ,
         Lottable02  NVARCHAR(18) NULL ,
         Lottable03  NVARCHAR(18) NULL ,
         Lottable04  DATETIME     NULL ,
         Lottable05  DATETIME     NULL ,
         Lottable06  NVARCHAR(30) NULL ,
         Lottable07  NVARCHAR(30) NULL ,
         Lottable08  NVARCHAR(30) NULL ,
         Lottable09  NVARCHAR(30) NULL ,
         Lottable10  NVARCHAR(30) NULL ,
         Lottable11  NVARCHAR(30) NULL ,
         Lottable12  NVARCHAR(30) NULL ,
         Lottable13  DATETIME     NULL ,
         Lottable14  DATETIME     NULL ,
         Lottable15  DATETIME     NULL 
   )

   CREATE TABLE #Deposit2 ( -- SOS# 254455
         StorerKey   NVARCHAR(15) NULL ,
         Sku         NVARCHAR(20) NOT NULL ,
         Lot         NVARCHAR(10) NULL ,
         Id          NVARCHAR(18) NULL,
         Loc         NVARCHAR(10) NOT NULL ,
         Qty         Int          NOT NULL,
         Lottable01  NVARCHAR(18) NULL ,
         Lottable02  NVARCHAR(18) NULL ,
         Lottable03  NVARCHAR(18) NULL ,
         Lottable04  DATETIME     NULL ,
         Lottable05  DATETIME     NULL ,
         Lottable06  NVARCHAR(30) NULL ,
         Lottable07  NVARCHAR(30) NULL ,
         Lottable08  NVARCHAR(30) NULL ,
         Lottable09  NVARCHAR(30) NULL ,
         Lottable10  NVARCHAR(30) NULL ,
         Lottable11  NVARCHAR(30) NULL ,
         Lottable12  NVARCHAR(30) NULL ,
         Lottable13  DATETIME     NULL ,
         Lottable14  DATETIME     NULL ,
         Lottable15  DATETIME     NULL 
   )

   SET @c_SQL = N' SELECT LOTxLOCxID.StorerKey'
              + ' ,LOTxLOCxID.Sku'
              + ' ,LOTxLOCxID.Lot'
              + ' ,LOTxLOCxID.Id'
              + ' ,LOTxLOCxID.Loc'
              +   CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN ', LOTxLOCxID.Qty-LOTxLOCxID.qtypicked' ELSE ', LOTxLOCxID.Qty' END
              + ' ,ISNULL(LOTATTRIBUTE.Lottable01, '''')'
              + ' ,ISNULL(LOTATTRIBUTE.Lottable02, '''')'
              + ' ,ISNULL(LOTATTRIBUTE.Lottable03, '''')'
              + ' ,LOTATTRIBUTE.Lottable04'    
              + ' ,LOTATTRIBUTE.Lottable05'
              + ' ,ISNULL(LOTATTRIBUTE.Lottable06, '''')'
              + ' ,ISNULL(LOTATTRIBUTE.Lottable07, '''')'
              + ' ,ISNULL(LOTATTRIBUTE.Lottable08, '''')'
              + ' ,ISNULL(LOTATTRIBUTE.Lottable09, '''')'
              + ' ,ISNULL(LOTATTRIBUTE.Lottable10, '''')'
              + ' ,ISNULL(LOTATTRIBUTE.Lottable11, '''')'
              + ' ,ISNULL(LOTATTRIBUTE.Lottable12, '''')'
              + ' ,LOTATTRIBUTE.Lottable13'
              + ' ,LOTATTRIBUTE.Lottable14'    
              + ' ,LOTATTRIBUTE.Lottable15'
              + ' FROM CCDETAIL   WITH (NOLOCK)'
              + ' JOIN LOTxLOCxID WITH (NOLOCK)   ON (CCDETAIL.Lot = LOTxLOCxID.Lot)'
              +                                 ' AND(CCDETAIL.Loc = LOTxLOCxID.Loc)'
              +                                 ' AND(CCDETAIL.ID  = LOTxLOCxID.Id)'
              + ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON (CCDETAIL.Lot = LOTATTRIBUTE.Lot)'
              + ' WHERE CCDETAIL.CCKey = ''' + @c_Stocktakekey + ''''
              + CASE WHEN @c_ExcludeQtyPicked = 'Y' THEN ' AND LOTxLOCxID.Qty-LOTxLOCxID.qtypicked > 0' ELSE 'AND LOTxLOCxID.Qty > 0' END
              + CASE WHEN @c_CountNo = '1' THEN ' AND CCDETAIL.Counted_Cnt1 = ''1'''
                     WHEN @c_CountNo = '2' THEN ' AND CCDETAIL.Counted_Cnt2 = ''1'''
                     WHEN @c_CountNo = '3' THEN ' AND CCDETAIL.Counted_Cnt3 = ''1'''
                     END
   INSERT INTO #Withdraw (StorerKey, Sku, Lot, Id, Loc, Qty, 
                           Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
                           Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                           Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
   EXEC ( @c_SQL )

   IF @b_debug = 1
   BEGIN
      SELECT @c_SQL
      SELECT * FROM #Withdraw
   END


   -- Generate Deposit Transaction From CCDETAIL Table

   SET @c_SQL  = N'SELECT CCDETAIL.StorerKey, CCDETAIL.Sku '
               + ','''' as Lot, CCDETAIL.Id, CCDETAIL.Loc '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.Qty '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.qty_Cnt2 '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.qty_Cnt3 '
               + ' END As Qty '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.Lottable01,'''') '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.Lottable01_Cnt2,'''') '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.Lottable01_Cnt3,'''') '
               + ' END As Lottable01 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.Lottable02,'''') '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.Lottable02_Cnt2,'''') '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.Lottable02_Cnt3,'''') '
               + ' END As Lottable02 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.Lottable03,'''') '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.Lottable03_Cnt2,'''') '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.Lottable03_Cnt3,'''') '
               + ' END As Lottable03 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.Lottable04 '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.Lottable04_Cnt2 '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.Lottable04_Cnt3 '
               + ' END As Lottable04 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.Lottable05 '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.Lottable05_Cnt2 '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.Lottable05_Cnt3 '
               + ' END As Lottable05 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.Lottable06,'''') '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.Lottable06_Cnt2,'''') '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.Lottable06_Cnt3,'''') '
               + ' END As Lottable06 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.Lottable07,'''') '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.Lottable07_Cnt2,'''') '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.Lottable07_Cnt3,'''') '
               + ' END As Lottable07 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.Lottable08,'''') '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.Lottable08_Cnt2,'''') '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.Lottable08_Cnt3,'''') '
               + ' END As Lottable08 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.Lottable09,'''') '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.Lottable09_Cnt2,'''') '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.Lottable09_Cnt3,'''') '
               + ' END As Lottable09 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.Lottable10,'''') '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.Lottable10_Cnt2,'''') '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.Lottable10_Cnt3,'''') '
               + ' END As Lottable10 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.Lottable11,'''') '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.Lottable11_Cnt2,'''') '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.Lottable11_Cnt3,'''') '
               + ' END As Lottable11 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN ISNULL(CCDETAIL.Lottable12,'''') '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN ISNULL(CCDETAIL.Lottable12_Cnt2,'''') '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN ISNULL(CCDETAIL.Lottable12_Cnt3,'''') '
               + ' END As Lottable12 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.Lottable13 '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.Lottable13_Cnt2 '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.Lottable13_Cnt3 '
               + ' END As Lottable13 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.Lottable14 '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.Lottable14_Cnt2 '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.Lottable14_Cnt3 '
               + ' END As Lottable14 '
               + ',CASE WHEN ' + @c_CountNo + ' = 1 THEN CCDETAIL.Lottable15 '
               + '      WHEN ' + @c_CountNo + ' = 2 THEN CCDETAIL.Lottable15_Cnt2 '
               + '      WHEN ' + @c_CountNo + ' = 3 THEN CCDETAIL.Lottable15_Cnt3 '
               + ' END As Lottable15 '
               + ' FROM CCDETAIL WITH (NOLOCK) '
               + ' JOIN SKU      WITH (NOLOCK) ON (CCDETAIL.StorerKey = Sku.StorerKey)'
               +                             ' AND(CCDETAIL.Sku = Sku.Sku)'
               + ' WHERE CCDETAIL.CCKEY = ''' + @c_StockTakeKey + ''''
               + CASE WHEN @c_CountNo = '1' THEN 'AND CCDETAIL.Qty > 0 AND CCDETAIL.FinalizeFlag = ''Y'' AND CCDETAIL.Counted_Cnt1 = ''1'''
                     WHEN @c_CountNo = '2' THEN 'AND CCDETAIL.QTY_Cnt2 > 0 AND CCDETAIL.FinalizeFlag_Cnt2 = ''Y'' AND CCDETAIL.Counted_Cnt2 = ''1'''
                     WHEN @c_CountNo = '3' THEN 'AND CCDETAIL.QTY_Cnt3 > 0 AND CCDETAIL.FinalizeFlag_Cnt3 = ''Y'' AND CCDETAIL.Counted_Cnt3 = ''1'''
                     END


   INSERT INTO #Deposit (StorerKey, Sku, Lot, Id, Loc, Qty,
                           Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
                           Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                           Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
   EXEC ( @c_SQL )

   IF @@ERROR <> 0
   BEGIN
      SET @n_continue = 3
      GOTO EXIT_SP
   END

   IF @b_debug = 1
   BEGIN
      SELECT * FROM #Deposit
   END

   -- Assign Lot# to #Deposit
   DECLARE CUR1 CURSOR READ_ONLY FAST_FORWARD FOR
   SELECT StorerKey, Sku, 
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
   FROM   #Deposit
   WHERE ISNULL(RTRIM(Lot),'') = ''
   AND    Qty > 0

   OPEN CUR1
   FETCH NEXT FROM CUR1 INTO @c_StorerKey, @c_Sku, 
                              @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                              @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                              @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
   WHILE @@fetch_status <> -1
   BEGIN

      SET @b_isok = 0
      EXECUTE nsp_LotLookUp
              @c_StorerKey
            , @c_Sku
            , @c_Lottable01
            , @c_Lottable02
            , @c_Lottable03
            , @d_Lottable04
            , @d_Lottable05
            , @c_Lottable06
            , @c_Lottable07
            , @c_Lottable08
            , @c_Lottable09
            , @c_Lottable10
            , @c_Lottable11
            , @c_Lottable12
            , @d_Lottable13
            , @d_Lottable14
            , @d_Lottable15
            , @c_Lot      OUTPUT
            , @b_isok     OUTPUT
            , @n_err      OUTPUT
            , @c_errmsg   OUTPUT

      IF @b_isok = 1
      BEGIN
         /* Add To Lotattribute File */
         SET @b_isok = 0
         EXECUTE nsp_LotGen
                 @c_StorerKey
               , @c_Sku
               , @c_Lottable01
               , @c_Lottable02
               , @c_Lottable03
               , @d_Lottable04
               , @d_Lottable05
               , @c_Lottable06
               , @c_Lottable07
               , @c_Lottable08
               , @c_Lottable09
               , @c_Lottable10
               , @c_Lottable11
               , @c_Lottable12
               , @d_Lottable13
               , @d_Lottable14
               , @d_Lottable15
               , @c_Lot      OUTPUT
               , @b_isok     OUTPUT
               , @n_err      OUTPUT
               , @c_errmsg   OUTPUT

         IF @b_isok <> 1
         BEGIN
            SET @n_continue = 3
         END

         IF ISNULL(RTRIM(@c_Lot),'') <> ''
         BEGIN
             UPDATE #Deposit SET Lot = @c_Lot
             WHERE StorerKey = @c_StorerKey
             AND   Sku = @c_Sku
             AND   Lottable01 = @c_Lottable01
             AND   Lottable02 = @c_Lottable02
             AND   Lottable03 = @c_Lottable03
             AND   ISNULL(Lottable04,'19000101') = ISNULL(@d_Lottable04,'19000101')
             AND   ISNULL(Lottable05,'19000101') = ISNULL(@d_Lottable05,'19000101')
             AND   Lottable06 = @c_Lottable06
             AND   Lottable07 = @c_Lottable07
             AND   Lottable08 = @c_Lottable08
             AND   Lottable09 = @c_Lottable09
             AND   Lottable10 = @c_Lottable10
             AND   Lottable11 = @c_Lottable11
             AND   Lottable12 = @c_Lottable12
             AND   ISNULL(Lottable13,'19000101') = ISNULL(@d_Lottable13,'19000101')
             AND   ISNULL(Lottable14,'19000101') = ISNULL(@d_Lottable14,'19000101')
             AND   ISNULL(Lottable15,'19000101') = ISNULL(@d_Lottable15,'19000101')
             AND   ISNULL(RTRIM(Lot),'') = ''
         END
      END
      FETCH NEXT FROM CUR1 INTO @c_StorerKey, @c_Sku, 
                                 @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                 @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                 @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
   END -- while
   CLOSE CUR1
   DEALLOCATE CUR1

   INSERT INTO #Deposit2 (StorerKey, Sku, Lot, Id, Loc, Qty, 
         Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
   SELECT StorerKey, Sku, Lot, Id, Loc, SUM(Qty),
         Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
   FROM #Deposit
   GROUP BY StorerKey, Sku, Lot, Id, Loc, 
         Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15


   -- (Deposit) Insert Lot Found in Stock Take which is not in LOTxLOCxID (System)
   INSERT INTO #Variance (StorerKey, Sku, Lot, Id, Loc, Qty, 
         Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
   SELECT D.StorerKey, D.Sku, D.Lot, D.Id, D.Loc, D.Qty, 
         D.Lottable01, D.Lottable02, D.Lottable03, D.Lottable04, D.Lottable05,
         D.Lottable06, D.Lottable07, D.Lottable08, D.Lottable09, D.Lottable10, 
         D.Lottable11, D.Lottable12, D.Lottable13, D.Lottable14, D.Lottable15
   FROM   #Deposit2 D
   LEFT OUTER JOIN #WithDraw W ON (W.Lot = D.Lot and W.Loc = D.Loc and W.Id = D.Id)
   WHERE W.Lot IS NULL

   -- (Withdraw) INSERT Lot That not in Count But Exists in LOTxLOCxID (System)
   INSERT INTO #Variance (StorerKey, Sku, Lot, Id, Loc, Qty, 
         Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
   SELECT W.StorerKey, W.Sku, W.Lot, W.Id, W.Loc, (W.Qty * -1), 
         W.Lottable01, W.Lottable02, W.Lottable03, W.Lottable04, W.Lottable05,
         W.Lottable06, W.Lottable07, W.Lottable08, W.Lottable09, W.Lottable10, 
         W.Lottable11, W.Lottable12, W.Lottable13, W.Lottable14, W.Lottable15
   FROM   #WithDraw W
   LEFT OUTER JOIN #Deposit2 D ON (W.Lot = D.Lot and W.Loc = D.Loc and W.Id = D.Id)
   WHERE D.Lot IS NULL

   INSERT INTO #Variance (StorerKey, Sku, Lot, Id, Loc, Qty, 
         Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
   SELECT W.StorerKey, W.Sku, W.Lot, W.Id, W.Loc,
         CASE WHEN W.Qty > D.Qty THEN D.Qty - W.Qty -- System > Counted (Withdraw)
               ELSE D.Qty - W.Qty -- Count > System (Deposit)
         END,
         W.Lottable01, W.Lottable02, W.Lottable03, W.Lottable04, W.Lottable05,
         W.Lottable06, W.Lottable07, W.Lottable08, W.Lottable09, W.Lottable10, 
         W.Lottable11, W.Lottable12, W.Lottable13, W.Lottable14, W.Lottable15
   FROM   #WithDraw W
   INNER JOIN #Deposit2 D ON (W.Lot = D.Lot and W.Loc = D.Loc and W.Id = D.Id)
   WHERE D.Qty <> W.Qty

   IF @b_debug = 1
   BEGIN
      SELECT * FROM #Variance
   END


   IF EXISTS(SELECT 1 FROM #Variance)
   BEGIN
      SET @c_PrevStorerKey = ''
      DECLARE CUR2 CURSOR READ_ONLY FAST_FORWARD FOR
      SELECT V.StorerKey, V.Sku, V.Lot, V.Id, V.Loc, V.Qty, P.PackKey, P.PackUOM3,
            V.Lottable01, V.Lottable02, V.Lottable03, V.Lottable04, V.Lottable05,
            V.Lottable06, V.Lottable07, V.Lottable08, V.Lottable09, V.Lottable10, 
            V.Lottable11, V.Lottable12, V.Lottable13, V.Lottable14, V.Lottable15
      FROM   #Variance V
      JOIN   Sku S (NOLOCK)  ON (S.StorerKey = V.StorerKey) AND (S.Sku = V.Sku)
      JOIN   PACK P (NOLOCK) ON (S.PackKey = P.PackKey)
      ORDER BY V.StorerKey, V.Sku

      OPEN CUR2
      FETCH NEXT FROM CUR2 INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Id, @c_Loc, @n_Qty, @c_PackKey, @c_UOM,
                                 @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                 @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                 @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_PrevStorerKey <> @c_StorerKey
         BEGIN
            EXECUTE nspg_GetKey
                    'Adjustment'
                  , 10
                  , @c_AdjustmentKey OUTPUT
                  , @b_success       OUTPUT
                  , @n_err           OUTPUT
                  , @c_errmsg        OUTPUT

            IF NOT @b_success = 1
            BEGIN
               SET @n_continue = 3
               SET @n_err = 67102
               SET @c_errmsg = 'NSQL' + CONVERT(Char(5), @n_err) + ': Unable to Obtain Adjustment key. (ispGenPartialSkuAdj_MultiCnt) (SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO EXIT_SP
            END
            ELSE -- insert new Adjustment header record
            BEGIN
               INSERT INTO Adjustment (AdjustmentKey, AdjustmentType, StorerKey, Facility, CustomerRefNo, Remarks)
               VALUES (@c_AdjustmentKey, @c_AdjType, @c_StorerKey, @c_Facility, @c_StockTakeKey, '')

               SET @n_err = @@error
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 67103
                  SET @c_errmsg = 'NSQL' + CONVERT(Char(5), @n_err) + ': Failed to Create Adjustment Header. (ispGenPartialSkuAdj_MultiCnt) ( SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                  GOTO EXIT_SP
               END
            END
            SET @c_PrevStorerKey = @c_StorerKey
         END

         SELECT @c_AdjDetailLine = RIGHT('0000' + RTRIM(CAST((ISNULL(MAX(AdjustmentLineNumber),0) + 1) AS Char(5))),5)
         FROM  AdjustmentDetail WITH (NOLOCK)
         WHERE AdjustmentKey = @c_AdjustmentKey

         INSERT INTO AdjustmentDetail ( AdjustmentKey, AdjustmentLineNumber, StorerKey, Sku, Loc, Lot, Id, ReasonCode, UOM, PackKey, Qty, 
                  Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, FinalizedFlag ) 
         VALUES ( @c_AdjustmentKey, @c_AdjDetailLine, @c_StorerKey, @c_Sku, @c_Loc, @c_Lot, @c_Id, @c_AdjReasonCode, @c_UOM, @c_PackKey, @n_Qty,
                  @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                  @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                  @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, 'N' )

         SET @n_err = @@error
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 67104
            SET @c_errmsg = 'NSQL' + CONVERT(Char(5), @n_err) + ': Failed to Create Adjustment Detail. (ispGenPartialSkuAdj_MultiCnt) ( SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            BREAK
         END

         FETCH NEXT FROM CUR2 INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Id, @c_Loc, @n_Qty, @c_PackKey, @c_UOM,
                                    @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                                    @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                    @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
      END -- while cursor
      CLOSE CUR2
      DEALLOCATE CUR2
   END

   IF EXISTS (SELECT 1 FROM ADJUSTMENT WITH (NOLOCK) WHERE CustomerRefNo = @c_StockTakeKey)
   BEGIN
      UPDATE CCDETAIL
      SET    CCDETAIL.Status = '9'
      WHERE  CCDETAIL.CCKEY = @c_StockTakeKey

      SET @c_errmsg = 'Adjustment Generated Sucessfully!'
   END
   ELSE
   BEGIN
      SET @c_errmsg = 'Nothing To Adjust'
   END

EXIT_SP:
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'ispGenPartialSkuAdj_MultiCnt'
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END


GO