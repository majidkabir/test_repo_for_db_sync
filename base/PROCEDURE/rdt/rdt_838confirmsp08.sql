SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_838ConfirmSP08                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 19-05-2021 1.0  yeekung     WMS-16963 created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_838ConfirmSP08] (
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
   DECLARE @nPickQTY       INT
   DECLARE @cPackDetailCartonID  NVARCHAR( 20)  

   DECLARE @cOrderKey NVARCHAR(20),
           @cLoadKey  NVARCHAR(20),
           @cZone    NVARCHAR(20)

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_838ConfirmSP08 -- For rollback or commit only our own transaction
    
   -- PackHeader  
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo)  
   BEGIN  
      DECLARE @cConsigneekey NVARCHAR(20)
      SET @cOrderKey = ''  
      SET @cLoadKey = ''  
  
      -- Get PickHeader info  
      SELECT TOP 1  
         @cOrderKey = PH.OrderKey,  
         @cLoadKey =ph. ExternOrderKey  
      FROM dbo.PickHeader PH WITH (NOLOCK) 
      WHERE PH.PickHeaderKey = @cPickSlipNo 
      
      SELECT  @cConsigneekey=ConsigneeKey
      FROM orders (NOLOCK)
      WHERE orderkey=@cOrderKey

        
      INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey,ConsigneeKey)  
      VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey,@cConsigneekey)  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 168051  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail  
         GOTO RollBackTran  
      END  
   END  
  
   -- (james01)  
   SET @cPackDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PackDetailCartonID', @cStorerKey)  
   IF @cPackDetailCartonID = '0' -- DropID/LabelNo/RefNo/RefNo2/UPC/NONE  
      SET @cPackDetailCartonID = 'DropID'  
  
   DECLARE @cDropID  NVARCHAR( 20) = ''  
   DECLARE @cRefNo   NVARCHAR( 20) = ''  
   DECLARE @cRefNo2  NVARCHAR( 30) = ''  
   DECLARE @cUPC     NVARCHAR( 30) = ''  
  
   IF @cPackDetailCartonID = 'DropID'  SET @cDropID  = @cPackDtlDropID ELSE  
   IF @cPackDetailCartonID = 'RefNo'   SET @cRefNo   = @cPackDtlRefNo ELSE  
   IF @cPackDetailCartonID = 'RefNo2'  SET @cRefNo2  = @cPackDtlRefNo2 ELSE  
   IF @cPackDetailCartonID = 'UPC'     SET @cUPC     = @cPackDtlUPC  
     
   SET @cNewLine = 'N'  
   SET @cNewCarton = 'N'  
     
   -- New carton, generate labelNo  
   IF @nCartonNo = 0 --   
   BEGIN  
      SET @cLabelNo = ''  
    
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
               SET @nErrNo = 168052  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail  
               GOTO RollBackTran  
            END  
         END  
      END  
  
      IF @cLabelNo = ''  
      BEGIN  
         SET @nErrNo = 168053  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail  
         GOTO RollBackTran  
      END  
  
      SET @cLabelLine = ''     
      SET @cNewLine = 'Y'  
      SET @cNewCarton = 'Y'  
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
         (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY,   
         DropID, RefNo, RefNo2, UPC,  
         AddWho, AddDate, EditWho, EditDate)  
      VALUES  
         (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY,   
         @cDropID, @cRefNo, @cRefNo2, @cUPC,  
         'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 168055  
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
         SET @nErrNo = 168056  
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
            SET @nErrNo = 168057  
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
            SET @nErrNo = 168057  
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
            SET @nErrNo = 168058  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail  
            GOTO RollBackTran  
         END  
      END  
   END  
  
   -- Many serial no  
   IF @nBulkSNO = 1  
   BEGIN  
      DECLARE @nReceiveSerialNoLogKey INT  
        
      -- Check SNO QTY  
      IF (SELECT ISNULL( SUM( QTY), 0)   
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)  
         WHERE Mobile = @nMobile  
            AND Func = @nFunc) <> @nBulkSNOQTY  
      BEGIN  
         SET @nErrNo = 168059  
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
               SET @nErrNo = 168060  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackSNOFail  
               GOTO RollBackTran  
            END  
         END  
         ELSE  
         BEGIN  
            SET @nErrNo = 168061  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan  
            GOTO RollBackTran  
         END  
  
         DELETE rdt.rdtReceiveSerialNoLog   
         WHERE ReceiveSerialNoLogKey = @nReceiveSerialNoLogKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 168062  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL TmpSN Fail  
            GOTO RollBackTran  
         END   
  
         SET @nQTY_Bal = @nQTY_Bal - @nSerialQTY  
      END  
           
      -- Check fully offset  
      IF @nQTY_Bal <> 0  
      BEGIN  
         SET @nErrNo = 168063  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error   
         GOTO RollBackTran  
      END   
  
      -- Check balance  
      IF EXISTS( SELECT 1  
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)  
         WHERE Mobile = @nMobile  
            AND Func = @nFunc)  
      BEGIN  
         SET @nErrNo = 168064  
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
            SET @nErrNo = 168065  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RDSNo Fail  
            GOTO RollBackTran  
         END  
      END  
        
      -- Check serial no scanned  
      ELSE  
      BEGIN  
         SET @nErrNo = 168066  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan  
         GOTO RollBackTran  
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
            SET @nErrNo = 168067  
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
            SET @nErrNo = 168068  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PDInfoFail  
            GOTO RollBackTran  
         END  
      END  
   END     
  
   --YeeKung        
   EXEC RDT.rdt_STD_EventLog             
   @cActionType         = '3',                
   @nMobileNo           = @nMobile,          
   @nFunctionID         = @nFunc,          
   @cFacility           = @cFacility,          
   @cStorerKey          = @cStorerkey,         
   @nQTY                = @nQTY,            
   @cUCC                = @cUCCNo,      
   @cOrderKey           = @cOrderKey,      
   @cSKU                = @cSKU,    
   @cRefNo1             = @nCartonNo   
  
   COMMIT TRAN rdt_838ConfirmSP08  
   GOTO Quit  
  
RollBackTran:  
BEGIN  
   ROLLBACK TRAN rdt_838ConfirmSP08 -- Only rollback change made here  
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