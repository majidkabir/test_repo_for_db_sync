SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_TRF_PopulateUCC_Wrapper                         */                                                                                  
/* Creation Date: 2020-08-25                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2293 - Transfer  SP for Populate Transfer by UCC       */
/*                                                                      */
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.2                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */
/* 2021-01-15  Wan01    1.1   Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/  
/* 2023-05-03  Wan02    1.2   LFWM-4072 - [CN] PROD_Mannings Populate   */
/*                            Transfer By UCC function needs to be fixed*/
/*                            in Transfer screen                        */
/*                            DevOps Combine Script                     */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_TRF_PopulateUCC_Wrapper]                                                                                                                     
      @c_TransferKey          NVARCHAR(10)         
   ,  @c_UCC_RowRef_List      NVARCHAR(MAX) = ''  -- UCC_Row_Ref seperated by '|'   
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)= '' OUTPUT
   ,  @n_ErrGroupKey          INT          = 0  OUTPUT    
   ,  @c_UserName             NVARCHAR(128)= ''  
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt                  INT = @@TRANCOUNT  
         ,  @n_Continue                   INT = 1

         ,  @n_Cnt                        INT = 0

         ,  @n_UCC_RowRef                 BIGINT = 0

         ,  @c_DefaultUOM                 NVARCHAR(10)   = ''
         ,  @c_UOM1                       NVARCHAR(10)   = ''
         ,  @c_UOM2                       NVARCHAR(10)   = ''
         ,  @c_UOM3                       NVARCHAR(10)   = ''
         ,  @c_UOM4                       NVARCHAR(10)   = ''

         ,  @c_FromFacility               NVARCHAR(5)    = ''
         ,  @c_FromStorerkey              NVARCHAR(15)   = ''
         ,  @c_ToFacility                 NVARCHAR(5)    = ''
         ,  @c_ToStorerkey                NVARCHAR(15)   = '' 
         ,  @c_TransferLineNumber         NVARCHAR(5)    = ''
         ,  @c_FromSku                    NVARCHAR(20)   = ''
         ,  @c_FromPackkey                NVARCHAR(10)   = ''
         ,  @c_FromUOM                    NVARCHAR(10)   = ''
         ,  @c_FromLot                    NVARCHAR(10)   = ''
         ,  @c_FromLottable01             NVARCHAR(18)   = ''
         ,  @c_FromLottable02             NVARCHAR(18)   = ''
         ,  @c_FromLottable03             NVARCHAR(18)   = ''
         ,  @dt_FromLottable04            DATETIME       = NULL
         ,  @dt_FromLottable05            DATETIME       = NULL
         ,  @c_FromLottable06             NVARCHAR(30)   = ''
         ,  @c_FromLottable07             NVARCHAR(30)   = ''
         ,  @c_FromLottable08             NVARCHAR(30)   = ''
         ,  @c_FromLottable09             NVARCHAR(30)   = ''
         ,  @c_FromLottable10             NVARCHAR(30)   = ''
         ,  @c_FromLottable11             NVARCHAR(30)   = ''
         ,  @c_FromLottable12             NVARCHAR(30)   = ''
         ,  @dt_FromLottable13            DATETIME       = NULL
         ,  @dt_FromLottable14            DATETIME       = NULL
         ,  @dt_FromLottable15            DATETIME       = NULL
         ,  @n_FromQty                    INT            = 0                        --(Wan02)
         ,  @c_ToSku                      NVARCHAR(20)   = ''                
         ,  @c_ToPackkey                  NVARCHAR(10)   = ''
         ,  @c_ToUOM                      NVARCHAR(10)   = ''
         ,  @c_ToLottable01               NVARCHAR(18)   = ''
         ,  @c_ToLottable02               NVARCHAR(18)   = ''
         ,  @c_ToLottable03               NVARCHAR(18)   = ''
         ,  @dt_ToLottable04              DATETIME       = NULL
         ,  @dt_ToLottable05              DATETIME       = NULL
         ,  @c_ToLottable06               NVARCHAR(30)   = ''
         ,  @c_ToLottable07               NVARCHAR(30)   = ''
         ,  @c_ToLottable08               NVARCHAR(30)   = ''
         ,  @c_ToLottable09               NVARCHAR(30)   = ''
         ,  @c_ToLottable10               NVARCHAR(30)   = ''
         ,  @c_ToLottable11               NVARCHAR(30)   = ''
         ,  @c_ToLottable12               NVARCHAR(30)   = ''
         ,  @dt_ToLottable13              DATETIME       = NULL
         ,  @dt_ToLottable14              DATETIME       = NULL
         ,  @dt_ToLottable15              DATETIME       = NULL

         ,  @c_ListName                   NVARCHAR(10)   = ''
         ,  @c_SPName                     NVARCHAR(60)   = ''
         ,  @c_UDF01                      NVARCHAR(60)   = ''
         ,  @c_ToLot                      NVARCHAR(20)   = ''                       --(Wan02)
         ,  @c_ToLottableLabel            NVARCHAR(20)   = ''
         ,  @c_ToLottable01Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable02Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable03Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable04Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable05Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable06Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable07Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable08Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable09Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable10Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable11Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable12Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable13Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable14Label          NVARCHAR(20)   = ''
         ,  @c_ToLottable15Label          NVARCHAR(20)   = ''
         ,  @c_ToLottableValue            NVARCHAR(18)   = ''
         ,  @dt_ToLottableValue           DATETIME       = NULL
         ,  @c_ToLottable01Value          NVARCHAR(18)   = ''
         ,  @c_ToLottable02Value          NVARCHAR(18)   = ''
         ,  @c_ToLottable03Value          NVARCHAR(18)   = ''
         ,  @dt_ToLottable04Value         DATETIME       = NULL
         ,  @dt_ToLottable05Value         DATETIME       = NULL
         ,  @c_ToLottable06Value          NVARCHAR(30)   = ''
         ,  @c_ToLottable07Value          NVARCHAR(30)   = ''
         ,  @c_ToLottable08Value          NVARCHAR(30)   = ''
         ,  @c_ToLottable09Value          NVARCHAR(30)   = ''
         ,  @c_ToLottable10Value          NVARCHAR(30)   = ''
         ,  @c_ToLottable11Value          NVARCHAR(30)   = ''
         ,  @c_ToLottable12Value          NVARCHAR(30)   = ''
         ,  @dt_ToLottable13Value         DATETIME       = NULL
         ,  @dt_ToLottable14Value         DATETIME       = NULL
         ,  @dt_ToLottable15Value         DATETIME       = NULL
         ,  @c_ToLottable01ReturnValue    NVARCHAR(18)   = ''
         ,  @c_ToLottable02ReturnValue    NVARCHAR(18)   = ''
         ,  @c_ToLottable03ReturnValue    NVARCHAR(18)   = ''
         ,  @dt_ToLottable04ReturnValue   DATETIME       = NULL
         ,  @dt_ToLottable05ReturnValue   DATETIME       = NULL
         ,  @c_ToLottable06ReturnValue    NVARCHAR(30)   = ''
         ,  @c_ToLottable07ReturnValue    NVARCHAR(30)   = ''
         ,  @c_ToLottable08ReturnValue    NVARCHAR(30)   = ''
         ,  @c_ToLottable09ReturnValue    NVARCHAR(30)   = ''
         ,  @c_ToLottable10ReturnValue    NVARCHAR(30)   = ''
         ,  @c_ToLottable11ReturnValue    NVARCHAR(30)   = ''
         ,  @c_ToLottable12ReturnValue    NVARCHAR(30)   = ''
         ,  @dt_ToLottable13ReturnValue   DATETIME       = NULL
         ,  @dt_ToLottable14ReturnValue   DATETIME       = NULL
         ,  @dt_ToLottable15ReturnValue   DATETIME       = NULL 
         ,  @n_ToQty                      INT            = 0                        --(Wan02)
         
         ,  @c_Channel_From               NVARCHAR(20)   = ''                       --(Wan02)
         ,  @c_Channel_To                 NVARCHAR(20)   = ''                       --(Wan02)

         
         ,  @c_TableName                  NVARCHAR(50)   = 'TRANSFERDETAIL'
         ,  @c_SourceType                 NVARCHAR(50)   = 'lsp_TRF_PopulateUCC_Wrapper'

         ,  @c_SourceKey                  NVARCHAR(50)   = ''
         ,  @c_SourceType_LARule          NVARCHAR(50)   = 'TRANSFER'

         ,  @c_ChannelInventoryMgmt_From  NVARCHAR(10)   = ''                       --(Wan02)   
         ,  @c_ChannelInventoryMgmt_To    NVARCHAR(10)   = ''                       --(Wan02)
         
   SET @b_Success = 1
   SET @n_Err     = 0
               
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName        --(Wan01) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
                
      EXECUTE AS LOGIN = @c_UserName        
   END                                    --(Wan01) - END

   BEGIN TRY                              --(Wan01) - START
      SET @n_ErrGroupKey = 0

      SET @c_FromFacility = ''
      SET @c_FromStorerkey= ''
      SET @c_ToFacility = ''
      SET @c_ToStorerkey= ''
      SELECT @c_FromFacility = TH.Facility
            ,@c_ToFacility   = TH.ToFacility
            ,@c_FromStorerkey= TH.FromStorerkey
            ,@c_ToStorerkey  = TH.ToStorerkey
      FROM TRANSFER TH WITH (NOLOCK)
      WHERE TH.TransferKey = @c_TransferKey
      
      --(Wan02) - START
      SELECT @c_ChannelInventoryMgmt_From = fsgr.Authority FROM dbo.fnc_SelectGetRight (@c_FromFacility, @c_FromStorerkey,'','ChannelInventoryMgmt') AS fsgr
      SELECT @c_ChannelInventoryMgmt_To   = fsgr.Authority FROM dbo.fnc_SelectGetRight (@c_ToFacility, @c_ToStorerkey,'','ChannelInventoryMgmt') AS fsgr
      --(Wan02) - END
      
      /*-------------------------------------------------------*/
      /* BUILD TEMP TABLES & INSERT DATA - START               */
      /*-------------------------------------------------------*/
      IF OBJECT_ID('tempdb..#tUCC', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tUCC
      END

      CREATE TABLE #tUCC 
         (  UCC_RowRef  BIGINT   NOT NULL DEFAULT('')    PRIMARY KEY
         )
   
      INSERT INTO #tUCC (UCC_RowRef)
      SELECT DISTINCT T.[Value] FROM string_split (@c_UCC_RowRef_List, '|') T

      /*-------------------------------------------------------*/
      /* BUILD TEMP TABLES & INSERT DATA - END                 */
      /*-------------------------------------------------------*/
                   
      -- Get Storerconfig      
      SET @c_TransferLineNumber = '00000'  
    
      SELECT TOP 1 @c_TransferLineNumber = TD.TransferLineNumber
      FROM TRANSFERDETAIL TD WITH (NOLOCK)
      WHERE TD.Transferkey = @c_Transferkey
      ORDER BY TD.TransferLineNumber DESC

      SET @n_UCC_RowRef = 0                    
      WHILE 1 = 1
      BEGIN
         SET @c_FromSku = ''
         SET @c_FromLot = ''
         SELECT Top 1
             @n_UCC_RowRef = UCC.UCC_RowRef
            ,@c_FromSku    = UCC.Sku
            ,@c_FromLot    = UCC.Lot
            ,@n_FromQty    = UCC.Qty                                                --(Wan02)
         FROM #tUCC t
         JOIN UCC UCC WITH (NOLOCK) ON t.UCC_RowRef = UCC.UCC_RowRef
         WHERE UCC.UCC_RowRef > @n_UCC_RowRef
         AND   UCC.Qty > 0 
         ORDER BY UCC.UCC_RowRef

         IF @@ROWCOUNT = 0 OR @c_FromSku = ''
         BEGIN
            BREAK
         END

         SET @c_UOM1 = ''
         SET @c_UOM2 = ''
         SET @c_UOM3 = ''
         SET @c_UOM4 = ''
         SET @c_FromPackkey = 'STD'

         SELECT @c_FromPackkey = FS.Packkey
         FROM SKU  FS WITH (NOLOCK)
         WHERE FS.Storerkey = @c_FromStorerkey
         AND   FS.Sku = @c_FromSku

         SELECT @c_UOM1 = FP.PackUOM1
            ,   @c_UOM2 = FP.PackUOM2
            ,   @c_UOM3 = FP.PackUOM3
            ,   @c_UOM4 = FP.PackUOM4
         FROM PACK FP WITH (NOLOCK) 
         WHERE FP.Packkey = @c_FromPackkey

         SET @c_FromUOM = @c_UOM3

         SET @c_Tosku = @c_FromSku   

         BEGIN TRY
            EXEC dbo.nspg_GETSKU
               @c_Storerkey= @c_ToStorerkey
            ,  @c_sku      = @c_ToSku     OUTPUT
            ,  @b_Success  = @b_Success   OUTPUT
            ,  @n_err      = @n_err       OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_Err = 558601
            SET @c_ErrMsg = ERROR_MESSAGE()
         END CATCH
   
         IF  @b_Success <> 1
         BEGIN
            SET @n_Err = 558601
         END 
      
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing nspg_GETSKU. (lsp_TRF_PopulateUCC_Wrapper)'   
                           + '(' + @c_ErrMsg + ')' 

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_TransferKey
               ,  @c_Refkey2     = @n_UCC_RowRef
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'ERROR' 
               ,  @n_err2        = @n_err 
               ,  @c_errmsg2     = @c_errmsg 
               ,  @b_Success     = @b_Success    
               ,  @n_err         = @n_err        
               ,  @c_errmsg      = @c_errmsg    

            GOTO EXIT_SP
         END       

         SET @c_ToPackkey = 'STD'
         SELECT @c_ToLottable01Label = TS.Lottable01Label
            ,   @c_ToLottable02Label = TS.Lottable02Label
            ,   @c_ToLottable03Label = TS.Lottable03Label
            ,   @c_ToLottable04Label = TS.Lottable04Label
            ,   @c_ToLottable05Label = TS.Lottable05Label
            ,   @c_ToLottable06Label = TS.Lottable06Label
            ,   @c_ToLottable07Label = TS.Lottable07Label
            ,   @c_ToLottable08Label = TS.Lottable08Label
            ,   @c_ToLottable09Label = TS.Lottable09Label
            ,   @c_ToLottable10Label = TS.Lottable10Label
            ,   @c_ToLottable11Label = TS.Lottable11Label
            ,   @c_ToLottable12Label = TS.Lottable12Label
            ,   @c_ToLottable13Label = TS.Lottable13Label
            ,   @c_ToLottable14Label = TS.Lottable14Label
            ,   @c_ToLottable15Label = TS.Lottable15Label
            ,   @c_ToPackkey = TS.Packkey
         FROM SKU  TS WITH (NOLOCK)
         WHERE TS.Storerkey = @c_ToStorerkey
         AND   TS.Sku = @c_ToSku

         SELECT @c_UOM1 = TP.PackUOM1
            ,   @c_UOM2 = TP.PackUOM2
            ,   @c_UOM3 = TP.PackUOM3
            ,   @c_UOM4 = TP.PackUOM4
         FROM PACK TP WITH (NOLOCK) 
         WHERE TP.Packkey = @c_ToPackkey

         SET @c_ToUOM = @c_UOM3

         SET @c_FromLottable01 = ''  
         SET @c_FromLottable02 = ''  
         SET @c_FromLottable03 = ''  
         SET @dt_FromLottable04= NULL  
         SET @dt_FromLottable05= NULL  
         SET @c_FromLottable06 = ''  
         SET @c_FromLottable07 = ''  
         SET @c_FromLottable08 = ''  
         SET @c_FromLottable09 = ''  
         SET @c_FromLottable10 = ''  
         SET @c_FromLottable11 = ''  
         SET @c_FromLottable12 = ''  
         SET @dt_FromLottable13= NULL  
         SET @dt_FromLottable14= NULL  
         SET @dt_FromLottable15= NULL

         SELECT @c_FromLottable01  = LA.Lottable01
            ,   @c_FromLottable02  = LA.Lottable02
            ,   @c_FromLottable03  = LA.Lottable03
            ,   @dt_FromLottable04 = LA.Lottable04
            ,   @dt_FromLottable05 = LA.Lottable05
            ,   @c_FromLottable06  = LA.Lottable06
            ,   @c_FromLottable07  = LA.Lottable07
            ,   @c_FromLottable08  = LA.Lottable08
            ,   @c_FromLottable09  = LA.Lottable09
            ,   @c_FromLottable10  = LA.Lottable10
            ,   @c_FromLottable11  = LA.Lottable11
            ,   @c_FromLottable12  = LA.Lottable12
            ,   @dt_FromLottable13 = LA.Lottable13
            ,   @dt_FromLottable14 = LA.Lottable14
            ,   @dt_FromLottable15 = LA.Lottable15
         FROM LOTATTRIBUTE LA WITH (NOLOCK)
         WHERE LA.Lot = @c_FromLot

         SET @c_ToLottable01 = @c_FromLottable01 
         SET @c_ToLottable02 = @c_FromLottable02 
         SET @c_ToLottable03 = @c_FromLottable03 
         SET @dt_ToLottable04= @dt_FromLottable04 
         SET @dt_ToLottable05= @dt_FromLottable05 
         SET @c_ToLottable06 = @c_FromLottable06 
         SET @c_ToLottable07 = @c_FromLottable07 
         SET @c_ToLottable08 = @c_FromLottable08 
         SET @c_ToLottable09 = @c_FromLottable09 
         SET @c_ToLottable10 = @c_FromLottable10 
         SET @c_ToLottable11 = @c_FromLottable11 
         SET @c_ToLottable12 = @c_FromLottable12 
         SET @dt_ToLottable13= @dt_FromLottable13 
         SET @dt_ToLottable14= @dt_FromLottable14 
         SET @dt_ToLottable15= @dt_FromLottable15
      
         SET @c_ToLottable01Value = @c_ToLottable01
         SET @c_ToLottable02Value = @c_ToLottable02
         SET @c_ToLottable03Value = @c_ToLottable03
         SET @dt_ToLottable04Value= @dt_ToLottable04
         SET @dt_ToLottable05Value= @dt_ToLottable05 
         SET @c_ToLottable06Value = @c_ToLottable06
         SET @c_ToLottable07Value = @c_ToLottable07
         SET @c_ToLottable08Value = @c_ToLottable08
         SET @c_ToLottable09Value = @c_ToLottable09
         SET @c_ToLottable10Value = @c_ToLottable10
         SET @c_ToLottable11Value = @c_ToLottable11
         SET @c_ToLottable12Value = @c_ToLottable12
         SET @dt_ToLottable13Value= @dt_ToLottable13
         SET @dt_ToLottable14Value= @dt_ToLottable14
         SET @dt_ToLottable15Value= @dt_ToLottable15

         SET @n_Cnt = 1
         WHILE @n_Cnt <= 15
         BEGIN
            SET @c_ListName     = CASE WHEN @n_Cnt = 1  THEN 'Lottable01'
                                       WHEN @n_Cnt = 2  THEN 'Lottable02'
                                       WHEN @n_Cnt = 3  THEN 'Lottable03'
                                       WHEN @n_Cnt = 4  THEN 'Lottable04'
                                       WHEN @n_Cnt = 5  THEN 'Lottable05'
                                       WHEN @n_Cnt = 6  THEN 'Lottable06'
                                       WHEN @n_Cnt = 7  THEN 'Lottable07'
                                       WHEN @n_Cnt = 8  THEN 'Lottable08'
                                       WHEN @n_Cnt = 10 THEN 'Lottable10'
                                       WHEN @n_Cnt = 11 THEN 'Lottable11'
                                       WHEN @n_Cnt = 12 THEN 'Lottable12'
                                       WHEN @n_Cnt = 13 THEN 'Lottable13'
                                       WHEN @n_Cnt = 14 THEN 'Lottable14'
                                       WHEN @n_Cnt = 15 THEN 'Lottable15'
                                       END

            SET @c_ToLottableValue =CASE WHEN @n_Cnt = 1  THEN @c_ToLottable01
                                         WHEN @n_Cnt = 2  THEN @c_ToLottable02
                                         WHEN @n_Cnt = 3  THEN @c_ToLottable03
                                         WHEN @n_Cnt = 6  THEN @c_ToLottable06
                                         WHEN @n_Cnt = 7  THEN @c_ToLottable07
                                         WHEN @n_Cnt = 8  THEN @c_ToLottable08
                                         WHEN @n_Cnt = 10 THEN @c_ToLottable10
                                         WHEN @n_Cnt = 11 THEN @c_ToLottable11
                                         WHEN @n_Cnt = 12 THEN @c_ToLottable12
                                         ELSE ''
                                         END
            SET @dt_ToLottableValue=CASE  WHEN @n_Cnt = 4 THEN @dt_ToLottable04
                                          WHEN @n_Cnt = 5  THEN @dt_ToLottable05
                                          WHEN @n_Cnt = 13 THEN @dt_ToLottable13
                                          WHEN @n_Cnt = 14 THEN @dt_ToLottable14
                                          WHEN @n_Cnt = 15 THEN @dt_ToLottable15
                                          ELSE NULL
                                          END

            SET @c_ToLottableLabel = CASE WHEN @n_Cnt = 1  THEN @c_ToLottable01Label
                                          WHEN @n_Cnt = 2  THEN @c_ToLottable02Label
                                          WHEN @n_Cnt = 3  THEN @c_ToLottable03Label
                                          WHEN @n_Cnt = 4  THEN @c_ToLottable04Label
                                          WHEN @n_Cnt = 5  THEN @c_ToLottable05Label
                                          WHEN @n_Cnt = 6  THEN @c_ToLottable06Label
                                          WHEN @n_Cnt = 7  THEN @c_ToLottable07Label
                                          WHEN @n_Cnt = 8  THEN @c_ToLottable08Label
                                          WHEN @n_Cnt = 10 THEN @c_ToLottable10Label
                                          WHEN @n_Cnt = 11 THEN @c_ToLottable11Label
                                          WHEN @n_Cnt = 12 THEN @c_ToLottable12Label
                                          WHEN @n_Cnt = 13 THEN @c_ToLottable13Label
                                          WHEN @n_Cnt = 14 THEN @c_ToLottable14Label
                                          WHEN @n_Cnt = 15 THEN @c_ToLottable15Label
                                          END
            SET @c_SPName = ''
            SET @c_UDF01 = ''
            IF (@n_Cnt IN (1,2,3,6,7,8,9,10,11,12) AND @c_ToLottableValue = '') OR
               (@n_Cnt IN (4,5,13,14,15) AND (@dt_ToLottableValue = '1900-01-01' OR @dt_ToLottableValue IS NULL))
            BEGIN
               SELECT TOP 1 
                        @c_SPName = ISNULL(CL.Long,'')  
                     ,  @c_UDF01  = ISNULL(CL.UDF01,'')      
               FROM CODELKUP CL WITH (NOLOCK)
               WHERE CL.ListName = @c_ListName
               AND CL.Code = @c_ToLottableLabel
               AND CL.Short IN ('PRE', 'BOTH')  
               --AND ((CL.Storerkey = @c_ToStorerkey AND @c_ToStorerkey <> '') OR (CL.Storerkey = ''))
               AND  CL.Storerkey IN ( @c_ToStorerkey, '')
               ORDER BY CL.Storerkey DESC    
            END  

            IF  @c_SPName <> '' AND EXISTS (SELECT 1 FROM SYS.Objects WHERE Name = @c_SPName AND [Type] = 'p')
            BEGIN
               SET @c_SourceKey = @c_TransferKey + @c_TransferLineNumber

               BEGIN TRY
                  SET @b_Success = 1
                  EXEC dbo.ispLottableRule_Wrapper 
                        @c_SPName            = @c_SPName
                     ,  @c_Listname          = @c_Listname
                     ,  @c_Storerkey         = @c_ToStorerkey
                     ,  @c_Sku               = @c_ToSku
                     ,  @c_LottableLabel     = @c_ToLottableLabel
                     ,  @c_Lottable01Value   = @c_ToLottable01Value 
                     ,  @c_Lottable02Value   = @c_ToLottable02Value 
                     ,  @c_Lottable03Value   = @c_ToLottable03Value 
                     ,  @dt_Lottable04Value  = @dt_ToLottable04Value
                     ,  @dt_Lottable05Value  = @dt_ToLottable05Value
                     ,  @c_Lottable06Value   = @c_ToLottable06Value 
                     ,  @c_Lottable07Value   = @c_ToLottable07Value 
                     ,  @c_Lottable08Value   = @c_ToLottable08Value 
                     ,  @c_Lottable09Value   = @c_ToLottable09Value 
                     ,  @c_Lottable10Value   = @c_ToLottable10Value 
                     ,  @c_Lottable11Value   = @c_ToLottable11Value 
                     ,  @c_Lottable12Value   = @c_ToLottable12Value 
                     ,  @dt_Lottable13Value  = @dt_ToLottable13Value
                     ,  @dt_Lottable14Value  = @dt_ToLottable14Value
                     ,  @dt_Lottable15Value  = @dt_ToLottable15Value
                     ,  @c_Lottable01        = @c_ToLottable01ReturnValue  OUTPUT
                     ,  @c_Lottable02        = @c_ToLottable02ReturnValue  OUTPUT
                     ,  @c_Lottable03        = @c_ToLottable03ReturnValue  OUTPUT
                     ,  @dt_Lottable04       = @dt_ToLottable04ReturnValue OUTPUT
                     ,  @dt_Lottable05       = @dt_ToLottable05ReturnValue OUTPUT
                     ,  @c_Lottable06        = @c_ToLottable06ReturnValue  OUTPUT
                     ,  @c_Lottable07        = @c_ToLottable07ReturnValue  OUTPUT
                     ,  @c_Lottable08        = @c_ToLottable08ReturnValue  OUTPUT
                     ,  @c_Lottable09        = @c_ToLottable09ReturnValue  OUTPUT
                     ,  @c_Lottable10        = @c_ToLottable10ReturnValue  OUTPUT
                     ,  @c_Lottable11        = @c_ToLottable11ReturnValue  OUTPUT
                     ,  @c_Lottable12        = @c_ToLottable12ReturnValue  OUTPUT
                     ,  @dt_Lottable13       = @dt_ToLottable13ReturnValue OUTPUT
                     ,  @dt_Lottable14       = @dt_ToLottable14ReturnValue OUTPUT
                     ,  @dt_Lottable15       = @dt_ToLottable15ReturnValue OUTPUT
                     ,  @b_Success           = @b_Success                  OUTPUT  
                     ,  @n_err               = @n_err                      OUTPUT                                                                                                             
                     ,  @c_ErrMsg            = @c_ErrMsg                   OUTPUT 
                     ,  @c_SourceKey         = @c_SourceKey                  
                     ,  @c_SourceType        = @c_SourceType_LARule 
               END TRY
               BEGIN CATCH
                  SET @n_Err = 558602
                  SET @c_ErrMsg = ERROR_MESSAGE()
               END CATCH

               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing ispLottableRule_Wrapper. (lsp_TRF_PopulateUCC_Wrapper)'   
                                 + '(' + @c_ErrMsg + ')' 

                  EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_TransferKey
                     ,  @c_Refkey2     = @n_UCC_RowRef
                     ,  @c_Refkey3     = ''
                     ,  @c_WriteType   = 'ERROR' 
                     ,  @n_err2        = @n_err 
                     ,  @c_errmsg2     = @c_errmsg 
                     ,  @b_Success     = @b_Success    
                     ,  @n_err         = @n_err        
                     ,  @c_errmsg      = @c_errmsg    

                  GOTO EXIT_SP
               END

               IF @n_Cnt = 1  
                  SET @c_ToLottable01 = @c_ToLottable01ReturnValue
               IF @n_Cnt = 2  
                  SET @c_ToLottable02 = @c_ToLottable02ReturnValue
               IF @n_Cnt = 3 
                  SET @c_ToLottable03 = @c_ToLottable03ReturnValue
               IF @n_Cnt = 4  
                  SET @dt_ToLottable04= @dt_ToLottable04ReturnValue
               IF @n_Cnt = 5  
                  SET @dt_ToLottable05= @dt_ToLottable05ReturnValue
               IF @n_Cnt = 6  
                  SET @c_ToLottable06 = @c_ToLottable06ReturnValue
               IF @n_Cnt = 7  
                  SET @c_ToLottable07 = @c_ToLottable07ReturnValue
               IF @n_Cnt = 8 
                  SET @c_ToLottable08 = @c_ToLottable08ReturnValue
               IF @n_Cnt = 9 
                  SET @c_ToLottable09 = @c_ToLottable09ReturnValue
               IF @n_Cnt = 10 
                  SET @c_ToLottable10 = @c_ToLottable10ReturnValue
               IF @n_Cnt = 11  
                  SET @c_ToLottable11 = @c_ToLottable11ReturnValue
               IF @n_Cnt = 12  
                  SET @c_ToLottable12 = @c_ToLottable12ReturnValue
               IF @n_Cnt = 13  
                  SET @dt_ToLottable13= @dt_ToLottable13ReturnValue
               IF @n_Cnt = 14  
                  SET @dt_ToLottable14= @dt_ToLottable14ReturnValue
               IF @n_Cnt = 15  
                  SET @dt_ToLottable15= @dt_ToLottable15ReturnValue
            END
            
            SET @n_Cnt = @n_Cnt + 1 
         END
   
         IF @c_ChannelInventoryMgmt_From = '1'                                      --(Wan02) - START
         BEGIN
            SELECT @c_Channel_From = fsci.Channel
            FROM dbo.fnc_SelectChannelInv(@c_FromFacility, @c_FromStorerkey, @c_FromSku, @c_Channel_From
                                         ,@c_FromLot, @n_FromQty
                                          ) AS fsci
         END
         
         IF @c_ChannelInventoryMgmt_To = '1'
         BEGIN
            EXEC dbo.nsp_LotLookup
                  @c_StorerKey  = @c_ToStorerKey                 
              ,   @c_Sku        = @c_ToSku                       
              ,   @c_Lottable01 = @c_ToLottable01
              ,   @c_Lottable02 = @c_ToLottable02
              ,   @c_Lottable03 = @c_ToLottable03
              ,   @c_Lottable04 = @dt_ToLottable04
              ,   @c_Lottable05 = @dt_ToLottable05
              ,   @c_Lottable06 = @c_ToLottable06
              ,   @c_Lottable07 = @c_ToLottable07
              ,   @c_Lottable08 = @c_ToLottable08
              ,   @c_Lottable09 = @c_ToLottable09
              ,   @c_Lottable10 = @c_ToLottable10
              ,   @c_Lottable11 = @c_ToLottable11
              ,   @c_Lottable12 = @c_ToLottable12
              ,   @c_Lottable13 = @dt_ToLottable13
              ,   @c_Lottable14 = @dt_ToLottable14
              ,   @c_Lottable15 = @dt_ToLottable15
              ,   @c_Lot        = @c_ToLot         OUTPUT
              ,   @b_Success    = @b_Success       OUTPUT
              ,   @n_err        = @n_err           OUTPUT
              ,   @c_errmsg     = @c_errmsg        OUTPUT
              ,   @b_resultset  = 0    
                                
            SET @n_ToQty = @n_FromQty
            SELECT @c_Channel_To = fsci.Channel
            FROM dbo.fnc_SelectChannelInv(@c_ToFacility, @c_ToStorerkey, @c_ToSku, @c_Channel_To
                                         ,@c_ToLot, @n_ToQty
                                         ) AS fsci
            
            IF @c_Channel_To = ''
            BEGIN
               SELECT TOP 1 @c_Channel_To = c.Code
               FROM dbo.CODELKUP AS c WITH (NOLOCK)
               WHERE c.ListName = 'Channel'
               AND c.Storerkey IN ('', @c_ToStorerkey)
               ORDER BY CASE WHEN c.Storerkey = @c_ToStorerkey THEN 1
                             ELSE 9
                             END
                     ,  c.Code               
            END
         END                                                                        --(Wan02) - END   
                
         SET @c_TransferLineNumber = RIGHT( '00000' + CONVERT(NVARCHAR(5), CONVERT(INT, @c_TransferLineNumber) + 1), 5 )
         BEGIN TRY
            INSERT INTO TRANSFERDETAIL
                  (  TransferKey
                  ,  TransferLineNumber
                  ,  FromStorerkey  
                  ,  FromSku
                  ,  FromPackkey  
                  ,  FromUOM
                  ,  FromQty
                  ,  FromLot
                  ,  FromLoc
                  ,  FromID
                  ,  Lottable01
                  ,  Lottable02
                  ,  Lottable03
                  ,  Lottable04
                  ,  Lottable05
                  ,  Lottable06
                  ,  Lottable07
                  ,  Lottable08
                  ,  Lottable09
                  ,  Lottable10
                  ,  Lottable11
                  ,  Lottable12
                  ,  Lottable13
                  ,  Lottable14
                  ,  Lottable15
                  ,  ToStorerkey  
                  ,  ToSku
                  ,  ToPackkey  
                  ,  ToUOM
                  ,  ToQty
                  ,  ToLot
                  ,  ToLoc
                  ,  ToID
                  ,  ToLottable01
                  ,  ToLottable02
                  ,  ToLottable03
                  ,  ToLottable04
                  ,  ToLottable05
                  ,  ToLottable06
                  ,  ToLottable07
                  ,  ToLottable08
                  ,  ToLottable09
                  ,  ToLottable10
                  ,  ToLottable11
                  ,  ToLottable12
                  ,  ToLottable13
                  ,  ToLottable14
                  ,  ToLottable15
                  ,  UserDefine01 
                  ,  UserDefine02 
                  ,  FromChannel                                                    --(Wan02)
                  ,  ToChannel                                                      --(Wan02)
                  )
            SELECT   @c_TransferKey
                  ,  @c_TransferLineNumber
                  ,  @c_FromStorerkey  
                  ,  @c_FromSku
                  ,  @c_FromPackkey  
                  ,  @c_FromUOM
                  ,  UCC.Qty
                  ,  UCC.Lot
                  ,  UCC.Loc
                  ,  UCC.ID
                  ,  @c_FromLottable01
                  ,  @c_FromLottable02
                  ,  @c_FromLottable03
                  ,  @dt_FromLottable04
                  ,  @dt_FromLottable05
                  ,  @c_FromLottable06
                  ,  @c_FromLottable07
                  ,  @c_FromLottable08
                  ,  @c_FromLottable09
                  ,  @c_FromLottable10
                  ,  @c_FromLottable11
                  ,  @c_FromLottable12
                  ,  @dt_FromLottable13
                  ,  @dt_FromLottable14
                  ,  @dt_FromLottable15
                  ,  @c_ToStorerkey  
                  ,  @c_ToSku
                  ,  @c_ToPackkey  
                  ,  @c_ToUOM
                  ,  UCC.Qty
                  , ''
                  ,  UCC.Loc
                  ,  UCC.ID
                  ,  @c_ToLottable01
                  ,  @c_ToLottable02
                  ,  @c_ToLottable03
                  ,  @dt_ToLottable04
                  ,  @dt_ToLottable05
                  ,  @c_ToLottable06
                  ,  @c_ToLottable07
                  ,  @c_ToLottable08
                  ,  @c_ToLottable09
                  ,  @c_ToLottable10
                  ,  @c_ToLottable11
                  ,  @c_ToLottable12
                  ,  @dt_ToLottable13
                  ,  @dt_ToLottable14
                  ,  @dt_ToLottable15
                  ,  UCC.UCCNo
                  ,  UCC.UCCNo
                  ,  @c_Channel_From                                                --(Wan02)
                  ,  @c_Channel_To                                                  --(Wan02)  
            FROM UCC WITH (NOLOCK)
            WHERE UCC_RowRef = @n_UCC_RowRef
         END TRY
         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_Err = 558603
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': INSERT TRANSFERDETAIL Table Fail. (lsp_TRF_PopulateUCC_Wrapper)'   
                           + '(' + @c_ErrMsg + ')' 

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_TransferKey
               ,  @c_Refkey2     = @n_UCC_RowRef
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'ERROR' 
               ,  @n_err2        = @n_err 
               ,  @c_errmsg2     = @c_errmsg 
               ,  @b_Success     = @b_Success    
               ,  @n_err         = @n_err        
               ,  @c_errmsg      = @c_errmsg    

            IF (XACT_STATE()) = -1  
            BEGIN
               ROLLBACK TRAN

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
            END  
            GOTO EXIT_SP
         END CATCH
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg   = ERROR_MESSAGE() 
      GOTO EXIT_SP   
   END CATCH                              --(Wan01) - END 
EXIT_SP:
   IF (XACT_STATE()) = -1                 --(Wan02) - START
   BEGIN
      SET @n_Continue = 3 
      ROLLBACK TRAN
   END                                    --(Wan02) - END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_TRF_PopulateUCC_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END  
         
   REVERT
END

GO