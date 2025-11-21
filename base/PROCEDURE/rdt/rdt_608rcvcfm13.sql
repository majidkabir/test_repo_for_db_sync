SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdt_608RcvCfm13                                        */  
/* Copyright      : LF Logistics                                           */  
/*                                                                         */  
/* Purpose: Copy from rdt_608RcvCfm02. Add update L9 = barcode(SKU) scanned*/  
/*                                                                         */  
/* Date       Rev  Author  Purposes                                        */  
/* 2022-03-09 1.0  James   WMS-18962 Created                               */  
/* 2022-09-30 1.1  James   Add duplicate lottable07 (james01)              */
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_608RcvCfm13](  
    @nFunc          INT,                
    @nMobile        INT,                
    @cLangCode      NVARCHAR( 3),       
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
    @cRDLineNo      NVARCHAR( 5)  OUTPUT,      
    @nErrNo         INT           OUTPUT,     
    @cErrMsg        NVARCHAR( 20) OUTPUT    
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   -- Handling transaction  
   DECLARE @nTranCount                 INT,  
           @nQTYExpected_Total         INT,  
           @nBeforeReceivedQTY_Total   INT,  
           @cUDF09                     NVARCHAR( 30),  
           @cBarcode                   NVARCHAR( 60)

   --SELECT @cBarcode = V_String44
   --FROM rdt.RDTMOBREC WITH (NOLOCK)
   --WHERE Mobile = @nMobile
   
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_608RcvCfm13 -- For rollback or commit only our own transaction  
  
   SELECT   
      @nQTYExpected_Total = ISNULL( SUM( QTYExpected), 0),  
      @nBeforeReceivedQTY_Total = ISNULL( SUM( BeforeReceivedQTY), 0)  
   FROM dbo.ReceiptDetail WITH (NOLOCK)  
   WHERE ReceiptKey = @cReceiptKey  
   AND   SKU = @cSKUCode  
  
   IF @nQTYExpected_Total < (@nBeforeReceivedQTY_Total + @nSKUQTY)  
   BEGIN  
      SET @nErrNo = 184051  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over receive  
      GOTO RollBackTran  
   END  

   SET @cLottable07 = ''
   SET @cLottable11 = ''
   SET @cLottable12 = ''  
   SELECT TOP 1 
      @cLottable07 = Lottable07,
      @cLottable11 = Lottable11,
      @cLottable12 = Lottable12  
   FROM dbo.ReceiptDetail WITH (NOLOCK)  
   WHERE ReceiptKey = @cReceiptKey  
   AND   SKU = @cSKUCode  
   ORDER BY 1 DESC   -- Take the one with value  

   -- Update lottable12 value to receipt header udf09  
   -- Need set required in rdtlottablecode table = 0 so no value will update to lottable12  
   IF ISNULL( @cLottable12, '') <> ''  
   BEGIN  
      SET @cUDF09 = @cLottable12  
  
      -- Assign back the lottable value (if have value)  
      SET @cLottable12 = ''  
      SELECT TOP 1 @cLottable12 = Lottable12  
      FROM dbo.ReceiptDetail WITH (NOLOCK)  
      WHERE ReceiptKey = @cReceiptKey  
      AND   SKU = @cSKUCode  
      ORDER BY 1 DESC   -- Take the one with value  
   END  

   --SET @cLottable09 = @cBarcode

   -- Receive  
   EXEC rdt.rdt_Receive_V7  
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
      @nSKUQTY       = @nSKUQTY,  
      @cUCC          = '',  
      @cUCCSKU       = '',  
      @nUCCQTY       = '',  
      @cCreateUCC    = '',  
      @cLottable01   = @cLottable01,  
      @cLottable02   = @cLottable02,  
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
      @nNOPOFlag     = @nNOPOFlag,  
      @cConditionCode = @cConditionCode,  
      @cSubreasonCode = '',   
      @cReceiptLineNumberOutput = @cRDLineNo OUTPUT  
  
      IF @nErrNo <> 0  
         GOTO RollBackTran  
  
      UPDATE dbo.Receipt WITH (ROWLOCK) SET   
         Userdefine09 = @cUDF09,  
         TrafficCop = NULL  
      WHERE ReceiptKey = @cReceiptKey  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 184052  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd rchdr fail  
         GOTO RollBackTran  
      END  

      GOTO Quit  
  
RollBackTran:    
   ROLLBACK TRAN rdt_608RcvCfm13   
Fail:    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN  
  
  
END  

GO