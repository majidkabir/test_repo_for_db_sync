SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_834ExtPack02                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick and pack confirm                                       */
/*                                                                      */
/* Called from: rdtfnc_CartonPack                                       */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2019-05-29   1.0  James    WMS9146. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_834ExtPack02] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5), 
   @tCfmPack         VariableTable READONLY, 
   @cPrintPackList   NVARCHAR( 1)   OUTPUT,
   @cPickSlipNo      NVARCHAR( 10)  OUTPUT,
   @nCartonNo        INT            OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT
   DECLARE @cUOM           NVARCHAR( 10)
   DECLARE @cZone          NVARCHAR( 10)
   DECLARE @cPH_LoadKey    NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @nQTY_PD        INT
   DECLARE @bSuccess       INT
   DECLARE @n_err          INT
   DECLARE @c_errmsg       NVARCHAR( 20)
   DECLARE @cShipperKey    NVARCHAR( 15)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cRoute         NVARCHAR( 20)
   DECLARE @cOrderRefNo    NVARCHAR( 18)
   DECLARE @cConsigneekey  NVARCHAR( 15)
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @nRowCount      INT
   DECLARE @cShipLabel     NVARCHAR( 10)
   DECLARE @cDelNotes      NVARCHAR( 10)
   DECLARE @cPaperPrinter  NVARCHAR( 10)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @nQty           INT
   DECLARE @nPicked        INT
   DECLARE @nPacked        INT
   DECLARE @nSum_Picked    INT
   DECLARE @nSum_Packed    INT
   DECLARE @cGenLabelNo_SP NVARCHAR( 20)
   DECLARE @cDocLabel      NVARCHAR( 20)
   DECLARE @cDocValue      NVARCHAR( 20)
   DECLARE @cCtnLabel      NVARCHAR( 20)
   DECLARE @cCtnValue      NVARCHAR( 20)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cPrintShipLbl  NVARCHAR( 60)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cUpdateSource  NVARCHAR( 10) 
   DECLARE @cUpdatePickDetail NVARCHAR( 1)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cOrderLineNumber  NVARCHAR( 5)
   DECLARE @cPackConfirm      NVARCHAR(1)
   DECLARE @tGenLabelNo    VARIABLETABLE
   DECLARE @nStep          INT
   DECLARE @nInputKey      INT

   SET @nErrNo = 0
   SET @cPrintPackList = 'N'
   SET @cPackConfirm = ''

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Variable mapping
   SELECT @cDocLabel = Value FROM @tCfmPack WHERE Variable = '@cDocLabel'
   SELECT @cDocValue = Value FROM @tCfmPack WHERE Variable = '@cDocValue'
   SELECT @cCtnLabel = Value FROM @tCfmPack WHERE Variable = '@cCtnLabel'
   SELECT @cCtnValue = Value FROM @tCfmPack WHERE Variable = '@cCtnValue'



   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_834ExtPack02

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerKey) 
   IF @cGenLabelNo_SP = '0'
      SET @cGenLabelNo_SP = ''  

   SET @cUpdatePickDetail = rdt.RDTGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey) 

   SELECT TOP 1 @cOrderKey = OrderKey
   FROM dbo.PickDetail PD WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   DropID = @cCtnValue
   ORDER BY 1

   SELECT @cLoadkey = LoadKey, 
          @cShipperKey = ShipperKey,
          @cUpdateSource = UpdateSource
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   SET @cPickSlipNo = ''  
   SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  

   IF @cPickSlipNo = ''  
      SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey  

   IF ISNULL( @cPickSlipNo, '') = ''
   BEGIN
      SET @nErrNo = 139451
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --PickSlip req
      GOTO RollBackTran  
   END

   SELECT @cZone = Zone, 
          @cLoadKey = ExternOrderKey,
          @cOrderKey = OrderKey
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo  

   SELECT @nQty = ISNULL( SUM( Qty), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   DropID = @cCtnValue
   AND   Status <> '4'
   AND   Status < @cPickConfirmStatus

   DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PickDetailKey, SKU, Qty
   FROM dbo.PickDetail PD WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   DropID = @cCtnValue
   AND   Status <> '4'
   AND   Status < @cPickConfirmStatus
   ORDER BY 1
   OPEN curPD
   FETCH NEXT FROM curPD INTO @cPickDetailKey, @cSKU, @nQTY_PD
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF @cUpdatePickDetail = '1'
      BEGIN
            -- Exact match
         IF @nQTY_PD = @nQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = @cPickConfirmStatus
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 139452
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            SET @nQty = @nQty - @nQTY_PD -- Reduce balance
         END
         -- PickDetail have less
         ELSE IF @nQTY_PD < @nQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = @cPickConfirmStatus
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 139453
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END
            ELSE

            SET @nQty = @nQty - @nQTY_PD -- Reduce balance
         END
         -- PickDetail have more, need to split
         ELSE IF @nQTY_PD > @nQty
         BEGIN
            DECLARE @cNewPickDetailKey NVARCHAR( 10)
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @n_err             OUTPUT,
               @c_errmsg          OUTPUT

            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 139454
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
               @nQTY_PD - @nQty, -- QTY
               NULL, --TrafficCop,
               '1'  --OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 139455
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'
               GOTO RollBackTran
            END

            IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
            BEGIN
               SELECT @cOrderLineNumber = OrderLineNumber
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey

               INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)  
               VALUES (@cNewPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 139456  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail  
                  GOTO RollBackTran  
               END  
            END

            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nQty,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 139457
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = @cPickConfirmStatus
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 139458
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            SET @nQty = 0 -- Reduce balance
         END
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
            SET @nErrNo = 139459
            SET @cErrMsg = rdt.rdtgetmessage( 66040, @cLangCode, 'DSP') --'InsPackHdrFail'
            GOTO RollBackTran
         END 
      END

      -- Same DropID + PickSlipNo will group SKU into a carton. 1 carton could be multi sku
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
         AND   DropID = @cCtnValue)
      BEGIN
         SET @nCartonNo = 0

         SET @cLabelNo = ''

         SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerkey)
         IF @cGenLabelNo_SP = '0'
            SET @cGenLabelNo_SP = ''
         
         IF @cGenLabelNo_SP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')  
            BEGIN
               INSERT INTO @tGenLabelNo (Variable, Value) VALUES 
               ('@cPickSlipNo',     @cPickSlipNo),
               ('@cDropID',         @cCtnValue)

               SET @nErrNo = 0
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenLabelNo_SP) +     
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
                  ' @tGenLabelNo, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

               SET @cSQLParam =    
                  '@nMobile                   INT,           ' +
                  '@nFunc                     INT,           ' +
                  '@cLangCode                 NVARCHAR( 3),  ' +
                  '@nStep                     INT,           ' +
                  '@nInputKey                 INT,           ' +
                  '@cFacility                 NVARCHAR( 5),  ' +
                  '@cStorerkey                NVARCHAR( 15), ' +
                  '@tGenLabelNo               VARIABLETABLE READONLY, ' +
                  '@cLabelNo                  NVARCHAR( 20) OUTPUT, ' +
                  '@nCartonNo                 INT           OUTPUT, ' +
                  '@nErrNo                    INT           OUTPUT, ' +
                  '@cErrMsg                   NVARCHAR( 20) OUTPUT  ' 
               
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                  @tGenLabelNo, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            END
         END
         ELSE
         BEGIN   
            EXECUTE dbo.nsp_GenLabelNo
               @c_orderkey    = '',
               @c_storerkey   = @cStorerKey,
               @c_labelno     = @cLabelNo    OUTPUT,
               @n_cartonno    = @nCartonNo   OUTPUT,
               @c_button      = '',
               @b_success     = @bSuccess    OUTPUT,
               @n_err         = @nErrNo      OUTPUT,
               @c_errmsg      = @cErrMsg     OUTPUT

            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 139460
               SET @cErrMsg = rdt.rdtgetmessage( 66038, @cLangCode, 'DSP') --'GenLabelFail'
               GOTO Quit
            END
         END

         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
         VALUES
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU, @nQTY_PD,
            @cCtnValue, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 139461
            SET @cErrMsg = rdt.rdtgetmessage( 66035, @cLangCode, 'DSP') --'InsPackDtlFail'
            GOTO RollBackTran
         END 

         -- 1 label 1 carton no
         SELECT TOP 1 @nCartonNo = CartonNo
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
         AND   LabelNo = @cLabelNo
         ORDER BY 1 
      END 
      ELSE  -- DropID not exists
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                        WHERE PickSlipNo = @cPickSlipNo
                        AND   DropID = @cCtnValue
                        AND    SKU = @cSKU)
         BEGIN
            SET @nCartonNo = 0

            SET @cLabelNo = ''

            SELECT @nCartonNo = CartonNo, 
                   @cLabelNo = LabelNo 
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND StorerKey = @cStorerKey
               AND DropID = @cCtnValue

            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND DropID = @cCtnValue

            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)
            VALUES
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nQTY_PD,
               @cCtnValue, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 139469
               SET @cErrMsg = rdt.rdtgetmessage( 66036, @cLangCode, 'DSP') --'InsPackDtlFail'
               GOTO RollBackTran
            END 
         END
         ELSE
         BEGIN
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET
               QTY = QTY + @nQTY_PD,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo
            AND   DropID = @cCtnValue
            AND   SKU = @cSKU

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 139462
               SET @cErrMsg = rdt.rdtgetmessage( 66037, @cLangCode, 'DSP') --'UpdPackDtlFail'
               GOTO RollBackTran
            END
         END
      END   -- DropID exists and SKU exists (update qty only)

      -- PackInfo
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
      BEGIN
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, UCCNo, QTY)
         VALUES (@cPickSlipNo, @nCartonNo, @cCtnValue, @nQTY_PD)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 139463
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         SELECT TOP 1 @nCartonNo = CartonNo 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
         AND   DropID = @cCtnValue
         AND   SKU = @cSKU
         ORDER BY 1

         UPDATE dbo.PackInfo SET
            UCCNo = @cDocValue, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 139464
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
            GOTO RollBackTran
         END
      END

      IF @cUpdatePickDetail = '1' AND @nQty = 0
         BREAK

      FETCH NEXT FROM curPD INTO @cPickDetailKey, @cSKU, @nQTY_PD
   END
   CLOSE curPD
   DEALLOCATE curPD

   SET @nSum_Packed = 0
   SELECT @nSum_Packed = ISNULL( SUM( Qty), 0)
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE PickSlipNo = @cPickSlipNo

   SET @nSum_Picked = 0

   -- conso picklist   
   If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' 
   BEGIN    
      -- Check outstanding PickDetail
      IF EXISTS( SELECT TOP 1 1
                 FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                 JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                 WHERE RKL.PickSlipNo = @cPickSlipNo
                 AND   PD.Status < '5'
                 AND    PD.QTY > 0
                 AND   (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
         SET @cPackConfirm = 'N'
      ELSE
         SET @cPackConfirm = 'Y'

      -- Check fully packed
      IF @cPackConfirm = 'Y'
      BEGIN
         SELECT @nSum_Picked = SUM( QTY) 
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
         WHERE RKL.PickSlipNo = @cPickSlipNo
         
         IF @nSum_Picked <> @nSum_Packed
            SET @cPackConfirm = 'N'
      END

      SELECT @nPicked = ISNULL( SUM( QTY), 0)
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
      WHERE RKL.PickSlipNo = @cPickSlipNo
      AND   PD.StorerKey = @cStorerKey
      AND   PD.Status = @cPickConfirmStatus
      AND   PD.DropID = @cCtnValue
   END
   -- Discrete PickSlip
   ELSE IF ISNULL(@cOrderKey, '') <> '' 
   BEGIN
      -- Check outstanding PickDetail
      IF EXISTS( SELECT TOP 1 1
                 FROM dbo.PickDetail PD WITH (NOLOCK)
                 WHERE PD.OrderKey = @cOrderKey
                 AND   PD.Status < '5'
                 AND   PD.QTY > 0
                 AND  (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
         SET @cPackConfirm = 'N'
      ELSE
         SET @cPackConfirm = 'Y'
      
      -- Check fully packed
      IF @cPackConfirm = 'Y'
      BEGIN
         SELECT @nSum_Picked = SUM( PD.QTY) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         WHERE PD.OrderKey = @cOrderKey
         
         IF @nSum_Picked <> @nSum_Packed
            SET @cPackConfirm = 'N'
      END

      SELECT @nPicked = ISNULL( SUM( QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      WHERE PD.OrderKey = @cOrderKey
      AND   PD.StorerKey = @cStorerKey
      AND   PD.Status = @cPickConfirmStatus
      AND   PD.DropID = @cCtnValue
   END
   ELSE
   BEGIN
      -- Check outstanding PickDetail
      IF EXISTS( SELECT TOP 1 1 
                 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                 JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                 WHERE LPD.LoadKey = @cLoadKey
                 AND   PD.Status < '5'
                 AND   PD.QTY > 0
                 AND  (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
         SET @cPackConfirm = 'N'
      ELSE
         SET @cPackConfirm = 'Y'
      
      -- Check fully packed
      IF @cPackConfirm = 'Y'
      BEGIN
         SELECT @nSum_Picked = SUM( PD.QTY) 
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
         WHERE LPD.LoadKey = @cLoadKey
         
         IF @nSum_Picked <> @nSum_Packed
            SET @cPackConfirm = 'N'
      END

      SELECT @nPicked = ISNULL( SUM( QTY), 0)
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
      JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
      WHERE LPD.LoadKey = @cLoadKey
      AND   PD.StorerKey = @cStorerKey
      AND   PD.Status = @cPickConfirmStatus
      AND   PD.DropID = @cCtnValue
   END

   IF @nPacked = @nPicked
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE PickSlipNo = @cPickSlipNo
                      AND   DropID = @cCtnValue
                      AND   RefNo2 = '1')
      BEGIN
         UPDATE dbo.PackDetail WITH (ROWLOCK) SET 
            RefNo2 = '1'
         WHERE PickSlipNo = @cPickSlipNo
         AND   DropID = @cCtnValue
         AND   RefNo2 = ''

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 139465
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
            GOTO RollBackTran
         END
      END
   END

   -- Pack confirm
   IF @cPackConfirm = 'Y'
   BEGIN
      SET @cPrintPackList = 'Y'

      UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
         [Status] = '9'
      WHERE PickSlipNo = @cPickSlipNo
      AND   [Status] < '9'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 139466
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
         GOTO RollBackTran
      END

      SET @nErrNo = 0
      EXEC isp_ScanOutPickSlip
         @c_PickSlipNo  = @cPickSlipNo,
         @n_err         = @nErrNo OUTPUT,
         @c_errmsg      = @cErrMsg OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 139467
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan Out Fail
         GOTO RollBackTran
      END

      EXEC [dbo].[isp_AssignPackLabelToOrderByLoad]  
         @c_Pickslipno  = @cPickSlipNo,  
         @b_Success     = @bSuccess    OUTPUT,  
         @n_err         = @nErrNo      OUTPUT,  
         @c_errmsg      = @cErrMsg     OUTPUT  
  
      IF @bSuccess <> 1      
      BEGIN      
         SET @nErrNo = 139468      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Assign Lbl Err'      
         GOTO RollBackTran      
      END      
   END


   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_834ExtPack02

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_834ExtPack02

   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
   IF @cShipLabel = '0'
      SET @cShipLabel = ''

   IF @cShipLabel <> ''
   BEGIN
      SELECT @nCartonNo = MAX( CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND   DropID = @cCtnValue

      SET @nErrNo = 0
      DECLARE @tSHIPPLABEL AS VariableTable
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cStorerKey',      @cStorerKey)
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',     @cPickSlipNo)
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nCartonNoFrom',   @nCartonNo)
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nCartonNoTo',     @nCartonNo)
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPrinter',        @cLabelPrinter)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 2, 1, @cFacility, @cStorerkey, @cLabelPrinter, '', 
         @cShipLabel, -- Report type
         @tSHIPPLABEL, -- Report params
         'rdt_834ExtPack02', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT 
   END

   Fail:
END

GO