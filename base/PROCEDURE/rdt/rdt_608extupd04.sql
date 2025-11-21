SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_608ExtUpd04                                           */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Calc suggest location, booking                                    */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 14-Sep-2016  ChewKP    1.0   SOS#314 Created                               */  
/* 17-Aug-2018  Ung       1.1   WMS-4675 Add PalletManifest                   */
/*                              Add QTY to price label                        */
/* 08-Sep-2022  Ung       1.2   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_608ExtUpd04]  
   @nMobile       INT,             
   @nFunc         INT,             
   @cLangCode     NVARCHAR( 3),    
   @nStep         INT,             
   @nAfterStep    INT,              
   @nInputKey     INT,             
   @cFacility     NVARCHAR( 5),     
   @cStorerKey    NVARCHAR( 15),   
   @cReceiptKey   NVARCHAR( 10),   
   @cPOKey        NVARCHAR( 10),   
   @cRefNo        NVARCHAR( 60),   
   @cID           NVARCHAR( 18),   
   @cLOC          NVARCHAR( 10),   
   @cMethod       NVARCHAR( 1),   
   @cSKU          NVARCHAR( 20),   
   @nQTY          INT,             
   @cLottable01   NVARCHAR( 18),   
   @cLottable02   NVARCHAR( 18),   
   @cLottable03   NVARCHAR( 18),   
   @dLottable04   DATETIME,        
   @dLottable05   DATETIME,        
   @cLottable06   NVARCHAR( 30),   
   @cLottable07   NVARCHAR( 30),   
   @cLottable08   NVARCHAR( 30),   
   @cLottable09   NVARCHAR( 30),   
   @cLottable10   NVARCHAR( 30),   
   @cLottable11   NVARCHAR( 30),   
   @cLottable12   NVARCHAR( 30),   
   @dLottable13   DATETIME,        
   @dLottable14   DATETIME,        
   @dLottable15   DATETIME,   
   @cRDLineNo     NVARCHAR( 5),   
   @nErrNo        INT           OUTPUT,   
   @cErrMsg       NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @bSuccess    INT  
   DECLARE @nTranCount  INT  
          ,@cStyle      NVARCHAR(20)       
          ,@cColor      NVARCHAR(10)
          ,@cLot        NVARCHAR(10) 
          ,@cSuggToLOC  NVARCHAR(10) 
          ,@cSKUClass   NVARCHAR(10)
          ,@cSKUGroup   NVARCHAR(10) 
          ,@cDocType    NVARCHAR(1) 
   
   DECLARE @cDataWindow   NVARCHAR( 50)    
   DECLARE @cTargetDB     NVARCHAR( 20)    
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT  

   BEGIN TRAN  
   SAVE TRAN rdt_608ExtUpd04  
  
   IF @nFunc = 608 -- Piece return  
   BEGIN    
      IF @nStep = 4 
      BEGIN 
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF ISNULL(@cSKU,'' )  <> '' 
            BEGIN 
               
               -- Print Carton Label --
               SET @cDataWindow = ''
               SET @cTargetDB   = ''
               
                  
               SELECT @cLabelPrinter = Printer
               FROM rdt.rdtMobrec WITH (NOLOCK)
               WHERE Mobile = @nMobile
               
               SELECT @cSKUClass = ISNULL(Class,'' ) 
                    , @cSKUGroup = ISNULL(SKUGroup,'') 
               FROM dbo.SKU WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU 
               
               SELECT @cDocType = DocType
               FROM dbo.Receipt WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND ReceiptKey = @cReceiptKey 

               IF EXISTS ( SELECT 1 FROM dbo.Codelkup WITH (NOLOCK)
                           WHERE ListName = 'SKULabel'
                           AND StorerKey = @cStorerKey
                           AND UDF01 = @cSKUClass
                           AND UDF02 = @cSKUGroup
                           AND UDF03 = @cDocType ) 
               BEGIN
               
                  SELECT @cDataWindow = DataWindow,     
                         @cTargetDB = TargetDB     
                  FROM rdt.rdtReport WITH (NOLOCK)     
                  WHERE StorerKey = @cStorerKey    
                  AND   ReportType = 'PRICELBLJS'   
               
               
                  EXEC RDT.rdt_BuiltPrintJob      
                      @nMobile,      
                      @cStorerKey,      
                      'PRICELBLJS',    -- ReportType      
                      'PRICELBLJS',    -- PrintJobName      
                      @cDataWindow,      
                      @cLabelPrinter,      
                      @cTargetDB,      
                      @cLangCode,      
                      @nErrNo  OUTPUT,      
                      @cErrMsg OUTPUT,    
                      @cStorerKey,
                      @cSKU, 
                      @nQTY
                   
                  IF @nErrNo <> 0 
                  BEGIN 
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
                     EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1   
                     GOTO QUIT  
                  END       
               END
            END
         END
         
         IF @nInputKey = 0 -- ESC
         BEGIN
            -- Get ASN info
            SELECT @cDocType = DocType FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey 
            
            -- Normal ASN
            IF @cDocType = 'A'
            BEGIN
               -- Storer configure
               DECLARE @cPalletManifest NVARCHAR( 10)
               SET @cPalletManifest = rdt.RDTGetConfig( @nFunc, 'PalletManifest', @cStorerKey)
               IF @cPalletManifest = '0'
                  SET @cPalletManifest = ''

               -- Pallet Manifest
               IF @cPalletManifest <> '' 
               BEGIN
                  -- Get printer
                  SELECT 
                     @cLabelPrinter = Printer, 
                     @cPaperPrinter = Printer_Paper 
                  FROM rdt.rdtMobRec WITH (NOLOCK) 
                  WHERE Mobile = @nMobile

                  -- Common params
                  DECLARE @tPalletManifest AS VariableTable
                  INSERT INTO @tPalletManifest (Variable, Value) VALUES 
                     ( '@cReceiptKey',    @cReceiptKey), 
                     ( '@cID',            @cID), 
                     ( '@cLOC',           @cLOC)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                     @cPalletManifest, -- Report type
                     @tPalletManifest, -- Report params
                     'rdt_608ExtUpd07', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT
                  -- IF @nErrNo <> 0
                  --    GOTO Quit
                  SET @nErrNo = 0 -- Allow ESC if error occur
               END
            END
         END
      END
   END  
   GOTO Quit  
     
RollBackTran:  
   ROLLBACK TRAN rdt_608ExtUpd04 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_608ExtUpd04
END  
  

GO