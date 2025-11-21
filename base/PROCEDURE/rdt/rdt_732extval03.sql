SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_732ExtVal03                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate user cannot choose option #2                       */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2019-08-29  1.0  James       WMS-10272 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_732ExtVal03]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cCCKey       NVARCHAR( 10)
   ,@cCCSheetNo   NVARCHAR( 10)
   ,@cCountNo     NVARCHAR( 1)
   ,@cLOC         NVARCHAR( 10)
   ,@cSKU         NVARCHAR( 20)
   ,@nQTY         INT
   ,@cOption      NVARCHAR( 1)
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nCounted   INT = 0
   DECLARE @cSQL       NVARCHAR( MAX)
   DECLARE @cSQLParam  NVARCHAR( MAX)

   IF @nStep = 8 -- Loc counted, reset?
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cOption = '2'
         BEGIN
            SET @nErrNo = 140651   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Opt 2 NotAllow 
            GOTO Quit
         END
      END
   END

Quit:

END

GO