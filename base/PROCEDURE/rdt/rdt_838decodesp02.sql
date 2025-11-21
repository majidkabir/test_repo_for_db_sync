SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DecodeSP02                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode SKU & Default QTY                                    */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2019-08-01  1.0  James       WMS-10030 Created                       */
/* 2023-03-20  1.1  Ung         WMS-21946 Add SerialNo param            */
/* 2024-10-22  1.2  PXL009      FCR-759 ID and UCC Length Issue         */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_838DecodeSP02]
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
            DECLARE @bSuccess INT
            DECLARE @cUPC NVARCHAR( 30)
            DECLARE @cFieldAttr08   NVARCHAR( 1)
            DECLARE @cInField08     NVARCHAR( 60)
            DECLARE @cQTY           NVARCHAR( 5)

            -- If user key in sku
            IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK, INDEX(PKSKU))
                        WHERE StorerKey = @cStorerKey
                        AND   SKU = @cBarcode)
            BEGIN
               SET @cSKU = @cBarcode

               SELECT @cFieldAttr08 = FieldAttr08,
                     @cInField08 = I_Field08
               FROM RDT.RDTMOBREC WITH (NOLOCK)
               WHERE Mobile = @nMobile

               SET @cQTY = CASE WHEN @cFieldAttr08 = 'O' THEN '' ELSE @cInField08 END
               IF RDT.rdtIsValidQTY( @cQTY, 1) = 1
                  SET @nQTY = CAST( @cQty AS INT)
               ELSE
                  SET @nQTY = 1
            END
            ELSE  -- If user key in Altsku
            BEGIN
               SET @cSKU = ''
               SELECT @cSKU = SKU
               FROM dbo.SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU))
               WHERE RetailSku = @cBarcode
               AND   StorerKey = @cStorerKey

               IF ISNULL( @cSKU, '') <> ''
               BEGIN
                  SELECT @nQTY = PACK.InnerPack
                  FROM dbo.PACK PACK WITH (NOLOCK)
                  JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PACK.PackKey = SKU.PACKKey)
                  WHERE SKU.StorerKey = @cStorerKey
                  AND   SKU.Sku = @cSKU
               END
               ELSE
               BEGIN
                  SELECT @cSKU = SKU
                  FROM dbo.SKU WITH (NOLOCK, INDEX(IX_SKU_ManufacturerSku))
                  WHERE ManufacturerSku = @cBarcode
                  AND   StorerKey = @cStorerKey

                  IF ISNULL( @cSKU, '') <> ''
                  BEGIN
                     SELECT @nQTY = PACK.CaseCnt
                     FROM dbo.PACK PACK WITH (NOLOCK)
                     JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PACK.PackKey = SKU.PACKKey)
                     WHERE SKU.StorerKey = @cStorerKey
                     AND   SKU.Sku = @cSKU
                  END
                  ELSE
                  BEGIN
                     SET @cSKU = @cBarcode
                     SET @nQTY = 0
                  END
               END
            END
         END
      END
   END
Quit:

END

GO