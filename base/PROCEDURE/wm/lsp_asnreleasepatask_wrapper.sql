SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_ASNReleasePATask_Wrapper                       */  
/* Creation Date: 18-Sep-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */
/*                                                                      */
/*                                                                      */  
/* Called By: ASN RCM Release Putaway Tasks                             */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 28-Dec-2020 SWT01    1.0   Adding Begin Try/Catch                    */
/* 15-JAN-2021 Wan01    1.1   Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/ 
CREATE PROCEDURE [WM].[lsp_ASNReleasePATask_Wrapper]
   @c_ReceiptKey NVARCHAR(10),    
   @b_Success    INT   OUTPUT,
   @n_Err        INT   OUTPUT, 
   @c_ErrMsg     NVARCHAR(250) OUTPUT, 
   @n_WarningNo  INT = 0        OUTPUT,
   @c_ProceedWithWarning CHAR(1) = 'N',    
   @c_UserName   NVARCHAR(128)=''
AS  
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   SET @n_Err = 0 
   
   IF SUSER_SNAME() <> @c_UserName     --(Wan01) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
      
      EXECUTE AS LOGIN = @c_UserName
   END                                 --(Wan01) - END
   
   BEGIN TRY -- SWT01 - Begin Outer Begin Try                 
      EXEC isp_ASNReleasePATask_Wrapper 
         @c_ReceiptKey = @c_ReceiptKey,
         @b_Success = @b_Success OUTPUT, 
         @n_Err = @n_Err OUTPUT, 
         @c_ErrMsg = @c_ErrMsg OUTPUT
   END TRY  
  
   BEGIN CATCH  
      SET @b_Success= 0       --(Wan01)  
      SET @c_ErrMsg = 'ASN Release Putaway Task Failed. (lsp_ASNReleasePATask_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '    --(Wan01)  
      GOTO EXIT_SP  
   END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch 
   EXIT_SP:       
   REVERT  
END

GO