SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtUpd04                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Generate PA1 task                                           */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-03-15   James     1.0   WMS1075. Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtUpd04]
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
   SAVE TRAN rdt_1819ExtUpd04 -- For rollback or commit only our own transaction

   -- Putaway By ID
   IF @nFunc = 1819
   BEGIN
      IF @nStep = 2 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF ISNULL( @cPickAndDropLOC, '') = ''
               GOTO Quit

            -- Get login info
            SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
            
            -- Get pallet info
            SELECT TOP 1 
               @cFromLOC = LLI.LOC, 
               @cStorerKey = StorerKey, 
               @cSKU = SKU, 
               @nQTYPicked = QTYPicked
            FROM LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.ID = @cFromID 
               AND LLI.QTY > 0
            ORDER BY LLI.QTYPicked DESC
         
            -- Determine pallet type
            IF @nQTYPicked > 0
               SET @cPalletType = 'PACK&HOLD'
            ELSE 
               SET @cPalletType = 'NORMAL'
         
            -- Outbound pallet (pack and hold)
            IF @cPalletType = 'PACK&HOLD'
               GOTO Quit

            -- Inbound pallet
            IF @cPalletType = 'NORMAL'
            BEGIN
               -- Check if pallet has mix sku
               IF NOT EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID WITH (NOLOCK)
                               WHERE StorerKey = @cStorerKey
                               AND   LOC = @cFromLoc 
                               AND   ID = @cFromID
                               GROUP BY ID 
                               HAVING COUNT( DISTINCT SKU) > 1)
               BEGIN -- no mix sku, use pallet putaway strategy
                  SET @cPAType = 'PALLET'
               END
               ELSE
               BEGIN
                  SET @cPAType = 'CASE'
               END

               -- Generate task
               IF @cPAType = 'CASE' 
               BEGIN
                  SET @cNewTaskDetailKey = ''

                  -- Loop UCC on ID
                  DECLARE @curUCC CURSOR
                  SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                     SELECT UCCNo
                     FROM dbo.UCC WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND LOC = @cToLOC
                        AND ID = @cFromID
                        AND Status = '1'
                  OPEN @curUCC
                  FETCH NEXT FROM @curUCC INTO @cUCC
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Get new TaskDetailKey
                     IF @cNewTaskDetailKey = ''
                     BEGIN
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
                           SET @nErrNo = 59851
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                           GOTO RollBackTran
                        END
                     END
             
                     -- Get final LOC
                     SELECT 
                        @cFinalLOC = SuggestedLOC, 
                        @cFinalID = ID
                     FROM dbo.RFPutaway WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND FromID = @cFromID
                        AND CaseID = @cUCC
            
                     -- Insert final task
                     INSERT INTO TaskDetail (
                        TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, CaseID, 
                        PickMethod, StorerKey, ListKey, TransitCount, SourceType, Priority, SourcePriority, TrafficCop)
                     VALUES (
                        @cNewTaskDetailKey, 'PAT', '0', '', @cToLOC, @cFromID, @cFinalLOC, @cFinalID, @cUCC, 
                        'PP', @cStorerKey, '', 0, 'rdt_1819ExtUpd04', '9', '9', NULL)
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 59852
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
                        GOTO RollBackTran
                     END
                     
                     SET @cNewTaskDetailKey = ''
                     FETCH NEXT FROM @curUCC INTO @cUCC
                  END

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
                     SET @nErrNo = 59851
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                     GOTO RollBackTran
                  END

                  -- Insert PAF task (dummy task for PAType=61 load balancing to work)
                  INSERT INTO TaskDetail (
                     TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, 
                     PickMethod, StorerKey, Message01, Message02, SourceType, Priority, SourcePriority, TrafficCop)
                  VALUES (
                     @cNewTaskDetailKey, 'PAF', '9', SUSER_SNAME(), @cFromLOC, @cFromID, @cPickAndDropLOC, @cFromID, 
                     'PP', @cStorerKey, 'Dummy task for', 'PAType=61 to work', 'rdt_1819ExtUpd04', '9', '9', NULL)
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 59852
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
                     GOTO RollBackTran
                  END
               END
               ELSE
               BEGIN 
                  SET @cNewTaskDetailKey = ''
                  -- Get new TaskDetailKey
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
                     SET @nErrNo = 55501
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                     GOTO RollBackTran
                  END
   
                  -- Insert final task
                  INSERT INTO TaskDetail (
                     TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, 
                     PickMethod, StorerKey, ListKey, TransitCount, SourceType, Priority, SourcePriority, TrafficCop)
                  VALUES (
                     @cNewTaskDetailKey, 'PA1', '0', '', @cToLOC, @cFromID, @cSuggLOC, @cFromID, 
                     'FP', @cStorerKey, '', 0, 'rdt_1819ExtUpd04', '5', '5', NULL)
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 55502
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
                     GOTO RollBackTran
                  END
               END
            END
         END
      END
   END
   
   COMMIT TRAN rdt_1819ExtUpd04 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtUpd04 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO