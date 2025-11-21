SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593ShipLabel11                                     */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date        Rev  Author   Purposes                                      */
/* 2018-03-14  1.1  Ung      WMS-4274 Created                              */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593ShipLabel11] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- Label No
   @cParam2    NVARCHAR(20),  
   @cParam3    NVARCHAR(20),  
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @cPaperPrinter  NVARCHAR( 10)
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nCartonNo      INT

   -- Parameter mapping
   SET @cDropID = @cParam1

   -- Check blank
   IF @cDropID = ''
   BEGIN
      SET @nErrNo = 121651
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need DropID
      GOTO Quit
   END

   -- Get PackDetail info
   SELECT TOP 1 
      @cPickSlipNo = PD.PickSlipNo, 
      @cLabelNo = LabelNo, 
      @nCartonNo = CartonNo
   FROM dbo.PackDetail PD WITH (NOLOCK) 
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
   WHERE PD.DropID = @cDropID
      AND PD.StorerKey = @cStorerKey

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 121652
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid DropID
      GOTO Quit
   END

    -- Get login info
   SELECT 
      @cFacility = Facility, 
      @cLabelPrinter = Printer, 
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Storer configure
   DECLARE @cShipLabel NVARCHAR(10)
   SET @cShipLabel = rdt.rdtGetConfig( @nFunc, 'ShipLabel', @cStorerKey)

   -- Common params
   DECLARE @tShipLabel AS VariableTable
   INSERT INTO @tShipLabel (Variable, Value) VALUES 
      ( '@cPickSlipNo', @cPickSlipNo), 
      ( '@cLabelNo',    @cLabelNo), 
      ( '@nCartonNo',   CAST( @nCartonNo AS NVARCHAR(10))), 
      ( '@cDropID',     @cDropID), 
      ( '@cStorerKey',  @cStorerKey)

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
      @cShipLabel, -- Report type
      @tShipLabel, -- Report params
      'rdt_593ShipLabel11', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

Quit:
  


GO