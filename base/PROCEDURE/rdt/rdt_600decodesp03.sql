SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: rdt_600DecodeSP03                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 21-12-2016  Ung       1.0   WMS-783 Created                                */
/* 09-10-2018  Ung       1.1   WMS-6040 Decode diff product group by facility */
/* 11-06-2019  Ung       1.2   WMS-6040 Remove hardcode facility              */
/* 07-08-2019  James     1.3   WMS-10133 Add decode Lottable04 (james01)      */
/* 18-05-2020  Ung       1.4   WMS-13279 Add decode SKUCode                   */
/* 05-05-2023  YeeKung   1.5   WMS-22369 Add output for barcode in decodesp   */
/*                            (yeekung01)                                     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DecodeSP03] (
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
               DECLARE @nRowcount INT
               DECLARE @cFacility NVARCHAR(5)

               -- Check whether need to decode
               IF CHARINDEX( ',', @cBarcode) = 0
                  GOTO Quit

               -- Get session info
               SELECT @cFacility = Facility FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

               -- IF @cFacility = '3101B'
               BEGIN
                  /*
                     Format:
                     Total 9 fields. Delimeter is comma

                     E.g. 1092020009,14003632,20162104V,480,DZ,480,PAC,18852001128516,1103-0000012420

                     Field    Description    Type     MaxLenght   MapTo
                     1	      Orderno		   FIXED	   10
                     2	      CerebosSKU		FIXED	   8	         Lottable06
                     3	      Batchnumber	   VARIABLE	14	         Lottable02, Lottable03 (first 8 char in YYYYMMDD)
                     4	      		         VARIABLE	8
                     5	      		         VARIABLE	3
                     6	      QTY		      VARIABLE	8	         QTY
                     7	      UOM		      VARIABLE	3	         UOM
                     8	      CartonBarcode	VARIABLE	15	         UPC
                     9                       VARIABLE
                  */

                  DECLARE @cTempLottable06 NVARCHAR( 30)
                  DECLARE @cTempLottable02 NVARCHAR( 18)
                  DECLARE @cTempLottable03 NVARCHAR( 18)
                  DECLARE @cTempLottable04 NVARCHAR( 16)
                  DECLARE @cQTY            NVARCHAR( 8)
                  DECLARE @cUOM            NVARCHAR( 3)
                  DECLARE @cRetailSKU      NVARCHAR( 20)
                  DECLARE @cTempSKU        NVARCHAR( 20)
                  DECLARE @cPackKey        NVARCHAR( 10)
                  DECLARE @nPos            INT
                  DECLARE @nRatio          INT
                  DECLARE @cYear           NVARCHAR( 4)
                  DECLARE @cMonth          NVARCHAR( 2)
                  DECLARE @cDay            NVARCHAR( 2)

                  SET @cTempLottable06 = ''
                  SET @cTempLottable02 = ''
                  SET @cTempLottable03 = ''
                  SET @cTempLottable04 = ''
                  SET @cQTY = ''
                  SET @cUOM = ''
                  SET @cRetailSKU = ''
                  SET @cTempSKU = ''
                  SET @nRatio = 0

                  -- Lottable06
                  SET @cTempLottable06 = rdt.rdtGetParsedString( @cBarcode, 2, ',')
                  IF LEN( @cTempLottable06) <> 8
                  BEGIN
                     SET @nErrNo = 105551
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid L06
                     GOTO Quit
                  END

                  -- Lottable02
                  SET @cTempLottable02 = rdt.rdtGetParsedString( @cBarcode, 3, ',')
                  --IF LEN( @cTempLottable02) <> 8 AND LEN( @cTempLottable02) <> 9
                  IF LEN( @cTempLottable02) NOT BETWEEN 8 AND 10
                  BEGIN
                     SET @nErrNo = 105552
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid L02
                     GOTO Quit
                  END

                  -- (james01)
                  -- Lottable04
                  SET @cTempLottable04 = rdt.rdtGetParsedString( @cBarcode, 9, ',')
                  IF LEN( @cTempLottable04) <> 8
                  BEGIN
                     SET @nErrNo = 105559
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid L04
                     GOTO Quit
                  END

                  -- Lottable03
                  SET @cTempLottable03 =
                     SUBSTRING( @cTempLottable02, 7, 2) + -- DD
                     SUBSTRING( @cTempLottable02, 5, 2) + -- MM
                     SUBSTRING( @cTempLottable02, 1, 4)   -- YYYY

                  -- QTY
                  SET @cQTY = rdt.rdtGetParsedString( @cBarcode, 6, ',')
                  IF rdt.rdtIsValidQTY( @cQTY, 0) = 0
                  BEGIN
                     SET @nErrNo = 105553
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
                     GOTO Quit
                  END

                  -- RetailSKU
                  SET @cRetailSKU = rdt.rdtGetParsedString( @cBarcode, 8, ',')
                  IF @cRetailSKU = ''
                  BEGIN
                     SET @nErrNo = 105554
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UPC
                     GOTO Quit
                  END

                  SELECT DISTINCT
                     @cTempSKU = SKU.SKU,
                     @cPackKey = SKU.PackKey
                  FROM ReceiptDetail RD WITH (NOLOCK)
                     JOIN SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
                  WHERE RD.ReceiptKey = @cReceiptKey
                     AND SKU.StorerKey = @cStorerKey
                     AND SKU.RetailSKU = @cRetailSKU
                     AND SKU.ManufacturerSKU = @cTempLottable06

                  SET @nRowCount = @@ROWCOUNT

                  IF @nRowCount = 0
                  BEGIN
                     SET @nErrNo = 105558
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
                     GOTO Quit
                  END

                  -- Multi SKU barcode
                  IF @nRowCount > 1
                     SET @cTempSKU = @cRetailSKU

                  -- UOM
                  SET @cUOM = rdt.rdtGetParsedString( @cBarcode, 7, ',')
                  IF @cUOM = ''
                  BEGIN
                     SET @nErrNo = 105556
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UOM
                     GOTO Quit
                  END

                  -- Convert QTY base on UOM
                  SELECT @nRatio =
                     CASE @cUOM
                        WHEN PackUOM4 THEN Pallet
                        WHEN PackUOM1 THEN CaseCnt
                        WHEN PackUOM2 THEN InnerPack
                        WHEN PackUOM3 THEN QTY
                        ELSE 0
                     END
                  FROM Pack WITH (NOLOCK)
                  WHERE PackKey = @cPackKey
                  IF @nRatio = 0
                  BEGIN
                     SET @nErrNo = 105557
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPackCNT
                     GOTO Quit
                  END

                  -- Return decoded values
                  SET @cLottable01 = 'SL'
                  SET @cLottable06 = @cTempLottable06
                  SET @cLottable02 = @cTempLottable02
                  SET @cLottable03 = @cTempLottable03
                  SET @cSKU = @cTempSKU
                  SET @nQTY = @cQTY * @nRatio

                  SET @cYear = SUBSTRING( @cTempLottable04, 1, 4)
                  SET @cMonth = SUBSTRING( @cTempLottable04, 5, 2)
                  SET @cDay = SUBSTRING( @cTempLottable04, 7, 2)
                  SET @cTempLottable04 = RTRIM( @cDay) + RTRIM( @cMonth) + RTRIM( @cYear)
                  --INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, col2, col3, col4) VALUES
                  --('rdt_600DecodeSP03', GETDATE(), @cTempLottable04, @cYear, @cMonth, @cDay)
                  IF rdt.rdtIsValidDate(@cTempLottable04) = 1 --valid date
                     SET @dLottable04 = rdt.rdtConvertToDate( @cTempLottable04)
               END
            END
         END
      END
   END

Quit:

END

GO