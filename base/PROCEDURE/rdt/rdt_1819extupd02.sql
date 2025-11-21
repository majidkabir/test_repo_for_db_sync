SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtUpd02                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate location type                                      */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-07-13   Ung       1.0   SOS346283 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtUpd02]
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

   DECLARE @cStorerKey NVARCHAR( 15)
   
   -- Get storer
   SELECT TOP 1 @cStorerKey = StorerKey FROM LOTxLOCxID WITH (NOLOCK) WHERE ID = @cFromID

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1819ExtUpd02 -- For rollback or commit only our own transaction

   -- Putaway By ID
   IF @nFunc = 1819
   BEGIN
      IF @nStep = 2 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cPickAndDropLOC <> ''
            BEGIN
               DECLARE @nSuccess          INT
               DECLARE @cNewTaskDetailKey NVARCHAR( 10)
               
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
                  GOTO Fail
               END
   
               -- Insert final task
               INSERT INTO TaskDetail (
                  TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, 
                  PickMethod, StorerKey, ListKey, TransitCount, SourceType, Priority, SourcePriority, TrafficCop)
               VALUES (
                  @cNewTaskDetailKey, 'PA1', '0', '', @cToLOC, @cFromID, @cSuggLOC, @cFromID, 
                  'FP', @cStorerKey, '', 0, 'rdt_1819ExtUpd02', '5', '5', NULL)
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
   
   COMMIT TRAN rdt_1819ExtUpd02 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtUpd02 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO