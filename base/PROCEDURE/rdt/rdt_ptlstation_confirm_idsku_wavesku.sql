SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLStation_Confirm_IDSKU_WaveSKU                      */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date       Rev Author      Purposes                                        */
/* 15-06-2023 1.0 Ung         WMS-22703 Created                               */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLStation_Confirm_IDSKU_WaveSKU] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cType        NVARCHAR( 15) -- ID=confirm ID, CLOSECARTON/SHORTCARTON = confirm carton
   ,@cStation1    NVARCHAR( 10)
   ,@cStation2    NVARCHAR( 10)
   ,@cStation3    NVARCHAR( 10)
   ,@cStation4    NVARCHAR( 10)
   ,@cStation5    NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1)
   ,@cScanID      NVARCHAR( 20)
   ,@cSKU         NVARCHAR( 20)
   ,@nQTY         INT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
   ,@cCartonID    NVARCHAR( 20) = ''
   ,@nCartonQTY   INT           = 0
   ,@cNewCartonID NVARCHAR( 20) = ''   -- For close carton with balance
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT

   DECLARE @nPTLKey        INT
   DECLARE @nGroupKey      INT
   DECLARE @nQTY_PD        INT
   DECLARE @nExpectedQTY   INT

   DECLARE @cIPAddress     NVARCHAR( 40)
   DECLARE @cPosition      NVARCHAR( 10)
   
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cPDLOC         NVARCHAR( 10)
   DECLARE @cPDID          NVARCHAR( 18)
   DECLARE @nPDQTY         INT
   DECLARE @cPDLOT         NVARCHAR( 10)

   DECLARE @cAreaKey          NVARCHAR( 10)
   DECLARE @cPutawayZone      NVARCHAR( 10)
   DECLARE @cTaskDetailKey    NVARCHAR( 10)
   DECLARE @cPTLLOC           NVARCHAR( 10)
   DECLARE @cPackStationLOC   NVARCHAR( 10)
   DECLARE @cGroupKey         NVARCHAR( 10)

   DECLARE @curPTL CURSOR
   DECLARE @curPD CURSOR
   DECLARE @curTD CURSOR

   -- Get storer config
   DECLARE @cUpdatePickDetail NVARCHAR(1)
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PTLStation_Confirm -- For rollback or commit only our own transaction

   /***********************************************************************************************

                                                CONFIRM ID

   ***********************************************************************************************/
   IF @cType = 'ID'
   BEGIN
      -- Confirm entire ID, SKU
      SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PTLKey, IPAddress, DevicePosition, ExpectedQTY, GroupKey
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND DropID = @cScanID
            AND SKU = @cSKU
            AND Status <> '9'
      OPEN @curPTL
      FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nExpectedQTY, @nGroupKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Confirm PTLTran
         UPDATE PTL.PTLTran SET
            Status = '9',
            QTY = ExpectedQTY,
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE(),
            TrafficCop = NULL
         WHERE PTLKey = @nPTLKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 202751
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO RollBackTran
         END

         -- Update PickDetail
         IF @cUpdatePickDetail = '1'
         BEGIN
            -- Get position info
            SELECT
               @cWaveKey = WaveKey,
               @cPTLLOC = LOC
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND IPAddress = @cIPAddress
               AND Position = @cPosition
            
            -- Get PickDetail tally PTLTran
            SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
            FROM Orders O WITH (NOLOCK)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            WHERE PD.WaveKey = @cWaveKey
               AND PD.ID = @cScanID
               AND PD.SKU = @cSKU
               AND PD.Status <= '5'
               AND PD.Status <> '4'
               AND PD.CaseID = ''
               AND PD.QTY > 0
               AND O.Status <> 'CANC'
               AND O.SOStatus <> 'CANC'

            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
               SET @nErrNo = 202752
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END

            -- Get LOC info
            SELECT TOP 1
               @cFacility = LOC.Facility, 
               @cAreaKey = A.AreaKey, 
               @cPackStationLOC = PZ.OutLOC
            FROM dbo.LOC WITH (NOLOCK) 
               JOIN dbo.PutawayZone PZ WITH (NOLOCK) ON (LOC.PutawayZone = PZ.PutawayZone)
               JOIN dbo.AreaDetail A WITH (NOLOCK) ON (PZ.PutawayZone = A.PutawayZone)
            WHERE LOC.LOC = @cPTLLOC

            -- Loop PickDetail
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.OrderKey, PD.PickDetailKey, PD.QTY, PD.LOC, PD.ID, PD.LOT
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE PD.WaveKey = @cWaveKey
                  AND PD.ID = @cScanID
                  AND PD.SKU = @cSKU
                  AND PD.Status <= '5'
                  AND PD.Status <> '4'
                  AND PD.CaseID = ''
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC'
                  AND O.SOStatus <> 'CANC'
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cOrderKey, @cPickDetailKey, @nPDQTY, @cPDLOC, @cPDID, @cPDLOT
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get task for this Order and SKU
               SET @cTaskDetailKey = ''
               SELECT @cTaskDetailKey = TaskDetailKey
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE TaskType = 'FCP'
                  AND FromLOC = @cPTLLOC
                  AND StorerKey = @cStorerKey
                  AND SKU = @cSKU
                  AND OrderKey = @cOrderKey
                  AND Status = 'H' 
               
               -- Need to generate FCP task
               IF @cTaskDetailKey = ''
               BEGIN
                  EXECUTE dbo.nspg_getkey
            	      'TaskDetailKey'
            	      , 10
            	      , @cTaskDetailKey OUTPUT
            	      , @bSuccess       OUTPUT
            	      , @nErrNo         OUTPUT
            	      , @cErrMsg        OUTPUT
                  IF @bSuccess <> 1
                  BEGIN
                     SET @nErrNo = 202753
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                     GOTO RollBackTran
                  END

                  INSERT INTO dbo.TaskDetail (
                     TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, SKU, Qty, AreaKey, SystemQty,
                     PickMethod, StorerKey, OrderKey, WaveKey, SourceType, GroupKey, Priority, SourcePriority, TrafficCop)
                  VALUES (
                     @cTaskDetailKey, 'FCP', 'H', '', @cPTLLOC, '', @cPackStationLOC, '', @cSKU, @nPDQTY, ISNULL(@cAreaKey,''), @nPDQTY,
                     'PP', @cStorerKey, @cOrderKey, @cWaveKey, 'Confirm_IDSKU_WaveSKU', @cOrderKey, '9', '9', NULL)
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 202754
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSTaskDtlFail
                     GOTO RollBackTran
                  END
               END
               
               -- Top up existing task
               ELSE
               BEGIN
                  UPDATE dbo.TaskDetail SET
                     QTY = QTY + @nPDQTY, 
                     EditWho = SUSER_SNAME(), 
                     EditDate = GETDATE(), 
                     TrafficCop = NULL
                  WHERE TaskDetailKey = @cTaskDetailKey 
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 202755
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
                     GOTO RollBackTran
                  END
               END
               
               -- Confirm PickDetail
               UPDATE PickDetail SET
                  --Status = '5',
                  CaseID = 'SORTED',
                  DropID = @cScanID, 
                  TaskDetailKey = @cTaskDetailKey, 
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 202756
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
               
               -- Release pick task for the order (if all its SKU had replenished and sorted)
               IF NOT EXISTS( SELECT TOP 1 1 
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                     AND UOM IN ('6', '7') -- Conso carton and loose QTY
                     AND QTY > 0
                     AND Status <> '4'
                     AND CaseID <> 'SORTED') -- Not yet sort
               BEGIN
                  SET @curTD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT TaskDetailKey 
                     FROM dbo.TaskDetail WITH (NOLOCK)
                     WHERE Tasktype = 'FCP'
                        AND StorerKey = @cStorerKey
                        AND OrderKey = @cOrderKey
                        AND Status = 'H' -- Only sort area FCP can be hold. Full carton direct to pack station does not have hold
                  OPEN @curTD
                  FETCH NEXT FROM @curTD INTO @cTaskDetailKey
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE dbo.TaskDetail SET
                        Status = '0',
                        EditWho = SUSER_SNAME(),
                        EditDate = GETDATE(),
                        TrafficCop = NULL
                     WHERE TaskDetailKey = @cTaskDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 202757
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
                        GOTO RollBackTran
                     END

                     FETCH NEXT FROM @curTD INTO @cTaskDetailKey
                  END
               END
               
               FETCH NEXT FROM @curPD INTO @cOrderKey, @cPickDetailKey, @nPDQTY, @cPDLOC, @cPDID, @cPDLOT
            END
               
            -- Move
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT,
               @cSourceType = 'rdt_PTLStation_Confirm_IDSKU_WaveSKU',
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cPDLOC,
               @cToLOC      = @cPTLLOC, -- Final LOC
               @cFromID     = @cPDID,
               @cToID       = '',
               @cSKU        = @cSKU,
               @nQty        = @nQTY_PD,
               @nQTYAlloc   = @nQTY_PD,
               --@cFromLOT    = @cPDLOT,
               @nFunc       = 805
            IF @nErrNo <> 0
               GOTO RollBackTran
         END

         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cIPAddress, @cPosition, @nExpectedQTY, @nGroupKey
      END

      -- Auto unassign
      DELETE rdt.rdtPTLStationLog WHERE RowRef = @nGroupKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 202758
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL Log Fail
         GOTO RollBackTran
      END

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
        @cActionType = '3',
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @cID         = @cScanID,
        @cSKU        = @cSKU,
        @nQty        = @nQTY
   END


   /***********************************************************************************************

                                              CONFIRM CARTON

   ***********************************************************************************************/
   -- Confirm carton
   IF @cType <> 'ID'
   BEGIN
      IF @cType = 'CLOSECARTON'
      BEGIN
         SET @nErrNo = 202759
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotAllowCLOSE
         GOTO Quit
      END

      IF @cType = 'SHORTCARTON'
      BEGIN
         SET @nErrNo = 202760
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotAllowSHORT
         GOTO Quit
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_PTLStation_Confirm
END



GO