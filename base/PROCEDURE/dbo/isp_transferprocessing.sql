SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_TransferProcessing                                  */
/* Creation Date: 16-MAR-2016                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 365626-Transfer allocation by lottable with empty from lot. */
/*          Use skip preallcation pickcode structure.                   */
/*          pre-allocation filter include transfer detail               */
/*                                                                      */
/* Called By: Transfer allocate RCM                                     */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */ 
/* 01-Jun-2016  NJOW01  1.0   Fix - double update tranfer.openqty       */
/* 21-Aug-2017  Wan     1.1   WMS-HK CPI - Lululemon - Transfer Allocation*/
/* 23-Apr-2018  NJOW02  1.2   WMS-9567 None conso allocation            */
/* 08-Aug-2021  NJOW03  1.3   WMS-17314 add #ALLOCATE_CANDIDATES        */
/************************************************************************/
CREATE PROC  [dbo].[isp_TransferProcessing]  
               @c_TransferKey   NVARCHAR(10)
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
         , @c_aTransferKey             NVARCHAR(10)
         , @c_aTransferLineNumber      NVARCHAR(5) --NJOW02
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

   DECLARE @n_Caseqty                  INT
         , @n_Palletqty                INT
         , @n_Innerpackqty             INT
         , @n_Otherunit1               INT 
         , @n_Otherunit2               INT
         , @n_PackQty                  INT

   DECLARE @n_SeqNo                    INT
         , @n_CursorCandidates_Open    INT
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
         , @c_TransferAllocateNoConso  NVARCHAR(10) --NJOW02

   DECLARE @c_NewTransferLineNumber NVARCHAR(5)
         , @c_TransferLineNumber NVARCHAR(5)
         , @n_BalQty INT
         , @n_FromQty INT
         , @n_SplitQty INT
         , @n_AllocatedLineCnt INT
         , @n_OpenLineCnt INT

   --NJOW03
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

   --(Wan01) - START
   EXEC isp_PreTransferAllocation_Wrapper 
         @c_TransferKey   = @c_TransferKey 
       , @b_Success       = @b_Success OUTPUT 
       , @n_Err           = @n_Err     OUTPUT 
       , @c_ErrMsg        = @c_ErrMsg  OUTPUT 

   IF @b_Success <> 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63501   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+ ': Error Executing isp_PreTrasnferAllocation_Wrapper.(nspTransferProcessing)'
      GOTO EXIT_SP
   END
   
   --(Wan01) - END
        
   SELECT @c_MinShelfLife60Mth = '', @c_ShelfLifeInDays = '', @n_CursorCandidates_Open = 0, @c_PStorerkey = '', @c_HostWHCode  = ''
   
   --NJOW02 Start
   SELECT @c_aStorerkey = FromStorerkey,
          @c_aFacility = Facility
   FROM TRANSFER (NOLOCK)
   WHERE Transferkey = @c_Transferkey
         
   SELECT @c_TransferAllocateNoConso = dbo.fnc_GetRight(@c_aFacility, @c_aStorerkey, '', 'TransferAllocateNoConso') 
   --NJOW02 End

   --Store original qty to userdefine09 if not empty
   UPDATE TRANSFERDETAIL WITH (ROWLOCK)
   SET Userdefine09 = CAST(FromQty AS NVARCHAR),
       TrafficCop = NULL
   WHERE Transferkey = @c_Transferkey
   AND ISNULL(FromLot,'') = ''
   AND ISNULL(Userdefine09,'') = ''
      
   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63500   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Transferdetail Failed! (nspTransferProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
      GOTO EXIT_SP
   END
		   	 
   CREATE TABLE #OPTRANSFERLINES 
         (  [SeqNo]                    [INT] IDENTITY(1, 1)
         ,  [Facility]                 [NVARCHAR](5)  NOT NULL
         ,  [TransferKey]              [NVARCHAR](10) NOT NULL
         ,  [TransferLineNumber]       [NVARCHAR](5)  NOT NULL
         ,  [FromStorerkey]            [NVARCHAR](15) NOT NULL
         ,  [FromSku]                  [NVARCHAR](20) NOT NULL
         ,  [FromQty]                  [INT]          NOT NULL
         ,  [FromPackkey]              [NVARCHAR](10) NOT NULL
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

   INSERT INTO #OPTRANSFERLINES
         (  [Facility]                  
         ,  [TransferKey]                    
         ,  [TransferLineNumber]                   
         ,  [FromStorerkey]                 
         ,  [FromSku] 
         ,  [FromQty]                       
         ,  [FromPackkey]                   
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
   SELECT   Facility = ISNULL(RTRIM(TRANSFER.Facility),'')
         ,  TransferKey = ISNULL(RTRIM(TRANSFER.Transferkey),'')
         ,  TransferLineNumber = ISNULL(RTRIM(TRANSFERDETAIL.TransferLineNumber),'')
         ,  FromStorerkey= ISNULL(RTRIM(TRANSFERDETAIL.FromStorerkey),'')
         ,  FromSku      = ISNULL(RTRIM(TRANSFERDETAIL.FromSku),'')
         ,  FromQty      = ISNULL(TRANSFERDETAIL.FromQty,0)
         ,  FromPackkey  = ISNULL(RTRIM(TRANSFERDETAIL.FromPackkey),'')
         ,  StrategyKey = ISNULL(RTRIM(STGY.TransferStrategyKey),'') 
         ,  MinShelf    = 0
         ,  Lottable01  = ISNULL(RTRIM(TRANSFERDETAIL.Lottable01),'')
         ,  Lottable02  = ISNULL(RTRIM(TRANSFERDETAIL.Lottable02),'')
         ,  Lottable03  = ISNULL(RTRIM(TRANSFERDETAIL.Lottable03),'')
         ,  Lottable04  = ISNULL(TRANSFERDETAIL.Lottable04, '19000101')
         ,  Lottable05  = ISNULL(TRANSFERDETAIL.Lottable05, '19000101')
         ,  Lottable06  = ISNULL(RTRIM(TRANSFERDETAIL.Lottable06),'')
         ,  Lottable07  = ISNULL(RTRIM(TRANSFERDETAIL.Lottable07),'')
         ,  Lottable08  = ISNULL(RTRIM(TRANSFERDETAIL.Lottable08),'')
         ,  Lottable09  = ISNULL(RTRIM(TRANSFERDETAIL.Lottable09),'')
         ,  Lottable10  = ISNULL(RTRIM(TRANSFERDETAIL.Lottable10),'')
         ,  Lottable11  = ISNULL(RTRIM(TRANSFERDETAIL.Lottable11),'')
         ,  Lottable12  = ISNULL(RTRIM(TRANSFERDETAIL.Lottable12),'')
         ,  Lottable13  = ISNULL(TRANSFERDETAIL.Lottable13, '19000101')
         ,  Lottable14  = ISNULL(TRANSFERDETAIL.Lottable14, '19000101')
         ,  Lottable15  = ISNULL(TRANSFERDETAIL.Lottable15, '19000101')
      FROM  TRANSFER (NOLOCK)
      JOIN  TRANSFERDETAIL (NOLOCK) ON TRANSFER.Transferkey = TRANSFERDETAIL.Transferkey
      JOIN  SKU (NOLOCK) ON TRANSFERDETAIL.FromStorerkey = SKU.StorerKey AND TRANSFERDETAIL.FromSku = SKU.Sku
      JOIN  STRATEGY STGY (NOLOCK) ON SKU.Strategykey = STGY.StrategyKey
      WHERE TRANSFER.Transferkey = @c_Transferkey
      AND ISNULL(TRANSFERDETAIL.FromLot,'') = ''
      ORDER BY TRANSFERDETAIL.FromSKU
      
      SET @n_cnt = @@ROWCOUNT      
      
      IF @b_debug = 1 or @b_debug = 2
         SELECT * FROM #OPTRANSFERLINES
      
      IF @n_cnt = 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63510   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': No Available Trasnfer Line To Allocate.(Empty FromLot) (nspTransferProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
         GOTO EXIT_SP
      END      

   IF @c_TransferAllocateNoConso = 'Y'  --NJOW02
   BEGIN
      DECLARE TRANSFERLINES_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT   #OPTRANSFERLINES.TransferKey
            ,  #OPTRANSFERLINES.Facility
            ,  #OPTRANSFERLINES.FromStorerKey
            ,  #OPTRANSFERLINES.FromSKU
            ,  #OPTRANSFERLINES.FromPackKey
            ,  SUM(#OPTRANSFERLINES.FromQty) AS FromQty
            ,  #OPTRANSFERLINES.StrategyKey
            ,  #OPTRANSFERLINES.MinShelf 
            ,  #OPTRANSFERLINES.Lottable01 
            ,  #OPTRANSFERLINES.Lottable02
            ,  #OPTRANSFERLINES.Lottable03 
            ,  #OPTRANSFERLINES.Lottable04 
            ,  #OPTRANSFERLINES.Lottable05 
            ,  #OPTRANSFERLINES.Lottable06 
            ,  #OPTRANSFERLINES.Lottable07 
            ,  #OPTRANSFERLINES.Lottable08 
            ,  #OPTRANSFERLINES.Lottable09 
            ,  #OPTRANSFERLINES.Lottable10 
            ,  #OPTRANSFERLINES.Lottable11 
            ,  #OPTRANSFERLINES.Lottable12 
            ,  #OPTRANSFERLINES.Lottable13 
            ,  #OPTRANSFERLINES.Lottable14 
            ,  #OPTRANSFERLINES.Lottable15
            ,  #OPTRANSFERLINES.TransferLineNumber
        FROM #OPTRANSFERLINES 
        GROUP BY #OPTRANSFERLINES.TransferKey
            ,  #OPTRANSFERLINES.Facility
            ,  #OPTRANSFERLINES.FromStorerKey
            ,  #OPTRANSFERLINES.FromSKU
            ,  #OPTRANSFERLINES.FromPackKey
            ,  #OPTRANSFERLINES.StrategyKey
            ,  #OPTRANSFERLINES.MinShelf 
            ,  #OPTRANSFERLINES.Lottable01 
            ,  #OPTRANSFERLINES.Lottable02
            ,  #OPTRANSFERLINES.Lottable03 
            ,  #OPTRANSFERLINES.Lottable04 
            ,  #OPTRANSFERLINES.Lottable05 
            ,  #OPTRANSFERLINES.Lottable06 
            ,  #OPTRANSFERLINES.Lottable07 
            ,  #OPTRANSFERLINES.Lottable08 
            ,  #OPTRANSFERLINES.Lottable09 
            ,  #OPTRANSFERLINES.Lottable10 
            ,  #OPTRANSFERLINES.Lottable11 
            ,  #OPTRANSFERLINES.Lottable12 
            ,  #OPTRANSFERLINES.Lottable13 
            ,  #OPTRANSFERLINES.Lottable14 
            ,  #OPTRANSFERLINES.Lottable15
            ,  #OPTRANSFERLINES.TransferLineNumber
         ORDER BY #OPTRANSFERLINES.FromStorerKey, #OPTRANSFERLINES.FromSKU
   END   
   ELSE
   BEGIN
      DECLARE TRANSFERLINES_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT   #OPTRANSFERLINES.TransferKey
            ,  #OPTRANSFERLINES.Facility
            ,  #OPTRANSFERLINES.FromStorerKey
            ,  #OPTRANSFERLINES.FromSKU
            ,  #OPTRANSFERLINES.FromPackKey
            ,  SUM(#OPTRANSFERLINES.FromQty) AS FromQty
            ,  #OPTRANSFERLINES.StrategyKey
            ,  #OPTRANSFERLINES.MinShelf 
            ,  #OPTRANSFERLINES.Lottable01 
            ,  #OPTRANSFERLINES.Lottable02
            ,  #OPTRANSFERLINES.Lottable03 
            ,  #OPTRANSFERLINES.Lottable04 
            ,  #OPTRANSFERLINES.Lottable05 
            ,  #OPTRANSFERLINES.Lottable06 
            ,  #OPTRANSFERLINES.Lottable07 
            ,  #OPTRANSFERLINES.Lottable08 
            ,  #OPTRANSFERLINES.Lottable09 
            ,  #OPTRANSFERLINES.Lottable10 
            ,  #OPTRANSFERLINES.Lottable11 
            ,  #OPTRANSFERLINES.Lottable12 
            ,  #OPTRANSFERLINES.Lottable13 
            ,  #OPTRANSFERLINES.Lottable14 
            ,  #OPTRANSFERLINES.Lottable15
            ,  '     '  --NJOW02
        FROM #OPTRANSFERLINES 
        GROUP BY #OPTRANSFERLINES.TransferKey
            ,  #OPTRANSFERLINES.Facility
            ,  #OPTRANSFERLINES.FromStorerKey
            ,  #OPTRANSFERLINES.FromSKU
            ,  #OPTRANSFERLINES.FromPackKey
            ,  #OPTRANSFERLINES.StrategyKey
            ,  #OPTRANSFERLINES.MinShelf 
            ,  #OPTRANSFERLINES.Lottable01 
            ,  #OPTRANSFERLINES.Lottable02
            ,  #OPTRANSFERLINES.Lottable03 
            ,  #OPTRANSFERLINES.Lottable04 
            ,  #OPTRANSFERLINES.Lottable05 
            ,  #OPTRANSFERLINES.Lottable06 
            ,  #OPTRANSFERLINES.Lottable07 
            ,  #OPTRANSFERLINES.Lottable08 
            ,  #OPTRANSFERLINES.Lottable09 
            ,  #OPTRANSFERLINES.Lottable10 
            ,  #OPTRANSFERLINES.Lottable11 
            ,  #OPTRANSFERLINES.Lottable12 
            ,  #OPTRANSFERLINES.Lottable13 
            ,  #OPTRANSFERLINES.Lottable14 
            ,  #OPTRANSFERLINES.Lottable15
         ORDER BY #OPTRANSFERLINES.FromStorerKey, #OPTRANSFERLINES.FromSKU
   END
     
   OPEN TRANSFERLINES_CUR
   FETCH NEXT FROM TRANSFERLINES_CUR INTO @c_aTransferKey
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
                                         ,@c_aTransferLineNumber --NJOW02

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      SET @c_aLot = ''
      SET @c_ALLineNo = ''
      SET @n_aUOMQty = 0
      
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
             SET @c_errmsg = 'isp_TransferProcessing : ' + RTRIM(@c_errmsg) 
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
             SET @c_errmsg = 'isp_TransferProcessing : ' + RTRIM(@c_errmsg) 
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
               ,@c_AUOM     = UOM  
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

         SET @c_OtherParms = RTRIM(@c_TransferKey) + @c_aTransferLineNumber + 'T'  --key + line no + call source --NJOW02
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
                  SET @c_ExecuteSP = RTRIM(@c_ExecuteSP) + ' ' +RTRIM(@c_ParmName) + ' = N''' + @c_TransferKey   + ''''  
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
            SET @n_err = 63520   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
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

      FETCH NEXT FROM TRANSFERLINES_CUR INTO @c_aTransferKey
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
                                            ,@c_aTransferLineNumber --NJOW02                                           
   END
   CLOSE TRANSFERLINES_CUR
   DEALLOCATE TRANSFERLINES_CUR

   EXIT_SP:

   IF CURSOR_STATUS('GLOBAL', 'TRANSFERLINES_CUR') IN (0 , 1)
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
   	  SELECT @n_OpenLineCnt = SUM(CASE WHEN ISNULL(TRANSFERDETAIL.FromLot,'') = '' THEN 1 ELSE 0 END),
   	         @n_AllocatedLineCnt = SUM(CASE WHEN ISNULL(TRANSFERDETAIL.FromLot,'') <> '' THEN 1 ELSE 0 END) 
      FROM  TRANSFER (NOLOCK)
      JOIN  TRANSFERDETAIL (NOLOCK) ON TRANSFER.Transferkey = TRANSFERDETAIL.Transferkey
      JOIN  SKU (NOLOCK) ON TRANSFERDETAIL.FromStorerkey = SKU.StorerKey AND TRANSFERDETAIL.FromSku = SKU.Sku
      WHERE TRANSFER.Transferkey = @c_Transferkey
      AND TRANSFERDETAIL.FromQty > 0
      
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
   
   DECLARE CUR_TRANSFERDET_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT TD.TransferLineNumber, 
             TD.FromQty
      FROM TRANSFER T (NOLOCK)
      JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey
      WHERE T.Transferkey = @c_Transferkey
      AND ISNULL(TD.FromLot,'') = ''
      AND TD.FromStorerkey = @c_aStorerkey
      AND TD.FromSku = @c_aSku
      AND TD.Lottable01 = @c_Lottable01
      AND TD.Lottable02 = @c_Lottable02
      AND TD.Lottable03 = @c_Lottable03
      AND ISNULL(TD.Lottable04, '19000101') = @dt_Lottable04
      AND ISNULL(TD.Lottable05, '19000101')  = @dt_Lottable05
      AND TD.Lottable06 = @c_Lottable06
      AND TD.Lottable07 = @c_Lottable07
      AND TD.Lottable08 = @c_Lottable08
      AND TD.Lottable09 = @c_Lottable09
      AND TD.Lottable10 = @c_Lottable10
      AND TD.Lottable11 = @c_Lottable11
      AND TD.Lottable12 = @c_Lottable12
      AND ISNULL(TD.Lottable13, '19000101') = @dt_Lottable13
      AND ISNULL(TD.Lottable14, '19000101') = @dt_Lottable14
      AND ISNULL(TD.Lottable15, '19000101') = @dt_Lottable15
      AND TD.TransferLineNumber = CASE WHEN ISNULL(@c_aTransferLineNumber,'') <> '' THEN @c_aTransferLineNumber ELSE TD.TransferLineNumber END --NJOW02
   
   OPEN CUR_TRANSFERDET_UPDATE  
   
   FETCH NEXT FROM CUR_TRANSFERDET_UPDATE INTO @c_TransferLineNumber, @n_FromQty
   
   WHILE @@FETCH_STATUS <> -1 AND @n_BalQty > 0 
   BEGIN                	                                	             
      IF @n_FromQty <= @n_BalQty
      BEGIN
         IF @b_debug = 1 or @b_debug = 2
         BEGIN
         	  PRINT 'Update Transfer Line:' + RTRIM(@c_TransferLineNumber) + ' From Qty:' + CAST(@n_FromQty AS NVARCHAR(10))
            PRINT 'BalQty:' + CAST(@n_BalQty AS NVARCHAR(10))
         END

      	 UPDATE TRANSFERDETAIL WITH (ROWLOCK)
      	 SET FromId = @c_ID,
      	     FromLoc = @c_Loc,
      	     FromLot = @c_Lot,
      	     ToQty = @n_FromQty,
      	     ToId = CASE WHEN ISNULL(ToID,'') = '' THEN @c_ID ELSE ToID END,  --NJOW02
      	     ToLoc = @c_Loc,    
      	     ToStorerkey = CASE WHEN ISNULL(ToStorerkey,'') = '' THEN FromStorerkey ELSE ToStorerkey END,
      	     ToSku = CASE WHEN ISNULL(ToSku,'') = '' THEN FromSku ELSE ToSku END,
      	     ToPackkey = CASE WHEN ISNULL(ToPackkey,'') = '' THEN FromPackkey ELSE ToPackkey END,
      	     ToUOM = CASE WHEN ISNULL(ToUOM,'') = '' THEN FromUOM ELSE ToUOM END,
      	     Userdefine10 = @c_aUOM,     	     
      	     TrafficCop = NULL
      	 WHERE Transferkey = @c_Transferkey
      	 AND TransferLineNumber = @c_TransferLineNumber
      	 
      	 SELECT @n_err = @@ERROR
      	 IF @n_err <> 0
      	 BEGIN
            SET @n_continue = 3
            SET @n_err = 63530   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Transferdetail Failed! (nspTransferProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		   	 END
		   	 
		   	 SELECT @n_BalQty = @n_BalQty - @n_FromQty
      END
      ELSE
      BEGIN  -- pickqty > packqty
      	 SELECT @n_SplitQty = @n_FromQty - @n_BalQty

         SELECT @c_NewTransferLineNumber = RIGHT('00000' + CONVERT(VARCHAR(5), MAX(CONVERT(INT, TransferLineNumber)) + 1),5)
         FROM TRANSFERDETAIL WITH (NOLOCK)
         WHERE Transferkey = @c_Transferkey

         IF @b_debug = 1 or @b_debug = 2
         BEGIN
         	  PRINT 'Split Transfer Line:' + RTRIM(@c_TransferLineNumber) + ' From Qty:' + CAST(@n_FromQty AS NVARCHAR(10)) + ' New Transfer Line:' + RTRIM(@c_NewTransferLineNumber)
            PRINT 'BalQty:' + CAST(@n_BalQty AS NVARCHAR(10)) + ' SplitQty:' + CAST(@n_SplitQty AS NVARCHAR(10))
         END

         INSERT INTO TRANSFERDETAIL
         (
         	TransferKey,
         	TransferLineNumber,
         	FromStorerKey,
         	FromSku,
         	FromLoc,
         	FromLot,
         	FromId,
         	FromQty,
         	FromPackKey,
         	FromUOM,
         	LOTTABLE01,
         	LOTTABLE02,
         	LOTTABLE03,
         	LOTTABLE04,
         	LOTTABLE05,
         	ToStorerKey,
         	ToSku,
         	ToLoc,
         	ToLot,
         	ToId,
         	ToQty,
         	ToPackKey,
         	ToUOM,
         	[Status],
         	tolottable01,
         	tolottable02,
         	tolottable03,
         	tolottable04,
         	tolottable05,
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
         	ToLottable06,
         	ToLottable07,
         	ToLottable08,
         	ToLottable09,
         	ToLottable10,
         	ToLottable11,
         	ToLottable12,
         	ToLottable13,
         	ToLottable14,
         	ToLottable15
         )
         SELECT	TransferKey,
         	      @c_NewTransferLineNumber,
         	      FromStorerKey,
         	      FromSku,
         	      FromLoc,
         	      FromLot,
         	      FromId,
         	      @n_SplitQty,
         	      FromPackKey,
         	      FromUOM,
         	      LOTTABLE01,
         	      LOTTABLE02,
         	      LOTTABLE03,
         	      LOTTABLE04,
         	      LOTTABLE05,
         	      ToStorerKey,
         	      ToSku,
         	      ToLoc,
         	      ToLot,
         	      ToId,
         	      @n_SplitQty,
         	      ToPackKey,
         	      ToUOM,
         	      [Status],
         	      tolottable01,
         	      tolottable02,
         	      tolottable03,
         	      tolottable04,
         	      tolottable05,
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
         	      ToLottable06,
         	      ToLottable07,
         	      ToLottable08,
         	      ToLottable09,
         	      ToLottable10,
         	      ToLottable11,
         	      ToLottable12,
         	      ToLottable13,
         	      ToLottable14,
         	      ToLottable15
         FROM TRANSFERDETAIL(NOLOCK)
         WHERE Transferkey = @c_Transferkey
         AND TransferLineNumber = @c_TransferLineNumber    	 

      	 SELECT @n_err = @@ERROR
      	 IF @n_err <> 0
      	 BEGIN
            SET @n_continue = 3
            SET @n_err = 63540   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Insert Transferdetail Failed! (nspTransferProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		   	 END      	 
		   	 
		   	 --NJOW01
		   	 UPDATE TRANSFER WITH (ROWLOCK)
         SET TRANSFER.OpenQty = TRANSFER.OpenQty - @n_SplitQty
         WHERE Transferkey = @c_Transferkey
         
         SELECT @n_err = @@ERROR
      	 IF @n_err <> 0
      	 BEGIN
            SET @n_continue = 3
            SET @n_err = 63545   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Transfer Failed! (nspTransferProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		   	 END      	 
		   	 
      	 UPDATE TRANSFERDETAIL WITH (ROWLOCK)
      	 SET FromQty = @n_BalQty,
      	     FromId = @c_ID,
      	     FromLoc = @c_Loc,
      	     FromLot = @c_Lot,
      	     ToQty = @n_BalQty,
      	     ToId = CASE WHEN ISNULL(ToID,'') = '' THEN @c_ID ELSE ToID END,  --NJOW02      	     
      	     ToLoc = @c_Loc,      	     
      	     ToStorerkey = CASE WHEN ISNULL(ToStorerkey,'') = '' THEN FromStorerkey ELSE ToStorerkey END,
      	     ToSku = CASE WHEN ISNULL(ToSku,'') = '' THEN FromSku ELSE ToSku END,
      	     ToPackkey = CASE WHEN ISNULL(ToPackkey,'') = '' THEN FromPackkey ELSE ToPackkey END,
      	     ToUOM = CASE WHEN ISNULL(ToUOM,'') = '' THEN FromUOM ELSE ToUOM END,
      	     Userdefine10 = @c_aUOM,      	     
      	     TrafficCop = NULL
      	 WHERE Transferkey = @c_Transferkey
      	 AND TransferLineNumber = @c_TransferLineNumber
      	 
      	 SELECT @n_err = @@ERROR
      	 IF @n_err <> 0
      	 BEGIN
            SET @n_continue = 3
            SET @n_err = 63550   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Transferdetail Failed! (nspTransferProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		   	 END
          
         SELECT @n_BalQty = 0
      END
      
      UPDATE TRANSFERDETAIL WITH (ROWLOCK)
      SET TRANSFERDETAIL.Lottable01 = LA.Lottable01,
          TRANSFERDETAIL.Lottable02 = LA.Lottable02,
          TRANSFERDETAIL.Lottable03 = LA.Lottable03,
          TRANSFERDETAIL.Lottable04 = LA.Lottable04,
          TRANSFERDETAIL.Lottable05 = LA.Lottable05,
          TRANSFERDETAIL.Lottable06 = LA.Lottable06,
          TRANSFERDETAIL.Lottable07 = LA.Lottable07,
          TRANSFERDETAIL.Lottable08 = LA.Lottable08,
          TRANSFERDETAIL.Lottable09 = LA.Lottable09,
          TRANSFERDETAIL.Lottable10 = LA.Lottable10,
          TRANSFERDETAIL.Lottable11 = LA.Lottable11,
          TRANSFERDETAIL.Lottable12 = LA.Lottable12,
          TRANSFERDETAIL.Lottable13 = LA.Lottable13,
          TRANSFERDETAIL.Lottable14 = LA.Lottable14,
          TRANSFERDETAIL.Lottable15 = LA.Lottable15,
          TRANSFERDETAIL.ToLottable01 = CASE WHEN ISNULL(TRANSFERDETAIL.ToLottable01,'') = '' THEN LA.Lottable01 ELSE TRANSFERDETAIL.ToLottable01 END,
          TRANSFERDETAIL.ToLottable02 = CASE WHEN ISNULL(TRANSFERDETAIL.ToLottable02,'') = '' THEN LA.Lottable02 ELSE TRANSFERDETAIL.ToLottable02 END,
          TRANSFERDETAIL.ToLottable03 = CASE WHEN ISNULL(TRANSFERDETAIL.ToLottable03,'') = '' THEN LA.Lottable03 ELSE TRANSFERDETAIL.ToLottable03 END,
          TRANSFERDETAIL.ToLottable04 = CASE WHEN TRANSFERDETAIL.ToLottable04 IS NULL OR CONVERT(VARCHAR(20), TRANSFERDETAIL.ToLottable04, 112) = '19000101' THEN LA.Lottable04 ELSE TRANSFERDETAIL.ToLottable04 END,
          TRANSFERDETAIL.ToLottable05 = CASE WHEN TRANSFERDETAIL.ToLottable05 IS NULL OR CONVERT(VARCHAR(20), TRANSFERDETAIL.ToLottable05, 112) = '19000101' THEN LA.Lottable05 ELSE TRANSFERDETAIL.ToLottable05 END,
          TRANSFERDETAIL.ToLottable06 = CASE WHEN ISNULL(TRANSFERDETAIL.ToLottable06,'') = '' THEN LA.Lottable06 ELSE TRANSFERDETAIL.ToLottable06 END,           
          TRANSFERDETAIL.ToLottable07 = CASE WHEN ISNULL(TRANSFERDETAIL.ToLottable07,'') = '' THEN LA.Lottable07 ELSE TRANSFERDETAIL.ToLottable07 END,           
          TRANSFERDETAIL.ToLottable08 = CASE WHEN ISNULL(TRANSFERDETAIL.ToLottable08,'') = '' THEN LA.Lottable08 ELSE TRANSFERDETAIL.ToLottable08 END,           
          TRANSFERDETAIL.ToLottable09 = CASE WHEN ISNULL(TRANSFERDETAIL.ToLottable09,'') = '' THEN LA.Lottable09 ELSE TRANSFERDETAIL.ToLottable09 END,           
          TRANSFERDETAIL.ToLottable10 = CASE WHEN ISNULL(TRANSFERDETAIL.ToLottable10,'') = '' THEN LA.Lottable10 ELSE TRANSFERDETAIL.ToLottable10 END,           
          TRANSFERDETAIL.ToLottable11 = CASE WHEN ISNULL(TRANSFERDETAIL.ToLottable11,'') = '' THEN LA.Lottable11 ELSE TRANSFERDETAIL.ToLottable11 END,           
          TRANSFERDETAIL.ToLottable12 = CASE WHEN ISNULL(TRANSFERDETAIL.ToLottable12,'') = '' THEN LA.Lottable12 ELSE TRANSFERDETAIL.ToLottable12 END,           
          TRANSFERDETAIL.ToLottable13 = CASE WHEN TRANSFERDETAIL.ToLottable13 IS NULL OR CONVERT(VARCHAR(20), TRANSFERDETAIL.ToLottable13, 112) = '19000101' THEN LA.Lottable13 ELSE TRANSFERDETAIL.ToLottable13 END,
          TRANSFERDETAIL.ToLottable14 = CASE WHEN TRANSFERDETAIL.ToLottable14 IS NULL OR CONVERT(VARCHAR(20), TRANSFERDETAIL.ToLottable14, 112) = '19000101' THEN LA.Lottable13 ELSE TRANSFERDETAIL.ToLottable14 END,
          TRANSFERDETAIL.ToLottable15 = CASE WHEN TRANSFERDETAIL.ToLottable15 IS NULL OR CONVERT(VARCHAR(20), TRANSFERDETAIL.ToLottable15, 112) = '19000101' THEN LA.Lottable13 ELSE TRANSFERDETAIL.ToLottable15 END,
          TRANSFERDETAIL.TrafficCop = NULL          
      FROM TRANSFERDETAIL 
      JOIN LOTATTRIBUTE LA (NOLOCK) ON TRANSFERDETAIL.FromLot = LA.Lot
      WHERE TRANSFERDETAIL.Transferkey = @c_Transferkey
      AND TRANSFERDETAIL.TransferLineNumber = @c_TransferLineNumber

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63560   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Transferdetail Failed! (nspTransferProcessing)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		  END      	 
      
      FETCH NEXT FROM CUR_TRANSFERDET_UPDATE INTO @c_TransferLineNumber, @n_FromQty            
   END
   CLOSE CUR_TRANSFERDET_UPDATE  
   DEALLOCATE CUR_TRANSFERDET_UPDATE                

   IF @b_debug = 1 or @b_debug = 2
   BEGIN
   	  IF @n_BalQty > 0
         PRINT 'Unable Fully Allocate! BalQty:' + CAST(@n_BalQty AS NVARCHAR(10))
   END
  
   SET @n_QtyToTake = @n_QtyToTake - @n_BalQty

   GOTO RETURNFROMUPDATEINV 
END

GO