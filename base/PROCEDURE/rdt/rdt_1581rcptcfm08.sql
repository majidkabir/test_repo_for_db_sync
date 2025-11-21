SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1581RcptCfm08                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Use rdt_Receive_v7 to do receiving                                */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2021-03-08 1.0  yeekung    WMS-16502 Created                               */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1581RcptCfm08] (
   @nFunc            INT,  
   @nMobile          INT,  
   @cLangCode        NVARCHAR( 3), 
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cReceiptKey      NVARCHAR( 10), 
   @cPOKey           NVARCHAR( 10),	
   @cToLOC           NVARCHAR( 10), 
   @cToID            NVARCHAR( 18), 
   @cSKUCode         NVARCHAR( 20), 
   @cSKUUOM          NVARCHAR( 10), 
   @nSKUQTY          INT, 
   @cUCC             NVARCHAR( 20), 
   @cUCCSKU          NVARCHAR( 20), 
   @nUCCQTY          INT, 
   @cCreateUCC       NVARCHAR( 1),  
   @cLottable01      NVARCHAR( 18), 
   @cLottable02      NVARCHAR( 18), 
   @cLottable03      NVARCHAR( 18), 
   @dLottable04      DATETIME, 
   @dLottable05      DATETIME, 
   @nNOPOFlag        INT, 
   @cConditionCode   NVARCHAR( 10),
   @cSubreasonCode   NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT, 
   @cSerialNo        NVARCHAR( 30) = '', 
   @nSerialQTY       INT = 0, 
   @nBulkSNO         INT = 0,
   @nBulkSNOQTY      INT = 0
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @nQTY_Bal             INT,
        @nQTY                 INT,
        @nTranCount           INT,
        @bSuccess             INT,
        @cLabelPrinter        NVARCHAR( 10),
        @cReportType          NVARCHAR( 10),
        @cPrintJobName        NVARCHAR( 60),
        @cDataWindow          NVARCHAR( 50),
        @cTargetDB            NVARCHAR( 20),
        @cNewUCC              NVARCHAR( 20),
        @cCounter             NVARCHAR( 20),
        @cLOT                 NVARCHAR( 10)
        
      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN rdt_1581RcptCfm08

      --Get the oldest LOT with QTY    
      SELECT TOP 1 @dLottable05 = LA.Lottable05,
              @cLottable01= Lottable01,
              @cLottable02= Lottable02,
              @cLottable03= Lottable03
      FROM dbo.LOTATTRIBUTE LA WITH (NOLOCK)    
      JOIN dbo.LOTXLOCXID LLI WITH (NOLOCK)     
         ON LA.Lot = LLI.Lot AND LA.Storerkey = LLI.Storerkey AND LA.Sku = LLI.Sku    
      JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.Loc = LOC.Loc    
      WHERE LA.StorerKey = @cStorerKey    
      AND   LA.Sku = @cSKUCode    
      AND   LLI.Qty > 0 
      GROUP BY Lottable01,Lottable02,Lottable03,Lottable05
      HAVING LA.lottable05= MIN( LA.Lottable05)

      --If such LOT not exist, return today date    
      IF ISNULL(@dLottable05,'') = ''    
         SET @dLottable05 = CONVERT(DATETIME, CONVERT(CHAR(20), GETDATE(), 112))     
                                                                       
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
         @cLottable06   = '',                                              
         @cLottable07   = '',                                              
         @cLottable08   = '',                                              
         @cLottable09   = '',                                              
         @cLottable10   = '',                                              
         @cLottable11   = '',                                              
         @cLottable12   = '',                                              
         @dLottable13   = NULL,                                            
         @dLottable14   = NULL,                                            
         @dLottable15   = NULL,                                            
         @nNOPOFlag     = @nNOPOFlag,                                      
         @cConditionCode = @cConditionCode,                                
         @cSubreasonCode = '',                                             
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT      

      IF @nErrNo <> 0
         GOTO RollBackTran

   GOTO Quit

   RollBackTran:  
      ROLLBACK TRAN rdt_1581RcptCfm08 

   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  


GO