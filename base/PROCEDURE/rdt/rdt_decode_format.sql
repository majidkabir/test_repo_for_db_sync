SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Decode_Format                                   */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: format input value                                          */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 15-04-2016  1.0  Ung       SOS368437 Created                         */
/* 20-05-2016  1.1  Ung       SOS370219 Migrate to Exceed               */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_Decode_Format]
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT, 
   @nInputKey           INT,
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cDecodeCode         NVARCHAR( 30), 
   @cDecodeLineNumber   NVARCHAR( 5), 
   @cFormatSP           NVARCHAR( 50), 
   @cFieldData          NVARCHAR( 60) OUTPUT,
   @nErrNo              INT           OUTPUT,
   @cErrMsg             NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)
   DECLARE @cTempFieldData NVARCHAR( 60)

   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cFormatSP AND type = 'P')
   BEGIN
      -- Backup to temp
      SET @cTempFieldData = @cFieldData
      
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cFormatSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' + 
         ' @cDecodeCode,       ' + 
         ' @cDecodeLineNumber, ' + 
         ' @cFormatSP,         ' +
         ' @cFieldData OUTPUT, ' + 
         ' @nErrNo     OUTPUT, ' + 
         ' @cErrMsg    OUTPUT  '
      SET @cSQLParam =
         '@nMobile            INT,           ' +
         '@nFunc              INT,           ' +
         '@cLangCode          NVARCHAR( 3),  ' +
         '@nStep              INT,           ' + 
         '@nInputKey          INT,           ' +
         '@cStorerKey         NVARCHAR( 15), ' +
         '@cFacility          NVARCHAR( 5),  ' +
         '@cDecodeCode        NVARCHAR( 30), ' + 
         '@cDecodeLineNumber  NVARCHAR( 5),  ' +
         '@cFormatSP          NVARCHAR( 50), ' + 
         '@cFieldData         NVARCHAR( 60) OUTPUT, ' + 
         '@nErrNo             INT           OUTPUT, ' +
         '@cErrMsg            NVARCHAR( 20) OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
         @cDecodeCode, 
         @cDecodeLineNumber, 
         @cFormatSP, 
         @cTempFieldData OUTPUT, 
         @nErrNo         OUTPUT, 
         @cErrMsg        OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      -- Save formatted data
      SET @cFieldData = @cTempFieldData
   END

Quit:

END -- End Procedure


GO