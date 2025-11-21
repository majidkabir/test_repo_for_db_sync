SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: lsp_Get_SCE_ASN_Upload_Path                             */
/* Creation Date: 06-Dec-2019                                           */
/* Copyright: Maersk                                                    */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: Return Multiple URL Link for ASN Image                      */
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
/* 2021-02-05  mingle01 1.1  Add Big Outer Begin try/Catch              */ 
/* 2023-07-11  Wan02    1.2   LFWM-2145 - UAT - TW  Unknown error when  */
/*                            uploading Image to ASN                    */
/*                            Devops Comnined Script                    */
/************************************************************************/
CREATE   PROC [WM].[lsp_Get_SCE_ASN_Upload_Path]
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
         
         , @c_Containerkey    NVARCHAR(18)  = ''                                    --(Wan02)
         , @c_POkey           NVARCHAR(18)  = ''                                    --(Wan02) 
 
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_ASN_PATH = ''

   --(mingle01) - START
   BEGIN TRY
      SELECT @c_ASN_PATH = ISNULL(OPTION5,'')
      FROM StorerConfig (NOLOCK)
      WHERE ConfigKey='GetASNPath'
      AND SValue = 'WM.lsp_Get_SCE_ASN_Upload_Path'
      AND OPTION5 IS NOT NULL         
   
      IF ISNULL(RTRIM(@c_ASN_PATH), '') > ''
      BEGIN
         SELECT @c_Containerkey = RTRIM(ISNULL(r.ContainerKey,''))                  --(Wan02) - START
               ,@c_POKey = RTRIM(ISNULL(r.POKey,''))
         FROM dbo.RECEIPT AS r WITH (NOLOCK)
         WHERE r.ReceiptKey = @c_Receiptkey

         SET @c_ASN_PATH = @c_ASN_PATH + '/' + RTRIM(@c_Storerkey) 
                         + '/IN/' +  CASE WHEN @c_Containerkey<>'' THEN @c_Containerkey + '_' 
                                          --WHEN @c_POKey<>'' THEN @c_POKey + '_'
                                          ELSE @c_Receiptkey + '_'
                                          END
                         + @c_Receiptkey                                            --(Wan02) - END
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
EXIT_SP:
END -- procedure

GO