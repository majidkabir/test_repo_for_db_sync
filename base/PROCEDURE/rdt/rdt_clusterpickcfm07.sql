SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_ClusterPickCfm07                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Cluster Pick Comfirm Pick SP.                               */
/*          1. Insert/Update PackInfo with carton type                  */
/*          2. Split PackDetail line with case count. 1 line = 1 case   */
/*          3. Update PickDetail.CaseID = PAckDetail.LabelNo for uom 2  */
/*          4. Print label once sku allocated in loc finish picked      */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 19-Jul-2017 1.0  James       WMS2447.Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_ClusterPickCfm07] (
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

   DECLARE  @bsuccess   INT,
            @cUserName  NVARCHAR( 20), 
   @n_err              INT,
   @c_errmsg           NVARCHAR( 250),
   @cPickDetailKey     NVARCHAR( 10),
   @nPickQty           INT,
   @nQTY_PD            INT,
   @nRowRef            INT,
   @nTranCount         INT,
   @nPackQty           INT,
   @nPack2Qty          INT,
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
   @cRoute             NVARCHAR( 20), 
   @cOrderRefNo        NVARCHAR( 18), 
   @nT_CartonNo        INT, 
   @nLoop              INT,
   @nDropIDExists      INT,
   @nGenUCCLabelNo     INT,
   @fCaseCount         FLOAT,
   @fCube              FLOAT, 
   @fWeight            FLOAT,
   @fCtnWeight         FLOAT,   
   @cCaseCount         NVARCHAR( 10), 
   @cCube              NVARCHAR( 10), 
   @cWeight            NVARCHAR( 10), 
   @cT_LabelLine       NVARCHAR( 5), 
   @cDropID_SKU        NVARCHAR( 20),  
   @cPrefUOM           NVARCHAR( 10),   
   @cCaseID            NVARCHAR( 20),    
   @cDataWindow        NVARCHAR( 50),
   @cTargetDB          NVARCHAR( 20),  
   @cLabelPrinter      NVARCHAR( 10),  
   @nTtl_PackQty       INT, 
   @nCaseCount         INT, 
   @nCountSKU          INT,  
   @nSum_DropID        INT, 
   @nQty2Offset        INT

   SELECT @cUserName = UserName, @cPrefUOM = V_UOM FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

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

   IF rdt.RDTGetConfig( @nFunc, 'ClusterPickCaptureCtnType', @cStorerKey) IN ('', '0')
      SET @cCartonType = ''

   SET @nGenUCCLabelNo = 0
   -- If storer config GenUCCLabelNoConfig turned on
   IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)
              WHERE StorerKey = @cStorerKey
              AND   ConfigKey = 'GenUCCLabelNoConfig'
              AND   SValue = '1')
      SET @nGenUCCLabelNo = 1


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

   SELECT @cUOM = RTRIM(PACK.PACKUOM3), 
          @fCaseCount = PACK.CaseCnt
   FROM dbo.PACK PACK WITH (NOLOCK)
   JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   WHERE SKU.Storerkey = @cStorerKey
   AND   SKU.SKU = @cSKU

   SET @cCaseCount = rdt.rdtFormatFloat( @fCaseCount)
   SET @nCaseCount = @cCaseCount

   IF ISNULL( @nCaseCount, 0) <= 0
   BEGIN
      SET @nErrNo = 112711
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Casecnt = 0'
      GOTO RollBackTran
   END                  
                     
   SET @cCartonType = ''

   -- Get RDT.RDTPickLock candidate to offset
   DECLARE curRPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRef, DropID, PickQty, ID, ISNULL( PackKey, '')
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
   FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @nCartonNo, @cCartonType
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @nPackQty = @nPickQty

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
         AND UOM = @cPrefUOM
      ORDER BY PickDetailKey
      OPEN curPD
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @nPickPackQty = @nQTY_PD -- (ChewKP02)        

         IF @nPickQty = 0
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = CASE WHEN ISNULL(@cLoadDefaultPickMethod, '') = 'C' AND @cStatus = '4' THEN '' ELSE @cDropID END,
               CartonType = @cCartonType, 
               Status = @cStatus
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 112701
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END
            ELSE
            BEGIN
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
               CartonType = @cCartonType, 
               Status = @cStatus
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 112702
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END
            ELSE
            BEGIN
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
               CartonType = @cCartonType,                
               Status = '5'
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 112703
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
                  @bsuccess          OUTPUT,
                  @n_err             OUTPUT,
                  @c_errmsg          OUTPUT

               IF @bsuccess <> 1
               BEGIN
                  SET @nErrNo = 112704
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
                  SET @nErrNo = 112705
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
                  SET @nErrNo = 112706
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  DropID = @cDropID,
                  CartonType = @cCartonType,                   
                  Status = '5'
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 112707
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

      IF rdt.RDTGetConfig( @nFunc, 'ClusterPickInsPackDt', @cStorerKey) = '1' AND @nPackQty > 0
      BEGIN
         --SET @nPackQty = @nPickPackQty 

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

         IF (@nTotalPackedQty + @nPackQty) > @nTotalPickedQty -- (ChewKP02)
         BEGIN
            SET @nErrNo = 112708
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Overpacked'
            --SET @cErrMsg = CAST( @nTotalPackedQty AS NVARCHAR( 3)) + '|' + CAST( @nPackQty AS NVARCHAR( 3)) + '|' + CAST( @nTotalPickedQty AS NVARCHAR( 3)) + '|' + @cSKU
            GOTO RollBackTran
         END

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
               SET @nErrNo = 112709
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPHdrFail'
               GOTO RollBackTran
            END 
         END

         IF @nPackQty < @nCaseCount
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND   PickSlipNo = @cPickSlipNo
                        AND   DropID = @cDropID
                        AND   SKU = @cSKU)
            BEGIN
               SELECT TOP 1 
                  @nCartonNo = CartonNo, 
                  @cLabelNo = LabelNo,
                  @cLabelLine = LabelLine 
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   PickSlipNo = @cPickSlipNo
               AND   DropID = @cDropID
               AND   SKU = @cSKU

               SET @nPack2Qty = @nPackQty
               SET @nPackQty = 0

               UPDATE dbo.PackDetail WITH (ROWLOCK) SET
                  QTY = QTY + @nPack2Qty
               WHERE PickSlipNo = @cPickSlipNo
               AND   CartonNo = @nCartonNo
               AND   LabelNo = @cLabelNo
               AND   LabelLine = @cLabelLine

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 112710
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
                  GOTO RollBackTran
               END 
            END  
            ELSE
            BEGIN
               SELECT @nCountSKU = COUNT( DISTINCT SKU) 
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   PickSlipNo = @cPickSlipNo
               AND   DropID = @cDropID

               IF @nCountSKU = 1
               BEGIN
                  SELECT @cDropID_SKU = SKU, 
                         @nSum_DropID = ISNULL( SUM( QTY), 0)
                  FROM dbo.PackDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND   PickSlipNo = @cPickSlipNo
                  AND   DropID = @cDropID
                  GROUP BY SKU

                  SELECT @fCaseCount = PACK.CaseCnt
                  FROM dbo.PACK PACK WITH (NOLOCK)
                  JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
                  WHERE SKU.Storerkey = @cStorerKey
                  AND   SKU.SKU = @cDropID_SKU

                  -- Current dropid already is a full carton, cannot use same dropid
                  --IF @nSum_DropID / @fCaseCount = 1
                  --BEGIN
                  --   SET @nErrNo = 55369
                  --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropID In Use'
                  --   GOTO RollBackTran
                  --END                    
               END
            END
         END   -- @nPackQty < @nCaseCount
         --ELSE
         --IF @nPackQty = @nCaseCount
         --BEGIN
         --   IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
         --               WHERE StorerKey = @cStorerKey
         --               AND   PickSlipNo = @cPickSlipNo
         --               AND   DropID = @cDropID)
         --   BEGIN
         --      SET @nErrNo = 55361
         --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropidInUse'
         --      GOTO RollBackTran
         --   END                    
         --END   -- @nPackQty = @nCaseCount
         --ELSE
         --IF @nPackQty > @nCaseCount
         --BEGIN
         --   IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
         --               WHERE StorerKey = @cStorerKey
         --               AND   PickSlipNo = @cPickSlipNo
         --               AND   DropID = @cDropID)
         --   BEGIN
         --      SET @nErrNo = 55362
         --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropidInUse'
         --      GOTO RollBackTran
         --   END                                
         --END   -- @nPackQty > @nCaseCount
         
         WHILE @nPackQty > 0
         BEGIN        
            --Ins packdetail
            SET @nCartonNo = 0
            SET @cLabelNo = ''
            SET @bsuccess = 1
            SET @nErrNo = 0

            IF @nPackQty < @nCaseCount
            BEGIN
               SELECT TOP 1 
                  @nCartonNo = CartonNo, 
                  @cLabelNo = LabelNo,
                  @cLabelLine = LabelLine 
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   PickSlipNo = @cPickSlipNo
               AND   DropID = @cDropID

               IF @nCartonNo > 0
                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)    
                  FROM PACKDETAIL WITH (NOLOCK)    
                  WHERE StorerKey = @cStorerKey
                  AND   PickSlipNo = @cPickSlipNo
                  AND   DropID = @cDropID
               ELSE
               BEGIN
                  IF @nGenUCCLabelNo = 1
                  BEGIN
                     EXEC RDT.rdt_GenUCCLabelNo
                        @cStorerKey = @cStorerKey,
                        @nMobile    = @nMobile,
                        @cLabelNo   = @cLabelNo    OUTPUT,
                        @cLangCode  = @cLangCode,
                        @nErrNo     = @nErrNo      OUTPUT,
                        @cErrMsg    = @cErrMsg     OUTPUT 

                     IF @nErrNo <> 0
                        SET @bsuccess = -1
                  END
                  ELSE
                  BEGIN
                     EXECUTE dbo.nsp_GenLabelNo
                        '',
                        @cStorerKey,
                        @c_labelno     = @cLabelNo  OUTPUT,
                        @n_cartonno    = @nCartonNo OUTPUT,
                        @c_button      = '',
                        @b_success     = @bsuccess  OUTPUT,
                        @n_err         = @nErrNo    OUTPUT,
                        @c_errmsg      = @cErrMsg   OUTPUT
                  END 
               END               
            END
            ELSE
            BEGIN
               IF @nGenUCCLabelNo = 1
               BEGIN
                  EXEC RDT.rdt_GenUCCLabelNo
                     @cStorerKey = @cStorerKey,
                     @nMobile    = @nMobile,
                     @cLabelNo   = @cLabelNo    OUTPUT,
                     @cLangCode  = @cLangCode,
                     @nErrNo     = @nErrNo      OUTPUT,
                     @cErrMsg    = @cErrMsg     OUTPUT 

                  IF @nErrNo <> 0
                     SET @bsuccess = -1
               END
               ELSE
               BEGIN
                  EXECUTE dbo.nsp_GenLabelNo
                     '',
                     @cStorerKey,
                     @c_labelno     = @cLabelNo  OUTPUT,
                     @n_cartonno    = @nCartonNo OUTPUT,
                     @c_button      = '',
                     @b_success     = @bsuccess  OUTPUT,
                     @n_err         = @nErrNo    OUTPUT,
                     @c_errmsg      = @cErrMsg   OUTPUT
               END
            END

            IF @bsuccess <> 1
            BEGIN
               SET @nErrNo = 112713
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'
               GOTO RollBackTran
            END

            IF @nCaseCount > @nPackQty
            BEGIN
               SET @nPack2Qty = @nPackQty
               SET @nPackQty = 0
            END
            ELSE
            BEGIN
               SET @nPack2Qty = @nCaseCount
               SET @nPackQty = @nPackQty - @nPack2Qty
            END
            
            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
            VALUES
               (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nPack2Qty,
               @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 112714
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
               GOTO RollBackTran
            END                      

            IF @cCartonType <> ''
            BEGIN
               SELECT TOP 1 @nCartonNo = CartonNo, @nTtl_PackQty = ISNULL( SUM( Qty), 0)
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE PickSlipNo = @cPickSlipNo
               AND   LabelNo = @cLabelNo
               AND   StorerKey = @cStorerKey
               GROUP BY CartonNo
                  
               SELECT @fCube = [Cube], 
                      @fCtnWeight = CartonWeight 
               FROM dbo.Cartonization CZ WITH (NOLOCK)
               JOIN Storer ST WITH (NOLOCK) ON CZ.CartonizationGroup = ST.CartonGroup
               WHERE StorerKey = @cStorerKey
               AND   CartonType = @cCartonType 

               SELECT @fWeight = STDGrossWGT 
               FROM dbo.SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   SKU = @cSKU

               SET @cCube = rdt.rdtFormatFloat( @fCube)

               SET @cWeight = ( @nTtl_PackQty * @fWeight) + @fCtnWeight
               SET @cWeight = rdt.rdtFormatFloat( @cWeight)
                  
               IF EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                           WHERE PickSlipNo = @cPickSlipNo
                           AND   CartonNo = @nCartonNo)                  
               BEGIN
                  UPDATE dbo.PackInfo WITH (ROWLOCK) SET
                     CartonType = CASE WHEN ISNULL( CartonType, '') = '' THEN @cCartonType ELSE CartonType END,
                     [Cube] = CASE WHEN [Cube] IS NULL THEN @cCube ELSE [Cube] END,
                     Weight = Weight + (@nTtl_PackQty * @fWeight),
                     EditDate = GETDATE(),
                     EditWho = 'rdt.' + sUser_sName()
                  WHERE PickSlipNo = @cPickSliPno
                  AND CartonNo = @nCartonNo
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 112715
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackInfoFail'
                     GOTO RollBackTran
                  END                  
               END
               ELSE
               BEGIN
                  INSERT INTO dbo.PACKINFO
                  (PickSlipNo, CartonNo, CartonType, [Cube], Weight)
                  VALUES
                  (@cPickSlipNo, @nCartonNo, @cCartonType, @cCube, @cWeight)

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 112716
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackInfoFail'
                     GOTO RollBackTran
                  END                  
               END          
            END   -- @cCartonType <> ''           
         END   -- While @nPackQty > 0
      END

      -- Stamp RPL's candidate to '5'
      UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
         Status = '5'   -- Picked
      WHERE RowRef = @nRowRef

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 112717
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKLockFail'
         GOTO RollBackTran
      END

      FETCH NEXT FROM curRPL INTO @nRowRef, @cDropID, @nPickQty, @nCartonNo, @cCartonType
   END
   CLOSE curRPL
   DEALLOCATE curRPL

   DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT DISTINCT LABELNO, SUM( Qty) FROM dbo.PackDetail PAD WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
   AND   SKU = @cSKU
   AND   DropID = ''
   AND   NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PID WITH (NOLOCK) 
                     WHERE PAD.StorerKey = PID.StorerKey 
                     AND   PAD.SKU = PID.SKU 
                     AND   PAD.LabelNo = PID.CaseID
                     AND   PID.OrderKey = @cOrderKey
                     AND   PID.DropID = '')
   GROUP BY LabelNo
   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @cLabelNo, @nQty2Offset
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DECLARE CUR_LOOP1 CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PickDetailKey, Qty
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerkey
      AND   OrderKey = @cOrderKey
      AND   LOC = @cLOC
      AND   SKU = @cSKU
      AND   Status = '5'
      AND   UOM = @cPrefUOM
      AND   CASEID = ''
      OPEN CUR_LOOP1
      FETCH NEXT FROM CUR_LOOP1 INTO @cPickDetailKey, @nQty_PD
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Exact match
         IF @nQTY_PD = @nQty2Offset
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               CaseID = @cLabelNo
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 112702
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            SET @nQty2Offset = @nQty2Offset - @nQTY_PD -- Reduce balance -- SOS# 176144
         END
         -- PickDetail have less
         ELSE IF @nQTY_PD < @nQty2Offset
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               CaseID = @cLabelNo
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 112703
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            SET @nQty2Offset = @nQty2Offset - @nQTY_PD -- Reduce balance
         END
         -- PickDetail have more, need to split
         ELSE IF @nQTY_PD > @nQty2Offset
         BEGIN
            IF @nQty2Offset > 0 -- SOS# 176144
            BEGIN
               -- If Status = '5' (full pick), split line if neccessary
               -- If Status = '4' (short pick), no need to split line if already last RPL line to update,
               -- just have to update the pickdetail.qty = short pick qty
               -- Get new PickDetailkey
               --DECLARE @cNewPickDetailKey NVARCHAR( 10)
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @cNewPickDetailKey OUTPUT,
                  @bsuccess          OUTPUT,
                  @n_err             OUTPUT,
                  @c_errmsg          OUTPUT

               IF @bsuccess <> 1
               BEGIN
                  SET @nErrNo = 112704
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
                  Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                  @nQTY_PD - @nQty2Offset, -- QTY
                  NULL, --TrafficCop,
                  '1'  --OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 112705
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'
                  GOTO RollBackTran
               END

               -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nQty2Offset,
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 112706
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  CaseID = @cLabelNo
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 112707
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               SET @nQty2Offset = 0 -- Reduce balance
            END
         END         

         IF @nQty2Offset = 0 
         BEGIN
            BREAK 
         END

         FETCH NEXT FROM CUR_LOOP1 INTO @cPickDetailKey, @nQty_PD
      END
      CLOSE CUR_LOOP1
      DEALLOCATE CUR_LOOP1
      FETCH NEXT FROM CUR_LOOP INTO @cLabelNo, @nQty2Offset
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP


   IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                   WHERE Storerkey = @cStorerkey
                   AND   LOC = @cLOC
                   AND   OrderKey = @cOrderKey
                   AND   Status = '0'
                   AND   UOM = '2')
   BEGIN
      -- Get login info
      SELECT @cLabelPrinter = Printer
      FROM rdt.rdtMobrec WITH (NOLOCK) 
      WHERE Mobile = @nMobile

      -- Get report info
      SET @cDataWindow = ''
      SET @cTargetDB = ''
      SELECT 
         @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
         @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
      FROM RDT.RDTReport WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   ReportType = 'DISPLABEL'
      AND   ( Function_ID = @nFunc OR Function_ID = 0)

      -- Check data window
      IF ISNULL( @cDataWindow, '') = ''
      BEGIN
         SET @nErrNo = 112718
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
         GOTO RollBackTran
      END
   
      -- Check database
      IF ISNULL( @cTargetDB, '') = ''
      BEGIN
         SET @nErrNo = 112719
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
         GOTO RollBackTran
      END

      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT CaseID 
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE Storerkey = @cStorerkey
      AND   LOC = @cLOC
      AND   OrderKey = @cOrderKey
      AND   Status = '5'
      AND   ISNULL( CASEID, '') <> ''
      AND   UOM = '2'
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cCaseID
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT TOP 1 @nCartonNo = CartonNo
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
         AND   LabelNo = @cCaseID

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 112720
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Pack Record
            GOTO RollBackTran
         END

         EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorerKey,
            'DISPLABEL',       -- ReportType
            'PRINT_DISPLABEL', -- PrintJobName
            @cDataWindow,
            @cLabelPrinter,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT, 
            @cStorerKey,
            @cPickSlipNo, 
            @nCartonNo,    -- Start CartonNo
            @nCartonNo     -- End CartonNo

         FETCH NEXT FROM CUR_LOOP INTO @cCaseID
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN Cluster_Pick_ConfirmTask

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN Cluster_Pick_ConfirmTask

END

GO