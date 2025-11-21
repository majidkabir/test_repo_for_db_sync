SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_647DecodeSKU01                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode QRCode, return SKU, Qty, Lot01, 04, 06                     */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2021-04-05  James     1.0   WMS-16636 Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_647DecodeSKU01] ( 
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cBarcode     NVARCHAR( 60),
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @nUCCQTY      INT            OUTPUT,
   @cUCCUOM      NVARCHAR( 6)   OUTPUT,  
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
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF ISNULL( @cBarcode, '') = '' --OR LEN( RTRIM( @cBarcode)) < 37
      GOTO Quit
   IF LEN( RTRIM( @cBarcode)) < 37
      GOTO Quit
      
   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         --Process:
         --1.	Decode QR code scanned from left 15th digital to 24th digital into Lottable01.
         --2.	Decode QR code scanned from left 26th digital to 35th digital into Lottable04
         --3.	Decode QR code scanned from left 37th digital to end into Lottable06
         --4.	Decode QR code scanned from left 1st digital to 13th digital into SKU.
         SET @cSKU = SUBSTRING( @cBarcode, 1, 13)
         SET @cLottable01 = SUBSTRING( @cBarcode, 15, 10)
         SET @dLottable04 = SUBSTRING( @cBarcode, 26, 10)
         SET @cLottable06 = SUBSTRING( @cBarcode, 37, LEN( RTRIM( @cBarcode)) - 36)
         SELECT @nUCCQTY = P.Pallet
         FROM dbo.PACK P WITH (NOLOCK)
         JOIN dbo.SKU S WITH (NOLOCK) ON ( P.PackKey = S.PACKKey)
         WHERE S.StorerKey = @cStorerKey
         AND   S.Sku = @cSKU 
      END
   END


Quit:

END

GO