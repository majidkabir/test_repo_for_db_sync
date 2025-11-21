SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_523ExtUpd02                                     */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2018-06-04 1.0  Ung        WMS-4667 Created                          */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtUpd02] (  
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cID             NVARCHAR( 18),
   @cUCC            NVARCHAR( 20),
   @cLOC            NVARCHAR( 10),
   @cSuggestSKU     NVARCHAR( 20),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cSuggestedLOC   NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @nRowCount INT
   DECLARE @nTranCount INT

   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
      IF @nStep = 4  -- Suggest LOC, final LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @nPABookingKey INT
            
            -- Handling transaction
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_523ExtUpd02 -- For rollback or commit only our own transaction
            
            -- Unlock booking (booking was done at FN593 print label, 1 QTY 1 RFPutaway, and user key-in total QTY here)
            WHILE @nQTY > 0
            BEGIN
               SET @nPABookingKey = 0
               SELECT TOP 1 
                  @nPABookingKey = PABookingKey 
               FROM RFPutaway WITH (NOLOCK)
               WHERE FromLOC = @cLOC
                  AND FromID = @cID
                  AND SKU = @cSKU
                  AND QTY = 1
                  AND SuggestedLOC = @cSuggestedLOC

               IF @nPABookingKey > 0
               BEGIN
                  /*
                  EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
                     ,'' --FromLOC
                     ,'' --FromID
                     ,'' --SuggLOC
                     ,'' --Storer
                     ,@nErrNo  OUTPUT
                     ,@cErrMsg OUTPUT
                     ,@nPABookingKey = @nPABookingKey OUTPUT
                  IF @nErrNo <> 0  
                     GOTO RollBackTran
                  */
                  
                  -- Exceed base (nspItrnAddMovecheck) already deduced PendingMoveIn
                  DELETE RFPutaway WHERE PABookingKey = @nPABookingKey 
                  
                  SET @nQTY = @nQTY - 1
               END
               ELSE
                  BREAK
            END

            COMMIT TRAN rdt_523ExtUpd02 -- Only commit change made here
         END
      END
   END
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtUpd02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO