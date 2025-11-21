SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_600DecodeSP07                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 06-01-2021  Chermaine 1.0   WMS-15955 Created                              */
/* 05-05-2023  YeeKung   1.1   WMS-22369 Add output for barcode in decodesp   */
/*                            (yeekung01)                                     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DecodeSP07] (
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

   DECLARE @cUPC        Nvarchar( 30)
   DECLARE @cScanQty    NVARCHAR( 5)

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET V_String42 = @cBarcode WHERE Mobile = @nMobile
            	--G128 barcode start with 02 space
            	IF @cBarcode LIKE '02%'
            	BEGIN
            		SET @cScanQty = RIGHT(@cBarcode , CHARINDEX ('73' ,REVERSE(@cBarcode))-1)
            		SET @cUPC = SUBSTRING(@cBarcode,3,LEN(@cBarcode)-LEN(@cScanQty)-4)
            	END
            	ELSE
            	BEGIN
            		--normal upc barcode
            		SET @cUPC = @cBarcode

            		--SELECT TOP 1
            		--   @nQTY =P.Qty
            		--FROM UPC U WITH (NOLOCK)
            		--JOIN PACK P WITH (NOLOCK) ON (U.Uom = P.PackUOM3 AND U.PackKey = P.PackKey)
            		--WHERE U.UPC = @cUPC
            		--AND U.storerKey = @cStorerKey
            	END
            	SET @cSKU = @cUPC
            END
         END
      END
   END

Quit:

END

GO