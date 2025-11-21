SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_540SAPCfm03                                     */
/* Copyright: IDS                                                       */
/* Purpose: Merge UCC pallet                                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Ver  Author   Purposes                                    */
/* 2020-07-21 1.0  Ung      WMS-14197 Created                           */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_540SAPCfm03]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cPackByType   NVARCHAR( 10),
   @cLoadKey      NVARCHAR( 10),
   @cOrderKey     NVARCHAR( 10),
   @cConsigneeKey NVARCHAR( 15),
   @cStorerKey    NVARCHAR( 15),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cLabelNo      NVARCHAR( 20),
   @cCartonType   NVARCHAR( 10),
   @bSuccess      INT            OUTPUT,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT,
   @cUCCNo        NVARCHAR(20) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success      INT
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nPickQTY       INT
   DECLARE @nQTY_PD        INT
   DECLARE @cSOStatus      NVARCHAR( 10)
   DECLARE @cPickStatus    NVARCHAR( 1)
   DECLARE @cFacility      NVARCHAR( 5)

   SET @nErrNo = 0
   SET @cErrMsg = ''
   SET @nPickQTY = @nQTY

   DECLARE @tPD TABLE
   (
      PickDetailKey NVARCHAR(10) NOT NULL,
      OrderKey      NVARCHAR(10) NOT NULL,
      ConsigneeKey  NVARCHAR(15) NOT NULL,
      QTY           INT      NOT NULL
   )

   SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerKey)

   SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

/*--------------------------------------------------------------------------------------------------

                                           PickDetail line

--------------------------------------------------------------------------------------------------*/
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_540SAPCfm03

   DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.OrderKey, O.ConsigneeKey, PD.PickDetailKey, PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.QTY > 0
         AND PD.Status = @cPickStatus
         AND O.ConsigneeKey = @cConsigneeKey
         AND O.OrderKey = CASE WHEN @cPackByType = 'CONSO' THEN O.OrderKey ELSE @cOrderKey END
      ORDER BY PD.PickDetailKey

   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @nQTY_PD
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Exact match
      IF @nQTY_PD = @nPickQty
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            Status = '5'
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 155301
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         INSERT INTO @tPD (PickDetailKey, OrderKey, ConsigneeKey, QTY) VALUES (@cPickDetailKey, @cOrderKey, @cConsigneeKey, @nQTY_PD)
         SET @nPickQty = 0 -- Reduce balance
         BREAK
      END

      -- PickDetail have less
      ELSE IF @nQTY_PD < @nPickQty
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            Status = '5'
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 155302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         INSERT INTO @tPD (PickDetailKey, OrderKey, ConsigneeKey, QTY) VALUES (@cPickDetailKey, @cOrderKey, @cConsigneeKey, @nQTY_PD)
         SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance
      END

      -- PickDetail have more, need to split
      ELSE IF @nQTY_PD > @nPickQty
      BEGIN
         -- Get new PickDetailkey
         DECLARE @cNewPickDetailKey NVARCHAR( 10)
         EXECUTE dbo.nspg_GetKey
            'PICKDETAILKEY',
            10 ,
            @cNewPickDetailKey OUTPUT,
            @b_success         OUTPUT,
            @nErrNo            OUTPUT,
            @cErrMsg           OUTPUT
         IF @b_success <> 1
         BEGIN
            SET @nErrNo = 155303
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
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
            Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
            @nQTY_PD - @nPickQty, -- QTY
            NULL, --TrafficCop,
            '1'  --OptimizeCop
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 155304
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
            GOTO RollBackTran
         END

         -- Split RefKeyLookup
         IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
         BEGIN
            -- Insert into
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
            SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
            FROM dbo.RefKeyLookup WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 155305
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RefKeyFail
               GOTO RollBackTran
            END
         END

         -- Change orginal PickDetail with exact QTY (with TrafficCop)
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            QTY = @nPickQty,
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 155306
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         -- Pick confirm original line
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            Status = '5'
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 155307
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         INSERT INTO @tPD (PickDetailKey, OrderKey, ConsigneeKey, QTY) VALUES (@cPickDetailKey, @cOrderKey, @cConsigneeKey, @nPickQty)
         SET @nPickQty = 0 -- Reduce balance
         BREAK
      END
      FETCH NEXT FROM @curPD INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @nQTY_PD
   END

   IF @nPickQty <> 0
   BEGIN
      SET @nErrNo = 155308
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset Fail
      GOTO RollBackTran
   END


/*--------------------------------------------------------------------------------------------------

                                      PackHeader, PackDetail line

--------------------------------------------------------------------------------------------------*/
   DECLARE @curT CURSOR
   SET @curT = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey, ConsigneeKey, PickDetailKey, QTY
      FROM @tPD
   OPEN @curT
   FETCH NEXT FROM @curT INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @nQTY_PD
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @cPackByType = 'CONSO'
         SET @cOrderKey = ''

      -- Get PickSlipNo (PickHeader)
      SET @cPickSlipNo = ''
      SELECT @cPickSlipNo = PickHeaderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE ExternOrderKey = @cLoadKey
         AND OrderKey = @cOrderKey

      -- PackHeader
      IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
      BEGIN
         -- Get PickSlipNo (PackHeader)
         DECLARE @cPSNO NVARCHAR( 10)
         SET @cPSNO = ''
         SELECT @cPSNO = PickSlipNo
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
            AND OrderKey = @cOrderKey

         IF @cPSNO <> ''
            SET @cPickSlipNo = @cPSNO
         ELSE
         BEGIN
            -- New PickSlipNo
            IF @cPickSlipNo = ''
            BEGIN
               EXECUTE nspg_GetKey
                  'PICKSLIP',
                  9,
                  @cPickSlipNo OUTPUT,
                  @b_success   OUTPUT,
                  @nErrNo      OUTPUT,
                  @cErrMsg     OUTPUT
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 155309
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
                  GOTO RollBackTran
               END
               SET @cPickSlipNo = 'P' + RTRIM( @cPickSlipNo)
            END

            -- Insert PackHeader
            INSERT INTO dbo.PackHeader
               (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, [STATUS])
            VALUES
               (@cPickSlipNo, @cStorerkey, @cOrderkey, @cLoadKey, '99', @cConsigneeKey, '', 0, '0')
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 155310
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackHdrFail
               GOTO RollBackTran
            END
         END
      END

      -- PackDetail
      -- Top up to existing carton and SKU
      IF EXISTS (SELECT 1
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND LabelNo = @cLabelNo
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU)
      BEGIN
         -- Update PackDetail
         UPDATE dbo.PackDetail WITH (ROWLOCK) SET
            Qty = Qty + @nQTY_PD,
            Refno = CASE WHEN ISNULL( Refno, '') <> '' THEN Refno ELSE @cPickDetailKey END,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + sUser_sName()
         WHERE PickSlipNo = @cPickSlipNo
            AND LabelNo = @cLabelNo
            AND StorerKey = @cStorerkey
            AND SKU = @cSKU
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 155311
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- Create new carton
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cLabelNo)
         BEGIN
            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
            VALUES
               (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nQTY_PD, -- CartonNo = 0 and LabelLine = '0000', trigger will auto assign
               @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '')
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 155312
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackDtlFail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            -- Add new SKU to existing carton
            DECLARE @nCartonNo INT
            DECLARE @cLabelLine NVARCHAR(5)

            SELECT TOP 1 @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND LabelNo = @cLabelNo

            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM PACKDETAIL WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND LabelNo = @cLabelNo

            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
            VALUES
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nQTY_PD,
               @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '')
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 155313
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackDtlFail
               GOTO RollBackTran
            END
         END
      END

      /*--------------------------------------------------------------------------------------------------
                                                Auto scan in
      --------------------------------------------------------------------------------------------------*/
      IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo)
      BEGIN
         INSERT INTO dbo.PickingInfo
         (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)
         VALUES
         (@cPickSlipNo, GETDATE(), 'rdt.' + sUser_sName(), NULL, 'rdt.' + sUser_sName())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 155314
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SCAN IN FAIL
            GOTO RollBackTran
         END
      END

      /*--------------------------------------------------------------------------------------------------
                                                Auto pack confirm
      --------------------------------------------------------------------------------------------------*/
      DECLARE @nPackQTY INT

      -- Get Pick QTY
      SELECT @nPickQTY = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
      WHERE LPD.LoadKey = @cLoadKey
         AND O.OrderKey = CASE WHEN @cOrderKey = '' THEN O.OrderKey ELSE @cOrderKey END
         AND PD.Status <> '4'

      -- Get Pack QTY
      SELECT @nPackQTY = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo

      -- (james02)
      SELECT TOP 1 @cSOStatus = O.SOStatus
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
      WHERE LPD.LoadKey = @cLoadKey
         AND O.OrderKey = CASE WHEN @cOrderKey = '' THEN O.OrderKey ELSE @cOrderKey END
         AND PD.Status <> '4'

      -- Auto pack confirm
      IF (@nPickQTY = @nPackQTY) AND @cSOStatus <> 'HOLD'   -- (james02)
      BEGIN
         -- Trigger pack confirm
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET
            STATUS = '9',
            EditWho = 'rdt.' + sUser_sName(),
            EditDate = GETDATE()
         WHERE PickSlipNo = @cPickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 155315
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail PackCfm
            GOTO RollBackTran
         END

         IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo AND ScanOutDate IS NULL)
         BEGIN
            UPDATE dbo.PickingInfo WITH (ROWLOCK)
               SET SCANOUTDATE = GETDATE(),
                   EditWho = 'rdt.' + sUser_sName()
            WHERE PickSlipNo = @cPickSlipNo
            AND   ScanOutDate IS NULL

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 155316
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SCAN OUT FAIL
               GOTO RollBackTran
            END
         END

         -- Get storer config
         DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)
         EXECUTE nspGetRight
            @cFacility,
            @cStorerKey,
            '', --@c_sku
            'AssignPackLabelToOrdCfg',
            @bSuccess                 OUTPUT,
            @cAssignPackLabelToOrdCfg OUTPUT,
            @nErrNo                   OUTPUT,
            @cErrMsg                  OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran

         -- Assign
         IF @cAssignPackLabelToOrdCfg = '1'
         BEGIN
            -- Update PickDetail, base on PackDetail.DropID
            EXEC isp_AssignPackLabelToOrderByLoad
                @cPickSlipNo
               ,@bSuccess OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran
         END

         /*--------------------------------------------------------------------------------------------------
                                                      Recalc Packinfo
         --------------------------------------------------------------------------------------------------*/
         DECLARE @curPInf CURSOR
         SET @curPInf = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT CartonNo
            FROM PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            ORDER BY CartonNo
         OPEN @curPInf
         FETCH NEXT FROM @curPInf INTO @nCartonNo
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Calc weight, cube
            DECLARE @fWeight FLOAT
            DECLARE @fCube   FLOAT
            SELECT
               @fWeight = ISNULL( SUM( SKU.STDGrossWGT * PD.QTY), 0),
               @fCube = ISNULL( SUM( SKU.STDCube * PD.QTY), 0)
            FROM dbo.PackDetail PD WITH (NOLOCK)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo

            IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
            BEGIN
               INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight, Cube)
               VALUES (@cPickSlipNo, @nCartonNo, @fWeight, @fCube)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 155317
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PINFO FAIL
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               UPDATE dbo.PackInfo SET
                  Weight = @fWeight,
                  Cube = @fCube,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME()
               WHERE PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 155318
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PINFO FAIL
                  GOTO RollBackTran
               END
            END
            FETCH NEXT FROM @curPInf INTO @nCartonNo
         END

         /*--------------------------------------------------------------------------------------------------
                                                      Remove
         --------------------------------------------------------------------------------------------------*/
         DECLARE @nRowRef INT
         DECLARE @curSortLOC CURSOR
         SET @curSortLOC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef
            FROM rdt.rdtSortAndPackLOC WITH (NOLOCK)
            WHERE LoadKey = @cLoadKey
               AND ConsigneeKey = @cConsigneeKey
               AND StorerKey = @cStorerKey
         OPEN @curSortLOC
         FETCH NEXT FROM @curSortLOC INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE rdt.rdtSortAndPackLOC WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 155319
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL SPLOC FAIL
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curSortLOC INTO @nRowRef
         END

      END

      FETCH NEXT FROM @curT INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @nQTY_PD
   END

   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_540SAPCfm03
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO