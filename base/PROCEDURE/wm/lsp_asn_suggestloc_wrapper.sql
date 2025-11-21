SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_ASN_SuggestLoc_Wrapper                          */                                                                                  
/* Creation Date: 2020-04-20                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2080 - UAT ASN  Suggest PA location function           */
/*        : implementation at ASN                                       */
/*                                                                      */
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.0                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 2021-02-05  mingle01 1.1  Add Big Outer Begin try/Catch             */
/*                           Execute Login if @c_UserName<>SUSER_SNAME()*/  
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_ASN_SuggestLoc_Wrapper]                                                                                                                     
      @c_ReceiptKey           NVARCHAR(10)         
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)= '' OUTPUT   
   ,  @c_UserName             NVARCHAR(128)= ''  
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt            INT = @@TRANCOUNT  
         ,  @n_Continue             INT = 1

         ,  @c_SQL                  NVARCHAR(1000) = ''
         ,  @c_SQLParms             NVARCHAR(1000) = ''

         ,  @c_Facility             NVARCHAR(5)    = ''
         ,  @c_Storerkey            NVARCHAR(15)   = ''

         ,  @c_SuggestPALoc_SP      NVARCHAR(30)   = ''

   SET @b_Success = 1
   SET @n_Err     = 0
               
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
      SELECT @c_Facility = RH.Facility
            ,@c_Storerkey= RH.Storerkey
      FROM RECEIPT RH WITH (NOLOCK)
      WHERE RH.ReceiptKey = @c_ReceiptKey

      SELECT @c_SuggestPALoc_SP = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'SuggestPALoc_SP')

      IF ISNULL(@c_SuggestPALoc_SP, 0) = '0' 
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 557801 
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': No Custom SP setup to suggest PA Loc.'
                       + ' (lsp_ASN_SuggestLoc_Wrapper)'  
         GOTO EXIT_SP   
      END
  
      IF NOT EXISTS (SELECT 1 FROM sys.objects (NOLOCK) WHERE object_id = OBJECT_ID(@c_SuggestPALoc_SP))
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 557802 
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Custom SP ' + @c_SuggestPALoc_SP + ' not found.'
                       + ' (lsp_ASN_SuggestLoc_Wrapper) |' + @c_SuggestPALoc_SP
         GOTO EXIT_SP  
      END

      BEGIN TRY
         SET @c_SQL = N'EXEC ' + @c_SuggestPALoc_SP + ' @c_ReceiptKey = @c_Receiptkey, @b_Success = @b_Success OUTPUT'
                    + ', @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT'

         SET @c_SQLParms = N'@c_Receiptkey   NVARCHAR(10)'
                         + ',@b_Success      INT   OUTPUT'
                         + ',@n_Err          INT   OUTPUT'
                         + ',@c_ErrMsg       NVARCHAR(255)  OUTPUT'

         EXEC sp_ExecuteSql @c_SQL
                           ,@c_SQLParms
                           ,@c_Receiptkey
                           ,@b_Success OUTPUT
                           ,@n_Err     OUTPUT
                           ,@c_ErrMsg  OUTPUT
      END TRY
      BEGIN CATCH
         SET @n_Continue = 3
         SET @c_errmsg = ERROR_MESSAGE()
         --SET @n_err = 557803
         --SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ' + @c_SuggestPALoc_SP
         --              + '.(lsp_ASN_SuggestLoc_Wrapper) |' + @c_SuggestPALoc_SP
         --GOTO EXIT_SP
      END CATCH   

      IF @b_Success = 0 OR @n_Continue = 3
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 557803
         IF ISNULL(@c_errmsg,'') <> '' 
         BEGIN
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing Custom SP'
                          + '.(lsp_ASN_SuggestLoc_Wrapper) ( ' + @c_errmsg+ ' )'
         END
         ELSE
         BEGIN
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ' + @c_SuggestPALoc_SP
                          + '.(lsp_ASN_SuggestLoc_Wrapper) |' + @c_SuggestPALoc_SP
         END
         GOTO EXIT_SP
      END
 
      IF @c_errmsg = ''
      BEGIN
         SET @c_errmsg = 'Suggest PA Loc Done!'
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ASN_SuggestLoc_Wrapper'
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