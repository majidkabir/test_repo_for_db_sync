SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580DecodeSP02                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode RFID label                                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-06-01 1.0  yeekung  WMS-22626 Created                                 */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1580DecodeSP02] (
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cStorerKey          NVARCHAR( 15),
   @cReceiptKey         NVARCHAR( 10),
   @cPOKey              NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cBarcode            NVARCHAR( 120),
   @cSKU                NVARCHAR( 20)     OUTPUT,
   @nQTY                INT               OUTPUT,
   @cLottable01         NVARCHAR( 18)     OUTPUT,
   @cLottable02         NVARCHAR( 18)     OUTPUT,
   @cLottable03         NVARCHAR( 18)     OUTPUT,
   @dLottable04         DATETIME          OUTPUT,
   @cSerialNoCapture    NVARCHAR(1) = 0   OUTPUT,
   @nErrNo              INT               OUTPUT,
   @cErrMsg             NVARCHAR( 20)     OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nBarcodeLen INT
   DECLARE @bSuccess    INT
   DECLARE @cTempSKU    NVARCHAR( 20)
   DECLARE @cErrMsg1    NVARCHAR( 125)
   DECLARE @cErrMsg2    NVARCHAR( 125)
   DECLARE @cStatus     NVARCHAR( 10) = ''
   DECLARE @cExternReceiptKey NVARCHAR( 50)
   
   
   SET @cErrMsg1 = ''
   SET @cErrMsg2 = ''

   IF @nStep = 5 -- SKU/QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF LEN(@cBarcode)=24
         BEGIN
            DECLARE @CBinary NVARCHAR(2000)
            DECLARE @cDecimal INT
            DECLARE @cAltSKU  NVARCHAR(60)

            
            IF EXISTS (SELECT 1 
                       FROM receiptSerialNo (NOLOCK)
                       WHERE serialno = @cBarcode
                       AND Storerkey = @cStorerkey)
            BEGIN
               SET @nErrNo = 203101
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --  EPCINMultiASN
               GOTO Quit
            END

            
            IF EXISTS (SELECT 1 
                  FROM serialno (NOLOCK)
                  WHERE serialno = @cBarcode
                     AND Storerkey = @cStorerkey
                     AND Status ='1')
            BEGIN
               SET @nErrNo = 203104
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --  DuplicateSNo
               GOTO Quit
            END

            SET @CBinary = rdt.rdt_ConvertHexToBinary(trim(@cBarcode))

            SET @cAltSKU = rdt.rdt_ConvertBinaryToDec(SUBSTRING(@CBinary,15,24))
            SET @cAltSKU = @cAltSKU +  RIGHT ('0000'+ CAST (rdt.rdt_ConvertBinaryToDec(SUBSTRING(@CBinary,39,20)) AS NVARCHAR(60)),5)

            SELECT @cSKU = sku
            FROM SKU (NOLOCK)
            WHERE Storerkey = @cStorerkey
            and ALTSKU like @cAltSKU + '%'
            AND SerialNoCapture ='1'

            IF ISNULL(@cSKU,'')=''
            BEGIN
               SET @nErrNo = 203102
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --  InvEPC
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
               SET @nErrNo = 203103
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --  EPCINMultiASN
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO