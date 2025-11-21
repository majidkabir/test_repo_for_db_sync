SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: ispGetEmail                                         */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: - Retrieve email from CodeLkUp table.                       */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Modifications:                                                       */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[ispGetEmail] (
     @c_Code       NVARCHAR(30)
   , @c_StorerKey  NVARCHAR(15)
   , @c_Email      NVARCHAR(255) OUTPUT
   , @c_Database   NVARCHAR(50) = ''
   , @c_Short      NVARCHAR(10) = '' -- EmailTo, EmailCc, EmailBcc
   , @c_ListName   NVARCHAR(10) = 'VALIDATE'
   , @b_debug      INT          = 0
   )
AS
BEGIN
   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)

   IF ISNULL(RTRIM(@c_Database),'') = ''
   BEGIN
      SET @c_Database = DB_NAME()
   END

   SET @c_ExecStatements = ''
   SET @c_ExecArguments  = ''
   SET @c_Email          = ''

   SET @c_ExecStatements = N'SELECT @c_Email = ISNULL(RTRIM(Long),'''') ' -- Retrieve Email
                           + 'FROM ' + ISNULL(RTRIM(@c_Database),'') + '.dbo.CodeLkUp WITH (NOLOCK) '
                           + 'WHERE ListName = ''' + ISNULL(RTRIM(@c_ListName),'') + ''' '
                           + 'AND Code = ''' + ISNULL(RTRIM(@c_Code),'') + ''' '
                           + 'AND ISNULL(RTRIM(StorerKey),'''') = ''' + ISNULL(RTRIM(@c_StorerKey),'') + ''' '
                           +  CASE WHEN ISNULL(RTRIM(@c_Short),'') <> ''
                                   THEN 'AND ISNULL(RTRIM(Short),'''') = ''' + ISNULL(RTRIM(@c_Short),'') + ''' '
                                   ELSE ''
                              END

   SET @c_ExecArguments = N'@c_Email NVARCHAR(255) OUTPUT'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @c_Email OUTPUT

   IF @b_debug >= 1
   BEGIN
      SELECT @c_ExecStatements '@c_ExecStatements'
   END
END

GO