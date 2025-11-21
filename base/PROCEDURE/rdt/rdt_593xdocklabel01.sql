SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Store procedure: rdt_593XDockLabel01                                    */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2018-07-11 1.0  Ung      WMS-4806 Created                               */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593XDockLabel01] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- ReceiptKey    
   @cParam2    NVARCHAR(20),  -- LineNo
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
  
   DECLARE @cLabelPrinter     NVARCHAR( 10)  
   DECLARE @cPaperPrinter     NVARCHAR( 10)  
   DECLARE @cReceiptKey       NVARCHAR( 10)
   DECLARE @cFacility         NVARCHAR( 5)  
   DECLARE @cExternReceiptKey NVARCHAR( 20)
   DECLARE @cLineNo           NVARCHAR( 5)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cToID             NVARCHAR( 18)
   DECLARE @cLottable08       NVARCHAR( 30)
   DECLARE @cLottable09       NVARCHAR( 30)
   DECLARE @cPalletLabel      NVARCHAR( 20)
   DECLARE @cStoreLabel       NVARCHAR( 20)
   
   SET @cReceiptKey = @cParam1
   SET @cLineNo = @cParam2  

   -- Both value must not blank
   IF @cReceiptKey = ''
   BEGIN
      SET @nErrNo = 126051  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need ReceiptKey
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
      GOTO Quit  
   END

   -- Check ReceiptKey valid
   IF NOT EXISTS( SELECT 1 FROM dbo.Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND StorerKey = @cStorerKey)
    BEGIN  
      SET @nErrNo = 126052  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid ASN  
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
      GOTO Quit  
   END  

   -- Check blank
   IF @cLineNo = ''
   BEGIN
      SET @nErrNo = 126053  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need LineNo
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param2  
      GOTO Quit  
   END

   -- Check LineNo in Receipt
   IF NOT EXISTS( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ReceiptLineNumber = @cLineNo)
   BEGIN
      SET @nErrNo = 126054  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid LineNo
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param2  
      GOTO Quit  
   END

   -- Get ReceiptDetail info
   SELECT 
      @cExternReceiptKey = ExternReceiptKey, 
      @cSKU = SKU, 
      @cToID = TOID, 
      @cLottable08 = Lottable08, 
      @cLottable09 = Lottable09
   FROM dbo.ReceiptDetail WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey 
      AND ReceiptLineNumber = @cLineNo

   -- Get login info
   SELECT 
      @cFacility = Facility, 
      @cLabelPrinter = Printer,   
      @cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   
   /*-------------------------------------------------------------------------------  
  
                                      Print XDOCK label 
  
   -------------------------------------------------------------------------------*/  
   -- Get storer config
   SET @cPalletLabel = rdt.RDTGetConfig( @nFunc, 'PalletLabel', @cStorerKey)
   IF @cPalletLabel = '0'
      SET @cPalletLabel = ''
   SET @cStoreLabel = rdt.RDTGetConfig( @nFunc, 'StoreLabel', @cStorerKey)
   IF @cStoreLabel = '0'
      SET @cStoreLabel = ''

   -- Pallet label
   IF @cPalletLabel <> ''
   BEGIN  
      -- Common params
      DECLARE @tPalletLabel VariableTable
      INSERT INTO @tPalletLabel (Variable, Value) VALUES 
         ( '@cReceiptKey',       @cReceiptKey),
         ( '@cExternReceiptKey', @cExternReceiptKey), 
         ( '@cSKU',              @cSKU)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
         @cPalletLabel, -- Report type
         @tPalletLabel, -- Report params
         'rdt_593XDockLabel01', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT

      IF @nErrNo <> 0
         GOTO Quit
   END

   -- Store label
   IF @cStoreLabel <> ''
   BEGIN  
      -- Common params
      DECLARE @tStoreLabel VariableTable
      INSERT INTO @tStoreLabel (Variable, Value) VALUES 
         ( '@cReceiptKey',  @cReceiptKey),
         ( '@cSKU',         @cSKU),
         ( '@cLottable08',  @cLottable08), 
         ( '@cLottable09',  @cLottable09), 
         ( '@cToID',        @cToID)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
         @cStoreLabel, -- Report type
         @tStoreLabel, -- Report params
         'rdt_593XDockLabel01', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT

      IF @nErrNo <> 0
         GOTO Quit
   END
   
Quit:  

GO