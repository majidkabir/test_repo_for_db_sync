SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LMUCfmTask_01                                   */
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
/* 02-Apr-2014 1.1  James       Add config DefaultPickByCase (james01)  */
/************************************************************************/

CREATE PROC [RDT].[rdt_LMUCfmTask_01] (
   @nMobile      INT, 
   @nFunc        INT,  
   @cLangCode    NVARCHAR( 3),
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
   @cPickUOM     NVARCHAR( 10), 
   @bSuccess     INT          OUTPUT,
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
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
   @nCartonNo         INT, 
   @cDefaultPickByCase  NVARCHAR( 1)

   SET @cDefaultPickByCase = rdt.RDTGetConfig( @nFunc, 'DefaultPickByCase', @cStorerKey)  -- (james01)
   IF @cDefaultPickByCase IN ('0', '')
      SET @cDefaultPickByCase = ''

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN Case_Pick_ConfirmTask

   IF ISNULL(@cPickSlipNo, '') = ''
   BEGIN
      SELECT @cPickSlipNo = PickheaderKey FROM dbo.PickHeader (NOLOCK) WHERE ExternOrderKey = @cLoadKey
   END

   IF ISNULL(@cPickSlipNo, '') = ''
   BEGIN
      SET @nErrNo = 86851
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PKSlip blank'
      GOTO RollBackTran
   END

   -- Get RDT.RDTPickLock candidate to offset
   DECLARE curRPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRef, DropID, PickQty, 
      OrderKey, ID --(james01)
   FROM RDT.RDTPickLock WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND LoadKey = @cLoadKey
      AND PutAwayZone = @cPutAwayZone
      AND LOC = @cLOC
      AND SKU = @cSKU
      AND Status = '1'
      AND AddWho = @cUserName
      AND UOM = CASE WHEN @cDefaultPickByCase = '1' THEN UOM ELSE @cPickUOM END -- (Vicky01)/(james01)
   ORDER BY RowRef
   OPEN curRPL
   FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @cOrderKey, @nCartonNo
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
         AND PD.UOM = CASE WHEN @cDefaultPickByCase = '1' THEN PD.UOM ELSE @cPickUOM END-- (Vicky01)
         AND PD.OrderKey = @cOrderKey  --(james01)
      ORDER BY PD.PickDetailKey
      OPEN curPD
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
      WHILE @@FETCH_STATUS <> -1
      BEGIN
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
               SET @nErrNo = 86852
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
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
              @cRefNo2       = @cLoadKey

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
               SET @nErrNo = 86853
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
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
              @cRefNo2       = @cLoadKey

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
               SET @nErrNo = 86854
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
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
              @cRefNo2       = @cLoadKey

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
               SET @nErrNo = 86855
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKeyFail'
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
               SET @nErrNo = 86856
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'
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
               SET @nErrNo = 86857
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
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
               SET @nErrNo = 86858
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
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
              @cRefNo2       = @cLoadKey

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
         SET @nErrNo = 86859
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKLockFail'
         GOTO RollBackTran
      END

      FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @cOrderKey, @nCartonNo
   END
   CLOSE curRPL
   DEALLOCATE curRPL

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN Case_Pick_ConfirmTask

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN Case_Pick_ConfirmTask
END

GO