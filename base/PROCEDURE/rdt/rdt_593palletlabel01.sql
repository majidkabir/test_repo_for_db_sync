SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdt_593PalletLabel01                                   */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2017-09-06 1.0  James    WMS2715 Created                                */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593PalletLabel01] (  
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
     
   DECLARE @cLabelPrinter NVARCHAR( 10)  
          ,@cPaperPrinter NVARCHAR( 10)  
          ,@cReceiptKey   NVARCHAR( 10)  
          ,@cID           NVARCHAR( 20)  
          ,@cPalletLabel  NVARCHAR( 20)
          ,@tPalletLabel   VariableTable
          ,@cReceiptLineNumber   NVARCHAR( 5)
          ,@nInputKey      INT
          ,@cFacility      NVARCHAR( 5)
   

   SET @cReceiptKey = @cParam1
   SET @cID = @cParam2  

   -- Both value must not blank
   IF ISNULL(@cReceiptKey, '') = '' OR ISNULL(@cID, '') = ''
   BEGIN
      SET @nErrNo = 114351  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --VALUE REQ
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
      GOTO Quit  
   END

   -- Check if it is valid ReceiptKey
   IF NOT EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK) 
                   WHERE ReceiptKey = @cReceiptKey 
                   AND   StorerKey = @cStorerKey)
    BEGIN  
      SET @nErrNo = 114352  
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
      SET @nErrNo = 114353  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV ID  
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1  
      GOTO Quit  
   END  

   SET @cPalletLabel = rdt.RDTGetConfig( @nFunc, 'PalletLabel', @cStorerKey)
   IF @cPalletLabel = '0'
      SET @cPalletLabel = ''

   IF @cPalletLabel = ''
    BEGIN  
      SET @nErrNo = 114354  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO RPT SETUP  
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
   IF @cOption = '1' -- Yes
   BEGIN
      IF @cPalletLabel <> ''
      BEGIN
         SELECT TOP 1 @cReceiptLineNumber = ReceiptLineNumber
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   ToID = @cID
         ORDER BY 1

         -- Common params
         INSERT INTO @tPalletLabel (Variable, Value) VALUES 
         ( '@cStorerKey', @cStorerKey),
         ( '@cReceiptKey', @cReceiptKey),
         ( '@cReceiptLineNumber_Start', @cReceiptLineNumber),
         ( '@cReceiptLineNumber_End', @cReceiptLineNumber),
         ( '@cPOKey', ''),
         ( '@cToID', '')

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
            @cPalletLabel, -- Report type
            @tPalletLabel, -- Report params
            'rdt_593PalletLabel01', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
   END

Quit:  

GO