SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_PostCC_Wrapper                                  */  
/* Creation Date: 14-MAR-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-263 - Stored Procedures for Release 2 Feature -         */
/*          Inventory  Cycle Count  Stock Take Parameters                */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.2                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */
/* 2021-02-05  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/ 
/* 2022-04-13  Wan01    1.2   Fixed infinity Loop in COMMIT TRAN         */
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_PostCC_Wrapper]  
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

         , @n_Count           INT = 0 
         , @c_CCSheetNo_Min   NVARCHAR(10) = ''
         , @c_CCSheetNo_Max   NVARCHAR(10) = ''
         
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
      SELECT @n_Count =COUNT(LOTxLOCxID.LOT)
      FROM LOTxLOCxID    WITH (NOLOCK)
      JOIN WITHDRAWSTOCK WITH (NOLOCK) ON ( LOTxLOCxID.Lot = WITHDRAWSTOCK.Lot )
                                       AND( LOTxLOCxID.Loc = WithDrawStock.Loc )
                                       AND( LOTxLOCxID.ID  = WithDrawStock.ID )
      JOIN LOT           WITH (NOLOCK) ON ( LOTxLOCxID.Lot = LOT.Lot)
      WHERE LOTxLOCxID.QtyAllocated + LOT.QtyPreAllocated + LOTxLOCxID.QtyPicked > 0
      AND   EXISTS (SELECT 1 
                    FROM TEMPSTOCK WITH (NOLOCK)
                    JOIN CCDETAIL  WITH (NOLOCK) ON (TEMPSTOCK.Sourcekey = CCDETAIL.CCDetailKey )
                    WHERE TEMPSTOCK.Storerkey = LOTxLOCxID.Storerkey
                    AND  TEMPSTOCK.Sku = LOTxLOCxID.Sku  
                    AND  CCDETAIL.CCkey = @c_StockTakeKey 
                    )
      AND   WITHDRAWSTOCK.SourceType = 'CC Withdrawal (' +  RTRIM(@c_StockTakeKey) + ')'

      IF @n_Count > 0
      BEGIN
         SET @n_continue = 3 
         SET @n_err = 552901 
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': There is still outstanding allocated transactions which haven''t CLOSE yet! Process Terminated. (lsp_PostCC_Wrapper)'
         GOTO EXIT_SP
      END

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      BEGIN TRY      
         EXECUTE nsp_CCWithdrawStock        
            @b_success = @b_success 
         ,  @c_StockTakeKey = @c_StockTakeKey         
      END TRY

      BEGIN CATCH
         SET @n_err = 552902
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing nsp_CCWithdrawStock. (lsp_PostCC_Wrapper)'
                        + '( ' + @c_errmsg + ' )'
      END CATCH    

      IF @b_success = 0
      BEGIN
         SET @n_err = 552903
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': CC Withdraw Stock Fail. (lsp_PostCC_Wrapper)'
      END
                   
      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_continue = 3      
         GOTO EXIT_SP
      END        

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      BEGIN TRY      
         EXECUTE nsp_InsertStock        
            @b_success = @b_success 
         ,  @c_StockTakeKey = @c_StockTakeKey   
      END TRY

      BEGIN CATCH
         SET @n_err = 552904
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing nsp_InsertStock. (lsp_PostCC_Wrapper)'
                        + '( ' + @c_errmsg + ' )'
      END CATCH    
                  
      IF @b_success = 0
      BEGIN
         SET @n_err = 552905
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': CC Insert Stock Fail. (lsp_PostCC_Wrapper)'
      END
                
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
         SET @n_err = 552906
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Update STOCKTAKESHEETPARAMETERS Fail. (lsp_PostCC_Wrapper)'
                        + '( ' + @c_errmsg + ' )'

         GOTO EXIT_SP
      END CATCH    
   END TRY

   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH     
   --(mingle01) - END
EXIT_SP:
   --(Wan01) - START
   IF (XACT_STATE()) = -1                                      
   BEGIN
      SET @n_Continue = 3
      ROLLBACK TRAN
   END 
   --(Wan01) - END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt    --(Wan01)
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_PostCC_Wrapper'
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