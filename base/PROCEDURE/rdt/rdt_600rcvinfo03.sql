SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600RcvInfo03                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Default lottable for receiving                                    */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 20-Apr-2016  Ung       1.0   SOS368437 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_600RcvInfo03]
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
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
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 600 -- Normal receive v7
   BEGIN
      -- DecodeSP not abstracted lottable
      IF @cLottable01 = ''             AND
         @cLottable02 = ''             AND
         @cLottable03 = ''             AND
         ISNULL( @dLottable04, 0) = 0  AND
         ISNULL( @dLottable05, 0) = 0  AND
         @cLottable06 = ''             AND
         @cLottable07 = ''             AND
         @cLottable08 = ''             AND
         @cLottable09 = ''             AND
         @cLottable10 = ''             AND
         @cLottable11 = ''             AND
         @cLottable12 = ''             AND
         ISNULL( @dLottable13, 0) = 0  AND
         ISNULL( @dLottable14, 0) = 0  AND
         ISNULL( @dLottable15, 0) = 0
      BEGIN
         -- Use ReceiveInfoSP logic
         SELECT TOP 1
            @cLottable01 = Lottable01,
            @cLottable02 = Lottable02,
            @cLottable03 = Lottable03,
            @dLottable04 = Lottable04,
            @dLottable05 = Lottable05,
            @cLottable06 = Lottable06,
            @cLottable07 = Lottable07,
            @cLottable08 = Lottable08,
            @cLottable09 = Lottable09,
            @cLottable10 = Lottable10,
            @cLottable11 = Lottable11,
            @cLottable12 = Lottable12,
            @dLottable13 = Lottable13,
            @dLottable14 = Lottable14,
            @dLottable15 = Lottable15
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
            AND SKU = @cSKU
         ORDER BY
            CASE WHEN @cID = ToID THEN 0 ELSE 1 END,
            CASE WHEN QTYExpected > 0 AND QTYExpected > BeforeReceivedQTY THEN 0 ELSE 1 END,
            ReceiptLineNumber
      END
   END
END

GO