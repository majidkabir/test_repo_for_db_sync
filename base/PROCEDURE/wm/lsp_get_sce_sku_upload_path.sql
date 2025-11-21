SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: lsp_Get_SCE_SKU_Upload_Path                             */
/* Creation Date: 11-Sep-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Return Multiple URL Link for SKU Image                      */
/*                                                                      */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-02-05  mingle01 1.1  Add Big Outer Begin try/Catch             */ 
/************************************************************************/
CREATE PROC [WM].[lsp_Get_SCE_SKU_Upload_Path]
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

 
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   --(mingle01) - START
   BEGIN TRY
      SET @c_SKU_PATH = ''
      SELECT @c_SKU_PATH = ISNULL(OPTION5,'')
      FROM StorerConfig (NOLOCK)
      WHERE ConfigKey='GetSKUPath'
      AND SValue = 'WM.lsp_Get_SCE_SKU_Upload_Path'
      AND OPTION5 IS NOT NULL         
   
      IF ISNULL(RTRIM(@c_SKU_PATH), '') > ''
      BEGIN
         SET @c_SKU_PATH = @c_SKU_PATH + '/' + RTRIM(@c_Storerkey)  
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