SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_598ExtUpd05                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 16-12-2022   Ung       1.0   WMS-21364 based on rdt_598ExtUpd02            */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_598ExtUpd05] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cRefNo       NVARCHAR( 20),
   @cColumnName  NVARCHAR( 20),
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
   @cReceiptKey  NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 598 -- Container receive
   BEGIN
      IF @nStep = 6 -- QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cLabelPrinter  NVARCHAR( 10)
            DECLARE @cPaperPrinter  NVARCHAR( 10)

            -- Get login info
            SELECT
               @cLabelPrinter = Printer,
               @cPaperPrinter = Printer_Paper
            FROM rdt.rdtMobRec WITH (NOLOCK)
            WHERE Mobile = @nMobile

            -- Common params
            DECLARE @tOutBoundList AS VariableTable
            INSERT INTO @tOutBoundList (Variable, Value) VALUES
               ( '@cReceiptKey', @cReceiptKey),
               ( '@cID',         @cID),
               ( '@cSKU',        @cSKU),
               ( '@cLottable02', @cLottable02),
               ( '@nQty',        CAST( @nQTY AS NVARCHAR( 10)))

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               'SKULABEL01',   -- Report type
               @tOutBoundList, -- Report params
               'rdt_598ExtUpd05',
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