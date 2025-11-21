SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_finalizeADJ_Wrapper                             */  
/* Creation Date: 09-MAR-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-328 - Stored Procedures for Release 2 Feature -         */
/*          Inventory  Inventory Adjustment                              */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2020-03-20  Wan01    1.1   Fixed                                      */ 
/* 2020-12-10  Wan02    1.2   Add Big Outer Begin Try..End Try to enable */
/*                            Revert when SP Raise error                 */
/*                      1.2   Fixed Uncommitable Transaction             */
/* 2021-01-15  Wan03    1.3   Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2022-07-13  Wan04    1.4   LFWM-3501 - PROD & UAT - GIT SCE Adjustment*/
/*                            Issue                                      */
/* 2022-07-13  Wan04    1.4   DevObj Combine script                      */
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_finalizeADJ_Wrapper]  
   @c_AdjustmentKey  NVARCHAR(10)
,  @b_Success        INT          = 1   OUTPUT   
,  @n_Err            INT          = 0   OUTPUT
,  @c_Errmsg         NVARCHAR(255)= ''  OUTPUT
,  @c_UserName       NVARCHAR(128)= ''
,  @n_ErrGroupKey    INT = 0 OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON                      --(Wan02) - START                                 
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   --SET ANSI_NULLS ON
   --SET ANSI_PADDING ON
   --SET ANSI_WARNINGS ON
   --SET QUOTED_IDENTIFIER ON
   --SET CONCAT_NULL_YIELDS_NULL ON
   --SET ARITHABORT ON                 --(Wan02) - END

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @n_Count           INT = 0 
         , @c_TableName       NVARCHAR(50)
         , @c_SourceType      NVARCHAR(30)

         , @c_Facility        NVARCHAR(5)
         , @c_Storerkey       NVARCHAR(15)
         , @c_AdjLineNo       NVARCHAR(5)
         , @c_Sku             NVARCHAR(20)
         , @c_Lot             NVARCHAR(10)         
         , @c_Loc             NVARCHAR(10)
         , @c_Lottable01      NVARCHAR(18)
         , @c_Lottable02      NVARCHAR(18)
         , @c_Lottable03      NVARCHAR(18)
         , @d_Lottable04      DATETIME    
         , @d_Lottable05      DATETIME    
         , @c_Lottable06      NVARCHAR(30)
         , @c_Lottable07      NVARCHAR(30)
         , @c_Lottable08      NVARCHAR(30)
         , @c_Lottable09      NVARCHAR(30)
         , @c_Lottable10      NVARCHAR(30)
         , @c_Lottable11      NVARCHAR(30)
         , @c_Lottable12      NVARCHAR(30)
         , @d_Lottable13      DATETIME    
         , @d_Lottable14      DATETIME    
         , @d_Lottable15      DATETIME    
         , @c_Lottable01Label NVARCHAR(20)
         , @c_Lottable02Label NVARCHAR(20)
         , @c_Lottable03Label NVARCHAR(20)
         , @c_Lottable04Label NVARCHAR(20)
         , @c_Lottable05Label NVARCHAR(20)
         , @c_Lottable06Label NVARCHAR(20)
         , @c_Lottable07Label NVARCHAR(20)
         , @c_Lottable08Label NVARCHAR(20)
         , @c_Lottable09Label NVARCHAR(20)
         , @c_Lottable10Label NVARCHAR(20)
         , @c_Lottable11Label NVARCHAR(20)
         , @c_Lottable12Label NVARCHAR(20)
         , @c_Lottable13Label NVARCHAR(20)
         , @c_Lottable14Label NVARCHAR(20)
         , @c_Lottable15Label NVARCHAR(20)
         , @n_Qty             INT
         
         , @c_CrossWH         NVARCHAR(30)
         , @c_ReasonCode      NVARCHAR(30)   = ''              --(Wan04)

         , @CUR_AJD           CURSOR

   SET @b_Success = 1
   SET @c_ErrMsg = ''
   SET @c_TableName = 'ADJUSTMENT'
   SET @c_SourceType = 'lsp_finalizeADJ_Wrapper'
   SET @n_ErrGroupKey= 0

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
   
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
   
   BEGIN TRY
      SET @c_Facility = ''
      SET @c_Storerkey= ''
      SELECT @c_Facility = RTRIM(AH.Facility)
         ,   @c_Storerkey= RTRIM(AH.Storerkey)
      FROM ADJUSTMENT AH WITH (NOLOCK)
      WHERE AH.AdjustmentKey = @c_AdjustmentKey

      IF ISNULL(RTRIM(@c_Facility),'') = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 551101
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Facility cannot be blank. (lsp_finalizeADJ_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
             , @c_TableName   = @c_TableName
             , @c_SourceType  = @c_SourceType
             , @c_Refkey1     = @c_AdjustmentKey
             , @c_Refkey2     = ''
             , @c_Refkey3     = ''
             , @n_err2        = @n_err
             , @c_errmsg2     = @c_errmsg
             , @b_Success     = @b_Success   
             , @n_err         = @n_err       
             , @c_errmsg      = @c_errmsg    
      END

      SET @b_Success = 1
      EXEC nspGetRight  
            @c_Facility           
         ,  @c_StorerKey             
         ,  ''       
         ,  'CROSSWH'             
         ,  @b_Success  OUTPUT   
         ,  @c_CrossWH  OUTPUT  
         ,  @n_err      OUTPUT  
         ,  @c_errmsg   OUTPUT

      IF @b_Success <> 1 
      BEGIN 
         SET @n_Continue = 3
         SET @n_Err     = 551102
         SET @c_ErrMsg = CONVERT(CHAR(6),@n_Err) + '. Error Executing nspGetRight. (lsp_finalizeADJ_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
                 @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               , @c_TableName   = @c_TableName
               , @c_SourceType  = @c_SourceType
               , @c_Refkey1     = @c_AdjustmentKey
               , @c_Refkey2     = ''
               , @c_Refkey3     = ''
               , @n_err2        = @n_err
               , @c_errmsg2     = @c_errmsg
               , @b_Success     = @b_Success   
               , @n_err         = @n_err       
               , @c_errmsg      = @c_errmsg   
      END

      IF OBJECT_ID('tempdb..#UPDLOT05','u') IS NOT NULL
      BEGIN
         DROP TABLE #UPDLOT05;
      END  

      CREATE TABLE #UPDLOT05  
         (  AdjustmentKey        NVARCHAR(10) NOT NULL   DEFAULT ('')  
         ,  AdjustmentLineNumber NVARCHAR(10) NOT NULL   DEFAULT ('')    
         )    

      SET @CUR_AJD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                  --(Wan04)
      SELECT AdjLineNo  = AD.AdjustmentLineNumber
            ,Storerkey  = RTRIM(AD.Storerkey)
            ,Sku        = RTRIM(AD.Sku)
            ,lot        = ISNULL(RTRIM(AD.Lot),'')
            ,Loc        = RTRIM(AD.Loc)
            ,Lottable01 = ISNULL(RTRIM(AD.Lottable01),'')
            ,Lottable02 = ISNULL(RTRIM(AD.Lottable02),'')       
            ,Lottable03 = ISNULL(RTRIM(AD.Lottable03),'')
            ,Lottable04 = AD.Lottable04
            ,Lottable05 = AD.Lottable05
            ,Lottable06 = ISNULL(RTRIM(AD.Lottable06),'')
            ,Lottable07 = ISNULL(RTRIM(AD.Lottable07),'') 
            ,Lottable08 = ISNULL(RTRIM(AD.Lottable08),'')
            ,Lottable09 = ISNULL(RTRIM(AD.Lottable09),'') 
            ,Lottable10 = ISNULL(RTRIM(AD.Lottable10),'')
            ,Lottable11 = ISNULL(RTRIM(AD.Lottable11),'') 
            ,Lottable12 = ISNULL(RTRIM(AD.Lottable12),'')
            ,Lottable13 = AD.Lottable13 
            ,Lottable14 = AD.Lottable14
            ,Lottable15 = AD.Lottable15 
            ,Qty        = AD.Qty
            ,ReasonCode = AD.ReasonCode                           --(Wan04)
      FROM ADJUSTMENTDETAIL AD WITH (NOLOCK)
      WHERE AD.AdjustmentKey = @c_Adjustmentkey
      AND AD.FinalizedFlag <> 'Y'
      ORDER BY AD.AdjustmentLineNumber

      OPEN @CUR_AJD

      FETCH NEXT FROM @CUR_AJD INTO    @c_AdjLineNo 
                                    ,  @c_Storerkey 
                                    ,  @c_Sku       
                                    ,  @c_lot       
                                    ,  @c_Loc       
                                    ,  @c_Lottable01
                                    ,  @c_Lottable02       
                                    ,  @c_Lottable03
                                    ,  @d_Lottable04
                                    ,  @d_Lottable05
                                    ,  @c_Lottable06
                                    ,  @c_Lottable07 
                                    ,  @c_Lottable08
                                    ,  @c_Lottable09 
                                    ,  @c_Lottable10
                                    ,  @c_Lottable11 
                                    ,  @c_Lottable12
                                    ,  @d_Lottable13
                                    ,  @d_Lottable14
                                    ,  @d_Lottable15
                                    ,  @n_Qty
                                    ,  @c_ReasonCode              --(Wan04)

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_CrossWH <> '1'
         BEGIN
            SET @n_Count = 0
            SELECT @n_Count = 1
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_Loc   
            AND Facility = @c_Facility

            IF @n_Count = 0 
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 551103
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Loc ' + @c_Loc 
                             + ' does not belong to Facility ' + @c_facility
                             + '. (lsp_finalizeADJ_Wrapper)'
                             + ' |' + @c_Loc  + '|' + @c_facility

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                   , @c_TableName   = @c_TableName
                   , @c_SourceType  = @c_SourceType
                   , @c_Refkey1     = @c_AdjustmentKey
                   , @c_Refkey2     = @c_AdjLineNo
                   , @c_Refkey3     = ''
                   , @n_err2        = @n_err
                   , @c_errmsg2     = @c_errmsg
                   , @b_Success     = @b_Success   
                   , @n_err         = @n_err       
                   , @c_errmsg      = @c_errmsg    
            END     
         END

         IF @c_Lot = ''
         BEGIN
            SET @c_Lottable01Label   = ''
            SET @c_Lottable02Label   = ''
            SET @c_Lottable03Label   = ''
            SET @c_Lottable04Label   = ''
            SET @c_Lottable05Label   = ''
            SET @c_Lottable06Label   = ''
            SET @c_Lottable07Label   = ''
            SET @c_Lottable08Label   = ''
            SET @c_Lottable09Label   = ''
            SET @c_Lottable10Label   = ''
            SET @c_Lottable11Label   = ''
            SET @c_Lottable12Label   = ''
            SET @c_Lottable13Label   = ''
            SET @c_Lottable14Label   = ''
            SET @c_Lottable15Label   = ''

            SELECT @c_Lottable01Label = ISNULL(RTRIM(SKU.Lottable01Label),'')
                  ,@c_Lottable02Label = ISNULL(RTRIM(SKU.Lottable02Label),'')
                  ,@c_Lottable03Label = ISNULL(RTRIM(SKU.Lottable03Label),'')
                  ,@c_Lottable04Label = ISNULL(RTRIM(SKU.Lottable04Label),'')
                  ,@c_Lottable05Label = ISNULL(RTRIM(SKU.Lottable05Label),'')
                  ,@c_Lottable06Label = ISNULL(RTRIM(SKU.Lottable06Label),'')
                  ,@c_Lottable07Label = ISNULL(RTRIM(SKU.Lottable07Label),'')
                  ,@c_Lottable08Label = ISNULL(RTRIM(SKU.Lottable08Label),'')
                  ,@c_Lottable09Label = ISNULL(RTRIM(SKU.Lottable09Label),'')
                  ,@c_Lottable10Label = ISNULL(RTRIM(SKU.Lottable10Label),'')
                  ,@c_Lottable11Label = ISNULL(RTRIM(SKU.Lottable11Label),'')
                  ,@c_Lottable12Label = ISNULL(RTRIM(SKU.Lottable12Label),'')
                  ,@c_Lottable13Label = ISNULL(RTRIM(SKU.Lottable13Label),'')
                  ,@c_Lottable14Label = ISNULL(RTRIM(SKU.Lottable14Label),'')
                  ,@c_Lottable15Label = ISNULL(RTRIM(SKU.Lottable15Label),'')
            FROM SKU WITH (NOLOCK)              
            WHERE Storerkey = @c_Storerkey      
            AND Sku = @c_Sku   

            IF @c_Lottable01Label <> ''
            BEGIN
               IF @c_Lottable01Label = 'HMCE' AND @n_Qty > 0
               BEGIN
                  IF @c_Lottable01 <> ''
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_err = 551104
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                                   + ' Please Empty ' + @c_Lottable01Label 
                                   + ' For Positive Adjustment Of SKU ' + @c_Sku 
                                   + '. (lsp_finalizeADJ_Wrapper)'
                                   + ' |' + @c_Lottable01Label + '|' + @c_Sku 

                     EXEC [WM].[lsp_WriteError_List] 
                           @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                         , @c_TableName   = @c_TableName
                         , @c_SourceType  = @c_SourceType
                         , @c_Refkey1     = @c_AdjustmentKey
                         , @c_Refkey2     = @c_AdjLineNo
                         , @c_Refkey3     = ''
                         , @n_err2        = @n_err
                         , @c_errmsg2     = @c_errmsg
                         , @b_Success     = @b_Success   
                         , @n_err         = @n_err       
                         , @c_errmsg      = @c_errmsg    
                   END
               END
               ELSE IF @c_Lottable01 = ''       --(Wan01)
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 551105
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                                 + ' Please Enter Lot#/ ' + @c_Lottable01Label 
                                 + ' For SKU ' + @c_Sku 
                                 + '. (lsp_finalizeADJ_Wrapper)'
                                 + ' |' + @c_Lottable01Label + '|' + @c_Sku 

                  EXEC [WM].[lsp_WriteError_List] 
                          @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                        , @c_TableName   = @c_TableName
                        , @c_SourceType  = @c_SourceType
                        , @c_Refkey1     = @c_AdjustmentKey
                        , @c_Refkey2     = @c_AdjLineNo
                        , @c_Refkey3     = ''
                        , @n_err2        = @n_err
                        , @c_errmsg2     = @c_errmsg
                        , @b_Success     = @b_Success   
                        , @n_err         = @n_err       
                        , @c_errmsg      = @c_errmsg    
               END
            END    

            IF @c_Lottable02Label <> '' AND @c_Lottable02 = ''
            BEGIN 
               SET @n_Continue = 3
               SET @n_err = 551106
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                              + ' Please Enter Lot#/ ' + @c_Lottable02Label 
                              + ' For SKU ' + @c_Sku 
                              + '. (lsp_finalizeADJ_Wrapper)'
                              + ' |' + @c_Lottable02Label + '|' + @c_Sku 

               EXEC [WM].[lsp_WriteError_List] 
                       @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   
                     , @n_err         = @n_err       
                     , @c_errmsg      = @c_errmsg    
            END 

            IF @c_Lottable03Label <> '' AND @c_Lottable03 = ''
            BEGIN 
               SET @n_Continue = 3
               SET @n_err = 551107
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                              + ' Please Enter Lot#/ ' + @c_Lottable03Label
                              + ' For SKU ' + @c_Sku 
                              + '. (lsp_finalizeADJ_Wrapper)'
                              + ' |' + @c_Lottable03Label + '|' + @c_Sku 

               EXEC [WM].[lsp_WriteError_List] 
                       @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   OUTPUT
                     , @n_err         = @n_err       OUTPUT
                     , @c_errmsg      = @c_errmsg    OUTPUT
            END 

            IF @c_Lottable04Label <> '' AND (@d_Lottable04 = '' OR @d_Lottable04 IS NULL)
            BEGIN 
               SET @n_Continue = 3
               SET @n_err = 551108
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                              + ' Please Enter Lot#/ ' + @c_Lottable04Label
                              + ' For SKU ' + @c_Sku 
                              + '. (lsp_finalizeADJ_Wrapper)'
                              + ' |' + @c_Lottable04Label + '|' + @c_Sku 

               EXEC [WM].[lsp_WriteError_List] 
                       @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   
                     , @n_err         = @n_err       
                     , @c_errmsg      = @c_errmsg    
            END

            IF @c_Lottable05Label <> '' AND (@d_Lottable05 = '' OR @d_Lottable05 IS NULL)
            BEGIN 
               IF @c_Lottable05Label = 'RCP_DATE'
               BEGIN
                  INSERT INTO #UPDLOT05 (AdjustmentKey, AdjustmentLineNumber)
                  VALUES (@c_AdjustmentKey, @c_AdjLineNo)
               END
               ELSE
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 551110
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                                 + ' Please Enter Lot#/ ' + @c_Lottable05Label
                                 + ' For SKU ' + @c_Sku 
                                 + '. (lsp_finalizeADJ_Wrapper)'
                                 + ' |' + @c_Lottable05Label + '|' + @c_Sku 

                  EXEC [WM].[lsp_WriteError_List] 
                          @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                        , @c_TableName   = @c_TableName
                        , @c_SourceType  = @c_SourceType
                        , @c_Refkey1     = @c_AdjustmentKey
                        , @c_Refkey2     = @c_AdjLineNo
                        , @c_Refkey3     = ''
                        , @n_err2        = @n_err
                        , @c_errmsg2     = @c_errmsg
                        , @b_Success     = @b_Success   
                        , @n_err         = @n_err       
                        , @c_errmsg      = @c_errmsg    
               END
            END

            IF @c_Lottable06Label <> '' AND @c_Lottable06 = ''
            BEGIN 
               SET @n_Continue = 3
               SET @n_err = 551111
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                              + ' Please Enter Lot#/ ' + @c_Lottable06Label
                              + ' For SKU ' + @c_Sku 
                              + '. (lsp_finalizeADJ_Wrapper)'
                              + ' |' + @c_Lottable06Label + '|' + @c_Sku 

               EXEC [WM].[lsp_WriteError_List] 
                       @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   
                     , @n_err         = @n_err       
                     , @c_errmsg      = @c_errmsg    
            END 

            IF @c_Lottable07Label <> '' AND @c_Lottable07 = ''
            BEGIN 
               SET @n_Continue = 3
               SET @n_err = 551112
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                              + ' Please Enter Lot#/ ' + @c_Lottable07Label
                              + ' For SKU ' + @c_Sku 
                              + '. (lsp_finalizeADJ_Wrapper)'
                              + ' |' + @c_Lottable07Label + '|' + @c_Sku 

               EXEC [WM].[lsp_WriteError_List] 
                       @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   
                     , @n_err         = @n_err       
                     , @c_errmsg      = @c_errmsg    
            END 

            IF @c_Lottable08Label <> '' AND @c_Lottable08 = ''
            BEGIN 
               SET @n_Continue = 3
               SET @n_err = 551113
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                              + ' Please Enter Lot#/ ' + @c_Lottable08Label
                              + ' For SKU ' + @c_Sku 
                              + '. (lsp_finalizeADJ_Wrapper)'
                              + ' |' + @c_Lottable08Label + '|' + @c_Sku 

               EXEC [WM].[lsp_WriteError_List] 
                       @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   
                     , @n_err         = @n_err       
                     , @c_errmsg      = @c_errmsg    
            END 

            IF @c_Lottable09Label <> '' AND @c_Lottable09 = ''
            BEGIN 
               SET @n_Continue = 3
               SET @n_err = 551114
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                              + ' Please Enter Lot#/ ' + @c_Lottable09Label
                              + ' For SKU ' + @c_Sku 
                              + '. (lsp_finalizeADJ_Wrapper)'
                              + ' |' + @c_Lottable09Label + '|' + @c_Sku 

               EXEC [WM].[lsp_WriteError_List] 
                       @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   
                     , @n_err         = @n_err       
                     , @c_errmsg      = @c_errmsg    
            END 

            IF @c_Lottable10Label <> '' AND @c_Lottable10 = ''
            BEGIN 
               SET @n_Continue = 3
               SET @n_err = 551115
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                              + ' Please Enter Lot#/ ' + @c_Lottable10Label
                              + ' For SKU ' + @c_Sku 
                              + '. (lsp_finalizeADJ_Wrapper)'
                              + ' |' + @c_Lottable10Label + '|' + @c_Sku 

               EXEC [WM].[lsp_WriteError_List] 
                       @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   
                     , @n_err         = @n_err       
                     , @c_errmsg      = @c_errmsg    
            END 

            IF @c_Lottable11Label <> '' AND @c_Lottable11 = ''
            BEGIN 
               SET @n_Continue = 3
               SET @n_err = 551116
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                              + ' Please Enter Lot#/ ' + @c_Lottable11Label
                              + ' For SKU ' + @c_Sku 
                              + '. (lsp_finalizeADJ_Wrapper)'
                              + ' |' + @c_Lottable11Label + '|' + @c_Sku 

               EXEC [WM].[lsp_WriteError_List] 
                       @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   
                     , @n_err         = @n_err       
                     , @c_errmsg      = @c_errmsg    
            END 
        
            IF @c_Lottable12Label <> '' AND @c_Lottable12 = ''
            BEGIN 
               SET @n_Continue = 3
               SET @n_err = 551117
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                              + ' Please Enter Lot#/ ' + @c_Lottable12Label 
                              + ' For SKU ' + @c_Sku 
                              + '. (lsp_finalizeADJ_Wrapper)'
                              + ' |' + @c_Lottable12Label + '|' + @c_Sku 

               EXEC [WM].[lsp_WriteError_List] 
                       @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   OUTPUT
                     , @n_err         = @n_err       OUTPUT
                     , @c_errmsg      = @c_errmsg    OUTPUT
            END 

            IF @c_Lottable13Label <> '' AND (@d_Lottable13 = '' OR @d_Lottable13 IS NULL)
            BEGIN 
               SET @n_Continue = 3
               SET @n_err = 551118
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                              + ' Please Enter Lot#/ ' + @c_Lottable13Label
                              + ' For SKU ' + @c_Sku 
                              + '. (lsp_finalizeADJ_Wrapper)'
                              + ' |' + @c_Lottable13Label + '|' + @c_Sku 

               EXEC [WM].[lsp_WriteError_List] 
                       @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   OUTPUT
                     , @n_err         = @n_err       OUTPUT
                     , @c_errmsg      = @c_errmsg    OUTPUT
            END       

            IF @c_Lottable14Label <> '' AND (@d_Lottable14 = '' OR @d_Lottable14 IS NULL)
            BEGIN 
               SET @n_Continue = 3
               SET @n_err = 551119
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                              + ' Please Enter Lot#/ ' + @c_Lottable14Label
                              + ' For SKU ' + @c_Sku 
                              + '. (lsp_finalizeADJ_Wrapper)'
                              + ' |' + @c_Lottable14Label + '|' + @c_Sku 

               EXEC [WM].[lsp_WriteError_List] 
                       @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   
                     , @n_err         = @n_err       
                     , @c_errmsg      = @c_errmsg    
            END       
 
            IF @c_Lottable15Label <> '' AND (@d_Lottable15 = '' OR @d_Lottable15 IS NULL)
            BEGIN 
               SET @n_Continue = 3
               SET @n_err = 551120
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': ' 
                              + ' Please Enter Lot#/ ' + @c_Lottable15Label
                              + ' For SKU ' + @c_Sku 
                              + '. (lsp_finalizeADJ_Wrapper)'
                              + ' |' + @c_Lottable15Label + '|' + @c_Sku 

               EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   
                     , @n_err         = @n_err       
                     , @c_errmsg      = @c_errmsg    
            END
         
         END -- @c_Lot = ''

         --(Wan04) - START
         IF @c_ReasonCode = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 551123
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Reason Code is required. (lsp_finalizeADJ_Wrapper)'

            EXEC [WM].[lsp_WriteError_List] 
                       @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     , @c_TableName   = @c_TableName
                     , @c_SourceType  = @c_SourceType
                     , @c_Refkey1     = @c_AdjustmentKey
                     , @c_Refkey2     = @c_AdjLineNo
                     , @c_Refkey3     = ''
                     , @n_err2        = @n_err
                     , @c_errmsg2     = @c_errmsg
                     , @b_Success     = @b_Success   
                     , @n_err         = @n_err       
                     , @c_errmsg      = @c_errmsg          
         END
         --(Wan04) - END   
         FETCH NEXT FROM @CUR_AJD INTO    @c_AdjLineNo 
                                       ,  @c_Storerkey 
                                       ,  @c_Sku       
                                       ,  @c_lot       
                                       ,  @c_Loc       
                                       ,  @c_Lottable01
                                       ,  @c_Lottable02       
                                       ,  @c_Lottable03
                                       ,  @d_Lottable04
                                       ,  @d_Lottable05
                                       ,  @c_Lottable06
                                       ,  @c_Lottable07 
                                       ,  @c_Lottable08
                                       ,  @c_Lottable09 
                                       ,  @c_Lottable10
                                       ,  @c_Lottable11 
                                       ,  @c_Lottable12
                                       ,  @d_Lottable13
                                       ,  @d_Lottable14
                                       ,  @d_Lottable15
                                       ,  @n_Qty
                                       ,  @c_ReasonCode              --(Wan04)
      END
      CLOSE @CUR_AJD
      DEALLOCATE @CUR_AJD

      IF @n_Continue IN ('1', '2')
      BEGIN
         BEGIN TRAN
         SET @CUR_AJD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT AdjLineNo  = AD.AdjustmentLineNumber
         FROM #UPDLOT05 AD WITH (NOLOCK)
         WHERE AD.AdjustmentKey = @c_Adjustmentkey
         ORDER BY AD.AdjustmentLineNumber

         OPEN @CUR_AJD

         FETCH NEXT FROM @CUR_AJD INTO @c_AdjLineNo

         WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1, 2)
         BEGIN
            BEGIN TRY
               UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK)
               SET Lottable05 = GETDATE()
                  ,EditWho    = @c_UserName
                  ,EditDate   = GETDATE()
                  ,Trafficcop = NULL
               WHERE AdjustmentKey = @c_AdjustmentKey    
               AND AdjustmentLineNumber = @c_AdjLineNo
            END TRY

            BEGIN CATCH
               SET @n_Continue = 3
               SET @n_err = 551109
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Update AdjustmentDetail Fail. (lsp_finalizeADJ_Wrapper)'
                              + '( ' + @c_errmsg + ' )'
                           
               IF (XACT_STATE()) = -1     --(Wan02) - START  
               BEGIN  
                  ROLLBACK TRAN;  
               END;                       --(Wan02) - END                            
            END CATCH

            FETCH NEXT FROM @CUR_AJD INTO @c_AdjLineNo
         END
         CLOSE @CUR_AJD
         DEALLOCATE @CUR_AJD

         IF @n_Continue = 3
         BEGIN 
            IF @@TRANCOUNT > 0            --(Wan02)  
               ROLLBACK TRAN;

            EXEC [WM].[lsp_WriteError_List] 
              @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            , @c_TableName   = @c_TableName
            , @c_SourceType  = @c_SourceType
            , @c_Refkey1     = @c_AdjustmentKey
            , @c_Refkey2     = @c_AdjLineNo
            , @c_Refkey3     = ''
            , @n_err2        = @n_err
            , @c_errmsg2     = @c_errmsg
            , @b_Success     = @b_Success   
            , @n_err         = @n_err       
            , @c_errmsg      = @c_errmsg 
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END
      END

      IF @n_Continue IN ('1', '2')
      BEGIN
         BEGIN TRY
            EXEC isp_FinalizeADJ
                  @c_ADJKey = @c_AdjustmentKey 
               ,  @b_Success= @b_Success OUTPUT
               ,  @n_Err    = @n_Err     OUTPUT
               ,  @c_ErrMsg = @c_Errmsg  OUTPUT
         END TRY
         BEGIN CATCH
            SET @n_err = 551121
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing isp_FinalizeADJ. (lsp_finalizeADJ_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
                        
            IF (XACT_STATE()) = -1     --(Wan02) - START  
            BEGIN  
               ROLLBACK TRAN;  
            END;                       --(Wan02) - END                         
         END CATCH      

         IF @b_Success = 0 OR @n_Err <> 0 
         BEGIN
            SET @n_Continue = 3

            EXEC [WM].[lsp_WriteError_List]              
              @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            , @c_TableName   = @c_TableName
            , @c_SourceType  = @c_SourceType
            , @c_Refkey1     = @c_AdjustmentKey
            , @c_Refkey2     = ''
            , @c_Refkey3     = ''
            , @n_err2        = @n_err
            , @c_errmsg2     = @c_errmsg
            , @b_Success     = @b_Success   
            , @n_err         = @n_err       
            , @c_errmsg      = @c_errmsg 
            GOTO EXIT_SP 
         END   
      END   
   END TRY
   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg = 'Finalize Adjustment fail. (lsp_finalizeADJ_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
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
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_finalizeADJ_Wrapper'
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