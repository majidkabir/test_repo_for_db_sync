SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593SKULabel07                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 05-01-2020 1.0  YeeKung   WMS-15842 Created                             */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593SKULabel07] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- ASN
   @cParam2    NVARCHAR(20),  -- RSO
   @cParam3    NVARCHAR(20),  -- SKU/UPC
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success     INT
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cSKUDesc       NVARCHAR( 30)
   DECLARE @nQTY           INT
   DECLARE @nCaseCnt       INT
   DECLARE @cLottable02    Nvarchar(20)
   DECLARE @cFacility      NVARCHAR(20)

   DECLARE @tSKULabel AS VariableTable

   select @cSKU=RD.SKU,@cSKUDesc=S.DESCR,@nQTY=RD.QtyReceived ,@nCaseCnt=P.CaseCnt,@cLottable02=RD.Lottable02 
   from RECEIPTDETAIL RD(nolock)
   JOIN SKU S(nolock) on RD.StorerKey = S.StorerKey AND S.SKU = RD.Sku
   JOIN Pack P(nolock) on S.PackKey = P.PackKey
   where RD.ReceiptKey=@cParam1 and Convert( BIGINT,RD.ReceiptLineNumber)=@cParam2
   and S.StorerKey=@cstorerkey

   IF @@ROWCount =0
   BEGIN
      select  @cSKU=S.SKU,@cSKUDesc=S.DESCR,@nQTY=@cParam3,@nCaseCnt=P.CaseCnt,@cLottable02=L.Lottable02 
      from  SKU S(nolock) 
      JOIN Pack P(nolock) on S.PackKey = P.PackKey
      JOIN LOTATTRIBUTE L (NOLOCK) on L.StorerKey = S.StorerKey AND L.SKU = S.Sku 
      where S.StorerKey=@cstorerkey and S.SKU = @cParam1 AND L.Lottable02 = @cParam2
   END

   -- Get login info
   SELECT 
      @cLabelPrinter = Printer, 
      @cPaperPrinter = Printer_Paper, 
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile


   INSERT INTO @tSKULabel (Variable, Value) VALUES 
      ( '@cSKU',       @cSKU), 
      ( '@cSKUDec1',     @cSKUDesc), 
      ( '@cLottable02',  @cLottable02),
      ( '@nQty',    CAST (@nQty AS NVARCHAR(10))),
      ( '@nCaseCnt',    CAST (@nCaseCnt AS NVARCHAR(10)))

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
      'SKULABEL', -- Report type
      @tSKULabel, -- Report params
      'rdt_593SKULabel07', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit
   
Quit:


GO