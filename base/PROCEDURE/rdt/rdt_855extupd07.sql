SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_855ExtUpd07                                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 19-07-2021 1.0  Chermaine  WMS-17439 Created (dup rdt_855ExtUpd04)   */  
/* 28-03-2022 1.1  James      WMS-17439 Add ucc validate (james01)      */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_855ExtUpd07] (  
   @nMobile      INT,   
   @nFunc        INT,   
   @cLangCode    NVARCHAR( 3),   
   @nStep        INT,   
   @nInputKey    INT,   
   @cStorerKey   NVARCHAR( 15),    
   @cRefNo       NVARCHAR( 10),   
   @cPickSlipNo  NVARCHAR( 10),   
   @cLoadKey     NVARCHAR( 10),   
   @cOrderKey    NVARCHAR( 10),   
   @cDropID      NVARCHAR( 20),   
   @cSKU         NVARCHAR( 20),    
   @nQty         INT,    
   @cOption      NVARCHAR( 1),    
   @nErrNo       INT           OUTPUT,    
   @cErrMsg      NVARCHAR( 20) OUTPUT,   
   @cID          NVARCHAR( 18) = '',  
   @cTaskDetailKey   NVARCHAR( 10) = '',        
   @cReasonCode  NVARCHAR(20) OUTPUT         
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount    INT  
   DECLARE @cLastCarton    NVARCHAR( 1)  
   DECLARE @cFacility      NVARCHAR( 5)  
   DECLARE @cLabelPrinter  NVARCHAR( 10)  
   DECLARE @cPaperPrinter  NVARCHAR( 10)  
   DECLARE @cLblPrinterLK  NVARCHAR( 10)  
   DECLARE @cPprPrinterLK  NVARCHAR( 10)  
   DECLARE @cLabelLine     NVARCHAR( 5)  
   DECLARE @nCartonNo      INT  
   DECLARE @nPPA_QTY       INT  
   DECLARE @nPick_QTY      INT  
   DECLARE @nPack_QTY      INT  
   DECLARE @cPickConfirmStatus       NVARCHAR( 1)  
   DECLARE @cSkipChkPSlipMustScanOut NVARCHAR( 1)  
   DECLARE @cPrintShipLabel          NVARCHAR( 1)  
   DECLARE @cPrintCartonManifest     NVARCHAR( 1)  
   DECLARE @cPrintPackList           NVARCHAR( 1)  
   DECLARE @cCOO                     NVARCHAR( 20)  
   DECLARE @cPriceLabel              NVARCHAR( 10)  
   DECLARE @cPPACartonIDByPickDetailCaseID   NVARCHAR( 1)  
   DECLARE @cPPACartonIDByPackDetailLabelNo  NVARCHAR( 1)  
   DECLARE @cPPACartonIDByPackDetailDropID   NVARCHAR( 1)  
   DECLARE @cPrinter                 NVARCHAR( 10)  
   DECLARE @cDiscrepancyLabel        NVARCHAR( 20)  
   DECLARE @nFromCartonNo            INT  
   DECLARE @nToCartonNo             INT  
   DECLARE @cShipLabel               NVARCHAR( 10)  
   DECLARE @cCartonManifest          NVARCHAR( 10)  
   DECLARE @cPackList                NVARCHAR( 10)  
   DECLARE @cUserName                NVARCHAR( 128)  
     
   DECLARE @tPackList AS VariableTable  
   DECLARE @tShipLabel AS VariableTable  
   DECLARE @tCartonManifest AS VariableTable  

   DECLARE @cLabelNo    NVARCHAR( 20)
   DECLARE @cInField01  NVARCHAR( 60)
   DECLARE @nRowref     INT
   DECLARE @nRowCnt     INT
   DECLARE @nPQty       INT = 0
   DECLARE @nCQty       INT = 0
   
   SELECT   
      @cFacility = Facility,   
      @cLabelPrinter = Printer,  
      @cPaperPrinter = Printer_Paper,  
      @cCOO = V_String36,  
      @cUserName = UserName,
      @cInField01 = I_Field01  
   FROM RDT.RDTMobRec WITH (NOLOCK)   
   WHERE Mobile = @nMobile  
     
    
  
   SET @nTranCount = @@TRANCOUNT  
  
   IF @nFunc = 855 -- PPA (carton ID)  
   BEGIN  
      IF @nStep = 3 -- SKU, QTY  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            -- Storer configure  
            SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
            IF @cPickConfirmStatus = '0'  
               SET @cPickConfirmStatus = '5'  
            SET @cSkipChkPSlipMustScanOut = rdt.rdtGetConfig( @nFunc, 'SkipChkPSlipMustScanOut', @cStorerKey)  
            IF @cSkipChkPSlipMustScanOut = '0'  
               SET @cPickConfirmStatus = '5'  
            SET @cPPACartonIDByPackDetailDropID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailDropID', @cStorerKey)  
            SET @cPPACartonIDByPackDetailLabelNo = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailLabelNo', @cStorerKey)  
            SET @cPPACartonIDByPickDetailCaseID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorerKey)  
            SET @cPriceLabel = rdt.RDTGetConfig( @nFunc, 'PriceLabel', @cStorerKey)  
               IF @cPriceLabel = '0'  
                  SET @cPriceLabel = ''  
              
            -- Get session info  
            --SELECT   
            --   @cFacility = Facility,   
            --   @cLabelPrinter = Printer,  
            --   @cPaperPrinter = Printer_Paper,  
            --   @cCOO = V_String36  
            -- FROM RDT.RDTMobRec WITH (NOLOCK)   
            -- WHERE Mobile = @nMobile  
  
            -- Get PPA QTY  
            SELECT @nPPA_QTY = ISNULL( SUM( CQTY), 0)  
            FROM rdt.rdtPPA WITH (NOLOCK)  
            WHERE DropID = @cDropID  
               AND StorerKey = @cStorerKey  
               AND SKU = @cSKU  
  
            -- Get PickDetail QTY  
            --SELECT @nPick_QTY = ISNULL( SUM( QTY), 0)   
            --FROM dbo.PickDetail WITH (NOLOCK)   
            --WHERE DropID = @cDropID  
            --   AND StorerKey = @cStorerKey  
            --   AND SKU = @cSKU  
            --   AND [Status] <> '4'  
            --   AND [Status] >= @cPickConfirmStatus  
                 
            IF @cPPACartonIDByPickDetailCaseID = '1'  
            BEGIN  
             SELECT @nPick_QTY = ISNULL( SUM( QTY), 0)   
               FROM dbo.PickDetail WITH (NOLOCK)   
               WHERE caseID = @cDropID  
                  AND StorerKey = @cStorerKey  
                  AND SKU = @cSKU  
                  AND [Status] <> '4'  
                  AND [Status] >= @cPickConfirmStatus  
            END  
            ELSE IF @cPPACartonIDByPackDetailDropID = '1'  
            BEGIN  
             SELECT @nPick_QTY = ISNULL( SUM( QTY), 0)   
               FROM dbo.PackDetail WITH (NOLOCK)   
               WHERE dropID = @cDropID  
                  AND StorerKey = @cStorerKey  
                  AND SKU = @cSKU  
            END  
            ELSE  
            BEGIN  
             SELECT @nPick_QTY = ISNULL( SUM( QTY), 0)   
               FROM dbo.PickDetail WITH (NOLOCK)   
               WHERE DropID = @cDropID  
                  AND StorerKey = @cStorerKey  
                  AND SKU = @cSKU  
                  AND [Status] <> '4'  
                  AND [Status] >= @cPickConfirmStatus  
            END  
  
            -- Check exceed tolerance  
            IF @nPPA_QTY > @nPick_QTY  
               GOTO Quit  
  
            -- Get Orders info  
            SET @cLoadKey = ''  
            IF @cPPACartonIDByPickDetailCaseID = '1'  
            BEGIN  
               SELECT TOP 1 @cOrderKey = OrderKey FROM dbo.PickDetail WITH (NOLOCK) WHERE CaseID = @cDropID AND StorerKey = @cStorerKey  
            END  
            ELSE IF @cPPACartonIDByPackDetailDropID = '1'  
            BEGIN  
             SELECT TOP 1   
                @cOrderKey = PH.OrderKey   
             FROM dbo.PackDetail PD WITH (NOLOCK)   
             JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.pickslipNo = PD.pickslipNo AND PH.StorerKey = PD.StorerKey)  
             WHERE PD.DropID = @cDropID   
             AND PD.StorerKey = @cStorerKey  
            END  
            ELSE  
            BEGIN  
             SELECT TOP 1 @cOrderKey = OrderKey FROM dbo.PickDetail WITH (NOLOCK) WHERE DropID = @cDropID AND StorerKey = @cStorerKey  
            END  
            SELECT @cLoadKey = LoadKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey  
  
            -- Get PickHeader info  
            SET @cPickSlipNo = ''  
            SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  
            IF @cPickSlipNo = '' AND @cLoadKey <> ''  
               SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey  
  
            -- Check pick slip  
            IF @cPickSlipNo = ''  
            BEGIN  
               SET @nErrNo = 171551  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Pickslip No  
               GOTO Quit  
            END  
  
            -- Get PackDetail QTY    
            SET @nPack_QTY = 0  
            SELECT @nPack_QTY = ISNULL( SUM( QTY), 0)    -- ZG01  
            FROM dbo.PackDetail WITH (NOLOCK)     
            WHERE PickSlipNo = @cPickSlipNo    
               AND LabelNo = @cDropID    
               AND SKU = @cSKU    
               AND StorerKey = @cStorerKey    
             
            --IF ((@nPack_QTY + @nQTY) > @nPick_QTY)        
            IF ((@nPack_QTY) > @nPick_QTY)             
            BEGIN    
               SET @nErrNo = 171552    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Overpacked  
               GOTO Quit    
            END    
  
            BEGIN TRAN  -- Begin our own transaction  
            SAVE TRAN rdt_855ExtUpd07 -- For rollback or commit only our own transaction  
  
            ---- PackHeader  
            --IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)  
            --BEGIN  
            --   -- Insert PackHeader  
            --   INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, LoadKey, OrderKey)   
            --   VALUES (@cPickSlipNo, @cStorerKey, @cLoadKey, @cOrderKey)  
            --   IF @@ERROR <> 0  
            --   BEGIN  
            --      SET @nErrNo = 171553  
            --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackHdrFail  
            --      GOTO RollBackTran  
            --   END  
            --END  
  
            ---- PickingInfo  
            --IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)  
            --BEGIN  
            --   -- Insert PackHeader  
            --   INSERT INTO dbo.PickingInfo   
            --      (PickSlipNo, ScanInDate, PickerID)   
            --   VALUES   
            --      (@cPickSlipNo, GETDATE(), SUSER_SNAME())  
  
            --   IF @@ERROR <> 0  
            --   BEGIN  
            --      SET @nErrNo = 171554  
            --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPickInfFail  
            --      GOTO RollBackTran  
            --   END  
            --END  

            SELECT TOP 1 @cLabelNo = PD.LabelNo
            FROM dbo.PackHeader PH WITH (NOLOCK)
            JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            WHERE PD.DropID = @cDropID
            AND PH.StorerKey = @cStorerKey
            ORDER BY 1

            IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                        WHERE Storerkey = @cStorerKey
                        AND   UCCNo = @cLabelNo)
            BEGIN
   	         SELECT @nRowref = RowRef 
   	         FROM rdt.rdtPPA WITH (NOLOCK) 
   	         WHERE StorerKey = @cStorerKey
   	         AND   DropID = @cDropID
   	         AND   STATUS = '0'
   	         SELECT @nRowCnt = @@ROWCOUNT
   	         
               IF @cInField01 = @cLabelNo
               BEGIN
   	            IF @nRowCnt > 1
                  BEGIN
                     SET @nErrNo = 171562
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC ALDY SCAN
                     GOTO RollBackTran
                  END
                  ELSE
                  BEGIN
               	   UPDATE rdt.rdtPPA WITH (ROWLOCK) SET 
               	      PQty = CQty
               	   WHERE RowRef = @nRowref 
                  
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 171563
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RDTPPA ERR
                        GOTO RollBackTran
                     END
                  END
               END
               ELSE
               BEGIN
                  UPDATE rdt.rdtPPA WITH (ROWLOCK) SET 
                     Sku = 'WRONG_UCCNO', 
               	   PQTY = 0 
                  WHERE RowRef = @nRowref 
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 171564
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RDTPPA ERR
                     GOTO RollBackTran
                  END
               END
            END
            
            /*-------------------------------------------------------------------------------  
                                              PackDetail  
            -------------------------------------------------------------------------------*/  
            -- Check PackDetail exist  
            SET @nCartonNo = 0  
              
            IF @cPPACartonIDByPackDetailDropID = '1'  
            BEGIN  
             SELECT TOP 1   
                  @nCartonNo = CartonNo,  
                  @cLabelLine = LabelLine  
               FROM PackDetail WITH (NOLOCK)  
               WHERE PickSlipNo = @cPickSlipNo  
                  AND dropID = @cDropID  
                  AND StorerKey = @cStorerKey  
                  AND SKU = @cSKU  
                 
               UPDATE dbo.PackDetail WITH (ROWLOCK) SET  
                  EditWho = 'rdt.' + SUSER_SNAME(),  
                  EditDate = GETDATE()  
                  --LOTTABLEVALUE = @cCOO  
               WHERE StorerKey = @cStorerKey  
                  AND PickSlipNo = @cPickSlipNo  
                  AND CartonNo = @nCartonNo  
                  AND dropID = @cDropID  
                  AND LabelLine = @cLabelLine  
            END  
            ELSE  
            BEGIN  
             SELECT TOP 1   
                  @nCartonNo = CartonNo,  
                  @cLabelLine = LabelLine  
               FROM PackDetail WITH (NOLOCK)  
               WHERE PickSlipNo = @cPickSlipNo  
                  AND LabelNo = @cDropID  
                  AND StorerKey = @cStorerKey  
                  AND SKU = @cSKU  
                 
               UPDATE dbo.PackDetail WITH (ROWLOCK) SET  
                  EditWho = 'rdt.' + SUSER_SNAME(),  
                  EditDate = GETDATE()  
         --LOTTABLEVALUE = @cCOO  
               WHERE StorerKey = @cStorerKey  
                  AND PickSlipNo = @cPickSlipNo  
                  AND CartonNo = @nCartonNo  
                  AND LabelNo = @cDropID  
                  AND LabelLine = @cLabelLine  
            END  
              
                             
              
              
            --IF @nCartonNo = 0  
            --BEGIN  
            --   -- Insert PackDetail  
            --   INSERT INTO dbo.PackDetail  
            --      (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate,LOTTABLEVALUE)  
            --   VALUES  
            --      (@cPickSlipNo, @nCartonNo, @cDropID, '00001', @cStorerKey, @cSKU, @nQTY, @cDropID,  
            --      'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(),@cCOO)  
            --   IF @@ERROR <> 0  
            --   BEGIN  
            --      SET @nErrNo = 171555  
            --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail  
            --      GOTO RollBackTran  
            --   END  
  
            --   -- If insert cartonno = 0, system will auto assign max cartonno  
            --   SELECT TOP 1   
            --      @nCartonNo = CartonNo  
            --   FROM PackDetail WITH (NOLOCK)  
            --   WHERE PickSlipNo = @cPickSlipNo  
            --      AND SKU = @cSKU  
            --      AND AddWho = 'rdt.' + SUSER_SNAME()  
            --   ORDER BY CartonNo DESC -- max cartonno  
            --END  
            --ELSE  
            --BEGIN  
            --   -- Same carton, different SKU  
            --   SET @cLabelLine = ''   
            --   SELECT TOP 1   
            --      @cLabelLine = LabelLine  
            --   FROM dbo.PackDetail WITH (NOLOCK)  
            --   WHERE PickSlipNo = @cPickSlipNo  
            --      AND CartonNo = @nCartonNo  
            --      AND LabelNo = @cDropID  
            --      AND StorerKey = @cStorerKey  
            --      AND SKU = @cSKU  
  
            --   -- New SKU  
            --   IF @cLabelLine = ''   
            --   BEGIN  
            --      -- Get next Label No  
            --      SELECT @cLabelLine =   
            --         RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
            --      FROM dbo.PackDetail WITH (NOLOCK)  
            --      WHERE PickSlipNo = @cPickSlipNo  
            --         AND CartonNo = @nCartonNo  
                          
            --      -- Insert PackDetail  
            --      INSERT INTO dbo.PackDetail  
            --         (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate,LOTTABLEVALUE)  
            --      VALUES  
            --         (@cPickSlipNo, @nCartonNo, @cDropID, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cDropID,  
            --         'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(),@cCOO)  
            --      IF @@ERROR <> 0  
            --      BEGIN  
            --         SET @nErrNo = 171556  
            --         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail  
            --         GOTO RollBackTran  
            --      END  
            --   END  
            --   ELSE  
            --   BEGIN  
            --      UPDATE dbo.PackDetail WITH (ROWLOCK) SET  
            --         QTY = QTY + @nQTY,  
            --         EditWho = 'rdt.' + SUSER_SNAME(),  
            --         EditDate = GETDATE(),  
            --         LOTTABLEVALUE = @cCOO  
            --      WHERE StorerKey = @cStorerKey  
            --         AND PickSlipNo = @cPickSlipNo  
            --         AND CartonNo = @nCartonNo  
            --         AND LabelNo = @cDropID  
            --         AND LabelLine = @cLabelLine  
            --      IF @@ERROR <> 0  
            --      BEGIN  
            --         SET @nErrNo = 171557  
            --         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail  
            --         GOTO RollBackTran  
            --      END  
            --   END   -- DropID exists and SKU exists (update qty only)  
            --END  
              
            /*-------------------------------------------------------------------------------  
                                              PackDetailInfo  
            -------------------------------------------------------------------------------*/  
            -- PackInfo  
            IF @cCOO <> ''  
            BEGIN  
             DECLARE @nPackDetailInfoKey BIGINT    
             -- Get PackDetailInfo    
               SET @nPackDetailInfoKey = 0    
               SELECT @nPackDetailInfoKey = PackDetailInfoKey    
               FROM dbo.PackDetailInfo WITH (NOLOCK)     
               WHERE PickSlipNo = @cPickSlipNo     
                  AND CartonNo = @nCartonNo    
                  AND LabelNo = @cDropID     
                  AND SKU = @cSKU    
                  AND UserDefine01 = @cCOO    
           
               IF @nPackDetailInfoKey = ''  
               BEGIN  
                  -- Insert PackInfo  
                  INSERT INTO dbo.PackDetailInfo ( PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, UserDefine01, UserDefine02, UserDefine03,     
                              AddWho, AddDate, EditWho, EditDate)    
                  VALUES (@cPickSlipNo, @nCartonNo, @cDropID, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cCOO, '', '',  
                           'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 171560  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPkDtlInfoErr  
                     GOTO RollBackTran  
                  END  
               END  
               ELSE  
               BEGIN  
                UPDATE dbo.PackDetailInfo WITH (ROWLOCK) SET  
                     QTY = QTY + @nQTY,  
                     EditWho = 'rdt.' + SUSER_SNAME(),     
                     EditDate = GETDATE(),     
                     ArchiveCop = NULL    
                  WHERE StorerKey = @cStorerKey  
                     AND PickSlipNo = @cPickSlipNo  
                     AND CartonNo = @nCartonNo  
                     AND LabelNo = @cDropID  
                     AND LabelLine = @cLabelLine  
                     AND UserDefine01 = @cCOO  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 171561  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPkDtlInfoErr  
                     GOTO RollBackTran  
                  END  
               END  
            END  
                         
            -- PackInfo  
            IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)  
            BEGIN  
               -- Insert PackInfo  
               INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight, Cube, CartonType)  
               VALUES (@cPickSlipNo, @nCartonNo, 0, 0, '')  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 171558  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackInfFail  
                  GOTO RollBackTran  
               END  
            END  
  
            -- Get Total PickDetail Qty Added by (SHONG) on 12/05/2019 (Start)  
            IF @cPPACartonIDByPickDetailCaseID = '1'  
            BEGIN  
             SELECT @nPick_QTY = ISNULL( SUM( QTY), 0)    
               FROM dbo.PickDetail WITH (NOLOCK)   
               WHERE caseID = @cDropID  
                  AND PickSlipNo = @cPickSlipNo  
                  AND [Status] <> '4'  
                  AND [Status] >= @cPickConfirmStatus    
            END  
            ELSE IF @cPPACartonIDByPackDetailDropID = '1'  
            BEGIN  
             SELECT @nPick_QTY = ISNULL( SUM( QTY), 0)    
               FROM dbo.PackDetail WITH (NOLOCK)   
               WHERE dropID = @cDropID  
                  AND PickSlipNo = @cPickSlipNo  
            END  
            BEGIN  
             SELECT @nPick_QTY = ISNULL( SUM( QTY), 0)    
               FROM dbo.PickDetail WITH (NOLOCK)   
               WHERE DropID = @cDropID  
                  AND PickSlipNo = @cPickSlipNo  
                  AND [Status] <> '4'  
                  AND [Status] >= @cPickConfirmStatus    
            END  
                        
            -- (End)  
                        
            -- Get Packdetail QTY  
            SET @nPack_QTY = 0      -- ZG01       
            SELECT @nPack_QTY = ISNULL( SUM( QTY), 0)  
            FROM dbo.PackDetail WITH (NOLOCK)   
            WHERE PickSlipNo = @cPickSlipNo  
               AND LabelNo = @cDropID  
  
            -- Carton pick and pack tally, print ship label and carton manifest  
            IF @nPick_QTY = @nPack_QTY  
            BEGIN  
               SET @cPrintShipLabel = 'Y'  
               SET @cPrintCartonManifest = 'Y'  
            END  
  
            -- Check last carton  
            /*  
            Last carton logic:  
            1. If PickDetail is outstanding (PickDetail.Status = 0 or 4), definitely not last carton  
            2. If pick QTY tally pack QTY, all cartons packed, it is last carton  
            */  
            SET @cLastCarton = 'Y'   
  
            -- 1. Check outstanding PickDetail  
            -- Discrete   
            IF @cOrderKey <> ''  
            BEGIN  
               IF EXISTS( SELECT TOP 1 1   
                  FROM dbo.PickDetail WITH (NOLOCK)   
                  WHERE OrderKey = @cOrderKey  
                     AND Status IN ('0', '4'))  
                  SET @cLastCarton = 'N'  
            END   
              
            -- Conso  
            ELSE IF @cLoadKey <> ''  
            BEGIN  
               IF EXISTS( SELECT TOP 1 1   
                  FROM Orders O WITH (NOLOCK)  
                     JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
                  WHERE O.LoadKey = @cLoadKey  
                      AND PD.Status IN ('0', '4'))  
                  SET @cLastCarton = 'N'  
            END   
  
            -- 2. If pick QTY tally pack QTY, all cartons packed, it is last carton  
            IF @cLastCarton = 'Y'   
            BEGIN  
               -- Get Pickdetail QTY  
               -- Discreate  
               IF @cOrderKey <> ''   
                  SELECT @nPick_QTY = ISNULL( SUM( QTY), 0)  
                  FROM dbo.PickDetail WITH (NOLOCK)   
                  WHERE OrderKey = @cOrderKey  
                     AND Status NOT IN ('0', '4')  
  
               -- Conso  
               ELSE IF @cLoadKey <> ''  
                  SELECT @nPick_QTY = ISNULL( SUM( PD.QTY), 0)  
                  FROM Orders O WITH (NOLOCK)  
                     JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
                  WHERE O.LoadKey = @cLoadKey  
                      AND PD.Status NOT IN ('0', '4')  
  
               -- Get Packdetail QTY  
               SET @nPack_QTY = 0      -- ZG01       
               SELECT @nPack_QTY = ISNULL( SUM( QTY), 0) FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo  
                 
               -- Pickslip pick and pack tally, print pack list  
               IF @nPick_QTY <> @nPack_QTY  
                  SET @cLastCarton = 'N'  
            END    
  
            -- Last carton  
            IF @cLastCarton = 'Y'  
            BEGIN  
               ---- Pack confirm  
               --IF EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND [Status] < '9')    
               --BEGIN    
               --   UPDATE dbo.PackHeader WITH (ROWLOCK) SET   
               --      [Status] = '9',   
               --      EditDate = GETDATE(),   
               --      EditWho = SUSER_SNAME()  
               --   WHERE PickSlipNo = @cPickSlipNo  
               --   IF @@ERROR <> 0  
               --   BEGIN  
               --      SET @nErrNo = 171559  
               --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail  
               --      GOTO RollBackTran  
               --   END  
               --END  
                 
               -- Print pack list  
               SET @cPrintPackList = 'Y'  
            END  
  
            COMMIT TRAN rdt_855ExtUpd07  
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
               COMMIT TRAN  
  
            ---- Print ship label  
            --IF @cPrintShipLabel = 'Y'  
            --BEGIN  
            --   DECLARE @cShipLabel NVARCHAR( 10)  
            --   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)  
            --   IF @cShipLabel = '0'  
            --      SET @cShipLabel = ''  
  
            --   -- Ship label  
            --   IF @cShipLabel <> ''   
            --   BEGIN  
            --      -- Common params  
            --      DECLARE @tShipLabel AS VariableTable  
            --      INSERT INTO @tShipLabel (Variable, Value) VALUES   
            --         ( '@cStorerKey',     @cStorerKey),   
            --         ( '@cPickSlipNo',    @cPickSlipNo),   
            --         ( '@cLabelNo',       @cDropID),   
            --         ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))  
  
            --      -- Print label  
            --      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
            --         @cShipLabel, -- Report type  
            --         @tShipLabel, -- Report params  
            --         'rdt_855ExtUpd07',   
            --         @nErrNo  OUTPUT,  
            --         @cErrMsg OUTPUT  
                    
            --      IF @nErrNo <> 0  
            --      BEGIN  
            --         SET @nErrNo = 0 -- To let parent commit  
            --         GOTO Quit  
            --      END  
            --   END  
            --END  
              
            ---- Print carton manifest  
            --IF @cPrintCartonManifest = 'Y'  
            --BEGIN  
            --   DECLARE @cCartonManifest NVARCHAR( 10)  
            --   SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)  
            --   IF @cCartonManifest = '0'  
            --      SET @cCartonManifest = ''  
  
            --   -- Carton manifest  
            --   IF @cCartonManifest <> ''  
            --   BEGIN  
            --      -- Common params  
            --      DECLARE @tCartonManifest AS VariableTable  
            --      INSERT INTO @tCartonManifest (Variable, Value) VALUES   
            --         ( '@cStorerKey',     @cStorerKey),   
            --         ( '@cPickSlipNo',    @cPickSlipNo),   
            --         ( '@cLabelNo',       @cDropID),   
            --         ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))  
  
            --      -- Print label  
            --      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
            --         @cCartonManifest, -- Report type  
            --         @tCartonManifest, -- Report params  
            --         'rdt_855ExtUpd07',   
            --         @nErrNo  OUTPUT,  
            --         @cErrMsg OUTPUT  
                    
            --      IF @nErrNo <> 0  
            --      BEGIN  
            --         SET @nErrNo = 0 -- To let parent commit  
            --         GOTO Quit  
            --      END  
            --   END  
            --END  
  
            ---- Print pack list  
            --IF @cPrintPackList = 'Y'  
            --BEGIN  
            --   DECLARE @cPackList NVARCHAR( 10)  
            --   SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PACKLIST', @cStorerKey)  
            --   IF @cPackList = '0'  
            --      SET @cPackList = ''  
                 
            --   IF @cPackList <> ''              --   BEGIN  
            --      -- Common params  
            --      DECLARE @tPackList AS VariableTable  
            --      INSERT INTO @tPackList (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)  
  
            --      -- Print label  
            --      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
            --         @cPackList, -- Report type  
            --         @tPackList, -- Report params  
            --         'rdt_855ExtUpd07',   
            --         @nErrNo  OUTPUT,  
            --         @cErrMsg OUTPUT  
  
            --      IF @nErrNo <> 0  
            --      BEGIN  
            --         SET @nErrNo = 0 -- To let parent commit  
            --         GOTO Quit  
            --      END  
            --   END  
            --END  
              
            IF @cPriceLabel <> ''  
            BEGIN  
             IF @cCOO <> ''  
             BEGIN  
              -- Common params  
                  DECLARE @tPriceLabel AS VariableTable  
                  INSERT INTO @tPriceLabel (Variable, Value) VALUES ( '@cLabelNo', @cDropID)  
                  INSERT INTO @tPriceLabel (Variable, Value) VALUES ( '@cSKU', @cSKU)  
                  INSERT INTO @tPriceLabel (Variable, Value) VALUES ( '@nQty', @nQty)  
  
                  -- Print priceLabel  
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
                     @cPriceLabel, -- Report type  
                     @tPriceLabel, -- Report params  
                     'rdt_855ExtUpd07',   
                     @nErrNo  OUTPUT,  
                     @cErrMsg OUTPUT  
  
                  IF @nErrNo <> 0  
                  BEGIN  
                     SET @nErrNo = 0 -- To let parent commit  
                     GOTO Quit  
                  END  
             END  
            END  
         END  
      END  
        
      IF @nStep = 4 -- Discrepancy  
      BEGIN  
         IF @cOption = '1' --sent to QC  
         BEGIN                     
          SET @cDiscrepancyLabel = rdt.RDTGetConfig( @nFunc, 'DiscrepancyLbl', @cStorerKey)     
            IF @cDiscrepancyLabel = '0'  
               SET @cDiscrepancyLabel = ''  
        
            IF @cDiscrepancyLabel <> ''  
          BEGIN  
               SELECT   
                  @cPprPrinterLK = long ,  
                  @cLblPrinterLK = long   
               FROM codelkup (NOLOCK)   
               WHERE listname = 'RDTPRINTER'   
               AND Storerkey = @cStorerKey   
               AND short = @nFunc   
               AND UDF01 = 'VARIANCELBL'   
               AND UDF02 = @cUserName  
                 
               IF ISNULL(@cPprPrinterLK,'') <> ''  
               BEGIN  
                SET @cLabelPrinter = @cLblPrinterLK  
                SET @cPaperPrinter = @cPprPrinterLK  
               END  
                 
             DECLARE @tDiscrepancyLabels AS VariableTable  
             INSERT INTO @tDiscrepancyLabels (Variable, Value) VALUES ( '@cStorerKey',@cStorerKey)  
             INSERT INTO @tDiscrepancyLabels (Variable, Value) VALUES ( '@cPickSlipNo','')  
             INSERT INTO @tDiscrepancyLabels (Variable, Value) VALUES ( '@cID','')  
               INSERT INTO @tDiscrepancyLabels (Variable, Value) VALUES ( '@cDropID',@cDropID)  
  
             -- Print label  
             EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
              @cDiscrepancyLabel, -- Report type  
              @tDiscrepancyLabels, -- Report params  
              'rdtfnc_PostPickAudit',  
              @nErrNo  OUTPUT,  
              @cErrMsg OUTPUT  
  
             IF @nErrNo <> 0  
               GOTO Quit  
          END  
         END  
      END   
  
      IF @nStep = 2 --summary  
      BEGIN  
         IF @nInputKey = 0 -- ESC  
         BEGIN         
            IF (NOT EXISTS (SELECT 1       
                             FROM PackDetail PD WITH (NOLOCK)       
                             LEFT JOIN RDT.RDTPPA R (NOLOCK) ON PD.STORERKEY = R.STORERKEY AND PD.DROPID = R.DROPID AND PD.SKU = R.SKU    
                             WHERE PD.StorerKey = @cStorerKey       
                             AND PD.DropID = @cDropID       
                             AND Qty <> ISNULL(R.CQty,0))  )    
                  AND (NOT EXISTS (SELECT 1 FROM RDT.RDTPPA R WITH (NOLOCK)    
                               WHERE R.StorerKey = @cStorerKey    
                               AND R.DropID = @cDropID    
                               AND CQty > 0    
                               AND NOT EXISTS (SELECT 1 FROM PackDetail PD WITH (NOLOCK)    
                                               WHERE PD.STORERKEY = R.STORERKEY AND PD.DROPID = R.DROPID AND PD.SKU = R.SKU)))    
            BEGIN       
               -- Print ship label        
               SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)        
               IF @cShipLabel = '0'        
                  SET @cShipLabel = ''        
        
               -- Ship label        
               IF @cShipLabel <> ''         
               BEGIN        
                  -- Common params        
                  INSERT INTO @tShipLabel (Variable, Value) VALUES  ( '@cDropID',  @cDropID)        
        
                  -- Print label        
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,         
                     @cShipLabel, -- Report type        
                     @tShipLabel, -- Report params        
                     'rdt_855ExtUpd07',         
                     @nErrNo  OUTPUT,        
                     @cErrMsg OUTPUT        
                          
                  IF @nErrNo <> 0        
                  BEGIN        
                     SET @nErrNo = 0 -- To let parent commit        
                     GOTO Quit        
                  END        
               END        
                    
               -- Print carton manifest        
               SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)        
               IF @cCartonManifest = '0'        
                  SET @cCartonManifest = ''        
        
               -- Carton manifest        
               IF @cCartonManifest <> ''        
               BEGIN        
                  -- Common params        
                  INSERT INTO @tCartonManifest (Variable, Value) VALUES ( '@cDropID', @cDropID)        
        
                  -- Print label        
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,         
                     @cCartonManifest, -- Report type        
                     @tCartonManifest, -- Report params        
                     'rdt_855ExtUpd07',         
                     @nErrNo  OUTPUT,        
                     @cErrMsg OUTPUT        
                          
                  IF @nErrNo <> 0        
                  BEGIN        
                     SET @nErrNo = 0 -- To let parent commit        
                     GOTO Quit        
                  END        
               END        
        
               -- Print pack list        
               SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PACKLIST', @cStorerKey)        
               IF @cPackList = '0'        
                  SET @cPackList = ''        
                       
               IF @cPackList <> ''        
               BEGIN        
                  -- Common params        
                  INSERT INTO @tPackList (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)        
        
                  -- Print label        
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,         
                     @cPackList, -- Report type        
                     @tPackList, -- Report params        
                     'rdt_855ExtUpd07',         
                     @nErrNo  OUTPUT,        
                     @cErrMsg OUTPUT        
        
                  IF @nErrNo <> 0        
                  BEGIN        
                     SET @nErrNo = 0 -- To let parent commit        
                     GOTO Quit        
                  END        
               END          
            END     
         END  
      END  
        
      IF @nStep = 8 -- cartonInfo  
      BEGIN  
        IF @nInputKey = 1 -- ENTER  
        BEGIN  
          -- Print ship label                 
            SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)  
            IF @cShipLabel = '0'  
               SET @cShipLabel = ''  
  
            -- Ship label  
            IF @cShipLabel <> ''   
            BEGIN  
               -- Common params  
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cDropID',@cDropID)  
  
               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
                  @cShipLabel, -- Report type  
                  @tShipLabel, -- Report params  
                  'rdt_855ExtUpd07',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT  
                    
               IF @nErrNo <> 0  
               BEGIN  
                  SET @nErrNo = 0 -- To let parent commit  
                  GOTO Quit  
               END  
            END  
              
            -- Print carton manifest  
            SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)  
            IF @cCartonManifest = '0'  
               SET @cCartonManifest = ''  
  
            -- Carton manifest  
            IF @cCartonManifest <> ''  
            BEGIN  
               -- Common params  
               INSERT INTO @tCartonManifest (Variable, Value) VALUES ('@cDropID', @cDropID)  
  
               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
                  @cCartonManifest, -- Report type  
                  @tCartonManifest, -- Report params  
                  'rdt_855ExtUpd07',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT  
                    
               IF @nErrNo <> 0  
               BEGIN  
                  SET @nErrNo = 0 -- To let parent commit  
                  GOTO Quit  
               END  
            END  
  
            -- Print pack list  
            SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PACKLIST', @cStorerKey)  
            IF @cPackList = '0'  
               SET @cPackList = ''  
                 
            IF @cPackList <> ''  
            BEGIN  
               -- Common params  
               INSERT INTO @tPackList (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)  
  
               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
                  @cPackList, -- Report type  
                  @tPackList, -- Report params  
                  'rdt_855ExtUpd07',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT  
  
               IF @nErrNo <> 0  
               BEGIN  
                  SET @nErrNo = 0 -- To let parent commit  
                  GOTO Quit  
               END  
            END  
       END  
      END  
   END  
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_855ExtUpd07  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO