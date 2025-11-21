SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_CCGenTagNo_Wrapper                              */  
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
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */
/* 2021-02-05   mingle01 1.1  Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_CCGenTagNo_Wrapper]  
   @c_StockTakeKey      NVARCHAR(10)
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
         , @n_EmptyTag        INT = 0

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
      BEGIN TRY      
         EXECUTE dbo.ispGenTagNo        
            @c_StockTakeKey = @c_StockTakeKey         
      END TRY
      BEGIN CATCH
         SET @n_continue = 3      
         SET @n_err = 550351
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ispGenTagNo. (lsp_CCGenTagNo_Wrapper)'
                       + '( ' + @c_errmsg + ' )'
         GOTO EXIT_SP
      END CATCH    

      SET @n_Count = 0
      SET @n_EmptyTag = 0
      SELECT @n_Count    = COUNT(1)
            ,@n_EmptyTag = ISNULL(SUM(CASE WHEN ISNULL(RTRIM(TagNo),'') = '' THEN 1 ELSE 0 END),0)
      FROM CCDETAIL WITH (NOLOCK)
      WHERE cckey = @c_StockTakeKey
   
      IF @n_Count > 0 AND @n_EmptyTag = 0 
      BEGIN
         SET @c_ErrMsg = 'Cycle Count Ref #: ' + @c_StockTakeKey + CHAR(13)
                       + 'Tag # is generated Successfully'  
         GOTO EXIT_SP
      END
      
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_CCGenTagNo_Wrapper'
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