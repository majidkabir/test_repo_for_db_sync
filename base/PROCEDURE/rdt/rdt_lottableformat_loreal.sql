SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_Loreal                           */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-02-14 1.0  Ung        WMS-18866 Created                         */
/* 2022-07-04 1.1  Ung        WMS-20103 Minor correct on spec           */
/************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_LottableFormat_Loreal](
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
   DECLARE @cYear       NVARCHAR(4)
   DECLARE @cMonth      NVARCHAR(2)
   
   IF (LEN(@cLottable)NOT BETWEEN 6 AND 7)
   BEGIN
      SET @nErrNo = 182551
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   SET @cYearCode = SUBSTRING( @cLottable, 3, 1)
   SET @cMonthCode = SUBSTRING( @cLottable, 4, 1)


   IF @cYearCode NOT BETWEEN 'A' AND 'Z'
   BEGIN
      SET @nErrNo = 182552
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidLOREALY
      GOTO Quit
   END

   -- Check month valid
   IF @cMonthCode NOT BETWEEN '1' AND '9 ' AND
      @cMonthCode NOT IN ('O','N','D')
   BEGIN
      SET @nErrNo = 182553
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidLOREALM
      GOTO Quit
   END

  -- Get month
   SELECT @cMonth = LEFT( Short, 2)
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'LOREALM'
      AND Code2 = @cMonthCode
      AND StorerKey = @cStorerKey

   -- Get year
   SELECT @cYear = LEFT( Short, 4)
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'LOREALY'
      AND Code2 = @cYearCode
      AND StorerKey = @cStorerKey

   -- Generate expiry date
   SET @cLottable = '01/' + @cMonth + '/' + @cYear

Quit:

END

GO