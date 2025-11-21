SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_547ExtUpd01                                     */  
/* Purpose: Print lulu shipping label                                   */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 2021-02-19  1.0  James      WMS-15660. Created                       */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_547ExtUpd01] (  
   @nMobile     INT,  
   @nFunc       INT,  
   @cLangCode   NVARCHAR( 3),  
   @nStep       INT,  
   @cUserName   NVARCHAR( 18),  
   @cFacility   NVARCHAR( 5),
   @cStorerkey  NVARCHAR( 15),  
   @cLabelPrinter  NVARCHAR( 10),
   @cCloseCartonID NVARCHAR( 20),
   @cLoadKey       NVARCHAR( 10),
   @cLabelNo       NVARCHAR( 20),
   @nErrNo      INT           OUTPUT,  
   @cErrMsg     NVARCHAR( 20) OUTPUT  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount           INT
   DECLARE @nInputKey            INT
   DECLARE @nCartonNo            INT
   DECLARE @cPickSlipNo          NVARCHAR( 10)
   DECLARE @cPaperPrinter        NVARCHAR( 10)
   DECLARE @cCartonLabel         NVARCHAR( 10)
   DECLARE @tCartonLabel         VARIABLETABLE
   DECLARE @cMECartonLabel       NVARCHAR( 10)
   DECLARE @tMECartonLabel       VARIABLETABLE
   DECLARE @cCur                 CURSOR
   DECLARE @cOption              NVARCHAR( 1)
   
   SELECT @cLabelPrinter = Printer,
          @cFacility     = Facility,
          @cLabelNo      = V_CaseID, 
          @nInputKey     = InputKey,
          @cPickSlipNo   = V_String18, 
          @cOption       = I_Field01
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   IF @nStep IN ( 6, 8)  
   BEGIN  
      IF @nInputKey = 1 
      BEGIN
         IF @nStep = 6 AND @cOption <> '3'
            GOTO Quit

         SET @cCur = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE ExternOrderKey = @cLoadKey
         OPEN @cCur
         FETCH NEXT FROM @cCur INTO @cPickSlipNo
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SELECT TOP 1 @cLabelNo = Dropid
            FROM dbo.Dropid D WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   LabelPrinted <> 'Y'
            AND EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
                         WHERE D.PickSlipNo = PD.PickSlipNo
                         AND   D.Dropid = PD.LabelNo)
            ORDER BY 1

            SELECT @nCartonNo = CartonNo
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   LabelNo = @cLabelNo
         
            SET @cCartonLabel = rdt.RDTGetConfig( @nFunc, 'CartonLbl', @cStorerKey)
            IF @cCartonLabel = '0'
               SET @cCartonLabel = ''

            IF @cCartonLabel <> ''
            BEGIN
               DELETE FROM @tCartonLabel
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cStorerkey', @cStorerkey)
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)     
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)     
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)    

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                  @cCartonLabel, -- Report type
                  @tCartonLabel, -- Report params
                  'rdt_547ExtUpd01', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 
               
               IF @nErrNo <> 0
                  GOTO Quit
            END
         
            IF EXISTS ( SELECT 1 FROM dbo.PackHeader PH WITH (NOLOCK)
                        JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PH.OrderKey = O.OrderKey) 
                        WHERE PH.PickSlipNo = @cPickSlipNo
                        AND   EXISTS ( SELECT 1 FROM dbo.CODELKUP CLK WITH (NOLOCK)
                                       WHERE CLK.ListName = 'LULULABEL'
                                       AND   O.[Type] = CLK.Code
                                       AND   O.StorerKey = CLK.Storerkey
                                       AND   CLK.UDF01 = 'Y'))
            BEGIN
               SET @cMECartonLabel = rdt.RDTGetConfig( @nFunc, 'MECartonLb', @cStorerKey)
               IF @cMECartonLabel = '0'
                  SET @cMECartonLabel = ''

               IF @cMECartonLabel <> ''
               BEGIN
                  DELETE FROM @tMECartonLabel
                  INSERT INTO @tMECartonLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)     
                  INSERT INTO @tMECartonLabel (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)     
                  INSERT INTO @tMECartonLabel (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)    

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                     @cMECartonLabel, -- Report type
                     @tMECartonLabel, -- Report params
                     'rdt_547ExtUpd01', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT 
               
                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END
         
            UPDATE dbo.Dropid SET 
               LabelPrinted = 'Y',
               [STATUS] = '9', 
               EditWho = @cUserName, 
               EditDate = GETDATE()
            WHERE Dropid = @cLabelNo
              
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 167401  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close Ctn Error  
               GOTO Quit  
            END  
            
            FETCH NEXT FROM @cCur INTO @cPickSlipNo
         END
      END
   END  
  
   Quit:


GO