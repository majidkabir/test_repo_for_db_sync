SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdt_1580RcptCfm28                                      */  
/* Copyright      : LF Logistics                                           */  
/*                                                                         */  
/* Date       Rev  Author  Purposes                                        */  
/* 2023-03-22 1.0  James   WMS-21943 Created                               */  
/***************************************************************************/  
CREATE   PROC [RDT].[rdt_1580RcptCfm28](  
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
  
   DECLARE @cDuplicateFrom NVARCHAR( 5)  
   DECLARE @cBarcode       NVARCHAR( 60)  
   DECLARE @nBarcodeLen    INT  
   DECLARE @nTranCount     INT  
   DECLARE @cRcvUcc        CURSOR  
   DECLARE @cBulkSerialNo  CURSOR  
   DECLARE @nReceiveSerialNoLogKey INT  
   DECLARE @cLottable06    NVARCHAR( 30)  
     
   -- Handling transaction  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_1580RcptCfm28 -- For rollback or commit only our own transaction  
                                       --      
   SELECT @cBarcode = I_Field02  
   FROM rdt.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
     
   SELECT @cLottable06 = ExternReceiptKey  
   FROM dbo.RECEIPT WITH (NOLOCK)  
   WHERE ReceiptKey = @cReceiptKey  
     
   IF EXISTS ( SELECT 1  
               FROM dbo.UCC WITH (NOLOCK)  
               WHERE Storerkey = @cStorerKey  
               AND   UCCNo = @cBarcode  
               AND   [Status] = '0')  
   BEGIN  
    SET @cUCC = @cBarcode  
      
    SET @cRcvUcc = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
    SELECT SKU, Qty  
    FROM dbo.UCC WITH (NOLOCK)  
    WHERE Storerkey = @cStorerKey  
    AND   UCCNo = @cBarcode  
    AND   [Status] = '0'  
    ORDER BY UCC_RowRef  
    OPEN @cRcvUcc  
    FETCH NEXT FROM @cRcvUcc INTO @cUCCSKU, @nUCCQTY  
    WHILE @@FETCH_STATUS = 0  
    BEGIN  
         SELECT TOP 1  
          @cLottable01 = Lottable01,  
          @cLottable02 = Lottable02,  
          @cLottable03 = Lottable03,  
          @dLottable04 = Lottable04  
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
         WHERE ReceiptKey = @cReceiptKey  
         AND   Sku = @cUCCSKU  
         ORDER BY 1  
           
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
            @cSKUCode       = '',  
            @cSKUUOM        = '',  
            @nSKUQTY        = 0,  
            @cUCC           = @cUCC,  
            @cUCCSKU        = @cUCCSKU,  
            @nUCCQTY        = @nUCCQTY,  
            @cCreateUCC     = '0',  
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
     
         IF ISNULL( @cReceiptLineNumber, '') <> ''  
         BEGIN  
          UPDATE dbo.RECEIPTDETAIL SET   
             Lottable01 = @cLottable01,  
             Lottable02 = @cLottable02,  
             Lottable03 = @cLottable03,  
             Lottable04 = @dLottable04,  
             Lottable06 = @cLottable06  
          WHERE ReceiptKey = @cReceiptKey  
          AND   ReceiptLineNumber = @cReceiptLineNumber  
      
          IF @@ERROR <> 0  
             GOTO RollBackTran  
         END  
  
       SET @cBulkSerialNo = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
       SELECT ReceiveSerialNoLogKey, SerialNo, QTY  
       FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)  
       WHERE Mobile = @nMobile  
       AND   Func = @nFunc  
       AND   SKU = @cUCCSKU  
       ORDER BY 1  
       OPEN @cBulkSerialNo  
       FETCH NEXT FROM @cBulkSerialNo INTO @nReceiveSerialNoLogKey, @cSerialNo, @nSerialQTY  
       WHILE @@FETCH_STATUS = 0  
       BEGIN  
            -- ReceiptSerialNo  
            EXEC rdt.rdt_Receive_ReceiptSerialNo @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility,  
               @cReceiptKey,  
               @cReceiptLineNumber,  
               @cUCCSKU,  
               @cSerialNo,  
               @nSerialQTY,  
               @nErrNo     OUTPUT,  
               @cErrMsg    OUTPUT,  
               @cUCC      
  
          IF @@ERROR <> 0  
             GOTO RollBackTran  
            ELSE  
            BEGIN  
              DELETE FROM rdt.rdtReceiveSerialNoLog   
              WHERE ReceiveSerialNoLogKey = @nReceiveSerialNoLogKey  
                
              IF @@ERROR <> 0  
                 GOTO RollBackTran  
            END  
               
               
          FETCH NEXT FROM @cBulkSerialNo INTO @nReceiveSerialNoLogKey, @cSerialNo, @nSerialQTY  
       END  
       CLOSE @cBulkSerialNo  
       DEALLOCATE @cBulkSerialNo  
  
     FETCH NEXT FROM @cRcvUcc INTO @cUCCSKU, @nUCCQTY  
    END  
      
   END  
   ELSE  
   BEGIN  
      SET @nBarcodeLen = LEN( @cBarcode)  
     
      IF @nBarcodeLen = 24  
      BEGIN  
       IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK)  
                   WHERE StorerKey = @cStorerKey  
                   AND   Sku = SUBSTRING( @cBarcode, 1 , 18)  
                   AND   SerialNoCapture = '1')  
         BEGIN  
            SET @cSerialNo = @cBarcode  
            SET @nSerialQTY = 1  
         END  
         ELSE  
         BEGIN  
            SET @cSerialNo = ''  
            SET @nSerialQTY = 0  
         END  
      END  
  
      SELECT TOP 1  
       @cLottable01 = Lottable01,  
       @cLottable02 = Lottable02,  
       @cLottable03 = Lottable03,  
       @dLottable04 = Lottable04  
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
      WHERE ReceiptKey = @cReceiptKey  
      AND   Sku = @cSKUCode  
      ORDER BY 1  
     
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
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT,   
         @cSerialNo      = @cSerialNo,   
         @nSerialQTY     = @nSerialQTY   
        
      IF @nErrNo <> 0  
         GOTO RollBackTran  
     
      IF ISNULL( @cReceiptLineNumber, '') <> ''  
      BEGIN  
       UPDATE dbo.RECEIPTDETAIL SET   
          Lottable01 = @cLottable01,  
          Lottable02 = @cLottable02,  
          Lottable03 = @cLottable03,  
          Lottable04 = @dLottable04,  
            Lottable06 = @cLottable06  
       WHERE ReceiptKey = @cReceiptKey  
       AND   ReceiptLineNumber = @cReceiptLineNumber  
      
       IF @@ERROR <> 0  
          GOTO RollBackTran  
      END  
   END  
     
GOTO Quit  
     
RollBackTran:  
   ROLLBACK TRAN rdt_1580RcptCfm28 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
  
END  

GO