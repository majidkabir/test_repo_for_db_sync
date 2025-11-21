SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_608DecodeSP04                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode SKU                                                        */
/*                                                                            */
/* Called from: rdtfnc_PieceReturn                                            */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 05-08-2017  YeeKung    1.0   WMS-21965 Created                             */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_608DecodeSP04] (
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


   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF EXISTS (SELECT 1 FROM lotattribute (NOLOCK) WHERE lottable07=@cBarcode and storerkey=@cstorerkey)
         BEGIN
            SELECT   @cLottable03   = lottable03,  
                     @dLottable04   = lottable04,
                     @dLottable05   = lottable05,
                     @cLottable07   = lottable07,  
                     @cSKU = LLI.SKU 
            FROM LOTXLOCXID LLI (NOLOCK)
               JOIN LOTAttribute LOT WITH (NOLOCK) ON LLI.lot=LOT.lot and LLI.SKU = LOT.SKU 
            WHERE lottable07=@cBarcode 
               AND LLI.storerkey=@cStorerKey
            ORDER BY lottable04,lottable05

            SET @nUCCQTY ='1'
         END
         
      END
   END

Quit:

END

GO