SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ConfirmSP01                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 25-03-2020  1.0  Ung      WMS-12631 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ConfirmSP01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18), 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cFromLOC         NVARCHAR( 10), 
   @cFromID          NVARCHAR( 18), 
   @cSuggLOC         NVARCHAR( 10), 
   @cPickAndDropLOC  NVARCHAR( 10), 
   @cToLOC           NVARCHAR( 10), 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSwapLOT    NVARCHAR( 1)
   DECLARE @cChkQuality NVARCHAR( 10)
   DECLARE @cITrnKey    NVARCHAR( 10)
   DECLARE @cFromLOT    NVARCHAR( 10)
   DECLARE @cUCC_LOT    NVARCHAR( 10)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nQTY        INT
   DECLARE @nUCC_RowRef INT

   -- Check move allowed 
   EXEC rdt.rdt_UAMoveCheck @nMobile, @nFunc, @cLangCode, 3, 1, @cStorerKey, @cFacility
      ,@cFromLOC 
      ,@cToLOC 
      ,'P' -- Type
      ,@cSwapLOT     OUTPUT
      ,@cChkQuality  OUTPUT
      ,@nErrNo       OUTPUT
      ,@cErrMsg      OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

	-- Handling transaction
	DECLARE @nTranCount INT
	SET @nTranCount = @@TRANCOUNT
	BEGIN TRAN  -- Begin our own transaction
	SAVE TRAN rdt_1819ConfirmSP01 -- For rollback or commit only our own transaction
   
   -- Swap lottables
   IF @cSwapLOT = '1'
   BEGIN
   	-- Loop LLI
   	DECLARE @curLLI CURSOR
   	SET @curLLI = CURSOR LOCAL READ_ONLY STATIC FOR -- Cannot use FAST_FORWARD as transfer will insert new record into LLI and fetch by cursor
   		SELECT LLI.SKU, LLI.LOT, LLI.QTY-LLI.QTYAllocated-LLI.QTYPicked AS QTY
   		FROM LOTxLOCxID LLI WITH (NOLOCK)
   		WHERE LLI.LOC = @cFromLOC
   			AND LLI.ID = @cFromID
   			AND LLI.QTY-LLI.QTYAllocated-LLI.QTYPicked > 0
      OPEN @curLLI 
      FETCH NEXT FROM @curLLI INTO @cSKU, @cFromLOT, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         EXEC rdt.rdt_UATransfer @nMobile, @nFunc, @cLangCode, 2, 1, @cStorerKey, @cFacility
            ,@cFromLOC
            ,@cFromID
            ,@cFromLOT
            ,@cSKU
            ,@nQTY
            ,@cChkQuality
            ,@cITrnKey OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
            
         -- Get new LOT
         SELECT @cUCC_LOT = LOT FROM ITrn WITH (NOLOCK)WHERE ITrnKey = @cITrnKey

         -- Loop UCC
         DECLARE @curUCC CURSOR
         SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT UCC_RowRef
            FROM dbo.UCC WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND LOC = @cFromLOC
               AND ID = @cFromID
               AND LOT = @cFromLOT
               AND [Status] = '1'
         OPEN @curUCC
         FETCH NEXT FROM @curUCC INTO @nUCC_RowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update UCC
            UPDATE dbo.UCC WITH (ROWLOCK) SET 
               LOT = @cUCC_LOT, 
               EditWho  = SUSER_SNAME(),    
               EditDate = GETDATE()
            WHERE UCC_RowRef = @nUCC_RowRef
            IF @@ERROR <> 0
            BEGIN    
               SET @nErrNo = 50020 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UPD UCC FAIL 
               GOTO RollBackTran    
            END
            FETCH NEXT FROM @curUCC INTO @nUCC_RowRef
         END

         FETCH NEXT FROM @curLLI INTO @cSKU, @cFromLOT, @nQTY
      END
   END

   -- Execute move process
   EXECUTE rdt.rdt_Move
      @nMobile     = @nMobile,
      @cLangCode   = @cLangCode, 
      @nErrNo      = @nErrNo  OUTPUT,
      @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
      @cSourceType = 'rdt_1819ConfirmSP01', 
      @cStorerKey  = @cStorerKey,
      @cFacility   = @cFacility, 
      @cFromLOC    = @cFromLOC, 
      @cToLOC      = @cToLOC, 
      @cFromID     = @cFromID, 
      @cToID       = NULL,  -- NULL means not changing ID
      @nFunc       = @nFunc
   IF @nErrNo <> 0
      GOTO RollBackTran

   IF @cPickAndDropLOC <> ''
      SET @cSuggLOC = @cPickAndDropLOC

   -- Unlock SuggestedLOC
   EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK' 
      ,''        --@cLOC      
      ,@cFromID  --@cID       
      ,@cSuggLOC --@cSuggLOC 
      ,''        --@cStorerKey
      ,@nErrNo  OUTPUT
      ,@cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

   COMMIT TRAN rdt_1819ConfirmSP01 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ConfirmSP01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO