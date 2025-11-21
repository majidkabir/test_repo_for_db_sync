SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Store procedure: [rdt_600ExtVal_OVRL]                                 */
/* Copyright: Maersk                                                     */
/*                                                                       */
/*                                                                       */
/* Date         Rev   Author   Purposes                                  */
/* 12/02/2024   1.0   WSE016   Lottable03 Validations                    */
/* 13/02/2024   1.1   WSE016   Prevert OverReceipt                       */
/*                                                                       */
/*************************************************************************/

CREATE   PROC [RDT].[rdt_600ExtVal_OVRL]
(
   @nMobile INT,
   @nFunc INT,
   @cLangCode NVARCHAR(3),
   @nStep INT,
   @nInputKey INT,
   @cFacility NVARCHAR(5),
   @cStorerKey NVARCHAR(15),
   @cReceiptKey NVARCHAR(10),
   @cPOKey NVARCHAR(10),
   @cLOC NVARCHAR(10),
   @cID NVARCHAR(18),
   @cSKU NVARCHAR(20),
   @cLottable01 NVARCHAR(18),
   @cLottable02 NVARCHAR(18),
   @cLottable03 NVARCHAR(18),
   @dLottable04 DATETIME,
   @dLottable05 DATETIME,
   @cLottable06 NVARCHAR(30),
   @cLottable07 NVARCHAR(30),
   @cLottable08 NVARCHAR(30),
   @cLottable09 NVARCHAR(30),
   @cLottable10 NVARCHAR(30),
   @cLottable11 NVARCHAR(30),
   @cLottable12 NVARCHAR(30),
   @dLottable13 DATETIME,
   @dLottable14 DATETIME,
   @dLottable15 DATETIME,
   @nQTY INT,
   @cReasonCode NVARCHAR(10),
   @cSuggToLOC NVARCHAR(10),
   @cFinalLOC NVARCHAR(10),
   @cReceiptLineNumber NVARCHAR(10),
   @nErrNo INT OUTPUT,
   @cErrMsg NVARCHAR(20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   IF @nFunc = 600
   BEGIN
      IF @nStep = 6 -- Check Lottable03
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF NOT EXISTS (SELECT 1  FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                        WHERE ReceiptKey = @cReceiptKey
                           AND Lottable01 = @cLottable01)
            BEGIN
               SET @nErrNo = 218074
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --218074 Lottable03 Not Exist
               GOTO Quit
            END

            IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                           WHERE ReceiptKey = @cReceiptKey
                              AND Lottable01 = @cLottable01
                              AND Lottable03 = @cLottable03
                              AND POKey = @cPOKey)
            BEGIN
               SET @nErrNo = 217975
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --217975 Lottable03 Mismatch
               GOTO Quit
            END

            IF EXISTS (SELECT 1 FROM dbo.RECEIPTDETAIL WITH(NOLOCK) 
                        WHERE toid = @cID 
                           AND storerkey = @cStorerKey
                           AND POKey <> @cPOKey
                           AND Lottable01 <> @cLottable01
                           AND Lottable03 <> @cLottable03)
            BEGIN
                  SET @nErrNo = 217976
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --217976 LPN Used Diff PO
                  GOTO Quit
            END

            IF EXISTS (SELECT 1 FROM dbo.RECEIPTDetail WITH(NOLOCK) 
                        WHERE Receiptkey = @cReceiptKey
                           AND Storerkey = @CStorerkey
                           AND POKey = @cPOKey
                           AND Lottable01 = @cLottable01
                           AND Lottable03 = @cLottable03
                           HAVING SUM(BeforeReceivedQty) + @nQTY >SUM(QTYExpected))
            BEGIN
               SET @nErrNo = 217977
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 217977 Over Receipt
               GOTO Quit
            END
         END
      END
   END

Quit:
END

GO