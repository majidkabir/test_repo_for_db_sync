SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600ExtUpd08                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Print pallet label                                                */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 23-Jul-2021  Ung       1.0   WMS-13279 Created                             */
/******************************************************************************/

CREATE PROC [RDT].[rdt_600ExtUpd08] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cSKU         NVARCHAR( 20), 
   @cLottable01  NVARCHAR( 18), 
   @cLottable02  NVARCHAR( 18), 
   @cLottable03  NVARCHAR( 18), 
   @dLottable04  DATETIME,      
   @dLottable05  DATETIME,      
   @cLottable06  NVARCHAR( 30), 
   @cLottable07  NVARCHAR( 30), 
   @cLottable08  NVARCHAR( 30), 
   @cLottable09  NVARCHAR( 30), 
   @cLottable10  NVARCHAR( 30), 
   @cLottable11  NVARCHAR( 30), 
   @cLottable12  NVARCHAR( 30), 
   @dLottable13  DATETIME,      
   @dLottable14  DATETIME,      
   @dLottable15  DATETIME,      
   @nQTY         INT,           
   @cReasonCode  NVARCHAR( 10), 
   @cSuggToLOC   NVARCHAR( 10), 
   @cFinalLOC    NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 10), 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 6 -- QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Storer configure
            DECLARE @cPalletLabel NVARCHAR( 10)
            SET @cPalletLabel = rdt.RDTGetConfig( @nFunc, 'PalletLabel', @cStorerKey)
            IF @cPalletLabel = '0'
               SET @cPalletLabel = ''

            -- Pallet label
            IF @cPalletLabel <> '' 
            BEGIN
               -- Get printer
               DECLARE @cLabelPrinter NVARCHAR( 10)
               DECLARE @cPaperPrinter NVARCHAR( 10)
               SELECT 
                  @cLabelPrinter = Printer, 
                  @cPaperPrinter = Printer_Paper 
               FROM rdt.rdtMobRec WITH (NOLOCK) 
               WHERE Mobile = @nMobile

               -- Common params
               DECLARE @tPalletLabel AS VariableTable
               INSERT INTO @tPalletLabel (Variable, Value) VALUES 
                  ( '@cStorerKey',         @cStorerKey),  
                  ( '@cReceiptKey',        @cReceiptKey),  
                  ( '@cReceiptLineNumber', @cReceiptLineNumber),  
                  ( '@cPOKey',             @cPOKey),  
                  ( '@cToID',              @cID)  

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                  @cPalletLabel, -- Report type
                  @tPalletLabel, -- Report params
                  'rdt_600ExtUpd08', 
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

GO