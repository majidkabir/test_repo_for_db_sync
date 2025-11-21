SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_MaisonCrivelli                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-02-14 1.0  Ung        WMS-18866 Created                         */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_LottableFormat_MaisonCrivelli](
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

   DECLARE @cYear    NVARCHAR( 4)
   DECLARE @cMonth   NVARCHAR( 2)
   DECLARE @cDay     NVARCHAR( 2)
   DECLARE @cDate    NVARCHAR( 10)

   SET @cLottable= REPLACE( @cLottable, ' ', '')

   -- Check length
   IF LEN( @cLottable) < 3
   BEGIN
      SET @nErrNo = 182201
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   -- Get year
   SELECT @cYear = Short 
   FROM dbo.CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'RDTDecode' 
      AND Code = 'MCY'
      AND Code2 = LEFT( @cLottable, 1)

   -- Get month, day
   SELECT 
      @cMonth = UDF02, 
      @cDay = UDF01
   FROM dbo.CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'RDTDecode' 
      AND Code = 'MCDM'
      AND Code2 = SUBSTRING( @cLottable, 2, 2)

   SET @cDate = @cDay + '/' + @cMonth + '/' + @cYear

   SET @cLottable = @cDate

Quit:

END

GO