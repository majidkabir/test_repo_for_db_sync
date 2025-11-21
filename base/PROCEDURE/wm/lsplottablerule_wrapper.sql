SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lspLottableRule_Wrapper                             */  
/* Creation Date: 2020-11-30                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-2438 - UAT  Philippines  PH SCE Lottable13 Not          */
/*          Autocomputing                                                */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2020-11-30  Wan      1.0   Creation                                   */
/* 2020-12-08  Wan      1.0   LFWM-2410 - UAT  Philippines  PH SCE No    */
/*                            Prompt For Entering Expired Stocks         */
/* 2021-02-19  Wan01    1.1   Execute Login @c_Username if <> SUSER_SNAME()*/
/* 2021-03-31  Wan02    1.2   LFWM-2666 - PROD PH MNC LOTTABLE04 defaulting*/
/*                            to 01011900                                */
/* 2021-08-11  Wan03    1.3   LFWM-2935 - UAT - TW  Adjustment Lottable  */
/*                            Input Validation                           */
/* 2021-10-14  Wan03    1.0   DevOps Script Combine                      */
/*************************************************************************/   
CREATE PROCEDURE [WM].[lspLottableRule_Wrapper]  
        @c_SPName                NVARCHAR(250)
      , @c_Listname              NVARCHAR(10)
      , @c_Storerkey             NVARCHAR(15)
      , @c_Sku                   NVARCHAR(20)
      , @c_LottableLabel         NVARCHAR(20)
      , @c_Lottable01Value       NVARCHAR(60)   
      , @c_Lottable02Value       NVARCHAR(60)
      , @c_Lottable03Value       NVARCHAR(60)
      , @dt_Lottable04Value      DATETIME
      , @dt_Lottable05Value      DATETIME
      , @c_Lottable06Value       NVARCHAR(60)   = ''
      , @c_Lottable07Value       NVARCHAR(60)   = ''
      , @c_Lottable08Value       NVARCHAR(60)   = ''
      , @c_Lottable09Value       NVARCHAR(60)   = ''
      , @c_Lottable10Value       NVARCHAR(60)   = ''
      , @c_Lottable11Value       NVARCHAR(60)   = ''
      , @c_Lottable12Value       NVARCHAR(60)   = ''
      , @dt_Lottable13Value      DATETIME       = NULL
      , @dt_Lottable14Value      DATETIME       = NULL
      , @dt_Lottable15Value      DATETIME       = NULL
      , @c_Lottable01            NVARCHAR(18)            OUTPUT
      , @c_Lottable02            NVARCHAR(18)            OUTPUT
      , @c_Lottable03            NVARCHAR(18)            OUTPUT
      , @dt_Lottable04           DATETIME                OUTPUT
      , @dt_Lottable05           DATETIME                OUTPUT
      , @c_Lottable06            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable07            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable08            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable09            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable10            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable11            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable12            NVARCHAR(30)   = ''     OUTPUT
      , @dt_Lottable13           DATETIME       = NULL   OUTPUT
      , @dt_Lottable14           DATETIME       = NULL   OUTPUT
      , @dt_Lottable15           DATETIME       = NULL   OUTPUT
      , @b_Success               int            = 1      OUTPUT   --0: FAIL, 1: Success 2: Warning
      , @n_Err                   int            = 0      OUTPUT
      , @c_Errmsg                NVARCHAR(250)  = ''     OUTPUT   
      , @c_Sourcekey             NVARCHAR(15)   = '' 
      , @c_Sourcetype            NVARCHAR(20)   = '' 
      , @c_type                  NVARCHAR(10)   = ''
      , @c_PrePost               NVARCHAR(10)   = ''
      , @c_UserName              NVARCHAR(128)  = ''
      , @n_WarningNo             INT            = 0      OUTPUT  --2020-12-08 When WarningNo > 0, Need Comfirmation from User to Continue
      , @c_ProceedWithWarning    CHAR(1)        = 'N'            --2020-12-08
      , @c_UpdateTable           NVARCHAR(30)   = ''             --2020-12-08 Same as @c_UpdateTable pass to lsp_Wrapup_Validation_Wrapper
AS  
BEGIN  
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   --Notes:
   --ALL Pass In data are same is pass to call ispLottableRule_Wrapper. Adding @c_UserName in case need in Future 
   --This is WM SP Wrapper to handle Exception.
   --2020-12-08: All New Parameters to pass in a default value. For eg if string pass in '', if int pass in 0
   --Passing @n_WarningNo to Return If need Confirmation from Users to continue, Pass in Return Warning No and @c_ProceedWithWarning = 'Y' to Conitnue
   --If @c_ErrMsg <> '', Show it to users. @c_ErrMsg can be 1) Question 2) Error Message 3) Warning Message 4) Information
   --If there is a warning message, information message should not overwrite warning message which output to @c_errmsg 

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @n_WarningNo_Orig  INT = 0
         , @c_WarningMsg      NVARCHAR(255) = ''

         , @c_SQL             NVARCHAR(MAX) = ''
         , @c_SQLParms        NVARCHAR(MAX) = ''
         , @c_SPName_Rule     NVARCHAR(50)  = ''
         
   SET @b_Success = 1
   SET @c_ErrMsg = ''

   --(Wan01) - START
   IF SUSER_SNAME() <> @c_UserName        
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
                
      EXECUTE AS LOGIN = @c_UserName        
   END 
   --(Wan01) - END    
   
   --Need to Create Big Outer BEGIN TRY..END TRY If more Logic in the SP

   BEGIN TRY
      --2020-12-08 - START
      IF @c_ListName <> '' 
      BEGIN
         SET @n_WarningNo_Orig = @n_WarningNo
           
         -- Try Not to Create New or customize in @c_SPName_Rule. 
         -- Customize in SP that setup in CODELKUP.Long for Lottables
         SET @c_SPName_Rule = 'lsp_' + RTRIM(@c_UpdateTable) + '_' + @c_ListName + 'PreRule_Std'  

         IF EXISTS (SELECT 1 FROM sys.Objects (NOLOCK) WHERE Name = @c_SPName_Rule AND type = 'P')  
         BEGIN 
            SET @c_SQL = N'EXEC WM.' + @c_SPName_Rule 
                       + ' @c_Listname         = @c_Listname'
                       + ',@c_Storerkey        = @c_Storerkey'
                       + ',@c_Sku              = @c_Sku'
                       + ',@c_LottableLabel    = @c_LottableLabel'
                       + ',@c_Lottable01Value  = @c_Lottable01Value    OUTPUT'
                       + ',@c_Lottable02Value  = @c_Lottable02Value    OUTPUT'
                       + ',@c_Lottable03Value  = @c_Lottable03Value    OUTPUT'
                       + ',@dt_Lottable04Value = @dt_Lottable04Value   OUTPUT'
                       + ',@dt_Lottable05Value = @dt_Lottable05Value   OUTPUT'
                       + ',@c_Lottable06Value  = @c_Lottable06Value    OUTPUT'
                       + ',@c_Lottable07Value  = @c_Lottable07Value    OUTPUT'
                       + ',@c_Lottable08Value  = @c_Lottable08Value    OUTPUT'
                       + ',@c_Lottable09Value  = @c_Lottable09Value    OUTPUT'
                       + ',@c_Lottable10Value  = @c_Lottable10Value    OUTPUT'
                       + ',@c_Lottable11Value  = @c_Lottable11Value    OUTPUT'
                       + ',@c_Lottable12Value  = @c_Lottable12Value    OUTPUT'
                       + ',@dt_Lottable13Value = @dt_Lottable13Value   OUTPUT'
                       + ',@dt_Lottable14Value = @dt_Lottable14Value   OUTPUT'
                       + ',@dt_Lottable15Value = @dt_Lottable15Value   OUTPUT'
                       + ',@c_Lottable01       = @c_Lottable01         OUTPUT'
                       + ',@c_Lottable02       = @c_Lottable02         OUTPUT'
                       + ',@c_Lottable03       = @c_Lottable03         OUTPUT'
                       + ',@dt_Lottable04      = @dt_Lottable04        OUTPUT'
                       + ',@dt_Lottable05      = @dt_Lottable05        OUTPUT'
                       + ',@c_Lottable06       = @c_Lottable06         OUTPUT'
                       + ',@c_Lottable07       = @c_Lottable07         OUTPUT'
                       + ',@c_Lottable08       = @c_Lottable08         OUTPUT'
                       + ',@c_Lottable09       = @c_Lottable09         OUTPUT'
                       + ',@c_Lottable10       = @c_Lottable10         OUTPUT'
                       + ',@c_Lottable11       = @c_Lottable11         OUTPUT'
                       + ',@c_Lottable12       = @c_Lottable12         OUTPUT'
                       + ',@dt_Lottable13      = @dt_Lottable13        OUTPUT'
                       + ',@dt_Lottable14      = @dt_Lottable14        OUTPUT'
                       + ',@dt_Lottable15      = @dt_Lottable15        OUTPUT'
                       + ',@c_Sourcekey        = @c_Sourcekey'
                       + ',@c_Sourcetype       = @c_Sourcetype'       
                       + ',@c_type             = @c_type'       
                       + ',@b_Success          = @b_Success            OUTPUT'  
                       + ',@n_Err              = @n_Err                OUTPUT'  
                       + ',@c_ErrMsg           = @c_ErrMsg             OUTPUT'   
                       + ',@n_WarningNo        = @n_WarningNo          OUTPUT' 
    
            SET @c_SQLParms = '@c_Listname         NVARCHAR(10)'
                            +',@c_Storerkey        NVARCHAR(15)'
                            +',@c_Sku              NVARCHAR(20)' 
                            +',@c_LottableLabel    NVARCHAR(20)'
                            +',@c_Lottable01Value  NVARCHAR(60)   OUTPUT'
                            +',@c_Lottable02Value  NVARCHAR(60)   OUTPUT'
                            +',@c_Lottable03Value  NVARCHAR(60)   OUTPUT'
                            +',@dt_Lottable04Value DATETIME       OUTPUT'
                            +',@dt_Lottable05Value DATETIME       OUTPUT'
                            +',@c_Lottable06Value  NVARCHAR(60)   OUTPUT'
                            +',@c_Lottable07Value  NVARCHAR(60)   OUTPUT'
                            +',@c_Lottable08Value  NVARCHAR(60)   OUTPUT'
                            +',@c_Lottable09Value  NVARCHAR(60)   OUTPUT'
                            +',@c_Lottable10Value  NVARCHAR(60)   OUTPUT'
                            +',@c_Lottable11Value  NVARCHAR(60)   OUTPUT'
                            +',@c_Lottable12Value  NVARCHAR(60)   OUTPUT'
                            +',@dt_Lottable13Value DATETIME       OUTPUT'
                            +',@dt_Lottable14Value DATETIME       OUTPUT'
                            +',@dt_Lottable15Value DATETIME       OUTPUT'
                            +',@c_Lottable01       NVARCHAR(18)   OUTPUT'
                            +',@c_Lottable02       NVARCHAR(18)   OUTPUT'
                            +',@c_Lottable03       NVARCHAR(18)   OUTPUT'
                            +',@dt_Lottable04      DATETIME       OUTPUT'
                            +',@dt_Lottable05      DATETIME       OUTPUT'
                            +',@c_Lottable06       NVARCHAR(30)   OUTPUT'
                            +',@c_Lottable07       NVARCHAR(30)   OUTPUT'
                            +',@c_Lottable08       NVARCHAR(30)   OUTPUT'
                            +',@c_Lottable09       NVARCHAR(30)   OUTPUT'
                            +',@c_Lottable10       NVARCHAR(30)   OUTPUT'
                            +',@c_Lottable11       NVARCHAR(30)   OUTPUT'
                            +',@c_Lottable12       NVARCHAR(30)   OUTPUT'
                            +',@dt_Lottable13      DATETIME       OUTPUT'
                            +',@dt_Lottable14      DATETIME       OUTPUT'
                            +',@dt_Lottable15      DATETIME       OUTPUT'
                            +',@c_Sourcekey        NVARCHAR(15)'  
                            +',@c_Sourcetype       NVARCHAR(20)' 
                            +',@c_type             NVARCHAR(10)'                               
                            +',@b_Success          INT            OUTPUT'  
                            +',@n_Err              INT            OUTPUT'  
                            +',@c_ErrMsg           NVARCHAR(255)  OUTPUT'  
                            +',@n_WarningNo        INT            OUTPUT'   
 
            BEGIN TRY  
               SET @b_Success = 1     
               EXEC sp_ExecuteSQL @c_SQL  
                                 ,@c_SQLParms  
                                 ,@c_Listname         
                                 ,@c_Storerkey        
                                 ,@c_Sku              
                                 ,@c_LottableLabel    
                                 ,@c_Lottable01Value  OUTPUT
                                 ,@c_Lottable02Value  OUTPUT
                                 ,@c_Lottable03Value  OUTPUT
                                 ,@dt_Lottable04Value OUTPUT
                                 ,@dt_Lottable05Value OUTPUT
                                 ,@c_Lottable06Value  OUTPUT
                                 ,@c_Lottable07Value  OUTPUT
                                 ,@c_Lottable08Value  OUTPUT
                                 ,@c_Lottable09Value  OUTPUT
                                 ,@c_Lottable10Value  OUTPUT
                                 ,@c_Lottable11Value  OUTPUT
                                 ,@c_Lottable12Value  OUTPUT
                                 ,@dt_Lottable13Value OUTPUT
                                 ,@dt_Lottable14Value OUTPUT
                                 ,@dt_Lottable15Value OUTPUT
                                 ,@c_Lottable01       OUTPUT
                                 ,@c_Lottable02       OUTPUT
                                 ,@c_Lottable03       OUTPUT
                                 ,@dt_Lottable04      OUTPUT
                                 ,@dt_Lottable05      OUTPUT
                                 ,@c_Lottable06       OUTPUT
                                 ,@c_Lottable07       OUTPUT
                                 ,@c_Lottable08       OUTPUT
                                 ,@c_Lottable09       OUTPUT
                                 ,@c_Lottable10       OUTPUT
                                 ,@c_Lottable11       OUTPUT
                                 ,@c_Lottable12       OUTPUT
                                 ,@dt_Lottable13      OUTPUT
                                 ,@dt_Lottable14      OUTPUT
                                 ,@dt_Lottable15      OUTPUT
                                 ,@c_Sourcekey  
                                 ,@c_Sourcetype         
                                 ,@c_type                                                
                                 ,@b_Success          OUTPUT -- 0: Fail, 1: Success 2) Warning 
                                 ,@n_Err              OUTPUT  
                                 ,@c_ErrMsg           OUTPUT   
                                 ,@n_WarningNo        OUTPUT 
            END TRY    
       
            BEGIN CATCH    
               SET @b_Success = 0     
               SET @n_err = 559052    
               SET @c_ErrMsg = ERROR_MESSAGE()    
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ' + @c_SPName_Rule + '. (lspLottableRule_Wrapper)'    
                              + '( ' + @c_errmsg + ' )'   
            END CATCH        

            IF @b_Success  = 0
            BEGIN
               SET @n_Continue = 3
               GOTO EXIT_SP
            END

            IF @n_WarningNo > @n_WarningNo_Orig 
            BEGIN
               GOTO EXIT_SP
            END

            IF @b_Success  = 2 
            BEGIN
               SET @c_WarningMsg = @c_Errmsg
            END
         END
      END--2020-12-08 - END

      BEGIN TRY      
         EXECUTE ispLottableRule_Wrapper 
           @c_SPName          = @c_SPName          
         , @c_Listname        = @c_Listname        
         , @c_Storerkey       = @c_Storerkey       
         , @c_Sku             = @c_Sku             
         , @c_LottableLabel   = @c_LottableLabel   
         , @c_Lottable01Value = @c_Lottable01Value 
         , @c_Lottable02Value = @c_Lottable02Value 
         , @c_Lottable03Value = @c_Lottable03Value 
         , @dt_Lottable04Value= @dt_Lottable04Value
         , @dt_Lottable05Value= @dt_Lottable05Value
         , @c_Lottable06Value = @c_Lottable06Value 
         , @c_Lottable07Value = @c_Lottable07Value 
         , @c_Lottable08Value = @c_Lottable08Value 
         , @c_Lottable09Value = @c_Lottable09Value 
         , @c_Lottable10Value = @c_Lottable10Value 
         , @c_Lottable11Value = @c_Lottable11Value 
         , @c_Lottable12Value = @c_Lottable12Value 
         , @dt_Lottable13Value= @dt_Lottable13Value
         , @dt_Lottable14Value= @dt_Lottable14Value
         , @dt_Lottable15Value= @dt_Lottable15Value
         , @c_Lottable01      = @c_Lottable01       OUTPUT
         , @c_Lottable02      = @c_Lottable02       OUTPUT
         , @c_Lottable03      = @c_Lottable03       OUTPUT
         , @dt_Lottable04     = @dt_Lottable04      OUTPUT
         , @dt_Lottable05     = @dt_Lottable05      OUTPUT
         , @c_Lottable06      = @c_Lottable06       OUTPUT
         , @c_Lottable07      = @c_Lottable07       OUTPUT
         , @c_Lottable08      = @c_Lottable08       OUTPUT
         , @c_Lottable09      = @c_Lottable09       OUTPUT
         , @c_Lottable10      = @c_Lottable10       OUTPUT
         , @c_Lottable11      = @c_Lottable11       OUTPUT
         , @c_Lottable12      = @c_Lottable12       OUTPUT
         , @dt_Lottable13     = @dt_Lottable13      OUTPUT
         , @dt_Lottable14     = @dt_Lottable14      OUTPUT
         , @dt_Lottable15     = @dt_Lottable15      OUTPUT
         , @b_Success         = @b_Success          OUTPUT
         , @n_Err             = @n_Err              OUTPUT
         , @c_Errmsg          = @c_Errmsg           OUTPUT
         , @c_Sourcekey       = @c_Sourcekey        
         , @c_Sourcetype      = @c_Sourcetype       
         , @c_type            = @c_type             
         , @c_PrePost         = @c_PrePost          
      END TRY

      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_err = 559051
         SET @c_Errmsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ispLottableRule_Wrapper. (lspLottableRule_Wrapper)'
                  + '( ' + @c_errmsg + ' )'

         GOTO EXIT_SP
      END CATCH  

      IF @b_Success = 2 
      BEGIN
         SET @c_WarningMsg = @c_WarningMsg + ', ' +  @c_Errmsg
      END
      ELSE        --(Wan03) - START
      BEGIN
         IF @c_Errmsg <> ''
         BEGIN
            SET @n_Continue = 3
         END
      END         --(Wan03) - END
      
      --(Wan02) - START
      IF @c_Lottable01 = '' OR @c_Lottable01 IS NULL SET @c_Lottable01 = ISNULL(RTRIM(@c_Lottable01Value),'')   
      IF @c_Lottable02 = '' OR @c_Lottable02 IS NULL SET @c_Lottable02 = ISNULL(RTRIM(@c_Lottable02Value),'')   
      IF @c_Lottable03 = '' OR @c_Lottable03 IS NULL SET @c_Lottable03 = ISNULL(RTRIM(@c_Lottable03Value),'')    
      IF @dt_Lottable04= '1900-01-01' OR @dt_Lottable04 IS NULL SET @dt_Lottable04= @dt_Lottable04Value   
      IF @dt_Lottable05= '1900-01-01' OR @dt_Lottable05 IS NULL SET @dt_Lottable05= @dt_Lottable05Value  
      IF @c_Lottable06 = '' OR @c_Lottable06 IS NULL SET @c_Lottable06 = ISNULL(RTRIM(@c_Lottable06Value),'')   
      IF @c_Lottable07 = '' OR @c_Lottable07 IS NULL SET @c_Lottable07 = ISNULL(RTRIM(@c_Lottable07Value),'')   
      IF @c_Lottable08 = '' OR @c_Lottable08 IS NULL SET @c_Lottable08 = ISNULL(RTRIM(@c_Lottable08Value),'') 
      IF @c_Lottable09 = '' OR @c_Lottable09 IS NULL SET @c_Lottable09 = ISNULL(RTRIM(@c_Lottable09Value),'')   
      IF @c_Lottable10 = '' OR @c_Lottable10 IS NULL SET @c_Lottable10 = ISNULL(RTRIM(@c_Lottable10Value),'')       
      IF @c_Lottable11 = '' OR @c_Lottable11 IS NULL SET @c_Lottable11 = ISNULL(RTRIM(@c_Lottable11Value),'')   
      IF @c_Lottable12 = '' OR @c_Lottable12 IS NULL SET @c_Lottable12 = ISNULL(RTRIM(@c_Lottable12Value),'')       
      IF @dt_Lottable13= '1900-01-01' OR @dt_Lottable13 IS NULL SET @dt_Lottable13= @dt_Lottable13Value    
      IF @dt_Lottable14= '1900-01-01' OR @dt_Lottable14 IS NULL SET @dt_Lottable14= @dt_Lottable14Value   
      IF @dt_Lottable15= '1900-01-01' OR @dt_Lottable15 IS NULL SET @dt_Lottable15= @dt_Lottable15Value        
      --(Wan02) - END
   END TRY

   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = 'Process Lottable Rule fail. (lspLottableRule_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      GOTO EXIT_SP
   END CATCH  

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lspLottableRule_Wrapper'

      SET @n_WarningNo = 0
   END
   ELSE
   BEGIN
      IF @c_WarningMsg = ''
      BEGIN
         SET @b_Success = 1
      END
      ELSE
      BEGIN
         SET @c_ErrMsg = @c_WarningMsg
      END

      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   
   --(Wan01)
   REVERT
   
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END  

GO