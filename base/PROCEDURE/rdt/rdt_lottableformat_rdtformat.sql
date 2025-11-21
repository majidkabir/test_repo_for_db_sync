SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_RDTFormat                        */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Check lottable format                                       */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 22-02-2022  1.0  Ung         WMS-18950 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableFormat_RDTFormat]
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
   
   DECLARE @cLottableField NVARCHAR( 10)
   SET @cLottableField = 'Lottable' + RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR( 2)), 2)

   IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, @cLottableField, @cLottableValue) = 0
   BEGIN
      SET @nErrNo = 183301
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
   END
END

GO