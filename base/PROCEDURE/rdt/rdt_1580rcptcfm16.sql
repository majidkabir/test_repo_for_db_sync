SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm16                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2020-04-29 1.0  James   WMS-13044 Created                               */
/***************************************************************************/
CREATE PROC [RDT].[rdt_1580RcptCfm16](
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
   
   DECLARE @nTranCount     INT
   DECLARE @cUCCNo         NVARCHAR( 20)
   
   IF @cLottable01 <> ''
      SET @cUCCNo = @cLottable01

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_1580RcptCfm16  
   
   SELECT TOP 1 @cLottable01 = Lottable01, 
                @cLottable02 = Lottable02, 
                @cLottable03 = Lottable03, 
                @dLottable04 = Lottable04
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND Sku = @cSKUCode
   ORDER BY 1
   
   SET @nErrNo = 0
   EXEC rdt.rdt_Receive
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
      @dLottable05    = NULL,
      @nNOPOFlag      = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = @cSubreasonCode,
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
      
   IF @nErrNo <> 0
      GOTO RollBackTran
   
   IF ISNULL( @cUCCNo, '') <> ''
   BEGIN
      -- New ucc
      IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                      WHERE Storerkey = @cStorerKey
                      AND   UCCNo = @cUCCNo)
      BEGIN
         INSERT INTO dbo.UCC (StorerKey, UCCNo, Status, SKU, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, ExternKey)  
         VALUES (@cStorerKey, @cUCCNo, '1', @cSKUCode, @nSKUQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber, '')  
         SET @nErrNo = @@ERROR
         
         IF @nErrNo <> 0
         BEGIN  
            SET @nErrNo = 151551  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS UCC Fail'  
            GOTO RollBackTran  
         END 
      END
      ELSE
      BEGIN
         -- Multi sku ucc
         IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                         WHERE Storerkey = @cStorerKey
                         AND   UCCNo = @cUCCNo
                         AND   SKU = @cSKUCode)
         BEGIN
            INSERT INTO dbo.UCC (StorerKey, UCCNo, Status, SKU, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, ExternKey)  
            VALUES (@cStorerKey, @cUCCNo, '1', @cSKUCode, @nSKUQTY, @cToLOC, @cToID, @cReceiptKey, @cReceiptLineNumber, '')  
            SET @nErrNo = @@ERROR
         
            IF @nErrNo <> 0
            BEGIN  
               SET @nErrNo = 151552  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS UCC Fail'  
               GOTO RollBackTran  
            END
         END
         ELSE
         -- Update qty only
         BEGIN
            UPDATE dbo.UCC WITH (ROWLOCK) SET 
               qty = qty + @nSKUQTY
            WHERE Storerkey = @cStorerKey
            AND   UCCNo = @cUCCNo
            AND   SKU = @cSKUCode
            SET @nErrNo = @@ERROR

            IF @nErrNo <> 0
            BEGIN  
               SET @nErrNo = 151553  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD UCC Fail'  
               GOTO RollBackTran  
            END
         END
      END
      
      UPDATE dbo.ReceiptDetail SET 
         Lottable01 = @cUCCNo 
      WHERE ReceiptKey = @cReceiptKey 
      AND   ReceiptLineNumber = @cReceiptLineNumber
      SET @nErrNo = @@ERROR
      
      IF @nErrNo <> 0
      BEGIN  
         SET @nErrNo = 151554  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD L01 Fail'  
         GOTO RollBackTran  
      END
   END
   
   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_1580RcptCfm16  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN rdt_1580RcptCfm16  

END

GO