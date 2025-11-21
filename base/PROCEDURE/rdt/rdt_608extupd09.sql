SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608ExtUpd09                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Mark ASN if fully receive                                         */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 15-08-2018  Ung       1.0   WMS-5962 Created                               */
/* 2022-09-08  Ung       1.1   WMS-20348 Expand RefNo to 60 chars             */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtUpd09]
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
      IF @nStep = 4 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get storer configure
            DECLARE @cProductLabel NVARCHAR(10)
            SET @cProductLabel = rdt.RDTGetConfig( @nFunc, 'ProductLabel', @cStorerKey) 
            IF @cProductLabel = '0'
               SET @cProductLabel = ''
            
            -- Product label
            IF @cProductLabel <> '' 
            BEGIN
               DECLARE @cLabelPrinter NVARCHAR(10) 
               DECLARE @cPaperPrinter NVARCHAR(10)
               
               -- Get session info
               SELECT 
                  @cLabelPrinter = Printer, 
                  @cPaperPrinter = Printer_Paper
               FROM rdt.rdtMobRec WITH (NOLOCK)
               WHERE Mobile = @nMobile
               
               -- Common params
               DECLARE @tProductLabel AS VariableTable
               INSERT INTO @tProductLabel (Variable, Value) VALUES 
                  ( '@cReceiptKey', @cReceiptKey), 
                  ( '@cStorerKey', @cStorerKey), 
                  ( '@cSKU', @cSKU)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                  @cProductLabel, -- Report type
                  @tProductLabel, -- Report params
                  'rdt_608ExtUpd09', 
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