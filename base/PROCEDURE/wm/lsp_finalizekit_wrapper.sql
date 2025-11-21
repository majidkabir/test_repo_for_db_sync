SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: WM.lsp_FinalizeKit_Wrapper                          */  
/* Creation Date: 09-OCT-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-1281 - Stored Procedures for Kitting functionalities    */
/*        :                                                              */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.2                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2020-08-26  Wan01    1.1   LFWM-2153 - UAT CNKitting Module shows     */
/*                            lottable is required                       */
/* 2020-12-10  Wan02    1.1   Add Big Outer Begin Try..End Try to enable */
/*                            Revert when SP Raise error                 */
/*                      1.1   Fixed Uncommitable Transaction             */
/* 2021-01-15  Wan03    1.2   Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_FinalizeKit_Wrapper]  
   @c_KITKey               NVARCHAR(10)
,  @b_Success              INT          = 1  OUTPUT   
,  @n_Err                  INT          = 0  OUTPUT
,  @c_Errmsg               NVARCHAR(255)= '' OUTPUT
,  @n_WarningNo            INT          = 0  OUTPUT
,  @c_ProceedWithWarning   CHAR(1)      = 'N' 
,  @c_UserName             NVARCHAR(128)= ''
,  @n_ErrGroupKey          INT = 0           OUTPUT
AS  
BEGIN
   SET NOCOUNT ON                   -- (Wan02) - START                                     
   SET QUOTED_IDENTIFIER OFF        
   SET ANSI_NULLS OFF               
   SET CONCAT_NULL_YIELDS_NULL OFF	-- (Wan02) - END

   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT
         , @n_CurrTrnCnt         INT = 0  

   DECLARE @c_TableName          NVARCHAR(50)   = 'KIT'
         , @c_SourceType         NVARCHAR(50)   = 'lsp_FinalizeKit_Wrapper'
      
         , @c_Facility           NVARCHAR(5)    = ''
         , @c_Storerkey          NVARCHAR(15)   = ''
         , @c_ParentFromSku      NVARCHAR(20)   = ''
         , @c_ParentToSku        NVARCHAR(20)   = ''
         , @c_LocFacility        NVARCHAR(5)    = ''
         , @c_kitLineNumber      NVARCHAR(20)   = ''
         , @c_Sku                NVARCHAR(20)   = ''
         , @c_Lot                NVARCHAR(10)   = ''
         , @c_Loc                NVARCHAR(10)   = ''
         , @c_ID                 NVARCHAR(20)   = ''
         , @n_TotalKitFromQty    INT            = 0
         , @c_Lottable01         NVARCHAR(18)   = ''         
         , @c_Lottable02         NVARCHAR(18)   = ''         
         , @c_Lottable03         NVARCHAR(18)   = ''         
         , @c_Lottable04         NVARCHAR(30)   = ''                   
         , @c_Lottable05         NVARCHAR(30)   = ''               
         , @c_Lottable06         NVARCHAR(30)   = ''         
         , @c_Lottable07         NVARCHAR(30)   = ''         
         , @c_Lottable08         NVARCHAR(30)   = ''         
         , @c_Lottable09         NVARCHAR(30)   = ''         
         , @c_Lottable10         NVARCHAR(30)   = ''         
         , @c_Lottable11         NVARCHAR(30)   = ''         
         , @c_Lottable12         NVARCHAR(30)   = ''         
         , @c_Lottable13         NVARCHAR(30)   = ''                  
         , @c_Lottable14         NVARCHAR(30)   = ''              
         , @c_Lottable15         NVARCHAR(30)   = ''             
         , @n_KitToQty           INT            = 0
         , @n_TotalKitToQty      INT            = 0
         
         , @n_No                 INT            = 0
         , @c_No                 NVARCHAR(2)    = ''
         , @c_Lottable           NVARCHAR(30)   = ''
         , @c_LottableLabel      NVARCHAR(20)   = ''
         , @c_LottableDesc       NVARCHAR(60)   = ''
         , @c_Lottable01Label    NVARCHAR(20)   = ''   
         , @c_Lottable02Label    NVARCHAR(20)   = ''   
         , @c_Lottable03Label    NVARCHAR(20)   = ''   
         , @c_Lottable04Label    NVARCHAR(20)   = ''   
         , @c_Lottable05Label    NVARCHAR(20)   = ''   
         , @c_Lottable06Label    NVARCHAR(20)   = ''   
         , @c_Lottable07Label    NVARCHAR(20)   = ''   
         , @c_Lottable08Label    NVARCHAR(20)   = ''   
         , @c_Lottable09Label    NVARCHAR(20)   = ''   
         , @c_Lottable10Label    NVARCHAR(20)   = ''   
         , @c_Lottable11Label    NVARCHAR(20)   = ''   
         , @c_Lottable12Label    NVARCHAR(20)   = ''   
         , @c_Lottable13Label    NVARCHAR(20)   = ''   
         , @c_Lottable14Label    NVARCHAR(20)   = ''   
         , @c_Lottable15Label    NVARCHAR(20)   = ''   


         , @n_KitFrom            INT            = 0
         , @n_KitTo              INT            = 0
         , @n_QtyInvAvail        INT            = 0
         , @n_Count              INT            = 0
         , @n_KitFromQty         INT            = 0
         , @n_EmptyToLoc         INT            = 0
         , @n_BOM                INT            = 0
         , @n_UnMatchQtySet      INT            = 0


         , @CUR_KITFR            CURSOR
         , @CUR_KITTO            CURSOR

         , @CUR_UPDKITTO         CURSOR   --(Wan01)

   --(Wan01) - START
   DECLARE
           @b_UpdateLot03        BIT            = 0
         , @b_UpdateLot05        BIT            = 0

   DECLARE @t_UpdateKITTo  TABLE
      (
         RowRef         INT IDENTITY(1,1)  PRIMARY KEY
      ,  KitLineNumber  NVARCHAR(5)       NOT NULL DEFAULT('')
      ,  Lot03_Rec_Date INT               NOT NULL DEFAULT(0)
      ,  Lot05_Rec_Date INT               NOT NULL DEFAULT(0)
      ,  Lottable03     NVARCHAR(10)      NOT NULL DEFAULT('')
      ,  Lottable05     NVARCHAR(10)      NOT NULL DEFAULT('')
      )
   --(Wan01) - END

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_ErrGroupKey = 0

   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName       --(Wan03) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] 
               @c_UserName = @c_UserName  OUTPUT
            ,  @n_Err      = @n_Err       OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
      
      EXECUTE AS LOGIN = @c_UserName
   END                                   --(Wan03) - END

   BEGIN TRY         --(Wan02) - START
      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo  < 1
      BEGIN
         -------------------
         -- Validation Start
         -------------------
         SET @c_Facility = ''
         SELECT @c_Facility = RTRIM(K.Facility)
               ,@c_Storerkey= K.Storerkey
         FROM KIT K  WITH (NOLOCK)
         WHERE K.KitKey = @c_KitKey

         SET @n_KitFrom         = 0 
         SET @n_TotalKitFromQty = 0
         SET @c_ParentFromSku   = ''
         SET @CUR_KITFR = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT KD.KITLineNumber
               ,Sku = RTRIM(KD.Sku)
               ,Lot = RTRIM(KD.Lot)
               ,Loc = RTRIM(KD.Loc)
               ,ID  = RTRIM(KD.ID)
               ,KitFromQty =  KD.Qty
         FROM KITDETAIL KD WITH (NOLOCK)
         WHERE KD.KitKey = @c_KitKey
         AND KD.[Type] = 'F'
         ORDER BY KD.KITLineNumber

         OPEN @CUR_KITFR
   
         FETCH NEXT FROM @CUR_KITFR INTO  @c_KITLineNumber   
                                       ,  @c_Sku 
                                       ,  @c_Lot  
                                       ,  @c_Loc 
                                       ,  @c_ID          
                                       ,  @n_KitFromQty  
                                    
         WHILE @@FETCH_STATUS <> -1
         BEGIN   
            SET @b_UpdateLot03 = 0   --(Wan01)
            SET @b_UpdateLot05 = 0   --(Wan01)
                                          
            SET @n_KitFrom = @n_KitFrom + 1

            IF @n_KitFrom = 1
            BEGIN
               SET @c_ParentFromSku = @c_Sku
            END 

            IF @n_KitFromQty <= 0
            BEGIN
               SET @n_continue = 3   
               SET @n_err = 554501
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                             + ': Zero QtyCompleted found at Kit From. (lsp_FinalizeKit_Wrapper)'

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_Kitkey
                  ,  @c_Refkey2     = @c_KITLineNumber
                  ,  @c_Refkey3     = ''
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   OUTPUT
                  ,  @n_err         = @n_err       OUTPUT
                  ,  @c_errmsg      = @c_errmsg    OUTPUT
            END

            SET @n_Count = 0
            SET @n_QtyInvAvail = 0

            SELECT @n_Count = COUNT(1)
                  ,@n_QtyInvAvail = ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked),0)
            FROM LOTxLOCxID LLI WITH (NOLOCK) 
            WHERE LLI.Lot = @c_Lot
            AND   LLI.Loc = @c_Loc
            AND   LLI.ID  = @c_ID

            IF @n_Count = 0
            BEGIN
               SET @n_continue = 3   
               SET @n_err = 554502
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                             + ': Inventory for Lot: ' + @c_Lot + ', Loc: ' + @c_Loc + ', ID: ' + @c_ID + ' not found. (lsp_FinalizeKit_Wrapper)'
                             + ' |' +  @c_Lot + '|' + @c_Loc + '|' + @c_ID

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_Kitkey
                  ,  @c_Refkey2     = @c_KITLineNumber
                  ,  @c_Refkey3     = ''
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   OUTPUT
                  ,  @n_err         = @n_err       OUTPUT
                  ,  @c_errmsg      = @c_errmsg    OUTPUT
            END

            IF @n_Count > 0 AND @n_QtyInvAvail - @n_KitFromQty < 0
            BEGIN
               SET @n_continue = 3   
               SET @n_err = 554503
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                             + ': Kit from qty is less than inventory available qty: '+ CONVERT(NVARCHAR(10), @n_QtyInvAvail) 
                             + '. Please Check Inventory Balance'
                             + '. (lsp_FinalizeKit_Wrapper)'
                             + ' |' +  CONVERT(NVARCHAR(10), @n_QtyInvAvail) 

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_Kitkey
                  ,  @c_Refkey2     = @c_KITLineNumber
                  ,  @c_Refkey3     = ''
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   OUTPUT
                  ,  @n_err         = @n_err       OUTPUT
                  ,  @c_errmsg      = @c_errmsg    OUTPUT
            END

            SET @n_TotalKitFromQty = @n_TotalKitFromQty + @n_KitFromQty

            FETCH NEXT FROM @CUR_KITFR INTO  @c_KITLineNumber   
                                          ,  @c_Sku 
                                          ,  @c_Lot  
                                          ,  @c_Loc 
                                          ,  @c_ID          
                                          ,  @n_KitFromQty  
         END

         IF @n_KitFrom = 0 
         BEGIN
            SET @n_continue = 3   
            SET @n_err = 554504
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                          + ': Kitting from not found. (lsp_FinalizeKit_Wrapper)'

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey = @n_ErrGroupKey OUTPUT
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_Kitkey
               ,  @c_Refkey2     = ''
               ,  @c_Refkey3     = ''
               ,  @n_err2        = @n_err
               ,  @c_errmsg2     = @c_errmsg
               ,  @b_Success     = @b_Success   OUTPUT
               ,  @n_err         = @n_err       OUTPUT
               ,  @c_errmsg      = @c_errmsg    OUTPUT
         END


         SET @n_KitTo = 0
         SET @n_TotalKitToQty  = 0
         SET @c_ParentToSku = ''
         SET @CUR_KITTO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT L.Facility
               ,KD.KITLineNumber
               ,Sku = RTRIM(KD.Sku)
               ,Loc = RTRIM(KD.Loc)
               ,Lottable01  =  ISNULL(RTRIM(KD.lottable01),'')
               ,Lottable02  =  ISNULL(RTRIM(KD.lottable02),'')
               ,Lottable03  =  ISNULL(RTRIM(KD.lottable03),'')
               ,Lottable04  =  CONVERT( NVARCHAR(30), ISNULL(KD.lottable04, '1900-01-01'), 120)
               ,Lottable05  =  CONVERT( NVARCHAR(30), ISNULL(KD.lottable05, '1900-01-01'), 120)
               ,Lottable06  =  ISNULL(RTRIM(KD.lottable06),'')
               ,Lottable07  =  ISNULL(RTRIM(KD.lottable07),'')
               ,Lottable08  =  ISNULL(RTRIM(KD.lottable08),'')
               ,Lottable09  =  ISNULL(RTRIM(KD.lottable09),'')
               ,Lottable10  =  ISNULL(RTRIM(KD.lottable10),'')
               ,Lottable11  =  ISNULL(RTRIM(KD.lottable11),'')
               ,Lottable12  =  ISNULL(RTRIM(KD.lottable12),'')
               ,Lottable13  =  CONVERT( NVARCHAR(30), ISNULL(KD.lottable13, '1900-01-01'), 120)
               ,Lottable14  =  CONVERT( NVARCHAR(30), ISNULL(KD.lottable14, '1900-01-01'), 120)
               ,Lottable15  =  CONVERT( NVARCHAR(30), ISNULL(KD.lottable15, '1900-01-01'), 120)
               ,KitToQty    =  KD.Qty
         FROM KITDETAIL KD WITH (NOLOCK)
         LEFT JOIN LOC L WITH (NOLOCK) ON (KD.Loc = L.Loc)
         WHERE KD.KitKey = @c_KitKey
         AND KD.[Type] = 'T'
         ORDER BY KD.KITLineNumber

         OPEN @CUR_KITTO
         FETCH NEXT FROM @CUR_KITTO INTO  @c_LocFacility 
                                       ,  @c_KITLineNumber   
                                       ,  @c_Sku 
                                       ,  @c_Loc           
                                       ,  @c_Lottable01     
                                       ,  @c_Lottable02     
                                       ,  @c_Lottable03     
                                       ,  @c_Lottable04     
                                       ,  @c_Lottable05     
                                       ,  @c_Lottable06     
                                       ,  @c_Lottable07     
                                       ,  @c_Lottable08     
                                       ,  @c_Lottable09     
                                       ,  @c_Lottable10     
                                       ,  @c_Lottable11     
                                       ,  @c_Lottable12     
                                       ,  @c_Lottable13     
                                       ,  @c_Lottable14     
                                       ,  @c_Lottable15     
                                       ,  @n_KitToQty       

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @n_KitTo = @n_KitTo + 1

            IF @n_KitTo = 1
            BEGIN
               SET @c_ParentToSku = @c_Sku
            END

            IF @n_KitToQty <= 0
            BEGIN
               SET @n_continue = 3   
               SET @n_err = 554505
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                             + ': Zero QtyCompleted found at Kit To. (lsp_FinalizeKit_Wrapper)'

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_Kitkey
                  ,  @c_Refkey2     = @c_KITLineNumber
                  ,  @c_Refkey3     = ''
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   OUTPUT
                  ,  @n_err         = @n_err       OUTPUT
                  ,  @c_errmsg      = @c_errmsg    OUTPUT
            END


            IF @c_Loc = ''
            BEGIN
               SET @n_continue = 3   
               SET @n_err = 554506
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                             + ': Empty Kit To Loc. (lsp_FinalizeKit_Wrapper)'

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_Kitkey
                  ,  @c_Refkey2     = @c_KITLineNumber
                  ,  @c_Refkey3     = ''
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   OUTPUT
                  ,  @n_err         = @n_err       OUTPUT
                  ,  @c_errmsg      = @c_errmsg    OUTPUT
            END
      
            IF @c_LocFacility <> @c_Facility 
            BEGIN
               SET @n_continue = 3   
               SET @n_err = 554507
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                              + ': Invalid Kit To Loc: ' + @c_Loc + '. It does not belong to KIT Facility: ' + @c_Facility + '. (lsp_FinalizeKit_Wrapper)'
                              + ' |' + @c_Loc + '|' + @c_Facility

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey = @n_ErrGroupKey OUTPUT
                   , @c_TableName   = @c_TableName
                   , @c_SourceType  = @c_SourceType
                   , @c_Refkey1     = @c_Kitkey
                   , @c_Refkey2     = @c_KITLineNumber
                   , @c_Refkey3     = ''
                   , @n_err2        = @n_err
                   , @c_errmsg2     = @c_errmsg
                   , @b_Success     = @b_Success   OUTPUT
                   , @n_err         = @n_err       OUTPUT
                   , @c_errmsg      = @c_errmsg    OUTPUT
            END

            SET @c_Lottable01Label  = ''                 
            SET @c_Lottable02Label  = ''                 
            SET @c_Lottable03Label  = ''                 
            SET @c_Lottable04Label  = ''                 
            SET @c_Lottable05Label  = ''                 
            SET @c_Lottable06Label  = ''                 
            SET @c_Lottable07Label  = ''                 
            SET @c_Lottable08Label  = ''                 
            SET @c_Lottable09Label  = ''                 
            SET @c_Lottable10Label  = ''                 
            SET @c_Lottable11Label  = ''                 
            SET @c_Lottable12Label  = ''                 
            SET @c_Lottable13Label  = ''                 
            SET @c_Lottable14Label  = ''                 
            SET @c_Lottable15Label  = ''                 

            SELECT @c_Lottable01Label = ISNULL(RTRIM(SKU.Lottable01Label),'')   
               ,   @c_Lottable02Label = ISNULL(RTRIM(SKU.Lottable02Label),'')   
               ,   @c_Lottable03Label = ISNULL(RTRIM(SKU.Lottable03Label),'')   
               ,   @c_Lottable04Label = ISNULL(RTRIM(SKU.Lottable04Label),'')   
               ,   @c_Lottable05Label = ISNULL(RTRIM(SKU.Lottable05Label),'')   
               ,   @c_Lottable06Label = ISNULL(RTRIM(SKU.Lottable06Label),'')   
               ,   @c_Lottable07Label = ISNULL(RTRIM(SKU.Lottable07Label),'')   
               ,   @c_Lottable08Label = ISNULL(RTRIM(SKU.Lottable08Label),'')   
               ,   @c_Lottable09Label = ISNULL(RTRIM(SKU.Lottable09Label),'')   
               ,   @c_Lottable10Label = ISNULL(RTRIM(SKU.Lottable10Label),'')   
               ,   @c_Lottable11Label = ISNULL(RTRIM(SKU.Lottable11Label),'')   
               ,   @c_Lottable12Label = ISNULL(RTRIM(SKU.Lottable12Label),'')   
               ,   @c_Lottable13Label = ISNULL(RTRIM(SKU.Lottable13Label),'')   
               ,   @c_Lottable14Label = ISNULL(RTRIM(SKU.Lottable14Label),'')   
               ,   @c_Lottable15Label = ISNULL(RTRIM(SKU.Lottable15Label),'')   
            FROM SKU WITH (NOLOCK)
            WHERE SKU.Storerkey = @c_Storerkey   
            AND   SKU.Sku = @c_Sku


            IF  @c_Lottable04 = '1900-01-01 00:00:00'
            BEGIN
               SET @c_Lottable04 = ''
            END

            IF  @c_Lottable05 = '1900-01-01 00:00:00'
            BEGIN
               SET @c_Lottable05 = ''
            END

            IF  @c_Lottable13 = '1900-01-01 00:00:00'
            BEGIN
               SET @c_Lottable13 = ''
            END

            IF  @c_Lottable14 = '1900-01-01 00:00:00'
            BEGIN
               SET @c_Lottable14 = ''
            END

            IF  @c_Lottable15 = '1900-01-01 00:00:00'
            BEGIN
               SET @c_Lottable15 = ''
            END

            IF @c_Lottable03Label = 'RCP_DATE' AND @c_Lottable03 = ''
            BEGIN
               SET @c_Lottable03 = CONVERT( NVARCHAR(10), GETDATE(), 120 )
               SET @b_UpdateLot03= 1
            END

            IF @c_Lottable05Label = 'RCP_DATE' AND @c_Lottable05 = ''
            BEGIN
               SET @c_Lottable05 = CONVERT( NVARCHAR(10), GETDATE(), 120 )
               SET @b_UpdateLot03= 1
            END

            SET @n_No = 1
            WHILE @n_No <= 15
            BEGIN

               SET @c_No = RIGHT('00' + CONVERT(NVARCHAR(2), @n_No), 2)
               SET @c_Lottable = ''
               SET @c_Lottablelabel = ''   
                    
               SET @c_Lottable = CASE @n_No WHEN 1  THEN @c_Lottable01
                                            WHEN 2  THEN @c_Lottable02
                                            WHEN 3  THEN @c_Lottable03
                                            WHEN 4  THEN @c_Lottable04
                                            WHEN 5  THEN @c_Lottable05
                                            WHEN 6  THEN @c_Lottable06
                                            WHEN 7  THEN @c_Lottable07
                                            WHEN 8  THEN @c_Lottable08
                                            WHEN 9  THEN @c_Lottable09
                                            WHEN 10 THEN @c_Lottable10
                                            WHEN 11 THEN @c_Lottable11
                                            WHEN 12 THEN @c_Lottable12
                                            WHEN 13 THEN @c_Lottable13
                                            WHEN 14 THEN @c_Lottable14
                                            WHEN 15 THEN @c_Lottable15
                                            END
                                 
               SET @c_LottableLabel = CASE @n_No WHEN 1  THEN @c_Lottable01Label
                                                 WHEN 2  THEN @c_Lottable02Label
                                                 WHEN 3  THEN @c_Lottable03Label
                                                 WHEN 4  THEN @c_Lottable04Label
                                                 WHEN 5  THEN @c_Lottable05Label
                                                 WHEN 6  THEN @c_Lottable06Label
                                                 WHEN 7  THEN @c_Lottable07Label
                                                 WHEN 8  THEN @c_Lottable08Label
                                                 WHEN 9  THEN @c_Lottable09Label
                                                 WHEN 10 THEN @c_Lottable10Label
                                                 WHEN 11 THEN @c_Lottable11Label
                                                 WHEN 12 THEN @c_Lottable12Label
                                                 WHEN 13 THEN @c_Lottable13Label
                                                 WHEN 14 THEN @c_Lottable14Label
                                                 WHEN 15 THEN @c_Lottable15Label
                                                 END


               IF @c_LottableLabel <> '' AND @c_Lottable = ''
               BEGIN
                  SET @c_LottableDesc = ''
                  SELECT @c_LottableDesc = ISNULL(RTRIM(Description), '')
                  FROM   CODELKUP (NOLOCK)
                  WHERE  ListName = 'LOTTABLE' + @c_No
                  AND    Code = @c_LottableLabel

                  SET @n_continue = 3   
                  SET @n_err = 554508
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                                 + ': Lottable ' + @c_No + ' for SKU: ' + @c_Sku + ' cannot be BLANK, Please Fill In ' + @c_LottableDesc + '. (lsp_FinalizeKit_Wrapper)'
                                 + ' |' + @c_No + '|' + @c_Sku + '|' + @c_LottableDesc


                  EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey = @n_ErrGroupKey OUTPUT
                      , @c_TableName   = @c_TableName
                      , @c_SourceType  = @c_SourceType
                      , @c_Refkey1     = @c_Kitkey
                      , @c_Refkey2     = @c_KITLineNumber
                      , @c_Refkey3     = ''
                      , @n_err2        = @n_err
                      , @c_errmsg2     = @c_errmsg
                      , @b_Success     = @b_Success   OUTPUT
                      , @n_err         = @n_err       OUTPUT
                      , @c_errmsg      = @c_errmsg    OUTPUT
               END

               SET @n_No = @n_No + 1
            END

            --(Wan01) - START
            IF @b_UpdateLot03 = 1 OR @b_UpdateLot05 = 1
            BEGIN
               IF @b_UpdateLot03 = 0 SET @c_Lottable03 = ''
               IF @b_UpdateLot03 = 0 SET @c_Lottable05 = ''
               
               INSERT INTO @t_UpdateKITTo ( KitLineNumber, Lottable03, Lottable05 )
               VALUES (@c_kitLineNumber, @c_Lottable03, @c_Lottable05)
            END
            --(Wan01) - END

            SET @n_TotalKitToQty = @n_TotalKitToQty + @n_KitToQty
            FETCH NEXT FROM @CUR_KITTO INTO  @c_LocFacility
                                          ,  @c_KITLineNumber       
                                          ,  @c_Sku 
                                          ,  @c_Loc           
                                          ,  @c_Lottable01     
                                          ,  @c_Lottable02     
                                          ,  @c_Lottable03     
                                          ,  @c_Lottable04     
                                          ,  @c_Lottable05     
                                          ,  @c_Lottable06     
                                          ,  @c_Lottable07     
                                          ,  @c_Lottable08     
                                          ,  @c_Lottable09     
                                          ,  @c_Lottable10     
                                          ,  @c_Lottable11     
                                          ,  @c_Lottable12     
                                          ,  @c_Lottable13     
                                          ,  @c_Lottable14     
                                          ,  @c_Lottable15    
                                          ,  @n_KitToQty       
         END
         CLOSE @CUR_KITTO
         DEALLOCATE @CUR_KITTO 

         IF @n_KitTo = 0 
         BEGIN
            SET @n_continue = 3   
            SET @n_err = 554509
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                          + ': Kitting To not found. (lsp_FinalizeKit_Wrapper)'

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey = @n_ErrGroupKey OUTPUT
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_Kitkey
               ,  @c_Refkey2     = ''
               ,  @c_Refkey3     = ''
               ,  @n_err2        = @n_err
               ,  @c_errmsg2     = @c_errmsg
               ,  @b_Success     = @b_Success   OUTPUT
               ,  @n_err         = @n_err       OUTPUT
               ,  @c_errmsg      = @c_errmsg    OUTPUT

         END

         IF @n_continue = 3   
         BEGIN
            GOTO EXIT_SP
         END
         -------------------
         -- Validation End
         -------------------

         --------------------------
         -- 1st Warning Check START
         --------------------------
         SET @n_UnMatchQtySet = 0
         IF @n_KitFrom = 1 AND @n_KitTo > 1 
         BEGIN
            SET @c_ParentToSku = ''

            SELECT @n_BOM = 1
            FROM   BILLOFMATERIAL BOM WITH (NOLOCK)
            WHERE  StorerKey = @c_Storerkey
            AND    SKU = @c_ParentFromSku

            IF @n_BOM > 0 
            BEGIN
               SET @n_UnMatchQtySet = 0
               SELECT @n_UnMatchQtySet = 1
               FROM KITDETAIL KD WITH (NOLOCK)
               JOIN BILLOFMATERIAL BOM WITH (NOLOCK) ON (BOM.StorerKey = KD.Storerkey)
                                                     AND(BOM.SKU       = @c_ParentFromSku)
                                                     AND(BOM.ComponentSku = KD.Sku) 
               WHERE KD.KitKey = @c_KitKey
               AND KD.[Type] = 'T'
               GROUP BY KD.Storerkey
                     ,  KD.Sku
                     ,  BOM.Qty
               HAVING SUM(KD.Qty * BOM.ParentQty) <> (@n_KitFromQty * BOM.Qty)
            END
         END
         ELSE IF @n_KitFrom > 1
         BEGIN
            SET @c_ParentFromSku = ''
            SET @n_KitToQty      = 0

            SELECT @n_BOM = 1
            FROM   BILLOFMATERIAL BOM WITH (NOLOCK)
            WHERE  StorerKey = @c_Storerkey
            AND    SKU = @c_ParentToSku

            IF @n_BOM > 0 
            BEGIN
               SET @n_KitToQty = @n_TotalKitToQty

               SET @n_UnMatchQtySet = 0
               SELECT @n_UnMatchQtySet = 1
               FROM KITDETAIL KD WITH (NOLOCK)
               LEFT JOIN BILLOFMATERIAL BOM WITH (NOLOCK) ON  (BOM.StorerKey = KD.Storerkey)
                                                           AND(BOM.SKU       = @c_ParentToSku)
                                                           AND(BOM.ComponentSku = KD.Sku) 
               WHERE KD.KitKey = @c_KitKey
               AND KD.[Type] = 'F'
               GROUP BY KD.Storerkey
                     ,  KD.Sku
                     ,  BOM.Qty
               HAVING SUM(KD.Qty * ISNULL(BOM.ParentQty,0)) <> (@n_KitToQty * ISNULL(BOM.Qty,0))
            END
         END

         IF @n_UnMatchQtySet > 0
         BEGIN
            SET @n_WarningNo = 1
            SET @c_ErrMsg = 'Total of Component Quantity does not match to the quantity set in BOM Master. '
                          + 'Do you want to proceed?'
            GOTO EXIT_SP
         END
         --------------------------
         -- 1st Warning Check END
         --------------------------
      END 
   
      --(Wan01) - START
      BEGIN TRAN
      SET @CUR_UPDKITTO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT kitLineNumber
            ,Lottable03
            ,Lottable05
      FROM @t_UpdateKITTo

      OPEN @CUR_UPDKITTo

      FETCH NEXT FROM @CUR_UPDKITTO INTO  @c_KITLineNumber 
                                       ,  @c_Lottable03
                                       ,  @c_Lottable05  
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         BEGIN TRY
            UPDATE KITDETAIL 
            SET Lottable03 = CASE WHEN @c_Lottable03 <> '' THEN @c_Lottable03 ELSE Lottable03 END
               ,Lottable05 = CASE WHEN @c_Lottable05 <> '' THEN CONVERT(DATETIME, @c_Lottable05, 121) ELSE Lottable05 END
               ,EditWho = @c_UserName
               ,EditDate= GETDATE()
               ,TrafficCop = NULL
            WHERE KitKey = @c_KitKey
            AND   KITLineNumber = @c_KITLineNumber
         END TRY
         BEGIN CATCH
            SET @n_continue = 3   
            SET @n_err = 554510
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                           + ': Update KITDETAIL Table Fail. (lsp_FinalizeKit_Wrapper)'
                           + '(' + @c_errmsg + ')' 
                           
            IF (XACT_STATE()) = -1     --(Wan02) - START  
            BEGIN  
               ROLLBACK TRAN;  
            END;                       --(Wan02) - END                              
            GOTO EXIT_SP
         END CATCH

         FETCH NEXT FROM @CUR_UPDKITTO INTO  @c_KITLineNumber 
                                          ,  @c_Lottable03
                                          ,  @c_Lottable05 
      END
      --(Wan01) - END

      BEGIN TRY
         UPDATE KIT WITH (ROWLOCK)
         SET [Status] = '9'
            ,EditWho = @c_UserName
            ,EditDate= GETDATE()
         WHERE KitKey = @c_KitKey
      END TRY

      BEGIN CATCH
         SET @n_continue = 3   
         SET @n_err = 554511  ---554451 -- (Wan01) - Fixed Wrong Error Code
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                       + ': Update KIT Table Fail. (lsp_FinalizeKit_Wrapper)'
                       + '(' + @c_errmsg + ')' 

         IF (XACT_STATE()) = -1  
         BEGIN
            ROLLBACK TRAN;
         END;
         GOTO EXIT_SP
      END CATCH
   END TRY

   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg = 'Finalize Kit fail. (lsp_FinalizeKit_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      GOTO EXIT_SP
   END CATCH   --(Wan02) - END
   EXIT_SP:
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         SET @n_CurrTrnCnt = @@TRANCOUNT  
         WHILE @n_CurrTrnCnt > @n_StartTCnt  
         BEGIN  
            SET @n_CurrTrnCnt = @n_CurrTrnCnt - 1   
            COMMIT TRAN  
         END  
           
         /*WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END*/  
      END  
  
      SET @n_WarningNo = 0  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_FinalizeKit_Wrapper'  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
        
      SET @n_CurrTrnCnt = @@TRANCOUNT  
      WHILE @n_CurrTrnCnt > @n_StartTCnt  
      BEGIN  
        SET @n_CurrTrnCnt = @n_CurrTrnCnt - 1   
         COMMIT TRAN  
      END  
        
      /*WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END*/  
   END  
  
   SET @n_CurrTrnCnt = @@TRANCOUNT  
   WHILE @n_CurrTrnCnt < @n_StartTCnt  
   BEGIN  
      SET @n_CurrTrnCnt = @n_CurrTrnCnt + 1   
      BEGIN TRAN  
   END  
  
   /*WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END*/  

   REVERT      
END  

GO