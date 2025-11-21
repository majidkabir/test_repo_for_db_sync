SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/***************************************************************************/    
/* Store procedure: rdt_1580RcptCfm08                                      */    
/* Copyright      : LF Logistics                                           */    
/*                                                                         */    
/* Date       Rev  Author  Purposes                                        */    
/* 2018-08-01 1.0  ChewKP  WMS-5406 Created                                */  
/* 2018-09-25 1.1  Ung     WMS-5722 Add param                              */  
/***************************************************************************/    
CREATE PROC [RDT].[rdt_1580RcptCfm08](    
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
   @cSerialNo        NVARCHAR( 30) = '',     
   @nSerialQTY       INT = 0,                
   @nBulkSNO         INT = 0,
   @nBulkSNOQTY      INT = 0

) AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @nStep             INT    
          ,@nInputKey         INT    
          ,@cSKU              NVARCHAR( 20)    
          ,@nQty              INT    
          ,@cTempLottable02   NVARCHAR( 20)    
          ,@nTranCount        INT    
    
   SET @nTranCount = @@TRANCOUNT        
    
   BEGIN TRAN        
   SAVE TRAN rdt_1580RcptCfm08      
    
   SET @nStep = 5    
   SET @nInputKey = 1    
    
   SELECT @cTempLottable02 = V_String2    
   FROM RDT.RDTMOBREC WITH (NOLOCK)    
   WHERE MOBILE = @nMobile    
    
   SET @cLottable02 = SUBSTRING( @cTempLottable02, 3, 18)    
    
   -- Screen only key in lottable02    
   -- Look for matched lottables based on lottable02    
   SELECT --TOP 1     
      @cLottable01 = RD.Lottable01    
     ,@cLottable03 = RD.Lottable03    
     ,@dLottable04 = RD.Lottable04    
   FROM Receipt R WITH (NOLOCK)    
   JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)    
   WHERE R.StorerKey = @cStorerKey    
   AND   R.Facility = @cFacility    
   AND   RD.ReceiptKey = @cReceiptKey    
   AND   RD.SKU     = @cSKUCode     
   AND   RD.Lottable02 = @cLottable02    
   AND   RD.UserDefine04 ='MIX'    
      
   IF @@ROWCOUNT = 0    
   BEGIN    
      SET @nErrNo = 127851       
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not in L02     
      GOTO RollBackTran    
   END    
    
   -- lottable02 ,sku, lottable01, lottable04 and receiptdetial.userdefine04='Mix'    
   -- Only 1 record    
   IF @@ROWCOUNT > 1    
   BEGIN    
      SET @nErrNo = 127852       
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lot > 1 Rec    
      GOTO RollBackTran    
   END    
    
   -- Pass in lottable values from receiptdetail (screen only key in lottable02)    
   -- so will not split line. Then update lottable02 back at the end based on ReceiptLine# output    
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
    
   IF @nErrNo > 0     
      GOTO RollBackTran    
    
   GOTO Quit    
    
   RollBackTran:      
         ROLLBACK TRAN rdt_1580RcptCfm08      
   Quit:      
      WHILE @@TRANCOUNT > @nTranCount      
         COMMIT TRAN      
END 
SET QUOTED_IDENTIFIER OFF

GO