SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1742Confirm01                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Update PickDetail.ToLOC                                     */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2024-01-22  1.0  Ung      WMS-24657 Create based on base             */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1742Confirm01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),  
   @cDropID          NVARCHAR( 20), 
   @cSuggLOC         NVARCHAR( 10), 
   @cPickAndDropLOC  NVARCHAR( 10), 
   @cToLOC           NVARCHAR( 10), 
   @nPABookingKey    INT           OUTPUT, 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cConfirmSP  NVARCHAR( 20)

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   DECLARE @cMoveQTYAlloc  NVARCHAR( 1)
   DECLARE @cMoveQTYPick   NVARCHAR( 1)
   DECLARE @cToID          NVARCHAR( 18)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @cID            NVARCHAR( 18)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @nQTY           INT
   DECLARE @nQTYAlloc      INT
   DECLARE @nQTYPick       INT
   DECLARE @cStatus        NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @curPD          CURSOR

   -- Storer config
   SET @cMoveQTYAlloc = rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cMoveQTYPick = rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)

   -- Get LoseID
   DECLARE @cLoseID NVARCHAR(1)
   SELECT @cLoseID = @cLoseID FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLOC

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1742Confirm01 -- For rollback or commit only our own transaction

   -- Loop drop ID
   SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT LOT, LOC, ID, SKU, QTY, Status, PickDetailKey
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND DropID = @cDropID
         AND Status = '5'
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cLOT, @cLOC, @cID, @cSKU, @nQTY, @cStatus, @cPickDetailKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @cMoveQTYAlloc = '1' OR @cMoveQTYPick = '1'
      BEGIN
         IF @cLoseID = '1'
            SET @cToID = ''
         ELSE
            SET @cToID = @cID
            
         IF @cStatus = '5'
         BEGIN
            SET @nQTYAlloc = 0
            SET @nQTYPick = @nQTY
         END
         ELSE
         BEGIN
            SET @nQTYAlloc = @nQTY
            SET @nQTYPick = 0
         END

         -- Execute move process
         EXECUTE rdt.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode, 
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
            @cSourceType = 'rdt_1742Confirm01', 
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility, 
            @cFromLOC    = @cLOC, 
            @cToLOC      = @cToLOC, 
            @cFromID     = @cID, 
            @cToID       = @cToID,  -- NULL means not changing ID
            @cSKU        = @cSKU, 
            @nQTY        = @nQTY, 
            @nQTYAlloc   = @nQTYAlloc,
            @nQTYPick    = @nQTYPick,
            @cDropID     = @cDropID, 
            @cFromLOT    = @cLOT, 
            @nFunc       = @nFunc
         IF @nErrNo <> 0
            GOTO RollBackTran
            
      END
      
      UPDATE dbo.PickDetail SET
         TOLOC = @cToLOC, 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME()
      WHERE PickDetailKey = @cPickDetailKey
      SET @nErrNo = @@ERROR  
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO Quit
      END
      
      FETCH NEXT FROM @curPD INTO @cLOT, @cLOC, @cID, @cSKU, @nQTY, @cStatus, @cPickDetailKey
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

   COMMIT TRAN rdt_1742Confirm01 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1742Confirm01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

SET QUOTED_IDENTIFIER OFF

GO