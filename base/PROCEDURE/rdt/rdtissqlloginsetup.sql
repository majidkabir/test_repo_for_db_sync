SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtIsSQLLoginSetup                                 */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/* 1. Check whether SQL login exists                                    */
/* 2. Check whether SQL login granted to NSQL role                      */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtIsSQLLoginSetup] (
   @cLogin     SYSNAME,
   @cLangCode  NVARCHAR( 3),
   @bSuccess   INT OUTPUT, 
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF

   SET @bSuccess = 0 -- Fail

   -- Validate SQL login exists
   IF NOT EXISTS( select loginname from master.dbo.syslogins (nolock) where loginname = @cLogin)
   BEGIN
      SET @nErrNo = 60000
      SET @cErrMsg = 'SQL login not exists'
      GOTO Quit
   END

   -- Validate SQL login in NSQL role
   /*
   Note: 
   Only checks NSQL in RDT DB. RDT points to which EXceed DB to is unknown at this point. 
   Exception occur if SQL login is not granted to NSQL in EXceed DB
   It wont be an issue in future after RDT DB merge into EXceed DB
   */
   IF NOT EXISTS( select u.name
		from sysusers u (nolock), sysusers g (nolock), sysmembers m (nolock)
		where g.uid = m.groupuid
			and u.uid = m.memberuid
         and g.name = 'NSQL'
			and g.issqlrole = 1
         and u.name = @cLogin)
   BEGIN
      SET @nErrNo = 60000
      SET @cErrMsg = 'Login not in NSQL'
      GOTO Quit
   END

   SET @bSuccess = 1 -- Success

Quit:

END

GO