SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: lsp_SetUser                                         */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Dynamic lottable                                            */
/*                                                                      */
/* Date        Author   Rev   Purposes                                  */
/* 12-11-2014  Shong    1.0   Created                                   */
/* 05-12-2017  KHLim    1.1   Extend length same as SUSER_SNAME (KH01)  */
/* 04-04-2018  Shong    1.2   Fixing Bugs                               */
/* 2021-02-25  Wan01    1.1   Add Big Outer Try/Catch                   */
/* 2025-05-23  SWT01    1.3   Setting Session Context for user name     */
/* 2025-09-04  SWT02    1.4   Set user name to suser_sname if not exists*/
/* 2025-11-07  AK01     1.5   UWP-43795 bug fixes                       */
/************************************************************************/
CREATE     PROCEDURE [WM].[lsp_SetUser]
   @c_UserName     NVARCHAR(128) OUTPUT,
   @n_Err          INT ='' OUTPUT,
   @c_ErrMsg       NVARCHAR(125) = '' OUTPUT, 
   @b_ExecuteAs    BIT = 0 OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cExternalUserID  NVARCHAR(100) = '',
           @c_LDAP_DOMAIN    NVARCHAR(50) = '',
           @c_UserType       INT = 0

   -- AK01 S
   DECLARE @b_HasRole        BIT          = 0
         , @b_HasLogin       BIT          = 0
   -- AK01 E

   -- Doesn't matter whether this user id exists in security login, we still set the session context to user name.
   EXEC sp_set_session_context @key = 'mwms_user_name', @value = @c_UserName;
   
   --(Wan01) - START
   BEGIN TRY
      SELECT @c_UserType = USER_TYPE
      FROM WM.WMS_USER_CREATION_STATUS WITH (NOLOCK)
      WHERE USER_NAME = @c_UserName

      -- External User
      IF @c_UserName LIKE '%_@_%_.__%' OR @c_UserType = 1
      BEGIN
         SET @cExternalUserID = ''

         SELECT @cExternalUserID  = WMS_USER_NAME
         FROM WM.WMS_USER_CREATION_STATUS WITH (NOLOCK)
         WHERE USER_NAME = @c_UserName
         AND   WMS_LOGIN_SYNC = 1

         IF @cExternalUserID <> ''
            SET @c_UserName = @cExternalUserID
      END
      ELSE
      BEGIN
         SET @c_LDAP_DOMAIN = ''
         SELECT @c_LDAP_DOMAIN = LDAP_DOMAIN
         FROM WM.WMS_USER_CREATION_STATUS WITH (NOLOCK)
         WHERE USER_NAME = @c_UserName
         IF @c_LDAP_DOMAIN <> ''
         BEGIN
            SET @c_UserName = @c_LDAP_DOMAIN + '\' + @c_UserName

            EXEC sp_set_session_context @key = 'mwms_user_name', @value = @c_UserName; --V0 db user name contains ldap domain
         END
      END

      --AK01 S
      --If this user is not found in NSQL role or has no server login, skip "EXECUTE AS LOGIN"
      --RDT and other application may still using this.
      IF EXISTS (
         SELECT 1 FROM sys.database_principals DBUser
         INNER JOIN sys.database_role_members DBM ON DBM.member_principal_id = DBUser.principal_id
         INNER JOIN sys.database_principals DBRole ON DBRole.principal_id = DBM.role_principal_id
         WHERE DBRole.name = 'NSQL' 
         AND DBUser.name = @c_UserName
      )
      BEGIN
         SET @b_HasRole = 1
      END

      -- Check if user has corresponding server login
      IF EXISTS ( SELECT 1 FROM sys.server_principals SP WHERE SP.name = @c_UserName )
      BEGIN
         SET @b_HasLogin = 1
      END

      IF @b_HasRole = 1 AND @b_HasLogin = 1
      BEGIN
         SET @b_ExecuteAs = 1
      END
      ELSE
      BEGIN
         SET @b_ExecuteAs = 0 
         SET @c_UserName = SUSER_SNAME()
         GOTO EXIT_SP
      END
      --AK01 E
      
   END TRY
   BEGIN CATCH
      SET @n_Err    = @@ERROR
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(Wan01) - END

   EXIT_SP:


   --(Wan01) - START
   IF @n_Err <> 0 AND @c_ErrMsg <> ''
   BEGIN
      Execute nsp_logerror @n_err, @c_errmsg, 'lsp_SetUser'
   END
   --(Wan01) - END

END -- End Procedure

GO