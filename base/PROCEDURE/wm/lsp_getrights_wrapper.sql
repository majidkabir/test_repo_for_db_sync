SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: WMS                                                 */
/* Copyright      : LFLogistics                                         */
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Dynamic lottable                                            */  
/*                                                                      */  
/* Called By: ASN/Receipt                                               */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */ 
/* 28-Dec-2020 SWT01    1.1   Adding Begin Try/Catch                    */
/* 15-Jan-2021 Wan01    1.2   Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/
CREATE PROCEDURE [WM].[lsp_GetRights_Wrapper]
   @c_Facility NVARCHAR(5),
   @c_StorerKey NVARCHAR(15) ,
   @c_Sku NVARCHAR(20) ,
   @c_ConfigKey NVARCHAR(30) ,
   @b_Success INT OUTPUT,
   @c_Authority NVARCHAR(30) OUTPUT,
   @n_Err INT OUTPUT,
   @c_Errmsg  NVARCHAR(250)   OUTPUT,
   @c_Option1 NVARCHAR(50)='' OUTPUT,
   @c_Option2 NVARCHAR(50)='' OUTPUT,
   @c_Option3 NVARCHAR(50)='' OUTPUT,
   @c_Option4 NVARCHAR(50)='' OUTPUT,
   @c_Option5 NVARCHAR(4000)='' OUTPUT,
   @c_UserName  NVARCHAR(128) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @b_Success = 0
   
   SET @n_Err = 0
   IF SUSER_SNAME() <> @c_UserName       --(Wan01) - START
   BEGIN 
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
   
      EXECUTE AS LOGIN=@c_UserName
   END                                   --(Wan01) - END   
   -- Change to user date format
   -- DECLARE @cDateFormat NVARCHAR( 3)
   -- SET @cDateFormat = RDT.rdtGetDateFormat( @cUserName)
   -- SET DATEFORMAT @cDateFormat
   
   BEGIN TRY -- SWT01 - Begin Outer Begin Try
              --    
   EXEC dbo.nspGetRight
        @c_Facility  = @c_Facility  
       ,@c_StorerKey = @c_StorerKey 
       ,@c_Sku       = @c_Sku       
       ,@c_ConfigKey = @c_ConfigKey 
       ,@b_Success   = @b_Success OUTPUT
       ,@c_Authority = @c_Authority OUTPUT
       ,@n_Err       = @n_Err OUTPUT
       ,@c_Errmsg    = @c_Errmsg  OUTPUT  
       ,@c_Option1   = @c_Option1 OUTPUT  
       ,@c_Option2   = @c_Option2 OUTPUT  
       ,@c_Option3   = @c_Option3 OUTPUT  
       ,@c_Option4   = @c_Option4 OUTPUT  
       ,@c_Option5   = @c_Option5 OUTPUT  
   
   END TRY  
  
   BEGIN CATCH 
      SET @b_Success = 0               --(Wan01) 
      SET @c_Errmsg  = ERROR_MESSAGE() --(Wan01)    
      GOTO EXIT_SP  
   END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch  

   EXIT_SP:
   REVERT  
END -- End Procedure

GO