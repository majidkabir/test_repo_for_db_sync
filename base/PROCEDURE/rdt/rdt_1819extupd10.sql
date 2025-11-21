SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1819ExtUpd10                                          */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Purpose: Validate location type                                            */
/*                                                                            */
/* Date         Author    Ver.      Purposes                                  */
/* 2024-03-08   Ung       1.0       Dennis Created                            */
/* 2024-06-17   VBH079    1.1       Updated to use putaway type               */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1819ExtUpd10]
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
   --VBH079
   DECLARE @cLocRoom NVARCHAR(30)
   DECLARE @cPAType  NVARCHAR(10)
   DECLARE @cStatus  NVARCHAR(10)
   DECLARE @cAreaKey NVARCHAR(30)
   
   -- Get storer
   SELECT TOP 1 @cStorerKey = StorerKey FROM LOTxLOCxID WITH (NOLOCK) WHERE ID = @cFromID

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1819ExtUpd10 -- For rollback or commit only our own transaction

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
               --if to location room is oversized the create PA1 VBH079
               SELECT TOP 1 @cLocRoom = LocationRoom , @cAreaKey = adt.AreaKey
               FROM LOC (NOLOCK) loc LEFT JOIN AREADETAIL (NOLOCK) adt
               ON loc.PutawayZone = adt.PutawayZone
               WHERE LOC = @cSuggLOC 
      
               IF @cLocRoom = 'OVERSIZED' 
               BEGIN
                  SET @cPAType = 'PA1'
                  SET @cStatus = '0'
               END
               ELSE
               BEGIN
                  SET @cPAType = 'VNAIN'
                  SET @cStatus = 'Q'
               END
               
               --VBH079 Changed to use putaway type as variable
                  -- Insert final task
                  --INSERT INTO TaskDetail (
                  --   TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, 
                  --   PickMethod, StorerKey, ListKey, TransitCount, SourceType, Priority, SourcePriority, TrafficCop)
                  --VALUES (
                  --   @cNewTaskDetailKey, 'VNAIN', 'Q', '', @cToLOC, @cFromID, @cSuggLOC, @cFromID, 
                  --   'FP', @cStorerKey, '', 0, 'rdt_1819ExtUpd10', '2', '5', NULL)

               INSERT INTO TaskDetail (
                  TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, 
                  PickMethod, StorerKey, ListKey, TransitCount, SourceType, Priority, SourcePriority, TrafficCop, AreaKey)
                  VALUES (
                     @cNewTaskDetailKey, @cPAType, @cStatus, '', @cToLOC, @cFromID, @cSuggLOC, @cFromID, 
                     'FP', @cStorerKey, '', 0, 'rdt_1819ExtUpd10', '2', '5', NULL, @cAreaKey)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 55502
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
                  GOTO RollBackTran
               END
            END -- PnD Loc <> ''
         END --  inputkey=1
      END -- step2
   END -- 1819
   
   COMMIT TRAN rdt_1819ExtUpd10 -- Only commit change made here
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1819ExtUpd10 -- Only rollback change made here
   Fail:
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
END -- end sp

GO