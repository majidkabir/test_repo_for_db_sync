SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtUpd05                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Generate PA1 task                                           */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-07-26   ChewKP    1.0   WMS-2514 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtUpd05]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFromID         NVARCHAR( 18),
   @cSuggLOC        NVARCHAR( 10),
   @cPickAndDropLOC NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSuccess          INT
   DECLARE @cNewTaskDetailKey NVARCHAR( 10)
   
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cUCC        NVARCHAR( 20)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nQTYPicked  INT
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cFinalLOC   NVARCHAR( 10)
   DECLARE @cFinalID    NVARCHAR( 18)
   DECLARE @cPalletType NVARCHAR( 10)
   DECLARE @cPAType     NVARCHAR( 10)
   DECLARE @cSUSR1      NVARCHAR( 18)

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1819ExtUpd05 -- For rollback or commit only our own transaction

   -- Putaway By ID
   IF @nFunc = 1819
   BEGIN
      IF @nStep = 2 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get login info
            SELECT @cFacility = Facility 
                  ,@cStorerKey = StorerKey
            FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
            
            -- Get pallet info
            SELECT TOP 1 
               @cFromLOC = LLI.LOC
               --@cStorerKey = StorerKey
               --@cSKU = SKU, 
               --@nQTYPicked = QTYPicked
            FROM LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.StorerKey = @cStorerKey
               AND LLI.ID = @cFromID 
               AND LLI.QTY > 0
            ORDER BY LLI.QTYPicked DESC
         

            -- Get new TaskDetailKey
            SET @cNewTaskDetailKey = ''
            SET @nSuccess = 1
            EXECUTE dbo.nspg_getkey
            	'TASKDETAILKEY'
            	, 10
            	, @cNewTaskDetailKey OUTPUT
            	, @nSuccess          OUTPUT
            	, @nErrNo            OUTPUT
            	, @cErrMsg           OUTPUT
            IF @nSuccess <> 1
            BEGIN
               SET @nErrNo = 113051
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
               GOTO RollBackTran
            END

            -- Insert PAF task (dummy task for PAType=61 load balancing to work)
            INSERT INTO TaskDetail (
               TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, 
               PickMethod, StorerKey, Message01, Message02, Message03, SourceType, Priority, SourcePriority, TrafficCop)
            VALUES (
               @cNewTaskDetailKey, 'PAF', 'X', SUSER_SNAME(), @cFromLOC, @cFromID, @cSuggLOC, @cFromID, 
               'PP', @cStorerKey, 'Dummy task for', 'PAType=62 to work', @nMobile, 'rdt_1819ExtUpd05', '9', '9', NULL)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 113052
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
               GOTO RollBackTran
            END

            UPDATE dbo.TaskDetail WITH (ROWLOCK) 
            SET Status = '9'
               ,Trafficcop = NULL 
            WHERE TaskDetailKey = @cNewTaskDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 113053
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskDetFail
               GOTO RollBackTran
            END
               
            
         END
      END
   END
   
   COMMIT TRAN rdt_1819ExtUpd05 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtUpd05 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO