SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_600DecodeSP06                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 24-02-2020  Chermaine 1.0   WMS-12115 Created                              */
/* 16-12-2020  Chermiane 1.1   WMS-15775 Add checking len(barcode)            */
/*                             and check lot02 (cc01)                         */
/* 10-03-2021  Chermaine 1.2   WMS-16434 Change Decode logic (cc02)           */
/* 05-05-2023  YeeKung   1.3   WMS-22369 Add output for barcode in decodesp   */
/*                            (yeekung01)                                     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DecodeSP06] (
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

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''  AND LEN (@cBarcode) > 10 --(cc01)
            BEGIN
               DECLARE @nRowcount INT
               DECLARE @cFacility NVARCHAR(5)
               DECLARE @nBeforeRecQty INT

               -- Get session info
               SELECT @cFacility = Facility FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

               /*
                  Format: QR Code
                  Total 5 fields. Delimeter is semicolon
                  E.g. SKU; Lottable02; Lottable07; Lottable03; 1
               */

               DECLARE @cQTY  NVARCHAR( 8)
               SET @cQTY = ''

               -- Column 1: SKU
               SET @cSKU = rdt.rdtGetParsedString( @cBarcode, 1, ';')
               IF @cSKU = ''
               BEGIN
                  SET @nErrNo = 148751
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Require SKU
                  GOTO Quit
               END

               --(cc02)
               IF NOT EXISTS (SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE storerKey = @cStorerKey AND receiptKey = @cReceiptKey AND SKU = @cSKU)
               BEGIN
               	SET @nErrNo = 148758
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong SKU
                  GOTO Quit
               END

               -- Column 2: Lottable02
               SET @cLottable02 = rdt.rdtGetParsedString( @cBarcode, 2, ';')
               IF @cLottable02 = ''
               BEGIN
                  SET @nErrNo = 148752
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Require L02
                  GOTO Quit
               END

               --(cc02)
               IF EXISTS (SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE storerKey = @cStorerKey AND receiptKey = @cReceiptKey AND Lottable02 = @cLottable02)
               BEGIN
               	SET @nErrNo = 148757
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Dup Lot02
                  GOTO Quit
               END

               SET @cID = @cLottable02

               -- Column 3: Lottable01 --(cc02)
               SET @cLottable01 = rdt.rdtGetParsedString( @cBarcode, 3, ';')
               IF @cLottable01 = ''
               BEGIN
                  SET @nErrNo = 148753
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Require L07
                  GOTO Quit
               END

               -- Column 4: Lottable03
               SET @cLottable03 = rdt.rdtGetParsedString( @cBarcode, 4, ';')
               IF @cLottable03 = ''
               BEGIN
                  SET @nErrNo = 148754
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Require L03
                  GOTO Quit
               END

               -- Column 5: Qty
               SET @cQTY = rdt.rdtGetParsedString( @cBarcode, 5, ';')

               DECLARE @col1 NVARCHAR( 20)
               DECLARE @col2 NVARCHAR( 20)
               DECLARE @col3 NVARCHAR( 20)
               SET @col1 = LEFT(@cBarcode,20)
               SET @col2 = SUBSTRING(@cBarcode,21,20)
               SET @col3 = RIGHT(@cBarcode,20)


               IF rdt.rdtIsValidQTY( @cQTY, 0) = 0
               BEGIN
                  SET @nErrNo = 148755
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Require QTY
                  GOTO Quit
               END

               --(cc02)
               SELECT @nBeforeRecQty = SUM(BeforeReceivedQty) FROM ReceiptDetail WITH (NOLOCK) WHERE storerKey = @cStorerKey AND receiptKey = @cReceiptKey AND SKU = @cSKU

               IF @nBeforeRecQty > @cQTY
               BEGIN
               	SET @nErrNo = 148759
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Rec
                  GOTO Quit
               END

               IF EXISTS (SELECT 1 FROM RECEIPTDETAIL (NOLOCK)
                          WHERE lottable02= @cLottable02
                           AND ReceiptKey = @cReceiptKey
                           AND Storerkey= @cStorerKey
                           AND @cQTY-Beforereceivedqty=0
                           AND Status<9)
               BEGIN
                  SET @nErrNo = 148756
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID Received
                  GOTO Quit
               END

               -- Get UOM
               DECLARE @cUOM NVARCHAR(10)
               SELECT @cUOM = PackUOM3
               FROM dbo.SKU WITH (NOLOCK)
                  JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU

               -- NOPO flag
               DECLARE @nNOPOFlag INT
               SET @nNOPOFlag = CASE WHEN @cPOkey = 'NOPO' THEN 1 ELSE 0 END

               -- Reason code
               DECLARE @cReasonCode NVARCHAR( 10)
               SET @cReasonCode = 'OK'

               -- Receipt Line Number
               DECLARE @cReceiptLineNumber  NVARCHAR( 5)

            --   -- Receive
               EXEC rdt.rdt_Receive_V7
                  @nFunc         = @nFunc,
                  @nMobile       = @nMobile,
                  @cLangCode     = @cLangCode,
                  @nErrNo        = @nErrNo OUTPUT,
                  @cErrMsg       = @cErrMsg OUTPUT,
                  @cStorerKey    = @cStorerKey,
                  @cFacility     = @cFacility,
                  @cReceiptKey   = @cReceiptKey,
                  @cPOKey        = @cPoKey,
                  @cToLOC        = @cLOC,
                  @cToID         = @cID,
                  @cSKUCode      = @cSKU,
                  @cSKUUOM       = @cUOM,
                  @nSKUQTY       = @cQTY,
                  @cUCC          = '',
                  @cUCCSKU       = '',
                  @nUCCQTY       = '',
                  @cCreateUCC    = '',
                  @cLottable01   = @cLottable01,
                  @cLottable02   = @cLottable02,
                  @cLottable03   = @cLottable03,
                  @dLottable04   = @dLottable04,
                  @dLottable05   = NULL,
                  @cLottable06   = @cLottable06,
                  @cLottable07   = @cLottable07,
                  @cLottable08   = @cLottable08,
                  @cLottable09   = @cLottable09,
                  @cLottable10   = @cLottable10,
                  @cLottable11   = @cLottable11,
                  @cLottable12   = @cLottable12,
                  @dLottable13   = @dLottable13,
                  @dLottable14   = @dLottable14,
                  @dLottable15   = @dLottable15,
                  @nNOPOFlag     = @nNOPOFlag,
                  @cConditionCode = @cReasonCode,
                  @cSubreasonCode = '',
                  @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  GOTO Quit
               END
               ELSE
               BEGIN
               	SET @nErrNo = -1

                  DECLARE @nBal INT,@cQtyReceive INT
                  SELECT @cQtyReceive=ISNULL( SUM(BeforeReceivedQTY),0),@nBal = ISNULL( SUM(QtyExpected), 0)
                  FROM ReceiptDetail WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey

                  SET @cErrMsg = 'QTY:' + CAST(@cQtyReceive AS NVARCHAR(3)) +'/'+CAST(@nBal AS NVARCHAR(3))
               END
            END
         END
      END
   END

Quit:

END

GO