SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_AutoGenID                      */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Auto generate ID                                            */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2024-06-28  1.0  CYU027    UWP-20470 Created                         */
/************************************************************************/

CREATE PROCEDURE rdt.rdt_AutoGenID
   @nMobile     INT, 
   @nFunc       INT, 
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @cAutoGenID  NVARCHAR(20),
   @tExtData    VariableTable READONLY,
   @cAutoID     NVARCHAR( 18)  OUTPUT,
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @cAutoID = ''

   IF @cAutoGenID = '1'
   BEGIN
      DECLARE @b_success INT
      SET @b_success = 0
      EXECUTE dbo.nspg_GetKey
         'ID',
         10 ,
         @cAutoID    OUTPUT,
         @b_success  OUTPUT,
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @b_success <> 1
      BEGIN
         SET @nErrNo = 59418
         SET @cErrMsg = rdt.rdtgetmessage( 64265, @cLangCode, 'DSP') --GetAutoID Fail
         GOTO Fail
      END
   END
   ELSE
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAutoGenID AND type = 'P')
      BEGIN
         DECLARE @cSQL NVARCHAR(1000)
         DECLARE @cSQLParam NVARCHAR(1000)

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cAutoGenID) + ' @nMobile, @nFunc, @nStep, @cLangCode, ' + 
            '@tExtData, @cAutoID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile     INT,           ' +
            '@nFunc       INT,           ' +
            '@nStep       INT,           ' +
            '@cLangCode   NVARCHAR( 3),  ' +
            '@tExtData    VariableTable READONLY,' +
            '@cAutoID     NVARCHAR( 18) OUTPUT, ' +
            '@nErrNo      INT           OUTPUT, ' + 
            '@cErrMsg     NVARCHAR( 20) OUTPUT'
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @nStep, @cLangCode
            ,@tExtData
            ,@cAutoID  OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
      END
   END

Fail:
END


GO