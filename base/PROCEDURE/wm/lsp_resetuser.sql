SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: lsp_ResetUser                                       */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Reset session context back to NULL                          */
/*                                                                      */
/* Date        Author   Rev   Purposes                                  */
/* 06-06-2025  Shong    1.0   Created                                   */
/************************************************************************/
CREATE   PROCEDURE [WM].[lsp_ResetUser]
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Reverse user name to prevent conflict of share connection.
   EXEC sp_set_session_context @key = 'mwms_user_name', @value = NULL;


END -- End Procedure

GO