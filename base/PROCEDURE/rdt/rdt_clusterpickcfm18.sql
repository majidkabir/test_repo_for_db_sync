SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_ClusterPickCfm18                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: UA Comfirm Pick SP. Stamp Packdetail.Refno2 = Lottable08    */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 30-04-2021  1.0  Chermaine WMS-16884 Created(dup rdt_ClusterPickCfm01)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_ClusterPickCfm18] (
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

   DECLARE  @b_success  INT,
            @cUserName  NVARCHAR( 20),
   @n_err              INT,
   @c_errmsg           NVARCHAR( 250),
   @cPickDetailKey     NVARCHAR( 10),
   @nPickQty           INT,
   @nQTY_PD            INT,
   @nRowRef            INT,
   @nTranCount         INT,
   @nPackQty           INT,
   @nCartonNo          INT,
   @cLabelNo           NVARCHAR( 20),
   @cLabelLine         NVARCHAR( 5),
   @cKeyname           NVARCHAR( 30),
   @cConsigneeKey      NVARCHAR( 15),
   @cExternOrderKey    NVARCHAR( 30),
   @cUOM               NVARCHAR( 10),
   @cLoadDefaultPickMethod NVARCHAR( 1),
   @nTotalPickedQty    INT,
   @nTotalPackedQty    INT,
   @nPickPackQty       INT,
   @cRoute             NVARCHAR( 20),
   @cOrderRefNo        NVARCHAR( 18),
   @cCOO               NVARCHAR( 30)
   
   DECLARE @cClusterPickGenLabelNo_SP  NVARCHAR( 20),
           @cSQL                       NVARCHAR( MAX),
           @cSQLParam                  NVARCHAR( MAX)
   
   SET @cClusterPickGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickGenLabelNo_SP', @cStorerKey) 
      
   SELECT @cUserName = UserName 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SELECT @cLoadKey = LoadKey 
   FROM dbo.OrderDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND OrderKey = @cOrderKey

   SELECT @cLoadDefaultPickMethod = LoadPickMethod 
   FROM dbo.LoadPlan WITH (NOLOCK)
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

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_ClusterPickCfm18

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
      AND OrderKey = @cOrderKey
      AND SKU = @cSKU
      AND LOT = @cLOT
      AND LOC = @cLOC
      AND Status = '1'
      AND AddWho = @cUserName
      AND PutAwayZone = CASE WHEN @cPutAwayZone = 'ALL' THEN PutAwayZone ELSE @cPutAwayZone END
      AND PickZone = CASE WHEN ISNULL(@cPickZone  , '') = '' THEN PickZone ELSE @cPickZone END
   Order By RowRef
   OPEN curRPL
   FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @nCartonNo
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Get PickDetail candidate to offset based on RPL's candidate
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, QTY
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE OrderKey  = @cOrderKey
         AND StorerKey  = @cStorerKey
         AND SKU = @cSKU
         AND LOT = @cLOT
         AND LOC = @cLOC
         AND Status = '0'
      ORDER BY PickDetailKey
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
               Status = @cStatus,
               EditDate = GETDATE()
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 167251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END
            ELSE
            BEGIN
               -- EventLog - QTY
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
               DropID = CASE WHEN ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4' THEN '' ELSE @cDropID END,
               Status = @cStatus,
               EditDate = GETDATE()
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 167252
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END
            ELSE
            BEGIN
               --EventLog - QTY
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
            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance -- SOS# 176144
         END
         -- PickDetail have less
         ELSE IF @nQTY_PD < @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = CASE WHEN ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4' THEN '' ELSE @cDropID END,
               Status = '5',
               EditDate = GETDATE()
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 167253
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

            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance
         END
         -- PickDetail have more, need to split
         ELSE IF @nQTY_PD > @nPickQty
         BEGIN
            IF @nPickQty > 0 -- SOS# 176144
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
                  SET @nErrNo = 167254
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
                  CASE WHEN ISNULL(@cLoadDefaultPickMethod, '') = 'C' THEN '4' ELSE '0' END,
                  --'0',
                  DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                  @nQTY_PD - @nPickQty, -- QTY
                  NULL, --TrafficCop,
                  '1'  --OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 167255
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
                  SET @nErrNo = 167256
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  DropID = @cDropID,
                  Status = '5',
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 167257
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
               SET @nPickQty = 0 -- Reduce balance
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
            AND DropID = @cDropID -- (ChewKP01)
            AND PutAwayZone = CASE WHEN @cPutAwayZone = 'ALL' THEN PutAwayZone ELSE @cPutAwayZone END
            AND PickZone = CASE WHEN ISNULL(@cPickZone  , '') = '' THEN PickZone ELSE @cPickZone END

         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickInsPackDt', @cStorerKey) = '1' AND @nPackQty > 0
         BEGIN
            SELECT @cCOO = Lottable08
            FROM dbo.LotAttribute WITH (NOLOCK)
            WHERE LOT = @cLOT

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
               SET @nErrNo = 167258
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Overpacked'
               GOTO RollBackTran
            END

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
                  (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, AddWho)
                  VALUES
                  (@cRoute, @cOrderKey, @cOrderRefNo, @cLoadKey, @cConsigneekey, @cStorerKey, @cPickSlipNo, 'rdt.' + sUser_sName())

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 167259
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPHdrFail'
                     GOTO RollBackTran
                  END
               END

               SET @nCartonNo = 0
               SET @cLabelNo = ''
               SET @b_success = 1
               SET @nErrNo = 0

               -- If storer config GenUCCLabelNoConfig turned on
               IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)
                          WHERE StorerKey = @cStorerKey
                          AND   ConfigKey = 'GenUCCLabelNoConfig'
                          AND   SValue = '1')
               BEGIN
                  EXEC RDT.rdt_GenUCCLabelNo
                     @cStorerKey = @cStorerKey,
                     @nMobile    = @nMobile,
                     @cLabelNo   = @cLabelNo    OUTPUT,
                     @cLangCode  = @cLangCode,
                     @nErrNo     = @nErrNo      OUTPUT,
                     @cErrMsg    = @cErrMsg     OUTPUT

                  IF @nErrNo <> 0
                     SET @b_success = -1
               END
               ELSE
               BEGIN
                  IF @cClusterPickGenLabelNo_SP NOT IN ('', '0') AND 
                     EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cClusterPickGenLabelNo_SP AND type = 'P')
                  BEGIN
                     SET @nErrNo = 0
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cClusterPickGenLabelNo_SP) +     
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
                        ' @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cPickSlipNo, @cSKU, ' + 
                        ' @nQty, @cDropID, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                        SET @cSQLParam =    
                           '@nMobile                   INT,           ' +
                           '@nFunc                     INT,           ' +
                           '@cLangCode                 NVARCHAR( 3),  ' +
                           '@nStep                     INT,           ' +
                           '@nInputKey                 INT,           ' +
                           '@cFacility                 NVARCHAR( 5),  ' +
                           '@cStorerkey                NVARCHAR( 15), ' +
                           '@cWaveKey                  NVARCHAR( 10), ' +
                           '@cLoadKey                  NVARCHAR( 10), ' +
                           '@cOrderKey                 NVARCHAR( 10), ' +
                           '@cPutAwayZone              NVARCHAR( 10), ' +
                           '@cPickZone                 NVARCHAR( 10), ' +
                           '@cPickSlipNo               NVARCHAR( 10), ' +
                           '@cSKU                      NVARCHAR( 20), ' +
                           '@nQty                      INT, ' +
                           '@cDropID                   NVARCHAR( 20), ' +
                           '@cLabelNo                  NVARCHAR( 20) OUTPUT, ' +
                           '@nCartonNo                 INT           OUTPUT, ' +
                           '@nErrNo                    INT           OUTPUT, ' +
                           '@cErrMsg                   NVARCHAR( 20) OUTPUT  ' 
               
                        EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                           @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                           @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cPickSlipNo, @cSKU, 
                           @nPackQty, @cDropID, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
                  END
                  ELSE
                  BEGIN   
                     EXECUTE dbo.nsp_GenLabelNo
                        '',
                        @cStorerKey,
                        @c_labelno     = @cLabelNo  OUTPUT,
                        @n_cartonno    = @nCartonNo OUTPUT,
                        @c_button      = '',
                        @b_success     = @b_success OUTPUT,
                        @n_err         = @nErrNo    OUTPUT,
                        @c_errmsg      = @cErrMsg   OUTPUT
                  END

                  IF @b_success <> 1
                  BEGIN
                     SET @nErrNo = 167260
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'
                     GOTO RollBackTran
                  END
               END

--			   Update pickdetail set dropid = @cLabelNo
--			   where orderkey = @cOrderKey and dropid = @cDropID and status = '5'

               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, RefNo2)
               VALUES
                  (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nPackQty,
                  @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID, @cCOO)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 167261
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

--				  Update pickdetail set dropid = @cLabelNo
--			      where orderkey = @cOrderKey and dropid = @cDropID and status = '5'

                  INSERT INTO dbo.PackDetail
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, Refno2)
                  VALUES
                     (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nPackQty,
                     @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID, @cCOO)

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 167262
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
                     GOTO RollBackTran
                  END
               END   -- DropID exists but SKU not exists (insert new line with same cartonno)
               ELSE
               BEGIN

--			   Update pickdetail set dropid = @cLabelNo
--			   where orderkey = @cOrderKey and dropid = @cDropID and status = '5'

                  UPDATE dbo.PackDetail WITH (ROWLOCK) SET
                     QTY = QTY + @nPackQty
                  WHERE StorerKey = @cStorerKey
                     AND PickSlipNo = @cPickSlipNo
                     AND DropID = @cDropID
                     AND SKU = @cSKU

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 167263
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
                     GOTO RollBackTran
                  END
               END   -- DropID exists and SKU exists (update qty only)
            END
         END


         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                        WHERE DropID = @cDropID) OR
            -- If dropid not exists then need create new dropid.
            -- If exists dropid then check if allow reuse dropid. If allow then go on.
            rdt.RDTGetConfig( @nFunc, 'ClusterPickAllowReuseDropID', @cStorerKey) = '1'
         BEGIN
            -- Insert into DropID table   (james08)
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

         IF @nPickQty = 0
         BEGIN
            BREAK
         END

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
         SET @nErrNo = 167264
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKLockFail'
         GOTO RollBackTran
      END

      FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @nCartonNo
   END
   CLOSE curRPL
   DEALLOCATE curRPL

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_ClusterPickCfm18

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_ClusterPickCfm18

END

GO