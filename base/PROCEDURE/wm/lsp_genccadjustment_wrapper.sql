SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_GenCCAdjustment_Wrapper                         */  
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
CREATE PROCEDURE [WM].[lsp_GenCCAdjustment_Wrapper]  
   @c_StockTakeKey      NVARCHAR(10)
,  @c_ByPalletLevel     NVARCHAR(10) = 'N' -- 1)    
,  @c_IDOnHold          NVARCHAR(10) = 'N'
,  @b_Success           INT          = 1   OUTPUT   
,  @n_Err               INT          = 0   OUTPUT
,  @c_Errmsg            NVARCHAR(255)= ''  OUTPUT
,  @c_UserName          NVARCHAR(128)= ''
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

         , @n_Count           INT = 0 
         , @c_CountNo         CHAR(1) = '1'
         
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
      SELECT @c_CountNo = CONVERT(CHAR(1), ISNULL(FinalizeStage, 0))
      FROM STOCKTAKESHEETPARAMETERS WITH (NOLOCK)
      WHERE StockTakeKey = @c_StockTakeKey

      IF @c_CountNo = '0'
      BEGIN
         SET @n_continue = 3 
         SET @n_err = 552251
         SET @c_ErrMsg= 'NSQL' +CONVERT(CHAR(6),@n_err) + ': None of the count was FINALISED, Please check with administrator.'
                      + ' (lsp_GenCCAdjustment_Wrapper)' 
         GOTO EXIT_SP
      END

      IF EXISTS ( SELECT 1  
                  FROM ADJUSTMENT WITH (NOLOCK) 
                  WHERE CustomerRefNo = @c_StockTakeKey 
                )
      BEGIN
         SET @n_continue = 3 
         SET @n_err = 552252
         SET @c_ErrMsg= 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Adjustment Transaction Already Generated.'
                      + ' (lsp_GenCCAdjustment_Wrapper)' 
         GOTO EXIT_SP
      END

      SET @n_Count = 0
      BEGIN TRY      
         EXECUTE @n_Count = ispCheckOutstandingOrders        
            @c_StockTakeKey = @c_StockTakeKey         
         ,  @c_CountNo      = @c_CountNo
         ,  @c_ByPalletLevel= @c_ByPalletLevel 
      END TRY

      BEGIN CATCH
         SET @n_err = 552253
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ispCheckOutstandingOrders. (lsp_GenCCAdjustment_Wrapper)'
                       + '( ' + @c_errmsg + ' )'
      END CATCH    
                   
      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_continue = 3      
         GOTO EXIT_SP
      END        

      IF @n_Count > 0 
      BEGIN
         SET @n_continue = 3 
         SET @n_err = 552254
         SET @c_ErrMsg= 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Outstanding record(s) found!'
                      + ' Please close all the Shipment Orders before you proceed. (lsp_GenCCAdjustment_Wrapper)' 
         GOTO EXIT_SP
      END

      BEGIN TRY      
         EXECUTE ispGenCCAdjustmentPost_MultiCnt        
               @c_StockTakeKey = @c_StockTakeKey 
            ,  @c_CountNo      = @c_CountNo
            ,  @b_success      = @b_Success  OUTPUT
            ,  @c_TaskDetailKey= ''
            ,  @c_ByPalletLevel= @c_ByPalletLevel   
            ,  @c_IDOnHold     = @c_IDOnHold        
      END TRY

      BEGIN CATCH
         SET @n_err = 552255
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ispGenCCAdjustmentPost_MultiCnt. (lsp_GenCCAdjustment_Wrapper)'
                        + '( ' + @c_errmsg + ' )'
      END CATCH    
                  
      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_continue = 3      
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
         SET @n_err = 552256
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Update STOCKTAKESHEETPARAMETERS Fail. (lsp_CloseStockTake_Wrapper)'
                        + '( ' + @c_errmsg + ' )'

         GOTO EXIT_SP
      END CATCH    
          
      SET @n_Count = 0
      SELECT @n_Count = COUNT(1)  
      FROM ADJUSTMENT WITH (NOLOCK) 
      WHERE CustomerRefNo = @c_StockTakeKey 
   
      IF @n_Count = 0 
      BEGIN
         SET @c_ErrMsg = 'Stocktake are posted without variance to be adjusted.'
      END
      ELSE
      BEGIN
         SET @c_ErrMsg = 'Adjustment Generated Sucessfully!'
      END
   
   END TRY

   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
EXIT_SP:

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_GenCCAdjustment_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   REVERT      
END  

GO