SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPrint13                                   */
/* Purpose: Print label and packlist together after key in carton       */
/*          (no need check pick and pack for packlist)                  */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-08-03 1.0  James      WMS-14322. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtPrint13] (
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
           @cShipLabel        NVARCHAR( 10),
           @cDelNotes         NVARCHAR( 10)

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cFacility = Facility,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         SELECT @cLoadKey = ISNULL(RTRIM(LoadKey), ''),
                @cShipperKey = ISNULL(RTRIM(ShipperKey), '')
         FROM dbo.Orders WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey
         AND   Orderkey = @cOrderkey

         SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'DSShipLabel', @cStorerKey)
         IF @cShipLabel = '0'
            SET @cShipLabel = ''

         IF @cShipLabel <> ''
         BEGIN
            DECLARE @tSHIPPLABEL AS VariableTable
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',     @cPickSlipNo)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo',   @nCartonNo)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',     @nCartonNo)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',       @cOrderKey)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cShipperKey',     @cShipperKey)
            
            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
               @cShipLabel,  -- Report type
               @tSHIPPLABEL, -- Report params
               'rdt_840ExtPrint13', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT 

            IF @nErrNo <> 0
               GOTO Quit         
         END

         SET @cDelNotes = rdt.RDTGetConfig( @nFunc, 'DelNotes', @cStorerKey)
         IF @cDelNotes = '0'
            SET @cDelNotes = ''
         
         IF @cDelNotes <> ''
         BEGIN
            DECLARE @tDELNOTES AS VariableTable
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cStorerKey',   @cStorerkey)
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey',     @cLoadKey)
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@nFromCartonNo',   @nCartonNo)
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@nToCartonNo',     @nCartonNo)


            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter, 
               @cDelNotes, -- Report type
               @tDELNOTES, -- Report params
               'rdt_840ExtPrint13', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT 

            IF @nErrNo <> 0
               GOTO Quit                 
         END

      END   -- IF @nStep = 3
   END   -- @nInputKey = 1

Quit:

GO