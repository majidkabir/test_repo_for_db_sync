SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableProcess_GenProductionDateL13ByL4        */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Key in L4 (Expiry date) and populate L13 (Production date)  */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 09-04-2019  1.0  James       WMS8582. Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_GenProductionDateL13ByL4]
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

   DECLARE @nShelfLife  INT

   IF @cType = 'PRE'
   BEGIN
      SET @dLottable04 = NULL
      SET @dLottable13 = NULL

      GOTO Quit
   END

   IF @cLottable = '' OR @cLottable IS NULL
      GOTO Quit

   -- Get SKU info
   SELECT @nShelfLife = ShelfLife FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   
   -- Add shelf life
   IF @nShelfLife > 0
      SET @dLottable13 = DATEADD( dd, -@nShelfLife, @dLottable04)
   
   SET @dLottable13 = CONVERT( DATETIME, @dLottable13, 101) --MM/DD/YYYY
   
Fail:
   -- Setup error, or L04/L13 empty
   IF (@dLottable04 = 0 OR @dLottable04 IS NULL) OR (@dLottable13 = 0 OR @dLottable13 IS NULL) 
   BEGIN
      -- Remain in current screen
      SET @nErrNo = -1
   END

Quit:

END -- End Procedure


GO