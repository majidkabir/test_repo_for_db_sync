SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPrint27                                   */
/* Purpose: Print label after pick = pack                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-04-12 1.0  James      WMS-22264. Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtPrint27] (
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
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cPaperPrinter     NVARCHAR( 10),
           @cLabelPrinter     NVARCHAR( 10),
           @cUserName         NVARCHAR( 18),
           @cLoadKey          NVARCHAR( 10),
           @cShipperKey       NVARCHAR( 10),
           @cFacility         NVARCHAR( 5),
           @cDocType          NVARCHAR( 1),
           @cShipLabel        NVARCHAR( 10),
           @cDelNotes         NVARCHAR( 10),
           @cUCCLabel         NVARCHAR( 10),
           @cShipLblEC        NVARCHAR( 10),
           @cCtnLabel         NVARCHAR( 10),
           @cLabelNo          NVARCHAR( 20),
           @nPickQty          INT = 0,
           @nPackQty          INT = 0,
           @nFromCartonNo     INT = 0,
           @nToCartonNo       INT = 0

   DECLARE @tShipLblEC  AS VariableTable
   DECLARE @tCtnLabel   AS VariableTable
   DECLARE @tUCCLABEL   AS VariableTable
   DECLARE @tSHIPPLABEL AS VariableTable
   DECLARE @tDELNOTES   AS VariableTable
                        
   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         SELECT @cDocType = DocType,
                @cShipperKey = ShipperKey
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         IF @cDocType = 'N' AND @cShipperKey = ''
         BEGIN
            SET @cShipLblEC = rdt.RDTGetConfig( @nFunc, 'ShipLblEC', @cStorerKey)
            IF @cShipLblEC = '0'
               SET @cShipLblEC = ''
  
            IF @cShipLblEC <> ''
            BEGIN
               INSERT INTO @tShipLblEC (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)
               INSERT INTO @tShipLblEC (Variable, Value) VALUES ( '@cOrderKey',     @cOrderKey)
               INSERT INTO @tShipLblEC (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
               INSERT INTO @tShipLblEC (Variable, Value) VALUES ( '@nToCartonNo',   @nCartonNo)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                  @cShipLblEC,  -- Report type
                  @tShipLblEC, -- Report params
                  'rdt_840ExtPrint27', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 

               IF @nErrNo <> 0
                  GOTO Quit
            END

            SET @cCtnLabel = rdt.RDTGetConfig( @nFunc, 'CtnLabel', @cStorerKey)
            IF @cCtnLabel = '0'
               SET @cCtnLabel = ''
  
            IF @cCtnLabel <> ''
            BEGIN
               INSERT INTO @tCtnLabel (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)
               INSERT INTO @tCtnLabel (Variable, Value) VALUES ( '@cOrderKey',     @cOrderKey)
               INSERT INTO @tCtnLabel (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
               INSERT INTO @tCtnLabel (Variable, Value) VALUES ( '@nToCartonNo',   @nCartonNo)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                  @cCtnLabel,  -- Report type
                  @tCtnLabel, -- Report params
                  'rdt_840ExtPrint27', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 

               IF @nErrNo <> 0
                  GOTO Quit
            END

            SET @cUCCLabel = rdt.RDTGetConfig( @nFunc, 'UCCLabel', @cStorerKey)
            IF @cUCCLabel = '0'
               SET @cUCCLabel = ''
  
            IF @cUCCLabel <> ''
            BEGIN
               INSERT INTO @tUCCLABEL (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)
               INSERT INTO @tUCCLABEL (Variable, Value) VALUES ( '@cOrderKey',       @cOrderKey)
               INSERT INTO @tUCCLABEL (Variable, Value) VALUES ( '@nFromCartonNo',   @nCartonNo)
               INSERT INTO @tUCCLABEL (Variable, Value) VALUES ( '@nToCartonNo',     @nCartonNo)

               -- Print paper (so called ucclabel but using delivery note)
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter, 
                  @cUCCLabel,  -- Report type
                  @tUCCLABEL, -- Report params
                  'rdt_840ExtPrint27', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
         ELSE
         BEGIN
            SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
            IF @cShipLabel = '0'
               SET @cShipLabel = ''
  
            IF @cShipLabel <> ''
            BEGIN
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',     @cOrderKey)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',   @nCartonNo)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                  @cShipLabel,  -- Report type
                  @tSHIPPLABEL, -- Report params
                  'rdt_840ExtPrint27', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 

               IF @nErrNo <> 0
                  GOTO Quit
            END

            IF @cDocType = 'N'
            BEGIN
               SET @cUCCLabel = rdt.RDTGetConfig( @nFunc, 'UCCLabel', @cStorerKey)
               IF @cUCCLabel = '0'
                  SET @cUCCLabel = ''
  
               IF @cUCCLabel <> ''
               BEGIN
                  INSERT INTO @tUCCLABEL (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)
                  INSERT INTO @tUCCLABEL (Variable, Value) VALUES ( '@cOrderKey',       @cOrderKey)
                  INSERT INTO @tUCCLABEL (Variable, Value) VALUES ( '@nFromCartonNo',   @nCartonNo)
                  INSERT INTO @tUCCLABEL (Variable, Value) VALUES ( '@nToCartonNo',     @nCartonNo)

                  -- Print paper (so called ucclabel but using delivery note)
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter, 
                     @cUCCLabel,  -- Report type
                     @tUCCLABEL, -- Report params
                     'rdt_840ExtPrint27', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT 

                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END
            ELSE IF @cDocType = 'E'
            BEGIN
               SELECT @nPickQty = ISNULL( SUM( QTY), 0)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey 
               AND   StorerKey = @cStorerkey

               SELECT @nPackQty = ISNULL( SUM( QTY), 0)
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerkey
               AND   PickSlipNo = @cPickSlipNo
   
               -- Delivery notes only print when all items pick n pack  
               IF @nPickQty = @nPackQty  
               BEGIN  
                  SET @cDelNotes = rdt.RDTGetConfig( @nFunc, 'DelNotes', @cStorerKey)  
                  IF @cDelNotes = '0'  
                     SET @cDelNotes = ''  
  
                  IF @cDelNotes <> ''  
                  BEGIN  
                     INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey',     @cLoadKey)  
                     INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)  
                     INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)  
                     INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cTrackNo',     @cTrackNo)  
                     INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)  
                     INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLabelNo',     @cLabelNo)  
  
                     -- Print label  
                     EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter,   
                        @cDelNotes, -- Report type  
                        @tDELNOTES, -- Report params  
                        'rdt_840ExtPrint27',   
                        @nErrNo  OUTPUT,  
                        @cErrMsg OUTPUT   
  
                     IF @nErrNo <> 0  
                        GOTO Quit  
                  END  
               END  
            END
         END
      END   -- IF @nStep = 4
   END   -- @nInputKey = 1

Quit:

GO