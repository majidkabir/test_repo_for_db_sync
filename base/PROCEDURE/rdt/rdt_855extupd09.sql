SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_855ExtUpd09                                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2023-04-28 1.0  James      WMS-22322. Created                        */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_855ExtUpd09] (  
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
      
   DECLARE @cFacility      NVARCHAR( 5)      
   DECLARE @cLabelPrinter  NVARCHAR( 10)      
   DECLARE @cPaperPrinter  NVARCHAR( 10)      
   DECLARE @cLblPrinterLK  NVARCHAR( 10)      
   DECLARE @cPprPrinterLK  NVARCHAR( 10)      
   DECLARE @cDiscrepancyLabel        NVARCHAR( 20)      
   DECLARE @cShipLabel               NVARCHAR( 10)      
   DECLARE @cUserName                NVARCHAR( 128)    
   DECLARE @nRowRef        INT      
   DECLARE @nPackQty       INT = 0    
   DECLARE @nPPAQty        INT = 0    
   DECLARE @nTranCount     INT    
   DECLARE @nCartonNo      INT    
   DECLARE @cLabelNo       NVARCHAR( 20)    
   DECLARE @cLabelLine     NVARCHAR( 5)    
       
   SELECT       
      @cFacility = Facility,       
      @cLabelPrinter = Printer,      
      @cPaperPrinter = Printer_Paper,      
      @cUserName = UserName      
   FROM RDT.RDTMobRec WITH (NOLOCK)       
   WHERE Mobile = @nMobile      
        
   IF @nFunc = 855 -- PPA (carton ID)      
   BEGIN      
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
               -- Handling transaction                
               SET @nTranCount = @@TRANCOUNT                
               BEGIN TRAN  -- Begin our own transaction                
               SAVE TRAN rdt_855ExtUpd09 -- For rollback or commit only our own transaction        
    
               DECLARE @curUpdOrd CURSOR    
               SET @curUpdOrd = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
               SELECT DISTINCT OrderKey    
               FROM dbo.PackDetail PD WITH (NOLOCK)    
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)    
               WHERE PD.StorerKey = @cStorerKey    
               AND   PD.DropID = @cDropID    
               OPEN @curUpdOrd    
               FETCH NEXT FROM @curUpdOrd INTO @cOrderKey    
               WHILE @@FETCH_STATUS = 0    
               BEGIN    
                IF EXISTS ( SELECT 1     
                            FROM dbo.ORDERS WITH (NOLOCK)    
                            WHERE OrderKey = @cOrderKey    
                            AND   [Status] < '9')    
                  BEGIN    
                   SELECT @nPackQty = ISNULL( SUM( Qty), 0)    
                   FROM dbo.PackDetail PD WITH (NOLOCK)    
                   JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)    
                   WHERE PH.OrderKey = @cOrderKey    
                       
                   SELECT @nPPAQty = ISNULL( SUM( CQty), 0)    
                   FROM rdt.RDTPPA PPA WITH (NOLOCK)    
                   WHERE StorerKey = @cStorerKey    
                   AND   EXISTS ( SELECT 1     
                                  FROM dbo.PackDetail PD WITH (NOLOCK)    
                                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)    
                                  WHERE PH.OrderKey = @cOrderKey    
                                  AND   PD.DropID = PPA.DropID    
                                  AND   PD.SKU = PPA.Sku)    
    
                     IF @nPackQty = @nPPAQty AND @nPackQty > 0 AND @nPPAQty > 0    
                     BEGIN    
                      UPDATE dbo.ORDERS SET     
                         UserDefine04 = 'PPADONE',    
                         EditWho = SUSER_SNAME(),    
                         EditDate = GETDATE()    
                      WHERE OrderKey = @cOrderKey    
                          
                      IF @@ERROR <> 0    
                      BEGIN    
                           SET @nErrNo = 201751    
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD ORD Fail    
                           GOTO RollBackTran    
                      END    
                     END    
                  END    
                      
                FETCH NEXT FROM @curUpdOrd INTO @cOrderKey    
               END    
    
               DECLARE @curUpdPack CURSOR    
               SET @curUpdPack = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
               SELECT PickSlipNo, CartonNo, LabelNo, LabelLine    
               FROM dbo.PackDetail WITH (NOLOCK)    
               WHERE StorerKey = @cStorerKey    
               AND   DropID = @cDropID    
               OPEN @curUpdPack    
               FETCH NEXT FROM @curUpdPack INTO @cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine    
               WHILE @@FETCH_STATUS = 0    
               BEGIN    
                    
                  UPDATE dbo.PackDetail SET     
                     RefNo2 = CASE ISNULL(RefNo2,'') WHEN '' THEN @cDropID ELSE RefNo2 END,    
                     DropID = @cLabelNo,    
                     EditWho = SUSER_SNAME(),    
                     EditDate = GETDATE()    
                  WHERE PickSlipNo = @cPickSlipNo    
                  AND   CartonNo = @nCartonNo    
                  AND   LabelNo = @cLabelNo    
                  AND   LabelLine = @cLabelLine    
    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 201752    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Pack Fail    
                     GOTO RollBackTran    
                  END    
                          
                FETCH NEXT FROM @curUpdPack INTO @cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine    
               END    
                   
               DECLARE @curUpdPPA CURSOR    
               SET @curUpdPPA = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
               SELECT RowRef     
               FROM rdt.RDTPPA WITH (NOLOCK)     
               WHERE StorerKey = @cStorerKey     
               AND   DropID = @cDropID    
               OPEN @curUpdPPA    
               FETCH NEXT FROM @curUpdPPA INTO @nRowRef    
               WHILE @@FETCH_STATUS = 0    
               BEGIN    
    
                UPDATE rdt.RDTPPA SET     
                   DropID = @cLabelNo,     
                   EditWho = SUSER_SNAME(),     
                   EditDate = GETDATE()    
                WHERE RowRef = @nRowRef    
    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @nErrNo = 201753    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PPA Fail    
                     GOTO RollBackTran    
                  END    
                      
                FETCH NEXT FROM @curUpdPPA INTO @nRowRef    
               END    
                   
               COMMIT TRAN rdt_855ExtUpd09    
    
               GOTO Commit_Tran    
    
               RollBackTran:    
                  ROLLBACK TRAN rdt_855ExtUpd09 -- Only rollback change made here    
               Commit_Tran:    
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
                     COMMIT TRAN    

               -- Print ship label            
               SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)            
               IF @cShipLabel = '0'            
                  SET @cShipLabel = ''            
            
               -- Ship label            
               IF @cShipLabel <> ''             
               BEGIN            
                DECLARE @tShipLabel AS VariableTable    
                  INSERT INTO @tShipLabel (Variable, Value) VALUES  ( '@cLabelNo',  @cLabelNo)            
            
                  -- Print label            
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,             
                     @cShipLabel, -- Report type            
                     @tShipLabel, -- Report params            
                     'rdt_855ExtUpd09',             
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
               'rdt_855ExtUpd09',      
               @nErrNo  OUTPUT,      
               @cErrMsg OUTPUT      
      
             IF @nErrNo <> 0      
               GOTO Quit      
          END      
         END      
      END       
    
   END      
      
      
Quit:      
      
END 

GO