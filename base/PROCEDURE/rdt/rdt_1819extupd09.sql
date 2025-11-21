SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtUpd09                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Generate PA1 task                                           */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2020-05-19   James     1.0   WMS-12964. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtUpd09]
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
   DECLARE @nCnt        INT
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
   SAVE TRAN rdt_1819ExtUpd09 -- For rollback or commit only our own transaction

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
               SET @nCnt = 0
               SELECT @nCnt = SUM( Cnt) FROM (
               SELECT COUNT(1) AS Cnt 
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
               WHERE LLI.StorerKey = @cStorerKey
               AND   LLI.LOC = @cFromLoc 
               AND   LLI.ID = @cFromID
               GROUP BY LLI.ID, LA.Sku, LA.Lottable02, LA.Lottable03, LA.Lottable04
               HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) > 0) A

               -- Check if pallet has mix sku   
               IF ISNULL( @nCnt, 0) = 1
                  SET @cPAType = 'PALLET' -- no mix sku, use pallet putaway strategy
               ELSE
                  SET @cPAType = 'CASE'
               
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
                           SET @nErrNo = 152401
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
                        'PP', @cStorerKey, '', 0, 'rdt_1819ExtUpd09', '9', '9', NULL)
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 152402
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
                     SET @nErrNo = 152403
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                     GOTO RollBackTran
                  END

                  -- Insert PAF task (dummy task for PAType=61 load balancing to work)
                  INSERT INTO TaskDetail (
                     TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, 
                     PickMethod, StorerKey, Message01, Message02, SourceType, Priority, SourcePriority, TrafficCop)
                  VALUES (
                     @cNewTaskDetailKey, 'PAF', '9', SUSER_SNAME(), @cFromLOC, @cFromID, @cPickAndDropLOC, @cFromID, 
                     'PP', @cStorerKey, 'Dummy task for', 'PAType=61 to work', 'rdt_1819ExtUpd09', '9', '9', NULL)
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 152404
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
                     SET @nErrNo = 152405
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                     GOTO RollBackTran
                  END
   
                  -- Insert final task
                  INSERT INTO TaskDetail (
                     TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, 
                     PickMethod, StorerKey, ListKey, TransitCount, SourceType, Priority, SourcePriority, TrafficCop)
                  VALUES (
                     @cNewTaskDetailKey, 'PA1', '0', '', @cToLOC, @cFromID, @cSuggLOC, @cFromID, 
                     'FP', @cStorerKey, '', 0, 'rdt_1819ExtUpd09', '5', '5', NULL)
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 152406
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
                     GOTO RollBackTran
                  END
               END
            END
         END
      END
   END
   
   COMMIT TRAN rdt_1819ExtUpd09 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtUpd09 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO