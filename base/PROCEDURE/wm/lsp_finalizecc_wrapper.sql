SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_FinalizeCC_Wrapper                              */  
/* Creation Date: 04-APR-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-263 - Stored Procedures for Release 2 Feature -         */
/*          Inventory  Cycle Count  Stock Take Parameters                */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.3                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2020-11-23  Wan01    1.1   LFWM-2441- UAT  Philippines  PH SCE Error  */
/*                            in Finalizing Cycle Count and No Posting by*/
/*                            Withdrawal or Deposit                      */
/* 2020-12-10  Wan02    1.1   Add Big Outer Begin Try..End Try to enable */
/*                            Revert when SP Raise error                 */
/*                      1.1   Fixed Uncommitable Transaction             */
/* 2021-01-15  Wan03    1.2   Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2021-12-02  Wan04    1.3   WMS-18332 - [TW]LOR_CycleCount_CR          */
/*             Wan04    1.3   DevOps Combine Script                      */
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_FinalizeCC_Wrapper]  
   @c_StockTakeKey         NVARCHAR(10)
,  @n_CountNo              INT
,  @b_Success              INT          = 1   OUTPUT   
,  @n_Err                  INT          = 0   OUTPUT
,  @c_Errmsg               NVARCHAR(255)= ''  OUTPUT
,  @n_WarningNo            INT          = 0   OUTPUT
,  @c_ProceedWithWarning   CHAR(1)      = 'N' 
,  @c_UserName             NVARCHAR(128)= ''
AS  
BEGIN
   --Wan01 - Turn Of Truncate Message  
   SET NOCOUNT ON                                                       
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @n_SumQty          INT = 0 
         
   SET @b_Success = 1
   SET @c_ErrMsg = ''

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
   
   BEGIN TRAN        --(Wan04)
   BEGIN TRY   --(Wan02) - START
      IF @c_ProceedWithWarning = 'N'
      BEGIN
         IF @n_CountNo = 0 
         BEGIN
            SET @n_continue = 3      
            SET @n_err = 551551
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Can''t identify Stock Take Count Number. (lsp_FinalizeCC_Wrapper)'
            GOTO EXIT_SP
         END
      END

      IF @n_Continue IN (1,2) AND (@c_ProceedWithWarning = 'N' OR (@n_WarningNo < 1))
      BEGIN
         SET @n_SumQty = 0
         SELECT @n_SumQty = ISNULL(SUM(CASE WHEN @n_CountNo = 1
                                            THEN Qty 
                                            WHEN @n_CountNo = 2
                                            THEN Qty_Cnt2 
                                            WHEN @n_CountNo = 3
                                            THEN Qty_Cnt3 
                                            END),0)
         FROM CCDETAIL WITH (NOLOCK)
         WHERE CCkey = @c_StockTakeKey

         IF @n_SumQty = 0
         BEGIN
            SET @n_WarningNo = 1   
            SET @n_continue = 3   
            SET @c_errmsg = 'ZERO(0) Count Qty. Are You Sure to Finalize Count ' 
                          + CONVERT(CHAR(1), @n_CountNo) + '?'
            GOTO EXIT_SP
         END
      END

      IF @n_Continue IN (1,2) --AND @c_ProceedWithWarning = 'Y'
      BEGIN
         BEGIN TRY      
            EXECUTE dbo.ispFinalizeStkTakeCount        
               @c_StockTakeKey = @c_StockTakeKey 
            ,  @n_CountNo      = @n_CountNo        
         END TRY

         BEGIN CATCH
            SET @n_continue = 3      
            SET @n_err = 551552
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ispFinalizeStkTakeCount. (lsp_FinalizeCC_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
            GOTO EXIT_SP
         END CATCH   

         BEGIN TRY      
            UPDATE STOCKTAKESHEETPARAMETERS WITH (ROWLOCK)
               SET [Status]  = '3'
                  ,[ArchiveCop] = NULL
                  ,[EditWho] = @c_UserName
                  ,[EditDate]= GETDATE()
            WHERE StockTakeKey = @c_StockTakeKey
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_err = 551553
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Update STOCKTAKESHEETPARAMETERS Fail. (lsp_FinalizeCC_Wrapper)'
                           + '( ' + @c_errmsg + ' )'

            GOTO EXIT_SP
         END CATCH 

         BEGIN TRY      
            DELETE NCOUNTER 
            WHERE Keyname = 'CSHEET' + RTRIM(@c_StockTakeKey)
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_err = 551554
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Delete NCOUNTER Fail. (lsp_FinalizeCC_Wrapper)'
                           + '( ' + @c_errmsg + ' )'

            GOTO EXIT_SP
         END CATCH 

         SET @c_ErrMsg = 'Count ' + CONVERT(NVARCHAR(1), @n_CountNo) + CHAR(13)
                        + 'is finalized Successfully!'  
         GOTO EXIT_SP
      END
   END TRY
   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg = 'Finalize CC fail. (lsp_FinalizeCC_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      GOTO EXIT_SP
   END CATCH   --(Wan02) - END
   EXIT_SP:
   
   --(Wan04) - Move up
   IF (XACT_STATE()) = -1     --(Wan02) - START  
   BEGIN  
      SET @n_Continue=3
      ROLLBACK TRAN;  
   END;                       --(Wan02) - END 
      
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN                              
      SET @b_Success = 0
      IF  @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt         --(Wan04)
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt  --@n_Continue=3
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_FinalizeCC_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END

      SET @n_WarningNo = 0
   END

   REVERT      
END  

GO