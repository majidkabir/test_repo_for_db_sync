SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_YYMM                             */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Key-inYYMM, default DD                                      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 08-10-2014  1.0  Ung         SOS350418. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableFormat_YYMM]
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

   IF LEN( @cLottableValue) = 4
      SET @cLottable = '20' + @cLottableValue + '01'

Quit:

END -- End Procedure


GO