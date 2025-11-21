SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPrint11                                   */
/* Purpose: Print label after pick = pack                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-04-13 1.0  James      WMS-12855. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtPrint11] (
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
           @nExpectedQty      INT,
           @nPackedQty        INT,
           @nIsMoveOrder      INT,
           @cDocType          NVARCHAR( 1),
           @cUDF03            NVARCHAR( 10),
           @cShipLabel        NVARCHAR( 10),
           @cShipLabelEC      NVARCHAR( 10),
           @cContentLbl       NVARCHAR( 10),
           @cPackList         NVARCHAR( 10),
           @nShortPack        INT = 0,
           @nOriginalQty      INT = 0,
           @nPackQty          INT = 0,
           @nFromCartonNo     INT = 0,
           @nToCartonNo       INT = 0

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @cDocType = DocType,
          @cUDF03 = UserDefine03
   FROM dbo.ORDERS WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
   
   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         IF @cDocType = 'N'
         BEGIN
            SET @cShipLabelEC = rdt.RDTGetConfig( @nFunc, 'ShipLblEC', @cStorerKey)
            IF @cShipLabelEC = '0'
               SET @cShipLabelEC = ''

            IF @cShipLabelEC <> ''
            BEGIN
               DECLARE @tSHIPPLABELEC AS VariableTable
               INSERT INTO @tSHIPPLABELEC (Variable, Value) VALUES ( '@cPickSlipNo',     @cPickSlipNo)
               INSERT INTO @tSHIPPLABELEC (Variable, Value) VALUES ( '@nFromCartonNo',   @nCartonNo)
               INSERT INTO @tSHIPPLABELEC (Variable, Value) VALUES ( '@nToCartonNo',     @nCartonNo)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                  @cShipLabelEC,  -- Report type
                  @tSHIPPLABELEC, -- Report params
                  'rdt_840ExtPrint11', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 

               IF @nErrNo <> 0
                  GOTO Quit
            END

            SET @cContentLbl = rdt.RDTGetConfig( @nFunc, 'ContentLbl', @cStorerKey)
            IF @cContentLbl = '0'
               SET @cContentLbl = ''

            IF @cContentLbl <> ''
            BEGIN
               DECLARE @tCONTENTLBL AS VariableTable
               INSERT INTO @tCONTENTLBL (Variable, Value) VALUES ( '@cPickSlipNo',     @cPickSlipNo)
               INSERT INTO @tCONTENTLBL (Variable, Value) VALUES ( '@nFromCartonNo',   @nCartonNo)
               INSERT INTO @tCONTENTLBL (Variable, Value) VALUES ( '@nToCartonNo',     @nCartonNo)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                  @cContentLbl, -- Report type
                  @tCONTENTLBL, -- Report params
                  'rdt_840ExtPrint11', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
         
         IF @cUDF03 = 'NC'
         BEGIN
            SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
            IF @cShipLabel = '0'
               SET @cShipLabel = ''

            IF @cShipLabel <> ''
            BEGIN
               DECLARE @tSHIPPLABEL AS VariableTable
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',       @cOrderKey)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo',   @nCartonNo)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',     @nCartonNo)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter, 
                  @cShipLabel,   -- Report type
                  @tSHIPPLABEL,  -- Report params
                  'rdt_840ExtPrint11', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
      END   -- IF @nStep = 4
   END   -- @nInputKey = 1

Quit:

GO