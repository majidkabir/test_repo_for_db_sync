SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_638DecodeSP01                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode SKU (modify from rdt_608DecodeSP01)                        */
/*                                                                            */
/* Called from: rdtfnc_ecomreturn                                             */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 09-07-2020  YeeKung   1.0   WMS12488.Created                               */
/* 22-07-2020  Ung       1.1   WMS-13555 Change params                        */
/* 23-09-2022  YeeKung   1.2   WMS-20820 Extended refno length (yeekung01)    */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_638DecodeSP01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cRefNo       NVARCHAR( 60), --(yeekung01)
   @cLOC         NVARCHAR( 10),
   @cBarcode     NVARCHAR( 60),
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @nUCCQTY      INT            OUTPUT,
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

   DECLARE @cSeason  NVARCHAR( 2)
   DECLARE @cLOT     NVARCHAR( 12)
   DECLARE @cCOO     NVARCHAR( 2)
   DECLARE @cDocType NVARCHAR( 1)
   DECLARE @cTempSKU NVARCHAR( 13)

   SET @cSeason = ''
   SET @cTempSKU = ''
   SET @cLOT = ''
   SET @cCOO = ''

   -- Get 2D barcode
   SET @cSeason = SUBSTRING( @cBarcode, 1, 2)
   SET @cTempSKU = SUBSTRING( @cBarcode, 3, 13)
   SET @cLOT = SUBSTRING( @cBarcode, 16, 12)
   SET @cCOO = SUBSTRING( @cBarcode, 28, 2)

   -- Get Receipt info
   SELECT @cDocType = DocType FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

   -- Check SKU valid
   IF @cTempSKU = ''
   BEGIN
      SET @nErrNo = 154701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU is blank
      GOTO Quit
   END

   -- Check season valid
   IF @cSeason = ''
   BEGIN
      SET @nErrNo = 154702
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Season IsBlank
      GOTO Quit
   END

   -- Check season valid
   IF @cLOT = ''
   BEGIN
      SET @nErrNo = 154703
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT Is Blank
      GOTO Quit
   END

   -- Check COO valid
   IF @cCOO = ''
   BEGIN
      SET @nErrNo = 154704
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --COO Is Blank
      GOTO Quit
   END

   IF NOT EXISTS( SELECT TOP 1 1
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND SKU = @cTempSKU)
   BEGIN
      SET @nErrNo = 154705
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not In ASN
      GOTO Quit
   END

   -- Check season in ASN
   IF NOT EXISTS( SELECT TOP 1 1
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND SKU = @cTempSKU
         AND SUBSTRING( Lottable01, 5, 2) = @cSeason)
   BEGIN
      SET @nErrNo = 154706
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SeasonNotInASN
      GOTO Quit
   END

   -- Check LOT in ASN
   IF NOT EXISTS( SELECT TOP 1 1
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND SKU = @cTempSKU
         AND SUBSTRING( Lottable02, 1, 12) = @cLOT)
   BEGIN
      SET @nErrNo = 154707
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT Not In L02
      GOTO Quit
   END

   -- Check COO in ASN
   IF NOT EXISTS( SELECT TOP 1 1
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND SKU = @cTempSKU
         AND SUBSTRING( Lottable02, 14, 2) = @cCOO)
   BEGIN
      SET @nErrNo = 154708
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --COO Not In L02
      GOTO Quit
   END

   -- Return value
   IF @cTempSKU <> ''
   BEGIN
      SET @cSKU = @cTempSKU
      SET @cLottable01 = SUBSTRING( @cLOT, 1, 6)
      SET @cLottable02 = @cLOT + '-' + @cCOO
      SET @cLottable03 = 'STD'
   END

Quit:

END

GO