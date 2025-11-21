SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_547SortPackCfm01                                */  
/* Copyright: LFL                                                       */  
/* Purpose: Lulu Sort And Pack Confirm                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Ver  Author   Purposes                                   */  
/* 2021-03-19  1.0  James    WMS-15660. Created                         */  
/* 2021-08-11  1.1  James    Fix missing orderkey (james01)             */
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_547SortPackCfm01]  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR(3),  
   @cPackByType   NVARCHAR(10),   
   @cLoadKey      NVARCHAR(10),  
   @cOrderKey     NVARCHAR(10),   
   @cConsigneeKey NVARCHAR(15),  
   @cStorerKey    NVARCHAR(15),  
   @cSKU          NVARCHAR(20),  
   @nQTY          INT,   
   @cLabelNo      NVARCHAR(20),  
   @cCartonType   NVARCHAR(10),
   @bSuccess      INT            OUTPUT,
   @nErrNo        INT            OUTPUT,  
   @cErrMsg       NVARCHAR(20)   OUTPUT,   
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
   DECLARE @cAutoPackCfm   NVARCHAR( 1)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @nStep          INT
   DECLARE @nInputKey      INT
   DECLARE @cType          NVARCHAR( 10)
   DECLARE @cPD_SKU        NVARCHAR( 20)
   DECLARE @nIsUCC         INT
   DECLARE @cRoute         NVARCHAR( 10)
   
   SET @nErrNo = 0  
   SET @cErrMsg = ''  
   SET @nPickQTY = @nQTY  
   
   SELECT @cFacility = Facility,
          @nStep = Step,
          @nInputKey = InputKey, 
          @nIsUCC = V_Integer13
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   DECLARE @tPD TABLE   
   (  
      PickDetailKey NVARCHAR(10) NOT NULL,  
      OrderKey      NVARCHAR(10) NOT NULL,  
      ConsigneeKey  NVARCHAR(15) NOT NULL,  
      SKU           NVARCHAR(20) NOT NULL,
      QTY           INT      NOT NULL  
   )  

   DECLARE @tSKU TABLE   
   (  
      SKU           NVARCHAR(20) NOT NULL
   )  

   IF @nIsUCC = 1
      SET @cType = 'UCC'

   IF @nStep = 7
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @cType = 'UCC'
         
         INSERT INTO @tSKU (SKU)
         SELECT DISTINCT PD.SKU
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         WHERE O.LoadKey = @cLoadKey
         AND   PD.StorerKey = @cStorerKey
         AND   PD.DropID = @cUCCNo
         AND   PD.QTY > 0
         AND   PD.Status IN ('3', '5')
         AND   ISNULL(PD.CaseID,'') = ''    
         
         SELECT @nPickQTY = ISNULL( SUM( PD.Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         WHERE O.LoadKey = @cLoadKey
         AND   PD.StorerKey = @cStorerKey
         AND   PD.DropID = @cUCCNo
         AND   PD.QTY > 0
         AND   PD.Status IN ('3', '5')
         AND   ISNULL(PD.CaseID,'') = ''    

      END
   END
   ELSE
      INSERT INTO @tSKU (SKU) VALUES (@cSKU)
      
   SET @cAutoPackCfm = rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
  
/*--------------------------------------------------------------------------------------------------  
  
                                           PickDetail line  
  
--------------------------------------------------------------------------------------------------*/  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_SortAndPack_Confirm  
  
   DECLARE @curPD CURSOR  
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT O.OrderKey, O.ConsigneeKey, PD.PickDetailKey, PD.Sku, PD.QTY  
      FROM dbo.PickDetail PD WITH (NOLOCK)  
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)  
         JOIN @tSKU SKU ON ( PD.Sku = SKU.Sku)
      WHERE LPD.LoadKey = @cLoadKey  
         AND PD.StorerKey = @cStorerKey  
         AND PD.QTY > 0  
         AND PD.[Status] <= '5'
         AND PD.[Status] <> '4'  
         AND PD.CaseID = ''
         AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END
         AND O.ConsigneeKey = @cConsigneeKey  
         AND O.OrderKey = CASE WHEN @cPackByType = 'CONSO' THEN O.OrderKey ELSE @cOrderKey END  
      ORDER BY PD.PickDetailKey  
  
   OPEN @curPD  
   FETCH NEXT FROM @curPD INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @cPD_SKU, @nQTY_PD  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      -- Exact match  
      IF @nQTY_PD = @nPickQty  
      BEGIN  
         -- Confirm PickDetail  
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
            [Status] = CASE WHEN [Status] = '5' THEN [Status] ELSE '5' END,
            CaseID = @cLabelNo,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77401  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
            GOTO RollBackTran  
         END  
  
         INSERT INTO @tPD (PickDetailKey, OrderKey, ConsigneeKey, SKU, QTY) VALUES (@cPickDetailKey, @cOrderKey, @cConsigneeKey, @cPD_SKU, @nQTY_PD)  
         SET @nPickQty = 0 -- Reduce balance  
         BREAK  
      END  
  
      -- PickDetail have less  
      ELSE IF @nQTY_PD < @nPickQty  
      BEGIN  
         -- Confirm PickDetail  
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
            [Status] = CASE WHEN [Status] = '5' THEN [Status] ELSE '5' END,
            CaseID = @cLabelNo,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77402  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
            GOTO RollBackTran  
         END  
  
         INSERT INTO @tPD (PickDetailKey, OrderKey, ConsigneeKey, SKU, QTY) VALUES (@cPickDetailKey, @cOrderKey, @cConsigneeKey, @cPD_SKU, @nQTY_PD)  
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
            SET @nErrNo = 77403  
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
            SET @nErrNo = 77404  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail  
            GOTO RollBackTran  
         END  
  
         -- Change orginal PickDetail with exact QTY (with TrafficCop)  
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
            QTY = @nPickQty,  
            Trafficcop = NULL  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77405  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
            GOTO RollBackTran  
         END  
  
         -- Pick confirm original line  
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
            [Status] = CASE WHEN [Status] = '5' THEN [Status] ELSE '5' END,
            CaseID = @cLabelNo,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77406  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
            GOTO RollBackTran  
         END  
  
         INSERT INTO @tPD (PickDetailKey, OrderKey, ConsigneeKey, SKU, QTY) VALUES (@cPickDetailKey, @cOrderKey, @cConsigneeKey, @cPD_SKU, @nPickQty)  
         SET @nPickQty = 0 -- Reduce balance  
         BREAK  
      END  

      FETCH NEXT FROM @curPD INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @cPD_SKU, @nQTY_PD  
   END  
--select * from @tPD  
   IF @nPickQty <> 0  
   BEGIN  
      SET @nErrNo = 77407  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset Fail  
      GOTO RollBackTran  
   END  
  
/*--------------------------------------------------------------------------------------------------  
  
                                      PackHeader, PackDetail line  
  
--------------------------------------------------------------------------------------------------*/  
   DECLARE @curT CURSOR  
   SET @curT = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT OrderKey, ConsigneeKey, PickDetailKey, SKU, QTY  
      FROM @tPD  
   OPEN @curT  
   FETCH NEXT FROM @curT INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @cPD_SKU, @nQTY_PD  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      -- Get PickSlipNo (PickHeader)  
      IF ISNULL( @cOrderKey, '') = ''
      BEGIN
         SELECT @cOrderKey = OrderKey FROM dbo.PICKDETAIL WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey
         --INSERT INTO traceinfo (TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5) VALUES ('547', GETDATE(), @cOrderKey, @cPickDetailKey, @cLoadKey, @cType, @cPackByType)
      END
      SET @cPickSlipNo = ''  
      SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  
      IF @cPickSlipNo = ''  
         SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey  
      --INSERT INTO traceinfo (TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5, Step1, Step2, Step3) VALUES 
      --('5471', GETDATE(), @cOrderKey, @cPickDetailKey, @cLoadKey, @cType, @cPackByType, @cPickSlipNo, @cLabelNo, @cPD_SKU)
      -- PackHeader  
      IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)  
      BEGIN  
         -- Get PickSlipNo (PackHeader)  
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
               SET @nErrNo = 77408  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail  
               GOTO RollBackTran  
            END  
            SET @cPickSlipNo = 'P' + RTRIM( @cPickSlipNo)  
         END  
  
         SELECT @cRoute = [Route]
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
            
         -- Insert PackHeader  
         INSERT INTO dbo.PackHeader  
            (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, [STATUS])  
         VALUES  
            (@cPickSlipNo, @cStorerkey, @cOrderkey, @cLoadKey, @cRoute, @cConsigneeKey, '', 0, '0')  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77409  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackHdrFail  
            GOTO RollBackTran  
         END  
      END  
  
      -- PackDetail  
      -- Top up to existing carton and SKU  
      IF EXISTS (SELECT 1  
         FROM dbo.PackDetail WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickSlipNo  
            AND LabelNo = @cLabelNo  
            AND StorerKey = @cStorerKey  
            AND SKU = @cPD_SKU)  
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
            AND SKU = @cPD_SKU  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77410  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail  
            GOTO RollBackTran  
         END  
      END  
      ELSE  
      BEGIN  
         -- Create new carton  
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cLabelNo)  
         BEGIN  
/*  
            -- Get new LabelNo  
            EXECUTE isp_GenUCCLabelNo  
               @cStorerKey,  
               @cLabelNo     OUTPUT,  
               @b_Success    OUTPUT,  
               @nErrNo       OUTPUT,  
               @cErrMsg      OUTPUT  
            IF @b_Success <> 1  
            BEGIN  
               SET @nErrNo = 77411  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GET LABEL Fail  
               GOTO RollBackTran  
            END  
*/  
            INSERT INTO dbo.PackDetail  
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)  
            VALUES  
               (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cPD_SKU, @nQTY_PD, -- CartonNo = 0 and LabelLine = '0000', trigger will auto assign  
               @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '')  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 77412  
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
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cPD_SKU, @nQTY_PD,  
               @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '')  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 77413  
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
            SET @nErrNo = 77417  
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
         IF @cAutoPackCfm = '1'
         BEGIN
            -- Trigger pack confirm      
            UPDATE dbo.PackHeader WITH (ROWLOCK) SET       
               STATUS = '9',       
               EditWho = 'rdt.' + sUser_sName(),      
               EditDate = GETDATE()      
            WHERE PickSlipNo = @cPickSlipNo    
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 77414  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail PackCfm  
               GOTO RollBackTran  
            END    

            -- Update packdetail.labelno = pickdetail.caseid
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

            DECLARE @curUpdPack   CURSOR
            DECLARE @curUpdPick   CURSOR
            DECLARE @cTempLabelNo   NVARCHAR( 20)
            DECLARE @cTempDropID    NVARCHAR( 20)
            DECLARE @cTempPickDetailKey    NVARCHAR( 20)
            SET @curUpdPack = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT LabelNo
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            ORDER BY 1
            OPEN @curUpdPack
            FETCH NEXT FROM @curUpdPack INTO @cTempLabelNo
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Update packdetail.dropid = pickdetail.dropid
               SET @curUpdPick = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT DropID FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   CaseID = @cLabelNo
               AND   [Status] = '5'
               OPEN @curUpdPick
               FETCH NEXT FROM @curUpdPick INTO @cTempDropID
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  UPDATE dbo.PACKDETAIL SET 
                     DropID = CASE WHEN ISNULL( @cTempDropID, '') = '' THEN @cTempLabelNo ELSE @cTempDropID END,
                     EditWho = USER_NAME(), 
                     EditDate = GETDATE()
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   LabelNo = @cTempLabelNo
                  
                  IF @@ERROR <> 0
                     GOTO RollBackTran
                     
                  FETCH NEXT FROM @curUpdPick INTO @cTempDropID
               END
               CLOSE @curUpdPick
               DEALLOCATE @curUpdPick

               -- Update pickdetail.dropid = packdetail.labelno
               SET @curUpdPick = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT PickDetailKey FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   CaseID = @cTempLabelNo
               AND   [Status] = '5'
               OPEN @curUpdPick
               FETCH NEXT FROM @curUpdPick INTO @cTempPickDetailKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  UPDATE dbo.PICKDETAIL SET 
                     DropID = @cTempLabelNo,
                     EditWho = USER_NAME(), 
                     EditDate = GETDATE()
                  WHERE PickDetailKey = @cTempPickDetailKey
                  
                  IF @@ERROR <> 0
                     GOTO RollBackTran
                  FETCH NEXT FROM @curUpdPick INTO @cTempPickDetailKey
               END
               CLOSE @curUpdPick
               DEALLOCATE @curUpdPick

               FETCH NEXT FROM @curUpdPack INTO @cTempLabelNo
            END
            CLOSE @curUpdPack
            DEALLOCATE @curUpdPack
            
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
               SET @nErrNo = 77418  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SCAN OUT FAIL  
               GOTO RollBackTran  
            END    
         END
      END  

      /*--------------------------------------------------------------------------------------------------  
        
                                                Insert Packinfo  
        
      --------------------------------------------------------------------------------------------------*/  
      
      SELECT TOP 1 @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK)  
      WHERE PickSlipNo = @cPickSlipNo  
         AND LabelNo = @cLabelNo  

      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   CartonNo = @nCartonNo)
      BEGIN
         INSERT INTO dbo.PACKINFO (PickSlipNo, CartonNo, CartonType)  
         VALUES (@cPickSlipNo, @nCartonNo, @cCartonType)   
         
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77415  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PINFO FAIL  
            GOTO RollBackTran  
         END    
      END
      ELSE
      BEGIN
         UPDATE dbo.PackInfo WITH (ROWLOCK) SET 
            CartonType = @cCartonType 
         WHERE PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nCartonNo
         AND   ISNULL(CartonType, '') = ''

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77416  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PINFO FAIL  
            GOTO RollBackTran  
         END    
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Dropid WITH (NOLOCK)
                      WHERE Dropid = @cLabelNo)
      BEGIN
         INSERT INTO dbo.DropID   
         (DropID, DropIDType, LabelPrinted, ManifestPrinted, [Status], PickSlipNo, LoadKey)  
         VALUES   
         (@cLabelNo, 'SortnPack', 'N', '0', '5', @cPickSlipNo, @cLoadKey)
              
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 167401  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsertDropIDEr  
            GOTO Quit  
         END  
            
      END
      FETCH NEXT FROM @curT INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @cPD_SKU, @nQTY_PD  
   END  

   GOTO Quit  
  
RollBackTran:  
      ROLLBACK TRAN rdt_SortAndPack_Confirm  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  
END  

GO