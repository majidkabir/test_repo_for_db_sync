SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_600DecodeSP02                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 13-10-2016  ChewKP    1.0   WMS-512 Created                                */
/* 05-05-2023  YeeKung   1.1   WMS-22369 Add output for barcode in decodesp   */
/*                            (yeekung01)                                     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DecodeSP02] (
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

   DECLARE @nSCount INT
          ,@nBarcodeLength INT


   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               SET @nSCount = CHARINDEX( 'S', @cBarcode )

               IF ISNULL(@nSCount,0 )  = 0
               BEGIN
                    SET @nErrNo = 104851
                    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidBarcode
                    GOTO Quit
               END
               ELSE
               BEGIN
                   SET @nBarcodeLength = LEN(@cBarcode)
                   SET @cSKU = SUBSTRING(@cBarcode, 2, 6)
                   SET @cLottable02 = SUBSTRING(@cBarcode, 9 , @nBarcodeLength  ) --RIGHT (@cBarcode, @nBarcodeLength - @nSCount )


                   --INSERT INTO TRACEINFO ( TracEName , TimeIN , Col1, col2, col3, col4, col5  )
                   --VALUES ( 'rdt_600DecodeSP02' , getdate() , @cBarcode, @nBarcodeLength , @cSKU , @cLottable02, @nQty )

                   IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                               WHERE StorerKey = @cStorerKey
                               AND ReceiptKey = @cReceiptKey
                               AND SKU = @cSKU
                               AND Lottable02 = @cLottable02
                               AND BeforeReceivedQty > 0  )
                   BEGIN
                       SET @nErrNo = 104852
                       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BarcodeExist
                       GOTO Quit
                   END

                   IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI WITH (NOLOCK)
                               INNER JOIN dbo.Lot Lot WITH (NOLOCK) ON Lot.Lot = LLI.Lot
                               INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = Lot.Lot
                               WHERE LLI.StorerKey = @cStorerKey
                               AND LLI.SKU = @cSKU
                               AND LA.Lottable02 = @cLottable02 )
                   BEGIN
                       SET @nErrNo = 104853
                       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BarcodeExist
                       GOTO Quit
                   END

                   SELECT @nQty = Short
                   FROM dbo.Codelkup WITH (NOLOCK)
                   WHERE ListName = 'RDT-600'
                   AND StorerKey = @cStorerKey
                   AND Code = 'Qty'



               END
            END
         END
      END
   END

Quit:

END

GO