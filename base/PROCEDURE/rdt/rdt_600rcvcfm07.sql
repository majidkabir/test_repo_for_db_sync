SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_600RcvCfm07                                           */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Purpose: Workaround to print pallet label for each receive                 */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 16-03-2020  YeeKung   1.0   WMS-10709 Created                              */  
/* 19-11-2020  YeeKung   1.1   WMS-15597 Add SerialNo(yeekung01)              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_600RcvCfm07] (
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
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
   @cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT,
   @cSerialNo      NVARCHAR( 30) = '',   
   @nSerialQTY     INT = 0,   
   @nBulkSNO       INT = 0,   
   @nBulkSNOQTY    INT = 0 
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cLottable01Required NVARCHAR( 1)    
   DECLARE @cLottable02Required NVARCHAR( 1)    
   DECLARE @cLottable03Required NVARCHAR( 1)    
   DECLARE @cLottable04Required NVARCHAR( 1)    
   DECLARE @cLottable05Required NVARCHAR( 1)    
   DECLARE @cLottable06Required NVARCHAR( 1)    
   DECLARE @cLottable07Required NVARCHAR( 1)    
   DECLARE @cLottable08Required NVARCHAR( 1)    
   DECLARE @cLottable09Required NVARCHAR( 1)    
   DECLARE @cLottable10Required NVARCHAR( 1)    
   DECLARE @cLottable11Required NVARCHAR( 1)    
   DECLARE @cLottable12Required NVARCHAR( 1)    
   DECLARE @cLottable13Required NVARCHAR( 1)    
   DECLARE @cLottable14Required NVARCHAR( 1)    
   DECLARE @cLottable15Required NVARCHAR( 1)    
   DECLARE @cLottableCode       NVARCHAR( 30)    
   DECLARE @cNewSKU             NVARCHAR( 30)     
    
   -- Handling transaction    
   DECLARE @nTranCount     INT,    
           @b_Success      INT    
    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
   SAVE TRAN rdt_607RcptCfm07 -- For rollback or commit only our own transaction    
     
   IF @nFunc = 600 -- Normal receiving  
   BEGIN  
  
        SELECT    
         @cLottableCode = LottableCode    
      FROM dbo.SKU SKU (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
         AND SKU = @cSKUCode    
    
      SET @cNewSKU = ''    
    
      SELECT    
         @cLottable01Required = '0', @cLottable02Required = '0', @cLottable03Required = '0', @cLottable04Required = '0', @cLottable05Required = '0',    
         @cLottable06Required = '0', @cLottable07Required = '0', @cLottable08Required = '0', @cLottable09Required = '0', @cLottable10Required = '0',    
         @cLottable11Required = '0', @cLottable12Required = '0', @cLottable13Required = '0', @cLottable14Required = '0', @cLottable15Required = '0'    
    
      -- Get LottableCode info    
      SELECT    
         @cLottable01Required = CASE WHEN LottableNo =  1 THEN Required ELSE @cLottable01Required END,    
         @cLottable02Required = CASE WHEN LottableNo =  2 THEN Required ELSE @cLottable02Required END,    
         @cLottable03Required = CASE WHEN LottableNo =  3 THEN Required ELSE @cLottable03Required END,    
         @cLottable04Required = CASE WHEN LottableNo =  4 THEN Required ELSE @cLottable04Required END,    
         @cLottable05Required = CASE WHEN LottableNo =  5 THEN Required ELSE @cLottable05Required END,    
         @cLottable06Required = CASE WHEN LottableNo =  6 THEN Required ELSE @cLottable06Required END,    
         @cLottable07Required = CASE WHEN LottableNo =  7 THEN Required ELSE @cLottable07Required END,    
         @cLottable08Required = CASE WHEN LottableNo =  8 THEN Required ELSE @cLottable08Required END,    
         @cLottable09Required = CASE WHEN LottableNo =  9 THEN Required ELSE @cLottable09Required END,    
         @cLottable10Required = CASE WHEN LottableNo = 10 THEN Required ELSE @cLottable10Required END,    
         @cLottable11Required = CASE WHEN LottableNo = 11 THEN Required ELSE @cLottable11Required END,    
         @cLottable12Required = CASE WHEN LottableNo = 12 THEN Required ELSE @cLottable12Required END,    
         @cLottable13Required = CASE WHEN LottableNo = 13 THEN Required ELSE @cLottable13Required END,    
         @cLottable14Required = CASE WHEN LottableNo = 14 THEN Required ELSE @cLottable14Required END,    
         @cLottable15Required = CASE WHEN LottableNo = 15 THEN Required ELSE @cLottable15Required END    
      FROM rdt.rdtLottableCode WITH (NOLOCK)    
      WHERE LottableCode = @cLottableCode    
         AND Function_ID = @nFunc    
         AND StorerKey = @cStorerKey  
  
            --Get the oldest LOT with QTY    
      SELECT @dLottable05 = MIN( LA.Lottable05)    
      FROM dbo.LOTATTRIBUTE LA WITH (NOLOCK)    
      JOIN dbo.LOTXLOCXID LLI WITH (NOLOCK)     
         ON LA.Lot = LLI.Lot AND LA.Storerkey = LLI.Storerkey AND LA.Sku = LLI.Sku    
      JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.Loc = LOC.Loc    
      WHERE LA.StorerKey = @cStorerKey    
         AND   LA.Sku = @cSKUCode    
         AND LLI.Qty > 0    
    
      --If such LOT not exist, return today date    
      IF ISNULL(@dLottable05,'') = ''    
         SET @dLottable05 =rdt.RDTFORMATDATE (@dLottable05)   
      ELSE    
         -- Minus 1 day to not get the same receive day from previous receipt ( for sku with stock only)    
         -- If 2 receipt date same then allocation might not allocate from return stock    
         SET @dLottable05 = rdt.RDTFORMATDATE (@dLottable05)   
      -- Receive    
      EXEC rdt.rdt_Receive_V7_L05    
         @nFunc         = @nFunc,    
         @nMobile       = @nMobile,    
         @cLangCode     = @cLangCode,    
         @nErrNo        = @nErrNo OUTPUT,    
         @cErrMsg       = @cErrMsg OUTPUT,    
         @cStorerKey    = @cStorerKey,    
         @cFacility     = @cFacility,    
         @cReceiptKey   = @cReceiptKey,    
         @cPOKey        = @cPoKey,  -- (ChewKP01)    
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
         @dLottable05   = @dLottable05,    
         @cLottable06   = @cLottable06,    
         @cLottable07   = @cLottable07,    
         @cLottable08   = @cLottable08,    
         @cLottable09   = @cLottable09,    
         @cLottable10   = @cLottable10,    
         @cLottable11 = @cLottable11,    
         @cLottable12   = @cLottable12,    
         @dLottable13   = @dLottable13,    
         @dLottable14   = @dLottable14,    
         @dLottable15   = @dLottable15,    
         @nNOPOFlag     = @nNOPOFlag,    
         @cConditionCode = @cConditionCode,    
         @cSubreasonCode = '',     
         @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT    
    
      IF @nErrNo <> 0    
         GOTO RollBackTran   
   END  
  
   GOTO Quit  
  
RollBackTran:      
   ROLLBACK TRAN rdt_607RcptCfm07    
Fail:      
Quit:      
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
      COMMIT TRAN    
      --insert into TraceInfo (TraceName, TimeIn, Col1) values ('607', getdate(), @dLottable05)   
END

GO