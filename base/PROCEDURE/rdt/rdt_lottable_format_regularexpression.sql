SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Lottable_Format_RegularExpression               */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Check input value by regular expression                     */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2021-08-19  1.0  James     WMS-17701. Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_Lottable_Format_RegularExpression]
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

   DECLARE @cLottable2Check   NVARCHAR( 10)
   
   SET @cLottable2Check = 'LOT' + RIGHT( '00' + CAST( @nLottableNo AS NVARCHAR( 2)), 2)

   -- Check Lottable format    
   IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, @cLottable2Check, @cLottableValue) = 0    
   BEGIN    
      SET @nErrNo = 173751    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format    
      GOTO Quit    
   END    

Quit:

END -- End Procedure

GO