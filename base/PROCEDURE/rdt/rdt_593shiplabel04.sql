SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdt_593ShipLabel04                                     */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2015-12-29 1.0  James    SOS373519 Created                              */  
/* 2016-11-24 1.1  James    WMS601 - Limit # of printing copy (james01)    */  
/***************************************************************************/  

CREATE PROC [RDT].[rdt_593ShipLabel04] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- ReceiptKey  
   @cParam2    NVARCHAR(20),  -- SKU
   @cParam3    NVARCHAR(20),  -- Qty
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
          ,@cTargetDB     NVARCHAR( 20)  
          ,@cLabelPrinter NVARCHAR( 10)  
          ,@cPaperPrinter NVARCHAR( 10)  
          ,@cReceiptKey   NVARCHAR( 10)  
          ,@cSKUCode      NVARCHAR( 20)  
          ,@cSKU          NVARCHAR( 20)  
          ,@cQty          NVARCHAR( 5) 
          ,@cLabelType    NVARCHAR( 10)  
          ,@cPrintType    NVARCHAR( 10) 
          ,@cReportType   NVARCHAR( 10)
          ,@cPrintJobName NVARCHAR( 60)
          ,@cDescription  NVARCHAR( 60) 
          ,@nQty          INT 
          ,@nSKUCnt       INT 
          ,@bSuccess      INT 

   DECLARE @cNoOfCopyAllowed NVARCHAR( 5)

   SELECT @cDescription = Description
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'RDTLBLRPT'
   AND   Storerkey = @cStorerKey
   AND   Code = @cOption

   SET @cLabelType = ''
   SET @cPrintType = ''

   -- Print either CIT or Price Tag label
   -- Each type can print by ReceiptKey or SKU + Qty (no. of copy)
   -- Retrieve label type by using the descript on the screen
   IF CHARINDEX( 'CIT', RTRIM( @cDescription)) > 0
      SET @cLabelType = 'CIT'

   IF CHARINDEX( 'PRICE', RTRIM( @cDescription)) > 0
      SET @cLabelType = 'PT'

   IF CHARINDEX( 'SKU', RTRIM( @cDescription)) > 0
      SET @cPrintType = 'SKU'

   IF CHARINDEX( 'ASN', RTRIM( @cDescription)) > 0
      SET @cPrintType = 'ASN'

   -- Print by ASN
   IF @cPrintType = 'ASN'
   BEGIN
      SET @cReceiptKey = @cParam1

      -- Check if SKU blank
      IF ISNULL(@cReceiptKey, '') = '' 
      BEGIN
         SET @nErrNo = 102351  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ASN# REQ
         GOTO Quit  
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND   ReceiptKey = @cReceiptKey)
      BEGIN
         SET @nErrNo = 102352  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INVALID ASN#
         GOTO Quit  
      END                      

      -- Set the SKU type label variable blank
      SET @cSKUCode = ''
      SET @cSKU = ''
      SET @cQty = ''
   END

   -- Print by SKU
   IF @cPrintType = 'SKU'
   BEGIN
      SET @cSKUCode = @cParam1
      SET @cQty = @cParam2

      -- Check if SKU blank
      IF ISNULL(@cSKUCode, '') = '' 
      BEGIN
         SET @nErrNo = 102353  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SKU/UPC REQ
         GOTO Quit  
      END

      EXEC [RDT].[rdt_GETSKUCNT]
         @cStorerKey  = @cStorerKey
        ,@cSKU        = @cSKUCode
        ,@nSKUCnt     = @nSKUCnt    OUTPUT
        ,@bSuccess    = @bSuccess   OUTPUT
        ,@nErr        = @nErrNo     OUTPUT
        ,@cErrMsg     = @cErrMsg    OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 102354  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid SKU/UPC
         GOTO Quit  
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 102355  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SameBarcodeSKU
         GOTO Quit  
      END

      EXEC [RDT].[rdt_GETSKU]
         @cStorerKey  = @cStorerKey
        ,@cSKU        = @cSKUCode   OUTPUT
        ,@bSuccess    = @bSuccess   OUTPUT
        ,@nErr        = @nErrNo     OUTPUT
        ,@cErrMsg     = @cErrMsg    OUTPUT

      SET @cSKU = @cSKUCode

      -- Check valid qty
      IF RDT.rdtIsValidQTY( @cQty, 1) = 0
      BEGIN
         SET @nErrNo = 102356  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Qty
         GOTO Quit  
      END

      -- (james01)
      SET @cNoOfCopyAllowed = rdt.RDTGetConfig( @nFunc, 'NoOfCopyAllowed', @cStorerKey)
      IF RDT.rdtIsValidQTY( @cNoOfCopyAllowed, 1) = 0
         SET @cNoOfCopyAllowed = '0'

      IF CAST( @cNoOfCopyAllowed AS INT) < CAST( @cQty AS INT)
      BEGIN
         SET @nErrNo = 102359  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Qty Over Limit
         GOTO Quit  
      END

      SET @nQty = CAST( @cQty AS INT)

      -- Set the ASN type label variable blank
      SET @cReceiptKey = ''
   END

   -- Bartender label config need setup before printing
   IF NOT EXISTS ( SELECT 1 FROM dbo.BartenderLabelCfg WITH (NOLOCK)
                   WHERE LabelType = 'CITPTLBL')
   BEGIN  
      SET @nErrNo = 102357  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup BartCfg  
      GOTO Quit  
   END  

   -- Get printer info  
   SELECT   
      @cLabelPrinter = Printer,   
      @cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
     
   /*-------------------------------------------------------------------------------  
  
                                    Print Ship Label  
  
   -------------------------------------------------------------------------------*/  
  
   -- Check label printer blank  
   IF ISNULL( @cLabelPrinter, '') = ''  
   BEGIN  
      SET @nErrNo = 102358  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
      GOTO Quit  
   END  

   SET @cPrintJobName = 'PRINT ' + CASE WHEN @cLabelType = 'CIT' THEN 'CIT' 
                        ELSE 'PRICE TAG' END + 
                        'LABEL BY ' + @cPrintType
   SET @cDataWindow = 'r_dw_bartender'
   SET @cTargetDB = 'IDSCN'

   -- Insert print job 
   SET @nErrNo = 0                    
   EXEC RDT.rdt_BuiltPrintJob                     
      @nMobile,                    
      @cStorerKey,                    
      'CITPTLBL',                    
      @cPrintJobName,                    
      @cDataWindow,                    
      @cLabelPrinter,                    
      @cTargetDB,                    
      @cLangCode,                    
      @nErrNo  OUTPUT,                     
      @cErrMsg OUTPUT,                    
      @cReceiptKey,
      @cSKU,
      @nQty,
      @cLabelType

   IF @nErrNo <> 0
      GOTO Quit  

Quit:  

GO