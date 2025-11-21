SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLCart_Confirm_Case02                                */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose:                                                                   */
/* Matrix shows either case or piece, depends on the barcode scanned          */
/* So confirm need to follow suit by either case or piece                     */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 25-05-2015 1.0  Ung         WMS-19592 base on rdt_PTLCart_Confirm_Case     */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Confirm_Case02] (
    @nMobile    INT
   ,@nFunc      INT
   ,@cLangCode  NVARCHAR( 3)
   ,@nStep      INT
   ,@nInputKey  INT
   ,@cFacility  NVARCHAR(5)
   ,@cStorerKey NVARCHAR( 15)
   ,@cType      NVARCHAR( 10) -- LOC = confirm LOC, CLOSETOTE/SHORTTOTE = confirm tote
   ,@cDPLKey    NVARCHAR( 10)
   ,@cCartID    NVARCHAR( 10)
   ,@cToteID    NVARCHAR( 20) -- Required for confirm tote
   ,@cLOC       NVARCHAR( 10)
   ,@cSKU       NVARCHAR( 20)
   ,@nQTY       INT
   ,@cNewToteID NVARCHAR( 20) -- For close tote with balance
   ,@nErrNo     INT           OUTPUT
   ,@cErrMsg    NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
   DECLARE @nRowRef        INT
   DECLARE @nPTLKey        INT
   DECLARE @nQTY_PTL       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
   DECLARE @cCaseID        NVARCHAR( 20)

   DECLARE @cPosition      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)

   DECLARE @curPTL CURSOR
   DECLARE @curPD  CURSOR

   -- Get storer config
   DECLARE @cUpdatePickDetail NVARCHAR(1)
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)

   SET @nQTY_Bal = @nQTY

   -- Check case or piece barcode
   DECLARE @cBarcode NVARCHAR( 30)
   DECLARE @nCaseCNT INT = 1
   SELECT @cBarcode = I_Field03 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
   IF EXISTS( SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC = @cBarcode)
   BEGIN
      SELECT @nCaseCNT = Pack.CaseCNT
      FROM dbo.SKU WITH (NOLOCK)
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU
         
      IF ISNULL( @nCaseCNT, 0) = 0
         SET @nCaseCNT = 1
         
      SET @nQTY = @nQTY * @nCaseCNT
      SET @nQTY_Bal = @nQTY
   END

   /***********************************************************************************************

                                                CONFIRM LOC

   ***********************************************************************************************/
   IF @cType = 'LOC'
   BEGIN
      -- Confirm entire LOC
      SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PTLKey, DevicePosition, ExpectedQTY, CaseID
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceProfileLogKey = @cDPLKey
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND Status <> '9'
      OPEN @curPTL
      FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY, @cCaseID
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Transaction at order level
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_PTLCart_Confirm_Case02 -- For rollback or commit only our own transaction

         -- Confirm PTLTran
         UPDATE PTL.PTLTran SET
            Status = '9',
            QTY = ExpectedQTY,
            DropID = @cCaseID,
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE(),
            TrafficCop = NULL
         WHERE PTLKey = @nPTLKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 189301
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO RollBackTran
         END



         -- Update PickDetail
         IF @cUpdatePickDetail = '1'
         BEGIN
            -- Get PickDetail tally PTLTran
            SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
            FROM Orders O WITH (NOLOCK)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            WHERE PD.CaseID = @cCaseID
               AND PD.LOC = @cLOC
               AND PD.SKU = @cSKU
               AND PD.Status < '4'
               AND PD.QTY > 0
               AND O.Status <> 'CANC'
               AND O.SOStatus <> 'CANC'
            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
               SET @nErrNo = 189302
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END

            -- Loop PickDetail
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE PD.CaseID = @cCaseID
                  AND PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND PD.Status < '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC'
                  AND O.SOStatus <> 'CANC'
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Confirm PickDetail
               UPDATE PickDetail SET
                  Status = '5',
                  DropID = @cCaseID,
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 189303
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
            END
         END

         -- EventLog -- (ChewKP01)
         EXEC RDT.rdt_STD_EventLog
           @cActionType = '3', -- Sign-in
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerkey,
           @cDeviceID   = @cCartID,
           @cLocation   = @cLoc,
           @cCaseID     = @cCaseID,
           @cSKU        = @cSKU,
           @nQty        = @nExpectedQTY

         -- Commit order level
         COMMIT TRAN rdt_PTLCart_Confirm_Case02
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY, @cCaseID
      END
   END


   /***********************************************************************************************

                                                CONFIRM TOTE

   ***********************************************************************************************/
   -- Confirm tote
   IF @cType <> 'LOC'
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_PTLCart_Confirm_Case02 -- For rollback or commit only our own transaction

      -- Close with QTY or short
      IF (@cType = 'CLOSETOTE' AND @nQTY > 0) OR
         (@cType = 'SHORTTOTE')
      BEGIN
         -- Get tote info
         SELECT
            @cPosition = Position,
            @cCaseID = CaseID
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE CartID = @cCartID
            AND ToteID = @cToteID

         SET @nExpectedQTY = NULL

         -- PTLTran
         SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PTLKey, ExpectedQTY
            FROM PTL.PTLTran WITH (NOLOCK)
            WHERE DeviceProfileLogKey = @cDPLKey
               AND LOC = @cLOC
               AND SKU = @cSKU
               AND DevicePosition = @cPosition
               AND Status <> '9'
         OPEN @curPTL
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @nExpectedQTY IS NULL
               SET @nExpectedQTY = @nQTY_PTL

            -- Exact match
            IF @nQTY_PTL = @nQTY_Bal
            BEGIN
               -- Confirm PTLTran
               UPDATE PTL.PTLTran WITH (ROWLOCK) SET
                  Status = '9',
                  QTY = ExpectedQTY,
                  DropID = @cCaseID,
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE(),
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 189304
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END

               SET @nQTY_Bal = 0 -- Reduce balance
            END

            -- PTLTran have less
      		ELSE IF @nQTY_PTL < @nQTY_Bal
            BEGIN
               -- Confirm PickDetail
               UPDATE PTL.PTLTran WITH (ROWLOCK) SET
                  Status = '9',
                  QTY = ExpectedQTY,
                  DropID = @cCaseID,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 189305
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                  GOTO RollBackTran
               END

               SET @nQTY_Bal = @nQTY_Bal - @nQTY_PTL -- Reduce balance
            END

            -- PTLTran have more
      		ELSE IF @nQTY_PTL > @nQTY_Bal
            BEGIN
               -- Short pick
               IF @cType = 'SHORTTOTE' AND @nQTY_Bal = 0 -- Don't need to split
               BEGIN
                  -- Confirm PTLTran
                  UPDATE PTL.PTLTran WITH (ROWLOCK) SET
                     Status = '9',
                     QTY = 0,
                     DropID = @cCaseID,
                     TrafficCop = NULL,
                     EditDate = GETDATE(),
                     EditWho  = SUSER_SNAME()
                  WHERE PTLKey = @nPTLKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 189306
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                     GOTO RollBackTran
                  END
               END
               ELSE
               BEGIN -- Have balance, need to split
                  -- Create new a PTLTran to hold the balance
                  INSERT INTO PTL.PTLTran (
                     ExpectedQty, QTY, TrafficCop,
                     IPAddress, DeviceID, DevicePosition, Status, PTLType, DropID, CaseID, Storerkey, SKU, LOC, LOT, Remarks,
                     DeviceProfileLogKey, ArchiveCop, SourceKey, ConsigneeKey, LightUp, LightMode, LightSequence, UOM, RefPTLKey)
                  SELECT
                     @nQTY_PTL - @nQTY_Bal, @nQTY_PTL - @nQTY_Bal, NULL,
                     IPAddress, DeviceID, DevicePosition, Status, PTLType, '', CaseID, Storerkey, SKU, LOC, LOT, Remarks,
                     DeviceProfileLogKey, ArchiveCop, SourceKey, ConsigneeKey, LightUp, LightMode, LightSequence, UOM, RefPTLKey
                  FROM PTL.PTLTran WITH (NOLOCK)
         			WHERE PTLKey = @nPTLKey
                  IF @@ERROR <> 0
                  BEGIN
         				SET @nErrNo = 189307
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PTL Fail
                     GOTO RollBackTran
                  END

                  -- Confirm orginal PTLTran with exact QTY
                  UPDATE PTL.PTLTran WITH (ROWLOCK) SET
                     Status = '9',
                     ExpectedQty = @nQTY_Bal,
                     QTY = @nQTY_Bal,
                     DropID = @cCaseID,
                     EditDate = GETDATE(),
                     EditWho  = SUSER_SNAME(),
                     Trafficcop = NULL
                  WHERE PTLKey = @nPTLKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 189308
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                     GOTO RollBackTran
                  END

                  SET @nQTY_Bal = 0 -- Reduce balance
               END
            END

            -- EventLog -- (ChewKP01)
            EXEC RDT.rdt_STD_EventLog
              @cActionType = '3', -- Sign-in
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerkey,
              @cDeviceID   = @cCartID,
              @cLocation   = @cLoc,
              @cCaseID     = @cCaseID,
              @cSKU        = @cSKU,
              @nQty        = @nQTY_PTL

            -- Exit condition
            IF @cType = 'CLOSETOTE' AND @nQTY_Bal = 0
               BREAK

            FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL
         END

         -- PickDetail
         IF @cUpdatePickDetail = '1'
         BEGIN
            -- Get PickDetail tally PTLTran
            SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
            FROM Orders O WITH (NOLOCK)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            WHERE PD.CaseID = @cCaseID
               AND PD.LOC = @cLOC
               AND PD.SKU = @cSKU
               AND PD.Status < '4'
               AND PD.QTY > 0
               AND O.Status <> 'CANC'
               AND O.SOStatus <> 'CANC'

            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
               SET @nErrNo = 189309
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END

            -- For calculation
            SET @nQTY_Bal = @nQTY

            -- Get PickDetail candidate
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey, QTY
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE PD.CaseID = @cCaseID
                  AND PD.LOC = @cLOC
                  AND PD.SKU = @cSKU
                  AND PD.Status < '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC'
                  AND O.SOStatus <> 'CANC'
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Exact match
               IF @nQTY_PD = @nQTY_Bal
               BEGIN
                  -- Confirm PickDetail
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     Status = '5',
                     DropID = @cCaseID,
                     EditDate = GETDATE(),
                     EditWho  = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 189310
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END

                  SET @nQTY_Bal = 0 -- Reduce balance
               END

               -- PickDetail have less
         		ELSE IF @nQTY_PD < @nQTY_Bal
               BEGIN
                  -- Confirm PickDetail
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     Status = '5',
                     DropID = @cCaseID,
                     EditDate = GETDATE(),
                     EditWho  = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 189311
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END

                  SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
               END

               -- PickDetail have more
         		ELSE IF @nQTY_PD > @nQTY_Bal
               BEGIN
                  -- Short pick
                  IF @cType = 'SHORTTOTE' AND @nQTY_Bal = 0 -- Don't need to split
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                        Status = '4',
                        DropID = @cCaseID, 
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME(),
                        TrafficCop = NULL
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 189312
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                  END
                  ELSE
                  BEGIN -- Have balance, need to split

                     -- Get new PickDetailkey
                     DECLARE @cNewPickDetailKey NVARCHAR( 10)
                     EXECUTE dbo.nspg_GetKey
                        'PICKDETAILKEY',
                        10 ,
                        @cNewPickDetailKey OUTPUT,
                        @bSuccess          OUTPUT,
                        @nErrNo            OUTPUT,
                        @cErrMsg           OUTPUT
                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 189313
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
                        GOTO RollBackTran
                     END

                     -- Create new a PickDetail to hold the balance
                     INSERT INTO dbo.PickDetail (
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                        UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                        ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                        PickDetailKey,
                        QTY,
                        TrafficCop,
                        OptimizeCop)
                     SELECT
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                        UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                        CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                        @cNewPickDetailKey,
                        @nQTY_PD - @nQTY_Bal, -- QTY
                        NULL, -- TrafficCop
                        '1'   -- OptimizeCop
                     FROM dbo.PickDetail WITH (NOLOCK)
            			WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
            				SET @nErrNo = 189314
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
                        GOTO RollBackTran
                     END

                     -- Split RefKeyLookup
                     IF EXISTS( SELECT 1 FROM dbo.RefKeyLookup (NOLOCK) WHERE PickDetailkey = @cPickDetailKey)
                     BEGIN
                        -- Insert RefKeyLookup
                        INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
                        SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                        FROM dbo.RefKeyLookup (NOLOCK) 
                        WHERE PickDetailkey = @cPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 189315
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                           GOTO RollBackTran
                        END
                     END


                     -- Change orginal PickDetail with exact QTY (with TrafficCop)
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                        QTY = @nQTY_Bal,
                        DropID = @cCaseID, 
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME(),
                        Trafficcop = NULL
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 189316
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END

                     -- Confirm orginal PickDetail with exact QTY
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                        Status = '5',
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME()
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 189317
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END

                     -- Short pick
                     IF @cType = 'SHORTTOTE'
                     BEGIN
                        -- Confirm PickDetail
                        UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                           Status = '4',
                           DropID = @cCaseID, 
                           EditDate = GETDATE(),
                           EditWho  = SUSER_SNAME(),
                           TrafficCop = NULL
                        WHERE PickDetailKey = @cNewPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 189318
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                           GOTO RollBackTran
                        END
                     END

                     SET @nQTY_Bal = 0 -- Reduce balance
                  END
               END

               -- Exit condition
               IF @cType = 'CLOSETOTE' AND @nQTY_Bal = 0
                  BREAK

               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
            END
         END
      END

      -- Update new tote
      IF @cType = 'CLOSETOTE' AND @cNewToteID <> ''
      BEGIN
         -- Get RowRef
         SELECT @nRowRef = RowRef FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID = @cToteID

         -- Change Tote on rdtPTLCartLog
         UPDATE rdt.rdtPTLCartLog SET
            ToteID = @cNewToteID
         WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 189319
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
            GOTO RollBackTran
         END
      END

      -- Auto short all subsequence tote
      IF @cType = 'SHORTTOTE'
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'AutoShortRemainTote', @cStorerKey) = '1'
         BEGIN
            SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PTLKey, DevicePosition, ExpectedQTY, CaseID
               FROM PTL.PTLTran WITH (NOLOCK)
               WHERE DeviceProfileLogKey = @cDPLKey
                  AND LOC = @cLOC
                  AND SKU = @cSKU
                  AND Status <> '9'

            OPEN @curPTL
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY, @cCaseID
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Confirm PTLTran
               UPDATE PTL.PTLTran SET
                  Status = '9',
                  QTY = 0,
                  DropID = @cCaseID, 
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE(),
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 189320
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END

               -- Update PickDetail
               IF @cUpdatePickDetail = '1'
               BEGIN
                  -- Get PickDetail tally PTLTran
                  SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
                  FROM Orders O WITH (NOLOCK)
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE PD.CaseID = @cCaseID
                     AND PD.LOC = @cLOC
                     AND PD.SKU = @cSKU
                     AND PD.Status < '4'
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC'
                     AND O.SOStatus <> 'CANC'
                  IF @nQTY_PD <> @nExpectedQTY
                  BEGIN
                     SET @nErrNo = 189321
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                     GOTO RollBackTran
                  END

                  -- Loop PickDetail
                  SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PickDetailKey
                     FROM Orders O WITH (NOLOCK)
                        JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                     WHERE PD.CaseID = @cCaseID
                        AND PD.LOC = @cLOC
                        AND PD.SKU = @cSKU
                        AND PD.Status < '4'
                        AND PD.QTY > 0
                        AND O.Status <> 'CANC'
                        AND O.SOStatus <> 'CANC'
                  OPEN @curPD
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE PickDetail SET
                        Status = '4',
                        DropID = @cCaseID, 
                        EditWho = SUSER_SNAME(),
                        EditDate = GETDATE()
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 189322
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  END
               END

               FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY, @cCaseID
            END
         END
      END

      COMMIT TRAN rdt_PTLCart_Confirm_Case02
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Confirm_Case02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO