SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: lsp_WM_Get_SKU_Upload_Path                              */
/* Creation Date: 11-Sep-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Return Multiple URL Link for SKU Image                      */
/*                                                                      */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 05-Dec-2019 Shong    1.1   Bug Fixed                                 */
/* 10-Feb-2021 mingle01 1.2   Add Big Outer Begin try/Catch             */
/* 2021-02-15  Wan01    1.3   Execute Login if @c_UserName<>SUSER_SNAME()*/
/*                            Return @b_Success=0 if @n_Continue=3      */
/* 2023-06-07  Wan02    1.4   LFWM-4273 - PROD & UAT - TH UQNMD - SCE   */
/*                            Image Upload-not show photo after uploaded*/
/*                            DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [WM].[lsp_WM_Get_SKU_Upload_Path]
     @c_Storerkey          NVARCHAR(15)
   , @c_SKU                NVARCHAR(20)
   , @c_SKU_PATH           NVARCHAR(500) ='' OUTPUT 
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
         , @c_SQL             NVARCHAR(2000)
         , @c_SQL_Parm        NVARCHAR(2000) 

   DECLARE @c_NSQLDescrip     NVARCHAR(215), 
           @c_SKUImageURL     NVARCHAR(1000), 
           @c_CustStoredProc  NVARCHAR(100) = ''

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1     --(Wan01)
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_SKU_PATH = ISNULL(@c_SKU_PATH, '')                                        --(Wan02)
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
   --(Wan01) - END
   
   --(mingle01) - START
   BEGIN TRY
      SET @c_CustStoredProc = ''
      SELECT @c_CustStoredProc = ISNULL(SValue,'')
      FROM StorerConfig (NOLOCK)
      WHERE ConfigKey='GetSKUPath'
      AND SValue > ''
      AND StorerKey = @c_Storerkey
      IF @c_CustStoredProc = ''
      BEGIN
         SET @c_CustStoredProc = ''
         SELECT @c_CustStoredProc = ISNULL(SValue,'')
         FROM StorerConfig (NOLOCK)
         WHERE ConfigKey='GetSKUPath'
         AND SValue > ''
         AND StorerKey = 'ALL'      
      END
      
      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.sysobjects WHERE  id = OBJECT_ID('WM.lsp_Get_SCE_SKU_Upload_Path') 
                      AND OBJECTPROPERTY(id ,N'IsProcedure') = 1 )
      BEGIN
         GOTO URL_STANDARD
      END 
      
      IF @c_CustStoredProc <> ''                                                    --(Wan02)-START
      BEGIN
         SET @c_SQL = N'EXEC ' +  @c_CustStoredProc  + 
               '   @c_Storerkey = @c_Storerkey' + 
               ' , @c_SKU = @c_SKU ' + 
               ' , @c_SKU_PATH = @c_SKU_PATH  OUTPUT ' + 
               ' , @c_UserName = @c_UserName' + 
               ' , @b_Success = @b_Success OUTPUT ' +   
               ' , @n_err = @n_Err OUTPUT ' +  
               ' , @c_ErrMsg = @c_ErrMsg OUTPUT '
             
         SET @c_SQL_Parm = 
               N'  @c_Storerkey NVARCHAR(15) ' + 
               N', @c_SKU NVARCHAR(20) ' + 
               N', @c_SKU_PATH NVARCHAR(500) OUTPUT ' + 
               N', @c_UserName NVARCHAR(128) ' +   
               N', @b_Success INT OUTPUT ' + 
               N', @n_err INT OUTPUT ' + 
               N', @c_ErrMsg NVARCHAR(255) OUTPUT '   
       
         EXEC sp_ExecuteSQL @c_SQL, @c_SQL_Parm, @c_Storerkey, @c_SKU, @c_SKU_PATH OUTPUT, @c_UserName, @b_Success OUTPUT, @n_err OUTPUT, @c_ErrMsg OUTPUT
      
         GOTO EXIT_SP
      END                                                                           --(Wan02)-END                                                                              
      ---  URL_STANDARD ---
      URL_STANDARD:   

      SET @c_NSQLDescrip = ''
      SELECT @c_NSQLDescrip = NSQLDescrip
      FROM NSQLCONFIG (NOLOCK)
      WHERE ConfigKey='SkuImageServer'
      AND NSQLValue='1'
      
      IF @c_NSQLDescrip > ''
      BEGIN
         SET @c_SKU_PATH = @c_NSQLDescrip + CASE WHEN RIGHT(@c_NSQLDescrip,1) = '/' THEN '' ELSE '/' END + @c_Storerkey       
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