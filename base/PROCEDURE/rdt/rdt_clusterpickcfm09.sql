SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_ClusterPickCfm09                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Mast cluster pick (1628).                                   */
/* Use packdetail.dropID = packdetail.labelno = pickdetai.caseID        */
/*                                                                      */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 23-Nov-2017 1.0  James       WMS3221.Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_ClusterPickCfm09] (
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
   @cUCC               NVARCHAR( 20), 
   @bSuccess           INT,
   @cAuthority         NVARCHAR(30)

   DECLARE @cClusterPickUpdLabelNoToCaseID   NVARCHAR( 1)

   SELECT @cUserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   SET @cClusterPickUpdLabelNoToCaseID = rdt.RDTGetConfig( @nFunc, 'ClusterPickUpdLabelNoToCaseID', @cStorerKey) 

   EXECUTE dbo.nspGetRight
      @c_Facility    = '',
      @c_StorerKey   = @cStorerKey,  
      @c_sku         = '', 
      @c_ConfigKey   = 'PACKUPD_UCCTOUPC', 
      @b_Success     = @bSuccess    OUTPUT,
      @c_authority   = @cAuthority  OUTPUT,
      @n_err         = @nErrNo      OUTPUT,
      @c_errmsg      = @cErrMsg     OUTPUT

   IF @bSuccess <> 1
   BEGIN
      SET @nErrNo = 65709
      SET @cErrMsg = rdt.rdtgetmessage( 65709, @cLangCode, 'DSP') --'nspGetRight'
      GOTO Fail
   END

   SET @cPrevDropID = ''
            
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

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN Cluster_Pick_ConfirmTask

   SELECT @cUOM = RTRIM(PACK.PACKUOM3)
   FROM dbo.PACK PACK WITH (NOLOCK)
   JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   WHERE SKU.Storerkey = @cStorerKey
   AND   SKU.SKU = @cSKU

   -- Get RDT.RDTPickLock candidate to offset
   DECLARE curRPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRef, DropID, PickQty, ID, ISNULL( LabelNo, '')
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
   FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @nCartonNo, @cUCC
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @cAuthority <> '1' SET @cUCC = ''

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
                  insert into traceinfo (tracename, timein, step1, step2, step3, step4, step5, col1, col2) values
                  ('mast1628short', getdate(), @cStorerKey, @cOrderKey, @cLOC, @cSKU, @cLOT, @cPickDetailKey, @nQTY_PD)
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE(),
               DropID = CASE WHEN ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4' THEN '' ELSE @cDropID END,
               Status = '4'   -- short pick
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 117651
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
                 @cRefNo4       = @cPickSlipNo,
                 @cRefNo5       = @cPickDetailKey
            END
         END
         ELSE
         -- Exact match
         IF @nQTY_PD = @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE(),
               DropID = CASE WHEN ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4' THEN '' ELSE @cDropID END,
               Status = '5'
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 117652
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
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE(),
               DropID = CASE WHEN ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4' THEN '' ELSE @cDropID END,
               Status = '5'
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 117653
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
                  SET @nErrNo = 117654
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
                  '0',
                  DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                  @nQTY_PD - @nPickQty, -- QTY
                  NULL, --TrafficCop,
                  '1'  --OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 117655
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'
                  GOTO RollBackTran
               END

               -- Split RefKeyLookup (james14)
               IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
               BEGIN
                  -- Insert into
                  INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
                  SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                  FROM RefKeyLookup WITH (NOLOCK) 
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 117656
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                     GOTO RollBackTran
                  END
               END

               -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE(),
                  QTY = @nPickQty,
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 117657
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  DropID = @cDropID,
                  Status = '5'
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 117658
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
               SET @nErrNo = 117659
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Overpacked'
               if SUSER_SNAME() = 'jameswong'
               begin
               select optimizecop, pd.* from pickdetail pd (nolock) 
                  join loadplandetail lpd (nolock) on pd.orderkey = lpd.orderkey
                  where lpd.loadkey = '0001050120' 
                  and sku = '22811028'
                  order by orderkey, orderlinenumber, PickDetailKey
                  select * from packdetail (nolock)where pickslipno = 'P008099956' and sku = '22811028'
               end
               GOTO RollBackTran
            END
            
            -- insert packdetail (start)
            -- If this carton no not exists in PackDetail then insert new line
            IF rdt.RDTGetConfig( @nFunc, 'ClusterPickPrtURNLbl', @cStorerKey) = '1' 
            BEGIN
               EXEC RDT.rdt_Case_Pick_InsertPack
                  @cStorerKey,
                  @cPickDetailKey,
                  @cSKU,
                  @cPickSlipNo,
                  @nPackQty,
                  @nCartonNo,
                  @cLangCode,
                  @nErrNo          OUTPUT,
                  @cErrMsg         OUTPUT  

               IF @nErrNo <> 0 
               BEGIN
                  GOTO RollBackTran
               END   
            END
            ELSE  -- Normal Packing
            BEGIN
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
                        SET @nErrNo = 117660
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPHdrFail'
                        GOTO RollBackTran
                     END 
                  END

                  SET @nCartonNo = 0

                  INSERT INTO dbo.PackDetail
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC)
                  VALUES
                     (@cPickSlipNo, 0, @cDropID, '00000', @cStorerKey, @cSku, @nPackQty,
                     @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID, @cUCC)

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 117661
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
                     GOTO RollBackTran
                  END 
               END -- DropID not exists
               ELSE
               BEGIN
                  SET @nCartonNo = 0

                  SET @cLabelNo = ''

                  SELECT @nCartonNo = CartonNo, @cLabelNo = LabelNo 
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE Pickslipno = @cPickSlipNo
                     AND StorerKey = @cStorerKey
                     AND DropID = @cDropID

                  IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                        AND PickSlipNo = @cPickSlipNo
                        AND DropID = @cDropID
                        AND SKU = @cSKU
                        AND UPC = @cUCC)
                  BEGIN
                     SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                     FROM dbo.PackDetail WITH (NOLOCK)
                     WHERE Pickslipno = @cPickSlipNo
                        AND CartonNo = @nCartonNo
                        AND DropID = @cDropID

                     INSERT INTO dbo.PackDetail
                        (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC)
                     VALUES
                        (@cPickSlipNo, @nCartonNo, @cDropID, @cLabelLine, @cStorerKey, @cSku, @nPackQty,
                        @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID, @cUCC)

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 117662
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
                        GOTO RollBackTran
                     END 
                  END   -- DropID exists but UPC not exists (insert new line with same cartonno)
                  ELSE 
                  BEGIN
                  IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                        AND PickSlipNo = @cPickSlipNo
                        AND DropID = @cDropID
                        AND SKU = @cSKU)
                     BEGIN
                        SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                        FROM dbo.PackDetail WITH (NOLOCK)
                        WHERE Pickslipno = @cPickSlipNo
                           AND CartonNo = @nCartonNo
                           AND DropID = @cDropID

                        INSERT INTO dbo.PackDetail
                           (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC)
                        VALUES
                           (@cPickSlipNo, @nCartonNo, @cDropID, @cLabelLine, @cStorerKey, @cSku, @nPackQty,
                           @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID, @cUCC)

                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 117662
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
                           AND UPC = CASE WHEN ISNULL( @cUCC, '') = '' THEN UPC ELSE @cUCC END
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 117663
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
                           GOTO RollBackTran
                        END
                     END
                  END   -- DropID, UPC exists and SKU exists (update qty only)
               END
            END
         END

         -- (james10)
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                        WHERE DropID = @cDropID) OR 
            -- If dropid not exists then need create new dropid.  (james11)
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

         IF @cClusterPickUpdLabelNoToCaseID = '1'
         BEGIN
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               CaseID = CASE WHEN ISNULL( @cDropID, '') = '' THEN CaseID ELSE @cDropID END,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 117664
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdCaseID Fail'
               GOTO RollBackTran
            END
         END

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

      IF @cAuthority = '1' AND @cUCC <> ''
      BEGIN
         UPDATE dbo.UCC WITH (ROWLOCK) SET 
            [Status] = '6'
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC
         AND   [Status] <> '6'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 58218
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD UCC Fail'
            GOTO RollBackTran
         END
      END

      -- Stamp RPL's candidate to '5'
      UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
         Status = '5'   -- Picked
      WHERE RowRef = @nRowRef

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 117665
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKLockFail'
         GOTO RollBackTran
      END

      FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @nCartonNo, @cUCC
   END
   CLOSE curRPL
   DEALLOCATE curRPL

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN Cluster_Pick_ConfirmTask

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN Cluster_Pick_ConfirmTask

   Fail:
END

GO