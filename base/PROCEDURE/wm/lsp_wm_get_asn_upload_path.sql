SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: lsp_WM_Get_ASN_Upload_Path                              */
/* Creation Date: 11-Sep-2019                                           */
/* Copyright: Maersk                                                    */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Return Multiple URL Link for SKU Image                      */
/*        :                                                             */
/* Called By: WM.lsp_Get_SCE_ASN_Upload_Path                            */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch             */
/* 2021-02-15  Wan01    1.1   Execute Login if @c_UserName<>SUSER_SNAME()*/
/*                            Return @b_Success=0 if @n_Continue=3      */
/* 2023-07-11  Wan02    1.2   LFWM-2145 - UAT - TW  Unknown error when  */
/*                            uploading Image to ASN                    */
/*                            Devops Comnined Script                    */
/************************************************************************/
CREATE   PROC [WM].[lsp_WM_Get_ASN_Upload_Path]
     @c_Storerkey          NVARCHAR(15)
   , @c_Receiptkey         NVARCHAR(10)                                             --(Wan02)
   , @c_ASN_PATH           NVARCHAR(500) ='' OUTPUT 
   , @c_UserName           NVARCHAR(128) =''   
   , @b_Success            INT = 1           OUTPUT  
   , @n_err                INT = 0           OUTPUT                                                                                                             
   , @c_ErrMsg             NVARCHAR(255)= '' OUTPUT                 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT
         , @c_SQL             NVARCHAR(2000)= ''
         , @c_SQL_Parm        NVARCHAR(2000)= '' 

   DECLARE @c_NSQLDescrip     NVARCHAR(215) = ''
         , @c_SKUImageURL     NVARCHAR(1000)= '' 
         , @c_CustStoredProc  NVARCHAR(100) = ''
         
         , @c_Containerkey    NVARCHAR(18)  = ''                                    --(Wan02)
         , @c_POkey           NVARCHAR(18)  = ''                                    --(Wan02) 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1     --(Wan01)
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @n_Err = 0 
   --(Wan01) - START
   IF SUSER_SNAME() <> @c_UserName 
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
   
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
      
      EXECUTE AS LOGIN = @c_UserName
   END
   --(Wan02) - END (Wan01) - END
   
   --(mingle01) - START
   BEGIN TRY
      SELECT @c_CustStoredProc = ISNULL(SValue,'')
      FROM StorerConfig (NOLOCK)
      WHERE ConfigKey='GetASNPath'
      AND SValue > ''
      AND StorerKey = @c_Storerkey
      AND Option5 NOT IN ('', NULL)                                                 --(Wan02)   

      IF @c_CustStoredProc = ''
      BEGIN
         SET @c_CustStoredProc = ''
         SELECT @c_CustStoredProc = ISNULL(SValue,'')
         FROM StorerConfig (NOLOCK)
         WHERE ConfigKey='GetASNPath'
         AND SValue > ''
         AND StorerKey = 'ALL' 
         AND Option5 NOT IN ('', NULL)                                              --(Wan02)    
      END
      
      IF @c_CustStoredProc = ''
      BEGIN
         GOTO URL_STANDARD
      END 
      
      IF NOT EXISTS (SELECT 1 
                     FROM dbo.sysobjects WHERE  id = OBJECT_ID(@c_CustStoredProc) 
                     AND OBJECTPROPERTY(id ,N'IsProcedure') = 1 )
      BEGIN
         GOTO URL_STANDARD
      END 
       
      SET @c_SQL = N'EXEC ' +  @c_CustStoredProc  
                 +'  @c_Storerkey  = @c_Storerkey'  
                 +', @c_Receiptkey = @c_Receiptkey'                                 --(Wan02)  
                 +', @c_ASN_PATH   = @c_ASN_PATH  OUTPUT'   
                 +', @c_UserName   = @c_UserName'  
                 +', @b_Success    = @b_Success OUTPUT'    
                 +', @n_err        = @n_Err     OUTPUT'   
                 +', @c_ErrMsg     = @c_ErrMsg  OUTPUT'
             
      SET @c_SQL_Parm= 
                     + N'  @c_Storerkey  NVARCHAR(15)'   
                     + N', @c_Receiptkey NVARCHAR(10)'                              --(Wan02)
                     + N', @c_ASN_PATH   NVARCHAR(500)   OUTPUT' 
                     + N', @c_UserName   NVARCHAR(128)'     
                     + N', @b_Success    INT             OUTPUT'
                     + N', @n_err        INT             OUTPUT'
                     + N', @c_ErrMsg     NVARCHAR(255)   OUTPUT'   
       
      EXEC sp_ExecuteSQL @c_SQL, @c_SQL_Parm
                        ,@c_Storerkey
                        ,@c_Receiptkey                                              --(Wan02)
                        ,@c_ASN_PATH   OUTPUT
                        ,@c_UserName
                        ,@b_Success    OUTPUT
                        ,@n_err        OUTPUT
                        ,@c_ErrMsg     OUTPUT   
      
      GOTO EXIT_SP

      ---  URL_STANDARD ---
      URL_STANDARD:   

      SET @c_NSQLDescrip = ''
      SELECT @c_NSQLDescrip = NSQLDescrip
      FROM NSQLCONFIG (NOLOCK)
      WHERE ConfigKey='ASNImageServer'
      AND NSQLValue='1'
      
      IF @c_NSQLDescrip > ''
      BEGIN
         SELECT @c_Containerkey = RTRIM(ISNULL(r.ContainerKey,''))
               ,@c_POKey = RTRIM(ISNULL(r.POKey,''))
         FROM dbo.RECEIPT AS r WITH (NOLOCK)
         WHERE r.ReceiptKey = @c_Receiptkey
         
         SET @c_ASN_PATH = @c_NSQLDescrip + CASE WHEN RIGHT(@c_NSQLDescrip,1) = '/' THEN '' ELSE '/' END + RTRIM(@c_Storerkey) 
                         + '/IN/' +  CASE WHEN @c_Containerkey<>'' THEN @c_Containerkey + '_' 
                                          --WHEN @c_POKey<>'' THEN @c_POKey + '_'
                                          ELSE @c_Receiptkey + '_'
                                          END
                         + @c_Receiptkey    
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
      
   EXIT_SP:
   
   --(Wan01) - START
   IF @n_Continue = 3 
   BEGIN
      SET @b_Success = 0
   END
   REVERT
   --(Wan01) - END
END -- procedure

GO