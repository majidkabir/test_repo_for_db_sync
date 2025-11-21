SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: lsp_WM_Get_ASN_Image_URL                                */
/* Creation Date: 11-Sep-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Return Multiple URL Link for Inbound Images                 */
/*                                                                      */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
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
/* 2021-10-06  Wan02    1.2   DevOps Combine Script                     */
/* 2021-10-06  Wan02    1.2   LFWM-2020 - SIT  ASN image upload SP Issue*/
/* 2023-08-08  Wan03    1.3   LFWM-2145 - UAT - TW  Unknown error when  */
/*                            uploading Image to ASN                    */
/************************************************************************/
CREATE   PROC [WM].[lsp_WM_Get_ASN_Image_URL]
     @c_Storerkey          NVARCHAR(15)  -- Required
   , @c_ReceiptKey         NVARCHAR(10)  -- Required 
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

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   DECLARE @c_NSQLDescrip     NVARCHAR(215), 
           @c_CustStoredProc  NVARCHAR(100) = '',
           @c_SQL             NVARCHAR(2000) = '', 
           @c_SQL_Parm        NVARCHAR(2000) = ''
           
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1              --(Wan01)
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @n_Err = 0 
   
   --(Wan03) - START Need to Use WMCONNECT Admin right to excute xp_dirtree in Sub SP (Wan01) - START
   --IF SUSER_SNAME() <> @c_UserName 
   --BEGIN
   --   EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
   --
   --   IF @n_Err <> 0 
   --   BEGIN
   --      GOTO EXIT_SP
   --   END
   --   
   --   EXECUTE AS LOGIN = @c_UserName
   --END
   --(Wan01) - END
   
   --(mingle01) - START
   BEGIN TRY
      SELECT @c_CustStoredProc = ISNULL(sc.SValue,'')
      FROM dbo.StorerConfig AS sc WITH (NOLOCK)
      WHERE sc.ConfigKey='GetASNURL'
      AND sc.Storerkey = 'ALL'
      AND sc.Option5 IS NOT NULL
      
      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.sysobjects WHERE id = OBJECT_ID(@c_CustStoredProc) 
                      AND OBJECTPROPERTY(id ,N'IsProcedure') = 1 )
      BEGIN
         GOTO URL_STANDARD
      END 
      --(Wan02) - START
      SET @c_SQL = N'EXEC ' +  @c_CustStoredProc  + 
            N'  @c_Storerkey        = @c_Storerkey       ' +
            N', @c_ReceiptKey       = @c_ReceiptKey      ' +
            N', @c_UserName         = @c_UserName        ' +
            N', @b_Success          = @b_Success OUTPUT  ' +      
            N', @n_err              = @n_err     OUTPUT  ' +                                                                                                              
            N', @c_ErrMsg           = @c_ErrMsg  OUTPUT  '      

      SET @c_SQL_Parm = 
            N'  @c_Storerkey          NVARCHAR(15) ' +   
            N', @c_ReceiptKey         NVARCHAR(10) ' +   
            N', @c_UserName           NVARCHAR(128)' +         
            N', @b_Success            INT OUTPUT   ' +
            N', @n_err                INT OUTPUT   ' +                                                                                                          
            N', @c_ErrMsg             NVARCHAR(255) OUTPUT '
       
      EXEC sp_ExecuteSQL @c_SQL, @c_SQL_Parm, 
          @c_Storerkey        
         ,@c_ReceiptKey       
         ,@c_UserName         
         ,@b_Success  OUTPUT        
         ,@n_err      OUTPUT        
         ,@c_ErrMsg   OUTPUT        
      
      GOTO EXIT_SP
      
      URL_STANDARD:
      
      CREATE TABLE #URL (
         SeqNo INT IDENTITY(1,1), 
         URL   NVARCHAR(2000) )

      INSERT INTO #URL VALUES('https://intranetapi.lfuat.net/GenericAPI/GetFile?src=%2BGLq4DAwiIfSKV%2FVqwkCb35eKoWeQCCw')
      --(Wan02) - END
      SELECT @c_ReceiptKey AS ReceiptKey, u.SeqNo, u.URL 
      FROM #URL AS u WITH(NOLOCK)
      ORDER BY u.SeqNo
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
   
   --REVERT --(Wan03)    
   --(Wan01) - END
END -- procedure

GO