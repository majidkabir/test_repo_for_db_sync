SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtUpd09                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2022-11-10  1.0  James    WMS-21135. Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1638ExtUpd09] (
   @nMobile      INT,           
   @nFunc        INT,           
   @nStep        INT,
   @nAfterStep   INT,        
   @nInputKey    INT,           
   @cLangCode    NVARCHAR( 3),  
   @cFacility    NVARCHAR( 5),  
   @cStorerkey   NVARCHAR( 15), 
   @cPalletKey   NVARCHAR( 30), 
   @cCartonType  NVARCHAR( 10), 
   @cCaseID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,            
   @cLength      NVARCHAR(5),    
   @cWidth       NVARCHAR(5),    
   @cHeight      NVARCHAR(5),    
   @cGrossWeight NVARCHAR(5),    
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @bSuccess       INT
   DECLARE @cWeight        NVARCHAR( 10)
   DECLARE @cCube          NVARCHAR( 10)
   DECLARE @nUseSequence   INT
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nCartonNo      INT
   DECLARE @cRefNo         NVARCHAR( 20)
   DECLARE @cMBOLKey       NVARCHAR( 10)
   DECLARE @cChkStatus     NVARCHAR( 10)
   DECLARE @cChkFacility   NVARCHAR( 5)
   DECLARE @cCapturePackInfo  NVARCHAR( 10)
   DECLARE 
      @nCtnCnt1 INT = '', 
      @nCtnCnt2 INT = '', 
      @nCtnCnt3 INT = '', 
      @nCtnCnt4 INT = '', 
      @nCtnCnt5 INT = '', 
      @cUDF01   NVARCHAR(20) = '', 
      @cUDF02   NVARCHAR(20) = '', 
      @cUDF03   NVARCHAR(20) = '', 
      @cUDF04   NVARCHAR(20) = '', 
      @cUDF05   NVARCHAR(20) = '', 
      @cUDF09   NVARCHAR(10) = '', 
      @cUDF10   NVARCHAR(10) = ''
   DECLARE @cCartonLbl     NVARCHAR( 10)
   DECLARE @tCartonLbl     VARIABLETABLE
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @curMbol        CURSOR
   DECLARE @curLoad        CURSOR
               
   SELECT 
      @cLabelPrinter = Printer, 
      @cPickSlipNo = V_PickSlipNo,
      @nCartonNo = V_CartonNo,
      @cCapturePackInfo = V_String5,
      @cWeight = I_Field02,
      @cCube = I_Field03,
      @cRefNo = I_Field04
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
               
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1638ExtUpd09   

   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
   	IF @nStep = 3
   	BEGIN
         SET @cCartonLbl = rdt.RDTGetConfig( @nFunc, 'CartonLbl', @cStorerkey)    
         IF @cCartonLbl = '0'    
            SET @cCartonLbl = ''  

         IF @cCartonLbl <> ''
         BEGIN
            SELECT TOP 1  
               @cPickSlipNo = PickSlipNo, 
               @nCartonNo = CartonNo  
            FROM dbo.PackDetail WITH (NOLOCK)  
            WHERE LabelNo = @cCaseID  
            AND   StorerKey = @cStorerKey  
            ORDER BY LabelLine 

            INSERT INTO @tCartonLbl (Variable, Value) VALUES ( '@cStorerKey',    @cStorerKey)  
            INSERT INTO @tCartonLbl (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)  
            INSERT INTO @tCartonLbl (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)  
            INSERT INTO @tCartonLbl (Variable, Value) VALUES ( '@nToCartonNo',   @nCartonNo)
              
            -- Print label  
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '',   
               @cCartonLbl, -- Report type  
               @tCartonLbl, -- Report params  
               'rdt_1638ExtUpd09',   
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT
            
            IF @nErrNo <> 0
               GOTO RollBackTran
         END   
   	END
   	
      IF @nStep = 7    -- Close pallet
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get MBOL info  
            SELECT   
               @cMBOLKey = MBOLKey,   
               @cChkStatus = Status,   
               @cChkFacility = Facility  
            FROM MBOL WITH (NOLOCK)  
            WHERE ExternMbolKey = @cPalletKey  

            -- Create MBOL  
            IF @@ROWCOUNT = 0  
            BEGIN  
               -- Get MBOLKey  
               EXECUTE nspg_GetKey  
                  'MBOL',  
                  10,  
                  @cMBOLKey   OUTPUT,  
                  @bSuccess   OUTPUT,  
                  @nErrNo     OUTPUT,  
                  @cErrMsg    OUTPUT  
               IF @bSuccess <> 1  
               BEGIN  
                  SET @nErrNo = 193802  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail  
                  GOTO RollBackTran  
               END  
           
               -- Insert MBOL  
               INSERT INTO MBOL (MBOLKey, ExternMBOLKey, Facility, STATUS, Remarks) VALUES (@cMBOLKey, @cPalletKey, @cFacility, '0', 'ECOM')  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 193803  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBOL Fail  
                  GOTO RollBackTran  
               END  
            END  
            ELSE  
            BEGIN  
               -- Check MBOL status  
               IF @cChkStatus = '9'  
               BEGIN  
                  SET @nErrNo = 193804  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL shipped  
                  GOTO RollBackTran  
               END  
  
               -- Check MBOL facility  
               IF @cChkFacility <> @cFacility  
               BEGIN  
                  SET @nErrNo = 193805  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL FAC Diff  
                  GOTO RollBackTran  
               END  
            END

            SET @curLoad = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
            SELECT DISTINCT CaseId   
            FROM dbo.PALLETDETAIL WITH (NOLOCK)  
            WHERE PalletKey = @cPalletKey  
            AND   StorerKey = @cStorerkey  
            ORDER BY 1
            OPEN @curLoad  
            FETCH NEXT FROM @curLoad INTO @cCaseID  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               -- Retrieve current pickslipno  
               SELECT TOP 1 @cPickSlipNo = PickSlipNo  
               FROM dbo.PackDetail WITH (NOLOCK)   
               WHERE StorerKey = @cStorerKey  
               AND   LabelNo = @cCaseID  
               ORDER BY 1  
               
               SELECT @cLoadKey = LoadKey
               FROM dbo.PackHeader WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo

               IF ISNULL( @cLoadKey, '') = ''
               BEGIN    
                  SET @nErrNo = 193801    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No LoadKey'    
                  GOTO RollBackTran    
               END 
            
               SET @curMbol = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT LPD.OrderKey
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               WHERE LPD.LoadKey = @cLoadKey
               AND   NOT EXISTS ( SELECT 1 FROM dbo.MBOLDETAIL MD WITH (NOLOCK)
                                  WHERE MbolKey = @cMBOLKey 
                                  AND   LPD.OrderKey = MD.OrderKey)
               ORDER BY 1
               OPEN @curMbol
               FETCH NEXT FROM @curMbol INTO @cOrderKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  INSERT INTO dbo.MBOLDetail 
                     (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, AddDate, EditWho, EditDate)
                  VALUES 
                     (@cMBOLKey, '00000', @cOrderKey, @cLoadKey, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())  

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 193806
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBDtl Fail
                     GOTO RollbackTran
                  END
            
                  FETCH NEXT FROM @curMbol INTO @cOrderKey
               END
               CLOSE @curMbol
               DEALLOCATE @curMbol
               
               FETCH NEXT FROM @curLoad INTO @cCaseID
            END
            
            -- Submit for MBOL validation (backend job)    
            UPDATE MBOL SET    
               Status = '5',     
               EditWho = SUSER_SNAME(),    
               EditDate = GETDATE(),     
               TrafficCop = NULL    
            WHERE MBOLKey = @cMBOLKey    
            AND   Status = '0'

            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 193807    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MBOL Fail    
               GOTO RollbackTran  
            END    
         END
      END
   END

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_1638ExtUpd09 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN   
END

GO