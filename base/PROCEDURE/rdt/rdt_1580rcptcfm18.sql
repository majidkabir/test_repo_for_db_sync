SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm18                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2019-07-23 1.0  James   WMS-9550 . Created                              */
/***************************************************************************/
CREATE PROC [RDT].[rdt_1580RcptCfm18](
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10),
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18),
   @cSKUCode       NVARCHAR( 20),
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,
   @cCreateUCC     NVARCHAR( 1),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT, 
   @cSerialNo      NVARCHAR( 30) = '', 
   @nSerialQTY     INT = 0, 
   @nBulkSNO       INT = 0,
   @nBulkSNOQTY    INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLottable06    NVARCHAR( 30)
          ,@cLottable07    NVARCHAR( 30)
          ,@cLottable08    NVARCHAR( 30)
          ,@cLottable09    NVARCHAR( 30)
          ,@cLottable10    NVARCHAR( 30)
          ,@cLottable11    NVARCHAR( 30)
          ,@cLottable12    NVARCHAR( 30)
          ,@dLottable13    DATETIME
          ,@dLottable14    DATETIME
          ,@dLottable15    DATETIME

   DECLARE @nQTYExpected         INT,
           @nBeforeReceivedQTY   INT,
           @nRowCount            INT,
           @cChkSKU              NVARCHAR( 20),
           @cChkL02              NVARCHAR( 18),
           @cChkStatus           NVARCHAR( 10)

   -- Check L02 blank
   IF @cLottable02 = ''
   BEGIN
      SET @nErrNo = 151801
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lottable2
      GOTO Quit
   END

   -- Check L02 in ASN
   IF NOT EXISTS( SELECT TOP 1 1 
      FROM ReceiptDetail WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey 
         AND Lottable02 = @cLottable02)
   BEGIN
      SET @nErrNo = 151802
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L02 not in ASN
      GOTO Quit
   END

   -- Get ReceiptDetail info
   SELECT 
      @nQTYExpected = ISNULL( SUM( QTYExpected), 0), 
      @nBeforeReceivedQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
   FROM ReceiptDetail WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey 
      AND StorerKey = @cStorerKey 
      AND Lottable02 = @cLottable02
         
   -- Check L02 fully received
   IF @nBeforeReceivedQTY >= @nQTYExpected
   BEGIN
      SET @nErrNo = 151803
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L02 full Recv
      GOTO Quit
   END

   -- Check SKU, L02 in ASN
   IF NOT EXISTS( SELECT TOP 1 1 
      FROM ReceiptDetail WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey 
         AND StorerKey = @cStorerKey 
         AND SKU = @cSKUCode 
         AND Lottable02 = @cLottable02)
   BEGIN
      SET @nErrNo = 151804
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUL02NotInASN
      GOTO Quit
   END

   -- Get ReceiptDetail info
   SELECT 
      @nQTYExpected = ISNULL( SUM( QTYExpected), 0), 
      @nBeforeReceivedQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
   FROM ReceiptDetail WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey 
      AND StorerKey = @cStorerKey 
      AND SKU = @cSKUCode 
      AND Lottable02 = @cLottable02
         
   -- Check over receive SKU, L02
   IF @nQTYExpected < @nBeforeReceivedQTY + @nSKUQTY
   BEGIN
      SET @nErrNo = 151805
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUL02OverRecv
      GOTO Quit
   END

   -- Get ReceiptDetail info
   SELECT 
      @cChkSKU = SKU, 
      @cChkL02 = Lottable02, 
      @nBeforeReceivedQty = BeforeReceivedQty
   FROM ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
      AND StorerKey = @cStorerKey
      AND Lottable06 = @cSerialNo
   SET @nRowCount = @@ROWCOUNT
      
   -- Check SNO in ASN
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 151806
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO not in ASN
      GOTO Quit
   END
      
   -- Check SNO multi line
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 151807
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO dup in ASN
      GOTO Quit
   END
      
   -- Check SNO diff SKU
   IF @cChkSKU <> @cSKUCode
   BEGIN
      SET @nErrNo = 151808
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO diff SKU
      GOTO Quit
   END
      
   -- Check SNO received
   IF @nBeforeReceivedQty > 0
   BEGIN
      SET @nErrNo = 151809
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO received
      GOTO Quit
   END
      
   -- Get serial no info
   IF @cChkStatus IS NULL
      SELECT @cChkStatus = Status
      FROM SerialNo WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKUCode
         AND SerialNo = @cSerialNo

   -- Check serial no received
   IF @cChkStatus = '1'
   BEGIN
      SET @nErrNo = 142210
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO received
      GOTO Quit
   END
      
   -- Get Lottable02
   SELECT @cLottable02 = V_Lottable02 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
      
   -- Check Lottable02 matches
   IF @cChkL02 <> @cLottable02
   BEGIN
      SET @nErrNo = 142211
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff batch
      GOTO Quit
   END      

   -- Serial SKU
   IF @cSerialNo <> ''
   BEGIN
      -- Get lottables
      SELECT 
         @cLottable01 = Lottable01,
         @cLottable02 = Lottable02,   
         @cLottable03 = Lottable03,
         @dLottable04 = Lottable04,
         @dLottable05 = Lottable05,
         @cLottable06 = Lottable06,
         @cLottable07 = Lottable07,
         @cLottable08 = Lottable08,
         @cLottable09 = Lottable09,
         @cLottable10 = Lottable10,
         @cLottable11 = Lottable11,
         @cLottable12 = Lottable12,
         @dLottable13 = Lottable13,
         @dLottable14 = Lottable14,
         @dLottable15 = Lottable15
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND StorerKey = @cStorerKey
         AND SKU = @cSKUCode
         AND Lottable02 = @cLottable02
         AND Lottable06 = @cSerialNo
   END
   
   -- Non serial SKU
   ELSE
   BEGIN
      -- Get lottables
      SELECT 
         @cLottable01 = Lottable01,
         @cLottable02 = Lottable02,   
         @cLottable03 = Lottable03,
         @dLottable04 = Lottable04,
         @dLottable05 = Lottable05,
         @cLottable06 = Lottable06,
         @cLottable07 = Lottable07,
         @cLottable08 = Lottable08,
         @cLottable09 = Lottable09,
         @cLottable10 = Lottable10,
         @cLottable11 = Lottable11,
         @cLottable12 = Lottable12,
         @dLottable13 = Lottable13,
         @dLottable14 = Lottable14,
         @dLottable15 = Lottable15
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND StorerKey = @cStorerKey
         AND SKU = @cSKUCode
         AND Lottable02 = @cLottable02
         AND QTYExpected >= BeforeReceivedQTY + @nSKUQTY
   END
   
   EXEC rdt.rdt_Receive_v7  
      @nFunc          = @nFunc,
      @nMobile        = @nMobile,
      @cLangCode      = @cLangCode,
      @nErrNo         = @nErrNo  OUTPUT,
      @cErrMsg        = @cErrMsg OUTPUT,
      @cStorerKey     = @cStorerKey,
      @cFacility      = @cFacility,
      @cReceiptKey    = @cReceiptKey,
      @cPOKey         = @cPOKey,
      @cToLOC         = @cToLOC,
      @cToID          = @cToID,
      @cSKUCode       = @cSKUCode,
      @cSKUUOM        = @cSKUUOM,
      @nSKUQTY        = @nSKUQTY,
      @cUCC           = @cUCC,
      @cUCCSKU        = @cUCCSKU,
      @nUCCQTY        = @nUCCQTY,
      @cCreateUCC     = @cCreateUCC,
      @cLottable01    = @cLottable01,
      @cLottable02    = @cLottable02,   
      @cLottable03    = @cLottable03,
      @dLottable04    = @dLottable04,
      @dLottable05    = @dLottable05,
      @cLottable06    = @cLottable06,
      @cLottable07    = @cLottable07,
      @cLottable08    = @cLottable08,
      @cLottable09    = @cLottable09,
      @cLottable10    = @cLottable10,
      @cLottable11    = @cLottable11,
      @cLottable12    = @cLottable12,
      @dLottable13    = @dLottable13,
      @dLottable14    = @dLottable14,
      @dLottable15    = @dLottable15,
      @nNOPOFlag      = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = @cSubreasonCode, 
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT

Quit:

END

GO