SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/******************************************************************************/  
/* Store procedure: rdt_607ExtUpd04                                          */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: print label                                                       */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 06-05-2020   YeeKung   1.0    WMS-12705 Created                            */
/* 22-06-2020   YeeKung   1.1    WMS13847- Suggloc empty not need update      */
/*                                         (yeekung01)                        */   
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_607ExtUpd04]  
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
          ,@cNewSuggToLOC  NVARCHAR(20) 
  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN                
   SAVE TRAN rdt_607ExtUpd04 
     
           
   IF @nFunc = 607 -- Return V7  
   BEGIN    
      IF @nStep = 5 -- ID, LOC  
      BEGIN  

         DECLARE @cLOT NVARCHAR (20)

         SELECT TOP 1 @cNewSuggToLOC = LLI.LOC       
         FROM LOTxLOCxID LLI WITH (NOLOCK)     
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)   
         JOIN LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)    
         WHERE LLI.StorerKey = @cstorerkey   
         AND LLI.SKU = @cSKU     
         AND LOC.Facility=@cFacility
         AND LOC.HostWHCode =(SELECT ISNULL(HOSTWHCODE,'') FROM LOC WHERE 
         LOC=@cSuggLoc)
         AND LLI.QTY - LLI.QTYPicked > 0    
         AND LOC.LocationCategory <> 'STAGE'
         GROUP BY LLI.LOC
         ORDER BY SUM( LLI.QTY - LLI.QTYPicked), LLI.LOC
         
         SELECT TOP 1 @cLOT=LOT
         FROM LOTXLOCXID (NOLOCK)
         WHERE sku=@cSKU
         AND loc=@cSuggLoc
         AND ID=CASE WHEN ISNULL(@cSuggID,'')='' THEN ID ELSE @cSuggID END
         AND QTY<>0

         IF ISNULL(@cNewSuggToLOC,'') <>'' 
         BEGIN     
            INSERT INTO RFPUTAWAY(storerkey,sku,lot,fromloc,suggestedloc,fromid,id,ptcid,qty)
            values(@cstorerkey,@cSKU,@cLOT,@cLoc,@cNewSuggToLOC,@cID,'',sUser_sName(),@nQty)

            IF @nErrNo <> 0 
            BEGIN     
               SET @nErrNo = 151851    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsRFFail    
               GOTO RollBackTran
            END    
            --SET @nErrNo = 151852   
            --SET @cErrMsg = @cSuggLoc--rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsRFFail    
            --GOTO RollBackTran
         END 



                  
 
      END  
   END  
   GOTO Quit  
     
RollBackTran:  
   ROLLBACK TRAN rdt_607ExtUpd04 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO