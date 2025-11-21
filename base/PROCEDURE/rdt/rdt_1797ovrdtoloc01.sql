SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1797OvrdToLoc01                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2019-12-18  1.0  James    WMS11394. Created                          */
/* 2020-01-13  1.1  James    Add booking function if overwrite (james01)*/
/* 2020-03-10  1.2  SPChin   INC1066142 - Revise COMMIT TRAN            */
/************************************************************************/

CREATE PROC [RDT].[rdt_1797OvrdToLoc01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cTaskdetailKey   NVARCHAR( 10),
   @cSuggToLOC       NVARCHAR( 10),
   @cToLOC           NVARCHAR( 10),
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount          INT
   DECLARE @cTTMTaskType        NVARCHAR(10)
   DECLARE @cFromLOC            NVARCHAR(10)
   DECLARE @cFromID             NVARCHAR(18)
   DECLARE @cSKU                NVARCHAR(20)
   DECLARE @nQTY                INT
   DECLARE @nPABookingKey       INT
   DECLARE @cLOT                NVARCHAR( 10)
   DECLARE @cStorerKey          NVARCHAR( 15)
   DECLARE @cUserName           NVARCHAR( 18)
   
   SET @nErrNo = 0

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1797OvrdToLoc01 -- For rollback or commit only our own transaction
      
   -- Get task info
   SELECT 
      @cTTMTaskType = TaskType, 
      @cFromLOC = FromLoc,
      @cFromID = FromID,
      @cStorerKey = Storerkey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskdetailKey
   
   SET @cUserName = SUSER_SNAME()

   IF @cTTMTaskType = 'PAF'
   BEGIN
      SELECT @cSKU = SKU,
             @nQTY = Qty,
             @cLOT = Lot,
             @nPABookingKey = PABookingKey
      FROM dbo.RFPUTAWAY WITH (NOLOCK)
      WHERE FromLoc = @cFromLOC 
      AND   FromID = @cFromID
      AND   SuggestedLoc = @cSuggToLOC
      AND   StorerKey = @cStorerKey
      
      -- Unlock original suggested loc
      SET @nErrNo = 0
      -- Unlock by RPF task
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,''
         ,''
         ,''
         ,''
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,''
         ,0
         ,''
         ,''
         ,''
         ,''
         ,0
         ,@nPABookingKey
         ,''
         ,''
      IF @nErrNo <> 0
         GOTO RollBackTran 

      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         ToLoc = @cToLoc
      WHERE TaskDetailKey = @cTaskDetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 147201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OverWrite Fail
         GOTO RollBackTran
      END

      -- Lock user key in toloc
      SET @nErrNo = 0
      SET @nPABookingKey = 0
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cFromLOC
         ,@cFromID
         ,@cToLoc
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU          = @cSKU
         ,@nPutawayQTY   = @nQTY
         ,@cFromLOT      = @cLOT
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran
      SET @nErrNo = -1
   END

   COMMIT TRAN rdt_1797OvrdToLoc01 -- Only commit change made here
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1797OvrdToLoc01 -- Only rollback change made here
   
Quit:
   WHILE @@TRANCOUNT > @nTranCount  --INC1066142
      COMMIT TRAN                   --INC1066142

END

GO