SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_ClusterPickCfm13                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Comfirm Pick with PickDetail.Status = '3'                   */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 22-Nov-2018 1.0  James       WMS6843 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_ClusterPickCfm13] (
   @nMobile                   INT,           
   @nFunc                     INT,           
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,           
   @nInputKey                 INT,           
   @cFacility                 NVARCHAR( 5),  
   @cStorerkey                NVARCHAR( 15), 
   @cWaveKey                  NVARCHAR( 10), 
   @cLoadKey                  NVARCHAR( 10), 
   @cOrderKey                 NVARCHAR( 10), 
   @cPutAwayZone              NVARCHAR( 10), 
   @cPickZone                 NVARCHAR( 10), 
   @cSKU                      NVARCHAR( 20), 
   @cPickSlipNo               NVARCHAR( 10), 
   @cLOT                      NVARCHAR( 10), 
   @cLOC                      NVARCHAR( 10), 
   @cDropID                   NVARCHAR( 20), 
   @cStatus                   NVARCHAR( 1),  
   @cCartonType               NVARCHAR( 10), 
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT    
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @b_success  INT,
   @n_err              INT,
   @c_errmsg           NVARCHAR( 250),
   @cPickDetailKey     NVARCHAR( 10),
   @nDropIDCnt         INT,
   @nPickQty           INT,
   @nQTY_PD            INT,
   @nRowRef            INT,
   @nTranCount         INT,
   @nRPLCount          INT,
   @nPackQty           INT,
   @nCartonNo          INT,
   @cLabelNo           NVARCHAR( 20),
   @cLabelLine         NVARCHAR( 5),
   @cConsigneeKey      NVARCHAR( 15),
   @cExternOrderKey    NVARCHAR( 30),
   @cUOM               NVARCHAR( 10), 
   @cLoadDefaultPickMethod NVARCHAR( 1),  
   @nTotalPickedQty    INT,   
   @nTotalPackedQty    INT,   
   @nPickPackQty       INT,   
   @nMultiStorer       INT, 
   @cRoute             NVARCHAR( 20),  
   @cOrderRefNo        NVARCHAR( 18), 
   @cUserName          NVARCHAR( 20), 
   @cPrevDropID        NVARCHAR( 20),
   @cID                NVARCHAR( 18),
   @cSplitPD_Status    NVARCHAR( 1)

   SET @cPrevDropID = ''

   SELECT @cUserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
   
   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
   BEGIN
      SELECT @cStorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
   END

   SELECT @cLoadKey = LoadKey FROM dbo.OrderDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND OrderKey = @cOrderKey

   SELECT @cLoadDefaultPickMethod = LoadPickMethod FROM dbo.LoadPlan WITH (NOLOCK)
   WHERE LoadKey = @cLoadKey

   IF ISNULL(@cPickSlipNo, '') = ''
   BEGIN
      SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey
   END

   -- If still blank picklipno then look for conso pick   
   IF ISNULL(@cPickSlipNo, '') = ''
   BEGIN
      SELECT TOP 1 @cPickSlipNo = PickHeaderKey 
      FROM dbo.PickHeader PIH WITH (NOLOCK)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PIH.ExternOrderKey = LPD.LoadKey)
      JOIN dbo.Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
      WHERE O.OrderKey = @cOrderKey
         AND O.StorerKey = @cStorerKey
   END

   -- If short pick and need split line, short pick the rest
   -- Normal split line (change dropid), status = '0'
   IF @cStatus = '4'
      SET @cSplitPD_Status = '4'
   ELSE
      SET @cSplitPD_Status = '0'

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_ClusterPickCfm13

   SELECT @cUOM = RTRIM(PACK.PACKUOM3)
   FROM dbo.PACK PACK WITH (NOLOCK)
   JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   WHERE SKU.Storerkey = @cStorerKey
   AND   SKU.SKU = @cSKU

   -- Get RDT.RDTPickLock candidate to offset
   DECLARE curRPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRef, DropID, PickQty, ID
   FROM RDT.RDTPickLock WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU
      AND LOT = @cLOT
      AND LOC = @cLOC
      AND Status = '1'
      AND AddWho = @cUserName
      AND PutAwayZone = CASE WHEN @cPutAwayZone = 'ALL' THEN PutAwayZone ELSE @cPutAwayZone END
      AND PickZone = CASE WHEN ISNULL(@cPickZone  , '') = '' THEN PickZone ELSE @cPickZone END
      AND WaveKey = @cWaveKey
   Order By RowRef
   OPEN curRPL
   FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @cID
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Get PickDetail candidate to offset based on RPL's candidate
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
      WHERE StorerKey  = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.LOT = @cLOT
         AND PD.LOC = @cLOC
         AND PD.ID = @cID
         AND PD.Status = '0'
         AND WD.WaveKey = @cWaveKey
      ORDER BY PD.OrderKey, PD.PickDetailKey
      OPEN curPD
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @nPickPackQty = @nQTY_PD 

         IF @nPickQty = 0
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = CASE WHEN ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4' THEN '' ELSE @cDropID END,
               Status = '4'   -- short pick
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 132651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END
            ELSE
            BEGIN
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
                 @cUOM          = @cUOM,
                 @nQTY          = @nPickQty,
                 @cLot          = @cLOT,
                 @cRefNo1       = @cPutAwayZone,
                 @cRefNo2       = @cPickZone,
                 @cRefNo3       = @cOrderKey,
                 @cRefNo4       = @cPickSlipNo
            END
         END
         ELSE
         -- Exact match
         IF @nQTY_PD = @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               Status = '3', 
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 132652
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END
            ELSE
            BEGIN
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
                 @cUOM          = @cUOM,
                 @nQTY          = @nPickQty,
                 @cLot          = @cLOT,
                 @cRefNo1       = @cPutAwayZone,
                 @cRefNo2       = @cPickZone,
                 @cRefNo3       = @cOrderKey,
                 @cRefNo4       = @cPickSlipNo
            END
            SET @nPickQty = @nPickQty - @nQTY_PD 
         END
         -- PickDetail have less
         ELSE IF @nQTY_PD < @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               Status = '3', 
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 132653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END
            ELSE
            BEGIN
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
                 @cUOM          = @cUOM,
                 @nQTY          = @nPickQty,
                 @cLot          = @cLOT,
                 @cRefNo1       = @cPutAwayZone,
                 @cRefNo2       = @cPickZone,
                 @cRefNo3       = @cOrderKey,
                 @cRefNo4       = @cPickSlipNo
            END

            SET @nPickQty = @nPickQty - @nQTY_PD 
         END
         -- PickDetail have more, need to split
         ELSE IF @nQTY_PD > @nPickQty
         BEGIN
            IF @nPickQty > 0 
            BEGIN
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
                  SET @nErrNo = 132654
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
                  @cSplitPD_Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                  @nQTY_PD - @nPickQty, -- QTY
                  NULL, --TrafficCop,
                  '1'  --OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 132655
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
                  SET @nErrNo = 132656
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  DropID = @cDropID,
                  Status = '3', 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 132657
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END
               ELSE
               BEGIN
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
                    @cUOM          = @cUOM,
                    @nQTY          = @nPickQty,
                    @cLot          = @cLOT,
                    @cRefNo1       = @cPutAwayZone,
                    @cRefNo2       = @cPickZone,
                    @cRefNo3       = @cOrderKey,
                    @cRefNo4       = @cPickSlipNo
               END

               SET @nPickPackQty = @nPickQty 
               SET @nPickQty = 0 
            END
         END

         -- Get total qty that need to be packed
         SELECT @nPackQty =  ISNULL(SUM(PickQty), 0)
         FROM RDT.RDTPickLock WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND OrderKey = @cOrderKey
            AND SKU = @cSKU
            AND LOT = @cLOT
            AND LOC = @cLOC
            AND Status = '1'
            AND AddWho = @cUserName
            AND DropID = @cDropID 
            AND PutAwayZone = CASE WHEN @cPutAwayZone = 'ALL' THEN PutAwayZone ELSE @cPutAwayZone END
            AND PickZone = CASE WHEN ISNULL(@cPickZone  , '') = '' THEN PickZone ELSE @cPickZone END
            AND WaveKey = @cWaveKey
      
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickInsPackDt', @cStorerKey) = '1' AND @nPackQty > 0
         BEGIN
            SET @nPackQty = @nPickPackQty 

            IF @cLoadDefaultPickMethod = 'C' 
            BEGIN
               -- Prevent overpacked 
               SET @nTotalPickedQty = 0 
               SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY), 0) 
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
               JOIN dbo.Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey
               WHERE PD.StorerKey = @cStorerKey
                  AND O.LoadKey = @cLoadKey
                  AND PD.SKU = @cSKU
                  AND PD.Status = '5' 

               SET @nTotalPackedQty = 0 
               SELECT @nTotalPackedQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND SKU = @cSKU
            END
            ELSE
            BEGIN
               -- Prevent overpacked 
               SET @nTotalPickedQty = 0 
               SELECT @nTotalPickedQty = ISNULL(SUM(QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderKey
                  AND SKU = @cSKU
                  AND Status = '5' 

               SET @nTotalPackedQty = 0 
               SELECT @nTotalPackedQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND SKU = @cSKU
            END
            
            IF (@nTotalPackedQty + @nPackQty) > @nTotalPickedQty 
            BEGIN
               
               SET @nErrNo = 132658
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Overpacked'
               GOTO RollBackTran
            END
            
            -- insert packdetail (start)
 
            -- Same DropID + PickSlipNo will group SKU into a carton. 1 carton could be multi sku
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND DropID = @cDropID)
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
               BEGIN
                  SELECT @cRoute = [Route], 
                           @cOrderRefNo = SUBSTRING(ExternOrderKey, 1, 18), 
                           @cConsigneekey = ConsigneeKey 
                  FROM dbo.Orders WITH (NOLOCK) 
                  WHERE OrderKey = @cOrderKey
                  AND   StorerKey = @cStorerKey
   
                  INSERT INTO dbo.PackHeader
                  (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                  VALUES
                  (@cRoute, @cOrderKey, @cOrderRefNo, @cLoadKey, @cConsigneekey, @cStorerKey, @cPickSlipNo)

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 132659
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPHdrFail'
                     GOTO RollBackTran
                  END 
               END

               SET @nCartonNo = 0

               SET @cLabelNo = ''
               EXECUTE dbo.nsp_GenLabelNo
                  '',
                  @cStorerKey,
                  @c_labelno     = @cLabelNo  OUTPUT,
                  @n_cartonno    = @nCartonNo OUTPUT,
                  @c_button      = '',
                  @b_success     = @b_success OUTPUT,
                  @n_err         = @n_err     OUTPUT,
                  @c_errmsg      = @c_errmsg  OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 132660
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'
                  GOTO RollBackTran
               END

               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
               VALUES
                  (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nPackQty,
                  @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 132661
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
                  GOTO RollBackTran
               END 
            END -- DropID not exists
            ELSE
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                     AND PickSlipNo = @cPickSlipNo
                     AND DropID = @cDropID
                     AND SKU = @cSKU)
               BEGIN
                  SET @nCartonNo = 0

                  SET @cLabelNo = ''

                  SELECT @nCartonNo = CartonNo, @cLabelNo = LabelNo 
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE Pickslipno = @cPickSlipNo
                     AND StorerKey = @cStorerKey
                     AND DropID = @cDropID

                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE Pickslipno = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     AND DropID = @cDropID

                  INSERT INTO dbo.PackDetail
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
                  VALUES
                     (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nPackQty,
                     @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 132662
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
                     GOTO RollBackTran
                  END 
               END   -- DropID exists but SKU not exists (insert new line with same cartonno)
               ELSE
               BEGIN
                  UPDATE dbo.PackDetail WITH (ROWLOCK) SET
                     QTY = QTY + @nPackQty
                  WHERE StorerKey = @cStorerKey
                     AND PickSlipNo = @cPickSlipNo
                     AND DropID = @cDropID
                     AND SKU = @cSKU

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 132663
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
                     GOTO RollBackTran
                  END
               END   -- DropID exists and SKU exists (update qty only)
            END

         END 

         -- Scan in pickslip if not already scan in
         IF NOT EXISTS ( SELECT 1
                         FROM dbo.PickingInfo WITH (NOLOCK)
                         WHERE PickSlipNo = @cPickSlipNo)
         BEGIN
            INSERT INTO dbo.PickingInfo
            (PickSlipNo, ScanInDate, PickerID )
            Values(@cPickSlipNo, GETDATE(), sUser_sName())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 132665
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SCAN IN FAIL'
               GOTO RollBackTran
            END
         END   -- Insert pickinginfo
         ELSE
         BEGIN
            UPDATE dbo.PickingInfo WITH (ROWLOCK) SET
               ScanInDate = GETDATE(),
               PickerID = sUser_sName()
            WHERE PickSlipNo = @cPickSlipNo
            AND   ScanInDate IS NULL

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 132666
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SCAN IN FAIL'
               GOTO RollBackTran
            END
         END   -- Update pickinginfo
         

         IF @nPickQty = 0 
         BEGIN
            BREAK -- Exit   
         END

         FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
      END
      CLOSE curPD
      DEALLOCATE curPD

      -- (james01)
      -- If change of dropid only need insert new dropid record
      IF @cPrevDropID <> @cDropID
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                        WHERE DropID = @cDropID) OR 
            -- If dropid not exists then need create new dropid.  
            -- If exists dropid then check if allow reuse dropid. If allow then go on.
            rdt.RDTGetConfig( @nFunc, 'ClusterPickAllowReuseDropID', @cStorerKey) = '1'
         BEGIN
            -- Insert into DropID table   
            IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPromtOpenDropID', @cStorerKey) = '1' 
            BEGIN
               SET @nErrNo = 0  
               EXECUTE rdt.rdt_Cluster_Pick_DropID  
                  @nMobile, 
                  @nFunc,    
                  @cStorerKey,  
                  @cUserName,  
                  @cFacility,  
                  @cLoadKey,
                  @cPickSlipNo,  
                  @cOrderKey, 
                  @cDropID       OUTPUT,  
                  @cSKU,  
                  'I',      -- I = Insert
                  @cLangCode,  
                  @nErrNo        OUTPUT,  
                  @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max  
  
               IF @nErrNo <> 0  
                  GOTO RollBackTran
            END
         END

         SET @cPrevDropID = @cDropID
      END

      -- Stamp RPL's candidate to '5'
      UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
         Status = '5'   -- Picked
      WHERE RowRef = @nRowRef

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 132664
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKLockFail'
         GOTO RollBackTran
      END

      FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @cID
   END
   CLOSE curRPL
   DEALLOCATE curRPL

   IF @cSplitPD_Status = '4'
   BEGIN
      -- If short pick then need short pick the rest of the pickdetail of same sku + loc
      -- Cater for many pickdetail line same loc, sku, id, different orderkey
      DECLARE CUR_SHORT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PickDetailKey
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.LOC = @cLOC
         AND PD.Status = '0'
         AND WD.WaveKey = @cWaveKey
         AND EXISTS (
            SELECT 1--RowRef, DropID, PickQty, ID
            FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE StorerKey = PD.StorerKey
               AND SKU = PD.SKU
               AND LOC = PD.LOC
               AND ISNULL( ID, '') = PD.ID
               AND Status = '5'
               AND AddWho = @cUserName
               AND PutAwayZone = CASE WHEN @cPutAwayZone = 'ALL' THEN PutAwayZone ELSE @cPutAwayZone END
               AND PickZone = CASE WHEN ISNULL(@cPickZone  , '') = '' THEN PickZone ELSE @cPickZone END
               AND WaveKey = WD.WaveKey)

      OPEN CUR_SHORT
      FETCH NEXT FROM CUR_SHORT INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE dbo.PickDetail SET
            Status = @cSplitPD_Status
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 132667
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKLockFail'
            GOTO RollBackTran
         END

         FETCH NEXT FROM CUR_SHORT INTO @cPickDetailKey
      END
      CLOSE CUR_SHORT
      DEALLOCATE CUR_SHORT
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_ClusterPickCfm13

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_ClusterPickCfm13
        
END

GO