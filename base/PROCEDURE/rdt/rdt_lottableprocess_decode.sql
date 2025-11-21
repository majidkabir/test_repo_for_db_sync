SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_Decode                                */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check lottable received                                           */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 17-04-2018  Ung       1.0   WMS-4668 Created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_Decode]
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

   DECLARE @cBarcode NVARCHAR(30)
   DECLARE @nDecodeErrNo INT

   -- Get lottable
   IF @nLottableNo =  1 SET @cBarcode = @cLottable01Value ELSE 
   IF @nLottableNo =  2 SET @cBarcode = @cLottable02Value ELSE 
   IF @nLottableNo =  3 SET @cBarcode = @cLottable03Value ELSE 
   IF @nLottableNo =  4 SET @cBarcode = @dLottable04Value ELSE 
   IF @nLottableNo =  5 SET @cBarcode = @dLottable05Value ELSE 
   IF @nLottableNo =  6 SET @cBarcode = @cLottable06Value ELSE 
   IF @nLottableNo =  7 SET @cBarcode = @cLottable07Value ELSE 
   IF @nLottableNo =  8 SET @cBarcode = @cLottable08Value ELSE 
   IF @nLottableNo =  9 SET @cBarcode = @cLottable09Value ELSE 
   IF @nLottableNo = 10 SET @cBarcode = @cLottable10Value ELSE 
   IF @nLottableNo = 11 SET @cBarcode = @cLottable11Value ELSE 
   IF @nLottableNo = 12 SET @cBarcode = @cLottable12Value ELSE 
   IF @nLottableNo = 13 SET @cBarcode = @dLottable13Value ELSE 
   IF @nLottableNo = 14 SET @cBarcode = @dLottable14Value ELSE 
   IF @nLottableNo = 15 SET @cBarcode = @dLottable15Value

   -- Get session info
   DECLARE @nStep INT
   DECLARE @cFacility NVARCHAR(5)
   SELECT 
      @nStep = Step, 
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Decode
   EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
      @cLottable01 = @cLottable01  OUTPUT, 
      @cLottable02 = @cLottable02  OUTPUT, 
      @cLottable03 = @cLottable03  OUTPUT, 
      @dLottable04 = @dLottable04  OUTPUT, 
      @dLottable05 = @dLottable05  OUTPUT,
      @cLottable06 = @cLottable06  OUTPUT, 
      @cLottable07 = @cLottable07  OUTPUT, 
      @cLottable08 = @cLottable08  OUTPUT, 
      @cLottable09 = @cLottable09  OUTPUT, 
      @cLottable10 = @cLottable10  OUTPUT,
      @cLottable11 = @cLottable11  OUTPUT, 
      @cLottable12 = @cLottable12  OUTPUT, 
      @dLottable13 = @dLottable13  OUTPUT, 
      @dLottable14 = @dLottable14  OUTPUT, 
      @dLottable15 = @dLottable15  OUTPUT, 
      @nErrNo      = @nDecodeErrNo OUTPUT

END

GO