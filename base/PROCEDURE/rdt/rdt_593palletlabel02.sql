SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593PalletLabel02                                   */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2018-01-29 1.0  Ung      WMS-3855 Created                               */
/* 2018-06-05 1.1  Ung      WMS-5096 Change validation                     */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593PalletLabel02] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- Pallet ID
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

   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)
   DECLARE @cID           NVARCHAR( 20)
   DECLARE @cFacility     NVARCHAR( 5)
   DECLARE @cSKU          NVARCHAR( 20)
   DECLARE @cPalletLabel  NVARCHAR( 10)
   DECLARE @nRowCount     INT

   SET @cID = @cParam1

   -- Check blank
   IF @cID = ''
   BEGIN
      SET @nErrNo = 119101
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need ID
      GOTO Quit
   END

   -- Get login info
   SELECT
      @cFacility = Facility,
      @cLabelPrinter = Printer,
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF LEN( @cID) = 20
      -- Carton
      SELECT @cSKU = SKU
      FROM UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cID
   ELSE
      -- Pallet
      SELECT @cSKU = SKU
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE Facility = @cFacility
         AND StorerKey = @cStorerKey
         AND ID = @cID
         AND QTY > 0

   SET @nRowCount = @@ROWCOUNT

   -- Check UCC valid
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 119102
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid ID
      GOTO Quit
   END

   -- Check multi SKU UCC
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 119103
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Multi SKU ID
      GOTO Quit
   END

   -- Check pick face
   IF NOT EXISTS( SELECT 1
      FROM SKUxLOC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND LocationType IN ('PICK', 'CASE'))
   BEGIN
      SET @nErrNo = 119103
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --No pick face
      GOTO Quit
   END

   /*-------------------------------------------------------------------------------

                                      Print pallet label

   -------------------------------------------------------------------------------*/
   -- Get storer config
   SET @cPalletLabel = rdt.RDTGetConfig( @nFunc, 'PalletLabel', @cStorerKey)
   IF @cPalletLabel = '0'
      SET @cPalletLabel = ''

   -- Check report setup
   IF @cPalletLabel = ''
   BEGIN
      SET @nErrNo = 119104
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --RPTypeNotSetup
      GOTO Quit
   END

   -- Common params
   DECLARE @tPalletLabel VariableTable
   INSERT INTO @tPalletLabel (Variable, Value) VALUES
      ( '@cStorerKey', @cStorerKey),
      ( '@cID',        @cID)

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
      @cPalletLabel, -- Report type
      @tPalletLabel, -- Report params
      'rdt_593PalletLabel02',
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT

   IF @nErrNo <> 0
      GOTO Quit

Quit:

GO