SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_598RcvCfm01                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Receive across multiple ASN                                       */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2016-09-02 1.0  Ung        SOS375564 Created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_598RcvCfm01] (
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cRefNo         NVARCHAR( 20), 
   @cColumnName    NVARCHAR( 20), 
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18), -- Blank = receive to blank ToID
   @cSKUCode       NVARCHAR( 20), -- SKU code. Not SKU barcode
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,           -- In master unit
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,           -- In master unit. Pass in the QTY for UCCWithDynamicCaseCNT
   @cCreateUCC     NVARCHAR( 1),  -- Create UCC. 1=Yes, the rest=No
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,
   @dLottable14    DATETIME,
   @dLottable15    DATETIME,
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10),
   @nErrNo         INT                    OUTPUT,
   @cErrMsg        NVARCHAR( 20)          OUTPUT, 
   @cReceiptKeyOutput NVARCHAR( 10)       OUTPUT,
   @cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT, 
   @cDebug         NVARCHAR( 1) = '0'
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cReceiptKey  NVARCHAR(10)
DECLARE @nQTY_Bal     INT
DECLARE @nQTY         INT
DECLARE @cExternReceiptKey NVARCHAR( 20)

-- Copy QTY to process
SET @nQTY_Bal = @nSKUQTY

-- Handling transaction
DECLARE @nTranCount INT
SET @nTranCount = @@TRANCOUNT
BEGIN TRAN  -- Begin our own transaction
SAVE TRAN rdt_598RcvCfm01 -- For rollback or commit only our own transaction

DECLARE @curReceipt CURSOR
SET @curReceipt = CURSOR FOR
   SELECT CRL.ReceiptKey, ISNULL( SUM( QTYExpected-BeforeReceivedQTY), 0)
   FROM dbo.ReceiptDetail RD WITH (NOLOCK)
      JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON (RD.ReceiptKey = CRL.ReceiptKey)
   WHERE Mobile = @nMobile
      AND RD.StorerKey = @cStorerKey
      AND RD.SKU = @cSKUCode
   GROUP BY CRL.ReceiptKey
   ORDER BY CRL.ReceiptKey
OPEN @curReceipt
FETCH NEXT FROM @curReceipt INTO @cReceiptKey, @nQTY
WHILE @@FETCH_STATUS = 0
BEGIN
   IF @nQTY > 0
   BEGIN
      IF @nQTY_Bal < @nQTY
         SET @nQTY = @nQTY_Bal

      -- Get receipt info
      SELECT @cExternReceiptKey = ExternReceiptKey FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey
         
      EXEC rdt.rdt_Receive_V7
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = 'NOPO',
         @cToLOC        = @cToLOC,
         @cToID         = @cToID,
         @cSKUCode      = @cSKUCode,
         @cSKUUOM       = @cSKUUOM,
         @nSKUQTY       = @nQTY,
         @cUCC          = '',
         @cUCCSKU       = '',
         @nUCCQTY       = '',
         @cCreateUCC    = '',
         @cLottable01   = @cReceiptKey,         -- ReceiptKey
         @cLottable02   = @cExternReceiptKey,   -- ExternReceiptKey
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = NULL,
         @cLottable06   = @cLottable06,
         @cLottable07   = @cLottable07,
         @cLottable08   = @cLottable08,
         @cLottable09   = @cLottable09,
         @cLottable10   = @cLottable10,
         @cLottable11   = @cLottable11,
         @cLottable12   = @cLottable12,
         @dLottable13   = @dLottable13,
         @dLottable14   = @dLottable14,
         @dLottable15   = @dLottable15,
         @nNOPOFlag     = 1,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = '', 
         @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran
         
      SET @cReceiptKeyOutput = @cReceiptKey
      SET @nQTY_Bal = @nQTY_Bal - @nQTY
      IF @nQTY_Bal = 0
         BREAK
   END
   FETCH NEXT FROM @curReceipt INTO @cReceiptKey, @nQTY
END

-- If still have balance, means offset has error
IF @nQTY_Bal <> 0
BEGIN
   SET @nErrNo = 103601
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error
   GOTO RollBackTran
END
GOTO Quit

RollBackTran:  
   ROLLBACK TRAN rdt_598RcvCfm01 
Fail:  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  

GO