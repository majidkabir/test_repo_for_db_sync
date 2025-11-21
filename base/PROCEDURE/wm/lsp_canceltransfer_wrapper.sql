SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_CancelTransfer_Wrapper                         */  
/* Creation Date: 06-Apr-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Cancel Transfer                                             */  
/*                                                                      */  
/* Called By: Transfer screen                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */ 
/* 2021-02-05   mingle01 1.1  Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_CancelTransfer_Wrapper]
    @c_Transferkey NVARCHAR(10)  
   ,@b_Success     INT = 1 OUTPUT 
   ,@n_Err         INT = 0 OUTPUT
   ,@c_ErrMsg      NVARCHAR(250) = '' OUTPUT
   ,@c_UserName    NVARCHAR(128) = ''
AS
BEGIN 
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
    
   DECLARE @n_err2 INT
    
   SET @n_Err = 0 

   --(mingle01) - START   
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
   EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
   IF @n_Err <> 0 
   BEGIN
      GOTO EXIT_SP
   END
                
   EXECUTE AS LOGIN = @c_UserName
   END
   --(mingle01) - END
    
   --(mingle01) - START
   BEGIN TRY    
      DECLARE @n_Continue              INT
            ,@n_starttcnt             INT

      SELECT @n_starttcnt=@@TRANCOUNT, @n_err=0, @b_success=1, @c_errmsg='', @n_continue=1
    
      IF @@TRANCOUNT = 0
         BEGIN TRAN

      IF @n_continue IN(1,2)
      BEGIN      
         BEGIN TRY      
            UPDATE Transfer WITH (ROWLOCK)
            SET Status = 'CANC'
            WHERE TransferKey = @c_Transferkey
         END TRY
    
         BEGIN CATCH
            IF @n_err = 0 
            BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err2 = ERROR_NUMBER()
                  SELECT @c_ErrMsg = ERROR_MESSAGE()
                  SELECT @n_err = 550251
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': ' + RTRIM(ISNULL(@c_errmsg,''))  + ' (lsp_CancelTransfer_Wrapper)' + ' (' 
                              + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(ISNULL(CONVERT(NVARCHAR(50),@n_err2),''))) + ' )'    
            END
         END CATCH             
      END

   END TRY

   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
EXIT_SP: 
    IF @n_continue=3  -- Error Occured - Process And Return  
    BEGIN  
       SELECT @b_success = 0  
       IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt  
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
       execute nsp_logerror @n_err, @c_errmsg, 'lsp_CancelTransfer_Wrapper'  
       --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
       RETURN  
    END  
    ELSE  
    BEGIN  
       SELECT @b_success = 1  
       WHILE @@TRANCOUNT > @n_starttcnt  
       BEGIN  
          COMMIT TRAN  
       END  
       RETURN  
    END  
    REVERT              
END

GO