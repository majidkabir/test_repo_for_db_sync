SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593PreRecv01                                       */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2016-07-22 1.0  Ung      SOS373382 Created                              */
/* 2016-09-15 1.1  James    WMS332 Add new param (james01)                 */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593PreRecv01] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- ReceiptKey
   @cParam2    NVARCHAR(20),  -- ReceiptLine
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

   DECLARE @cLabelPrinter      NVARCHAR( 10)
   DECLARE @cPaperPrinter      NVARCHAR( 10)
   DECLARE @cDataWindow        NVARCHAR( 50)
   DECLARE @cTargetDB          NVARCHAR( 20)

   DECLARE @cReceiptKey        NVARCHAR( 10)
   DECLARE @cReceiptLineNumber NVARCHAR( 5)
   DECLARE @cUserName          NVARCHAR( 18)
   DECLARE @cChkStorerKey      NVARCHAR( 15)
   DECLARE @cChkFacility       NVARCHAR( 5)
   DECLARE @cUPC               NVARCHAR( 30)
   DECLARE @cSKU               NVARCHAR( 20)

   -- Parameter mapping
   SET @cReceiptKey = @cParam1
   SET @cReceiptLineNumber = @cParam2
   SET @cUPC = @cParam3 -- (james01)

   -- Check blank
   IF @cReceiptKey = ''
   BEGIN
      SET @nErrNo = 102601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need ASN
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
      GOTO Quit
   END

   -- Get Receipt info
   SELECT
      @cChkStorerKey = StorerKey,
      @cChkFacility = Facility
   FROM dbo.Receipt WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey

   -- Check ReceiptKey valid
   IF @@ROWCOUNT <> 1
   BEGIN
      SET @nErrNo = 102602
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ASN not exists
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey
      GOTO Quit
   END

   -- Get facility
   DECLARE @cFacility NVARCHAR(5)
   SELECT @cFacility = Facility FROM rdt.rdtMobRec WHERE Mobile = @nMobile

   -- Check diff facility
   IF @cChkFacility <> @cFacility
   BEGIN
      SET @nErrNo = 102603
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff facility
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey
      GOTO Quit
   END

   -- Check diff storer
   IF @cChkStorerKey <> @cStorerKey
   BEGIN
      SET @nErrNo = 102604
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff storer
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey
      GOTO Quit
   END

   -- Check blank
   IF ISNULL( @cReceiptLineNumber, '') = '' AND ISNULL( @cUPC, '') = ''
   BEGIN
      SET @nErrNo = 102605
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need Line/SKU
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param2
      GOTO Quit
   END

   -- Only either 1 value
   IF ISNULL( @cReceiptLineNumber, '') <> '' AND ISNULL( @cUPC, '') <> ''
   BEGIN
      SET @nErrNo = 102613
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --EitherLine/SKU
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param2
      GOTO Quit
   END

   IF ISNULL( @cReceiptLineNumber, '') <> ''
   BEGIN
      -- Format line no
      SET @cReceiptLineNumber = RTRIM( LTRIM( @cReceiptLineNumber))
      SET @cReceiptLineNumber = RIGHT( '00000' + @cReceiptLineNumber, 5)

      -- Check LineNo in ASN
      IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ReceiptLineNumber = @cReceiptLineNumber)
      BEGIN
         SET @nErrNo = 102606
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Line NotInASN
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param2
         GOTO Quit
      END
   END

   -- (james01)
   -- SKU/UPC validation
   SET @cSKU = ''
   IF ISNULL( @cUPC, '') <> ''
   BEGIN
      -- Get SKU
      DECLARE @nSKUCnt INT
      SET @nSKUCnt = 0
      SELECT
         @nSKUCnt = COUNT( DISTINCT A.SKU),
         @cSKU = MIN( A.SKU) -- Just to bypass SQL aggregrate checking
      FROM
      (
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cUPC
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cUPC
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cUPC
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cUPC
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cUPC
      ) A

      -- Check SKU
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 102610
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Param3
         GOTO Quit
      END

      -- Check barcode return multi SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 102611
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Param2
         GOTO Quit
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
                      WHERE ReceiptKey = @cReceiptKey
                      AND   SKU = @cSKU)
      BEGIN
         SET @nErrNo = 102612
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SKU NotInASN
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Param2
         GOTO Quit
      END                      
   END

   -- Get printer info
   SELECT
      @cUserName = UserName,
      @cLabelPrinter = Printer,
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get report info
   SET @cDataWindow = ''
   SET @cTargetDB = ''
   SELECT TOP 1 
      @cDataWindow = DataWindow, 
      @cTargetDB = TargetDB
   FROM rdt.rdtReport WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ReportType = 'PreRecv'
      AND (Function_ID = @nFunc OR Function_ID = 0)


   /*-------------------------------------------------------------------------------

                                      Print Label

   -------------------------------------------------------------------------------*/

   -- Check label printer blank
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 102607
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END

   -- Check data window
   IF @cDataWindow = ''
   BEGIN
      SET @nErrNo = 102608
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END

   -- Check database
   IF @cTargetDB = ''
   BEGIN
      SET @nErrNo = 102609
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
      GOTO Quit
   END

   IF ISNULL( @cReceiptLineNumber, '') <> ''
      EXEC RDT.rdt_BuiltPrintJob
          @nMobile
         ,@cStorerKey
         ,'PreRecv'        -- ReportType 
         ,'PRINT_PreRecv'  -- PrintJobName
         ,@cDataWindow
         ,@cLabelPrinter
         ,@cTargetDB
         ,@cLangCode
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cReceiptKey
         ,@cReceiptLineNumber
         ,@cReceiptLineNumber
         ,''
   ELSE
      EXEC RDT.rdt_BuiltPrintJob
          @nMobile
         ,@cStorerKey
         ,'PreRecv'        -- ReportType 
         ,'PRINT_PreRecv'  -- PrintJobName
         ,@cDataWindow
         ,@cLabelPrinter
         ,@cTargetDB
         ,@cLangCode
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cReceiptKey
         ,''
         ,''
         ,@cSKU
Quit:

GO