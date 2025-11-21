SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_600DecodeSP01                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 23-11-2015  Ung       1.0   SOS357362 Created                              */
/* 17-05-2016  Ung       1.1   SOS370261 Add scan SKU code                    */
/* 05-05-2023  YeeKung   1.2   WMS-22369 Add output for barcode in decodesp   */
/*                            (yeekung01)                                     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DecodeSP01] (
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
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               -- SKU
               IF LEN( @cBarcode) <= 12
               BEGIN
                  SELECT TOP 1
                     @cSKU = SKU,
                     @nQTY = CASE WHEN QTYExpected > BeforeReceivedQTY THEN QTYExpected - BeforeReceivedQTY ELSE 0 END,
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
                  FROM ReceiptDetail WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                     AND SKU = @cBarcode
                     AND BeforeReceivedQTY = 0
                  ORDER BY ReceiptLineNumber
               END

               -- SSCC
               IF LEN( @cBarcode) > 12
               BEGIN
                  DECLARE @cSSCC  NVARCHAR( 60)
                  DECLARE @cCode  NVARCHAR( 10)
                  DECLARE @cShort NVARCHAR( 10)
                  DECLARE @cLong  NVARCHAR( 250)
                  DECLARE @cUDF01 NVARCHAR( 60)

                  -- Get SSCC decode rule (SOS 361419)
                  SELECT
                     @cCode = Code,                -- Prefix of barcode
                     @cShort = ISNULL( Short, 0),  -- Lenght of string to take, after the prefix
                     @cLong = ISNULL( Long, ''),   -- String indicate don't need to decode (not used)
                     @cUDF01 = ISNULL( UDF01, '')  -- Prefix of actual string after decode
                  FROM dbo.CodeLKUP WITH (NOLOCK)
                  WHERE ListName = 'SSCCDECODE'
                     AND StorerKey = @cStorerKey

                  -- Check rule valid
                  IF @@ROWCOUNT <> 1
                  BEGIN
                     SET @nErrNo = 96101
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup CodeLKUP
                     GOTO Quit
                  END

                  -- Check valid prefix
                  IF @cCode <> SUBSTRING( @cBarCode, 1, LEN( @cCode))
                  BEGIN
                     SET @nErrNo = 96102
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Prefix
                     GOTO Quit
                  END

                  -- Check valid length
                  IF rdt.rdtIsValidQty( @cShort, 1) = 0
                  BEGIN
                     SET @nErrNo = 96303
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Length
                     GOTO Quit
                  END

                  -- Get actual string
                  SET @cSSCC = SUBSTRING( @cBarcode, LEN( @cCode) + 1, CAST( @cShort AS INT))

                  -- Check valid length
                  IF LEN( @cSSCC) <> @cShort
                  BEGIN
                     SET @nErrNo = 96104
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid length
                     GOTO Quit
                  END

                  -- Check actual string prefix
                  IF @cUDF01 <> SUBSTRING( @cSSCC, 1, LEN( @cUDF01))
                  BEGIN
                     SET @nErrNo = 96105
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid prefix
                     GOTO Quit
                  END

                  -- Check actual string is numeric
                  DECLARE @i INT
                  DECLARE @c NVARCHAR(1)
                  SET @i = 1
                  WHILE @i <= LEN( RTRIM( @cSSCC))
                  BEGIN
                     SET @c = SUBSTRING( @cSSCC, @i, 1)
                     IF NOT (@c >= '0' AND @c <= '9')
                     BEGIN
                        SET @nErrNo = 96106
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SSCC
                        GOTO Quit
                     END
                     SET @i = @i + 1
                  END

                  -- Get SSCC row
                  DECLARE @nRowCount INT
                  SELECT @nRowCount = COUNT( 1)
                  FROM ReceiptDetail WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                     AND Lottable09 = @cSSCC

                  -- Check valid SSCC
                  IF @nRowCount = 0
                  BEGIN
                     SET @nErrNo = 96107
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SSCC
                     GOTO Quit
                  END

                  -- Check SSCC multi row
                  IF @nRowCount > 1
                  BEGIN
                     SET @nErrNo = 96108
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiLine SSCC
                     GOTO Quit
                  END

                  IF @nRowCount = 1
                     SELECT
                        @cSKU = SKU,
                        @nQTY = CASE WHEN QTYExpected > BeforeReceivedQTY THEN QTYExpected - BeforeReceivedQTY ELSE 0 END,
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
                     FROM ReceiptDetail WITH (NOLOCK)
                     WHERE ReceiptKey = @cReceiptKey
                        AND Lottable09 = @cSSCC
               END
            END
         END
      END
   END

Quit:

END

GO