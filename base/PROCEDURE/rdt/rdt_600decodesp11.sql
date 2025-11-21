SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_600DecodeSP11                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2021-10-21  James     1.0   WMS-18181 Created                              */
/* 2021-12-30  Chermaine 1.1   WMS-18586 Add expDate decode logic (cc01)      */
/* 05-05-2023  YeeKung   1.2   WMS-22369 Add output for barcode in decodesp   */
/*                            (yeekung01)                                     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DecodeSP11] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cBarcode     NVARCHAR( 2000)  OUTPUT,
   @cFieldName   NVARCHAR( 10),
   @cID          NVARCHAR( 18)  OUTPUT,
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @nQTY         INT            OUTPUT,
   @cLottable01  NVARCHAR( 18)  OUTPUT,
   @cLottable02  NVARCHAR( 18)  OUTPUT,
   @cLottable03  NVARCHAR( 18)  OUTPUT,
   @dLottable04  DATETIME       OUTPUT,
   @dLottable05  DATETIME       OUTPUT,
   @cLottable06  NVARCHAR( 30)  OUTPUT,
   @cLottable07  NVARCHAR( 30)  OUTPUT,
   @cLottable08  NVARCHAR( 30)  OUTPUT,
   @cLottable09  NVARCHAR( 30)  OUTPUT,
   @cLottable10  NVARCHAR( 30)  OUTPUT,
   @cLottable11  NVARCHAR( 30)  OUTPUT,
   @cLottable12  NVARCHAR( 30)  OUTPUT,
   @dLottable13  DATETIME       OUTPUT,
   @dLottable14  DATETIME       OUTPUT,
   @dLottable15  DATETIME       OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cRetailSKU     NVARCHAR( 20) = ''
   DECLARE @cLot01         NVARCHAR( 18) = ''
   DECLARE @cExpDate       NVARCHAR( 10)
   DECLARE @nBegin         INT
   DECLARE @nEnd           INT
   DECLARE @nSKUCnt        INT
   DECLARE @bSuccess       INT
   DECLARE @cSeparator     NVARCHAR( 2)
   DECLARE @cSeparator2     NVARCHAR( 2)

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
            	IF LEN(@cBarcode) > 24
            	BEGIN
            		--(cc01)
            		--SET @cSeparator = SUBSTRING( @cBarcode, 25, 2)
            		SET @cExpDate = SUBSTRING( @cBarcode, 19, 4) + '-01-' + SUBSTRING( @cBarcode, 23, 2)
            		SET @dLottable04 = rdt.RDTFORMATDATE(@cExpDate)

                  IF SUBSTRING( @cBarcode, 25, 2) <> '11'
                     SET @cLot01 =  SUBSTRING( @cBarcode, 27, 4)
            	END
            	ELSE
            	BEGIN
            		--SET @cSeparator = SUBSTRING( @cBarcode, 17, 2)

            		IF SUBSTRING( @cBarcode, 17, 2) <> '11'
                     SET @cLot01 = SUBSTRING( @cBarcode, 19, 18)
               END

               --IF @cSeparator NOT IN ('21', '10')
               --BEGIN
               --   SET @cSKU = @cBarcode
               --   GOTO Quit
               --END

               --Sample barcode 010704543208200521280419 OR 010704543208200510280419
               --Sample barcode 010704543205519317202211101821371 --(cc01)
               SET @cRetailSKU = SUBSTRING( @cBarcode, 3, 14)



               IF @cRetailSKU <> ''
               BEGIN
                  SET @nSKUCnt = 0
                  EXEC [RDT].[rdt_GETSKUCNT]
                     @cStorerKey  = @cStorerKey,
                     @cSKU        = @cRetailSKU,
                     @nSKUCnt     = @nSKUCnt       OUTPUT,
                     @bSuccess    = @bSuccess      OUTPUT,
                     @nErr        = @nErrNo        OUTPUT,
                     @cErrMsg     = @cErrMsg       OUTPUT

                  IF @nSKUCnt <> 1
                  BEGIN
                     SET @nErrNo =  177401
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
                     GOTO Quit
                  END

                  EXEC [RDT].[rdt_GETSKU]
                     @cStorerKey  = @cStorerkey,
                     @cSKU        = @cRetailSKU    OUTPUT,
                     @bSuccess    = @bSuccess      OUTPUT,
                     @nErr        = @nErrNo        OUTPUT,
                     @cErrMsg     = @cErrMsg       OUTPUT

                  IF @cLot01 <> ''
                  BEGIN
                     IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                                     WHERE ReceiptKey = @cReceiptKey
                                     AND   Sku = @cRetailSKU
                                     AND   Lottable01 = @cLot01)
                     BEGIN
                        SET @nErrNo =  177402
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot01
                        GOTO Quit
                     END
                  END

                  SET @cSKU = @cRetailSKU
                  SET @cLottable01 = @cLot01
                  INSERT INTO traceinfo (tracename, timein, Col1, Col2, col3) VALUES ('123', GETDATE(), @cSKU, @cLottable01, @dLottable04)
               END
            END
         END
      END
   END

Quit:

END

GO