SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Lottable_Format                                 */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Dynamic lottable to format input value                      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 08-10-2014  1.0  Ung         SOS317571. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_Lottable_Format]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15),
   @cSKU          NVARCHAR( 20),
   @cLottableCode NVARCHAR( 30), 
   @nLottableNo   INT,
   @cFormatSP     NVARCHAR( 50), 
   @cLottable     NVARCHAR( 60) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)
   DECLARE @cTempLottable  NVARCHAR( 60)

   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cFormatSP AND type = 'P')
   BEGIN
      -- Backup to temp lottables
      SET @cTempLottable = @cLottable
      
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cFormatSP) +
         ' @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cFormatSP, @cLottableValue, ' +
         ' @cLottable OUTPUT, ' + 
         ' @nErrNo    OUTPUT, ' + 
         ' @cErrMsg   OUTPUT  '
      SET @cSQLParam =
         '@nMobile          INT,           ' +
         '@nFunc            INT,           ' +
         '@cLangCode        NVARCHAR( 3),  ' +
         '@nInputKey        INT,           ' +
         '@cStorerKey       NVARCHAR( 15), ' +
         '@cSKU             NVARCHAR( 20), ' +
         '@cLottableCode    NVARCHAR( 30), ' + 
         '@nLottableNo      INT,           ' +
         '@cFormatSP        NVARCHAR( 50), ' + 
         '@cLottableValue   NVARCHAR( 60), ' +
         '@cLottable        NVARCHAR( 60) OUTPUT, ' + 
         '@nErrNo           INT           OUTPUT, ' +
         '@cErrMsg          NVARCHAR( 20) OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cFormatSP, @cLottable, 
         @cTempLottable OUTPUT, 
         @nErrNo        OUTPUT, 
         @cErrMsg       OUTPUT

      IF @nErrNo <> 0 AND
         @nErrNo <> -1     -- Retain in current screen
         GOTO Quit

      -- Save processed lottable
      SET @cLottable = @cTempLottable
   END

Quit:

END -- End Procedure


GO