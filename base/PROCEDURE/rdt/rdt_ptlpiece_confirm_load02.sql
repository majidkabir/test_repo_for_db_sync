SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLPiece_Confirm_Load02                         */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Confirm by load                                             */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 16-11-2022 1.0  Ung         WMS-21112 Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Confirm_Load02] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cLight       NVARCHAR( 1)
   ,@cStation     NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1)
   ,@cSKU         NVARCHAR( 20)
   ,@cIPAddress   NVARCHAR( 40) OUTPUT
   ,@cPosition    NVARCHAR( 10) OUTPUT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
   ,@cResult01    NVARCHAR( 20) OUTPUT
   ,@cResult02    NVARCHAR( 20) OUTPUT
   ,@cResult03    NVARCHAR( 20) OUTPUT
   ,@cResult04    NVARCHAR( 20) OUTPUT
   ,@cResult05    NVARCHAR( 20) OUTPUT
   ,@cResult06    NVARCHAR( 20) OUTPUT
   ,@cResult07    NVARCHAR( 20) OUTPUT
   ,@cResult08    NVARCHAR( 20) OUTPUT
   ,@cResult09    NVARCHAR( 20) OUTPUT
   ,@cResult10    NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess             INT
   DECLARE @nTranCount           INT
   DECLARE @nRowCount            INT

   DECLARE @cPickSlipNo          NVARCHAR(10)
   DECLARE @cDropID              NVARCHAR(20)
   DECLARE @cZone                NVARCHAR(18)
   DECLARE @cOrderKey            NVARCHAR(10)
   DECLARE @cLoadKey             NVARCHAR(10)
   DECLARE @cDisplay             NVARCHAR(5) = ''

   DECLARE @cFromPickDetailKey   NVARCHAR(10) = ''
   DECLARE @nFromQTY             INT
   DECLARE @cFromOrderKey        NVARCHAR(10)
   DECLARE @cFromOrderLineNumber NVARCHAR(5)
   DECLARE @cFromLOT             NVARCHAR(10)
   DECLARE @cFromLOC             NVARCHAR(10)
   DECLARE @cFromID              NVARCHAR(18)

   DECLARE @cToPickDetailKey     NVARCHAR(10) = ''
   DECLARE @nToQTY               INT

   DECLARE @nCartonNo            INT
   DECLARE @cLabelNo             NVARCHAR(20)
   DECLARE @cLabelLine           NVARCHAR(5)

   -- Get assign info
   SELECT TOP 1 @cPickSlipNo = PickSlipNo 
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
   WHERE Station = @cStation

   -- Get PickHeader info
   SELECT
      @cZone = Zone,
      @cOrderKey = ISNULL( OrderKey, ''),
      @cLoadKey = ExternOrderKey
   FROM PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      SELECT TOP 1
         @cLoadKey = O.LoadKey, 
         @cFromPickDetailKey = PD.PickDetailKey,
         @nFromQTY = PD.QTY, 
         @cFromOrderKey = PD.OrderKey, 
         @cFromOrderLineNumber = PD.OrderLineNumber, 
         @cFromLOT = PD.LOT,
         @cFromLOC = PD.LOC,
         @cFromID  = PD.ID
      FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (L.LoadKey = O.LoadKey)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         JOIN dbo.RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey AND RKL.PickSlipNo = L.PickSlipNo)
      WHERE L.Station = @cStation
         AND PD.SKU = @cSKU
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         
      SELECT TOP 1
         @cToPickDetailKey = PD.PickDetailKey,
         @nToQTY = QTY
      FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (L.LoadKey = O.LoadKey)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey AND RKL.PickSlipNo = L.PickSlipNo)
      WHERE L.Station = @cStation
         AND PD.SKU = @cSKU
         AND PD.CaseID = 'SORTED'
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         AND PD.OrderKey = @cFromOrderKey
         AND PD.OrderLineNumber = @cFromOrderLineNumber 
         AND PD.LOT = @cFromLOT
         AND PD.LOC = @cFromLOC
         AND PD.ID = @cFromID
   END

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      SELECT TOP 1
         @cLoadKey = O.LoadKey, 
         @cFromPickDetailKey = PD.PickDetailKey,
         @nFromQTY = PD.QTY, 
         @cFromOrderKey = PD.OrderKey, 
         @cFromOrderLineNumber = PD.OrderLineNumber, 
         @cFromLOT = PD.LOT,
         @cFromLOC = PD.LOC,
         @cFromID  = PD.ID
      FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (L.LoadKey = O.LoadKey)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE L.Station = @cStation
         AND PD.SKU = @cSKU
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'

      SELECT TOP 1
         @cToPickDetailKey = PD.PickDetailKey,
         @nToQTY = QTY
      FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (L.LoadKey = O.LoadKey)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE L.Station = @cStation
         AND PD.SKU = @cSKU
         AND PD.CaseID = 'SORTED'
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         AND PD.OrderKey = @cFromOrderKey
         AND PD.OrderLineNumber = @cFromOrderLineNumber 
         AND PD.LOT = @cFromLOT
         AND PD.LOC = @cFromLOC
         AND PD.ID = @cFromID
   END

   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      SELECT TOP 1
         @cLoadKey = O.LoadKey, 
         @cFromPickDetailKey = PD.PickDetailKey,
         @nFromQTY = PD.QTY, 
         @cFromOrderKey = PD.OrderKey, 
         @cFromOrderLineNumber = PD.OrderLineNumber, 
         @cFromLOT = PD.LOT,
         @cFromLOC = PD.LOC,
         @cFromID  = PD.ID
      FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (L.LoadKey = O.LoadKey)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE L.Station = @cStation
         AND PD.SKU = @cSKU
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         
      SELECT TOP 1
         @cToPickDetailKey = PD.PickDetailKey,
         @nToQTY = QTY
      FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (L.LoadKey = O.LoadKey)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE L.Station = @cStation
         AND PD.SKU = @cSKU
         AND PD.CaseID = 'SORTED'
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         AND PD.OrderKey = @cFromOrderKey
         AND PD.OrderLineNumber = @cFromOrderLineNumber 
         AND PD.LOT = @cFromLOT
         AND PD.LOC = @cFromLOC
         AND PD.ID = @cFromID
   END

   -- Custom PickSlip
   ELSE
   BEGIN
      SELECT TOP 1
         @cLoadKey = O.LoadKey, 
         @cFromPickDetailKey = PD.PickDetailKey,
         @nFromQTY = PD.QTY, 
         @cFromOrderKey = PD.OrderKey, 
         @cFromOrderLineNumber = PD.OrderLineNumber, 
         @cFromLOT = PD.LOT,
         @cFromLOC = PD.LOC,
         @cFromID  = PD.ID
      FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (L.LoadKey = O.LoadKey)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey AND PD.PickSlipNo = L.PickSlipNo)
      WHERE L.Station = @cStation
         AND PD.SKU = @cSKU
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'

      SELECT TOP 1
         @cToPickDetailKey = PD.PickDetailKey,
         @nToQTY = QTY
      FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (L.LoadKey = O.LoadKey)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey AND PD.PickSlipNo = L.PickSlipNo)
      WHERE L.Station = @cStation
         AND PD.SKU = @cSKU
         AND PD.CaseID = 'SORTED'
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC'
         AND PD.OrderKey = @cFromOrderKey
         AND PD.OrderLineNumber = @cFromOrderLineNumber 
         AND PD.LOT = @cFromLOT
         AND PD.LOC = @cFromLOC
         AND PD.ID = @cFromID
   END

   -- Check blank
   IF @cFromPickDetailKey = ''
   BEGIN
      SET @nErrNo = 195301
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No task
      GOTO Quit
   END


   /***********************************************************************************************
                                              PickDetail
   ***********************************************************************************************/
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PTLPiece_Confirm -- For rollback or commit only our own transaction

   /*
      For 1 position = 1 load, it is most likeky a B2B process. So won't split PickDetail to 1 QTY = 1 record
      Need to use find PickDetail to reduce and top up approach

      1. Reduce from pickdetail
         if from qty = 1
            if have to pickdetail, direct delete the from, don't need to reduce first
            if don't have to pickdetail, stamp it as sorted
         else 
            if have to pickdetail
               reduce from pickdetail
            if don't have to pickdetail
               split line, new line holding the balance
               stamp from line as sorted
            
      2. Top up to pickdetail
         if found
      
      test scenarios:
         1 QTY
         2 QTY
         3 QTY
      end result should only have 1 pickdetail line after fully sorted
   
   */

   -- 1. Reduce from pickdetail
   IF @nFromQTY = 1 
   BEGIN
      -- if have to pickdetail, delete the from, don't need to reduce first
      IF @cToPickDetailKey <> ''
      BEGIN
         UPDATE dbo.PickDetail SET
            ArchiveCop = '9'
         WHERE PickDetailKey = @cFromPickDetailKey
            AND QTY = @nFromQTY
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @nErrNo = 195302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END

         DELETE dbo.PickDetail
         WHERE PickDetailKey = @cFromPickDetailKey
            AND QTY = @nFromQTY
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @nErrNo = 195303
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL PKDtl Fail
            GOTO RollBackTran
         END
      END
      
      -- if don't have to pickdetail, stamp it as sorted
      ELSE
      BEGIN
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            CaseID = 'SORTED',
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cFromPickDetailKey
            AND QTY = @nFromQTY
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @nErrNo = 195304
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
   END
   ELSE
   BEGIN
      -- if have to pickdetail
      IF @cToPickDetailKey <> ''
      BEGIN
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            QTY = QTY - 1,
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cFromPickDetailKey
            AND QTY = @nFromQTY
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @nErrNo = 195305
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
      
      -- if don't have to pickdetail
      ELSE
      BEGIN
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
            SET @nErrNo = 195306
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
            GOTO RollBackTran
         END

         -- Create new a PickDetail to hold the balance
         INSERT INTO dbo.PickDetail (
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
            UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, Channel_ID, 
            PickDetailKey,
            QTY,
            TrafficCop,
            OptimizeCop)
         SELECT
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
            UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
            CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, Channel_ID, 
            @cNewPickDetailKey,
            @nFromQTY - 1, -- QTY
            NULL,        -- TrafficCop
            '1'          -- OptimizeCop
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE PickDetailKey = @cFromPickDetailKey
            AND QTY = @nFromQTY
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @nErrNo = 195307
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
            GOTO RollBackTran
         END

         -- Check RefKeyLookup
         IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cFromPickDetailKey)
         BEGIN
            -- Insert RefKeyLookup
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickslipNo, OrderKey, OrderLineNumber, Loadkey)
            SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
            FROM RefKeyLookup WITH (NOLOCK)
            WHERE PickDetailKey = @cFromPickDetailKey
            
            SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
            IF @nErrNo <> 0 OR @nRowCount <> 1
            BEGIN
               SET @nErrNo = 195308
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
               GOTO RollBackTran
            END
         END

         -- stamp from line as sorted
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            QTY = 1,
            CaseID = 'SORTED',
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME(),
            Trafficcop = NULL
         WHERE PickDetailKey = @cFromPickDetailKey
            AND QTY = @nFromQTY
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @nErrNo = 195309
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
   END
   
   -- 2. Top up to pickdetail
   IF @cToPickDetailKey <> ''
   BEGIN
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         QTY = QTY + 1,
         EditDate = GETDATE(),
         EditWho  = SUSER_SNAME(), 
         TrafficCop = NULL
      WHERE PickDetailKey = @cToPickDetailKey
         AND QTY = @nToQTY
      SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
      IF @nErrNo <> 0 OR @nRowCount <> 1
      BEGIN
         SET @nErrNo = 195310
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
         GOTO RollBackTran
      END
   END

   /***********************************************************************************************
                                              PackDetail
   ***********************************************************************************************/
   -- Get position info
   SELECT
      @cIPAddress = IPAddress,
      @cPosition = Position, 
      @cLabelNo = CartonID
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
   WHERE Station = @cStation
      AND LoadKey = @cLoadKey

   -- Storer config
   DECLARE @cUpdatePackDetail NVARCHAR( 1)
   SET @cUpdatePackDetail = rdt.RDTGetConfig( @nFunc, 'UpdatePackDetail', @cStorerkey)

   -- Generate PackDetail.LabelNo
   IF @cUpdatePackDetail = '1'
   BEGIN
      -- Get Packing side pick slip
      SELECT @cPickSlipNo = PickSlipNo FROM PackHeader WITH (NOLOCK) WHERE LoadKey = @cLoadKey
      
      -- PackHeader
      IF @@ROWCOUNT = 0
      BEGIN
         -- Generate PickSlipNo
         EXECUTE dbo.nspg_GetKey
            'PICKSLIP',
            9,
            @cPickslipNo   OUTPUT,
            @bSuccess      OUTPUT,
            @nErrNo        OUTPUT,
            @cErrMsg       OUTPUT  
         IF @nErrNo <> 0
            GOTO RollBackTran

         SET @cPickslipNo = 'P' + @cPickslipNo
         
         INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey)
         VALUES (@cPickSlipNo, @cStorerKey, '', @cLoadKey)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 195311
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPHdrFail
            GOTO RollBackTran
         END
      END
      
      -- Get LabelLine
      SET @cLabelLine = ''
      SET @nCartonNo = 0
      SELECT 
         @nCartonNo = CartonNo, 
         @cLabelLine = LabelLine
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo 
         AND LabelNo = @cLabelNo 
         AND SKU = @cSKU
      
      -- PackDetail
      IF @cLabelLine = ''
      BEGIN
         -- Insert PackDetail
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, 
            AddWho, AddDate, EditWho, EditDate)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, 1, 
            'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 195312
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPackDtlFail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- Update Packdetail
         UPDATE dbo.PackDetail WITH (ROWLOCK) SET   
            SKU = @cSKU, 
            QTY = QTY + 1, 
            EditWho = 'rdt.' + SUSER_SNAME(), 
            EditDate = GETDATE(), 
            ArchiveCop = NULL
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND LabelLine = @cLabelLine
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 195313
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPackDtlFail
            GOTO RollBackTran
         END
      END
      
      -- Get system assigned CartonoNo and LabelNo
      IF @nCartonNo = 0
      BEGIN
         -- If insert cartonno = 0, system will auto assign max cartonno
         SELECT TOP 1 
            @nCartonNo = CartonNo
         FROM PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND SKU = @cSKU
            AND AddWho = 'rdt.' + SUSER_SNAME()
         ORDER BY CartonNo DESC -- max cartonno
      END
      
      -- PackInfo
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
      BEGIN
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, QTY)
         VALUES (@cPickSlipNo, @nCartonNo, 1)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 195314
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INSPackInfFail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.PackInfo SET
            QTY = QTY + 1, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE PickslipNo = @cPickslipNo
            AND CartonNo = @nCartonNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 195315
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPDPackInfFail
            GOTO RollBackTran
         END
      END
   
      -- Pack confirm
      EXEC rdt.rdt_Pack_PackConfirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPickSlipNo
         ,'' -- @cFromDropID
         ,'' -- @cPackDtlDropID
         ,'' -- @cPrintPackList OUTPUT
         ,@nErrNo         OUTPUT
         ,@cErrMsg        OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran
         
      -- Print label, pack list
      IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9')
      BEGIN
         -- Courier interface
         IF EXISTS( SELECT TOP 1 1 FROM Orders (nolock) WHERE Loadkey = @cLoadKey AND ShipperKey = 'SGW') 
         BEGIN
            EXEC ispGenTransmitLog2   
               @c_TableName      = 'WSSHIPINFOSGW'  
               ,@c_Key1          = @cLoadKey  
               ,@c_Key2          = ''  
               ,@c_Key3          = @cStorerkey  
               ,@c_TransmitBatch = ''  
               ,@b_Success       = @bSuccess    OUTPUT  
               ,@n_Err           = @nErrNo      OUTPUT  
               ,@c_ErrMsg        = @cErrMsg     OUTPUT        
            IF @bSuccess <> 1      
               GOTO RollBackTran  
         END
         
         -- Get login info
         DECLARE @cPaperPrinter NVARCHAR( 10)
         DECLARE @cLabelPrinter NVARCHAR( 10)
         SELECT 
            @cPaperPrinter = Printer_Paper,
            @cLabelPrinter = Printer
         FROM rdt.rdtMobRec WITH (NOLOCK)
         WHERE Mobile = @nMobile

         -- Storer config
         DECLARE @cCartonManifest NVARCHAR( 10)
         DECLARE @cPackList       NVARCHAR( 10)
         DECLARE @cShipLabel      NVARCHAR( 10)
         SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)
         IF @cCartonManifest = '0'
            SET @cCartonManifest = ''
         SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)
         IF @cPackList = '0'
            SET @cPackList = ''
         SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
         IF @cShipLabel = '0'
            SET @cShipLabel = ''

         -- Ship label
         IF @cShipLabel <> ''
         BEGIN
            -- Common params
            DECLARE @tShipLabel AS VariableTable
            INSERT INTO @tShipLabel (Variable, Value) VALUES
               ( '@cStorerKey',     @cStorerKey),
               ( '@cPickSlipNo',    @cPickSlipNo),
               ( '@cLabelNo',       @cLabelNo),
               ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cShipLabel, -- Report type
               @tShipLabel, -- Report params
               'rdt_PTLPiece_Confirm_Load02',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END

         -- Carton manifest
         IF @cCartonManifest <> ''
         BEGIN
            -- Common params
            DECLARE @tCartonManifest AS VariableTable
            INSERT INTO @tCartonManifest (Variable, Value) VALUES
               ( '@cStorerKey',     @cStorerKey),
               ( '@cPickSlipNo',    @cPickSlipNo),
               ( '@cLabelNo',       @cLabelNo),
               ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cCartonManifest, -- Report type
               @tCartonManifest, -- Report params
               'rdt_PTLPiece_Confirm_Load02',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
         
         -- Packing list
         IF @cPackList <> ''
         BEGIN
            -- Get report param
            DECLARE @tPackList AS VariableTable
            INSERT INTO @tPackList (Variable, Value) VALUES
               ( '@cStorerKey',     @cStorerKey),
               ( '@cPickSlipNo',    @cPickSlipNo)

            -- Print packing list
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cPackList, -- Report type
               @tPackList, -- Report params
               'rdt_PTLPiece_Confirm_Load02',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
   END

   -- Draw matrix (and light up)
   EXEC rdt.rdt_PTLPiece_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
      ,@cLight
      ,@cStation
      ,@cMethod
      ,@cSKU
      ,@cIPAddress
      ,@cPosition
      ,@cDisplay
      ,@nErrNo     OUTPUT
      ,@cErrMsg    OUTPUT
      ,@cResult01  OUTPUT
      ,@cResult02  OUTPUT
      ,@cResult03  OUTPUT
      ,@cResult04  OUTPUT
      ,@cResult05  OUTPUT
      ,@cResult06  OUTPUT
      ,@cResult07  OUTPUT
      ,@cResult08  OUTPUT
      ,@cResult09  OUTPUT
      ,@cResult10  OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
     @cActionType     = '3',
     @nMobileNo       = @nMobile,
     @nFunctionID     = @nFunc,
     @cFacility       = @cFacility,
     @cStorerKey      = @cStorerkey,
     @cPickSlipNo     = @cPickSlipNo,
     @cLoadKey        = @cLoadKey, 
     @cLabelNo        = @cLabelNo,
     @cSKU            = @cSKU,
     @cDeviceID       = @cStation,
     @cDevicePosition = @cPosition, 
     @nQty            = 1

   COMMIT TRAN rdt_PTLPiece_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLPiece_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO