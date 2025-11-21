SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_600DecodeSP04                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Normal Receipt V7 decode ToID                                     */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 26-10-2018  James     1.0   WMS-6623 Created                               */
/* 05-05-2023  YeeKung   1.1   WMS-22369 Add output for barcode in decodesp   */
/*                            (yeekung01)                                     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DecodeSP04] (
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

   DECLARE @cBUSR2      NVARCHAR( 30)
   DECLARE @cBUSR5      NVARCHAR( 30)
   DECLARE @cItemClass  NVARCHAR( 10)
   DECLARE @cTempSKU    NVARCHAR( 20)
   DECLARE @cTempLottable06   NVARCHAR( 30)
   DECLARE @nRowCount   INT

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 3 -- ToID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               IF LEN( rtrim( @cBarcode)) < 20
               BEGIN
                  SET @nErrNo = 130854
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Required SSCC
                  GOTO Quit
               END

               SET @cID = SUBSTRING( @cBarcode, 3, 18)
               SET @cLottable06 = @cBarcode
               SET @cSKU = ''
            END
         END
      END

      IF @nStep = 4  -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               IF LEN( rtrim( @cBarcode)) < 22
               BEGIN
                  SET @nErrNo = 130855
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Required SSCC
                  GOTO Quit
               END
            END

            SET @cBUSR5 = SUBSTRING( @cBarcode, 1, 8)
            SET @cBUSR2 = SUBSTRING( @cBarcode, 9, 8)
            --SET @cItemClass = SUBSTRING( @cBarcode, 17, 6)
            SET @cItemClass = SUBSTRING( @cBarcode, 17, 1)
            SET @nQTY = CAST( RIGHT( @cBarcode, 4) AS INT)
            --SET @cLottable02 = @cBUSR5
            SET @cTempLottable06 = @cLottable06

            SELECT @cTempSKU = SKU
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   BUSR2 = @cBUSR2
            AND   BUSR5 = @cBUSR5
            AND   Left( ItemClass, 1) = @cItemClass

            SET @nRowCount = @@ROWCOUNT

            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 130851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not Found
               GOTO Quit
            END

            IF @nRowCount > 1
            BEGIN
               SET @nErrNo = 130852
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --X Mat/Grid/Cat
               GOTO Quit
            END

            SELECT TOP 1 @cLottable02 = Lottable02
            FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND   SKU = @cTempSKU

            IF ISNULL( @cLottable02, '') = ''
            BEGIN
               SET @nErrNo = 130853
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Batch
               GOTO Quit
            END

            -- Assign back the correct variable
            SET @cSKU = @cTempSKU
            SET @nQTY = CAST( RIGHT( @cBarcode, 4) AS INT)
            --SET @cLottable02 = @cBUSR5
            SET @cLottable06 = @cTempLottable06
            --delete from traceinfo where tracename = '600'
            --insert into TraceInfo (TraceName, TimeIn, col1, col2) values ('600', getdate(), @cLottable06, @cTempLottable06)
         END
      END
   END

Quit:

END

GO