SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: [rdt_600ExtUpdVLT]                                  */
/* Copyright: Maersk                                                    */
/*                                                                      */
/* Purpose: Update lottable05                                           */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 24/06/2024   1.0  PPA374   Created                                   */
/* 18/10/2024   1.1  PPA374   Added UPDATE of SKUs to other lot codes   */
/* 18/10/2024   1.2  PPA374   Lottable05 UPDATE is added                */
/************************************************************************/

CREATE     PROC [RDT].[rdt_600ExtUpdVLT] (
   @nMobile            INT,
   @nFunc              INT,
   @cLangCode          NVARCHAR( 3),
   @nStep              INT,
   @nInputKey          INT,
   @cFacility          NVARCHAR( 5),
   @cStorerKey         NVARCHAR( 15),
   @cReceiptKey        NVARCHAR( 10),
   @cPOKey             NVARCHAR( 10),
   @cLOC               NVARCHAR( 10),
   @cID                NVARCHAR( 18),
   @cSKU               NVARCHAR( 20),
   @cLottable01        NVARCHAR( 18),
   @cLottable02        NVARCHAR( 18),
   @cLottable03        NVARCHAR( 18),
   @dLottable04        DATETIME,
   @dLottable05        DATETIME,
   @cLottable06        NVARCHAR( 30),
   @cLottable07        NVARCHAR( 30),
   @cLottable08        NVARCHAR( 30),
   @cLottable09        NVARCHAR( 30),
   @cLottable10        NVARCHAR( 30),
   @cLottable11        NVARCHAR( 30),
   @cLottable12        NVARCHAR( 30),
   @dLottable13        DATETIME,
   @dLottable14        DATETIME,
   @dLottable15        DATETIME,
   @nQTY               INT,
   @cReasonCode        NVARCHAR( 10),
   @cSuggToLOC         NVARCHAR( 10),
   @cFinalLOC          NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @nErrNo             INT            OUTPUT,
   @cErrMsg            NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   IF @nFunc = 600
   BEGIN
      IF @nStep = 3
      BEGIN
         BEGIN
            UPDATE dbo.SKU WITH(ROWLOCK)
               SET LottableCode = 'HUSQBATTERY'
            WHERE Style = 'B' AND StorerKey = @cStorerKey AND LottableCode <> 'HUSQBATTERY'
         
            UPDATE dbo.SKU WITH(ROWLOCK)
               SET LottableCode = 'HUSQSHELF'
            WHERE Style = 'SHLV' AND StorerKey = @cStorerKey AND LottableCode <> 'HUSQSHELF'          
         END
      END

      IF @nStep = 6
      BEGIN
         IF @dLottable05 <> ''
         BEGIN
            UPDATE dbo.receiptdetail WITH(ROWLOCK)
               SET Lottable05 = @dLottable05
            WHERE receiptkey = @cReceiptKey
               AND storerkey = @cstorerkey
               AND toId = @cID
               AND Sku = @cSKU
               AND toloc = @cLOC
         END
      END
   END
END

GO