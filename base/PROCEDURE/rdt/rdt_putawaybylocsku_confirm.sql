SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PutawayByLOCSKU_Confirm                         */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 15-08-2019  1.0  Ung      WMS-10056 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_PutawayByLOCSKU_Confirm] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT, 
   @nInputKey     INT, 
   @cStorerKey    NVARCHAR( 15), 
   @cFacility     NVARCHAR( 5), 
   @cLOC          NVARCHAR( 10),
   @cID           NVARCHAR( 18),
   @cSKU          NVARCHAR( 20), 
   @nQTY          INT, 
   @cFinalLOC     NVARCHAR( 10), 
   @cSuggestedLOC NVARCHAR( 10), 
   @nPABookingKey INT           OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PutawayByLOCSKU_Confirm -- For rollback or commit only our own transaction

   -- Execute move
   EXEC rdt.rdt_Move
      @nMobile     	= @nMobile,
      @cLangCode   	= @cLangCode,
      @nErrNo      	= @nErrNo  OUTPUT,
      @cErrMsg     	= @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
      @cSourceType 	= 'rdt_PutawayByLOCSKU_Confirm',
      @cStorerKey  	= @cStorerKey,
      @cFacility   	= @cFacility,
      @cFromLOC    	= @cLOC,
      @cToLOC      	= @cFinalLOC,
      @cFromID     	= @cID, -- NULL means not filter by ID. Blank is a valid ID
      @cToID       	= NULL, -- NULL means not changing ID. Blank consider a valid ID
      @cSKU        	= @cSKU,
      @nQTY        	= @nQTY,
		@nFunc   		= @nFunc 
   IF @nErrNo <> 0
      GOTO RollBackTran

   -- Unlock current session suggested LOC
   IF @nPABookingKey <> 0
   BEGIN
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
   
      SET @nPABookingKey = 0
   END

   COMMIT TRAN rdt_PutawayByLOCSKU_Confirm -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PutawayByLOCSKU_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO