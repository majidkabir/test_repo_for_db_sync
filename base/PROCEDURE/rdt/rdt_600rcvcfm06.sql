SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600RcvCfm06                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Workaround to print pallet label for each receive                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 14-06-2019  Ung       1.0   WMS-9450 Created                               */
/* 19-11-2020  YeeKung   1.1   WMS-15597 Add SerialNo(yeekung01)              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_600RcvCfm06] (
   @nFunc          INT,           
   @nMobile        INT,           
   @cLangCode      NVARCHAR( 3),  
   @cStorerKey     NVARCHAR( 15), 
   @cFacility      NVARCHAR( 5),  
   @cReceiptKey    NVARCHAR( 10), 
   @cPOKey         NVARCHAR( 10), 
   @cToLOC         NVARCHAR( 10), 
   @cToID          NVARCHAR( 18), 
   @cSKUCode       NVARCHAR( 20), 
   @cSKUUOM        NVARCHAR( 10), 
   @nSKUQTY        INT,           
   @cUCC           NVARCHAR( 20), 
   @cUCCSKU        NVARCHAR( 20), 
   @nUCCQTY        INT,           
   @cCreateUCC     NVARCHAR( 1),  
   @cLottable01    NVARCHAR( 18), 
   @cLottable02    NVARCHAR( 18), 
   @cLottable03    NVARCHAR( 18), 
   @dLottable04    DATETIME,      
   @dLottable05    DATETIME,      
   @cLottable06    NVARCHAR( 30), 
   @cLottable07    NVARCHAR( 30), 
   @cLottable08    NVARCHAR( 30), 
   @cLottable09    NVARCHAR( 30), 
   @cLottable10    NVARCHAR( 30), 
   @cLottable11    NVARCHAR( 30), 
   @cLottable12    NVARCHAR( 30), 
   @dLottable13    DATETIME,      
   @dLottable14    DATETIME,      
   @dLottable15    DATETIME,      
   @nNOPOFlag      INT,           
   @cConditionCode NVARCHAR( 10), 
   @cSubreasonCode NVARCHAR( 10), 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
   @cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT,
   @cSerialNo      NVARCHAR( 30) = '',   
   @nSerialQTY     INT = 0,   
   @nBulkSNO       INT = 0,   
   @nBulkSNOQTY    INT = 0 

) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nFunc = 600 -- Normal receiving
   BEGIN
      -- Receive
      EXEC rdt.rdt_Receive_V7
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPOKey,  
         @cToLOC        = @cToLOC,
         @cToID         = @cToID,
         @cSKUCode      = @cSKUCode,
         @cSKUUOM       = @cSKUUOM,
         @nSKUQTY       = @nSKUQTY,
         @cUCC          = '',
         @cUCCSKU       = '',
         @nUCCQTY       = '',
         @cCreateUCC    = '',
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = NULL,
         @cLottable06   = @cLottable06,
         @cLottable07   = @cLottable07,
         @cLottable08   = @cLottable08,
         @cLottable09   = @cLottable09,
         @cLottable10   = @cLottable10,
         @cLottable11   = @cLottable11,
         @cLottable12   = @cLottable12,
         @dLottable13   = @dLottable13,
         @dLottable14   = @dLottable14,
         @dLottable15   = @dLottable15,
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = '', 
         @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT   
      IF @nErrNo <> 0
         GOTO Quit
   
      -- Print pallet label
      IF @cToID <> ''
      BEGIN
         DECLARE @cPalletLabel NVARCHAR( 20)
         DECLARE @tPalletLabel VariableTable

         SET @cPalletLabel = rdt.RDTGetConfig( @nFunc, 'PalletLabel', @cStorerKey)
         IF @cPalletLabel = '0'
            SET @cPalletLabel = ''

         -- Pallet label
         IF @cPalletLabel <> ''
         BEGIN
            DECLARE @cLabelPrinter NVARCHAR(10)
            DECLARE @cPaperPrinter NVARCHAR(10)
            
            SELECT 
               @cLabelPrinter = Printer,
               @cPaperPrinter = Printer_Paper
            FROM rdt.rdtMobRec WITH (NOLOCK)
            WHERE Mobile = @nMobile
            
            -- Common params
            INSERT INTO @tPalletLabel (Variable, Value) VALUES 
               ( '@cStorerKey', @cStorerKey),
               ( '@cReceiptKey', @cReceiptKey),
               ( '@cReceiptLineNumber_Start', @cReceiptLineNumberOutput),
               ( '@cReceiptLineNumber_End', @cReceiptLineNumberOutput),
               ( '@cPOKey', @cPOKey),
               ( '@cToID', @cToID)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 7, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
               @cPalletLabel, -- Report type
               @tPalletLabel, -- Report params
               'rdt_600RcvCfm06', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
   END
   
Quit:
   
END

GO