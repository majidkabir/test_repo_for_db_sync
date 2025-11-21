SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdtPalletLabelReprn                                    */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2014-04-28 1.0  James    SOS306942 Created                              */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtPalletLabelReprn] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- ReceiptKey  
   @cParam2    NVARCHAR(20),  -- Pallet ID  
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
  
   DECLARE @b_Success     INT  
     
   DECLARE @cDataWindow   NVARCHAR( 50)  
          ,@cTargetDB     NVARCHAR( 20)  
          ,@cLabelPrinter NVARCHAR( 10)  
          ,@cPaperPrinter NVARCHAR( 10)  
          ,@cReceiptKey   NVARCHAR( 10)  
          ,@cID           NVARCHAR( 20)  
          ,@cPrintTemplateSP  NVARCHAR( 40) 
   

   SET @cReceiptKey = @cParam1
   SET @cID = @cParam2  

   -- Both value must not blank
   IF ISNULL(@cReceiptKey, '') = '' OR ISNULL(@cID, '') = ''
   BEGIN
      SET @nErrNo = 87201  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --VALUE REQ
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
      GOTO Quit  
   END

   -- Check if it is valid ReceiptKey
   IF NOT EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK) 
                   WHERE ReceiptKey = @cReceiptKey 
                   AND   StorerKey = @cStorerKey)
    BEGIN  
      SET @nErrNo = 87202  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV ASN  
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
      GOTO Quit  
   END  

   -- Check if it is valid ReceiptKey
   IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                   WHERE ReceiptKey = @cReceiptKey 
                   AND   StorerKey = @cStorerKey
                   AND   TOID = @cID)
    BEGIN  
      SET @nErrNo = 87203  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV ID  
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
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
      SET @nErrNo = 87204  
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
      AND ReportType = 'PALLETLBL'  
        
   -- Insert print job  (james15)
   EXEC RDT.rdt_BuiltPrintJob  
      @nMobile,  
      @cStorerKey,  
      'PALLETLBL',       -- ReportType  
      'PRINT_PALLETLBL', -- PrintJobName  
      @cDataWindow,  
      @cLabelPrinter,  
      @cTargetDB,  
      @cLangCode,  
      @nErrNo  OUTPUT,  
      @cErrMsg OUTPUT,   
      @cReceiptKey, 
      @cID 


Quit:  

GO