SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608ExtUpd10                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Print Label                                                       */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2020-07-08  James     1.0   WMS-13257 Created                              */
/* 2022-09-08  Ung       1.1   WMS-20348 Expand RefNo to 60 chars             */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtUpd10]
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

   IF @nFunc = 608 -- Piece return
   BEGIN  
      IF @nStep = 5 -- Lottable
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cLabelPrinter  NVARCHAR( 10)    
            DECLARE @cUCClabel      NVARCHAR( 10)     
            DECLARE @tUCClabel      VariableTable    
    
            SELECT @cLabelPrinter = Printer     
            FROM RDT.RDTMOBREC WITH (NOLOCK)    
            WHERE Mobile = @nMobile     
    
            SET @cUCClabel = rdt.rdtGetConfig( @nFunc, 'UCCLABEL', @cStorerKey)    
            IF @cUCClabel = '0'    
               SET @cUCClabel = ''    
               
            IF @cUCClabel <> ''  
            BEGIN  
               INSERT INTO  @tUCClabel (Variable, Value) VALUES ( '@cUserdefine01', @cLottable01)   
               INSERT INTO  @tUCClabel (Variable, Value) VALUES ( '@cReceiptkey', @cReceiptKey)     
               INSERT INTO  @tUCClabel (Variable, Value) VALUES ( '@cSKU', @cSKU)     

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, '', 
                  @cUCClabel, -- Report type
                  @tUCClabel, -- Report params
                  'rdt_608ExtUpd10', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END   
         END
      END
   END

Quit:

END

SET QUOTED_IDENTIFIER OFF

GO