SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607ExtUpd03                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: print label                                                       */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 05-Mar-2018  ChewKP    1.0   WMS-3836 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_607ExtUpd03]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nAfterStep    INT,            
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),   
   @cStorerKey    NVARCHAR( 15), 
   @cReceiptKey   NVARCHAR( 10), 
   @cPOKey        NVARCHAR( 10), 
   @cRefNo        NVARCHAR( 20), 
   @cSKU          NVARCHAR( 20), 
   @nQTY          INT,           
   @cLottable01   NVARCHAR( 18), 
   @cLottable02   NVARCHAR( 18), 
   @cLottable03   NVARCHAR( 18), 
   @dLottable04   DATETIME,      
   @dLottable05   DATETIME,      
   @cLottable06   NVARCHAR( 30), 
   @cLottable07   NVARCHAR( 30), 
   @cLottable08   NVARCHAR( 30), 
   @cLottable09   NVARCHAR( 30), 
   @cLottable10   NVARCHAR( 30), 
   @cLottable11   NVARCHAR( 30), 
   @cLottable12   NVARCHAR( 30), 
   @dLottable13   DATETIME,      
   @dLottable14   DATETIME,      
   @dLottable15   DATETIME, 
   @cReasonCode   NVARCHAR( 5), 
   @cSuggID       NVARCHAR( 18), 
   @cSuggLOC      NVARCHAR( 10), 
   @cID           NVARCHAR( 18), 
   @cLOC          NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5), 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess INT
   DECLARE @nTranCount INT
          ,@cUserName      NVARCHAR(18)

   SET @nTranCount = @@TRANCOUNT
   
   DECLARE @cPrinter NVARCHAR(10)
   SELECT @cPrinter = Printer 
         ,@cUserName = UserName
   FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile 
         
         
   IF @nFunc = 607 -- Return V7
   BEGIN  
      IF @nStep = 5 -- ID, LOC
      BEGIN
         -- Clean Up RFPutaway
         --VALUES (@cStorerKey, @cSKU, @cLOT, @cLOC, @cID, @cSuggLOC, @cID, @cUserName, @nQTY, '')    
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'UNLOCK'      
               ,''      
               ,''      
               ,@cSuggLOC     
               ,@cStorerKey    
               ,@nErrNo  OUTPUT      
               ,@cErrMsg OUTPUT      
               ,@cSKU
                
            IF @nErrNo <> 0      
               GOTO RollBackTran   
         
         
         
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_607ExtUpd03 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

SET QUOTED_IDENTIFIER OFF

GO