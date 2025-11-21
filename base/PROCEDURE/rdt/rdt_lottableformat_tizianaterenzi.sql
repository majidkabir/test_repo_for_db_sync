SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_TizianaTerenzi                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-02-14 1.0  Ung        WMS-18866 Created                         */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_LottableFormat_TizianaTerenzi](
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
   IF LEN( @cLottable) < 6
   BEGIN
      SET @nErrNo = 182251
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END

   -- 1st, 2nd char is alphabet
   IF LEFT( @cLottable, 2) LIKE '[A-Za-z][A-Za-z]'
   BEGIN
      -- Get year
      SELECT @cYear = Short 
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'RDTDecode' 
         AND Code = 'TTY'
         AND Code2 = SUBSTRING( @cLottable, 6, 1)

      -- Get month
      SELECT @cMonth = Short
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'RDTDecode' 
         AND Code = 'TTM'
         AND Code2 = LEFT( @cLottable, 2)
   END

   -- 1st char is alphabet
   ELSE IF LEFT( @cLottable, 1) LIKE '[A-Za-z]'
   BEGIN
      -- Get year
      SELECT @cYear = Short 
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'RDTDecode' 
         AND Code = 'TTY'
         AND Code2 = SUBSTRING( @cLottable, 5, 1)

      -- Get month
      SELECT @cMonth = Short
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'RDTDecode' 
         AND Code = 'TTM'
         AND Code2 = LEFT( @cLottable, 1)
   END
   
   ELSE
   BEGIN
      SET @nErrNo = 182252
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Batch
      GOTO Quit
   END
   
   SET @cDate = '01' + '/' + @cMonth + '/' + @cYear

   SET @cLottable = @cDate

Quit:

END

GO