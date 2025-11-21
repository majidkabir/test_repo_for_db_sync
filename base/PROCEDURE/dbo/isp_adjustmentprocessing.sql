SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_AdjustmentProcessing                                */
/* Creation Date: 29-JUN-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: WMS-17314 - Adjustment allocation by lottable with empty    */
/*          from lot.                                                   */
/*          Use skip preallcation pickcode structure.                   */
/*          pre-allocation filter include adjustment detail             */
/*                                                                      */
/* Called By: Adjustment allocate RCM                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */ 
/************************************************************************/
CREATE PROC  [dbo].[isp_AdjustmentProcessing]  
               @c_AdjustmentKey   NVARCHAR(10)               
,              @b_Success  INT            OUTPUT
,              @n_err      INT            OUTPUT
,              @c_errmsg   NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue                 INT
         , @n_StartTCnt                INT -- Holds the current transaction count
         , @n_cnt                      INT -- Holds @@ROWCOUNT after certain operations
         , @b_debug                    INT -- Debug: 0 - OFF, 1 - show all, 2 - map

   DECLARE @c_MinShelfLife60Mth        NVARCHAR(10)
         , @c_ShelfLifeInDays          NVARCHAR(10)       

   DECLARE @c_aFacility                NVARCHAR(5)
         , @c_aAdjustmentKey           NVARCHAR(10)
         , @c_aAdjustmentLineNumber    NVARCHAR(5) 
         , @c_aStorerkey               NVARCHAR(15)
         , @c_aSku                     NVARCHAR(20)
         , @c_aPackKey                 NVARCHAR(10)
         , @c_aUOM                     NVARCHAR(10)
         , @n_aUOMQty                  INT 
         , @n_aQtyLeftToFulfill        INT
         , @c_aLot                     NVARCHAR(10)
         , @c_aStrategyKey             NVARCHAR(10)
         , @n_MinShelfLife             INT
         , @c_Lottable01               NVARCHAR(18)
         , @c_Lottable02               NVARCHAR(18)
         , @c_Lottable03               NVARCHAR(18)
         , @dt_Lottable04              DATETIME
         , @dt_Lottable05              DATETIME
         , @c_Lottable04               NVARCHAR(18)
         , @c_Lottable05               NVARCHAR(18)
         , @c_Lottable06               NVARCHAR(30)
         , @c_Lottable07               NVARCHAR(30)
         , @c_Lottable08               NVARCHAR(30)
         , @c_Lottable09               NVARCHAR(30)
         , @c_Lottable10               NVARCHAR(30)
         , @c_Lottable11               NVARCHAR(30)
         , @c_Lottable12               NVARCHAR(30)
         , @dt_Lottable13              DATETIME
         , @dt_Lottable14              DATETIME
         , @dt_Lottable15              DATETIME
         , @c_Lottable13               NVARCHAR(30)
         , @c_Lottable14               NVARCHAR(30)
         , @c_Lottable15               NVARCHAR(30)
         , @n_AdjPlusMinus             INT

   DECLARE @n_Caseqty                  INT
         , @n_Palletqty                INT
         , @n_Innerpackqty             INT
         , @n_Otherunit1               INT 
         , @n_Otherunit2               INT
         , @n_PackQty                  INT

   DECLARE @n_CursorCandidates_Open    INT
         , @c_PStorerkey               NVARCHAR(15)
         , @c_ExecuteSP                NVARCHAR(MAX)
         , @c_ParmName                 NVARCHAR(255)
         , @c_Lottable_Parm            NVARCHAR(20)
         , @c_LocType                  NVARCHAR(20)
         , @n_OrdinalPosition          INT
         , @c_ALLineNo                 NVARCHAR(5)
         , @c_AllocatePickCode         NVARCHAR(10)
         , @c_HostWHCode               NVARCHAR(10)
         , @c_OtherParms               NVARCHAR(255)
         , @c_Lot                      NVARCHAR(10)
         , @c_Loc                      NVARCHAR(10)
         , @c_ID                       NVARCHAR(18)
         , @n_Available                INT  
         , @n_QtyAvailable             INT
         , @n_QtyToTake                INT
         , @c_AdjustmentAllocateNoConso  NVARCHAR(10)
         , @c_AdjustmentAllocateStrategykey NVARCHAR(10)

   DECLARE @c_NewAdjustmentLineNumber NVARCHAR(5)
         , @c_AdjustmentLineNumber NVARCHAR(5)
         , @n_BalQty INT
         , @n_Qty INT
         , @n_SplitQty INT
         , @n_AllocatedLineCnt INT
         , @n_OpenLineCnt INT
         
   IF OBJECT_ID('tempdb..#ALLOCATE_CANDIDATES','u') IS NOT NULL
   BEGIN
      DROP TABLE #ALLOCATE_CANDIDATES;
   END

   CREATE TABLE #ALLOCATE_CANDIDATES
   (  RowID          INT            NOT NULL IDENTITY(1,1) 
   ,  Lot            NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  Loc            NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  ID             NVARCHAR(18)   NOT NULL DEFAULT('')
   ,  QtyAvailable   INT            NOT NULL DEFAULT(0)
   ,  OtherValue     NVARCHAR(20)   NOT NULL DEFAULT('')   
   )

   IF @n_err = 1
      SET @b_debug = 1
   ELSE
      SET @b_debug = 0

   SELECT @n_StartTCnt = @@TRANCOUNT, @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''
           
   SELECT @c_MinShelfLife60Mth = '', @c_ShelfLifeInDays = '', @n_CursorCandidates_Open = 0, @c_PStorerkey = '', @c_HostWHCode  = ''
   
   SELECT @c_aStorerkey = Storerkey,
          @c_aFacility = Facility
   FROM ADJUSTMENT (NOLOCK)
   WHERE Adjustmentkey = @c_Adjustmentkey
         
   SELECT @c_AdjustmentAllocateNoConso = dbo.fnc_GetRight(@c_aFacility, @c_aStorerkey, '', 'AdjustmentAllocateNoConso') 
   SELECT @c_AdjustmentAllocateStrategykey = dbo.fnc_GetRight(@c_aFacility, @c_aStorerkey, '', 'AdjustmentAllocateStrategykey') 
   
   IF ISNULL(@c_AdjustmentAllocateStrategykey,'') NOT IN ('','0','1') 
   BEGIN
   	  IF NOT EXISTS(SELECT 1 FROM ALLOCATESTRATEGY AST(NOLOCK)
   	                JOIN ALLOCATESTRATEGYDETAIL ASTD (NOLOCK) ON AST.AllocateStrategykey = ASTD.AllocateStrategykey
   	                WHERE AST.AllocateStrategykey = @c_AdjustmentAllocateStrategykey)
   	  BEGIN
         SET @n_continue = 3
         SET @n_err = 63500   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Invalid alloation strategykey at storerconfig AdjustmentAllocateStrategykey (isp_AdjustmentProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
         GOTO EXIT_SP   	        
   	  END                 	                
   END
                                            
   --Store original qty to userdefine09 if not empty
   UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK)
   SET Userdefine09 = CAST(Qty AS NVARCHAR),
       TrafficCop = NULL
   WHERE Adjustmentkey = @c_Adjustmentkey
   AND ISNULL(Lot,'') = ''
   AND ISNULL(Userdefine09,'') = ''
      
   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63510   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update adjustmentdetail Failed! (isp_AdjustmentProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
      GOTO EXIT_SP
   END
		   	 
   CREATE TABLE #OPADJUSTLINES 
         (  [SeqNo]                    [INT] IDENTITY(1, 1)
         ,  [Facility]                 [NVARCHAR](5)  NOT NULL
         ,  [AdjustmentKey]            [NVARCHAR](10) NOT NULL
         ,  [AdjustmentLineNumber]     [NVARCHAR](5)  NOT NULL
         ,  [Storerkey]                [NVARCHAR](15) NOT NULL
         ,  [Sku]                      [NVARCHAR](20) NOT NULL
         ,  [Qty]                      [INT]          NOT NULL
         ,  [Packkey]                  [NVARCHAR](10) NOT NULL
         ,  [StrategyKey]              [NVARCHAR](10) NOT NULL
         ,  [MinShelf]                 [INT]          NOT NULL
         ,  [Lottable01]               [NVARCHAR](18) NOT NULL
         ,  [Lottable02]               [NVARCHAR](18) NOT NULL
         ,  [Lottable03]               [NVARCHAR](18) NOT NULL
         ,  [Lottable04]               [DATETIME]     NOT NULL
         ,  [Lottable05]               [DATETIME]     NOT NULL
         ,  [Lottable06]               [NVARCHAR](30) NOT NULL
         ,  [Lottable07]               [NVARCHAR](30) NOT NULL
         ,  [Lottable08]               [NVARCHAR](30) NOT NULL
         ,  [Lottable09]               [NVARCHAR](30) NOT NULL
         ,  [Lottable10]               [NVARCHAR](30) NOT NULL
         ,  [Lottable11]               [NVARCHAR](30) NOT NULL
         ,  [Lottable12]               [NVARCHAR](30) NOT NULL
         ,  [Lottable13]               [DATETIME]     NOT NULL
         ,  [Lottable14]               [DATETIME]     NOT NULL
         ,  [Lottable15]               [DATETIME]     NOT NULL
         )

   INSERT INTO #OPADJUSTLINES
         (  [Facility]                  
         ,  [AdjustmentKey]                    
         ,  [AdjustmentLineNumber]                   
         ,  [Storerkey]                 
         ,  [Sku] 
         ,  [Qty]                       
         ,  [Packkey]                   
         ,  [StrategyKey]
         ,  [MinShelf]  
         ,  [Lottable01] 
         ,  [Lottable02] 
         ,  [Lottable03] 
         ,  [Lottable04] 
         ,  [Lottable05] 
         ,  [Lottable06] 
         ,  [Lottable07] 
         ,  [Lottable08] 
         ,  [Lottable09] 
         ,  [Lottable10] 
         ,  [Lottable11] 
         ,  [Lottable12] 
         ,  [Lottable13] 
         ,  [Lottable14] 
         ,  [Lottable15]             
         )
   SELECT   Facility = ISNULL(RTRIM(ADJUSTMENT.Facility),'')
         ,  AdjustmentKey = ISNULL(RTRIM(ADJUSTMENT.Adjustmentkey),'')
         ,  adjustmentLineNumber = ISNULL(RTRIM(ADJUSTMENTDETAIL.AdjustmentLineNumber),'')
         ,  Storerkey= ISNULL(RTRIM(ADJUSTMENTDETAIL.Storerkey),'')
         ,  Sku      = ISNULL(RTRIM(ADJUSTMENTDETAIL.Sku),'')
         ,  Qty      = ISNULL(ADJUSTMENTDETAIL.Qty,0)
         ,  Packkey  = ISNULL(RTRIM(ADJUSTMENTDETAIL.Packkey),'')
         ,  StrategyKey = CASE WHEN ISNULL(@c_AdjustmentAllocateStrategykey,'') NOT IN ('','0','1') THEN @c_AdjustmentAllocateStrategykey 
                               ELSE ISNULL(RTRIM(STGY.TransferStrategyKey),'') END 
         ,  MinShelf    = 0
         ,  Lottable01  = ISNULL(RTRIM(ADJUSTMENTDETAIL.Lottable01),'')
         ,  Lottable02  = ISNULL(RTRIM(ADJUSTMENTDETAIL.Lottable02),'')
         ,  Lottable03  = ISNULL(RTRIM(ADJUSTMENTDETAIL.Lottable03),'')
         ,  Lottable04  = ISNULL(ADJUSTMENTDETAIL.Lottable04, '19000101')
         ,  Lottable05  = ISNULL(ADJUSTMENTDETAIL.Lottable05, '19000101')
         ,  Lottable06  = ISNULL(RTRIM(ADJUSTMENTDETAIL.Lottable06),'')
         ,  Lottable07  = ISNULL(RTRIM(ADJUSTMENTDETAIL.Lottable07),'')
         ,  Lottable08  = ISNULL(RTRIM(ADJUSTMENTDETAIL.Lottable08),'')
         ,  Lottable09  = ISNULL(RTRIM(ADJUSTMENTDETAIL.Lottable09),'')
         ,  Lottable10  = ISNULL(RTRIM(ADJUSTMENTDETAIL.Lottable10),'')
         ,  Lottable11  = ISNULL(RTRIM(ADJUSTMENTDETAIL.Lottable11),'')
         ,  Lottable12  = ISNULL(RTRIM(ADJUSTMENTDETAIL.Lottable12),'')
         ,  Lottable13  = ISNULL(ADJUSTMENTDETAIL.Lottable13, '19000101')
         ,  Lottable14  = ISNULL(ADJUSTMENTDETAIL.Lottable14, '19000101')
         ,  Lottable15  = ISNULL(ADJUSTMENTDETAIL.Lottable15, '19000101')
      FROM  ADJUSTMENT (NOLOCK)
      JOIN  ADJUSTMENTDETAIL (NOLOCK) ON ADJUSTMENT.Adjustmentkey = ADJUSTMENTDETAIL.Adjustmentkey
      JOIN  SKU (NOLOCK) ON ADJUSTMENTDETAIL.Storerkey = SKU.StorerKey AND ADJUSTMENTDETAIL.Sku = SKU.Sku
      JOIN  STRATEGY STGY (NOLOCK) ON SKU.Strategykey = STGY.StrategyKey
      WHERE ADJUSTMENT.Adjustmentkey = @c_Adjustmentkey
      AND ISNULL(ADJUSTMENTDETAIL.Lot,'') = ''
      AND ADJUSTMENTDETAIL.FinalizedFlag = 'N'
      ORDER BY ADJUSTMENTDETAIL.SKU
      
   SET @n_cnt = @@ROWCOUNT      
   
   IF @b_debug = 1 or @b_debug = 2
      SELECT * FROM #OPADJUSTLINES
   
   IF @n_cnt = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63520   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': No Available Adjustment Line To Allocate.(Empty Lot) (isp_AdjustmentProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
      GOTO EXIT_SP
   END      
   
   IF @c_AdjustmentAllocateNoConso = 'Y'  
   BEGIN
      DECLARE ADJUSTLINES_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT   #OPADJUSTLINES.AdjustmentKey
            ,  #OPADJUSTLINES.Facility
            ,  #OPADJUSTLINES.StorerKey
            ,  #OPADJUSTLINES.SKU
            ,  #OPADJUSTLINES.PackKey
            ,  SUM(#OPADJUSTLINES.Qty) AS Qty
            ,  #OPADJUSTLINES.StrategyKey
            ,  #OPADJUSTLINES.MinShelf 
            ,  #OPADJUSTLINES.Lottable01 
            ,  #OPADJUSTLINES.Lottable02
            ,  #OPADJUSTLINES.Lottable03 
            ,  #OPADJUSTLINES.Lottable04 
            ,  #OPADJUSTLINES.Lottable05 
            ,  #OPADJUSTLINES.Lottable06 
            ,  #OPADJUSTLINES.Lottable07 
            ,  #OPADJUSTLINES.Lottable08 
            ,  #OPADJUSTLINES.Lottable09 
            ,  #OPADJUSTLINES.Lottable10 
            ,  #OPADJUSTLINES.Lottable11 
            ,  #OPADJUSTLINES.Lottable12 
            ,  #OPADJUSTLINES.Lottable13 
            ,  #OPADJUSTLINES.Lottable14 
            ,  #OPADJUSTLINES.Lottable15
            ,  #OPADJUSTLINES.AdjustmentLineNumber
        FROM #OPADJUSTLINES 
        GROUP BY #OPADJUSTLINES.AdjustmentKey
            ,  #OPADJUSTLINES.Facility
            ,  #OPADJUSTLINES.StorerKey
            ,  #OPADJUSTLINES.SKU
            ,  #OPADJUSTLINES.PackKey
            ,  #OPADJUSTLINES.StrategyKey
            ,  #OPADJUSTLINES.MinShelf 
            ,  #OPADJUSTLINES.Lottable01 
            ,  #OPADJUSTLINES.Lottable02
            ,  #OPADJUSTLINES.Lottable03 
            ,  #OPADJUSTLINES.Lottable04 
            ,  #OPADJUSTLINES.Lottable05 
            ,  #OPADJUSTLINES.Lottable06 
            ,  #OPADJUSTLINES.Lottable07 
            ,  #OPADJUSTLINES.Lottable08 
            ,  #OPADJUSTLINES.Lottable09 
            ,  #OPADJUSTLINES.Lottable10 
            ,  #OPADJUSTLINES.Lottable11 
            ,  #OPADJUSTLINES.Lottable12 
            ,  #OPADJUSTLINES.Lottable13 
            ,  #OPADJUSTLINES.Lottable14 
            ,  #OPADJUSTLINES.Lottable15
            ,  #OPADJUSTLINES.AdjustmentLineNumber
         ORDER BY #OPADJUSTLINES.StorerKey, #OPADJUSTLINES.SKU
   END   
   ELSE
   BEGIN
      DECLARE ADJUSTMENTLINES_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT   #OPADJUSTLINES.AdjustmentKey
            ,  #OPADJUSTLINES.Facility
            ,  #OPADJUSTLINES.StorerKey
            ,  #OPADJUSTLINES.SKU
            ,  #OPADJUSTLINES.PackKey
            ,  SUM(#OPADJUSTLINES.Qty) AS Qty
            ,  #OPADJUSTLINES.StrategyKey
            ,  #OPADJUSTLINES.MinShelf 
            ,  #OPADJUSTLINES.Lottable01 
            ,  #OPADJUSTLINES.Lottable02
            ,  #OPADJUSTLINES.Lottable03 
            ,  #OPADJUSTLINES.Lottable04 
            ,  #OPADJUSTLINES.Lottable05 
            ,  #OPADJUSTLINES.Lottable06 
            ,  #OPADJUSTLINES.Lottable07 
            ,  #OPADJUSTLINES.Lottable08 
            ,  #OPADJUSTLINES.Lottable09 
            ,  #OPADJUSTLINES.Lottable10 
            ,  #OPADJUSTLINES.Lottable11 
            ,  #OPADJUSTLINES.Lottable12 
            ,  #OPADJUSTLINES.Lottable13 
            ,  #OPADJUSTLINES.Lottable14 
            ,  #OPADJUSTLINES.Lottable15
            ,  '     '  
        FROM #OPADJUSTLINES 
        GROUP BY #OPADJUSTLINES.AdjustmentKey
            ,  #OPADJUSTLINES.Facility
            ,  #OPADJUSTLINES.StorerKey
            ,  #OPADJUSTLINES.SKU
            ,  #OPADJUSTLINES.PackKey
            ,  #OPADJUSTLINES.StrategyKey
            ,  #OPADJUSTLINES.MinShelf 
            ,  #OPADJUSTLINES.Lottable01 
            ,  #OPADJUSTLINES.Lottable02
            ,  #OPADJUSTLINES.Lottable03 
            ,  #OPADJUSTLINES.Lottable04 
            ,  #OPADJUSTLINES.Lottable05 
            ,  #OPADJUSTLINES.Lottable06 
            ,  #OPADJUSTLINES.Lottable07 
            ,  #OPADJUSTLINES.Lottable08 
            ,  #OPADJUSTLINES.Lottable09 
            ,  #OPADJUSTLINES.Lottable10 
            ,  #OPADJUSTLINES.Lottable11 
            ,  #OPADJUSTLINES.Lottable12 
            ,  #OPADJUSTLINES.Lottable13 
            ,  #OPADJUSTLINES.Lottable14 
            ,  #OPADJUSTLINES.Lottable15
         ORDER BY #OPADJUSTLINES.StorerKey, #OPADJUSTLINES.SKU
   END
     
   OPEN ADJUSTMENTLINES_CUR
   FETCH NEXT FROM ADJUSTMENTLINES_CUR INTO @c_aAdjustmentKey
                                         ,@c_aFacility
                                         ,@c_aStorerkey
                                         ,@c_aSku
                                         ,@c_aPackKey  
                                         ,@n_aQtyLeftToFulfill 
                                         ,@c_aStrategyKey
                                         ,@n_MinShelfLife
                                         ,@c_Lottable01
                                         ,@c_Lottable02
                                         ,@c_Lottable03
                                         ,@dt_Lottable04
                                         ,@dt_Lottable05  
                                         ,@c_Lottable06
                                         ,@c_Lottable07
                                         ,@c_Lottable08
                                         ,@c_Lottable09
                                         ,@c_Lottable10
                                         ,@c_Lottable11
                                         ,@c_Lottable12
                                         ,@dt_Lottable13
                                         ,@dt_Lottable14
                                         ,@dt_Lottable15
                                         ,@c_aAdjustmentLineNumber 

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      SET @c_aLot = ''
      SET @c_ALLineNo = ''
      SET @n_aUOMQty = 0
      
      IF @n_aQtyLeftToFulfill < 0
         SET @n_AdjPlusMinus = -1
      ELSE 
         SET @n_AdjPlusMinus = 1
      
      SET @n_aQtyLeftToFulfill = @n_aQtyLeftToFulfill * @n_AdjPlusMinus    
      
      IF @c_aStorerkey <> @c_PStorerkey 
      BEGIN
         SET @b_success = 0
         EXECUTE nspGetRight null            -- facility
               , @c_aStorerkey               -- StorerKey
               , null                        -- Sku
               , 'MinShelfLife60Mth'         -- Configkey
               , @b_success                  OUTPUT 
               , @c_MinShelfLife60Mth        OUTPUT 
               , @n_err                      OUTPUT 
               , @c_errmsg                   OUTPUT

         If @b_success = 0
         BEGIN
             SET @n_continue = 3
             SET @c_errmsg = 'isp_AdjustmentProcessing : ' + RTRIM(@c_errmsg) 
             GOTO EXIT_SP
         END
      
         SET @b_success = 0
         EXECUTE nspGetRight null            -- facility
               , @c_aStorerkey                -- StorerKey
               , null                        -- Sku
               , 'ShelfLifeInDays'           -- Configkey
               , @b_success                  OUTPUT 
               , @c_ShelfLifeInDays          OUTPUT 
               , @n_err                      OUTPUT 
               , @c_errmsg                   OUTPUT

         If @b_success = 0
         BEGIN
             SET @n_continue = 3
             SET @c_errmsg = 'isp_AdjustmentProcessing : ' + RTRIM(@c_errmsg) 
             GOTO EXIT_SP
         END
      END

      IF @n_MinShelfLife IS NULL OR @n_MinShelfLife = 0
      BEGIN     
         SET @n_MinShelfLife = 0   
      END 
      ELSE IF @c_MinShelfLife60Mth = '1' 
      BEGIN
         IF @n_MinShelfLife < 61    
            SET @n_MinShelfLife = @n_MinShelfLife * 30 
      END
      ELSE IF @c_ShelfLifeInDays = '1'            
      BEGIN
         SET @n_MinShelfLife = @n_MinShelfLife   
      END                                           
      ELSE IF @n_MinShelfLife < 13  
      BEGIN  
         SET @n_MinShelfLife = @n_MinShelfLife * 30    
      END 
 
      IF @n_MinShelfLife <> 0  
      BEGIN
         SET @c_aLot = '*' + CONVERT(NVARCHAR(5), @n_MinShelfLife)
      END

      LOOPPICKSTRATEGY:
      WHILE @n_aQtyLeftToFulfill > 0
      BEGIN
         GET_NEXT_STRATEGY:

         SELECT TOP 1
                @c_ALLineNo = AllocateStrategyLineNumber 
               ,@c_AllocatePickCode = Pickcode
               ,@c_aUOM     = UOM  
         FROM ALLOCATESTRATEGYDETAIL WITH (NOLOCK)
         WHERE AllocateStrategyLineNumber > @c_ALLineNo
         AND AllocateStrategyKey = @c_aStrategyKey
         ORDER BY AllocateStrategyLineNumber

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         SELECT @n_PalletQty = Pallet 
              , @n_CaseQty = CaseCnt 
              , @n_InnerPackQty = InnerPack 
              , @n_OtherUnit1 = CONVERT(INT,OtherUnit1) 
              , @n_OtherUnit2 = CONVERT(INT,OtherUnit2) 
         FROM PACK (NOLOCK)
         WHERE PackKey = @c_aPackKey

         SET @n_aUOMQty = CASE @c_aUOM WHEN '1' THEN @n_PalletQty
                                       WHEN '2' THEN @n_CaseQty
                                       WHEN '3' THEN @n_InnerPackQty
                                       WHEN '4' THEN @n_OtherUnit1
                                       WHEN '5' THEN @n_OtherUnit2
                                       WHEN '6' THEN 1
                                       WHEN '7' THEN 1
                                       ELSE 0
                                       END

         SET @n_PackQty = @n_aUOMQty

         IF @b_debug = 1 OR @b_debug = 2
         BEGIN
            PRINT ''
            PRINT '********** GET_NEXT_STRATEGY **********'
            PRINT '--> @c_aUOM: ' + @c_aUOM
            PRINT '--> @n_PackQty: ' + CAST(@n_PackQty AS VARCHAR(10))
            PRINT '--> @n_aQtyLeftToFulfill: ' +  CAST(@n_aQtyLeftToFulfill AS VARCHAR(10))
            PRINT '--> @n_AdjPlusMinus:' + CAST(@n_AdjPlusMinus AS NVARCHAR(10))
         END

         IF @n_PackQty > @n_aQtyLeftToFulfill AND @c_aUOM <> '1'
            GOTO GET_NEXT_STRATEGY

         DECLARECURSOR_CANDIDATES:

         IF @dt_Lottable04 IS NULL OR CONVERT(VARCHAR(20), @dt_Lottable04, 112) = '19000101'
            SELECT @c_Lottable04 = ''
         ELSE
            SELECT @c_Lottable04 = CONVERT(VARCHAR(20), @dt_Lottable04, 112)
         
         IF @dt_Lottable05 IS NULL OR CONVERT(VARCHAR(20), @dt_Lottable05, 112) = '19000101'
            SELECT @c_Lottable05 = ''
         ELSE
            SELECT @c_Lottable05 = CONVERT(VARCHAR(20), @dt_Lottable05, 112) 
         
         IF @dt_Lottable13 IS NULL OR CONVERT(VARCHAR(20), @dt_Lottable13, 112) = '19000101'
            SELECT @c_Lottable13 = '' 
         ELSE
            SELECT @c_Lottable13 = CONVERT(VARCHAR(20), @dt_Lottable13, 112)
         
         IF @dt_Lottable14 IS NULL OR CONVERT(VARCHAR(20), @dt_Lottable14, 112) = '19000101'
            SELECT @c_Lottable14 = ''
         ELSE
            SELECT @c_Lottable14 = CONVERT(VARCHAR(20), @dt_Lottable14, 112)
                    
         IF @dt_Lottable15 IS NULL OR CONVERT(VARCHAR(20), @dt_Lottable15, 112) = '19000101'
            SELECT @c_Lottable15 = ''
         ELSE
            SELECT @c_Lottable15 = CONVERT(VARCHAR(20), @dt_Lottable15, 112)

         SET @c_OtherParms = RTRIM(@c_AdjustmentKey) + @c_aAdjustmentLineNumber + 'A'  --key + line no + call source 
         SET @c_ExecuteSP = ''
         SET @c_Lottable_Parm = ''
         
         SELECT @c_Lottable_Parm = ISNULL(MAX(PARAMETER_NAME),'')
         FROM [INFORMATION_SCHEMA].[PARAMETERS]
         WHERE SPECIFIC_NAME = @c_AllocatePickCode
           AND PARAMETER_NAME Like '%Lottable%'

         IF ISNULL(RTRIM(@c_Lottable_Parm), '') <> '' 
         BEGIN  
            DECLARE CUR_PARM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PARAMETER_NAME, ORDINAL_POSITION
            FROM [INFORMATION_SCHEMA].[PARAMETERS] 
            WHERE SPECIFIC_NAME = @c_AllocatePickCode 
            ORDER BY ORDINAL_POSITION
            
            OPEN CUR_PARM
            FETCH NEXT FROM CUR_PARM INTO @c_ParmName, @n_OrdinalPosition
            
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF @n_OrdinalPosition = 1
                  SET @c_ExecuteSP = RTRIM(@c_ExecuteSP) + ' ' +RTRIM(@c_ParmName) + ' = N''' + @c_AdjustmentKey   + ''''  
               ELSE
               BEGIN 
                  SET @c_ExecuteSP = RTRIM(@c_ExecuteSP) + 
                  CASE @c_ParmName
                     WHEN '@c_Lot'        THEN ',@c_Lot        = N''' + RTRIM(@c_aLot) + ''''
                     WHEN '@c_Facility'   THEN ',@c_Facility   = N''' + RTRIM(@c_aFacility) + ''''
                     WHEN '@c_StorerKey'  THEN ',@c_StorerKey  = N''' + RTRIM(@c_aStorerKey) + ''''
                     WHEN '@c_SKU'        THEN ',@c_SKU        = N''' + RTRIM(@c_aSKU) + '''' 
                     WHEN '@c_Lottable01' THEN ',@c_Lottable01 = N''' + RTRIM(@c_Lottable01) + '''' 
                     WHEN '@c_Lottable02' THEN ',@c_Lottable02 = N''' + RTRIM(@c_Lottable02) + '''' 
                     WHEN '@c_Lottable03' THEN ',@c_Lottable03 = N''' + RTRIM(@c_Lottable03) + '''' 
                     WHEN '@d_Lottable04' THEN ',@d_Lottable04 = N''' + @c_Lottable04 + ''''  
                     WHEN '@c_Lottable04' THEN ',@c_Lottable04 = N''' + @c_Lottable04 + ''''  
                     WHEN '@d_Lottable05' THEN ',@d_Lottable05 = N''' + @c_Lottable05 + ''''  
                     WHEN '@c_Lottable05' THEN ',@c_Lottable05 = N''' + @c_Lottable05 + ''''  
                     WHEN '@c_Lottable06' THEN ',@c_Lottable06 = N''' + RTRIM(@c_Lottable06) + '''' 
                     WHEN '@c_Lottable07' THEN ',@c_Lottable07 = N''' + RTRIM(@c_Lottable07) + '''' 
                     WHEN '@c_Lottable08' THEN ',@c_Lottable08 = N''' + RTRIM(@c_Lottable08) + '''' 
                     WHEN '@c_Lottable09' THEN ',@c_Lottable09 = N''' + RTRIM(@c_Lottable09) + ''''  
                     WHEN '@c_Lottable10' THEN ',@c_Lottable10 = N''' + RTRIM(@c_Lottable10) + ''''  
                     WHEN '@c_Lottable11' THEN ',@c_Lottable11 = N''' + RTRIM(@c_Lottable11) + '''' 
                     WHEN '@c_Lottable12' THEN ',@c_Lottable12 = N''' + RTRIM(@c_Lottable12) + '''' 
                     WHEN '@d_Lottable13' THEN ',@d_Lottable13 = N''' + @c_Lottable13 + ''''    
                     WHEN '@d_Lottable14' THEN ',@d_Lottable14 = N''' + @c_Lottable14 + ''''    
                     WHEN '@d_Lottable15' THEN ',@d_Lottable15 = N''' + @c_Lottable15 + ''''   
                     WHEN '@c_UOM'        THEN ',@c_UOM = N''' + RTRIM(@c_aUOM) + '''' 
                     WHEN '@c_HostWHCode' THEN ',@c_HostWHCode = N''' + RTRIM(@c_HostWHCode) + '''' 
                     WHEN '@n_UOMBase'    THEN ',@n_UOMBase= ' + CONVERT(NVARCHAR(10),@n_PackQty) 
                     WHEN '@n_QtyLeftToFulfill' THEN ',@n_QtyLeftToFulfill=' + CONVERT(NVARCHAR(10), @n_aQtyLeftToFulfill) 
                     WHEN '@c_OtherParms' THEN ',@c_OtherParms=''' + @c_OtherParms + ''''     
                  END
               END 
            
               FETCH NEXT FROM CUR_PARM INTO @c_ParmName, @n_OrdinalPosition
            END 
            CLOSE CUR_PARM
            DEALLOCATE CUR_PARM   
         END

         IF RTRIM(@c_ExecuteSP) = ''
         BEGIN
            IF @b_debug = 1 OR @b_debug = 2
            BEGIN
               PRINT '@c_AllocatePickCode:' + RTRIM(@c_AllocatePickCode) + ' Invalid pick code'
            END
         	
            GOTO EXIT_SP
         END

         SET @c_ExecuteSP = @c_AllocatePickCode + ' ' + @c_ExecuteSP
         
         IF @b_debug = 1 OR @b_debug = 2
            PRINT @c_ExecuteSP
 
         EXEC (@c_ExecuteSP)

         SET @n_err = @@ERROR
         SET @n_cnt = @@ROWCOUNT

         IF @n_err = 16915
         BEGIN
            CLOSE CURSOR_CANDIDATES
            DEALLOCATE CURSOR_CANDIDATES
            GOTO DECLARECURSOR_CANDIDATES
         END

         OPEN CURSOR_CANDIDATES
         SET @n_err = @@ERROR
         SET @n_cnt = @@ROWCOUNT

         IF @n_err = 16905
         BEGIN
            CLOSE CURSOR_CANDIDATES
            DEALLOCATE CURSOR_CANDIDATES
            GOTO DECLARECURSOR_CANDIDATES
         END

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63530   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (nspTransferProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
            GOTO EXIT_SP
         END
         ELSE
         BEGIN
            SET @n_CursorCandidates_Open = 1
         END

         IF @n_CursorCandidates_Open = 1 
         BEGIN
            WHILE @n_aQtyLeftToFulfill > 0
            BEGIN
               FETCH NEXT FROM CURSOR_CANDIDATES INTO @c_LOT
                                                   ,  @c_loc
                                                   ,  @c_id
                                                   ,  @n_QtyAvailable
                                                   ,  @c_LocType

               IF @@FETCH_STATUS = -1
               BEGIN
                  BREAK
               END

               IF @@FETCH_STATUS = 0
               BEGIN
                  IF @c_LocType = 'FULLPALLET' AND @c_aUOM = '1' 
                  BEGIN                           
                     --SELECT @n_UOMQty = 1
                  	 
                     IF @n_QtyAvailable >= @n_aQtyLeftToFulfill
                     BEGIN
                        SELECT @n_QtyToTake = @n_aQtyLeftToFulfill
                     END
                     ELSE
                     BEGIN
                        SELECT @n_QtyToTake = @n_QtyAvailable 
                     END

                     IF @b_debug = 1 OR @b_debug = 2
                     BEGIN
                        PRINT 'FULLPALLET WITH UOM 1'                               
                     END
                  END
                  ELSE
               	  BEGIN
                     IF @n_PackQty > 0
                     BEGIN
                        SET @n_Available = FLOOR(@n_QtyAvailable / @n_PackQty) * @n_PackQty
                     END
                     ELSE
                     BEGIN
                        SET @n_Available = 0
                     END
                     
                     IF @n_Available >= @n_aQtyLeftToFulfill
                     BEGIN
                        SET @n_QtyToTake = @n_aQtyLeftToFulfill
                     END
                     ELSE
                     BEGIN
                        SET @n_QtyToTake = @n_Available
                     END
                     
                     IF @n_PackQty > 0
                     BEGIN
                        SET @n_QtyToTake = FLOOR(@n_QtyToTake / @n_PackQty) * @n_PackQty 
                     END
                  END

                  IF @b_debug = 1 or @b_debug = 2
                  BEGIN
                  	 PRINT 'Lot:' + RTRIM(@c_Lot) + ' Loc:' + RTRIM(@c_Loc) + ' ID:' + RTRIM(@c_ID)
                     PRINT 'Available:' + CAST(@n_Available AS NVARCHAR(10))
                     PRINT 'Qty To Take: ' + CAST(@n_QtyToTake AS NVARCHAR(10))
                  END

                  IF @n_QtyToTake > 0
                  BEGIN
                     GOTO UPDATEINV
                     RETURNFROMUPDATEINV:
                     SET @n_aQtyLeftToFulfill = @n_aQtyLeftToFulfill - @n_QtyToTake
                  END--@n_QtyToTake > 0
               END --@@FETCH_STATUS = 0
            END -- WHILE @n_aQtyLeftToFulfill > 0
         END 
        
         IF CURSOR_STATUS('GLOBAL', 'CURSOR_CANDIDATES') IN (0 , 1)
         BEGIN
            CLOSE CURSOR_CANDIDATES
            DEALLOCATE CURSOR_CANDIDATES
         END
      END -- END WHILE LOOPPICKSTRATEGY
      
      SET @c_PStorerkey = @c_aStorerkey

      FETCH NEXT FROM ADJUSTMENTLINES_CUR INTO @c_aAdjustmentKey
                                            ,@c_aFacility
                                            ,@c_aStorerkey
                                            ,@c_aSku
                                            ,@c_aPackKey  
                                            ,@n_aQtyLeftToFulfill 
                                            ,@c_aStrategyKey
                                            ,@n_MinShelfLife
                                            ,@c_Lottable01
                                            ,@c_Lottable02
                                            ,@c_Lottable03
                                            ,@dt_Lottable04
                                            ,@dt_Lottable05  
                                            ,@c_Lottable06
                                            ,@c_Lottable07
                                            ,@c_Lottable08
                                            ,@c_Lottable09
                                            ,@c_Lottable10
                                            ,@c_Lottable11
                                            ,@c_Lottable12
                                            ,@dt_Lottable13
                                            ,@dt_Lottable14
                                            ,@dt_Lottable15
                                            ,@c_aAdjustmentLineNumber 
   END
   CLOSE ADJUSTMENTLINES_CUR
   DEALLOCATE ADJUSTMENTLINES_CUR

   EXIT_SP:

   IF CURSOR_STATUS('GLOBAL', 'ADJUSTMENTLINES_CUR') IN (0 , 1)
   BEGIN
      CLOSE TRANSFERLINES_CUR
      DEALLOCATE TRANSFERLINES_CUR
   END

   IF CURSOR_STATUS('GLOBAL', 'CURSOR_CANDIDATES') IN (0 , 1)
   BEGIN
      CLOSE CURSOR_CANDIDATES
      DEALLOCATE CURSOR_CANDIDATES
   END

   IF @n_continue IN(1,2)
   BEGIN
   	  SELECT @n_OpenLineCnt = 0, @n_AllocatedLineCnt = 0
   	  SELECT @n_OpenLineCnt = SUM(CASE WHEN ISNULL(ADJUSTMENTDETAIL.Lot,'') = '' THEN 1 ELSE 0 END),
   	         @n_AllocatedLineCnt = SUM(CASE WHEN ISNULL(ADJUSTMENTDETAIL.Lot,'') <> '' THEN 1 ELSE 0 END) 
      FROM  ADJUSTMENT (NOLOCK)
      JOIN  ADJUSTMENTDETAIL (NOLOCK) ON ADJUSTMENT.Adjustmentkey = ADJUSTMENTDETAIL.Adjustmentkey
      JOIN  SKU (NOLOCK) ON ADJUSTMENTDETAIL.Storerkey = SKU.StorerKey AND ADJUSTMENTDETAIL.Sku = SKU.Sku
      WHERE ADJUSTMENT.Adjustmentkey = @c_Adjustmentkey
      AND ADJUSTMENTDETAIL.Qty <> 0
      
      IF @n_OpenLineCnt > 0 AND @n_AllocatedLineCnt > 0
         SET @c_ErrMsg = 'Partially Allocated'
      ELSE IF @n_OpenLineCnt = 0 AND @n_AllocatedLineCnt > 0
         SET @c_ErrMsg = 'Fully Allocated'                  	
      ELSE 
         SET @c_ErrMsg = 'Not Allocated'
   END
   
   /* #INCLUDE <SPPREOP2.SQL> */
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'nspTransferProcessing'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END

   UPDATEINV:
            
   SET @n_BalQty = @n_QtyToTake
   
   DECLARE CUR_ADJUSTMENTDET_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT AD.AdjustmentLineNumber, 
             AD.Qty
      FROM ADJUSTMENT A (NOLOCK)
      JOIN ADJUSTMENTDETAIL AD (NOLOCK) ON A.Adjustmentkey = AD.Adjustmentkey
      WHERE A.Adjustmentkey = @c_Adjustmentkey
      AND ISNULL(AD.Lot,'') = ''
      AND AD.Storerkey = @c_aStorerkey
      AND AD.Sku = @c_aSku
      AND AD.Lottable01 = @c_Lottable01
      AND AD.Lottable02 = @c_Lottable02
      AND AD.Lottable03 = @c_Lottable03
      AND ISNULL(AD.Lottable04, '19000101') = @dt_Lottable04
      AND ISNULL(AD.Lottable05, '19000101')  = @dt_Lottable05
      AND AD.Lottable06 = @c_Lottable06
      AND AD.Lottable07 = @c_Lottable07
      AND AD.Lottable08 = @c_Lottable08
      AND AD.Lottable09 = @c_Lottable09
      AND AD.Lottable10 = @c_Lottable10
      AND AD.Lottable11 = @c_Lottable11
      AND AD.Lottable12 = @c_Lottable12
      AND ISNULL(AD.Lottable13, '19000101') = @dt_Lottable13
      AND ISNULL(AD.Lottable14, '19000101') = @dt_Lottable14
      AND ISNULL(AD.Lottable15, '19000101') = @dt_Lottable15
      AND AD.FinalizedFlag = 'N'
      AND AD.AdjustmentLineNumber = CASE WHEN ISNULL(@c_aAdjustmentLineNumber,'') <> '' THEN @c_aAdjustmentLineNumber ELSE AD.AdjustmentLineNumber END
   
   OPEN CUR_ADJUSTMENTDET_UPDATE  
   
   FETCH NEXT FROM CUR_ADJUSTMENTDET_UPDATE INTO @c_AdjustmentLineNumber, @n_Qty
   
   WHILE @@FETCH_STATUS <> -1 AND @n_BalQty > 0 
   BEGIN            
   	  IF @n_AdjPlusMinus = 1  
   	  BEGIN --Positive adjustment. update all the lines with same lot,loc,id from the first lot found
         UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK)
         SET Id = @c_ID,
             Loc = @c_Loc,
             Lot = @c_Lot,
             --Qty = @n_Qty,
             Userdefine10 = @c_aUOM,     	     
             TrafficCop = NULL
         WHERE Adjustmentkey = @c_Adjustmentkey
         AND AdjustmentLineNumber = @c_AdjustmentLineNumber
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63540   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update ADJUSTMENTDETAIL Failed! (isp_AdjustmentProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		     END
		     
		     SET @n_aQtyLeftToFulfill = 0 	  	
   	  END
   	  ELSE
   	  BEGIN  --Negative adjustment   	  	
   	     SET @n_Qty = @n_Qty * @n_AdjPlusMinus
   	        	                                	             
         IF @n_Qty <= @n_BalQty
         BEGIN
            IF @b_debug = 1 or @b_debug = 2
            BEGIN
            	 PRINT 'Update Adjustment Line:' + RTRIM(@c_AdjustmentLineNumber) + ' Qty:' + CAST(@n_Qty AS NVARCHAR(10))
               PRINT 'BalQty:' + CAST(@n_BalQty AS NVARCHAR(10))
            END
         
         	  UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK)
         	  SET Id = @c_ID,
         	      Loc = @c_Loc,
         	      Lot = @c_Lot,
         	      --Qty = @n_Qty,
         	      Userdefine10 = @c_aUOM,     	     
         	      TrafficCop = NULL
         	  WHERE Adjustmentkey = @c_Adjustmentkey
         	  AND AdjustmentLineNumber = @c_AdjustmentLineNumber
         	 
         	  SELECT @n_err = @@ERROR
         	  IF @n_err <> 0
         	  BEGIN
               SET @n_continue = 3
               SET @n_err = 63550   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update ADJUSTMENTDETAIL Failed! (isp_AdjustmentProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		      	END
		      	 
		      	SELECT @n_BalQty = @n_BalQty - @n_Qty
         END
         ELSE
         BEGIN  -- pickqty > packqty
         	  SELECT @n_SplitQty = (@n_Qty - @n_BalQty) * @n_AdjPlusMinus
         
            SELECT @c_NewAdjustmentLineNumber = RIGHT('00000' + CONVERT(VARCHAR(5), MAX(CONVERT(INT, AdjustmentLineNumber)) + 1),5)
            FROM ADJUSTMENTDETAIL WITH (NOLOCK)
            WHERE Adjustmentkey = @c_Adjustmentkey
         
            IF @b_debug = 1 or @b_debug = 2
            BEGIN
            	 PRINT 'Split Adjustment Line:' + RTRIM(@c_AdjustmentLineNumber) + ' Qty:' + CAST(@n_Qty AS NVARCHAR(10)) + ' New Adjustment Line:' + RTRIM(@c_NewAdjustmentLineNumber)
               PRINT 'BalQty:' + CAST(@n_BalQty AS NVARCHAR(10)) + ' SplitQty:' + CAST(@n_SplitQty AS NVARCHAR(10))
            END
         
            INSERT INTO ADJUSTMENTDETAIL
            (
            	AdjustmentKey,
            	AdjustmentLineNumber,
            	StorerKey,
              Sku,
            	Loc,
            	Lot,
            	ID,
            	ReasonCode,
            	UOM,
            	Packkey,
            	Qty,
            	LOTTABLE01,
            	LOTTABLE02,
            	LOTTABLE03,
            	LOTTABLE04,
            	LOTTABLE05,
            	Lottable06,
            	Lottable07,
            	Lottable08,
            	Lottable09,
            	Lottable10,
            	Lottable11,
            	Lottable12,
            	Lottable13,
            	Lottable14,
            	Lottable15,
            	UserDefine01,
            	UserDefine02,
            	UserDefine03,
            	UserDefine04,
            	UserDefine05,
            	UserDefine06,
            	UserDefine07,
            	UserDefine08,
            	UserDefine09,
            	UserDefine10,
            	FinalizedFlag,
            	UCCNo,
            	Channel,
            	Channel_ID         	
            )
            SELECT	Adjustmentkey,
            	      @c_NewAdjustmentLineNumber,
            	      StorerKey,
            	      Sku,
            	      Loc,
            	      Lot,
            	      Id,
            	      ReasonCode,
            	      UOM,
            	      PackKey,
            	      @n_SplitQty,
            	      LOTTABLE01,
            	      LOTTABLE02,
            	      LOTTABLE03,
            	      LOTTABLE04,
            	      LOTTABLE05,
            	      Lottable06,
            	      Lottable07,
            	      Lottable08,
            	      Lottable09,
            	      Lottable10,
            	      Lottable11,
            	      Lottable12,
            	      Lottable13,
            	      Lottable14,
            	      Lottable15,
            	      UserDefine01,
            	      UserDefine02,
            	      UserDefine03,
            	      UserDefine04,
            	      UserDefine05,
            	      UserDefine06,
            	      UserDefine07,
            	      UserDefine08,
            	      UserDefine09,
            	      UserDefine10,
            	      FinalizedFlag,
            	      UCCNo,
            	      Channel,
            	      Channel_ID
            FROM ADJUSTMENTDETAIL(NOLOCK)
            WHERE Adjustmentkey = @c_Adjustmentkey
            AND AdjustmentLineNumber = @c_AdjustmentLineNumber    	 
         
         	  SELECT @n_err = @@ERROR
         	  IF @n_err <> 0
         	  BEGIN
                SET @n_continue = 3
                SET @n_err = 63560   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Insert ADJUSTMENTDETAIL Failed! (isp_AdjustmentProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		        END      	 
		      	  		 		   	 
         	  UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK)
         	  SET Qty = (@n_BalQty * @n_AdjPlusMinus),
         	      Id = @c_ID,
         	      Loc = @c_Loc,
         	      Lot = @c_Lot,
         	      Userdefine10 = @c_aUOM,      	     
         	      TrafficCop = NULL
         	  WHERE Adjustmentkey = @c_Adjustmentkey
         	  AND AdjustmentLineNumber = @c_AdjustmentLineNumber
         	  
         	  SELECT @n_err = @@ERROR
         	  IF @n_err <> 0
         	  BEGIN
                SET @n_continue = 3
                SET @n_err = 63570   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update ADJUSTMENTDETAIL Failed! (isp_AdjustmentProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		        END
              
            SELECT @n_BalQty = 0
         END
      END
      
      /*
      UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK)
      SET ADJUSTMENTDETAIL.Lottable01 = LA.Lottable01,
          ADJUSTMENTDETAIL.Lottable02 = LA.Lottable02,
          ADJUSTMENTDETAIL.Lottable03 = LA.Lottable03,
          ADJUSTMENTDETAIL.Lottable04 = LA.Lottable04,
          ADJUSTMENTDETAIL.Lottable05 = LA.Lottable05,
          ADJUSTMENTDETAIL.Lottable06 = LA.Lottable06,
          ADJUSTMENTDETAIL.Lottable07 = LA.Lottable07,
          ADJUSTMENTDETAIL.Lottable08 = LA.Lottable08,
          ADJUSTMENTDETAIL.Lottable09 = LA.Lottable09,
          ADJUSTMENTDETAIL.Lottable10 = LA.Lottable10,
          ADJUSTMENTDETAIL.Lottable11 = LA.Lottable11,
          ADJUSTMENTDETAIL.Lottable12 = LA.Lottable12,
          ADJUSTMENTDETAIL.Lottable13 = LA.Lottable13,
          ADJUSTMENTDETAIL.Lottable14 = LA.Lottable14,
          ADJUSTMENTDETAIL.Lottable15 = LA.Lottable15,
          ADJUSTMENTDETAIL.TrafficCop = NULL          
      FROM ADJUSTMENTDETAIL 
      JOIN LOTATTRIBUTE LA (NOLOCK) ON ADJUSTMENTDETAIL.Lot = LA.Lot
      WHERE ADJUSTMENTDETAIL.Adjustmentkey = @c_Adjustmentkey
      AND ADJUSTMENTDETAIL.AdjustmentLineNumber = @c_AdjustmentLineNumber

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63560   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update ADJUSTMENTDETAIL Failed! (isp_AdjustmentProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		  END      	 
		  */
      
      FETCH NEXT FROM CUR_ADJUSTMENTDET_UPDATE INTO @c_AdjustmentLineNumber, @n_Qty            
   END
   CLOSE CUR_ADJUSTMENTDET_UPDATE  
   DEALLOCATE CUR_ADJUSTMENTDET_UPDATE                

   IF @b_debug = 1 or @b_debug = 2
   BEGIN
   	  IF @n_BalQty > 0
         PRINT 'Unable Fully Allocate! BalQty:' + CAST(@n_BalQty AS NVARCHAR(10))
   END
  
   SET @n_QtyToTake = @n_QtyToTake - @n_BalQty

   GOTO RETURNFROMUPDATEINV 
END

GO