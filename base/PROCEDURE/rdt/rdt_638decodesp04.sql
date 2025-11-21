SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_638DecodeSP04                                         */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 11-04-2023  Ung       1.0   WMS-22017 base on rdt_638DecodeSP01            */
/*                             Change L03 STD to RET                          */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_638DecodeSP04] (
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

   DECLARE @nRowCount INT
   
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
      SET @nErrNo = 199301
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU is blank
      GOTO Quit
   END

   -- Check season valid
   IF @cSeason = ''
   BEGIN
      SET @nErrNo = 199302
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Season IsBlank
      GOTO Quit
   END

   -- Check season valid
   IF @cLOT = ''
   BEGIN
      SET @nErrNo = 199303
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT Is Blank
      GOTO Quit
   END

   -- Check COO valid
   IF @cCOO = ''
   BEGIN
      SET @nErrNo = 199304
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --COO Is Blank
      GOTO Quit
   END

   DECLARE @cColumnName NVARCHAR( 20)
   SELECT TOP 1 
      @cColumnName = Code
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'REFNOLKUP'
      AND StorerKey = @cStorerKey
      -- AND Code2 = @cFacility

   -- Check SKU Not In ASN
   SET @nRowCount = 0
   IF @cRefNo <> ''
   BEGIN
      IF @cColumnName = 'WarehouseReference'
         SELECT TOP 1
            @nRowCount = 1
         FROM dbo.Receipt R WITH (NOLOCK)
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.StorerKey = @cStorerKey
            AND R.WarehouseReference = @cRefNo
            AND SKU = @cTempSKU

      IF @cColumnName = 'VehicleNumber'
         SELECT TOP 1
            @nRowCount = 1
         FROM dbo.Receipt R WITH (NOLOCK)
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.StorerKey = @cStorerKey
            AND R.VehicleNumber  = @cRefNo
            AND SKU = @cTempSKU
   END
   ELSE
      SELECT TOP 1
         @nRowCount = 1
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND SKU = @cTempSKU
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 199305
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not In ASN
      GOTO Quit
   END

   -- Check season in ASN
   SET @nRowCount = 0
   IF @cRefNo <> ''
   BEGIN
      IF @cColumnName = 'WarehouseReference'
         SELECT TOP 1
            @nRowCount = 1
         FROM dbo.Receipt R WITH (NOLOCK)
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.StorerKey = @cStorerKey
            AND R.WarehouseReference = @cRefNo
            AND RD.SKU = @cTempSKU
            AND SUBSTRING( RD.Lottable01, 5, 2) = @cSeason

      IF @cColumnName = 'VehicleNumber'
         SELECT TOP 1
            @nRowCount = 1
         FROM dbo.Receipt R WITH (NOLOCK)
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.StorerKey = @cStorerKey
            AND R.VehicleNumber = @cRefNo
            AND RD.SKU = @cTempSKU
            AND SUBSTRING( RD.Lottable01, 5, 2) = @cSeason
   END
   ELSE
      SELECT TOP 1
         @nRowCount = 1
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND SKU = @cTempSKU
         AND SUBSTRING( Lottable01, 5, 2) = @cSeason
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 199306
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SeasonNotInASN
      GOTO Quit
   END

   -- Check LOT in ASN
   SET @nRowCount = 0
   IF @cRefNo <> ''
   BEGIN
      IF @cColumnName = 'WarehouseReference'
         SELECT TOP 1
            @nRowCount = 1
         FROM dbo.Receipt R WITH (NOLOCK)
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.StorerKey = @cStorerKey
            AND R.WarehouseReference = @cRefNo
            AND RD.SKU = @cTempSKU
            AND SUBSTRING( RD.Lottable02, 1, 12) = @cLOT

      IF @cColumnName = 'VehicleNumber'
         SELECT TOP 1
            @nRowCount = 1
         FROM dbo.Receipt R WITH (NOLOCK)
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.StorerKey = @cStorerKey
            AND R.VehicleNumber = @cRefNo
            AND RD.SKU = @cTempSKU
            AND SUBSTRING( RD.Lottable02, 1, 12) = @cLOT
   END
   ELSE
      SELECT TOP 1
         @nRowCount = 1
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND SKU = @cTempSKU
         AND SUBSTRING( Lottable02, 1, 12) = @cLOT
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 199307
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT Not In L02
      GOTO Quit
   END

   -- Check COO in ASN
   SET @nRowCount = 0
   IF @cRefNo <> ''
   BEGIN
      IF @cColumnName = 'WarehouseReference'
         SELECT TOP 1
            @nRowCount = 1
         FROM dbo.Receipt R WITH (NOLOCK)
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.StorerKey = @cStorerKey
            AND R.WarehouseReference = @cRefNo
            AND RD.SKU = @cTempSKU
            AND SUBSTRING( RD.Lottable02, 14, 2) = @cCOO

      IF @cColumnName = 'VehicleNumber'
         SELECT TOP 1
            @nRowCount = 1
         FROM dbo.Receipt R WITH (NOLOCK)
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.StorerKey = @cStorerKey
            AND R.VehicleNumber = @cRefNo
            AND RD.SKU = @cTempSKU
            AND SUBSTRING( RD.Lottable02, 14, 2) = @cCOO
   END
   ELSE
      SELECT TOP 1
         @nRowCount = 1
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND SKU = @cTempSKU
         AND SUBSTRING( Lottable02, 14, 2) = @cCOO
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 199308
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --COO Not In L02
      GOTO Quit
   END

   -- Return value
   IF @cTempSKU <> ''
   BEGIN
      SET @cSKU = @cTempSKU
      SET @cLottable01 = SUBSTRING( @cLOT, 1, 6)
      SET @cLottable02 = @cLOT + '-' + @cCOO
      SET @cLottable03 = 'RET'
   END

Quit:

END

GO