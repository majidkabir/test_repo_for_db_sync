SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_1620DecodeSP03                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: HM India decode IT69 label return SKU, Lottable02                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2020-05-10  James     1.0   WMS-12223 Created                              */
/* 2021-08-03  James     1.1   WMS-17497 Add decode ucc (james01)             */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1620DecodeSP03] (
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

   DECLARE @cLOC        NVARCHAR( 10)
   DECLARE @cActSKU     NVARCHAR( 20)
   DECLARE @cTempLottable02   NVARCHAR( 18)
   DECLARE @cUCC_LOT    NVARCHAR( 10)
   DECLARE @cUCC_SKU    NVARCHAR( 20)
   DECLARE @cUCC_LOC    NVARCHAR( 10)
   DECLARE @cUCC_QTY    INT
   
   IF @nFunc = 1620 -- Cluster Pick 
   BEGIN
      IF @nStep = 8 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               SELECT @cLOC = V_LOC
               FROM rdt.RDTMOBREC WITH (NOLOCK)
               WHERE Mobile = @nMobile

               SET @cActSKU = SUBSTRING( RTRIM( @cBarcode), 3, 13) -- SKU  
               SET @cTempLottable02 = SUBSTRING( RTRIM( @cBarcode), 16, 12) -- Lottable02  
               SET @cTempLottable02 = RTRIM( @cTempLottable02) + '-' -- Lottable02  
               SET @cTempLottable02 = RTRIM( @cTempLottable02) + SUBSTRING( RTRIM( @cBarcode), 28, 2) -- Lottable02  
               
               -- User key in IT69 barcode
               IF EXISTS ( SELECT 1 FROM dbo.LOTATTRIBUTE WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey 
                           AND   SKU = @cActSKU
                           AND   Lottable02 = @cTempLottable02)
               BEGIN
                  IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)   
                                  WHERE StorerKey = @cStorerkey  
                                  AND   OrderKey = @cOrderKey  
                                  AND   SKU = @cActSKU  
                                  AND   LOC = @cLOC
                                  AND   [Status] < '5')  
                  BEGIN
                     SET @nErrNo = 151901
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
                     GOTO Quit
                  END

                  SET @cUPC = @cActSKU
                  SET @cLottable02 = @cTempLottable02
               END
               ELSE
               BEGIN
                  -- (james01)
                  -- Check if user key in ucc
                  SELECT 
                     @cUCC_LOT = LOT, 
                     @cUCC_QTY = ISNULL( SUM( Qty), 0)
                  FROM dbo.UCC WITH (NOLOCK)
                  WHERE Storerkey = @cStorerKey
                  AND   UCCNo = @cBarcode
                  GROUP BY LOT
                  
                  IF @@ROWCOUNT > 0
                  BEGIN
                     SELECT @cTempLottable02 = Lottable02
                     FROM dbo.LOTATTRIBUTE WITH (NOLOCK)
                     WHERE Lot = @cUCC_LOT
                     
                     SET @cUPC = @cActSKU
                     SET @cLottable02 = @cTempLottable02
                     SET @nQTY = @cUCC_QTY
                  END
                  ELSE
                     SET @cUPC = @cBarcode
               END
            END   -- SKU
         END   -- ENTER
      END   -- @nStep = 8
   END

Quit:

END


GO