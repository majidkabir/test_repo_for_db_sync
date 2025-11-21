SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Kit_Allocation                                      */
/* Creation Date: 01-Aug-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-5819/WMS-8402/WMS-10084 Kitting allocation              */
/*          Use skip preallcation pickcode structure.                   */
/*          pre-allocation filter include kit from detail               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */ 
/* 09-SEP-2021  NJOW01  1.0   WMS-17858 Add post kit allocation         */
/* 22-NOV-2021  NJOW01  1.0   DEVOPS combine script                     */
/* 23-JUN-2022  NJOW02  1.1   WMS-20049 allow configure to copy qty to  */
/*                            expectedqty                               */ 
/* 15-Sep-2022  NJOW03  1.2   WMS-20808 set kit.status=1 if partial     */
/*                            allocated                                 */
/************************************************************************/
CREATE PROC  [dbo].[isp_Kit_Allocation]  
      @c_KitKey              NVARCHAR(10)
     ,@c_AllocateStrategykey NVARCHAR(10) = ''    
     ,@b_Success             INT            OUTPUT
     ,@n_err                 INT            OUTPUT
     ,@c_errmsg              NVARCHAR(250)  OUTPUT
              
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
         , @c_aKitKey                  NVARCHAR(10)
         , @c_aKitLineNumber           NVARCHAR(5)
         , @c_aType                    NVARCHAR(5)      
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
         , @c_kitAllocateNoConso       NVARCHAR(10) 
         , @c_ExpectedQtyFlag          NVARCHAR(5)            
         , @c_CaseUOM                  NVARCHAR(10)
         , @c_PalletUOM                NVARCHAR(10)
         , @c_EachUOM                  NVARCHAR(10)
         , @c_UOM                      NVARCHAR(10)
   
   --NJOW01      
   DECLARE @c_AllocateStrategykey_SC   NVARCHAR(10)                                
         , @c_UpdateUsedQty            NVARCHAR(5)
         , @c_UpdateExpectedQty        NVARCHAR(5) --NJOW02
         , @c_LineAllocated            INT
         , @c_option1                  NVARCHAR(50)
         , @c_option2                  NVARCHAR(50)
         , @c_option3                  NVARCHAR(50)
         , @c_option4                  NVARCHAR(50)
         , @c_option5                  NVARCHAR(4000)
           
   DECLARE @c_NewKitLineNumber NVARCHAR(5)
         , @c_KitLineNumber NVARCHAR(5)
         , @n_BalQty INT
         , @n_Qty INT
         , @n_SplitQty INT

   IF @n_err = 1
      SET @b_debug = 1
   ELSE
      SET @b_debug = 0

   SELECT @n_StartTCnt = @@TRANCOUNT, @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = '', @c_LineAllocated = 0
   SET @c_ExpectedQtyFlag = 'Y'  --default Y get from ExpectedQty field
   SET @c_UpdateUsedQty = 'N'  --default N Update qty field  --NJOW01
   SET @c_UpdateExpectedQty = 'N' --NJOW02
   
   IF @@TRANCOUNT = 0 --NJOW01
      BEGIN TRAN
   
   --NJOW01
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
   
   SELECT @c_aStorerkey = Storerkey,
          @c_aFacility = Facility
   FROM KIT (NOLOCK)
   WHERE KitKey = @c_Kitkey
  
   --NJOW01 S   
   EXECUTE nspGetRight                                
      @c_Facility   = @c_afacility,                     
      @c_StorerKey  = @c_aStorerKey,                    
      @c_sku        = '',                          
      @c_ConfigKey  = 'KitAllocateStrategykey', -- Configkey         
      @b_Success    = @b_success   OUTPUT,             
      @c_authority  = @c_AllocateStrategykey_SC OUTPUT,             
      @n_err        = @n_err       OUTPUT,             
      @c_errmsg     = @c_errmsg    OUTPUT,             
      @c_Option1    = @c_option1   OUTPUT,               
      @c_Option2    = @c_option2   OUTPUT,               
      @c_Option3    = @c_option3   OUTPUT,               
      @c_Option4    = @c_option4   OUTPUT,               
      @c_Option5    = @c_option5   OUTPUT                

   SELECT @c_ExpectedQtyFlag = dbo.fnc_GetParamValueFromString('@c_ExpectedQtyFlag', @c_Option5, @c_ExpectedQtyFlag)
   SELECT @c_UpdateUsedQty = dbo.fnc_GetParamValueFromString('@c_UpdateUsedQty', @c_Option5, @c_UpdateUsedQty)
   SELECT @c_UpdateExpectedQty = dbo.fnc_GetParamValueFromString('@c_UpdateExpectedQty', @c_Option5, @c_UpdateExpectedQty)  --NJOW02
   
   --NJOW01 E
   
   IF ISNULL(@c_AllocateStrategykey,'') = ''
   BEGIN
     	SET @c_AllocateStrategykey = @c_AllocateStrategykey_SC  --NJOW01
      --SELECT @c_AllocateStrategykey = dbo.fnc_GetRight(@c_aFacility, @c_aStorerkey, '', 'KitAllocateStrategykey') 
      
      IF ISNULL(@c_AllocateStrategykey,'') IN('0','1')
         SET @c_AllocateStrategykey = ''
   END         
   
   IF ISNULL(@c_AllocateStrategykey,'') <> ''
   BEGIN
      IF NOT EXISTS (SELECT 1 
                     FROM ALLOCATESTRATEGYDETAIL (NOLOCK)
                     WHERE AllocateStrategykey = @c_AllocateStrategykey)
      BEGIN      	
         SET @n_continue = 3
         SET @n_err = 63500   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+ ': Invalid AllocateStrategyKey: ''' + RTRIM(@c_AllocateStrategykey) + '''.(isp_Kit_Allocation)'
         GOTO EXIT_SP
      END               
   END   
   ELSE
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63501   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+ ': Kit Allocation is not enabled. (isp_Kit_Allocation)'
      GOTO EXIT_SP
   END

   EXEC isp_PreKitAllocation_Wrapper 
         @c_KitKey        = @c_KitKey 
       , @b_Success       = @b_Success OUTPUT 
       , @n_Err           = @n_Err     OUTPUT 
       , @c_ErrMsg        = @c_ErrMsg  OUTPUT 

   IF @b_Success <> 1
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = 'isp_Kit_Allocation : ' + RTRIM(@c_errmsg) 
      GOTO EXIT_SP
   END
           
   SELECT @c_MinShelfLife60Mth = '', @c_ShelfLifeInDays = '', @n_CursorCandidates_Open = 0, @c_PStorerkey = '', @c_HostWHCode  = ''
               
   SELECT @c_KitAllocateNoConso = dbo.fnc_GetRight(@c_aFacility, @c_aStorerkey, '', 'KitAllocateNoConso') 

   CREATE TABLE #OPKITLINES 
         (  [SeqNo]                    [INT] IDENTITY(1, 1)
         ,  [Facility]                 [NVARCHAR](5)  NOT NULL
         ,  [KitKey]                   [NVARCHAR](10) NOT NULL
         ,  [KitLineNumber]            [NVARCHAR](5)  NOT NULL
         ,  [Type]          					 [NVARCHAR](5)  NOT NULL
         ,  [Storerkey]                [NVARCHAR](15) NOT NULL
         ,  [Sku]                      [NVARCHAR](20) NOT NULL
         ,  [ExpectedQty]              [INT]          NOT NULL
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

   INSERT INTO #OPKITLINES
         (  [Facility]                  
         ,  [KitKey]                    
         ,  [KitLineNumber]
         ,  [Type]                   
         ,  [Storerkey]                 
         ,  [Sku]
         ,  [ExpectedQty] 
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
   SELECT   Facility = ISNULL(RTRIM(KIT.Facility),'')
         ,  KitKey = ISNULL(RTRIM(KIT.KitKey),'')
         ,  KitLineNumber = ISNULL(RTRIM(KITDETAIL.KitLineNumber),'')           
         ,  Type = ISNULL(RTRIM(KITDETAIL.Type),'')
         ,  Storerkey= ISNULL(RTRIM(KITDETAIL.Storerkey),'')
         ,  Sku      = ISNULL(RTRIM(KITDETAIL.Sku),'')
         ,  ExpectedQty = ISNULL(KITDETAIL.ExpectedQty,0)
         ,  Qty      = ISNULL(KITDETAIL.Qty,0)
         ,  Packkey  = ISNULL(RTRIM(KITDETAIL.Packkey),'')
         ,  StrategyKey = CASE WHEN ISNULL(@c_AllocateStrategykey,'') <> '' THEN
                             @c_AllocateStrategyKey
                          ELSE   
                             ISNULL(RTRIM(STGY.AllocateStrategyKey),'') 
                          END   
         ,  MinShelf    = 0
         ,  Lottable01  = ISNULL(RTRIM(KITDETAIL.Lottable01),'')
         ,  Lottable02  = ISNULL(RTRIM(KITDETAIL.Lottable02),'')
         ,  Lottable03  = ISNULL(RTRIM(KITDETAIL.Lottable03),'')
         ,  Lottable04  = ISNULL(KITDETAIL.Lottable04, '19000101')
         ,  Lottable05  = ISNULL(KITDETAIL.Lottable05, '19000101')
         ,  Lottable06  = ISNULL(RTRIM(KITDETAIL.Lottable06),'')
         ,  Lottable07  = ISNULL(RTRIM(KITDETAIL.Lottable07),'')
         ,  Lottable08  = ISNULL(RTRIM(KITDETAIL.Lottable08),'')
         ,  Lottable09  = ISNULL(RTRIM(KITDETAIL.Lottable09),'')
         ,  Lottable10  = ISNULL(RTRIM(KITDETAIL.Lottable10),'')
         ,  Lottable11  = ISNULL(RTRIM(KITDETAIL.Lottable11),'')
         ,  Lottable12  = ISNULL(RTRIM(KITDETAIL.Lottable12),'')
         ,  Lottable13  = ISNULL(KITDETAIL.Lottable13, '19000101')
         ,  Lottable14  = ISNULL(KITDETAIL.Lottable14, '19000101')
         ,  Lottable15  = ISNULL(KITDETAIL.Lottable15, '19000101')
      FROM  KIT (NOLOCK)
      JOIN  KITDETAIL (NOLOCK) ON KIT.Kitkey = KITDETAIL.Kitkey
      JOIN  SKU (NOLOCK) ON KITDETAIL.Storerkey = SKU.StorerKey AND KITDETAIL.Sku = SKU.Sku
      JOIN  STRATEGY STGY (NOLOCK) ON SKU.Strategykey = STGY.StrategyKey
      WHERE KIT.Kitkey = @c_Kitkey
      AND ISNULL(KITDETAIL.Lot,'') = ''
      AND KITDETAIL.Type = 'F'
      ORDER BY KITDETAIL.SKU
      
      SET @n_cnt = @@ROWCOUNT      
      
      IF @b_debug = 1 or @b_debug = 2
         SELECT * FROM #OPKITLINES
      
      IF @n_cnt = 0
      BEGIN
         SET @n_continue = 4
         --SET @n_err = 63510   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         --SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': No Available Kit From Line To Allocate.(Empty Lot) (isp_Kit_Allocation)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
         GOTO EXIT_SP
      END      

   IF @c_KitAllocateNoConso = 'Y'
   BEGIN
      DECLARE KITLINES_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT   #OPKITLINES.KitKey
            ,  #OPKITLINES.Facility
            ,  #OPKITLINES.StorerKey
            ,  #OPKITLINES.SKU
            ,  #OPKITLINES.PackKey
            ,  CASE WHEN @c_ExpectedQtyFlag = 'Y' THEN 
                    SUM(#OPKITLINES.ExpectedQty) 
               ELSE SUM(#OPKITLINES.Qty) END AS Qty
            ,  #OPKITLINES.StrategyKey
            ,  #OPKITLINES.MinShelf 
            ,  #OPKITLINES.Lottable01 
            ,  #OPKITLINES.Lottable02
            ,  #OPKITLINES.Lottable03 
            ,  #OPKITLINES.Lottable04 
            ,  #OPKITLINES.Lottable05 
            ,  #OPKITLINES.Lottable06 
            ,  #OPKITLINES.Lottable07 
            ,  #OPKITLINES.Lottable08 
            ,  #OPKITLINES.Lottable09 
            ,  #OPKITLINES.Lottable10 
            ,  #OPKITLINES.Lottable11 
            ,  #OPKITLINES.Lottable12 
            ,  #OPKITLINES.Lottable13 
            ,  #OPKITLINES.Lottable14 
            ,  #OPKITLINES.Lottable15
            ,  #OPKITLINES.KitLineNumber
            ,  #OPKITLINES.Type            
        FROM #OPKITLINES 
        GROUP BY #OPKITLINES.KitKey
            ,  #OPKITLINES.Facility
            ,  #OPKITLINES.StorerKey
            ,  #OPKITLINES.SKU
            ,  #OPKITLINES.PackKey
            ,  #OPKITLINES.StrategyKey
            ,  #OPKITLINES.MinShelf 
            ,  #OPKITLINES.Lottable01 
            ,  #OPKITLINES.Lottable02
            ,  #OPKITLINES.Lottable03 
            ,  #OPKITLINES.Lottable04 
            ,  #OPKITLINES.Lottable05 
            ,  #OPKITLINES.Lottable06 
            ,  #OPKITLINES.Lottable07 
            ,  #OPKITLINES.Lottable08 
            ,  #OPKITLINES.Lottable09 
            ,  #OPKITLINES.Lottable10 
            ,  #OPKITLINES.Lottable11 
            ,  #OPKITLINES.Lottable12 
            ,  #OPKITLINES.Lottable13 
            ,  #OPKITLINES.Lottable14 
            ,  #OPKITLINES.Lottable15
            ,  #OPKITLINES.KitLineNumber
            ,  #OPKITLINES.Type            
         ORDER BY #OPKITLINES.StorerKey, #OPKITLINES.SKU
   END   
   ELSE
   BEGIN
      DECLARE KITLINES_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT   #OPKITLINES.KitKey
            ,  #OPKITLINES.Facility
            ,  #OPKITLINES.StorerKey
            ,  #OPKITLINES.SKU
            ,  #OPKITLINES.PackKey
            ,  CASE WHEN @c_ExpectedQtyFlag = 'Y' THEN 
                    SUM(#OPKITLINES.ExpectedQty) 
               ELSE SUM(#OPKITLINES.Qty) END AS Qty
            ,  #OPKITLINES.StrategyKey
            ,  #OPKITLINES.MinShelf 
            ,  #OPKITLINES.Lottable01 
            ,  #OPKITLINES.Lottable02
            ,  #OPKITLINES.Lottable03 
            ,  #OPKITLINES.Lottable04 
            ,  #OPKITLINES.Lottable05 
            ,  #OPKITLINES.Lottable06 
            ,  #OPKITLINES.Lottable07 
            ,  #OPKITLINES.Lottable08 
            ,  #OPKITLINES.Lottable09 
            ,  #OPKITLINES.Lottable10 
            ,  #OPKITLINES.Lottable11 
            ,  #OPKITLINES.Lottable12 
            ,  #OPKITLINES.Lottable13 
            ,  #OPKITLINES.Lottable14 
            ,  #OPKITLINES.Lottable15
            ,  '     '  
            ,  #OPKITLINES.Type            
        FROM #OPKITLINES 
        GROUP BY #OPKITLINES.KitKey
            ,  #OPKITLINES.Facility
            ,  #OPKITLINES.StorerKey
            ,  #OPKITLINES.SKU
            ,  #OPKITLINES.PackKey
            ,  #OPKITLINES.StrategyKey
            ,  #OPKITLINES.MinShelf 
            ,  #OPKITLINES.Lottable01 
            ,  #OPKITLINES.Lottable02
            ,  #OPKITLINES.Lottable03 
            ,  #OPKITLINES.Lottable04 
            ,  #OPKITLINES.Lottable05 
            ,  #OPKITLINES.Lottable06 
            ,  #OPKITLINES.Lottable07 
            ,  #OPKITLINES.Lottable08 
            ,  #OPKITLINES.Lottable09 
            ,  #OPKITLINES.Lottable10 
            ,  #OPKITLINES.Lottable11 
            ,  #OPKITLINES.Lottable12 
            ,  #OPKITLINES.Lottable13 
            ,  #OPKITLINES.Lottable14 
            ,  #OPKITLINES.Lottable15
            ,  #OPKITLINES.Type
         ORDER BY #OPKITLINES.StorerKey, #OPKITLINES.SKU
   END
     
   OPEN KITLINES_CUR
   FETCH NEXT FROM KITLINES_CUR INTO @c_aKitKey
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
                                    ,@c_aKitLineNumber 
                                    ,@c_aType

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      SET @c_aLot = ''
      SET @c_ALLineNo = ''
      SET @n_aUOMQty = 0
      SET @c_CaseUOM = ''
      SET @c_PalletUOM = ''
      SET @c_EachUOM = ''
      
      SELECT @c_PalletUOM = CASE WHEN Pallet > 0 AND ISNULL(PackUOM4,'') <> '' THEN PackUOM4 ELSE '' END,
             @c_CaseUOM = CASE WHEN CaseCnt > 0 AND ISNULL(PackUOM1,'') <> '' THEN PackUOM1 ELSE '' END,
             @c_EachUOM = CASE WHEN Qty > 0 AND ISNULL(PackUOM3,'') <> '' THEN PackUOM3 ELSE '' END
      FROM PACK(NOLOCK)
      WHERE Packkey = @c_aPackkey
      
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
             SET @c_errmsg = 'isp_Kit_Allocation : ' + RTRIM(@c_errmsg) 
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
             SET @c_errmsg = 'isp_Kit_Allocation : ' + RTRIM(@c_errmsg) 
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

         SET @c_OtherParms = RTRIM(@c_aKitKey) + @c_aKitLineNumber + 'K'  --key + line no + call source 
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
                  SET @c_ExecuteSP = RTRIM(@c_ExecuteSP) + ' ' +RTRIM(@c_ParmName) + ' = N''' + @c_aKitKey   + ''''  
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
            SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (isp_Kit_Allocation)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
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

      FETCH NEXT FROM KITLINES_CUR INTO @c_aKitKey
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
                                       ,@c_aKitLineNumber       
                                       ,@c_aType                                 
   END
   CLOSE KITLINES_CUR
   DEALLOCATE KITLINES_CUR
   
   --NJOW01
   --Update used qty 
   IF @n_continue IN(1,2) AND @c_UpdateUsedQty = 'Y' AND @c_ExpectedQtyFlag = 'Y' AND @c_LineAllocated > 0
   BEGIN
      UPDATE KITDETAIL WITH (ROWLOCK)
      SET Qty = ExpectedQty,
          TrafficCop = NULL 
      WHERE Kitkey = @c_KitKey 
      AND (
            (Type = 'F'
             AND Lot <> ''
             AND Lot IS NOT NULL
             AND ExpectedQty > 0
             AND Qty = 0)
         OR (Type = 'T'
             AND ExpectedQty > 0
             AND Qty = 0)
           )
                                                  
      SELECT @n_err = @@ERROR                
      
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63530   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Kitdetail Failed! (isp_Kit_Allocation)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		  END   	            
   END
   
   --NJOW02
   IF @n_continue IN(1,2) AND @c_UpdateExpectedQty = 'Y' AND @c_ExpectedQtyFlag = 'N' AND @c_LineAllocated > 0
   BEGIN
      UPDATE KITDETAIL WITH (ROWLOCK)
      SET ExpectedQty = Qty,
          TrafficCop = NULL 
      WHERE Kitkey = @c_KitKey 
      AND (
            (Type = 'F'
             AND Lot <> ''
             AND Lot IS NOT NULL
             AND ExpectedQty = 0
             AND Qty > 0)
         OR (Type = 'T'
             AND ExpectedQty = 0
             AND Qty > 0)
           )
                                                  
      SELECT @n_err = @@ERROR                
      
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63540   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Kitdetail Failed! (isp_Kit_Allocation)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		  END   	            
   END

         
   --NJOW01      
   IF @n_continue IN(1,2) AND @c_LineAllocated > 0
   BEGIN
      EXEC isp_PostKitAllocation_Wrapper 
            @c_KitKey        = @c_KitKey 
          , @b_Success       = @b_Success OUTPUT 
          , @n_Err           = @n_Err     OUTPUT 
          , @c_ErrMsg        = @c_ErrMsg  OUTPUT 
      
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = 'isp_Kit_Allocation : ' + RTRIM(@c_errmsg) 
         GOTO EXIT_SP
      END
   END
   
   EXIT_SP:
   
   IF @n_continue IN(1,2)
   BEGIN
   	  IF EXISTS(SELECT 1 
   	            FROM KITDETAIL (NOLOCK)
   	            WHERE Kitkey = @c_Kitkey
   	            AND Type = 'F'
   	            AND Lot <> '' 
   	            AND Lot IS NOT NULL)   	                
   	   BEGIN
   	   	  IF EXISTS(SELECT 1 
   	                FROM KITDETAIL (NOLOCK)
   	                WHERE Kitkey = @c_Kitkey
   	                AND Type = 'F'
   	                AND (Lot = '' OR Lot IS NULL)
   	               )
   	      BEGIN  --NJOW03               
   	         UPDATE KIT WITH (ROWLOCK)
   	         SET Status = '1',
   	             TrafficCop = NULL
   	         WHERE KitKey = @c_Kitkey
   	         AND Status <= '2'   	      	 
   	      END          
   	      ELSE
   	      BEGIN   	            
   	         UPDATE KIT WITH (ROWLOCK)
   	         SET Status = '2',
   	             TrafficCop = NULL
   	         WHERE KitKey = @c_Kitkey
   	         AND Status < '2'
   	      END

      	  SELECT @n_err = @@ERROR
      	  IF @n_err <> 0
      	  BEGIN
             SET @n_continue = 3
             SET @n_err = 63550   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Kit Failed! (isp_Kit_Allocation)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		   	  END   	      
   	   END             
   END

   IF CURSOR_STATUS('LOCAL', 'KITLINES_CUR') IN (0 , 1)
   BEGIN
      CLOSE KITLINES_CUR
      DEALLOCATE KITLINES_CUR
   END

   IF CURSOR_STATUS('GLOBAL', 'CURSOR_CANDIDATES') IN (0 , 1)
   BEGIN
      CLOSE CURSOR_CANDIDATES
      DEALLOCATE CURSOR_CANDIDATES
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_Kit_Allocation'
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
            
   DECLARE CUR_KITDET_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT KD.kitLineNumber, 
             CASE WHEN @c_ExpectedQtyFlag = 'Y' THEN 
                KD.ExpectedQty
             ELSE KD.Qty END   
      FROM KIT K (NOLOCK)
      JOIN KITDETAIL KD (NOLOCK) ON K.kitkey = KD.Kitkey
      WHERE K.Kitkey = @c_aKitkey
      AND ISNULL(KD.Lot,'') = ''
      AND KD.Type = @c_aType
      AND KD.Storerkey = @c_aStorerkey
      AND KD.Sku = @c_aSku
      AND KD.Lottable01 = @c_Lottable01
      AND KD.Lottable02 = @c_Lottable02
      AND KD.Lottable03 = @c_Lottable03
      AND ISNULL(KD.Lottable04, '19000101') = @dt_Lottable04
      AND ISNULL(KD.Lottable05, '19000101')  = @dt_Lottable05
      AND KD.Lottable06 = @c_Lottable06
      AND KD.Lottable07 = @c_Lottable07
      AND KD.Lottable08 = @c_Lottable08
      AND KD.Lottable09 = @c_Lottable09
      AND KD.Lottable10 = @c_Lottable10
      AND KD.Lottable11 = @c_Lottable11
      AND KD.Lottable12 = @c_Lottable12
      AND ISNULL(KD.Lottable13, '19000101') = @dt_Lottable13
      AND ISNULL(KD.Lottable14, '19000101') = @dt_Lottable14
      AND ISNULL(KD.Lottable15, '19000101') = @dt_Lottable15
      AND KD.KitLineNumber = CASE WHEN ISNULL(@c_aKitLineNumber,'') <> '' THEN @c_aKitLineNumber ELSE KD.KitLineNumber END 
   
   OPEN CUR_KITDET_UPDATE  
   
   FETCH NEXT FROM CUR_KITDET_UPDATE INTO @c_KitLineNumber, @n_Qty
   
   WHILE @@FETCH_STATUS <> -1 AND @n_BalQty > 0 
   BEGIN                	                         	            	             
      IF @n_Qty <= @n_BalQty
      BEGIN
         IF @b_debug = 1 or @b_debug = 2
         BEGIN
         	  PRINT 'Update Kit From Line:' + RTRIM(@c_KitLineNumber) + ' From Qty:' + CAST(@n_Qty AS NVARCHAR(10))
            PRINT 'BalQty:' + CAST(@n_BalQty AS NVARCHAR(10))
         END

         SET @c_UOM = @c_EachUOM
         
         /*IF @n_PackQty > 0
         BEGIN
            IF @c_aUOM = '1' AND @n_Qty % @n_PackQty = 0 
               SET @c_UOM = @c_PalletUOM
            ELSE IF @c_aUOM = '2' AND @n_Qty % @n_PackQty = 0
               SET @c_UOM = @c_CaseUOM
         END*/    

      	 UPDATE KITDETAIL WITH (ROWLOCK)
      	 SET Id = @c_ID,
      	     Loc = @c_Loc,
      	     Lot = @c_Lot,      	     
      	     UOM = @c_UOM,
      	     TrafficCop = NULL
      	 WHERE kitkey = @c_aKitkey
      	 AND KitLineNumber = @c_KitLineNumber
      	 AND Type = @c_aType
      	 
      	 SELECT @n_err = @@ERROR
      	 IF @n_err <> 0
      	 BEGIN
            SET @n_continue = 3
            SET @n_err = 63550   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Kitdetail Failed! (isp_Kit_Allocation)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		   	 END
		   	 
		   	 SELECT @n_BalQty = @n_BalQty - @n_Qty
      END
      ELSE
      BEGIN  
      	 SELECT @n_SplitQty = @n_Qty - @n_BalQty

         SELECT @c_NewKitLineNumber = RIGHT('00000' + CONVERT(VARCHAR(5), MAX(CONVERT(INT, KitLineNumber)) + 1),5)
         FROM KITDETAIL WITH (NOLOCK)
         WHERE kitkey = @c_Kitkey
         AND Type = @c_aType

         IF @b_debug = 1 or @b_debug = 2
         BEGIN
         	  PRINT 'Split Kit Line:' + RTRIM(@c_KitLineNumber) + ' From Qty:' + CAST(@n_Qty AS NVARCHAR(10)) + ' New Kit Line:' + RTRIM(@c_NewKitLineNumber)
            PRINT 'BalQty:' + CAST(@n_BalQty AS NVARCHAR(10)) + ' SplitQty:' + CAST(@n_SplitQty AS NVARCHAR(10))
         END

         SET @c_UOM = @c_EachUOM
         
         /*IF @n_PackQty > 0
         BEGIN
            IF @c_aUOM = '1' AND @n_BalQty % @n_PackQty = 0 
               SET @c_UOM = @c_PalletUOM
            ELSE IF @c_aUOM = '2' AND @n_BalQty % @n_PackQty = 0
               SET @c_UOM = @c_CaseUOM
         END*/    

         INSERT INTO KITDETAIL
         (
         	KITKey,
         	KITLineNumber,
         	[Type],
         	StorerKey,
         	Sku,
         	Lot,
         	Loc,
         	Id,
         	ExpectedQty,
         	Qty,
         	PackKey,
         	UOM,
         	LOTTABLE01,
         	LOTTABLE02,
         	LOTTABLE03,
         	LOTTABLE04,
         	LOTTABLE05,
         	[Status],
         	EffectiveDate,
         	ExternKitKey,
         	ExternLineNo,
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
         	Channel,
         	Channel_ID
         )
         SELECT
         	KITDETAIL.KITKey,
         	@c_NewKitLineNumber,
         	KITDETAIL.[Type],
         	KITDETAIL.StorerKey,
         	KITDETAIL.Sku,
         	KITDETAIL.Lot,
         	KITDETAIL.Loc,
         	KITDETAIL.Id,
         	CASE WHEN @c_ExpectedQtyFlag = 'Y' THEN @n_SplitQty ELSE KITDETAIL.ExpectedQty END,
         	CASE WHEN @c_ExpectedQtyFlag <> 'Y' THEN @n_SplitQty ELSE KITDETAIL.Qty END,
         	KITDETAIL.PackKey,
         	@c_EachUOM, --KITDETAIL.UOM
         	KITDETAIL.LOTTABLE01,
         	KITDETAIL.LOTTABLE02,
         	KITDETAIL.LOTTABLE03,
         	KITDETAIL.LOTTABLE04,
         	KITDETAIL.LOTTABLE05,
         	KITDETAIL.[Status],
         	KITDETAIL.EffectiveDate,
         	KITDETAIL.ExternKitKey,
         	KITDETAIL.ExternLineNo,
         	KITDETAIL.Lottable06,
         	KITDETAIL.Lottable07,
         	KITDETAIL.Lottable08,
         	KITDETAIL.Lottable09,
         	KITDETAIL.Lottable10,
         	KITDETAIL.Lottable11,
         	KITDETAIL.Lottable12,
         	KITDETAIL.Lottable13,
         	KITDETAIL.Lottable14,
         	KITDETAIL.Lottable15,
         	KITDETAIL.Channel,
         	KITDETAIL.Channel_ID
         FROM KITDETAIL (NOLOCK) 
         WHERE KITDETAIL.kitkey = @c_aKitkey
         AND KITDETAIL.KitLineNumber = @c_KitLineNumber
         AND KITDETAIL.Type = @c_aType    	 

      	 SELECT @n_err = @@ERROR
      	 IF @n_err <> 0
      	 BEGIN
            SET @n_continue = 3
            SET @n_err = 63560   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Insert Kitdetail Failed! (isp_Kit_Allocation)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		   	 END      	 
		   	 
		   	 /*
		   	 UPDATE KIT WITH (ROWLOCK)
         SET KIT.OpenQty = KIT.OpenQty - @n_SplitQty
         WHERE KitKey = @c_aKitKey
         
         SELECT @n_err = @@ERROR
      	 IF @n_err <> 0
      	 BEGIN
            SET @n_continue = 3
            SET @n_err = 63545   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Kit Failed! (isp_Kit_Allocation)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		   	 END
		   	 */      	 
		   	 
      	 UPDATE KITDETAIL WITH (ROWLOCK)
      	 SET ExpectedQty  = CASE WHEN @c_ExpectedQtyFlag = 'Y' THEN @n_BalQty ELSE ExpectedQty END,
      	     Qty = CASE WHEN @c_ExpectedQtyFlag <> 'Y' THEN @n_BalQty ELSE Qty END,
      	     Id = @c_ID,
      	     Loc = @c_Loc,
      	     Lot = @c_Lot,
      	     UOM = @c_UOM,
      	     TrafficCop = NULL
      	 WHERE KitKey = @c_aKitkey
      	 AND KitLineNumber = @c_KitLineNumber
      	 AND Type = @c_aType
      	 
      	 SELECT @n_err = @@ERROR
      	 IF @n_err <> 0
      	 BEGIN
            SET @n_continue = 3
            SET @n_err = 63570   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Kitdetail Failed! (isp_Kit_Allocation)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		   	 END
          
         SELECT @n_BalQty = 0
      END
      
      UPDATE KITDETAIL WITH (ROWLOCK)
      SET KITDETAIL.Lottable01 = LA.Lottable01,
          KITDETAIL.Lottable02 = LA.Lottable02,
          KITDETAIL.Lottable03 = LA.Lottable03,
          KITDETAIL.Lottable04 = LA.Lottable04,
          KITDETAIL.Lottable05 = LA.Lottable05,
          KITDETAIL.Lottable06 = LA.Lottable06,
          KITDETAIL.Lottable07 = LA.Lottable07,
          KITDETAIL.Lottable08 = LA.Lottable08,
          KITDETAIL.Lottable09 = LA.Lottable09,
          KITDETAIL.Lottable10 = LA.Lottable10,
          KITDETAIL.Lottable11 = LA.Lottable11,
          KITDETAIL.Lottable12 = LA.Lottable12,
          KITDETAIL.Lottable13 = LA.Lottable13,
          KITDETAIL.Lottable14 = LA.Lottable14,
          KITDETAIL.Lottable15 = LA.Lottable15,
          KITDETAIL.TrafficCop = NULL          
      FROM KITDETAIL 
      JOIN LOTATTRIBUTE LA (NOLOCK) ON KITDETAIL.Lot = LA.Lot
      WHERE KITDETAIL.Kitkey = @c_aKitkey
      AND KITDETAIL.KitLineNumber = @c_KitLineNumber
      AND KITDETAIL.Type = @c_aType

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63580   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update KITDETAIL Failed! (isp_Kit_Allocation)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
		  END      	 
		  
		  SET @c_LineAllocated = @c_LineAllocated + 1 --NJOW01
      
      FETCH NEXT FROM CUR_KITDET_UPDATE INTO @c_kitLineNumber, @n_Qty            
   END
   CLOSE CUR_KITDET_UPDATE  
   DEALLOCATE CUR_KITDET_UPDATE                

   IF @b_debug = 1 or @b_debug = 2
   BEGIN
   	  IF @n_BalQty > 0
         PRINT 'Unable Fully Allocate! BalQty:' + CAST(@n_BalQty AS NVARCHAR(10))
   END
  
   SET @n_QtyToTake = @n_QtyToTake - @n_BalQty

   GOTO RETURNFROMUPDATEINV 
END

GO