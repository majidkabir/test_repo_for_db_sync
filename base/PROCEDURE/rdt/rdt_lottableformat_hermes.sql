SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_Hermes                           */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-02-14 1.0  Ung        WMS-18866 Created                         */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_LottableFormat_Hermes](
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nInputKey        INT
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30)
   ,@nLottableNo      INT
   ,@cFormatSP        NVARCHAR( 20)
   ,@cLottableValue   NVARCHAR( 20)
   ,@cLottable        NVARCHAR( 30) OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cYearCode   NVARCHAR(5)
   DECLARE @cMonthCode  NVARCHAR(5)
   DECLARE @cMonth      NVARCHAR(2)
   DECLARE @cYear       NVARCHAR(4)

   SET @cYearCode = SUBSTRING( @cLottable, 1, 1)
   SET @cMonthCode = SUBSTRING( @cLottable, 2, 1)

   -- Get month
   SELECT @cMonth = LEFT( Short, 2)
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'HERMESM'
      AND Code2 = @cMonthCode
      AND StorerKey = @cStorerKey

   -- Get year
   SELECT @cYear = LEFT( Short, 4)
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'HERMESY'
      AND Code2 = @cYearCode
      AND StorerKey = @cStorerKey

   -- Check year valid
   IF @cYearCode NOT BETWEEN '0' AND '9'  AND
      @cYearCode NOT BETWEEN 'B' AND 'I'
   BEGIN
      SET @nErrNo = 182501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   -- Check month valid
   IF @cMonthCode NOT BETWEEN 'A' AND 'L'
   BEGIN
      SET @nErrNo = 182502
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END
   
   -- Generate expiry date
   SET @cLottable = '01/' + @cMonth + '/' + @cYear

Quit:

END

GO