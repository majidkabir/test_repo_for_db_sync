SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600DecodeSP14                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2022-07-26  Yeekung   1.0   WMS-20273 Created                              */
/* 05-05-2023  YeeKung   1.1   WMS-22369 Add output for barcode in decodesp   */
/*                            (yeekung01)                                     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DecodeSP14] (
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

   DECLARE @nSKUCnt INT
   DECLARE @cUOM NVARCHAR(20)
   DECLARE @cPackKey NVARCHAR(20)

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF EXISTS (SELECT 1 
                           FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(PKSKU)) 
                           WHERE StorerKey = @cStorerKey AND Sku = @cBarcode) 
            BEGIN
               SET @nQTY= 1
            END
            ELSE
            BEGIN
               IF EXISTS (SELECT 1 FROM dbo.UPC 
                            WHERE UPC = @cBarcode 
                           AND StorerKey = @cStorerKey )
               BEGIN
               
                  SELECT  @cSKU = SKU,
                           @cUOM = UOM 
                  FROM dbo.UPC UPC WITH (NOLOCK) 
                  WHERE UPC = @cBarcode 
                  AND StorerKey = @cStorerKey    

                  SELECT @cPackKey=packkey
                  FROM SKU (NOLOCK)
                  Where SKU=@cSKU
                     AND StorerKey = @cStorerKey  

                  SELECT @nQTY= CASE WHEN @cUOM=PackUOM3 THEN QTY 
                                       WHEN @cUOM=PackUOM2 THEN Innerpack 
                                       WHEN @cUOM=PackUOM1 THEN CaseCnt 
                                       WHEN @cUOM=PackUOM4 THEN Pallet END
                  FROM dbo.Pack (nolock)
                  WHERE packkey=@cPackKey
               END
               ELSE
               BEGIN
                  SET @nErrNo = 188651
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UPC
                  GOTO Quit
               END

            END
         END
           
      END
   END

Quit:

END

GO