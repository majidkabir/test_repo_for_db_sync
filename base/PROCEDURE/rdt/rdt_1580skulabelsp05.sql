SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580SKULabelSP05                                   */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2018-10-02 1.0  Ung      WMS-6547 Created                               */
/***************************************************************************/

CREATE PROC [RDT].[rdt_1580SKULabelSP05] (
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

   DECLARE @cDocType       NVARCHAR( 1)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @cToID          NVARCHAR( 18)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @cPaperPrinter  NVARCHAR( 10)
   
   -- Get Receipt info
   SELECT 
      @cDocType = R.DocType, 
      @cSKU = RD.SKU, 
      @cToID = RD.ToID
   FROM dbo.Receipt R WITH (NOLOCK)
      JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
   WHERE R.ReceiptKey = @cReceiptKey
      AND RD.ReceiptLineNumber = @cReceiptLineNumber

   -- Trade return
   IF @cDocType = 'R' AND LEFT( @cToID, 2) = 'RP'
   BEGIN
      -- Get SKU info
      SET @cLOC = ''
      SELECT @cLOC = SL.LOC
      FROM SKUxLOC SL WITH (NOLOCK)
      WHERE SL.StorerKey = @cStorerKey
         AND SL.SKU = @cSKU
         AND SL.LocationType IN ('PICK', 'CASE')

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
         ( '@cLOC',                 @cLOC)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
         'SKULabel', -- Report type
         @tSKULabel,   -- Report params
         'rdt_1580SKULabelSP05', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END

Quit:


GO