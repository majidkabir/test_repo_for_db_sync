SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580SKULabelSP04                                   */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2018-07-05 1.0  Ung      WMS-5540 Created                               */
/***************************************************************************/

CREATE PROC [RDT].[rdt_1580SKULabelSP04] (
   @nMobile            INT,
   @nFunc              INT,
   @nStep              INT,
   @cLangCode          NVARCHAR( 3),
   @cStorerKey         NVARCHAR( 15),
   @cDataWindow        NVARCHAR( 60),
   @cPrinter           NVARCHAR( 10),
   @cTargetDB          NVARCHAR( 20),
   @cReceiptKey        NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR(  5),
   @nQTY               INT,
   @nErrNo             INT           OUTPUT,
   @cErrMsg            NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFacility     NVARCHAR( 5)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)
   DECLARE @cUserdefine10 NVARCHAR( 30)
   DECLARE @cSKU          NVARCHAR( 20)

   -- Get ReceiptDetail info
   SELECT 
      @cSKU = SKU, 
      @cUserdefine10 = Userdefine10
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
      AND ReceiptLineNumber = @cReceiptLineNumber

   IF @cUserdefine10 = 'Y' 
   BEGIN
      -- Get session info
      SELECT 
         @cFacility = Facility, 
         @cLabelPrinter = Printer, 
         @cPaperPrinter = Printer_Paper
      FROM rdt.rdtMobRec WITH (NOLOCK) 
      WHERE Mobile = @nMobile

      -- Common params
      DECLARE @tSKULabel AS VariableTable
      INSERT INTO @tSKULabel (Variable, Value) VALUES 
         ( '@cReceiptKey',          @cReceiptKey), 
         ( '@cReceiptLineNumber',   @cReceiptLineNumber), 
         ( '@cStorerKey',           @cStorerKey), 
         ( '@cSKU',                 @cSKU), 
         ( '@nQTY',                 CAST( @nQTY AS NVARCHAR(10)))

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
         'SKULabelLV', -- Report type
         @tSKULabel,   -- Report params
         'rdt_1580SKULabelSP04', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END

Quit:


GO