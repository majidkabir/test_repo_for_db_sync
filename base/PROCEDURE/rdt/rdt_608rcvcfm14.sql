SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdt_608RcvCfm14                                        */  
/* Copyright      : LF Logistics                                           */  
/*                                                                         */  
/* Purpose: update skutradereturn                                          */  
/*                                                                         */  
/* Date       Rev  Author  Purposes                                        */  
/* 2023-04-24 1.0  yeekung WMS-22622 Created                               */
/***************************************************************************/  
  
CREATE   PROC [RDT].[rdt_608RcvCfm14](  
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

   DECLARE @nTranCount INT
   DECLARE @cDocType NVARCHAR(20)
  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_608RcvCfm14 -- For rollback or commit only our own transaction  

   SELECT
      @cDocType = DocType
   FROM dbo.Receipt (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey

 
   SELECT @cToLOC =  CASE WHEN @cDocType ='N' THEN receiptloc 
                          WHEN @cDocType ='R' THEN ReturnLOC
                          WHEN @cDocType ='X' THEN xdockreceiptloc END
   FROM SKU (NOLOCK)
   WHERE SKU = @cSKUCode
      AND Storerkey = @cStorerKey

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

      GOTO Quit  
  
RollBackTran:    
   ROLLBACK TRAN rdt_608RcvCfm14   
Fail:    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN  
  
  
END  

GO