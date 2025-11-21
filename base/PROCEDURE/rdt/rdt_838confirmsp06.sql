SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_838ConfirmSP06                                        */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Date       Rev  Author      Purposes                                       */  
/* 30-09-2019 1.0  Ung         WMS-10729 Created (base on rdt_838ConfirmSP05) */  
/* 16-04-2021 1.1  James       WMS-16024 Standard use of TrackingNo (james01) */ 
/* 21-04-2022 1.2  KuanYee     INC1790688 Add Channel_ID Column (KY01)        */ 
/******************************************************************************/  

CREATE PROC [RDT].[rdt_838ConfirmSP06] (  
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
     
   DECLARE @bSuccess       INT  
   DECLARE @nRowCount      INT  
   DECLARE @cSQL           NVARCHAR(MAX)  
   DECLARE @cSQLParam      NVARCHAR(MAX)  
  
   DECLARE @cNewCarton     NVARCHAR( 1)  
   DECLARE @cLabelLine     NVARCHAR( 5)  
   DECLARE @cNewLine       NVARCHAR( 1)  
   DECLARE @cDocType       NVARCHAR( 1)  
   DECLARE @cGenLabelNo_SP NVARCHAR( 20)  
   DECLARE @cOrders_UDF04  NVARCHAR( 20)  
   DECLARE @cGroupKey      NVARCHAR( 20)  
   -- DECLARE @cUpdateGroupKey NVARCHAR( 1)  
   DECLARE @nQTY_PD        INT  
   DECLARE @nQTY_Bal       INT  
  
   -- Handling transaction  
   DECLARE @nTranCount  INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_838ConfirmSP06 -- For rollback or commit only our own transaction  
  
   /***********************************************************************************************  
                                                PackHeader  
   ***********************************************************************************************/  
   -- Get PickHeader info  
   DECLARE @cLoadKey  NVARCHAR( 10) = ''  
   DECLARE @cOrderKey NVARCHAR( 10) = ''  
   DECLARE @cZone     NVARCHAR( 18) = ''  
   SELECT TOP 1  
      @cOrderKey = OrderKey,  
      @cLoadKey = ExternOrderKey,  
      @cZone = Zone  
   FROM dbo.PickHeader WITH (NOLOCK)  
   WHERE PickHeaderKey = @cPickSlipNo  
           
   -- PackHeader  
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo)  
   BEGIN  
      INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey)  
      VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey)  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 144601  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail  
         GOTO RollBackTran  
      END  
   END  
     
  
   /***********************************************************************************************  
                                                PackDetail  
   ***********************************************************************************************/  
   -- Get order info  
   SELECT   
      @cDocType = DocType,   
      --@cOrders_UDF04 = UserDefine04  
      @cOrders_UDF04 = TrackingNo   -- (james01)  
   FROM dbo.ORDERS WITH (NOLOCK)  
   WHERE OrderKey = @cOrderKey  
  
   -- ECOMM order  
   IF @cDocType = 'E'   
   BEGIN  
      -- Check 1st carton tracking no exist  
      IF ISNULL( @cOrders_UDF04, '') = ''  
      BEGIN  
         SET @nErrNo = 144602  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No UDF04  
         GOTO RollBackTran  
      END  
   END  
     
   SET @cNewLine = 'N'  
   SET @cNewCarton = 'N'  
     
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
         IF @cDocType = 'E'  
         BEGIN  
            -- Get current carton no  
            DECLARE @nCurrCartonNo INT  
            SELECT @nCurrCartonNo = ISNULL( MAX( CartonNo), 1)  
            FROM PackDetail WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickslipNo  
               AND QTY > 0  
              
            EXEC isp_EPackCtnTrack03  
                @c_PickSlipNo = @cPickslipNo  
               ,@n_CartonNo   = @nCurrCartonNo -- Current CartonNo  
               ,@c_CTNTrackNo = @cLabelNo OUTPUT  
               ,@b_Success    = @bSuccess OUTPUT  
               ,@n_err        = @nErrNo   OUTPUT  
               ,@c_errmsg     = @cErrMsg  OUTPUT  
         END  
         ELSE  
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
                  SET @nErrNo = 144603  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail  
                  GOTO RollBackTran  
               END  
            END  
         END  
      END  
  
      IF @cLabelNo = ''  
      BEGIN  
         SET @nErrNo = 144604  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail  
         GOTO RollBackTran  
      END  
  
      SET @cLabelLine = ''     
      SET @cNewLine = 'Y'  
      SET @cNewCarton = 'Y'  
      -- SET @cUpdateGroupKey = 'Y'  
        
      -- 1 carton only allow pack from 1 group (PickDetail.CaseID/Notes = grouping key)  
      -- 1 group might pack multi cartons  
      -- 1 SKU only have 1 group  
      SET @cGroupKey = ''  
   END  
   ELSE  
   BEGIN  
      -- Get existing label no  
      SELECT TOP 1   
         @cLabelNo = LabelNo  
      FROM dbo.PackDetail WITH (NOLOCK)  
      WHERE PickSlipNo = @cPickSlipNo  
         AND CartonNo = @nCartonNo  
        
      -- Get GroupKey  
      SELECT TOP 1   
         @cGroupKey = Notes   
      FROM PickDetail WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND CaseID = @cLabelNo  
        
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
         SET @nErrNo = 144605  
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
         SET @nErrNo = 144606  
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
  
   /***********************************************************************************************  
                                                PackInfo  
   ***********************************************************************************************/  
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
            SET @nErrNo = 144607  
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
            SET @nErrNo = 144608  
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
            SET @nErrNo = 144609  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail  
            GOTO RollBackTran  
         END  
      END  
   END  
  
   /***********************************************************************************************  
                                                SerialNo  
   ***********************************************************************************************/  
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
         SET @nErrNo = 144610  
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
               SET @nErrNo = 144611  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackSNOFail  
               GOTO RollBackTran  
            END  
         END  
         ELSE  
         BEGIN  
            SET @nErrNo = 144612  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan  
            GOTO RollBackTran  
         END  
  
         DELETE rdt.rdtReceiveSerialNoLog   
         WHERE ReceiveSerialNoLogKey = @nReceiveSerialNoLogKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 144613  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL TmpSN Fail  
            GOTO RollBackTran  
         END   
  
         SET @nQTY_Bal = @nQTY_Bal - @nSerialQTY  
      END  
           
      -- Check fully offset  
      IF @nQTY_Bal <> 0  
      BEGIN  
         SET @nErrNo = 144614  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error   
         GOTO RollBackTran  
      END   
  
      -- Check balance  
      IF EXISTS( SELECT 1  
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)  
         WHERE Mobile = @nMobile  
            AND Func = @nFunc)  
      BEGIN  
         SET @nErrNo = 144615  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error   
         GOTO RollBackTran  
      END  
   END  
  
   -- Serial no  
   ELSE IF @cSerialNo <> ''  
   BEGIN  
      -- Get serial no info  
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
            SET @nErrNo = 144616  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RDSNo Fail  
            GOTO RollBackTran  
         END  
      END  
        
      -- Check serial no scanned  
      ELSE  
      BEGIN  
         SET @nErrNo = 144617  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan  
         GOTO RollBackTran  
      END  
   END  
  
   /***********************************************************************************************  
                                                PackData  
   ***********************************************************************************************/  
   DECLARE @cPickStatus NVARCHAR(1)  
   SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerkey)  
  
   -- Auto retrieve COO, if only 1 value  
   IF @cPackData1 = ''  
   BEGIN  
      -- Get SKU info  
      DECLARE @cSKUDataCapture NVARCHAR(1)  
      SELECT @cSKUDataCapture = DataCapture  
      FROM SKU WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey   
         AND SKU = @cSKU  
  
      IF @cSKUDataCapture IN ('1', '3') -- 1=Inbound and outbound, 3=outbound only  
      BEGIN  
         SELECT @cPackData1 = LA.Lottable01  
         FROM dbo.PickDetail PD WITH (NOLOCK)  
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)  
         WHERE PD.OrderKey = @cOrderKey  
            AND PD.StorerKey = @cStorerKey  
            AND PD.SKU = @cSKU  
            AND PD.Status < @cPickStatus  
            AND PD.Status <> '4'  
         GROUP BY LA.Lottable01  
           
         SET @nRowCount = @@ROWCOUNT  
         IF @nRowCount <> 1  
         BEGIN  
            SET @nErrNo = 144618  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --COO NotSpecify  
            GOTO RollBackTran  
         END  
      END  
   END  
  
   -- Pack data  
   IF @cPackData1 <> '' OR  
      @cPackData2 <> '' OR  
      @cPackData3 <> ''  
   BEGIN  
      DECLARE @nPackDetailInfoKey BIGINT  
        
      -- Get PackDetailInfo  
      SET @nPackDetailInfoKey = 0  
      SELECT @nPackDetailInfoKey = PackDetailInfoKey  
      FROM dbo.PackDetailInfo WITH (NOLOCK)   
      WHERE PickSlipNo = @cPickSlipNo   
         AND CartonNo = @nCartonNo  
         AND LabelNo = @cLabelNo   
         AND SKU = @cSKU  
         AND UserDefine01 = @cPackData1  
         AND UserDefine02 = @cPackData2  
         AND UserDefine03 = @cPackData3  
        
      IF @nPackDetailInfoKey = ''  
      BEGIN  
         -- Insert PackDetailInfo  
         INSERT INTO dbo.PackDetailInfo (  
            PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, UserDefine01, UserDefine02, UserDefine03,   
            AddWho, AddDate, EditWho, EditDate)  
         VALUES (  
            @cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cPackData1, @cPackData2, @cPackData3,   
            'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 144619  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PDInfoFail  
            GOTO RollBackTran  
         END  
      END  
      ELSE  
      BEGIN  
         -- Update PackDetailInfo  
         UPDATE dbo.PackDetailInfo SET     
QTY = QTY + @nQTY,   
            EditWho = 'rdt.' + SUSER_SNAME(),   
            EditDate = GETDATE(),   
            ArchiveCop = NULL  
         WHERE PackDetailInfoKey = @nPackDetailInfoKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 144620  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PDInfoFail  
            GOTO RollBackTran  
         END  
      END  
   END  
  
   /***********************************************************************************************  
                                                PickDetail  
   ***********************************************************************************************/  
   DECLARE @cPD_OrderKey      NVARCHAR( 10)  
   DECLARE @cPD_OrderLineNo   NVARCHAR( 5)  
   DECLARE @cPickDetailKey    NVARCHAR( 10) = ''  
   DECLARE @cPackedPDKey      NVARCHAR( 10)  
   DECLARE @cLOT              NVARCHAR( 10)  
   DECLARE @cLOC              NVARCHAR( 10)  
   DECLARE @cID               NVARCHAR( 18)  
   DECLARE @cSQLPickSlip      NVARCHAR( MAX)  
  
   -- Below reduce and top up logic only work for piece scan, QTY = 1  
   IF @nQTY <> 1  
   BEGIN  
      SET @nErrNo = 144621  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PieceScanOnly  
      GOTO Quit  
   END  
  
   -- Different types of PickSlip  
   SET @cSQLPickSlip =   
      CASE   
         -- Cross dock PickSlip  
         WHEN @cZone IN ('XD', 'LB', 'LP') THEN   
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +   
               ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +   
               ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +   
            ' WHERE RKL.PickSlipNo = @cPickSlipNo '  
         -- Discrete PickSlip  
         WHEN @cOrderKey <> '' THEN   
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +   
               ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +   
            ' WHERE PD.OrderKey = @cOrderKey '  
         -- Conso PickSlip  
         WHEN @cLoadKey <> '' THEN   
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)  ' +   
               ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +   
               ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +   
            ' WHERE LPD.LoadKey = @cLoadKey '  
         -- Custom PickSlip  
         ELSE   
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +   
               ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +   
            ' WHERE PD.PickSlipNo = @cPickSlipNo '  
      END  
        
   -- Find PickDetail to offset  
   SET @cSQL =   
      ' SELECT TOP 1 ' +   
         CASE WHEN @cGroupKey = '' THEN ' @cGroupKey = PD.Notes, ' ELSE '' END +   
         ' @cPD_OrderKey = PD.OrderKey, ' +   
         ' @cPD_OrderLineNo = PD.OrderLineNumber, ' +   
         ' @cPickDetailKey = PD.PickDetailKey, ' +   
         ' @cLOT = PD.LOT, ' +   
         ' @cLOC = PD.LOC, ' +   
         ' @cID = PD.ID, ' +   
         ' @nQTY_PD = PD.QTY ' +   
         @cSQLPickSlip +   
         ' AND PD.StorerKey = @cStorerKey ' +   
         ' AND PD.SKU = @cSKU ' +   
         ' AND PD.QTY > 0 ' +   
         ' AND PD.Status = @cPickStatus ' +   
         ' AND PD.CaseID = '''' ' +  
         ' AND PD.Status <> ''4'' ' +   
         CASE WHEN @cPackData1 = '' THEN '' ELSE ' AND LA.Lottable01 = @cPackData1 ' END  
     
   SET @cSQLParam =   
      ' @cGroupKey          NVARCHAR( 10) OUTPUT, ' +   
      ' @cPD_OrderKey       NVARCHAR( 10) OUTPUT, ' +   
      ' @cPD_OrderLineNo    NVARCHAR( 5)  OUTPUT, ' +   
      ' @cPickDetailKey     NVARCHAR( 10) OUTPUT, ' +   
      ' @cLOT               NVARCHAR( 10) OUTPUT, ' +   
      ' @cLOC               NVARCHAR( 10) OUTPUT, ' +   
      ' @cID                NVARCHAR( 18) OUTPUT, ' +   
      ' @nQTY_PD            INT           OUTPUT, ' +   
      ' @cPickSlipNo        NVARCHAR( 10),        ' +   
      ' @cLoadKey           NVARCHAR( 10),        ' +   
   ' @cOrderKey          NVARCHAR( 10),        ' +   
      ' @cStorerKey         NVARCHAR( 15),        ' +   
      ' @cSKU               NVARCHAR( 20),        ' +   
      ' @cPickStatus NVARCHAR( 1),         ' +   
      ' @cPackData1         NVARCHAR( 30)         '    
        
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam  
      ,@cGroupKey       OUTPUT    
      ,@cPD_OrderKey    OUTPUT    
      ,@cPD_OrderLineNo OUTPUT    
      ,@cPickDetailKey  OUTPUT    
      ,@cLOT            OUTPUT    
      ,@cLOC            OUTPUT    
      ,@cID             OUTPUT    
      ,@nQTY_PD         OUTPUT   
      ,@cPickSlipNo      
      ,@cLoadKey       
      ,@cOrderKey    
      ,@cStorerKey       
      ,@cSKU             
      ,@cPickStatus  
      ,@cPackData1  
  
   -- Check blank  
   IF @cPickDetailKey = ''  
   BEGIN  
      SET @nErrNo = 144622  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No PickKDetail  
      GOTO RollBackTran  
   END  
  
   -- Find packed PickDetail to topup (avoid split line, 1 QTY 1 line), but must be same order, line, LOT, LOC, ID  
   SET @cPackedPDKey = ''  
   SET @cSQL =   
      ' SELECT @cPackedPDKey = PD.PickDetailKey ' +  
         @cSQLPickSlip +   
         ' AND PD.OrderKey = @cPD_OrderKey ' +  
         ' AND PD.OrderLineNumber = @cPD_OrderLineNo ' +  
         ' AND PD.LOT = @cLOT ' +  
         ' AND PD.LOC = @cLOC ' +  
         ' AND PD.ID = @cID ' +  
         ' AND PD.Status = @cPickStatus ' +  
         ' AND PD.CaseID = @cLabelNo ' +  
         ' AND PD.QTY > 0 ' +  
         ' AND PD.Status <> ''4'' '  
  
   SET @cSQLParam =   
      ' @cPackedPDKey       NVARCHAR( 10) OUTPUT, ' +   
      ' @cLOT               NVARCHAR( 10), ' +   
      ' @cLOC               NVARCHAR( 10), ' +   
      ' @cID                NVARCHAR( 18), ' +   
      ' @cPickSlipNo        NVARCHAR( 10), ' +   
      ' @cLoadKey           NVARCHAR( 10), ' +   
      ' @cOrderKey          NVARCHAR( 10), ' +   
      ' @cPD_OrderKey       NVARCHAR( 10), ' +   
      ' @cPD_OrderLineNo    NVARCHAR( 5), ' +   
      ' @cPickStatus NVARCHAR( 1), ' +   
      ' @cLabelNo           NVARCHAR( 20)     '    
        
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam  
      ,@cPackedPDKey OUTPUT    
      ,@cLOT  
      ,@cLOC  
      ,@cID  
      ,@cPickSlipNo      
      ,@cLoadKey         
      ,@cOrderKey  
      ,@cPD_OrderKey  
      ,@cPD_OrderLineNo  
      ,@cPickStatus  
      ,@cLabelNo  
  
--SELECT @cPickDetailKey '@cPickDetailKey', @cPackedPDKey '@cPackedPDKey', @cPD_OrderKey '@cPD_OrderKey', @cPD_OrderLineNo '@cPD_OrderLineNo',   
--@cLOT '@cLOT', @cLOC '@cLOC', @cID '@cID', @cPickStatus '@cPickStatus', @cLabelNo '@cLabelNo'  
     
   IF @cPackedPDKey <> ''  
   BEGIN  
      -- Reduce open PickDetail   
      UPDATE PickDetail SET  
         QTY = QTY - 1,   
         EditDate = GETDATE(),   
         EditWho = SUSER_SNAME(),   
         TrafficCop = NULL  
      WHERE PickDetailKey = @cPickDetailKey  
      IF @@ERROR <> 0  
      BEGIN  
   SET @nErrNo = 144623  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
         GOTO RollBackTran  
      END  
        
      -- Top up sorted PickDetail  
      UPDATE PickDetail SET  
         QTY = QTY + 1,   
         CaseID = @cLabelNo,   
         EditDate = GETDATE(),   
         EditWho = SUSER_SNAME(),   
         TrafficCop = NULL  
      WHERE PickDetailKey = @cPackedPDKey  
      IF @@ERROR <> 0  
      BEGIN  
   SET @nErrNo = 144624  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
         GOTO RollBackTran  
      END  
        
      -- Delete zero balance PickDetail  
      IF @nQTY_PD = 1  
      BEGIN  
         DELETE PickDetail WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
      SET @nErrNo = 144625  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL PKDtl Fail  
            GOTO RollBackTran  
         END  
      END  
   END  
   ELSE  
   BEGIN  
      -- Exact match  
      IF @nQTY_PD = 1  
      BEGIN  
         -- Confirm PickDetail  
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
            CaseID = @cLabelNo,   
            EditDate = GETDATE(),   
            EditWho  = SUSER_SNAME(),   
            TrafficCop = NULL  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 144626  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
            GOTO RollBackTran  
         END  
      END  
           
      -- PickDetail have more  
    ELSE IF @nQTY_PD > 1  
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
            SET @nErrNo = 144627  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
            GOTO RollBackTran  
         END  
  
         -- Create new a PickDetail to hold the balance  
         INSERT INTO dbo.PickDetail (  
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,   
            UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,   
            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, Channel_ID,  --KY01  
            PickDetailKey,   
            QTY,   
            TrafficCop,  
            OptimizeCop)  
         SELECT   
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,   
            UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,   
            CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, Channel_ID,  --KY01
            @cNewPickDetailKey,   
            @nQTY_PD - 1, -- QTY  
            NULL, -- TrafficCop  
            '1'   -- OptimizeCop  
         FROM dbo.PickDetail WITH (NOLOCK)   
     WHERE PickDetailKey = @cPickDetailKey                 
         IF @@ERROR <> 0  
         BEGIN  
      SET @nErrNo = 144628  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail  
            GOTO RollBackTran  
         END  
  
         -- Split RefKeyLookup  
         IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)  
         BEGIN  
            -- Insert into  
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)  
            SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey  
            FROM RefKeyLookup WITH (NOLOCK)   
            WHERE PickDetailKey = @cPickDetailKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 144629  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail  
               GOTO RollBackTran  
            END  
         END  
           
         -- Change orginal PickDetail with exact QTY (with TrafficCop)  
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
            QTY = 1,   
            CaseID = @cLabelNo,   
            EditDate = GETDATE(),   
            EditWho  = SUSER_SNAME(),   
            Trafficcop = NULL  
         WHERE PickDetailKey = @cPickDetailKey   
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 144630  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
            GOTO RollBackTran  
         END  
      END  
   END  
     
   COMMIT TRAN rdt_838ConfirmSP06  
   GOTO Quit  
  
RollBackTran:  
BEGIN  
   ROLLBACK TRAN rdt_838ConfirmSP06 -- Only rollback change made here  
   IF @cNewCarton = 'Y'  
   BEGIN  
      SET @nCartonNo = 0  
      SET @cLabelNo = ''  
   END  
END  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
  
END  

GO