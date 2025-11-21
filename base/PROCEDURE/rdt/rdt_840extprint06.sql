SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtPrint06                                   */
/* Purpose: Print label after pick = pack                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2019-08-14 1.0  James      WMS-9881 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtPrint06] (
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

   DECLARE @cLabelPrinter     NVARCHAR( 10),
           @cPaperPrinter     NVARCHAR( 10),
           @nExpectedQty      INT,
           @nPackedQty        INT,
           @cShipLabel        NVARCHAR( 10),
           @cFacility         NVARCHAR( 5)


   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 3
      BEGIN
         SET @nExpectedQty = 0
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)
         WHERE Orderkey = @cOrderkey
            AND Storerkey = @cStorerkey
            AND Status < '9'

         SET @nPackedQty = 0
         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         IF @nExpectedQty = @nPackedQty
         BEGIN
            SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
            IF @cShipLabel = '0'
               SET @cShipLabel = ''

            IF @cShipLabel <> ''
            BEGIN
               SET @nErrNo = 0
               DECLARE @tSHIPPLABEL    VARIABLETABLE
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cStorerKey',   @cStorerKey)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                  @cShipLabel, -- Report type
                  @tSHIPPLABEL, -- Report params
                  'rdt_840ExtPrint06', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 
            END
         END
      END   -- IF @nStep = 3
   END   -- @nInputKey = 1

Quit:

GO