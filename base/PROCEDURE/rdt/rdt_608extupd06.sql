SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608ExtUpd06                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Mark ASN if fully receive                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 17-Aug-2016  Ung       1.0   SOS359609 Created                             */
/* 12-Apr-2018  Ung       1.1   WMS-4603 Add SKU label                        */
/* 28-Jun-2019  YeeKung   1.2   WMS-9091 Finalize ASN                         */  
/* 08-Sep-2022  Ung       1.3   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtUpd06]
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


   DECLARE     @b_success           INT,      
               @cReceiptLineNumber  NVARCHAR( 5)    
               
   IF @nFunc = 608 -- Piece return
   BEGIN  
      IF @nStep = 2 -- ID, LOC
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
            -- Check variance
            IF NOT EXISTS( SELECT 1 
               FROM ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
                  AND QTYExpected <> BeforeReceivedQTY)
            BEGIN
               -- Mark ASN fully received
               UPDATE Receipt SET
                  RoutingTool = 'FULLY'
               WHERE ReceiptKey = @cReceiptKey
            END
         END
      END

      IF @nStep = 4 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get storer configure
            DECLARE @cSKULabel NVARCHAR(10)
            SET @cSKULabel = rdt.RDTGetConfig( @nFunc, 'SKULabel', @cStorerKey) 
            IF @cSKULabel = '0'
               SET @cSKULabel = ''
            
            -- SKU label
            IF @cSKULabel <> '' 
            BEGIN
               DECLARE @cLabelPrinter NVARCHAR(10) 
               DECLARE @cPaperPrinter NVARCHAR(10)
               DECLARE @cPickLOC      NVARCHAR(10)
               
               -- Get session info
               SELECT 
                  @cLabelPrinter = Printer, 
                  @cPaperPrinter = Printer_Paper
               FROM rdt.rdtMobRec WITH (NOLOCK)
               WHERE Mobile = @nMobile
               
               -- Get assigned pick LOC
               SET @cPickLOC = ''
               SELECT TOP 1 
                  @cPickLOC = LOC
               FROM SKUxLOC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU
                  AND LocationType = 'PICK'
               
               -- Get pick LOC
               IF @cPickLOC = ''
                  SELECT TOP 1 
                     @cPickLOC = LOC.LOC
                  FROM LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  WHERE LOC.LocationType = 'PICK' 
                     AND StorerKey = @cStorerKey
                     AND SKU = @cSKU
                     AND LLI.QTY > 0 
               
               -- SKU label
               IF @cPickLOC <> ''
               BEGIN
                  -- Common params
                  DECLARE @tSKULabel AS VariableTable
                  INSERT INTO @tSKULabel (Variable, Value) VALUES 
                     ( '@cSKU', @cSKU), 
                     ( '@cPickLOC', @cPickLOC)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                     @cSKULabel, -- Report type
                     @tSKULabel, -- Report params
                     'rdt_608ExtUpd06', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT
                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END
         END
		END      
   	IF @nStep = 8 -- Finalize ASN    
      BEGIN    
         IF @nInputKey =1    
         BEGIN    
            DECLARE @curRD CURSOR        
            SET @curRD = CURSOR FOR        
            SELECT ReceiptLineNumber        
            FROM dbo.ReceiptDetail WITH (NOLOCK)          
            WHERE ReceiptKey = @cReceiptKey          
               AND Storerkey = @cStorerKey      
               AND BeforeReceivedQTY > 0        
            OPEN @curRD        
            FETCH NEXT FROM @curRD INTO @cReceiptLineNumber        
            WHILE @@FETCH_STATUS = 0        
            BEGIN        
               EXEC dbo.ispFinalizeReceipt        
               @c_ReceiptKey         = @cReceiptKey        
               ,@b_Success           = @b_Success  OUTPUT        
               ,@n_err               = @nErrNo     OUTPUT        
               ,@c_ErrMsg            = @cErrMsg    OUTPUT        
               ,@c_ReceiptLineNumber = @cReceiptLineNumber        
               IF @nErrNo <> 0 OR @b_Success = 0        
               BEGIN        
                  SET @nErrNo = 142101        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Finalize fail      
                  GOTO Quit        
               END      
              
   				FETCH NEXT FROM @curRD INTO @cReceiptLineNumber    
         	END     
      	END    
   	END    
	END      
      
Quit:      
      
END

SET QUOTED_IDENTIFIER OFF

GO