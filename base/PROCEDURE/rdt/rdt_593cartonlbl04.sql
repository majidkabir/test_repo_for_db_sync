SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593CartonLBL04                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2018-03-08 1.0  Ung        WMS-4084 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_593CartonLBL04] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- LabelNo
   @cParam2    NVARCHAR(20),
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)
   DECLARE @cOrderKey     NVARCHAR( 10)
   DECLARE @cCartonNo     NVARCHAR( 10)
   DECLARE @cStatus       NVARCHAR( 10)
   DECLARE @cFacility     NVARCHAR( 5)

   -- Parameter mapping
   SET @cOrderKey = @cParam1
   SET @cCartonNo = @cParam2

   -- Check blank
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 120751
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OrderKey
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
      GOTO Quit
   END
   
   -- Get order info
   SELECT @cStatus = Status 
   FROM Orders WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey 
      AND StorerKey = @cStorerKey
   
   -- Check order valid
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 120752
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
      GOTO Quit
   END
   
   -- Check status
   IF @cStatus <= '2'
   BEGIN
      SET @nErrNo = 120753
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order not pick
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
      GOTO Quit
   END

   -- Check blank
   IF @cCartonNo <> ''
   BEGIN
      -- Check carton format
      IF RDT.rdtIsValidQTY( @cCartonNo, 0) = 0
      BEGIN
         SET @nErrNo = 120754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonNo
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonNo
         GOTO Quit
      END
      
      -- Check carton valid
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM PackHeader PH WITH (NOLOCK) 
            JOIN PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         WHERE PH.OrderKey = @cOrderKey 
            AND PH.StorerKey = @cStorerKey
            AND PD.CartonNo = @cCartonNo)
      BEGIN
         SET @nErrNo = 120755
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonNotFound
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- CartonNo
         GOTO Quit
      END
   END

   -- Get login info
   SELECT 
      @cLabelPrinter = Printer, 
      @cPaperPrinter = Printer_Paper, 
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Storer configure
   DECLARE @cCartonLabel NVARCHAR(10)
   SET @cCartonLabel = rdt.rdtGetConfig( @nFunc, 'CARTONLBL', @cStorerKey)

   -- Report params
   DECLARE @tCartonLabel AS VariableTable
   INSERT INTO @tCartonLabel (Variable, Value) VALUES 
      ( '@cOrderKey', @cOrderKey), 
      ( '@cCartonNo', @cCartonNo)

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
      @cCartonLabel, -- Report type
      @tCartonLabel, -- Report params
      'rdt_593CartonLBL04', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit   
  
Quit:
      

GO