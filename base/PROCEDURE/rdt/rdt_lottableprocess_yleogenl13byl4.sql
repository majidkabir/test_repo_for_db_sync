SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store procedure: rdt_LottableProcess_YLEOGenL13ByL4                   */
/* Copyright      : LF                                                    */
/*                                                                        */
/* Purpose: Key-in value, generate production date (L13) by               */
/*          production date (L13)                                         */
/*                                                                        */
/* Date        Rev  Author      Purposes                                  */
/* 2021-10-07  1.0  YeeKung     WMS18012 Created                          */
/**************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_YLEOGenL13ByL4]
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nInputKey        INT
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30)
   ,@nLottableNo      INT
   ,@cLottable        NVARCHAR( 30)
   ,@cType            NVARCHAR( 10)
   ,@cSourceKey       NVARCHAR( 15)
   ,@cLottable01Value NVARCHAR( 18)
   ,@cLottable02Value NVARCHAR( 18)
   ,@cLottable03Value NVARCHAR( 18)
   ,@dLottable04Value DATETIME
   ,@dLottable05Value DATETIME
   ,@cLottable06Value NVARCHAR( 30)
   ,@cLottable07Value NVARCHAR( 30)
   ,@cLottable08Value NVARCHAR( 30)
   ,@cLottable09Value NVARCHAR( 30)
   ,@cLottable10Value NVARCHAR( 30)
   ,@cLottable11Value NVARCHAR( 30)
   ,@cLottable12Value NVARCHAR( 30)
   ,@dLottable13Value DATETIME
   ,@dLottable14Value DATETIME
   ,@dLottable15Value DATETIME
   ,@cLottable01      NVARCHAR( 18) OUTPUT
   ,@cLottable02      NVARCHAR( 18) OUTPUT
   ,@cLottable03      NVARCHAR( 18) OUTPUT
   ,@dLottable04      DATETIME      OUTPUT
   ,@dLottable05      DATETIME      OUTPUT
   ,@cLottable06      NVARCHAR( 30) OUTPUT
   ,@cLottable07      NVARCHAR( 30) OUTPUT
   ,@cLottable08      NVARCHAR( 30) OUTPUT
   ,@cLottable09      NVARCHAR( 30) OUTPUT
   ,@cLottable10      NVARCHAR( 30) OUTPUT
   ,@cLottable11      NVARCHAR( 30) OUTPUT
   ,@cLottable12      NVARCHAR( 30) OUTPUT
   ,@dLottable13      DATETIME      OUTPUT
   ,@dLottable14      DATETIME      OUTPUT
   ,@dLottable15      DATETIME      OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cYearCode   NVARCHAR(2)
   DECLARE @cWeekCode   NVARCHAR(2)
   DECLARE @cDayCode    NVARCHAR(1)
   DECLARE @nShelfLife  INT
   DECLARE @nYearNum    INT
   DECLARE @nWeekNum    INT
   DECLARE @nDayNum     INT
   DECLARE @cYear       NVARCHAR(4)
   DECLARE @cMonth      NVARCHAR(2)
   DECLARE @cProdDate   NVARCHAR(30)
   DECLARE @dProdDate   DATETIME
   DECLARE @cTempLottable02   NVARCHAR( 60)
   DECLARE @cTempLottable04   NVARCHAR( 60)
   DECLARE @cTempLottable13   NVARCHAR( 60)
   DECLARE @cSUSR2            NVARCHAR( 18)
   DECLARE @cErrMessage       NVARCHAR( 20)

   SET @nErrNo = 0

   IF @cType = 'PRE'
   BEGIN
      SET @cLottable02 = ''
      SET @dLottable04 = ''
      SET @dLottable13 = ''
      
      GOTO Quit
   END

   SELECT @cTempLottable04 = I_Field06,
          @cTempLottable13 = I_Field08,
          @cErrMessage = ErrMsg
   FROM rdt.RDTMOBREC WITH (NOLOCK)   --INC1475895 
   WHERE Mobile = @nMobile

   -- Get SKU info
   SELECT @nShelfLife = ShelfLife,
          @cSUSR2 = SUSR2
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
   AND   SKU = @cSKU

   --IF ISNULL( @cTempLottable02, '') <> '' AND ISNULL( @cTempLottable04, '') <> '' AND ISNULL( @cTempLottable13, '') <> ''
   IF ISNULL( @dLottable04Value , 0) <> 0 AND ISNULL( @dLottable13Value , 0) <> 0
   BEGIN
      SET @dLottable04 = @dLottable04Value
      SET @dLottable13 = @dLottable13Value

      GOTO Validate_Lottable
   END

   -- Get SKU info
   SELECT @nShelfLife = ShelfLife,
          @cSUSR2 = SUSR2
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
   AND   SKU = @cSKU

   -- Check valid shelf life
   IF ISNULL( @nShelfLife, 0) = 0
   BEGIN
      SET @nErrNo = 176701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv ShelfLife
      GOTO Quit
   END

   IF @nLottableNo = 4 AND ISNULL( @dLottable04Value, 0) <> 0
   BEGIN
      -- Get production date
      SET @dLottable13 = CONVERT( DATETIME, @dLottable04Value, 112)
      SET @dLottable13 = DATEADD( DAY, -@nShelfLife, @dLottable13) 
      SET @dLottable13 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable13, 103), 103) 

      SET @dProdDate = rdt.rdtConvertToDate( @cLottable) 

      -- Get year number
      SET @nYearNum = RIGHT ( YEAR( @dLottable13), 2)
      SET @cYearCode = CAST( @nYearNum AS NVARCHAR( 2))

      SET DATEFIRST 1   -- set monday to be the ast day of the week

      -- Get week number
      SET @nWeekNum = DATEPART(wk, @dLottable13)
      SET @cWeekCode = RIGHT('00'+ISNULL( CAST( @nWeekNum AS NVARCHAR( 2)), ''), 2)
      
      -- Get day number
      SET @nDayNum = DATEPART(dw, @dLottable13) 
      SET @cDayCode = CAST( @nDayNum AS NVARCHAR( 1)) 

      SET @nErrNo = -1  -- Make it display value on screen. next ENTER will proceed next screen
   END

   Validate_Lottable:
   IF DATEDIFF( D, @dLottable13, @dLottable04Value) < 0
   BEGIN
      SET @nErrNo = 176702
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv Prod Date
      GOTO Quit
   END

   IF DATEDIFF( D, GETDATE(), @dLottable04Value) < CAST( @cSUSR2 AS INT)
   BEGIN
      -- This error only need prompt once, user press enter again can proceed
      IF CHARINDEX( 'MRSL', @cErrMessage) = 0 
      BEGIN
         SET @nErrNo = 176703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU below MRSL
         GOTO Quit
      END
   END

   IF DATEDIFF( D, @dLottable13, GETDATE()) < 0
   BEGIN
      SET @nErrNo = 176704
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv Prod Date
      GOTO Quit
   END

   Quit:
END -- End Procedure


GO