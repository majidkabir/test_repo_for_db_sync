SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: lsp_SetDefaultRDTPrinter                            */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Dynamic lottable                                            */
/*                                                                      */
/* Date        Author   Ver.  Purposes                                  */
/*22-Feb-2018  Shong    1.0   Created                                   */
/*02-Mar-2018  NJOW     1.1   Support domain checking                   */
/* 2021-02-25  Wan01    1.2   Add Big Outer Try/Catch                   */ 
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2021-03-24  Wan02    1.3   LFWM-2250 - UAT - TW  Too Many Printer to */
/*                            be selected                               */
/************************************************************************/

CREATE PROCEDURE [WM].[lsp_SetDefaultRDTPrinter]
   @c_UserName        NVARCHAR(128), 
   @c_LabelPrinter    NVARCHAR(10),
   @c_PaperPrinter    NVARCHAR(10),
   @n_Err             INT ='' OUTPUT,  
   @c_ErrMsg          NVARCHAR(125) = '' OUTPUT
,  @c_SCEPrinterGroup NVARCHAR(20)  = ''     --(Wan02)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Pos INT,
           @c_Domain NVARCHAR(30),
           @c_NoDomainUserName NVARCHAR(128)
   
   --(Wan01) - START
   BEGIN TRY
      SELECT @n_Pos = CHARINDEX('\',@c_UserName)
   
      IF @n_Pos > 0 AND @c_UserName NOT LIKE '%_@_%_.__%' 
      BEGIN
         SELECT @c_Domain = LEFT(@c_UserName, @n_Pos - 1)
         SELECT @c_NoDomainUserName = SUBSTRING(@c_UserName, @n_Pos + 1, LEN(@c_Username))
      END
      ELSE 
           SET @c_NoDomainUserName = @c_UserName
      
      IF NOT EXISTS(SELECT 1
                    FROM WM.WMS_USER_CREATION_STATUS WITH (NOLOCK)
                    WHERE USER_NAME = @c_NoDomainUserName
                    AND ISNULL(LDAP_Domain, '') = CASE WHEN ISNULL(@c_domain, '') <> '' THEN '' ELSE ISNULL(LDAP_Domain, '') END)
      BEGIN
           SET @n_Err = 553101
           SET @c_ErrMsg = 'Invalid User ID'
           GOTO EXIT_SP
      END   

      --EXECUTE AS LOGIN = @c_UserName
      
      IF SUSER_SNAME() <> @c_UserName
      BEGIN
         SET @n_Err = 0 
         EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
   
         IF @n_Err <> 0 
         BEGIN
            GOTO EXIT_SP
         END
   
         EXECUTE AS LOGIN = @c_UserName
      END
       
      IF NOT EXISTS(SELECT 1 FROM RDT.RDTUser AS r WITH(NOLOCK)
                    WHERE r.UserName = @c_UserName)
      BEGIN
         INSERT INTO RDT.RdtUser (UserName, [Password], FullName, DefaultStorer,
                     DefaultFacility, DefaultLangCode, DefaultMenu, DefaultUOM,
                     LastLogin, DefaultPrinter, DefaultPrinter_Paper, [Active]
                  ,  SCEPrinterGroup                                 --(Wan02)
                     )
         VALUES (    @c_UserName, '', @c_UserName, '', '', 'ENG', 0, '', 
                     GETDATE(), @c_LabelPrinter, @c_PaperPrinter, '1'
                  ,  @c_SCEPrinterGroup                              --(Wan02)
                 )
      END 
      ELSE
      BEGIN
           UPDATE RDT.RdtUser 
              SET DefaultPrinter = CASE WHEN ISNULL(@c_LabelPrinter,'') <> '' THEN @c_LabelPrinter ELSE DefaultPrinter END       
                , DefaultPrinter_Paper = CASE WHEN ISNULL(@c_PaperPrinter,'') <> '' THEN @c_PaperPrinter ELSE DefaultPrinter_Paper END
                , SCEPrinterGroup = @c_SCEPrinterGroup                                 --(Wan02)
           WHERE UserName = @c_UserName                   
      END
   END TRY  
     BEGIN CATCH
      SET @n_Err    = @@ERROR
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH 
   EXIT_SP:
   REVERT    
END -- End Procedure

GO