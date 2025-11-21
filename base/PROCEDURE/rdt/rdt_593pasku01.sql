SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593PASKU01                                         */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2020-04-05 1.0  Ung      WMS-12219 Created                              */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593PASKU01] (
   @nMobile       INT,          
   @nFunc         INT,          
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT,          
   @nInputKey     INT,          
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),
   @cLabelPrinter NVARCHAR( 10),
   @cPaperPrinter NVARCHAR( 10),
   @cOption       NVARCHAR( 1), 
   @cParam1Label  NVARCHAR( 20) OUTPUT,
   @cParam2Label  NVARCHAR( 20) OUTPUT,
   @cParam3Label  NVARCHAR( 20) OUTPUT,
   @cParam4Label  NVARCHAR( 20) OUTPUT,
   @cParam5Label  NVARCHAR( 20) OUTPUT,
   @cParam1Value  NVARCHAR( 60) OUTPUT,
   @cParam2Value  NVARCHAR( 60) OUTPUT,
   @cParam3Value  NVARCHAR( 60) OUTPUT,
   @cParam4Value  NVARCHAR( 60) OUTPUT,
   @cParam5Value  NVARCHAR( 60) OUTPUT,
   @cFieldAttr02  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr04  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr06  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr08  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr10  NVARCHAR( 1)  OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cChkFacility   NVARCHAR( 5)
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @cID            NVARCHAR( 18) = ''
   DECLARE @cLOT           NVARCHAR( 10) = ''
   DECLARE @cLottable02    NVARCHAR( 18)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cSKUDesc       NVARCHAR( 60)
   DECLARE @cBarcode       NVARCHAR( 30)
   DECLARE @cSuggestedLOC  NVARCHAR( 10) = ''
   DECLARE @cPutawayZone   NVARCHAR( 10)
   DECLARE @cLOCAisle      NVARCHAR( 10)

   -- Parameter mapping
   SET @cLOC = @cParam1Value
   SET @cBarcode = LEFT( @cParam2Value, 30)

   -- Check blank
   IF @cLOC = ''
   BEGIN
      SET @nErrNo = 152251
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need LOC
      EXEC rdt.rdtSetFocusField @nMobile, 2 --LOC
      GOTO Quit
   END

   -- Get LOC info
   SELECT @cChkFacility = Facility FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC

   -- Check LOC valid
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 152252
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid LOC
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
      SET @cParam1Value = ''
      GOTO Quit
   END

   -- Check different facility
   IF @cChkFacility <> @cFacility
   BEGIN
      SET @nErrNo = 152253
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff facility
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
      SET @cParam1Value = ''
      GOTO Quit
   END
   SET @cParam1Value = @cLOC

   -- Check blank
   IF @cBarcode = ''
   BEGIN
      SET @nErrNo = 152254
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU/UPC
      GOTO Fail
   END
   SET @cBarcode = TRIM( @cBarcode)

   -- Decode IT69 (SKU)
   SET @cSKU = SUBSTRING( @cBarcode, 3, 13)  

   -- Get SKU info
   SELECT @cSKUDesc = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

   -- Check SKU valid
   IF @@ROWCOUNT <> 1
   BEGIN
      SET @nErrNo = 152255
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
      GOTO Fail
   END

   -- Decode IT69 (Lottable02)
   SET @cLottable02 = 
      SUBSTRING( @cBarcode, 16, 12) + 
      '-' + 
      SUBSTRING( @cBarcode, 28, 2)  

   -- Get ID, LOT
   SELECT TOP 1
      @cID = ID, 
      @cLOT = LLI.LOT
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
   WHERE LLI.LOC = @cLOC
      AND LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0
      AND LA.Lottable02 = @cLottable02

   -- Check SKU in ID, LOC
   IF @cLOT = ''
   BEGIN
      SET @nErrNo = 152256
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No QTY
      GOTO Fail
   END

   -- Suggest LOC
   EXEC @nErrNo = [dbo].[nspRDTPASTD]
        @c_userid          = 'RDT'
      , @c_storerkey       = @cStorerKey
      , @c_lot             = @cLOT
      , @c_sku             = @cSKU
      , @c_id              = @cID
      , @c_fromloc         = @cLOC
      , @n_qty             = 1
      , @c_uom             = '' -- not used
      , @c_packkey         = '' -- optional, if pass-in SKU
      , @n_putawaycapacity = 0
      , @c_final_toloc     = @cSuggestedLOC OUTPUT

   IF @cSuggestedLOC = ''
      GOTO Fail

   -- Get LOC info
   SELECT 
      @cPutawayZone = PutawayZone, 
      @cLOCAisle = LOCAisle
   FROM LOC WITH (NOLOCK)
   WHERE LOC = @cSuggestedLOC

   -- Prepare current screen var
   SET @cParam3Label = SUBSTRING( @cSKUDesc, 1, 20)
   SET @cParam3Value = SUBSTRING( @cSKUDesc, 21, 20)
   SET @cParam4Label = 'SUGGESTED LOC:'
   SET @cParam4Value = TRIM( @cPutawayZone) + '->' + TRIM( @cLOCAisle)

   EXEC rdt.rdtSetFocusField @nMobile, 4 --SKU

   GOTO Quit
   
Fail:
   EXEC rdt.rdtSetFocusField @nMobile, 4 --SKU
   SET @cParam2Value = '' -- SKU   
   SET @cParam3Label = '' -- Desc1
   SET @cParam3Value = '' -- Desc2
   SET @cParam4Value = '' -- Suggested LOC

Quit:
   

GO