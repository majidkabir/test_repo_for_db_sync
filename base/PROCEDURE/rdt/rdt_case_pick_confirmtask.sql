SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Case_Pick_ConfirmTask                           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Comfirm Pick                                                */
/*                                                                      */
/* Called from: rdtfnc_Case_Pick                                        */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 13-Apr-2009 1.0  James       Created                                 */
/* 23-Jun-2008 1.0  Vicky       UOM should consider the PD.UOM          */
/*                              either PackUOM4 or PackUOM1 (Vicky01)   */
/* 30-Jul-2009 1.1  Vicky       Add in EventLog (Vicky06)               */
/* 26-Oct-2009 1.2  James       SOS151572 - Bug fix (james01)           */
/* 01-Apr-2015 1.3  James       SOS337577 - Add pickslipno into event   */
/*                              log (james02)                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_Case_Pick_ConfirmTask] (
   @cStorerKey   NVARCHAR( 15),
   @cUserName    NVARCHAR( 15),
   @cFacility    NVARCHAR( 5),
   @cPutAwayZone NVARCHAR( 10),
   @cSKU         NVARCHAR( 20),
   @cLoadKey     NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cLOT         NVARCHAR( 10),
   @cDropID      NVARCHAR( 18),
   @cStatus      NVARCHAR( 1),
   @cPickSlipNo  NVARCHAR( 10),
   @cLangCode    NVARCHAR( 3),
   @cPickUOM     NVARCHAR( 10), -- (Vicky01)
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT,  -- screen limitation, 20 char max
   @nMobile      INT, -- (Vicky06)
   @nFunc        INT  -- (Vicky06)

)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success INT,
   @n_err             INT,
   @c_errmsg          NVARCHAR( 250),
   @cPickDetailKey    NVARCHAR( 10),
   @nDropIDCnt        INT,
   @nPickQty          INT,
   @nQTY_PD           INT,
   @nRowRef           INT,
   @nTranCount        INT,
   @nRPLCount         INT,
   @cOrderKey         NVARCHAR( 10),
   @cOrderLineNumber  NVARCHAR( 5),
   @nCartonNo         INT

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN Case_Pick_ConfirmTask

   IF ISNULL(@cPickSlipNo, '') = ''
   BEGIN
      SELECT @cPickSlipNo = PickheaderKey FROM dbo.PickHeader (NOLOCK) WHERE ExternOrderKey = @cLoadKey
   END

   IF ISNULL(@cPickSlipNo, '') = ''
   BEGIN
      SET @nErrNo = 66453
      SET @cErrMsg = rdt.rdtgetmessage( 66453, @cLangCode, 'DSP') --'PKSlip blank'
      GOTO RollBackTran
   END

   -- Get RDT.RDTPickLock candidate to offset
   DECLARE curRPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRef, DropID, PickQty, 
      OrderKey, OrderLineNumber, ID --(james01)
   FROM RDT.RDTPickLock WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND LoadKey = @cLoadKey
      AND PutAwayZone = @cPutAwayZone
      AND LOC = @cLOC
      AND SKU = @cSKU
      AND Status = '1'
      AND AddWho = @cUserName
      AND UOM = @cPickUOM -- (Vicky01)
   OPEN curRPL
   FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @cOrderKey, @cOrderLineNumber, @nCartonNo
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Get PickDetail candidate to offset based on RPL's candidate
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickDetailKey, PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.Orderkey)
      WHERE PD.StorerKey  = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.LOT = @cLOT
         AND PD.LOC = @cLOC
         AND PD.Status < '4'
         AND O.LoadKey = @cLoadKey
         AND PD.UOM = @cPickUOM -- (Vicky01)
         AND PD.OrderKey = @cOrderKey  --(james01)
         AND PD.OrderLineNumber = @cOrderLineNumber   --(james01)
      ORDER BY PD.PickDetailKey
      OPEN curPD
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
      WHILE @@FETCH_STATUS <> -1
      BEGIN
--         UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
--            PickDetailKey = @cPickDetailKey
--         WHERE rowref = @nRowRef

--         IF @@ERROR <> 0
--         BEGIN
--            SET @nErrNo = 66026
--            SET @cErrMsg = rdt.rdtgetmessage( 66026, @cLangCode, 'DSP') --'UPDPKLockFail'
--            GOTO RollBackTran
--         END

         IF @nPickQty = 0
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               Status = @cStatus,
               CaseID = CASE WHEN ISNULL(@nCartonNo, 0) = 0 THEN CaseID ELSE @nCartonNo END, --cater for short pick
               Pickslipno = @cPickSlipNo
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66026
               SET @cErrMsg = rdt.rdtgetmessage( 66026, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- Exclude short picked (status = '4')
            IF @cStatus = '5'
            BEGIN          
               EXEC RDT.rdt_Case_Pick_InsertPack
                  @cStorerKey,
                  @cPickDetailKey,
                  @cSKU,
                  @cPickSlipNo,
                  @nPickQty,
                  @nCartonNo,
                  @cLangCode,
                  @nErrNo          OUTPUT,
                  @cErrMsg         OUTPUT  -- screen limitation, 20 char max

               IF @nErrNo <> 0 
               BEGIN
                  GOTO RollBackTran
               END   
            END

           -- (Vicky06) EventLog - QTY
           EXEC RDT.rdt_STD_EventLog
              @cActionType   = '3', -- Picking
              @cUserID       = @cUserName,
              @nMobileNo     = @nMobile,
              @nFunctionID   = @nFunc,
              @cFacility     = @cFacility,
              @cStorerKey    = @cStorerkey,
              @cLocation     = @cLOC,
              @cID           = @cDropID,
              @cSKU          = @cSKU,
              @cUOM          = @cPickUOM,
              @nQTY          = @nPickQty,
              @cRefNo1       = @cPutAwayZone,
              @cRefNo2       = @cLoadKey,
              @cPickSlipNo   = @cPickSlipNo     -- (james02)

            BREAK -- Exit
         END

         -- Exact match
         IF @nQTY_PD = @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               Status = @cStatus,
               CaseID = CASE WHEN ISNULL(@nCartonNo, 0) = 0 THEN CaseID ELSE @nCartonNo END,
               Pickslipno = @cPickSlipNo
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66027
               SET @cErrMsg = rdt.rdtgetmessage( 66027, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- Exclude short picked (status = '4')
            IF @cStatus = '5'
            BEGIN          
               EXEC RDT.rdt_Case_Pick_InsertPack
                  @cStorerKey,
                  @cPickDetailKey,
                  @cSKU,
                  @cPickSlipNo,
                  @nPickQty,
                  @nCartonNo,
                  @cLangCode,
                  @nErrNo          OUTPUT,
                  @cErrMsg         OUTPUT  -- screen limitation, 20 char max

               IF @nErrNo <> 0 
               BEGIN
                  GOTO RollBackTran
               END   
            END

           -- (Vicky06) EventLog - QTY
           EXEC RDT.rdt_STD_EventLog
              @cActionType   = '3', -- Picking
              @cUserID       = @cUserName,
              @nMobileNo     = @nMobile,
              @nFunctionID   = @nFunc,
              @cFacility     = @cFacility,
              @cStorerKey    = @cStorerkey,
              @cLocation     = @cLOC,
              @cID           = @cDropID,
              @cSKU          = @cSKU,
              @cUOM          = @cPickUOM,
              @nQTY          = @nPickQty,
              @cRefNo1       = @cPutAwayZone,
              @cRefNo2       = @cLoadKey, 
              @cPickSlipNo   = @cPickSlipNo     -- (james02)

            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance
         END
          -- PickDetail have less
         ELSE IF @nQTY_PD < @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               Status = @cStatus,
               CaseID = CASE WHEN ISNULL(@nCartonNo, 0) = 0 THEN CaseID ELSE @nCartonNo END,
               Pickslipno = @cPickSlipNo
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66028
               SET @cErrMsg = rdt.rdtgetmessage( 66028, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- Exclude short picked (status = '4')
            IF @cStatus = '5'
            BEGIN          
               EXEC RDT.rdt_Case_Pick_InsertPack
                  @cStorerKey,
                  @cPickDetailKey,
                  @cSKU,
                  @cPickSlipNo,
                  @nPickQty,
                  @nCartonNo,
                  @cLangCode,
                  @nErrNo          OUTPUT,
                  @cErrMsg         OUTPUT  -- screen limitation, 20 char max

               IF @nErrNo <> 0 
               BEGIN
                  GOTO RollBackTran
               END   
            END

           -- (Vicky06) EventLog - QTY
           EXEC RDT.rdt_STD_EventLog
              @cActionType   = '3', -- Picking
              @cUserID       = @cUserName,
              @nMobileNo     = @nMobile,
              @nFunctionID   = @nFunc,
              @cFacility     = @cFacility,
              @cStorerKey    = @cStorerkey,
              @cLocation     = @cLOC,
              @cID           = @cDropID,
              @cSKU          = @cSKU,
              @cUOM          = @cPickUOM,
              @nQTY          = @nPickQty,
              @cRefNo1       = @cPutAwayZone,
              @cRefNo2       = @cLoadKey, 
              @cPickSlipNo   = @cPickSlipNo     -- (james02)

            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance
         END
         -- PickDetail have more, need to split
         ELSE IF @nQTY_PD > @nPickQty
         BEGIN
            -- If Status = '5' (full pick), split line if neccessary
            -- If Status = '4' (short pick), no need to split line if already last RPL line to update,
            -- just have to update the pickdetail.qty = short pick qty
            -- Get new PickDetailkey
            DECLARE @cNewPickDetailKey NVARCHAR( 10)
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @b_success         OUTPUT,
               @n_err             OUTPUT,
               @c_errmsg          OUTPUT

            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 66029
               SET @cErrMsg = rdt.rdtgetmessage( 66029, @cLangCode, 'DSP') -- 'GetDetKeyFail'
               GOTO RollBackTran
            END

            -- Create a new PickDetail to hold the balance
            INSERT INTO dbo.PICKDETAIL (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
               Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
               QTY,
               TrafficCop,
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
               --@cStatus,
               '0', DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
               @nQTY_PD - @nPickQty, -- QTY
               NULL, --TrafficCop,
               '1'  --OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66030
               SET @cErrMsg = rdt.rdtgetmessage( 66030, @cLangCode, 'DSP') --'Ins PDtl Fail'
               GOTO RollBackTran
            END

            -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nPickQty,
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66031
               SET @cErrMsg = rdt.rdtgetmessage( 66031, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- Confirm orginal PickDetail with exact QTY
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               Status = '5',
               CaseID = CASE WHEN ISNULL(@nCartonNo, 0) = 0 THEN CaseID ELSE @nCartonNo END,
               Pickslipno = @cPickSlipNo
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66032
               SET @cErrMsg = rdt.rdtgetmessage( 66032, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- Exclude short picked (status = '4')
            IF @cStatus = '5'
            BEGIN          
               EXEC RDT.rdt_Case_Pick_InsertPack
                  @cStorerKey,
                  @cPickDetailKey,
                  @cSKU,
                  @cPickSlipNo,
                  @nPickQty,
                  @nCartonNo,
                  @cLangCode,
                  @nErrNo          OUTPUT,
                  @cErrMsg         OUTPUT  -- screen limitation, 20 char max

               IF @nErrNo <> 0 
               BEGIN
                  GOTO RollBackTran
               END   
            END

           -- (Vicky06) EventLog - QTY
           EXEC RDT.rdt_STD_EventLog
              @cActionType   = '3', -- Picking
              @cUserID       = @cUserName,
              @nMobileNo     = @nMobile,
              @nFunctionID   = @nFunc,
              @cFacility     = @cFacility,
              @cStorerKey    = @cStorerkey,
              @cLocation     = @cLOC,
              @cID           = @cDropID,
              @cSKU          = @cSKU,
              @cUOM          = @cPickUOM,
              @nQTY          = @nPickQty,
              @cRefNo1       = @cPutAwayZone,
              @cRefNo2       = @cLoadKey, 
              @cPickSlipNo   = @cPickSlipNo     -- (james02)

            SET @nPickQty = 0 -- Reduce balance
         END

         IF @nPickQty = 0 BREAK -- Exit

         FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
      END
      CLOSE curPD
      DEALLOCATE curPD

      -- Stamp RPL's candidate to '5'
      UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
         Status = '5'   -- Picked
      WHERE RowRef = @nRowRef

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 66033
         SET @cErrMsg = rdt.rdtgetmessage( 66033, @cLangCode, 'DSP') --'UPDPKLockFail'
         GOTO RollBackTran
      END

--      UPDATE PD WITH (ROWLOCK) SET 
--         PD.RefNo = RPL.PickDetailKey
--      FROM RDT.RDTPickLock RPL  
--      JOIN dbo.PackDetail PD ON (RPL.PickSlipNo = PD.PickSlipNo AND RPL.SKU = PD.SKU AND RPL.ID = PD.CartonNo)
--      WHERE rowref = @nRowRef

      FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @cOrderKey, @cOrderLineNumber, @nCartonNo
   END
   CLOSE curRPL
   DEALLOCATE curRPL

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN Short_Pick_ConfirmTask

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN Short_Pick_ConfirmTask
END

GO