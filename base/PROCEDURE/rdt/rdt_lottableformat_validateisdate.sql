SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_ValidateIsDate                   */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Key-inYYMM, default DD                                      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 30-11-2017  1.0  ChewKP      WMS-3175. Created                       */
/* 06-04-2022  1.1  yeekung     Change error message(yeekung01)         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableFormat_ValidateIsDate]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @cLottableCode    NVARCHAR( 30), 
   @nLottableNo      INT,
   @cFormatSP        NVARCHAR( 50), 
   @cLottableValue   NVARCHAR( 60), 
   @cLottable        NVARCHAR( 60) OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   --IF @nLottableNo = 2 
   --BEGIN
      IF RDT.rdtIsValidDate( @cLottableValue) = 0
      BEGIN
         SET @nErrNo = 184601      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvDateFormat (yeekung01)   
         GOTO Quit  
      END
      ELSE 
      BEGIN
         SET @cLottable = @cLottableValue
      END
   --END


Quit:

END -- End Procedure


GO