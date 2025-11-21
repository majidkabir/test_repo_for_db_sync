SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_Pre_Delete_MBOLDetail_STD                      */  
/* Creation Date: 01-Nov-2019                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: MBOLDetail Pre-delete process / validation                  */  
/*                                                                      */  
/* Called By: LOadplandetail delete                                     */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */ 
/* 2021-02-25  Wan01    1.1   Add Big Outer Try/Catch                   */ 
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Pre_Delete_MBOLDetail_STD]
      @c_StorerKey         NVARCHAR(15)
   ,  @c_RefKey1           NVARCHAR(50)  = '' 
   ,  @c_RefKey2           NVARCHAR(50)  = '' 
   ,  @c_RefKey3           NVARCHAR(50)  = '' 
   ,  @c_RefreshHeader     CHAR(1) = 'N'        OUTPUT
   ,  @c_RefreshDetail     CHAR(1) = 'N'        OUTPUT 
   ,  @b_Success           INT = 1              OUTPUT   
   ,  @n_Err               INT = 0              OUTPUT
   ,  @c_Errmsg            NVARCHAR(255) = ''   OUTPUT
   ,  @c_UserName          NVARCHAR(128) = '' 
   ,  @c_IsSupervisor      CHAR(1) = 'N' 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                 INT = 1
         , @n_StartTCnt                INT = @@TRANCOUNT

         , @n_Allow                    INT = 0

         , @c_MBOLKey                  NVARCHAR(10) = ''
         , @c_MBOLLineNumber           NVARCHAR(5)  = ''
         , @c_Orderkey                 NVARCHAR(10) = '' 

   SET @n_err=0
   SET @b_success=1
   SET @c_errmsg='' 
   SET @c_RefreshDetail = 'Y'
   
   --(Wan01) - START
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
   
   BEGIN TRY
      SET @c_MBOLKey = ISNULL(@c_RefKey1,'')
      SET @c_MBOLLineNumber = ISNULL(@c_RefKey2,'')

      IF @c_MBOLKey = '' AND @c_MBOLLineNumber = ''
      BEGIN
         GOTO EXIT_SP  
      END
         
      IF EXISTS(  SELECT 1 
                  FROM MBOL WITH (NOLOCK)
                  WHERE MBOLkey = @c_MBOLkey
                  AND [Status] = '9' 
                  )
      BEGIN
         SET @n_continue = 3
         SET @n_err = 557451
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Cannot delete shipped ' + @c_MBOLkey + ' (lsp_Pre_Delete_MBOLDetail_STD) |' + @c_MBOLkey    
         GOTO EXIT_SP             
      END    
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(Wan01) - END
EXIT_SP:

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
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_Pre_Delete_MBOLDetail_STD'
      --RETURN             --(Wan01)
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      --RETURN             --(Wan01)
   END    
   REVERT          
END -- End Procedure

GO