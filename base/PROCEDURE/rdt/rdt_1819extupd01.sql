SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtUpd01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate location type                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-03-23   Ung       1.0   SOS336606 Created                       */
/* 2015-11-09   James     1.1   Add rollback tran (james01)             */
/* 2015-12-09   Ung       1.2   SOS355261 Add ASTMV task                */
/* 2016-03-30   James     1.3   SOS365488 Unhold VAP pallet (james02)   */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtUpd01]
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

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1819ExtUpd01 -- For rollback or commit only our own transaction

   -- Putaway By ID
   IF @nFunc = 1819
   BEGIN
      IF @nStep = 2 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            /*
            -- Delete DropID
            IF EXISTS( SELECT 1 FROM DropID WITH (NOLOCK) WHERE DropID = @cFromID)
            BEGIN
               DELETE DropID WHERE DropID = @cFromID
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 52851
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL DID Fail
                  GOTO RollBackTran
               END
            END
            */
            
            -- Update ID status
            IF EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE ID = @cFromID AND Status < '9')
            BEGIN
               UPDATE ID SET
                  PalletFlag = 'PackNHold', 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE ID = @cFromID
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 52852
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD ID Fail
                  GOTO RollBackTran
               END
            END

            DECLARE @cTaskDetailKey NVARCHAR(10)
            DECLARE @cFacility NVARCHAR(5)
            SET @cTaskDetailKey = ''
            SET @cFacility = ''

            -- Get ASTMV task
            SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
            SELECT @cTaskDetailKey = TaskDetailKey
               FROM TaskDetail TD WITH (NOLOCK) 
                  JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)
               WHERE LOC.Facility = @cFacility
                  AND TD.TaskType = 'ASTMV'
                  AND TD.Status = '0'
                  AND TD.FromID = @cFromID
            
            -- Update ASTMV task
            IF @cTaskDetailKey <> ''
            BEGIN
               UPDATE TaskDetail SET
                  Status = '9', 
                  ToLOC = @cToLOC, 
                  UserKey = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 52853
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
                  GOTO RollBackTran
               END
            END

            -- (james02)
            -- Unhold VAP pallet
            IF EXISTS ( SELECT 1 FROM dbo.InventoryHold WITH (NOLOCK) 
                        WHERE ID = @cFromID
                        AND   [Status] = 'VASIDHOLD'
                        AND   Hold = '1')            
            BEGIN
               UPDATE dbo.InventoryHold WITH (ROWLOCK) SET 
                  Hold = '0'
               WHERE ID = @cFromID
               AND   [Status] = 'VASIDHOLD'
               AND   Hold = '1'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 52854
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
                  GOTO RollBackTran
               END

               UPDATE dbo.ID WITH (ROWLOCK) SET 
                  [Status] = 'OK'
               WHERE ID = @cFromID

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 52855
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
                  GOTO RollBackTran
               END
            END

            -- Induct location
            IF EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC AND LocationCategory = 'ASRSINST')
            BEGIN
               SET @nErrNo = 0
               -- Send WCS
               EXEC rdt.rdt_WCS_SG_BULIM @nMobile, @nFunc, @cLangCode, @nStep, '', @nErrNo OUTPUT, @cErrMsg OUTPUT, @cFromID, @cToLOC
               -- (james01)
               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollBackTran
               END
            END
         END
      END
   END
   
   COMMIT TRAN rdt_1819ExtUpd01 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtUpd01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO