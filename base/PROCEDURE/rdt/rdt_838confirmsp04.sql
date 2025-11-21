SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdt_838ConfirmSP04                                  */    
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */    
/* 12-10-2018  1.0  James       WMS-6654 Created                        */    
/* 25-Mar-2019 1.1  CheeMun     INC0624434-Split PickDetail Status      */    
/* 04-04-2019  1.2  Ung         WMS-8134 Add PackData1..3 parameter     */    
/* 27-02-2020  1.3  James       WMS-12052 Add bulk serial no (james01)  */   
/* 04-16-2021  1.4  James       WMS-16024 Standarized use of TrackingNo */
/*                              (james02)                               */ 
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_838ConfirmSP04] (    
    @nMobile         INT    
   ,@nFunc           INT    
   ,@cLangCode       NVARCHAR( 3)    
   ,@nStep           INT    
   ,@nInputKey       INT    
   ,@cFacility       NVARCHAR( 5)    
   ,@cStorerKey      NVARCHAR( 15)    
   ,@cPickSlipNo     NVARCHAR( 10)    
   ,@cFromDropID     NVARCHAR( 20)    
   ,@cSKU            NVARCHAR( 20)     
   ,@nQTY            INT    
   ,@cUCCNo          NVARCHAR( 20)     
   ,@cSerialNo       NVARCHAR( 30)     
   ,@nSerialQTY      INT    
   ,@cPackDtlRefNo   NVARCHAR( 20)     
   ,@cPackDtlRefNo2  NVARCHAR( 20)     
   ,@cPackDtlUPC     NVARCHAR( 30)     
   ,@cPackDtlDropID  NVARCHAR( 20)     
   ,@nCartonNo       INT           OUTPUT    
   ,@cLabelNo        NVARCHAR( 20) OUTPUT    
   ,@nErrNo          INT           OUTPUT    
   ,@cErrMsg         NVARCHAR(250) OUTPUT    
   ,@nBulkSNO        INT    
   ,@nBulkSNOQTY     INT    
   ,@cPackData1      NVARCHAR( 30)    
   ,@cPackData2      NVARCHAR( 30)    
   ,@cPackData3      NVARCHAR( 30)    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @bSuccess       INT,    
           @cSQL           NVARCHAR(MAX),    
           @cSQLParam      NVARCHAR(MAX),    
           @cLabelLine     NVARCHAR( 5),    
           @cNewLine       NVARCHAR( 1),    
           @cGenLabelNo_SP NVARCHAR( 20),    
           @cOrders_UDF04  NVARCHAR( 20),    
           @cCarrierName   NVARCHAR( 15),    
           @cKeyName       NVARCHAR( 30),    
           @cTrackingNo    NVARCHAR( 20),    
           @cPickDetailKey NVARCHAR( 10),    
           @cLoadKey       NVARCHAR( 10),    
           @cOrderKey      NVARCHAR( 10),    
           @nPackQty       INT,    
           @nQTY_PD        INT,    
           @nFirst_Ctn     INT,    
           @b_success      INT,    
           @nQTY_Bal INT  
    
   -- Handling transaction    
   DECLARE @nTranCount  INT    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
   SAVE TRAN rdt_838ConfirmSP04 -- For rollback or commit only our own transaction    
    
   SET @cOrderKey = ''    
   SET @cLoadKey = ''    
    
   -- Get PickHeader info    
   SELECT TOP 1    
      @cOrderKey = OrderKey,    
      @cLoadKey = ExternOrderKey    
   FROM dbo.PickHeader WITH (NOLOCK)    
   WHERE PickHeaderKey = @cPickSlipNo    
             
   -- PackHeader    
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo)    
   BEGIN    
      INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey)    
      VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey)    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 130001    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail    
         GOTO RollBackTran    
      END    
   END    
       
   --SELECT @cOrders_UDF04 = UserDefine04,
   SELECT @cOrders_UDF04 = TrackingNo,    -- (james02)
          @cCarrierName = ShipperKey    
   FROM dbo.ORDERS WITH (NOLOCK)    
   WHERE OrderKey = @cOrderKey    
    
   IF ISNULL( @cOrders_UDF04, '') = ''    
   BEGIN    
      SET @nErrNo = 130002    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No UDF04    
      GOTO RollBackTran    
   END    
    
   IF @nCartonNo = 0 -- New carton    
   BEGIN    
      -- Determine whether is 1st carton in pickslip.     
      -- 1st Carton use orders.userdefine04    
      -- 2nd Carton use cartontrack .trackingno    
      IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)    
      BEGIN    
         SET @nFirst_Ctn = 0    
          
         SELECT @cKeyName = Long    
         FROM dbo.CodeLKUp WITH (NOLOCK)    
         WHERE LISTNAME = 'AsgnTNo'    
         AND   Storerkey = @cStorerKey    
         AND   Short = @cCarrierName    
    
         SELECT @cTrackingNo = MIN( TrackingNo)      
         FROM dbo.CartonTrack WITH (NOLOCK)      
         WHERE CarrierName = @cCarrierName       
         AND   Keyname = @cKeyName       
         AND   ISNULL( CarrierRef2, '') = ''      
    
         SET @cLabelNo = @cTrackingNo    
    
         UPDATE dbo.CartonTrack WITH (ROWLOCK) SET     
            LabelNo = @cOrderKey,    
            CarrierRef2 = 'GET'    
         WHERE CarrierName = @cCarrierName       
         AND   Keyname = @cKeyName       
         AND   ISNULL( CarrierRef2, '') = ''      
         AND   TrackingNo = @cTrackingNo    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 130003    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get Track Fail    
            GOTO RollBackTran    
         END    
    
      END    
      ELSE    
      BEGIN    
         SET @nFirst_Ctn = 1    
         SET @cLabelNo = @cOrders_UDF04    
      END    
   END    
   ELSE    
      -- Not new carton, get existing label no    
      SELECT TOP 1 @cLabelNo = LabelNo    
      FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
      AND   CartonNo = @nCartonNo    
      ORDER BY 1     
    
   --IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)     
   --                  WHERE PickSlipNo = @cPickSlipNo    
   --                  AND   LabelNo = @cLabelNo)    
   --   SET @nCartonNo = 0    
    
   SET @cNewLine = 'N'    
       
   -- New carton, generate labelNo    
   IF @nCartonNo = 0 --     
   BEGIN    
      IF @cUCCNo <> ''    
      BEGIN    
         IF rdt.RDTGetConfig( @nFunc, 'DefaultUCCtoLabelNo', @cStorerkey) = '1'    
            SET @cLabelNo = @cUCCNo    
      END    
          
      IF @cLabelNo = ''    
      BEGIN    
         SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerkey)    
         IF @cGenLabelNo_SP = '0'    
            SET @cGenLabelNo_SP = ''    
             
         IF @cGenLabelNo_SP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')      
            BEGIN    
               SET @cSQL = 'EXEC dbo.' + RTRIM( @cGenLabelNo_SP) +    
                  ' @cPickslipNo, ' +      
                  ' @nCartonNo,   ' +      
                  ' @cLabelNo     OUTPUT '      
               SET @cSQLParam =    
                  ' @cPickslipNo  NVARCHAR(10),       ' +      
                  ' @nCartonNo    INT,                ' +      
                  ' @cLabelNo     NVARCHAR(20) OUTPUT '      
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @cPickslipNo,     
                  @nCartonNo,     
                  @cLabelNo OUTPUT    
            END    
         END    
         ELSE    
         BEGIN       
            EXEC isp_GenUCCLabelNo    
               @cStorerKey,    
               @cLabelNo      OUTPUT,     
               @bSuccess      OUTPUT,    
               @nErrNo        OUTPUT,    
               @cErrMsg       OUTPUT    
            IF @nErrNo <> 0    
            BEGIN    
               SET @nErrNo = 130004    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail    
               GOTO RollBackTran    
            END    
         END    
      END    
    
      IF @cLabelNo = ''    
      BEGIN    
         SET @nErrNo = 130005    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail    
         GOTO RollBackTran    
      END    
    
      SET @cLabelLine = ''       
      SET @cNewLine = 'Y'    
   END    
   ELSE    
   BEGIN    
      -- Get LabelLine    
      SET @cLabelLine = ''    
      SELECT @cLabelLine = LabelLine    
      FROM dbo.PackDetail WITH (NOLOCK)     
      WHERE PickSlipNo = @cPickSlipNo     
         AND CartonNo = @nCartonNo    
         AND LabelNo = @cLabelNo     
         AND SKU = @cSKU    
         AND RefNo = @cPackDtlRefNo    
          
      IF @cLabelLine = ''    
         SELECT @cLabelLine = LabelLine    
         FROM dbo.PackDetail WITH (NOLOCK)     
         WHERE PickSlipNo = @cPickSlipNo     
            AND CartonNo = @nCartonNo    
            AND LabelNo = @cLabelNo     
            AND SKU = ''    
          
      IF @cLabelLine = ''    
      BEGIN    
         SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)     
         FROM dbo.PackDetail (NOLOCK)    
         WHERE Pickslipno = @cPickSlipNo    
            AND CartonNo = @nCartonNo    
            AND LabelNo = @cLabelNo    
    
         SET @cNewLine = 'Y'    
      END    
   END    
       
   IF @cNewLine = 'Y'    
   BEGIN    
      -- Insert PackDetail    
      INSERT INTO dbo.PackDetail    
         (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, RefNo,     
         AddWho, AddDate, EditWho, EditDate)    
      VALUES    
         (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cPackDtlRefNo,     
         'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 130006    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail    
         GOTO RollBackTran    
      END    
   END    
   ELSE    
   BEGIN    
      -- Update Packdetail    
      UPDATE dbo.PackDetail WITH (ROWLOCK) SET       
         SKU = @cSKU,     
         QTY = QTY + @nQTY,     
         EditWho = 'rdt.' + SUSER_SNAME(),     
         EditDate = GETDATE(),     
         ArchiveCop = NULL    
      WHERE PickSlipNo = @cPickSlipNo    
         AND CartonNo = @nCartonNo    
         AND LabelNo = @cLabelNo    
         AND LabelLine = @cLabelLine    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 130007    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail    
         GOTO RollBackTran    
      END    
   END    
    
   -- Get system assigned CartonoNo and LabelNo    
   IF @nCartonNo = 0    
   BEGIN    
      -- If insert cartonno = 0, system will auto assign max cartonno    
      SELECT TOP 1     
         @nCartonNo = CartonNo,     
         @cLabelNo = LabelNo,     
         @cLabelLine = LabelLine    
      FROM PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
         AND SKU = @cSKU    
         AND AddWho = 'rdt.' + SUSER_SNAME()    
      ORDER BY CartonNo DESC -- max cartonno    
   END       
    
   -- Insert PackInfo    
   IF @cUCCNo <> ''    
   BEGIN    
      -- PackInfo    
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)    
      BEGIN    
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, UCCNo, QTY)    
         VALUES (@cPickSlipNo, @nCartonNo, @cUCCNo, @nQTY)    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 130008    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail    
            GOTO RollBackTran    
         END    
      END    
      ELSE    
      BEGIN    
         UPDATE dbo.PackInfo SET    
            UCCNo = @cUCCNo,     
            EditDate = GETDATE(),     
            EditWho = SUSER_SNAME(),     
            TrafficCop = NULL    
         WHERE PickSlipNo = @cPickSlipNo    
            AND CartonNo = @nCartonNo    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 130009    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail    
            GOTO RollBackTran    
         END    
      END    
    
      -- Mark UCC packed    
      IF EXISTS( SELECT 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cUCCNo AND Status < '5')    
      BEGIN    
         UPDATE UCC SET    
            Status = '6',     
            EditWho = SUSER_SNAME(),     
            EditDate = GETDATE(),     
            TrafficCop = NULL    
         WHERE StorerKey = @cStorerKey     
            AND UCCNo = @cUCCNo    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 130010    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail    
            GOTO RollBackTran    
   END    
      END    
   END    
    
     -- Bulk serial no    
   IF @nBulkSNO = 1    
   BEGIN    
      DECLARE @nReceiveSerialNoLogKey INT    
          
      -- Check SNO QTY    
      IF (SELECT ISNULL( SUM( QTY), 0)     
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)    
         WHERE Mobile = @nMobile    
            AND Func = @nFunc) <> @nBulkSNOQTY    
      BEGIN    
         SET @nErrNo = 137711    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SN QTYNotTally    
         GOTO RollBackTran    
      END     
          
      SET @nQTY_Bal = @nQTY    
          
      -- Loop serial no          
      WHILE (1=1)    
      BEGIN    
         SELECT TOP 1     
            @nReceiveSerialNoLogKey = ReceiveSerialNoLogKey,     
            @cSerialNo = SerialNo,     
            @nSerialQTY = QTY    
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)    
         WHERE Mobile = @nMobile    
            AND Func = @nFunc    
             
         IF @@ROWCOUNT = 0    
            BREAK    
    
         -- Check serial no scanned    
         IF NOT EXISTS( SELECT 1    
            FROM PackSerialNo WITH (NOLOCK)    
            WHERE PickSlipNo = @cPickSlipNo    
               AND StorerKey = @cStorerKey    
               AND SKU = @cSKU    
               AND SerialNo = @cSerialNo)    
         BEGIN    
            -- Insert PackSerialNo     
            INSERT INTO PackSerialNo (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, SerialNo, QTY)    
            VALUES (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @cSerialNo, @nSerialQTY)    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 130020    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackSNOFail    
               GOTO RollBackTran    
            END    
         END    
         ELSE    
         BEGIN    
            SET @nErrNo = 130021    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan    
            GOTO RollBackTran    
         END    
    
         DELETE rdt.rdtReceiveSerialNoLog     
         WHERE ReceiveSerialNoLogKey = @nReceiveSerialNoLogKey    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 130022    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL TmpSN Fail    
            GOTO RollBackTran    
         END     
    
         SET @nQTY_Bal = @nQTY_Bal - @nSerialQTY    
      END    
             
      -- Check fully offset    
      IF @nQTY_Bal <> 0    
      BEGIN    
         SET @nErrNo = 130023    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error     
         GOTO RollBackTran    
      END     
    
      -- Check balance    
      IF EXISTS( SELECT 1    
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)    
         WHERE Mobile = @nMobile    
            AND Func = @nFunc)    
      BEGIN    
         SET @nErrNo = 130024    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error     
         GOTO RollBackTran    
      END    
   END    
    
   -- Serial no    
   ELSE IF @cSerialNo <> ''    
   BEGIN    
      -- Get serial no info    
      DECLARE @nRowCount INT    
      DECLARE @nPackSerialNoKey  INT    
      DECLARE @cChkSerialSKU NVARCHAR( 20)    
      DECLARE @nChkSerialQTY INT    
          
      SELECT     
         @nPackSerialNoKey = PackSerialNoKey,     
         @cChkSerialSKU = SKU,     
         @nChkSerialQTY = QTY    
      FROM PackSerialNo WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
         AND StorerKey = @cStorerKey    
         AND SKU = @cSKU    
         AND SerialNo = @cSerialNo    
      SET @nRowCount = @@ROWCOUNT    
          
      -- New serial no    
      IF @nRowCount = 0    
      BEGIN    
         -- Insert PackSerialNo     
         INSERT INTO PackSerialNo (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, SerialNo, QTY)    
         VALUES (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @cSerialNo, @nSerialQTY)    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 130011    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RDSNo Fail    
            GOTO RollBackTran    
         END    
      END    
          
      -- Check serial no scanned    
      ELSE    
      BEGIN    
         SET @nErrNo = 130012    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan    
         GOTO RollBackTran    
      END    
   END    
    
   SET @nPackQty = @nQty    
    
   DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT PickDetailKey, QTY    
   FROM dbo.PickDetail WITH (NOLOCK)    
   WHERE OrderKey  = @cOrderKey    
   AND   StorerKey  = @cStorerKey    
   AND   SKU = @cSKU    
   AND  ( [STATUS] <= '3' OR [STATUS] = '5')    
   AND   ISNULL( CaseID, '') = ''    
   ORDER BY PickDetailKey    
   OPEN curPD    
   FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      -- Exact match    
      IF @nQTY_PD = @nPackQty    
      BEGIN    
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
            EditWho = SUSER_SNAME(),    
            EditDate = GETDATE(),    
            CaseID = @cLabelNo,    
            TrafficCop = NULL    
         WHERE PickDetailKey = @cPickDetailKey    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 130013    
            SET @cErrMsg = rdt.rdtgetmessage( 66027, @cLangCode, 'DSP') --'Upd CaseID Fail'    
            GOTO RollBackTran    
         END    
    
         SET @nPackQty = @nPackQty - @nQTY_PD -- Reduce balance -- SOS# 176144    
      END    
      -- PickDetail have less    
      ELSE IF @nQTY_PD < @nPackQty    
      BEGIN    
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
            EditWho = SUSER_SNAME(),    
            EditDate = GETDATE(),    
            CaseID = @cLabelNo,    
            TrafficCop = NULL    
         WHERE PickDetailKey = @cPickDetailKey    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 130014    
            SET @cErrMsg = rdt.rdtgetmessage( 66028, @cLangCode, 'DSP') --'OffSetPDtlFail'    
            GOTO RollBackTran    
         END    
    
         SET @nPackQty = @nPackQty - @nQTY_PD -- Reduce balance    
      END    
      -- PickDetail have more, need to split    
      ELSE IF @nQTY_PD > @nPackQty    
      BEGIN    
         IF @nPackQty > 0 -- SOS# 176144    
         BEGIN    
            -- Get new PickDetailkey    
            DECLARE @cNewPickDetailKey NVARCHAR( 10)    
            EXECUTE dbo.nspg_GetKey    
               'PICKDETAILKEY',    
               10 ,    
               @cNewPickDetailKey OUTPUT,    
               @b_success         OUTPUT,    
               0,    
               0    
    
            IF @b_success <> 1    
            BEGIN    
               SET @nErrNo = 130015    
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
               Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,  --INC0624434    
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,    
               @nQTY_PD - @nPackQty, -- QTY    
               NULL, --TrafficCop,    
               '1'  --OptimizeCop    
            FROM dbo.PickDetail WITH (NOLOCK)    
            WHERE PickDetailKey = @cPickDetailKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 130016    
               SET @cErrMsg = rdt.rdtgetmessage( 66030, @cLangCode, 'DSP') --'Ins PDtl Fail'    
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
                  SET @nErrNo = 130017    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail    
                  GOTO RollBackTran    
               END    
            END    
    
            -- If split line needed. Update pickdetail.qty with no trafficcop    
            -- Change orginal PickDetail with exact QTY (with TrafficCop)    
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
               EditWho = SUSER_SNAME(),    
               EditDate = GETDATE(),    
               QTY = @nPackQty,    
               Trafficcop = NULL    
            WHERE PickDetailKey = @cPickDetailKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 130018    
               SET @cErrMsg = rdt.rdtgetmessage( 66031, @cLangCode, 'DSP') --'Upd CaseID Fail'    
               GOTO RollBackTran    
            END    
    
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
               EditWho = SUSER_SNAME(),    
               EditDate = GETDATE(),    
               CaseID = @cLabelNo,    
               TrafficCop = NULL    
            WHERE PickDetailKey = @cPickDetailKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 130019    
               SET @cErrMsg = rdt.rdtgetmessage( 66032, @cLangCode, 'DSP') --'Upd CaseID Fail'    
               GOTO RollBackTran    
            END    
    
            SET @nPackQty = 0 -- Reduce balance    
         END    
      END    
    
      IF @nPackQty = 0     
      BEGIN    
         BREAK -- Exit     
      END    
    
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD    
   END    
   CLOSE curPD    
   DEALLOCATE curPD       
       
   COMMIT TRAN rdt_838ConfirmSP04    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_838ConfirmSP04 -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
    
END 

GO