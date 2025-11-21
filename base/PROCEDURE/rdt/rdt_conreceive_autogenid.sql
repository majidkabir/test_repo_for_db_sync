SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_ConReceive_AutoGenID                            */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Auto generate ID                                            */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 16-06-2017  1.0  Ung         WMS-2231 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_ConReceive_AutoGenID]
   @nMobile     INT, 
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cFacility   NVARCHAR(5),
   @cStorerKey  NVARCHAR(15),
   @cAutoGenID  NVARCHAR(20),
   @cRefNo      NVARCHAR(20), 
   @cColumnName NVARCHAR(20), 
   @cLOC        NVARCHAR(10),
   @cID         NVARCHAR(18), 
   @cAutoID     NVARCHAR(18)  OUTPUT,   
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
         SET @nErrNo = 64265
         SET @cErrMsg = rdt.rdtgetmessage( 64265, @cLangCode, 'DSP') --GetAutoID Fail
         GOTO Fail
      END
   END
   ELSE
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAutoGenID AND type = 'P')
      BEGIN
         DECLARE @cSQL NVARCHAR(MAX)
         DECLARE @cSQLParam NVARCHAR(MAX)

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cAutoGenID) + 
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cAutoGenID, @cRefNo, @cColumnName, @cLOC, @cID, ' + 
            ' @cAutoID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile     INT,           ' +
            ' @nFunc       INT,           ' +
            ' @cLangCode   NVARCHAR( 3),  ' +
            ' @nStep       INT,           ' +
            ' @nInputKey   INT,           ' +
            ' @cFacility   NVARCHAR( 5),  ' +
            ' @cStorerKey  NVARCHAR( 15), ' + 
            ' @cAutoGenID  NVARCHAR( 20), ' + 
            ' @cRefNo      NVARCHAR( 20), ' +
            ' @cColumnName NVARCHAR( 20), ' +
            ' @cLOC        NVARCHAR( 10), ' +
            ' @cID         NVARCHAR( 18), ' +
            ' @cAutoID     NVARCHAR( 18) OUTPUT, ' +
            ' @nErrNo      INT           OUTPUT, ' + 
            ' @cErrMsg     NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cAutoGenID, @cRefNo, @cColumnName, @cLOC, @cID, 
            @cAutoID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
      END
   END

Fail:
END


GO