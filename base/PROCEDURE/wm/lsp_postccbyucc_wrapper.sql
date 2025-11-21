SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_PostCCByUCC_Wrapper                             */  
/* Creation Date: 15-MAR-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-263 - Stored Procedures for Release 2 Feature -         */
/*          Inventory  Cycle Count  Stock Take Parameters                */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */
/* 2021-02-05   mingle01 1.1  Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/  
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_PostCCByUCC_Wrapper]  
   @c_StockTakeKey      NVARCHAR(10)
,  @b_Success           INT          = 1   OUTPUT   
,  @n_Err               INT          = 0   OUTPUT
,  @c_Errmsg            NVARCHAR(255)= ''  OUTPUT
,  @c_UserName          NVARCHAR(128)= ''
AS  
BEGIN  
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF   

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @b_postucc         BIT = 0 
         , @c_Storerkey       NVARCHAR(15)

         , @c_CCAdjPostByUCC  NVARCHAR(30) = ''
         , @c_UCCTracking     NVARCHAR(30)
         
   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 

   --(mingle01) - START
   IF SUSER_SNAME() <> @c_UserName
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
   END
   --(mingle01) - END

   --(mingle01) - START
   BEGIN TRY

      SELECT @c_Storerkey = RTRIM(Storerkey)
      FROM STOCKTAKESHEETPARAMETERS WITH (NOLOCK)
      WHERE StockTakeKey = @c_StockTakeKey

      IF NOT EXISTS (SELECT 1
                     FROM STORER WITH (NOLOCK)
                     WHERE Storerkey = @c_Storerkey
                     )
      BEGIN
         SET @n_continue = 3 
         SET @n_err = 552951
         SET @c_ErrMsg= 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Invalid Storerkey: ' + @c_Storerkey
                      + ' (lsp_PostCCByUCC_Wrapper)' 
                      + '|' + @c_Storerkey
         GOTO EXIT_SP
      END

      BEGIN TRY
         EXEC nspGetRight
              @c_Facility    = ''
            , @c_StorerKey = @c_StorerKey
            , @c_sku       = NULL
            , @c_ConfigKey = 'UCCTracking'
            , @b_Success   = @b_Success      OUTPUT
            , @c_authority = @c_UCCTracking  OUTPUT
            , @n_err       = @n_err          OUTPUT
            , @c_errmsg    = @c_errmsg       OUTPUT
      END TRY
      BEGIN CATCH
         SET @n_err = 552952
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing nspGetRight - UCCTracking. (lsp_PostCCByUCC_Wrapper)'
                       + '( ' + @c_errmsg + ' )'
      END CATCH    
                   
      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_continue = 3      
         GOTO EXIT_SP
      END    

      IF @c_UCCTracking = '1'
      BEGIN
         BEGIN TRY      
            EXECUTE isp_AdjustStock        
                  @c_StockTakeKey = @c_StockTakeKey 
               ,  @b_success      = @b_Success  OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_err = 552953
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing isp_AdjustStock. (lsp_PostCCByUCC_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
         END CATCH    
                  
         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END 

         SET @b_postucc = 1
      END
      ELSE
      BEGIN
         BEGIN TRY
            EXEC nspGetRight
                 @c_Facility  = ''
               , @c_StorerKey = @c_StorerKey
               , @c_sku       = NULL
               , @c_ConfigKey = 'Allow_UCC_CC_Adj_Posting'
               , @b_Success   = @b_Success                  OUTPUT
               , @c_authority = @c_CCAdjPostByUCC           OUTPUT
               , @n_err       = @n_err                      OUTPUT
               , @c_errmsg    = @c_errmsg                   OUTPUT
         END TRY
         BEGIN CATCH
            SET @n_err = 552954
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing nspGetRight - Allow_UCC_CC_Adj_Posting. (lsp_PostCCByUCC_Wrapper)'
                          + '( ' + @c_errmsg + ' )'
         END CATCH    
                   
         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END        

         IF @c_CCAdjPostByUCC = '1'
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END

            BEGIN TRY      
               EXECUTE isp_CCPostingByAdjustment_UCC        
                     @c_CCKey = @c_StockTakeKey 
                  ,  @b_success      = @b_Success  OUTPUT
                  ,  @c_TaskDetailKey= ''
            END TRY

            BEGIN CATCH
               SET @n_err = 552955
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing isp_CCPostingByAdjustment_UCC. (lsp_PostCCByUCC_Wrapper)'
                              + '( ' + @c_errmsg + ' )'
            END CATCH    
                  
            IF @b_success = 0 OR @n_Err <> 0        
            BEGIN        
               SET @n_continue = 3      
               GOTO EXIT_SP
            END 

            SET @b_postucc = 1
         END
      END

      IF @b_postucc = 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 552956
         SET @c_ErrMsg =  'NSQL' +CONVERT(CHAR(6),@n_err) + ': Posting by UCC via Adjustment Failed! (lsp_PostCCByUCC_Wrapper)'
         GOTO EXIT_SP
      END

      BEGIN TRY      
         UPDATE STOCKTAKESHEETPARAMETERS WITH (ROWLOCK)
            SET [Protect] = 'Y'
               ,[PassWord]= 'POSTED' 
               ,[Status]  = '9'
               ,[EditWho] = @c_UserName
               ,[EditDate]= GETDATE()
         WHERE StockTakeKey = @c_StockTakeKey
      END TRY

      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_err = 552957
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Update STOCKTAKESHEETPARAMETERS Fail. (lsp_CloseStockTake_Wrapper)'
                        + '( ' + @c_errmsg + ' )'

         GOTO EXIT_SP
      END CATCH    
          
      SET @c_ErrMsg = 'UCC Cycle Count was posted successfully via Adjustments.'
   
   END TRY

   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_PostCCByUCC_Wrapper'
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