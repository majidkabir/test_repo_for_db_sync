SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPrint09                                   */
/* Purpose: Print label after pick = pack                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-03-25 1.0  James      WMS-12654. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtPrint09] (
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
           @cPackList         NVARCHAR( 10),
           @nShortPack        INT = 0,
           @nOriginalQty      INT = 0,
           @nPackQty          INT = 0,
           @nFromCartonNo     INT = 0,
           @nToCartonNo       INT = 0

   SELECT @cLabelPrinter = Printer,
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
            SELECT @nFromCartonNo = MIN( CartonNo), 
                   @nToCartonNo = MAX( CartonNo)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            DECLARE @tSHIPPLABEL AS VariableTable
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',       @cOrderKey)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo',   @nFromCartonNo)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',     @nToCartonNo)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
               @cShipLabel,  -- Report type
               @tSHIPPLABEL, -- Report params
               'rdt_840ExtInsPack09', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT 

            IF @nErrNo <> 0
               GOTO Quit
         END
      END   -- IF @nStep = 4
   END   -- @nInputKey = 1

Quit:

GO