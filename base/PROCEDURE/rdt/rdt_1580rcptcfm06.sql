SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm06                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2018-03-19 1.0  Ung     WMS-4333 Created                                */
/* 2018-09-25 1.1  Ung     WMS-5722 Add param                              */
/***************************************************************************/
CREATE PROC [RDT].[rdt_1580RcptCfm06](
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

   DECLARE @cStyle         NVARCHAR(20)
   DECLARE @nStyleExpQTY   INT
   DECLARE @nStyleActQTY   INT
   DECLARE @nSKUExpQTY     INT
   DECLARE @nSKUActQTY     INT
   DECLARE @nStyleBal      INT
   DECLARE @cDocType       NVARCHAR(1)

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1580RcptCfm06 -- For rollback or commit only our own transaction

   -- Get ASN info
   SELECT @cDocType = DocType FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

   -- Normal ASN
   IF @cDocType = 'A'
   BEGIN
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
         @cToID          = @cTOID,
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
   END
   
   -- Trade return
   ELSE IF @cDocType = 'R'
   BEGIN
      -- SKU with serial no
      IF @cPOKey = 'NOPO'
      BEGIN
         -- Check piece QTY
         IF @nSKUQTY <> 1
         BEGIN
            SET @nErrNo = 121406
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
            GOTO RollBackTran
         END
         
         -- Get SKU info
         SELECT @cStyle = Style FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKUCode
         
         -- Get style QTY across PO
         SELECT 
            @nStyleExpQTY = ISNULL( SUM( QTYExpected), 0), 
            @nStyleActQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
         FROM ReceiptDetail RD WITH (NOLOCK)
            JOIN SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
         WHERE ReceiptKey = @cReceiptKey
            AND SKU.Style = @cStyle

         -- Check SKU in ASN, PO
         IF @nStyleExpQTY = 0
         BEGIN
            SET @nErrNo = 121401
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Style NotInASN
            GOTO RollBackTran
         END
         
         -- Check style over receive
         IF (@nStyleActQTY + @nSKUQTY) > @nStyleExpQTY
         BEGIN
            SET @nErrNo = 121402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Style over RCV
            GOTO RollBackTran
         END
         
         -- Get style in PO not fully receive
         SELECT TOP 1 
            @cPOKey = RD.POKey
         FROM ReceiptDetail RD WITH (NOLOCK)
            JOIN SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
         WHERE ReceiptKey = @cReceiptKey
            AND SKU.Style = @cStyle
         GROUP BY RD.POKey
         HAVING ISNULL( SUM( QTYExpected), 0) > ISNULL( SUM( BeforeReceivedQTY), 0)
            
         -- Receive to that PO
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
            @cToID          = @cTOID,
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
            @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT, 
            @cSerialNo      = @cSerialNo, 
            @nSerialQTY     = @nSerialQTY 
            
         IF @nErrNo <> 0
            GOTO RollBackTran
         
         IF EXISTS( SELECT 1 
            FROM ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey 
               AND ReceiptLineNumber = @cReceiptLineNumber 
               AND ExternLineNo = '')
         BEGIN
            -- Get PO info
            DECLARE @cExternPOKey NVARCHAR(20)
            SELECT @cExternPOKey = ExternPOKey FROM PO WITH (NOLOCK) WHERE POKey = @cPOKey

            -- Stamp ExternReceiptKey
            UPDATE ReceiptDetail SET
               ExternReceiptKey = @cExternPOKey, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME(), 
               TrafficCop = NULL
            WHERE ReceiptKey = @cReceiptKey 
               AND ReceiptLineNumber = @cReceiptLineNumber 
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 121403
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RDtl Fail
               GOTO RollBackTran
            END
         END
      END
      ELSE
      BEGIN
         -- Get SKU 
         SELECT 
            @nSKUExpQTY = ISNULL( SUM( QTYExpected), 0), 
            @nSKUActQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
         FROM ReceiptDetail RD WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND POKey = @cPOKey
            AND StorerKey = @cStorerKey
            AND SKU = @cSKUCode
         
         -- Check SKU in ASN, PO
         IF @nSKUExpQTY = 0
         BEGIN
            SET @nErrNo = 121404
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not in PO
            GOTO RollBackTran
         END
         
         -- Check SKU over receive
         IF (@nSKUActQTY + @nSKUQTY) > @nSKUExpQTY
         BEGIN
            SET @nErrNo = 121405
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU over RCV
            GOTO RollBackTran
         END
         
         -- Normal SKU
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
            @cToID          = @cTOID,
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
      END
   END
   
   COMMIT TRAN rdt_1580RcptCfm06 -- Only commit change made in here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1580RcptCfm06
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO