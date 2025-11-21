SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ConfirmSP01                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 25-03-2020  1.0  Ung      WMS-12634 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_521ConfirmSP01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cLOT             NVARCHAR( 10),
   @cUCCNo           NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cToLOC           NVARCHAR( 10),
   @cSuggestedLOC    NVARCHAR( 10),
   @cPickAndDropLoc  NVARCHAR( 10),
   @nPABookingKey    INT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSwapLOT    NVARCHAR( 1)
   DECLARE @cChkQuality NVARCHAR( 10)
   DECLARE @cITrnKey    NVARCHAR( 10)
   DECLARE @cUCC_SKU    NVARCHAR( 20)
   DECLARE @cUCC_LOT    NVARCHAR( 10)
   DECLARE @nUCC_QTY    INT
   DECLARE @nUCC_RowRef INT
   
   -- Check move allowed 
   EXEC rdt.rdt_UAMoveCheck @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility
      ,@cFromLOC 
      ,@cToLOC 
      ,'P' -- Type P=Putaway
      ,@cSwapLOT     OUTPUT
      ,@cChkQuality  OUTPUT
      ,@nErrNo       OUTPUT
      ,@cErrMsg      OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

   -- Get LOC info  
   DECLARE @cLoseID  NVARCHAR( 1)
   DECLARE @cLoseUCC NVARCHAR( 1)
   SELECT   
      @cLoseID = LoseID,   
      @cLoseUCC = LoseUCC  
   FROM LOC WITH (NOLOCK)   
   WHERE LOC = @cToLOC  

	-- Handling transaction
	DECLARE @nTranCount INT
	SET @nTranCount = @@TRANCOUNT
	BEGIN TRAN  -- Begin our own transaction
	SAVE TRAN rdt_521ConfirmSP01 -- For rollback or commit only our own transaction

   -- Loop UCC
   DECLARE @curUCC CURSOR
   SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT UCC_RowRef, SKU, QTY, LOT
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCCNo
         AND [Status] = '1'
   OPEN @curUCC
   FETCH NEXT FROM @curUCC INTO @nUCC_RowRef, @cUCC_SKU, @nUCC_QTY, @cUCC_LOT
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Swap lottables
      IF @cSwapLOT = '1'
      BEGIN
         EXEC rdt.rdt_UATransfer @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility
            ,@cFromLOC
            ,@cID
            ,@cUCC_LOT
            ,@cUCC_SKU
            ,@nUCC_QTY
            ,@cChkQuality
            ,@cITrnKey OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
            
         -- Get new LOT
         SELECT @cUCC_LOT = LOT FROM ITrn WITH (NOLOCK)WHERE ITrnKey = @cITrnKey
      END
       
      -- Execute move process
      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode, 
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
         @cSourceType = 'rdt_521ConfirmSP01', 
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility, 
         @cFromLOC    = @cFromLOC, 
         @cToLOC      = @cToLOC, 
         @cFromID     = @cID, 
         @cToID       = NULL,  -- NULL means not changing ID
         @nFunc       = @nFunc, 
         @cSKU        = @cUCC_SKU, 
         @nQTY        = @nUCC_QTY, 
         @cFromLOT    = @cUCC_LOT
      IF @nErrNo <> 0
         GOTO RollBackTran

      -- Update UCC
      UPDATE dbo.UCC WITH (ROWLOCK) SET 
         LOT = @cUCC_LOT, 
         ID = CASE WHEN @cLoseID = '1' THEN '' ELSE ID END,   
         LOC = @cToLOC,   
         Status = CASE WHEN @cLoseUCC = '1' THEN '6' ELSE Status END, 
         EditWho  = SUSER_SNAME(),    
         EditDate = GETDATE()
      WHERE UCC_RowRef = @nUCC_RowRef
      IF @@ERROR <> 0
      BEGIN    
         SET @nErrNo = 50020 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UPD UCC FAIL 
         GOTO RollBackTran    
      END    

      FETCH NEXT FROM @curUCC INTO @nUCC_RowRef, @cUCC_SKU, @nUCC_QTY, @cUCC_LOT
   END

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

   COMMIT TRAN rdt_521ConfirmSP01 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_521ConfirmSP01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO