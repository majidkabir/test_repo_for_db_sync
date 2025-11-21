SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Decode_Format_UpperCase                         */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: format input value                                          */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2021-08-11  1.0  James     WMS-17655. Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_Decode_Format_UpperCase]
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

   IF @nLottableNo IN (1, 2, 3, 6, 7, 8, 9, 10, 11, 12)
      SET @cLottable = UPPER( @cLottableValue)

Quit:

END -- End Procedure

GO