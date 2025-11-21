SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtNKRTSKULabelReprn                                   */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2013-09-03 1.0  Ung      SOS273209 Created                              */
/* 2018-12-24 1.1  ChewKP   Performance Tuning (ChewKP01)                  */
/***************************************************************************/

CREATE PROC [RDT].[rdtNKRTSKULabelReprn] (
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

   DECLARE @cDataWindow   NVARCHAR( 50)
   DECLARE @cTargetDB     NVARCHAR( 20)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   DECLARE @cReceiptKey   NVARCHAR( 10)
   DECLARE @cLineNo       NVARCHAR( 5)
   DECLARE @cQTY          NVARCHAR( 5)

   DECLARE @cChkStorerKey NVARCHAR( 15)
   DECLARE @cChkFacility  NVARCHAR( 5)
   DECLARE @cRecType      NVARCHAR( 10)
   DECLARE @cDocType      NVARCHAR( 1)
   DECLARE @cProcessType NVARCHAR(1)

   -- Parameter mapping
   SET @cReceiptKey = @cParam1
   SET @cLineNo = @cParam2
   SET @cQTY = @cParam3

   -- Check blank
   IF @cReceiptKey = ''
   BEGIN
      SET @nErrNo = 84301
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need ASN
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
      GOTO Quit
   END

   -- Get Receipt info
   SELECT 
      @cDocType = DocType,
      @cRecType = RecType, 
      @cChkStorerKey = StorerKey, 
      @cChkFacility = Facility, 
      @cProcessType = ProcessType
   FROM dbo.Receipt WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey

   -- Check ReceiptKey valid
   IF @@ROWCOUNT <> 1
   BEGIN
      SET @nErrNo = 84302
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ASN not exists
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey
      GOTO Quit
   END

   -- Get facility
   DECLARE @cFacility NVARCHAR(5)
   SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile -- (ChewKP01) 

   -- Check diff facility
   IF @cChkFacility <> @cFacility
   BEGIN
      SET @nErrNo = 84303
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff facility
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey
      GOTO Quit
   END

   -- Check diff storer
   IF @cChkStorerKey <> @cStorerKey
   BEGIN
      SET @nErrNo = 84304
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff storer
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey
      GOTO Quit
   END

   -- Check blank
   IF @cLineNo = ''
   BEGIN
      SET @nErrNo = 84305
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need LineNo
      EXEC rdt.rdtSetFocusField @nMobile, 4 --SKU
      GOTO Quit
   END

   -- Check lino in ASN
   IF NOT EXISTS( SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ReceiptLineNumber = @cLineNo)
   BEGIN
      SET @nErrNo = 84306
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LineNoNotInASN
      EXEC rdt.rdtSetFocusField @nMobile, 4 --SKU
      GOTO Quit
   END

   -- Check blank
   IF @cQTY = ''
   BEGIN
      SET @nErrNo = 84307
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need QTY
      EXEC rdt.rdtSetFocusField @nMobile, 6 --QTY
      GOTO Quit
   END
   
   -- Check QTY
   IF RDT.rdtIsValidQTY( @cQTY, 1) = 0
   BEGIN
      SET @nErrNo = 84308
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid QTY
      EXEC rdt.rdtSetFocusField @nMobile, 6 --QTY
      GOTO Quit
   END

   -- Get code lookup info
   DECLARE @cShort NVARCHAR(10)
   SELECT @cShort = Short
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'PROTYPE'
      AND Code = @cProcessType
/*   
   -- Get grade info
   DECLARE @cGrade NVARCHAR(1)
   SELECT @cGrade = LEFT( ToID, 1)
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey 
      AND ReceiptLineNumber = @cLineNo
*/   

   -- Check SKU label required
   DECLARE @cNeedSKULabel NVARCHAR(1)
   SET @cNeedSKULabel = 'N'
   
   IF @cShort = 'Y'
      SET @cNeedSKULabel = 'Y'
      
   IF @cShort = 'Y1'
   BEGIN
/*
      -- Get ToID
      DECLARE @cToID NVARCHAR( 18)
      SELECT @cToID = ToID 
      FROM ReceiptDetail WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey 
         AND ReceiptLineNumber = @cLineNo
      
      -- Check SKU on ToID printed
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM rdt.rdtPrintJob WITH (NOLOCK) 
         WHERE ReportID = 'SKULABEL'
            AND Parm1 = @cReceiptKey 
            AND Parm2 IN (
               SELECT ReceiptLineNumber 
               FROM ReceiptDetail WITH (NOLOCK) 
               WHERE ReceiptKey = @cReceiptKey 
                  AND ToID = @cToID))
*/
         SET @cNeedSKULabel = 'Y'
   END
   
   IF @cNeedSKULabel = 'N'
   BEGIN
      SET @nErrNo = 84309
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NoNeedSKULabel
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey
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
      SET @nErrNo = 84310
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
      AND ReportType = 'SKULabel'
      
   -- Check data window
   IF ISNULL( @cDataWindow, '') = ''
   BEGIN
      SET @nErrNo = 84311
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END

   -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      SET @nErrNo = 84312
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
      GOTO Quit
   END
      
   -- Insert print job
   EXEC RDT.rdt_BuiltPrintJob
      @nMobile,
      @cStorerKey,
      'SKULABEL',       -- ReportType
      'PRINT_SKULABEL', -- PrintJobName
      @cDataWindow,
      @cLabelPrinter,
      @cTargetDB,
      @cLangCode,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT,
      @cReceiptKey,
      @cLineNo,
      @cQTY, 
      'REPRINT'
Quit:


GO