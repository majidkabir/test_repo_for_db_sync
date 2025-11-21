SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store procedure: rdt_LottableProcess_MDLGenL4ByL13                     */
/* Copyright      : LF                                                    */
/*                                                                        */
/* Purpose: Key-in value, generate expriry date (L4) using                */
/*          production date (L13)                                         */
/*                                                                        */
/* Date        Rev  Author      Purposes                                  */
/* 2020-03-05  1.0  James       WMS-12230. Created                        */
/**************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_MDLGenL4ByL13]
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
   DECLARE @cTempLottable04   NVARCHAR( 60)
   DECLARE @cTempLottable13   NVARCHAR( 60)
   DECLARE @cSUSR2            NVARCHAR( 18)
   DECLARE @cErrMessage       NVARCHAR( 20)

   SET @nErrNo = 0

   IF @cType = 'PRE'
   BEGIN
      SET @dLottable04 = ''
      SET @dLottable13 = ''
      
      GOTO Quit
   END

   -- Get SKU info
   SELECT @nShelfLife = ShelfLife,
          @cSUSR2 = SUSR2
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
   AND   SKU = @cSKU

   IF ISNULL( @dLottable04Value , 0) <> 0 AND ISNULL( @dLottable13Value , 0) <> 0
   BEGIN
      SET @dLottable04 = @dLottable04Value
      SET @dLottable13 = @dLottable13Value

      GOTO Validate_Lottable
   END

   -- Check valid shelf life
   IF ISNULL( @nShelfLife, 0) = 0
   BEGIN
      SET @nErrNo = 149101
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv ShelfLife
      GOTO Quit
   END
   
   IF @nLottableNo = 13 AND ISNULL( @dLottable13Value, 0) <> 0
   BEGIN
      -- Get expiry date
      SET @dLottable04 = DATEADD( DAY, @nShelfLife, @dLottable13Value) 
      SET @dLottable04 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable04, 103), 103) 

      SET @nErrNo = -1  -- Make it display value on screen. next ENTER will proceed next screen
   END

   Validate_Lottable:
   /*
   -- Check production date < today date
   IF DATEDIFF( D, @dLottable13Value, GETDATE()) <= 0
   BEGIN
      SET @nErrNo = 149102
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Prod < Today
      GOTO Quit
   END
   
   --Check production date < expiry date
   IF DATEDIFF( D, @dLottable13Value, @dLottable04) <= 0
   BEGIN
      SET @nErrNo = 149103
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Prod < Expriry
      GOTO Quit
   END
   */


   Quit:

END -- End Procedure


GO