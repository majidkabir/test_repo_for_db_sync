SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_841BTSP08                                       */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 21-03-2022  1.0  Ung       WMS-19208 Created                         */
/************************************************************************/
CREATE PROC [RDT].[rdt_841BTSP08] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cPrinterID   NVARCHAR( 10)
   ,@cDropID      NVARCHAR( 20)
   ,@cLoadKey     NVARCHAR( 10)
   ,@cLabelNo     NVARCHAR( 20)
   ,@cUserName    NVARCHAR( 18)
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelPrinter  NVARCHAR( 20)
   DECLARE @cPaperPrinter	NVARCHAR( 20)
   DECLARE @cShipLabel     NVARCHAR( 10)
   DECLARE @cDeliveryNote  NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @nCartonNo      INT

   -- Storer configure
   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
   IF @cShipLabel = '0'
      SET @cShipLabel = ''
   SET @cDeliveryNote = rdt.RDTGetConfig( @nFunc, 'DeliveryNote', @cStorerKey)
   IF @cDeliveryNote = '0'
      SET @cDeliveryNote = ''

   -- Get session info
   SELECT 
      @cLabelPrinter = Printer, 
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Get PackDetail info
   SELECT TOP 1 
      @cPickSlipNo = PickSlipNo, 
      @nCartonNo = CartonNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo

   -- Get Packheader info
   SELECT @cOrderKey = OrderKey
   FROM dbo.PackHeader WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
       
   -- Shipping label
   IF @cShipLabel <> ''
   BEGIN
      DECLARE @tShipLabel AS VariableTable
      INSERT INTO @tShipLabel (Variable, Value) VALUES 
         ( '@cOrderKey',  @cOrderKey), 
         ( '@nCartonNo',  CAST( @nCartonNo AS NVARCHAR(5)))
         
      -- Print label
      EXEC rdt.rdt_Print @nMobile, @nFunc, @cLangCode, 2, 1, @cFacility, @cStorerkey, @cLabelPrinter, @cPaperPrinter,
         @cShipLabel, -- Report type
         @tShipLabel, -- Report params
         'rdt_841BTSP08',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
   END

   -- Delivery Note
   IF @cDeliveryNote <> ''
   BEGIN
      DECLARE @tDeliveryNote AS VariableTable
      INSERT INTO @tDeliveryNote (Variable, Value) VALUES 
         ( '@cOrderKey',  @cOrderKey)

      -- Print label
      EXEC rdt.rdt_Print @nMobile, @nFunc, @cLangCode, 2, 1, @cFacility, @cStorerkey, @cLabelPrinter, @cPaperPrinter,
         @cDeliveryNote, -- Report type
         @tDeliveryNote, -- Report params
         'rdt_841BTSP08',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
   END

   -- To Proceed Ecomm Despatch while printing having error --
   SET @nErrNo = 0
   SET @cErrMsg = ''
END

GO