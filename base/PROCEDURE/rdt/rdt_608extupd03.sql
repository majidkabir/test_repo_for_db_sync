SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/******************************************************************************/  
/* Store procedure: rdt_608ExtUpd03                                           */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Calc suggest location, booking                                    */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 08-Aug-2016  ChewKP    1.0   SOS#374476 Created                            */  
/* 08-Sep-2022  Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_608ExtUpd03]  
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
   @cRefNo        NVARCHAR( 60),   
   @cID           NVARCHAR( 18),   
   @cLOC          NVARCHAR( 10),   
   @cMethod       NVARCHAR( 1),   
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
   @cRDLineNo     NVARCHAR( 5),   
   @nErrNo        INT           OUTPUT,   
   @cErrMsg       NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @bSuccess    INT  
   DECLARE @nTranCount  INT  
          ,@cStyle      NVARCHAR(20)       
          ,@cColor      NVARCHAR(10)
          ,@cLot        NVARCHAR(10) 
          ,@cSuggToLOC  NVARCHAR(10) 

   SET @nTranCount = @@TRANCOUNT  

   BEGIN TRAN  
   SAVE TRAN rdt_608ExtUpd03  
  
   IF @nFunc = 608 -- Piece return  
   BEGIN    
      IF @nStep = 4 AND @nInputKey = 1 
      BEGIN 
        
        IF ISNULL(@cSKU,'' )  <> '' 
        BEGIN 
            SET @cSuggToLOC = ''
--            IF EXISTS ( SELECT 1 FROM dbo.SKUXLOC SL WITH (NOLOCK) 
--                        INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = SL.Loc
--                        INNER JOIN dbo.PutawayZone PZ WITH (NOLOCK) ON PZ.PutawayZone = Loc.Putawayzone
--                        WHERE SL.StorerKey = @cStorerKey
--                        AND SL.SKU = @cSKU
--                        AND SL.Qty > 0 )
                        --AND PZ.ZoneCategory = 'VF'  ) 
            --BEGIN 
               SET @cLOT = ''  
               EXECUTE dbo.nsp_LotLookUp @cStorerKey, @cSKU  
                  , @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05  
                  , @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10  
                  , @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15  
                  , @cLOT      OUTPUT  
                  , @bSuccess  OUTPUT  
                  , @nErrNo    OUTPUT  
                  , @cErrMsg   OUTPUT  
              
               -- Create LOT if not exist  
               IF @cLOT IS NULL  
               BEGIN  
                  EXECUTE dbo.nsp_LotGen @cStorerKey, @cSKU  
                     , @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05  
                     , @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10  
                     , @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15  
                     , @cLOT     OUTPUT  
                     , @bSuccess OUTPUT  
                     , @nErrNo   OUTPUT  
                     , @cErrMsg  OUTPUT  

                  IF @bSuccess <> 1  
                     GOTO RollbackTran  
               END
                  
               -- Location Searching Sequence
               -- QKS_Y2C > QKS_Y2D > QKS_Y2F > QKS_Y2B > QKS_Y2A
               

               SELECT TOP 1  
                       @cSuggToLOC = SL.LOC  
               FROM dbo.SKUxLoc SL WITH (NOLOCK)    
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = SL.Loc 
               WHERE SL.SKU = @cSKU 
               AND SL.Qty - SL.QTYPicked > 0 
               AND Loc.PutawayZone = 'QKS_Y2C'
               AND SL.Loc <> @cLOC
               ORDER by 
                  SL.Qty
               ,  SL.Loc
               
               IF @cSuggToLoc <> '' 
               BEGIN
                  GOTO DO_BOOKING
               END
               
               SELECT TOP 1  
                       @cSuggToLOC = SL.LOC  
               FROM dbo.SKUxLoc SL WITH (NOLOCK)    
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = SL.Loc 
               WHERE SL.SKU = @cSKU 
               AND SL.Qty - SL.QTYPicked > 0 
               AND Loc.PutawayZone = 'QKS_Y2D'
               AND SL.Loc <> @cLOC
               ORDER by 
                  SL.Qty
               ,  SL.Loc
               
               IF @cSuggToLoc <> '' 
               BEGIN
                  GOTO DO_BOOKING
               END
               
               SELECT TOP 1  
                       @cSuggToLOC = SL.LOC  
               FROM dbo.SKUxLoc SL WITH (NOLOCK)    
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = SL.Loc 
               WHERE SL.SKU = @cSKU 
               AND SL.Qty - SL.QTYPicked > 0 
               AND Loc.PutawayZone = 'QKS_Y2F'
               AND SL.Loc <> @cLOC
               ORDER by 
                  SL.Qty
               ,  SL.Loc
               
               IF @cSuggToLoc <> '' 
               BEGIN
                  GOTO DO_BOOKING
               END
               
               SELECT TOP 1  
                       @cSuggToLOC = SL.LOC  
               FROM dbo.SKUxLoc SL WITH (NOLOCK)    
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = SL.Loc 
               WHERE SL.SKU = @cSKU 
               AND SL.Qty - SL.QTYPicked > 0 
               AND Loc.PutawayZone = 'QKS_Y2B'
               AND SL.Loc <> @cLOC
               ORDER by 
                  SL.Qty
               ,  SL.Loc
               
               IF @cSuggToLoc <> '' 
               BEGIN
                  GOTO DO_BOOKING
               END
               
               SELECT TOP 1  
                       @cSuggToLOC = SL.LOC  
               FROM dbo.SKUxLoc SL WITH (NOLOCK)    
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = SL.Loc 
               WHERE SL.SKU = @cSKU 
               AND SL.Qty - SL.QTYPicked > 0 
               AND Loc.PutawayZone = 'QKS_Y2A'
               AND SL.Loc <> @cLOC
               ORDER by 
                  SL.Qty
               ,  SL.Loc
               
               IF @cSuggToLoc <> '' 
               BEGIN
                  GOTO DO_BOOKING
               END
               
               
               
               DO_BOOKING:
               

               IF ISNULL(@cSuggToLoc,'')  <> '' 
               BEGIN
                  

                  IF NOT EXISTS ( SELECT 1 FROM dbo.RFPutaway WITH (NOLOCK) 
                                  WHERE StorerKey = @cStorerKey
                                  AND SKU = @cSKU
                                  AND Lot = @cLot
                                  AND FromLoc = @cLoc
                                  AND FromID = @cID
                                  AND SuggestedLoc = @cSuggToLOC
                                  AND ID = @cID ) 
                  BEGIN 
                     INSERT INTO RFPutaway (Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, QTY, CaseID)  
                     VALUES (@cStorerKey, @cSKU, @cLOT, @cLOC, @cID, @cSuggToLOC, @cID, SUSER_SNAME(), @nQTY, '')  
                  
                     SET @nErrNo = @@ERROR  
                  
                     IF @nErrNo <> 0  
                     BEGIN  
                        SET @nErrNo = 97701
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- InsRFPAFail
                        GOTO RollbackTran  
                     END  
                  END
                  ELSE
                  BEGIN
                     UPDATE RFPutaway WITH (ROWLOCK) 
                     SET Qty = Qty + @nQty 
                     WHERE StorerKey = @cStorerKey
                     AND SKU = @cSKU
                     AND Lot = @cLot
                     AND FromLoc = @cLoc
                     AND FromID = @cID
                     AND SuggestedLoc = @cSuggToLOC
                     AND ID = @cID

                     IF @nErrNo <> 0  
                     BEGIN  
                        SET @nErrNo = 97701
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- InsRFPAFail
                        GOTO RollbackTran  
                     END  
                  END
                
                  
                  UPDATE rdt.rdtmobrec WITH (ROWLOCK) 
                  SET V_String28 = @cSuggToLOC
                  WHERE Mobile = @nMobile
                  
                  
                  GOTO QUIT
               END

               
               
            --END

        END
            
      END
   
   END  
   GOTO Quit  
     
RollBackTran:  
   ROLLBACK TRAN rdt_608ExtUpd03 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_608ExtUpd03
END  
  

GO