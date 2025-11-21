SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_MoveToUCC_AutoGenID                             */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Auto generate ID                                            */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2017-03-24  1.0  Ung       WMS-1371 Created                          */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_MoveToUCC_AutoGenID]
   @nMobile     INT, 
   @nFunc       INT, 
   @nStep       INT, 
   @nInputKey   INT, 
   @cLangCode   NVARCHAR( 3), 
   @cStorerKey  NVARCHAR(15),
   @cFacility   NVARCHAR(5), 
   @cAutoGenID  NVARCHAR(20),
   @cFromLOC    NVARCHAR(10),
   @cFromID     NVARCHAR(18),
   @cSKU        NVARCHAR(20),
   @nQTY        INT,
   @cUCC        NVARCHAR(20),
   @cToID       NVARCHAR(18),
   @cToLOC      NVARCHAR(10),
   @cOption     NVARCHAR( 1),
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
         SET @nErrNo = 107351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetAutoID Fail
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
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, ' + 
            ' @cAutoGenID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @cOption, ' + 
            ' @cAutoID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile     INT,          ' + 
            '@nFunc       INT,          ' + 
            '@nStep       INT,          ' + 
            '@nInputKey   INT,          ' + 
            '@cLangCode   NVARCHAR( 3), ' +  
            '@cStorerKey  NVARCHAR(15), ' + 
            '@cFacility   NVARCHAR(5),  ' + 
            '@cAutoGenID  NVARCHAR(20), ' + 
            '@cFromLOC    NVARCHAR(10), ' + 
            '@cFromID     NVARCHAR(18), ' + 
            '@cSKU        NVARCHAR(20), ' + 
            '@nQTY        INT,          ' + 
            '@cUCC        NVARCHAR(20), ' + 
            '@cToID       NVARCHAR(18), ' + 
            '@cToLOC      NVARCHAR(10), ' + 
            '@cOption     NVARCHAR( 1), ' + 
            '@cAutoID     NVARCHAR(18)  OUTPUT, ' + 
            '@nErrNo      INT           OUTPUT, ' + 
            '@cErrMsg     NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, 
            @cAutoGenID, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC, @cToID, @cToLOC, @cOption, 
            @cAutoID  OUTPUT, 
            @nErrNo   OUTPUT, 
            @cErrMsg  OUTPUT
      END
   END

Fail:
END


GO