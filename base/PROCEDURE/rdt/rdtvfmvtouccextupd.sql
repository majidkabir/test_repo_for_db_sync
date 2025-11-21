SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdtVFMvToUccExtUpd                                  */  
/* Purpose: Func 1804 - Step 8 - Generate Putaway Task for Pallet       */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2013-10-07   Chee       1.0  Created                                 */  
/* 2014-05-22   Ung        1.1  SOS309830 UCC prefix. Build pallet rule */
/************************************************************************/  
CREATE PROCEDURE [RDT].[rdtVFMvToUccExtUpd]  
    @nMobile         INT   
   ,@nFunc           INT   
   ,@cLangCode       NVARCHAR( 3)   
   ,@nStep           INT   
   ,@cStorerKey      NVARCHAR( 15)  
   ,@cFacility       NVARCHAR(  5)  
   ,@cFromLOC        NVARCHAR( 10)  
   ,@cFromID         NVARCHAR( 18)  
   ,@cSKU            NVARCHAR( 20)  
   ,@nQTY            INT  
   ,@cUCC            NVARCHAR( 20)  
   ,@cToID           NVARCHAR( 18)  
   ,@cToLOC          NVARCHAR( 10)  
   ,@nErrNo          INT           OUTPUT   
   ,@cErrMsg         NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   -- Move To UCC 
   IF @nFunc = 1804  
   BEGIN  
      IF @nStep = 7 -- UCC
      BEGIN  
         IF LEFT( @cUCC, 2) <> 'VF' OR LEN( @cUCC) <> 10
         BEGIN
            SET @nErrNo = 88651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid format
            GOTO Quit
         END
         
         -- Build pallet rule (same SKU must same UCC.QTY)
         IF EXISTS( SELECT TOP 1 1 
            FROM UCC WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND Status = '1'
               AND LOC = @cToLOC
               AND ID = @cToID
               AND SKU = @cSKU
               AND QTY <> @nQTY)
         BEGIN
            SET @nErrNo = 88652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UCC Diff QTY
            GOTO Quit
         END
      END

      IF @nStep = 8 -- Close Pallet screen 
      BEGIN  
         -- Generate Putaway Task
         -- Handling transaction
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdtVFMvToUccExtUpd -- For rollback or commit only our own transaction

         -- Generate putaway task
         IF NOT EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND TaskType = 'PAF' AND FromID = @cToID)
         BEGIN
            DECLARE @cTaskDetailKey NVARCHAR( 10)
            DECLARE @cPickMethod NVARCHAR(10)

            -- Get pallet info
            SELECT @cPickMethod = CASE WHEN COUNT(DISTINCT UCC.SKU) = 1 THEN 'FP' ELSE 'PP' END
            FROM dbo.UCC WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
              AND Loc = @cToLOC
              AND ID = @cToID
              AND Status = '1'

            -- Get new TaskDetailKey
            DECLARE @nSuccess INT
            SET @nSuccess = 1
            EXECUTE dbo.nspg_getkey
               'TASKDETAILKEY'
               , 10
               , @cTaskDetailKey OUTPUT
               , @nSuccess       OUTPUT
               , @nErrNo         OUTPUT
               , @cErrMsg        OUTPUT
            IF @nSuccess <> 1
            BEGIN
               SET @nErrNo = 88653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GET KEY FAIL
               GOTO RollBackTran
            END

            -- Insert putaway task
            INSERT INTO TaskDetail (
               TaskDetailKey, Storerkey, TaskType, Fromloc, FromID, PickMethod, Status, Priority, SourcePriority, SourceType, SourceKey, TrafficCop)
            VALUES (
               @cTaskDetailKey, @cStorerKey, 'PAF', @cToLOC, @cToID, @cPickMethod, '0', '5', '5', 'rdtVFMvToUccExtUpd', '', NULL)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 88654
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
               GOTO RollBackTran
            END
         END

         COMMIT TRAN rdtVFMvToUccExtUpd -- Only commit change made here
      END -- IF @nStep = 8
      GOTO Quit
    
   END  -- IF @nFunc = 1804
END  
  
RollBackTran:
   ROLLBACK TRAN rdtVFMvToUccExtUpd -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO