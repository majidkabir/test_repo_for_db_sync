SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPrint10                                   */
/* Purpose: Print label after pick = pack                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-03-30 1.0  James      WMS-12664. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtPrint10] (
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
           @cLabelNo          NVARCHAR( 20),
           @nPickQty          INT = 0,
           @nPackQty          INT = 0,
           @nFromCartonNo     INT = 0,
           @nToCartonNo       INT = 0

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
         IF @cShipLabel = '0'
            SET @cShipLabel = ''
  
         IF @cShipLabel <> ''
         BEGIN
            DECLARE @tSHIPPLABEL AS VariableTable
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',     @cOrderKey)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',   @nCartonNo)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
               @cShipLabel,  -- Report type
               @tSHIPPLABEL, -- Report params
               'rdt_840ExtPrint10', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT 

            IF @nErrNo <> 0
               GOTO Quit
         END

         SELECT @cDocType = DocType
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         IF @cDocType = 'N'
         BEGIN
            SET @cUCCLabel = rdt.RDTGetConfig( @nFunc, 'UCCLabel', @cStorerKey)
            IF @cUCCLabel = '0'
               SET @cUCCLabel = ''
  
            IF @cUCCLabel <> ''
            BEGIN
               DECLARE @tUCCLABEL AS VariableTable
               INSERT INTO @tUCCLABEL (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)
               INSERT INTO @tUCCLABEL (Variable, Value) VALUES ( '@cOrderKey',       @cOrderKey)
               INSERT INTO @tUCCLABEL (Variable, Value) VALUES ( '@nFromCartonNo',   @nCartonNo)
               INSERT INTO @tUCCLABEL (Variable, Value) VALUES ( '@nToCartonNo',     @nCartonNo)

               -- Print paper (so called ucclabel but using delivery note)
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter, 
                  @cUCCLabel,  -- Report type
                  @tUCCLABEL, -- Report params
                  'rdt_840ExtPrint10', 
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
                  DECLARE @tDELNOTES AS VariableTable  
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
                     'rdt_840ExtPrint10',   
                     @nErrNo  OUTPUT,  
                     @cErrMsg OUTPUT   
  
                  IF @nErrNo <> 0  
                     GOTO Quit  
               END  
            END  
         END
      END   -- IF @nStep = 4
   END   -- @nInputKey = 1

Quit:

GO