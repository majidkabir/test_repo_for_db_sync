SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_550GetRcvInfo01                                 */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Get receive info                                            */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-01-20 1.0  Ung        SOS326375 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_550GetRcvInfo01] (
   @nMobile      INT,          
   @nFunc        INT,          
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT,          
   @nInputKey    INT,          
   @cStorer      NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18)  OUTPUT,
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @nQTY         INT            OUTPUT,
   @cUOM         NVARCHAR( 10)  OUTPUT, 
   @cLottable01  NVARCHAR( 18)  OUTPUT,
   @cLottable02  NVARCHAR( 18)  OUTPUT,
   @cLottable03  NVARCHAR( 18)  OUTPUT,
   @cLottable04  NVARCHAR( 16)  OUTPUT,
   @cLottable05  NVARCHAR( 16)  OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 550 -- Normal receiving
   BEGIN
      -- Get lottables
      SELECT 
         @cUOM = UOM,
         @cLottable01 = Lottable01, 
         @cLottable02 = Lottable02, 
         @cLottable03 = Lottable03, 
         @cLottable04 = rdt.rdtFormatDate( Lottable04) 
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND SKU = @cSKU
         AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
         AND QTYExpected > 0
         AND QTYExpected > BeforeReceivedQTY
      ORDER BY 
          CASE WHEN @cID = ToID THEN 0 ELSE 1 END
         ,ReceiptLineNumber
   END
Quit:


GO