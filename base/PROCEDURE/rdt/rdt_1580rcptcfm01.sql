SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580RcptCfm01                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Receive detail line in certain order.                             */
/*          Lottable02 = 'ECOM' receive 1st                                   */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2016-04-21 1.0  James      SOS367156 Created                               */
/* 2017-07-02 1.1  SPChin     IN00392817 - Bug Fixed                          */
/* 2018-09-25 1.2  Ung        WMS-5722 Add param                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580RcptCfm01] (
   @nFunc            INT,  
   @nMobile          INT,  
   @cLangCode        NVARCHAR( 3), 
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cReceiptKey      NVARCHAR( 10), 
   @cPOKey           NVARCHAR( 10), 
   @cToLOC           NVARCHAR( 10), 
   @cToID            NVARCHAR( 18), 
   @cSKUCode         NVARCHAR( 20), 
   @cSKUUOM          NVARCHAR( 10), 
   @nSKUQTY          INT, 
   @cUCC             NVARCHAR( 20), 
   @cUCCSKU          NVARCHAR( 20), 
   @nUCCQTY          INT, 
   @cCreateUCC       NVARCHAR( 1),  
   @cLottable01      NVARCHAR( 18), 
   @cLottable02      NVARCHAR( 18), 
   @cLottable03      NVARCHAR( 18), 
   @dLottable04      DATETIME, 
   @dLottable05      DATETIME, 
   @nNOPOFlag        INT, 
   @cConditionCode   NVARCHAR( 10),
   @cSubreasonCode   NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT,  --IN00392817 
   @cSerialNo        NVARCHAR( 30) = '',     --IN00392817
   @nSerialQTY       INT = 0,                --IN00392817
   @nBulkSNO         INT = 0,
   @nBulkSNOQTY      INT = 0
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @nQTY_Bal     INT
DECLARE @nQTY         INT

-- Copy QTY to process
SET @nQTY_Bal = @nSKUQTY

DECLARE @curReceipt CURSOR

-- Handling transaction
DECLARE @nTranCount INT
SET @nTranCount = @@TRANCOUNT
BEGIN TRAN  -- Begin our own transaction
SAVE TRAN rdt_1580RcptCfm01 -- For rollback or commit only our own transaction

DECLARE curReceipt CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
SELECT Lottable01, Lottable03, Lottable04, 
       ISNULL( SUM( QTYExpected-BeforeReceivedQTY), 0)
FROM dbo.ReceiptDetail RD WITH (NOLOCK)
WHERE StorerKey = @cStorerKey
AND   ReceiptKey = @cReceiptKey
AND   SKU = @cSKUCode
AND   Lottable02 = 'ECOM'
AND   ISNULL( QTYExpected-BeforeReceivedQTY, 0) > 0
GROUP BY Lottable01, Lottable03, Lottable04

OPEN curReceipt
FETCH NEXT FROM curReceipt INTO @cLottable01, @cLottable03, @dLottable04, @nQTY
WHILE @@FETCH_STATUS <> -1
BEGIN
   IF @nQTY > 0
   BEGIN
      IF @nQTY_Bal < @nQTY
         SET @nQTY = @nQTY_Bal
         
      EXEC rdt.rdt_Receive--_V7
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPOKey,
         @cToLOC        = @cToLOC,
         @cToID         = @cToID,
         @cSKUCode      = @cSKUCode,
         @cSKUUOM       = @cSKUUOM,
         @nSKUQTY       = @nQTY,
         @cUCC          = '',
         @cUCCSKU       = '',
         @nUCCQTY       = '',
         @cCreateUCC    = '',
         @cLottable01   = @cLottable01,
         @cLottable02   = 'ECOM',
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = NULL,
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = '',
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT   --IN00392817

      IF @nErrNo <> 0
         GOTO RollBackTran
         
      SET @nQTY_Bal = @nQTY_Bal - @nQTY

      IF @nQTY_Bal = 0
         BREAK
   END
   FETCH NEXT FROM curReceipt INTO @cLottable01, @cLottable03, @dLottable04, @nQTY
END
CLOSE curReceipt
DEALLOCATE curReceipt

-- If still have balance, go for another lottable02 to offset
IF @nQTY_Bal <> 0
BEGIN
   SELECT @cLottable01 = Lottable01, 
          @cLottable02 = Lottable02, 
          @cLottable03 = Lottable03, 
          @dLottable04 = Lottable04
   FROM dbo.ReceiptDetail RD WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   ReceiptKey = @cReceiptKey
   AND   SKU = @cSKUCode
   AND   Lottable02 <> 'ECOM'
   AND   ISNULL( QTYExpected-BeforeReceivedQTY, 0) > 0

   -- Receive the rest of the qty
   SET @nQTY = @nQTY_Bal
   SET @nQTY_Bal = 0

   EXEC rdt.rdt_Receive--_V7
      @nFunc         = @nFunc,
      @nMobile       = @nMobile,
      @cLangCode     = @cLangCode,
      @nErrNo        = @nErrNo OUTPUT,
      @cErrMsg       = @cErrMsg OUTPUT,
      @cStorerKey    = @cStorerKey,
      @cFacility     = @cFacility,
      @cReceiptKey   = @cReceiptKey,
      @cPOKey        = @cPOKey,
      @cToLOC        = @cToLOC,
      @cToID         = @cToID,
      @cSKUCode      = @cSKUCode,
      @cSKUUOM       = @cSKUUOM,
      @nSKUQTY       = @nQTY,
      @cUCC          = '',
      @cUCCSKU       = '',
      @nUCCQTY       = '',
      @cCreateUCC    = '',
      @cLottable01   = @cLottable01,
      @cLottable02   = @cLottable02,
      @cLottable03   = @cLottable03,
      @dLottable04   = @dLottable04,
      @dLottable05   = NULL,
      @nNOPOFlag     = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = '',
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT   --IN00392817

   IF @nErrNo <> 0
      GOTO RollBackTran
END

-- If still have balance, means offset has error
IF @nQTY_Bal <> 0
BEGIN
   SET @nErrNo = 56001
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error
   GOTO RollBackTran
END
GOTO Quit

RollBackTran:  
   ROLLBACK TRAN rdt_1580RcptCfm01 
Fail:  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  

GO