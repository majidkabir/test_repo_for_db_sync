SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_608DecodeSP05                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode SKU                                                        */
/*                                                                            */
/* Called from: rdtfnc_PieceReturn                                            */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-06-01  yeekung   1.0  WMS-22630 Created                               */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_608DecodeSP05] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cBarcode     NVARCHAR( 60),
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @nUCCQTY      INT            OUTPUT,
   @cUCCUOM      NVARCHAR( 6)   OUTPUT,
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


   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF LEN(@cBarcode) = 24
         BEGIN
            DECLARE @CBinary NVARCHAR(2000)
            DECLARE @cDecimal BIGINT
            DECLARE @cAltSKU  NVARCHAR(60)

            IF NOT EXISTS ( SELECT 1
                        FROM RECEIPT (NOLOCK)
                        WHERE Receiptkey = @cReceiptKey
                           AND Storerkey = @cStorerKey
                           AND DOCType = 'R')
            BEGIN
               IF EXISTS (SELECT 1 
                     FROM receiptSerialNo (NOLOCK)
                     WHERE serialno = @cBarcode
                        AND Storerkey = @cStorerkey)
               BEGIN
                  SET @nErrNo = 203151
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --  EPCINMultiASN
                  GOTO Quit
               END
            END

            IF EXISTS (SELECT 1 
               FROM receiptSerialNo (NOLOCK)
               WHERE serialno = @cBarcode
                  AND receiptkey = @cReceiptKey
                  AND Storerkey = @cStorerkey)
            BEGIN
               SET @nErrNo = 203155
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --  EPCINMultiASN
               GOTO Quit
            END

            IF EXISTS (SELECT 1 
                  FROM serialno (NOLOCK)
                  WHERE serialno = @cBarcode
                     AND Storerkey = @cStorerkey
                     AND Status ='1')
            BEGIN
               SET @nErrNo = 203154
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --  DuplicateSNo
               GOTO Quit
            END

            SET @CBinary = rdt.rdt_ConvertHexToBinary(trim(@cBarcode))

            SET @cAltSKU = rdt.rdt_ConvertBinaryToDec(SUBSTRING(@CBinary,15,24))
            SET @cAltSKU = @cAltSKU +  RIGHT ('0000'+ CAST (rdt.rdt_ConvertBinaryToDec(SUBSTRING(@CBinary,39,20)) AS NVARCHAR(60)),5)

            SELECT @cSKU = sku
            FROM SKU (NOLOCK)
            WHERE Storerkey = @cStorerkey
            AND ALTSKU like @cAltSKU + '%'
            AND SerialNoCapture ='1'

            IF ISNULL(@cSKU,'')=''
            BEGIN
               SET @nErrNo = 203103
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --  NeedScanEPC
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM SKU (NOLOCK)
                        WHERE (SKU = @cBarcode
                        OR ALTSKU = @cBarcode
                        OR MANUFACTURERSKU = @cBarcode
                        OR RETAILSKU = @cBarcode)
                        AND Storerkey = @cStorerKey
                        AND SerialNoCapture = 1
                        )
            BEGIN
               SET @nErrNo = 203153
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --  NeedScanEPC
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO