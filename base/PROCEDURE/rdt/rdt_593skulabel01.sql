SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdt_593SKULabel01                                      */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2015-11-25 1.0  Ung      SOS357817 Created base on rdtVFRTSKULabel      */  
/* 2018-12-25 1.0  TLTING01 Misisng nolock                                 */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593SKULabel01] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- ASN  
   @cParam2    NVARCHAR(20),  -- ID  
   @cParam3    NVARCHAR(20),  -- SKU/UPC  
   @cParam4    NVARCHAR(20),  
   @cParam5    NVARCHAR(20),  
   @nErrNo     INT OUTPUT,  
   @cErrMsg    NVARCHAR( 20) OUTPUT  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @b_Success     INT  
     
   DECLARE @cDataWindow   NVARCHAR( 50)  
   DECLARE @cTargetDB     NVARCHAR( 20)  
   DECLARE @cLabelPrinter NVARCHAR( 10)  
   DECLARE @cPaperPrinter NVARCHAR( 10)  
  
   DECLARE @cReceiptKey   NVARCHAR( 10)  
   DECLARE @cToID         NVARCHAR( 18)  
   DECLARE @cSKU          NVARCHAR( 20)  
  
   DECLARE @cLineNo       NVARCHAR( 5)  
   DECLARE @cChkStorerKey NVARCHAR( 15)  
   DECLARE @cChkFacility  NVARCHAR( 5)  
   DECLARE @cRecType      NVARCHAR( 10)  
   DECLARE @cDocType      NVARCHAR( 1)  
  
   -- Parameter mapping  
   SET @cReceiptKey = @cParam1  
   SET @cToID = @cParam2  
   SET @cSKU = @cParam3  
  
   -- Check blank  
   IF @cReceiptKey = ''  
   BEGIN  
      SET @nErrNo = 58501  
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
      SET @nErrNo = 58502  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ASN not exists  
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey  
      GOTO Quit  
   END  
  
   -- Get facility  
   DECLARE @cFacility NVARCHAR(5)  
   --tlting01
   SELECT @cFacility = Facility FROM rdt.rdtMobRec (NOLOCK) WHERE Mobile = @nMobile  
  
   -- Check diff facility  
   IF @cChkFacility <> @cFacility  
   BEGIN  
      SET @nErrNo = 58503  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff facility  
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey  
      GOTO Quit  
   END  
  
   -- Check diff storer  
   IF @cChkStorerKey <> @cStorerKey  
   BEGIN  
      SET @nErrNo = 58504  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff storer  
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey  
      GOTO Quit  
   END  
  
   -- Check trade return  
   IF @cDocType <> 'R'  
   BEGIN  
      SET @nErrNo = 58505  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Not return ASN  
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey  
      GOTO Quit  
   END  
     
   -- Check SKU label required  
   IF NOT EXISTS( SELECT 1   
      FROM CodeLKUP WITH (NOLOCK)   
      WHERE ListName = 'RECTYPE'   
         AND Code = @cRecType   
         AND Short = 'R'   
         AND StorerKey = @cStorerKey)  
   BEGIN  
      SET @nErrNo = 58506  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NoNeedSKULabel  
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ReceiptKey  
      GOTO Quit  
   END  
     
   -- Check blank  
   IF @cToID = ''  
   BEGIN  
      SET @nErrNo = 58507  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need ID  
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- ID  
      GOTO Quit  
   END  
  
   -- Check blank  
   IF @cSKU = ''  
   BEGIN  
      SET @nErrNo = 58508  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need SKU/UPC  
      EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU  
      GOTO Quit  
   END  
  
   -- Get SKU barcode count  
   DECLARE @nSKUCnt INT  
   EXEC rdt.rdt_GETSKUCNT  
       @cStorerKey  = @cStorerKey  
      ,@cSKU        = @cSKU  
      ,@nSKUCnt     = @nSKUCnt       OUTPUT  
      ,@bSuccess    = @b_Success     OUTPUT  
      ,@nErr        = @nErrNo        OUTPUT  
      ,@cErrMsg     = @cErrMsg       OUTPUT  
  
   -- Check SKU/UPC  
   IF @nSKUCnt = 0  
   BEGIN  
      SET @nErrNo = 58509  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU  
      EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU  
      GOTO Quit  
   END  
  
   -- Check multi SKU barcode  
   IF @nSKUCnt > 1  
   BEGIN  
      SET @nErrNo = 58510  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarCod  
      EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU  
      GOTO Quit  
   END  
  
   -- Get SKU code  
   EXEC rdt.rdt_GETSKU  
       @cStorerKey  = @cStorerKey  
      ,@cSKU        = @cSKU          OUTPUT  
      ,@bSuccess    = @b_Success     OUTPUT  
      ,@nErr        = @nErrNo        OUTPUT  
      ,@cErrMsg     = @cErrMsg       OUTPUT  
  
   -- Get ReceiptDetail info  
   SET @cLineNo = ''  
   SELECT TOP 1   
      @cLineNo = ReceiptLineNumber  
   FROM ReceiptDetail WITH (NOLOCK)  
   WHERE ReceiptKey = @cReceiptKey  
      AND ToID = @cToID  
      AND SKU = @cSKU  
      AND BeforeReceivedQTY > 0  
     
   -- Check SKU in ASN  
   IF @cLineNo = ''  
   BEGIN  
      SET @nErrNo = 58511  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID/SKUNotInASN  
      EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU  
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
      SET @nErrNo = 58512  
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
      SET @nErrNo = 58513  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup  
      GOTO Quit  
   END  
  
   -- Check database  
   IF ISNULL( @cTargetDB, '') = ''  
   BEGIN  
      SET @nErrNo = 58514  
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
      1,   
      'REPRINT'  
Quit:  

GO