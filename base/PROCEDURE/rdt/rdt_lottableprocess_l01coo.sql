SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_L01COO                                */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Default COO (country of origin) and validate in code lookup       */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 07-10-2019  Ung       1.0   WMS-10643 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_L01COO]
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

   -- Default COO
   IF @cType = 'PRE'
   BEGIN
      IF @nFunc = 608 -- Piece return
      BEGIN
         DECLARE @cReceiptKey    NVARCHAR( 10)
         DECLARE @cToLOC         NVARCHAR( 10)
         DECLARE @cToID          NVARCHAR( 18)
         DECLARE @cDefCOO        NVARCHAR( 18) = ''

         -- Get session info
         SELECT
            @cReceiptKey = V_ReceiptKey, 
            @cToLOC = V_LOC, 
            @cToID = V_ID
         FROM rdt.rdtMobRec WITH (NOLOCK)
         WHERE Mobile = @nMobile

         -- Get COO
         SELECT @cDefCOO = Lottable01
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND ToLOC = @cToLOC
            AND ToID = @cToID
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND BeforeReceivedQTY > 0
         ORDER BY EditDate
         
         SET @cLottable01 = @cDefCOO
      END
   END
   
   -- Process COO
   IF @cType = 'POST'
   BEGIN
      -- Check COO valid
      IF NOT EXISTS( SELECT 1 
         FROM CodeLKUP WITH (NOLOCK) 
         WHERE ListName = 'PVHCOO' 
            AND Code = @cLottable 
            AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 145001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid COO
         GOTO Quit
      END
   END
   
Quit:
   
END

GO