SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1620DecodeSP02                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Fanatics B2B decode label return SKU + Qty                        */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2019-07-01  James     1.0   WMS-9071 Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1620DecodeSP02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15), 
   @cBarcode       NVARCHAR( 60),
   @cWaveKey       NVARCHAR( 10), 
   @cLoadKey       NVARCHAR( 10), 
   @cOrderKey      NVARCHAR( 10), 
   @cPutawayZone   NVARCHAR( 10), 
   @cPickZone      NVARCHAR( 10), 
   @cDropID        NVARCHAR( 20)  OUTPUT, 
   @cUPC           NVARCHAR( 20)  OUTPUT, 
   @nQTY           INT            OUTPUT, 
   @cLottable01    NVARCHAR( 18)  OUTPUT, 
   @cLottable02    NVARCHAR( 18)  OUTPUT, 
   @cLottable03    NVARCHAR( 18)  OUTPUT, 
   @dLottable04    DATETIME       OUTPUT, 
   @dLottable05    DATETIME       OUTPUT, 
   @cLottable06    NVARCHAR( 30)  OUTPUT, 
   @cLottable07    NVARCHAR( 30)  OUTPUT, 
   @cLottable08    NVARCHAR( 30)  OUTPUT, 
   @cLottable09    NVARCHAR( 30)  OUTPUT, 
   @cLottable10    NVARCHAR( 30)  OUTPUT, 
   @cLottable11    NVARCHAR( 30)  OUTPUT, 
   @cLottable12    NVARCHAR( 30)  OUTPUT, 
   @dLottable13    DATETIME       OUTPUT, 
   @dLottable14    DATETIME       OUTPUT, 
   @dLottable15    DATETIME       OUTPUT, 
   @cUserDefine01  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine02  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine03  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine04  NVARCHAR( 60)  OUTPUT, 
   @cUserDefine05  NVARCHAR( 60)  OUTPUT, 
   @nErrNo         INT            OUTPUT, 
   @cErrMsg        NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cActSKU   NVARCHAR( 20), 
           @cDefaultQty   NVARCHAR( 5),
           @bSuccess  INT,
           @nSKUCnt   INT
   
   IF @nFunc = 1620 -- Cluster Pick 
   BEGIN
      IF @nStep = 8 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
	            SET @bsuccess = 1
               SET @cActSKU = @cBarcode

               EXEC [RDT].[rdt_GETSKUCNT]
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cActSKU
               ,@nSKUCnt     = @nSKUCnt      OUTPUT
               ,@bSuccess    = @bSuccess     OUTPUT
               ,@nErr        = @nErrNo       OUTPUT
               ,@cErrMsg     = @cErrMsg      OUTPUT

               -- Validate SKU/UPC
               IF @nSKUCnt = 0
                  GOTO Quit

               -- Validate barcode return multiple SKU
               IF @nSKUCnt > 1
                  GOTO Quit

               EXEC [RDT].[rdt_GETSKU]
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cActSKU      OUTPUT
               ,@bSuccess    = @bSuccess     OUTPUT
               ,@nErr        = @nErrNo       OUTPUT
               ,@cErrMsg     = @cErrMsg      OUTPUT

               IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                           AND   SKU = @cActSKU
                           AND   PickCode = 'M')
                  SET @nQTY = 0
               ELSE
               BEGIN
                  SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'DefaultQty', @cStorerKey)
                  IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 0
                     SET @nQty = 0
                  ELSE
                     SET @nQty = CAST( @cDefaultQty AS INT)
               END

               SET @cUPC = @cActSKU
            END   -- @cBarcode
         END   -- ENTER
      END   -- @nStep = 3
   END

Quit:

END

GO