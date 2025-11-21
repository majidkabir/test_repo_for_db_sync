SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_605RcvCfm01                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2020-07-29  1.0  YeeKung     WMS-14414 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_605RcvCfm01] (
   @nFunc        INT,            
   @nMobile      INT,            
   @cLangCode    NVARCHAR( 3),   
   @cStorerKey   NVARCHAR( 15),  
   @cFacility    NVARCHAR( 5),   
   @cReceiptKey  NVARCHAR( 10),  
   @cToID        NVARCHAR( 18),  
   @nErrNo       INT           OUTPUT, 
   @cErrMsg      NVARCHAR( 20) OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cToLOC       NVARCHAR( 10)  
   DECLARE @cSKU         NVARCHAR( 20)  
   DECLARE @cUOM         NVARCHAR( 10)  
   DECLARE @nQTY         INT           -- In mast
   DECLARE @cLottable01  NVARCHAR( 18)  
   DECLARE @cLottable02  NVARCHAR( 18)  
   DECLARE @cLottable03  NVARCHAR( 18)  
   DECLARE @dLottable04  DATETIME  
   DECLARE @dLottable05  DATETIME  
   DECLARE @cLottable06  NVARCHAR( 30)  
   DECLARE @cLottable07  NVARCHAR( 30)  
   DECLARE @cLottable08  NVARCHAR( 30)  
   DECLARE @cLottable09  NVARCHAR( 30)  
   DECLARE @cLottable10  NVARCHAR( 30)  
   DECLARE @cLottable11  NVARCHAR( 30)  
   DECLARE @cLottable12  NVARCHAR( 30)  
   DECLARE @dLottable13  DATETIME  
   DECLARE @dLottable14  DATETIME  
   DECLARE @dLottable15  DATETIME  
   DECLARE @cReceiptLineNumberOutput NVARCHAR( 5)

    -- Handling transaction  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_605RcvCfm01 -- For rollback or commit only our own transaction  
     
   DECLARE @curReceipt CURSOR  
   SET @curReceipt = CURSOR FOR  
      SELECT   
         ToLOC, SKU, QTYExpected,   
         Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,  
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,  
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15  
      FROM dbo.ReceiptDetail WITH (NOLOCK)  
      WHERE ReceiptKey = @cReceiptKey  
         AND ToID = @cToID  
         AND BeforeReceivedQTY = 0  
      ORDER BY ReceiptLineNumber  
   OPEN @curReceipt  
   FETCH NEXT FROM @curReceipt INTO @cToLOC, @cSKU, @nQTY,   
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,   
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,   
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15   
     
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      -- Get SKU info  
      SELECT @cUOM = Pack.PackUOM3   
      FROM SKU WITH (NOLOCK)   
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
      WHERE StorerKey = @cStorerKey   
         AND SKU = @cSKU  

      IF EXISTS (SELECT 1 from receipt (nolock) where receiptkey=@creceiptkey and DocType='R')
      BEGIN
         SELECT @cToLOC=SKU.loc
         FROM
            RECEIPTDETAIL RD JOIN SKUXLOC SKU
            ON RD.SKU=SKU.SKU AND RD.storerkey=SKU.StorerKey
         WHERE SKU.locationtype='PICK'
            AND RD.receiptkey=@creceiptkey
            AND RD.storerkey=@cStorerkey
            AND RD.SKU=@csku
      END

      SET @dLottable05=getdate();

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
      @cSKUCode      = @cSKU,  
      @cSKUUOM       = @cUOM,  
      @nSKUQTY       = @nQTY,  
      @cUCC          = '',  
      @cUCCSKU       = '',  
      @nUCCQTY       = '',  
      @cCreateUCC    = '',  
      @cLottable01   = @cLottable01,  
      @cLottable02   = @cLottable02,  
      @cLottable03   = @cLottable03,  
      @dLottable04   = @dLottable04,  
      @dLottable05   = @dLottable05,  
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
      @cConditionCode = 'OK',  
      @cSubreasonCode = '',   
      @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT  

      IF @nErrNo <> 0  
         GOTO RollBackTran  

      -- Move by UCC    
      EXECUTE rdt.rdt_Move    
         @nMobile     = @nMobile,    
         @cLangCode   = @cLangCode,    
         @nErrNo      = @nErrNo  OUTPUT,    
         @cErrMsg     = @cErrMsg OUTPUT,    
         @cSourceType = 'rdt_605RcvCfm01',    
         @cStorerKey  = @cStorerKey,    
         @cFacility   = @cFacility,    
         @cFromLOC    = @cToLOC,    
         @cToLOC      = @cToLOC,    
         @cFromID     = @cToID,    
         @cToID       = '',    
         @cSKU        = @cSKU,    
         @nQty        = @nQTY
            
      IF @nErrNo <> 0    
         GOTO RollBackTran  
              
      FETCH NEXT FROM @curReceipt INTO @cToLOC, @cSKU, @nQTY,   
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,   
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,   
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15   
   END  

   GOTO Quit  
END
  
RollBackTran:    
   ROLLBACK TRAN rdt_605RcvCfm01   
Fail:    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN  

GO