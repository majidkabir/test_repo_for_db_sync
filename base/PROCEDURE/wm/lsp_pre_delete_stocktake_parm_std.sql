SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_Pre_Delete_StockTake_Parm_STD                  */  
/* Creation Date: 24-Jul-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: StockTake Parm Pre-delete process / validation              */  
/*                                                                      */  
/* Called By: StockTake Parm delete                                     */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */
/* 2021-02-08   mingle01 1.1  Add Big Outer Begin try/Catch             */  
/* 2021-02-11   Wan01    1.1  Add Execute Login UserName.. Revert       */
/************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Pre_Delete_StockTake_Parm_STD]
      @c_StorerKey         NVARCHAR(15)
   ,  @c_RefKey1           NVARCHAR(50)  = '' 
   ,  @c_RefKey2           NVARCHAR(50)  = '' 
   ,  @c_RefKey3           NVARCHAR(50)  = '' 
   ,  @c_RefreshHeader     CHAR(1) = 'N' OUTPUT
   ,  @c_RefreshDetail     CHAR(1) = 'N' OUTPUT 
   ,  @b_Success           INT = 1 OUTPUT   
   ,  @n_Err               INT = 0 OUTPUT
   ,  @c_Errmsg            NVARCHAR(255) = ''  OUTPUT
   ,  @c_UserName          NVARCHAR(128) = '' 
   ,  @c_IsSupervisor      CHAR(1) = 'N' 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue          INT,
           @n_starttcnt         INT,
           @c_StockTakeKey     NVARCHAR(10) = ''
   
   SELECT @n_starttcnt=@@TRANCOUNT, @n_err=0, @b_success=1, @c_errmsg='', @n_continue=1
   SET @c_RefreshHeader = 'Y'
   
   --(Wan01) - START Login @c_UserName as there is Delete statement
   SET @n_Err = 0 
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
   
   --(mingle01) - START
   BEGIN TRY         
      SET @c_StockTakeKey = @c_RefKey1
      
      IF @n_continue IN(1,2)
      BEGIN          
         IF EXISTS(SELECT 1 
                  FROM CCDETAIL (NOLOCK)
                  WHERE CCKey = @c_StockTakeKey
                  AND (Finalizeflag = 'Y' OR FinalizeFlag_Cnt2 = 'Y' OR FinalizeFlag_Cnt3 = 'Y'))
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 551151
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Cannot delete finalized CCDetail. (lsp_Pre_Delete_StockTake_Parm_STD)'                
         END
         ELSE
         BEGIN
            DELETE FROM CCDetail
            WHERE CCKey = @c_StockTakeKey
              
            DELETE FROM NCOUNTER
            WHERE KeyName = 'CSHEET'+RTRIM(@c_StockTakeKey)
         END                         
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END   
   EXIT_SP:
   --REVERT     

   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
   ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_Pre_Delete_StockTake_Parm_STD'  
      --RETURN                --(Wan01) 
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      --RETURN                --(Wan01)
   END
   REVERT              
END -- End Procedure

GO