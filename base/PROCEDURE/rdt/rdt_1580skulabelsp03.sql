SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580SKULabelSP03                                   */
/*                                                                         */
/* Modifications log: Print pallet label if sku fully received on this     */
/*                    pallet. 1 pallet only 1 SKU for this storer          */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2016-05-05 1.0  James    SOS367156 Created                              */
/***************************************************************************/

CREATE PROC [RDT].[rdt_1580SKULabelSP03] (
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

   DECLARE @cToID    NVARCHAR( 18)

   SELECT @cToID = V_ID
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- CNA pallet is 1 pallet 1 sku, no need filter sku here
   IF EXISTS ( SELECT 1 FROM ReceiptDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   ReceiptKey = @cReceiptKey
               AND   ToID = @cToID  
               AND   FinalizeFlag <> 'Y'
               GROUP BY ToID
               HAVING SUM( BeforeReceivedQty) >= SUM( QtyExpected))
   BEGIN
      -- Insert print job to print pallet label
      EXEC RDT.rdt_BuiltPrintJob
         @nMobile,
         @cStorerKey,
         'SKULABEL',       -- ReportType
         'PRINT_SKULABEL', -- PrintJobName
         @cDataWindow,
         @cPrinter,
         @cTargetDB,
         @cLangCode,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT,
         @cReceiptKey,
         @cToID
   END

GO