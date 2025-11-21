SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtNKRTPLLabelReprn                                    */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2014-01-08 1.0  Ung      SOS273209 Created                              */
/* 2018-12-24 1.1  ChewKP   Performance Tuning                             */
/***************************************************************************/

CREATE PROC [RDT].[rdtNKRTPLLabelReprn] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- ASN
   @cParam2    NVARCHAR(20),  -- SKU/UPC
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

   DECLARE @cDataWindow   NVARCHAR( 50)
   DECLARE @cTargetDB     NVARCHAR( 20)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   DECLARE @cReceiptKey   NVARCHAR( 10)
   DECLARE @cToID         NVARCHAR( 18)
   DECLARE @cQTY          NVARCHAR( 5)

   DECLARE @cChkStorerKey NVARCHAR( 15)
   DECLARE @cChkFacility  NVARCHAR( 5)
   DECLARE @cRecType      NVARCHAR( 10)
   DECLARE @cDocType      NVARCHAR( 1)

   -- Parameter mapping
   SET @cReceiptKey = @cParam1
   SET @cToID = @cParam2
   SET @cQTY = @cParam3

   -- Check blank
   IF @cReceiptKey = ''
   BEGIN
      SET @nErrNo = 84351
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need ASN
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
      GOTO Quit
   END

   -- Get Receipt info
   SELECT 
      @cDocType = DocType,
      @cRecType = RecType, 
      @cChkStorerKey = StorerKey, 
      @cChkFacility = Facility
   FROM dbo.Receipt WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey

   -- Check ReceiptKey valid
   IF @@ROWCOUNT <> 1
   BEGIN
      SET @nErrNo = 84352
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ASN not exists
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey
      GOTO Quit
   END

   -- Get facility
   DECLARE @cFacility NVARCHAR(5)
   SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   -- Check diff facility
   IF @cChkFacility <> @cFacility
   BEGIN
      SET @nErrNo = 84353
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff facility
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey
      GOTO Quit
   END

   -- Check diff storer
   IF @cChkStorerKey <> @cStorerKey
   BEGIN
      SET @nErrNo = 84354
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff storer
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey
      GOTO Quit
   END

   -- Check blank
   IF @cToID = ''
   BEGIN
      SET @nErrNo = 84355
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need ID
      EXEC rdt.rdtSetFocusField @nMobile, 4 --ToID
      GOTO Quit
   END

   -- Check ID in ASN
   IF NOT EXISTS( SELECT TOP 1 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ToID = @cToID)
   BEGIN
      SET @nErrNo = 84356
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ID Not In ASN
      EXEC rdt.rdtSetFocusField @nMobile, 4 --ToID
      GOTO Quit
   END
   
   -- Get printer info
   SELECT 
      @cLabelPrinter = Printer, 
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   /*-------------------------------------------------------------------------------

                                    Print SKU Label

   -------------------------------------------------------------------------------*/

   -- Check label printer blank
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 84357
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END

   -- Get report info
   SET @cDataWindow = ''
   SET @cTargetDB = ''
   SELECT 
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
      @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
   FROM RDT.RDTReport WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
      AND ReportType = 'PalletLBL'
      
   -- Check data window
   IF ISNULL( @cDataWindow, '') = ''
   BEGIN
      SET @nErrNo = 84358
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END

   -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      SET @nErrNo = 84359
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
      GOTO Quit
   END
      
   -- Insert print job
   EXEC RDT.rdt_BuiltPrintJob
      @nMobile,
      @cStorerKey,
      'PalletLBL',       -- ReportType
      'PRINT_PalletLBL', -- PrintJobName
      @cDataWindow,
      @cLabelPrinter,
      @cTargetDB,
      @cLangCode,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT,
      @cReceiptKey,
      @cToID, 
      'REPRINT'
Quit:


GO