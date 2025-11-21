SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1628DecodeSP01                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: MAST GLOBAL decode label return SKU + Qty                         */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 20-Oct-2017 James     1.0   WMS3221. Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1628DecodeSP01] (
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

   DECLARE @nLength     INT,
           @cBUSR1      NVARCHAR( 30), 
           @cStyle      NVARCHAR( 20), 
           @cQty        NVARCHAR( 5), 
           @cSKU        NVARCHAR( 20),
           @cUCC_SKU    NVARCHAR( 20),
           @bSuccess    INT,
           @nPD_Qty     INT,
           @nUCC_Qty    INT,
           @nRowRef     INT,
           @nTranCount  INT

   SELECT @cSKU = V_SKU FROM RDT.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile
   
   IF @nStep = 8 -- SKU
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cBarcode <> ''
         BEGIN
	         SELECT @bsuccess = 1
      
            -- Validate SKU/UPC
            EXEC dbo.nspg_GETSKU
               @c_StorerKey= @cStorerKey  OUTPUT
               ,@c_Sku      = @cBarcode    OUTPUT
               ,@b_Success  = @bSuccess    OUTPUT
               ,@n_Err      = @nErrNo      OUTPUT
               ,@c_ErrMsg   = @cErrMsg     OUTPUT

            -- User key in valid SKU/UPC, no need decode anymore
   	      IF @bSuccess = 1
   	      BEGIN
               SET @cUPC = @cBarcode
               GOTO Quit
            END

            -- Check scanned data is valid UCC
            IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND   UCCNo = @cBarcode
                        AND   [Status] = '1')
            BEGIN
               -- Not allow UCC mix sku, return blank
               IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                           AND   UCCNo = @cBarcode 
                           AND   [Status] = '1'
                           GROUP BY UCCNo 
                           HAVING COUNT( DISTINCT SKU) > 1)
               BEGIN
                  SET @cUPC = @cBarcode
                  GOTO Quit
               END

               -- Only UCC with single sku will allow here
               SELECT @cUCC_SKU = SKU, @nUCC_Qty = ISNULL( SUM( QTY), 0)
               FROM dbo.UCC WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   UCCNo = @cBarcode
               AND   [Status] = '1'
               GROUP BY SKU

               SET @cUPC = @cUCC_SKU
               SET @nQty = @nUCC_Qty
            END
            ELSE
            BEGIN
               SET @cUPC = @cBarcode
            END
         END   -- @cBarcode
      END   -- ENTER
   END   -- @nStep = 3

Quit:

END

GO