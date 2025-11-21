SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513DecodeSP02                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Adidas decode label return SKU + Qty                              */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2022-08-23  YeeKung   1.0   WMS-19594 Created                               */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_513DecodeSP02] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 
   @cBarcode     NVARCHAR( 60), 
   @cFromLOC     NVARCHAR( 10)  OUTPUT, 
   @cFromID      NVARCHAR( 18)  OUTPUT, 
   @cSKU         NVARCHAR( 20)  OUTPUT, 
   @nQTY         INT            OUTPUT, 
   @cToLOC       NVARCHAR( 10)  OUTPUT, 
   @cToID        NVARCHAR( 18)  OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nLength     INT,
           @cBUSR1      NVARCHAR( 30), 
           @cStyle      NVARCHAR( 20), 
           @cQty        NVARCHAR( 5), 
           @bSuccess    INT
   
   IF @nFunc = 513 -- Move by SKU
   BEGIN
      IF @nStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               set @cBarcode= trim(@cBarcode)

	                          -- If user key in sku
               IF EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey
                           AND  SKU = @cBarcode)
                       OR EXISTS(SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey
                           AND  ManufacturerSku = @cBarcode)                        
                       OR EXISTS(SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey
                           AND  retailsku = @cBarcode) 
                        OR EXISTS(SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey
                           AND  altsku = @cBarcode) 
               BEGIN
                  SET @cSKU = @cBarcode

                  SET @nQTY=1
               END
               ELSE  -- If user key in Altsku
               BEGIN
                  SET @cSKU = ''
                  SELECT @cSKU = SKU 
                  FROM UPC (NOLOCK)
                  WHERE upc = @cBarcode 
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
         END   -- ENTER
      END   -- @nStep = 3
   END

Quit:

END

GO