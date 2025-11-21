SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtUpd15                                     */
/* Purpose: Pack confirm                                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-07-16 1.0  James      WMS-17472. Created                        */
/* 2022-09-20 1.1  James      WMS-20831 Change printing to use          */
/*                            rdt_rdtprint (james01)                    */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtUpd15] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cStorerkey  NVARCHAR( 15), 
   @cOrderKey   NVARCHAR( 10), 
   @cPickSlipNo NVARCHAR( 10), 
   @cTrackNo    NVARCHAR( 20), 
   @cSKU        NVARCHAR( 20), 
   @nCartonNo   INT,
   @cSerialNo   NVARCHAR( 30), 
   @nSerialQTY  INT,   
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @nTranCount        INT, 
           @nExpectedQty      INT,
           @nPackedQty        INT, 
           @cReportType       NVARCHAR( 10),
           @cPrintJobName     NVARCHAR( 50), 
           @cDataWindow       NVARCHAR( 50),
           @cTargetDB         NVARCHAR( 20), 
           @cPrinter          NVARCHAR( 10), 
           @cPrinter_Paper    NVARCHAR( 10), 
           @cLoadKey          NVARCHAR( 10),
           @cShipperKey       NVARCHAR( 15),
           @bSuccess          INT,           
           @cFacility         NVARCHAR( 5),  
           @cAutoMBOLPack     NVARCHAR( 1),   
           @cStatus           NVARCHAR( 10),
           @cPackCfmStatus    NVARCHAR( 10),
           @cLabelNo          NVARCHAR( 20),
           @cLabelLine        NVARCHAR( 5),
           @cErrMsg01         NVARCHAR( 20),
           @cErrMsg02         NVARCHAR( 20),
           @nPrintLabel       INT = 0, 
           @nDataDeletedMsg   INT = 0
           
   SELECT @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_840ExtUpd15
   
   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cStatus = [Status]
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
         IF @cStatus >= '2' AND @cStatus < '5'
         BEGIN
            SELECT 
               @cPickSlipNo = PickSlipNo,
               @cPackCfmStatus = [Status]
            FROM dbo.PackHeader WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey

            IF @cPackCfmStatus = '9'
            BEGIN  
               SET @nErrNo = 171401  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ord Pack Cfm       
               GOTO RollBackTran    
            END  
            
            IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
            BEGIN
               DECLARE @curDelPD CURSOR
               SET @curDelPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT CartonNo, LabelNo, LabelLine
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               OPEN @curDelPD
               FETCH NEXT FROM @curDelPD INTO @nCartonNo, @cLabelNo, @cLabelLine
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  DELETE FROM dbo.PackDetail
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   CartonNo = @nCartonNo
                  AND   LabelNo = @cLabelNo
                  AND   LabelLine = @cLabelLine
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 171402  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Del Pack Fail      
                     GOTO RollBackTran    
                  END
                  
                  FETCH NEXT FROM @curDelPD INTO @nCartonNo, @cLabelNo, @cLabelLine
               END
               
               DELETE FROM PackHeader 
               WHERE PickSlipNo = @cPickSlipNo

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 171403  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Del Pack Fail       
                  GOTO RollBackTran    
               END

               SET @nDataDeletedMsg = 1
            END
         END
      END
   END
   
   IF @nStep = 3
   BEGIN
      -- 1 orders 1 tracking no    
      -- discrete pickslip, 1 ordes 1 pickslipno    
      SET @nExpectedQty = 0    
      SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey    
         AND Storerkey = @cStorerkey    
         AND Status < '9'    
 
      SET @nPackedQty = 0    
      SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
         AND Storerkey = @cStorerkey    

      -- all SKU and qty has been packed, pack confirm it
      IF @nExpectedQty = @nPackedQty       
      BEGIN
         -- Pack confirm
         IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND [Status] < '9')
         BEGIN
            SET @nErrNo = 0
            EXEC nspGetRight  
                  @c_Facility   = @cFacility    
               ,  @c_StorerKey  = @cStorerKey   
               ,  @c_sku        = ''         
               ,  @c_ConfigKey  = 'AutoMBOLPack'   
               ,  @b_Success    = @bSuccess             OUTPUT  
               ,  @c_authority  = @cAutoMBOLPack        OUTPUT   
               ,  @n_err        = @nErrNo               OUTPUT  
               ,  @c_errmsg     = @cErrMsg              OUTPUT  
  
            IF @nErrNo <> 0   
            BEGIN  
               SET @nErrNo = 171404  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetRightFail       
               GOTO RollBackTran    
            END  
  
            IF @cAutoMBOLPack = '1'  
            BEGIN  
               SET @nErrNo = 0
               EXEC dbo.isp_QCmd_SubmitAutoMbolPack  
                 @c_PickSlipNo= @cPickSlipNo  
               , @b_Success   = @bSuccess    OUTPUT      
               , @n_Err       = @nErrNo      OUTPUT      
               , @c_ErrMsg    = @cErrMsg     OUTPUT   
           
               IF @nErrNo <> 0   
               BEGIN  
                  SET @nErrNo = 171405  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AutoMBOLPack       
                  GOTO RollBackTran    
               END     
            END  
            
            UPDATE dbo.PackHeader SET
               STATUS = '9',
               EditWho = 'rdt.' + SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 171406
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Packcfm fail
               GOTO RollBackTran            
            END
         END
         
         SET @nPrintLabel = 1
      END
   END

   GOTO Quit
   
   RollBackTran:
      ROLLBACK TRAN rdt_840ExtUpd15  

   Quit:
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  

   IF @nStep = 1
   BEGIN
      IF @nDataDeletedMsg = 1
      BEGIN
         SET @cErrMsg01 = ''  
         SET @cErrMsg02 = ''
         SET @cErrMsg01 = rdt.rdtgetmessage( 171411, @cLangCode, 'DSP')  -- Pack Data Exists
         SET @cErrMsg02 = rdt.rdtgetmessage( 171412, @cLangCode, 'DSP')  -- And Deleted
         SET @nErrNo = 0  
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01, @cErrMsg02
         SET @nErrNo = 0              
         GOTO Quit_SP
      END   
   END
   
   IF @nStep = 3
   BEGIN
      IF @nPrintLabel = 1
      BEGIN
         -- User scanned something
         IF EXISTS (SELECT 1 FROM rdt.rdtTrackLog WITH (NOLOCK)  
                    WHERE AddWho = SUSER_SNAME())  
         BEGIN
            SELECT @cPrinter = Printer, 
                   @cPrinter_Paper = Printer_Paper
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

            DECLARE @tPACKLIST AS VariableTable
            INSERT INTO @tPACKLIST (Variable, Value) VALUES ( '@cStorerKey',  @cStorerKey)
            INSERT INTO @tPACKLIST (Variable, Value) VALUES ( '@cOrderKey',   @cOrderKey)

            -- Print label
            SET @nErrNo = 0
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPrinter_Paper, 
               'PACKLIST', -- Report type
               @tPACKLIST, -- Report params
               'rdt_840ExtUpd15', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT 
                     
            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 171409
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSERTPRTFAIL
               GOTO Fail  
            END

            SELECT @cLoadKey = ISNULL(RTRIM(LoadKey), ''),
                     @cShipperKey = ISNULL(RTRIM(ShipperKey), '')
            FROM dbo.Orders WITH (NOLOCK)
            WHERE Storerkey = @cStorerkey
            AND   Orderkey = @cOrderkey

            IF ISNULL( @cShipperKey, '') = ''
            BEGIN
               SET @nErrNo = 171410
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV SHIPPERKEY
               GOTO Fail  
            END

            DECLARE @tSHIPPLABEL AS VariableTable
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLoadKey',  @cLoadKey)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',  @cOrderKey)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cShipperKey',  @cShipperKey)

            -- Print label
            SET @nErrNo = 0
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cPrinter, '', 
               'SHIPPLABEL', -- Report type
               @tSHIPPLABEL, -- Report params
               'rdt_840ExtUpd15', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT 

            IF @nErrNo <> 0
               GOTO Fail  
         END
      END
   END
   
   Fail:
   Quit_SP:

GO