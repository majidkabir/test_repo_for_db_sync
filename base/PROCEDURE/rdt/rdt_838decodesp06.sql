SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DecodeSP06                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode SKU                                                  */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2022-02-21  1.0  Ung         WMS-18939 Created                       */
/* 2023-03-20  1.1  Ung         WMS-21946 Add SerialNo param            */
/* 2023-04-13  1.2  Ung         WMS-22287 Add 2D barcode                */
/* 2024-10-25  1.3  PXL009      FCR-759 ID and UCC Length Issue         */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_838DecodeSP06]
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cFacility           NVARCHAR( 5),
   @cStorerKey          NVARCHAR( 15),
   @cPickSlipNo         NVARCHAR( 10),
   @cFromDropID         NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),
   @cBarcode2           NVARCHAR( 60),
   @cSKU                NVARCHAR( 20)  OUTPUT,
   @nQTY                INT            OUTPUT,
   @cPackDtlRefNo       NVARCHAR( 20)  OUTPUT,
   @cPackDtlRefNo2      NVARCHAR( 20)  OUTPUT,
   @cPackDtlUPC         NVARCHAR( 30)  OUTPUT,
   @cPackDtlDropID      NVARCHAR( 20)  OUTPUT,
   @cSerialNo           NVARCHAR( 30)  OUTPUT,
   @cFromDropIDDecode   NVARCHAR( 20)  OUTPUT,
   @cToDropIDDecode     NVARCHAR( 20)  OUTPUT,
   @cUCCNo              NVARCHAR( 20)  OUTPUT,
   @nErrNo              INT            OUTPUT,
   @cErrMsg             NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 838
   BEGIN
      IF @nStep = 3  -- SKU QTY
      BEGIN
         IF @nInputKey = 1
         BEGIN

            DECLARE @nPosition INT
            DECLARE @cUPC      NVARCHAR( 30)
            DECLARE @cBUSR5    NVARCHAR( 30)

            /*
            -- 2D barcode
            6925350518422|A2915022|20260314|GZ|00398776
               6925350518422 = UPC
               A2915022 = BatchNo
               20260314 = ExpiryDate
            */
            SET @nPosition = CHARINDEX( '|', @cBarcode)
            IF @nPosition > 0
               SET @cUPC = LEFT( @cBarcode, @nPosition - 1)
            ELSE
               -- 1D barcode
               SET @cUPC = LEFT( @cBarcode, 30)
            
            -- Get UPC, for saving into PackDetail.UPC
            SELECT 
               @cSKU = SKU, 
               @cPackDtlUPC = UPC
            FROM dbo.UPC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND UPC = @cUPC

            IF @@ROWCOUNT <> 1
            BEGIN
               SET @cSKU = ''
               SET @cPackDtlUPC = ''
            END
            
            -- Get SKU info
            SELECT @cBUSR5 = ISNULL( BUSR5, '')
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
            
            -- Check SKU that need to scan QRCode, but scanned UPC
            IF @cBUSR5 = '1' AND @nPosition = 0
            BEGIN
               SET @nErrNo = 199651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Scan QRCode
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END
   END
   
Quit:

END

GO