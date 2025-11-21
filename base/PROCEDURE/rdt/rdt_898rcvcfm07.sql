SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdt_898RcvCfm07                                        */  
/* Copyright      : LF Logistics                                           */  
/*                                                                         */  
/* Date       Rev  Author     Purposes                                     */  
/* 2020-08-03 1.0  Chermaine  WMS-14444 Created                            */  
/* 2020-09-21 1.1  Chermaine  WMS-15254 change                             */
/*                            serial.UserDefine01 = serial.uccNo (cc01)    */
/* 2020-09-29 1.2  Chermaine  WMS-15314 Update Ucc.Status for return (cc02)*/
/***************************************************************************/  
CREATE PROC [RDT].[rdt_898RcvCfm07](  
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
   @cSubreasonCode NVARCHAR( 10)  
) AS  
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @cSerialNo          NVARCHAR( 30)   
   DECLARE @cStatus            NVARCHAR( 10)
   DECLARE @cReceiptLineNumber NVARCHAR( 5)
   DECLARE @cSerialNoQTY       INT = 0

   DECLARE @nTranCount INT 
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_898RcvCfm07 -- For rollback or commit only our own transaction 
          
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
   
	DECLARE @curSNO CURSOR  
   SET @curSNO = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT SerialNo, Status
      FROM SerialNo WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey   
         AND SKU = @cUCCSKU   
         AND uccNo = @cUCC    --(cc01)
   OPEN @curSNO
   FETCH NEXT FROM @curSNO INTO @cSerialNo, @cStatus
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Check status
      IF @cStatus NOT IN ('0','9') 
      BEGIN
         IF @cStatus = '1' 
            SELECT @nErrNo = 158701, @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SNO received
         ELSE IF @cStatus = '5' 
            SELECT @nErrNo = 158702, @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SNO picked
         ELSE IF @cStatus = '6' 
            SELECT @nErrNo = 158703, @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SNO packed        
         ELSE
            SELECT @nErrNo = 158705, @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SNO bad status     
         GOTO RollbackTran
      END
      
      --(cc02) -- return
      IF @cStatus = '9' 
            --SELECT @nErrNo = 158704, @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SNO shipped
         BEGIN
            UPDATE ucc SET [status] = 1 WHERE uccNo = @cUCC AND storerKey = @cStorerKey   
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollbackTran
            END
            UPDATE SerialNo SET [Status] = 1 WHERE uccNo = @cUCC AND StorerKey = @cStorerKey AND serialNo = @cSerialNo
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollbackTran
            END
         END
      
      -- Insert ReceiptSerialno
      INSERT INTO ReceiptSerialno( ReceiptKey, ReceiptLineNumber, StorerKey, SKU, SerialNo, QTYExpected, QTY)
      VALUES (@cReceiptKey, @cReceiptLineNumber, @cStorerKey, @cUCCSKU, @cSerialNo, 1, 1)
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollbackTran
      END
      
      SET @cSerialNoQTY = @cSerialNoQTY + 1
   
      FETCH NEXT FROM @curSNO INTO @cSerialNo, @cStatus
   END
   
   -- Check UCC vs serial no balance
   IF @nUCCQTY <> @cSerialNoQTY
   BEGIN
      SET @nErrNo = 158706
      SET @cErrMsg = rdt.rdtgetmessage( 63116, @cLangCode, 'DSP') --UCCNotTallySNO
      GOTO RollbackTran
   END
   
   -- Check SKU setting (due to SKU.SerialNoCapture, is updated manually (not by interface), for new SKU)
   IF @cSerialNoQTY > 0
   BEGIN
      IF NOT EXISTS( SELECT 1 
         FROM SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND SKU = @cUCCSKU 
            AND SerialNoCapture IN ('1', '2'))-- 1=inbound and outbound, 2=inbound only
      BEGIN
         SET @nErrNo = 158707
         SET @cErrMsg = rdt.rdtgetmessage( 63116, @cLangCode, 'DSP') --SKU SNOCap Off
         GOTO RollbackTran
      END
   END
   
   COMMIT TRAN rdt_898RcvCfm07
   GOTO Quit
  
RollBackTran:  
   ROLLBACK TRAN rdt_898RcvCfm07  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN
END

GO