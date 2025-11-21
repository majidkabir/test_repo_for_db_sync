SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593PLMnfest01                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2018-03-08 1.0  Ung        WMS-4240 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_593PLMnfest01] (
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
   DECLARE @cConsigneeKey NVARCHAR( 15)
   DECLARE @cDropID       NVARCHAR( 20)
   DECLARE @cFacility     NVARCHAR( 5)
   DECLARE @cShort        NVARCHAR( 10)
   DECLARE @cSKU          NVARCHAR( 20)

   -- Parameter mapping
   SET @cDropID = @cParam1

   -- Check blank
   IF @cDropID = ''
   BEGIN
      SET @nErrNo = 120801
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Drop ID
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- DropID
      GOTO Quit
   END
   
   -- Get order info
   SELECT TOP 1 
      @cOrderKey = OrderKey, 
      @cSKU = SKU
   FROM PickDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND DropID = @cDropID
   
   -- Check ID picked
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 120802
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID not picked
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- DropID
      GOTO Quit
   END
   
   -- Get order info
   SELECT @cConsigneeKey = ConsigneeKey
   FROM Orders WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
   
   -- Get consignee info
   SELECT TOP 1 
      @cShort = Short 
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'CONSIGNEE'
      AND Code = @cConsigneeKey
      and StorerKey = @cStorerKey

   -- Check if Watson pallet
   IF @cShort <> 'WSN'
   BEGIN
      SET @nErrNo = 120803
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NON Watson
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- DropID
      GOTO Quit
   END

   -- Check PPA info
   IF NOT EXISTS( SELECT 1 FROM rdt.rdtPPA WITH (NOLOCK) WHERE DropID = @cDropID AND StorerKey = @cStorerKey)
   BEGIN
      SET @nErrNo = 120804
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not yet PPA
      GOTO Quit
   END

   -- Get login info
   SELECT 
      @cLabelPrinter = Printer, 
      @cPaperPrinter = Printer_Paper, 
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Storer configure
   DECLARE @cPalletManifest NVARCHAR(10)
   SET @cPalletManifest = rdt.rdtGetConfig( @nFunc, 'PalletManifest', @cStorerKey)

   -- Report params
   DECLARE @tPalletManifest AS VariableTable
   INSERT INTO @tPalletManifest (Variable, Value) VALUES 
      ( '@cOrderKey', @cOrderKey), 
      ( '@cDropID',   @cDropID)

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
      @cPalletManifest, -- Report type
      @tPalletManifest, -- Report params
      'rdt_593PLMnfest01', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit   
  
Quit:
      

GO