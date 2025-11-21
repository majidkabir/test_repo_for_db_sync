SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm17                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2020-04-21 1.0  James   WMS-12984. Created                              */
/***************************************************************************/
CREATE PROC [RDT].[rdt_1580RcptCfm17](
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
   DECLARE @nNewSKU        INT
   DECLARE @cReceiptGroup  NVARCHAR( 20)

   SET @nNewSKU = 0

   IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                   WHERE ReceiptKey = @cReceiptKey
                   AND   SKU = @cSKUCode)
   BEGIN
      SELECT @cReceiptGroup = ReceiptGroup
      FROM dbo.RECEIPT WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
   
      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE LISTNAME = 'DSRecGroup'
                  AND   Code = @cReceiptGroup
                  AND   Short = 'PCS'
                  AND   Storerkey = @cStorerkey)
         SET @nNewSKU = 1
   END
   
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_1580RcptCfm17  
   
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
      @dLottable05    = @dLottable05,
      @nNOPOFlag      = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = @cSubreasonCode,
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
      
   IF @nErrNo <> 0
      GOTO RollBackTran
   
   IF @nNewSKU = 1
   BEGIN
      UPDATE dbo.RECEIPTDETAIL SET 
         ExternLineNo = '000000', 
         QtyExpected = @nSKUQTY,
         UserDefine04 = 'NotInASN',
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE ReceiptKey = @cReceiptKey
      AND   ReceiptLineNumber = @cReceiptLineNumber
      SET @nErrNo = @@ERROR
         
      IF @nErrNo <> 0
      BEGIN  
         SET @nErrNo = 151751  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD RCDTL FAIL'  
         GOTO RollBackTran  
      END 
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                  AND   ReceiptLineNumber = @cReceiptLineNumber
                  AND   ExternLineNo = '000000'
                  AND   UserDefine04 = 'NotInASN')
      BEGIN
         UPDATE dbo.RECEIPTDETAIL SET 
            QtyExpected = QtyExpected + @nSKUQTY,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cReceiptLineNumber
         SET @nErrNo = @@ERROR
         
         IF @nErrNo <> 0
         BEGIN  
            SET @nErrNo = 151752  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD RCDTL FAIL'  
            GOTO RollBackTran  
         END 
      END
   END

   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_1580RcptCfm17  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN rdt_1580RcptCfm17  

END

GO