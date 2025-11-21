SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_639CustCaseCNT01                                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Show sku packkey                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2023-03-08   Ung       1.0   WMS-21506 Created                             */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_639CustCaseCNT01]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR(3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR(15),
   @cFacility       NVARCHAR(5),
   @cToLOC          NVARCHAR(10),
   @cToID           NVARCHAR(18),
   @cFromLOC        NVARCHAR(10),
   @cFromID         NVARCHAR(18),
   @cSKU            NVARCHAR(20),
   @nQTY            INT,
   @cUCC            NVARCHAR(20),
   @cLottable01     NVARCHAR(18),
   @cLottable02     NVARCHAR(18),
   @cLottable03     NVARCHAR(18),
   @dLottable04     DATETIME,
   @dLottable05     DATETIME,
   @cLottable06     NVARCHAR(18),
   @cLottable07     NVARCHAR(18),
   @cLottable08     NVARCHAR(18),
   @cLottable09     NVARCHAR(18),
   @cLottable10     NVARCHAR(18),
   @cLottable11     NVARCHAR(18),
   @cLottable12     NVARCHAR(18),
   @dLottable13     DATETIME,
   @dLottable14     DATETIME,
   @dLottable15     DATETIME,
   @nCaseCNT        INT          OUTPUT,
   @nErrNo          INT          OUTPUT, 
   @cErrMsg         NVARCHAR(20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 639 -- Move to UCC V7
   BEGIN
      SELECT TOP 1 
         @nCaseCNT = TRY_CONVERT( INT, UDF03) -- Could be Prepack QTY, not master QTY
      FROM dbo.RFPutaway WITH (NOLOCK)
      WHERE FromLOC = @cFromLOC
         AND FromID = @cFromID
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND TRY_CONVERT( INT, UDF03) IS NOT NULL
         
      IF @@ROWCOUNT > 0
      BEGIN
         -- Get SKU info
         DECLARE @cPrePackIndicator NVARCHAR( 20)
         DECLARE @nPackQtyIndicator INT
         SELECT
            @cPrePackIndicator = LEFT( PrePackIndicator, 20),
            @nPackQtyIndicator = ISNULL( PackQtyIndicator, 0)
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            
         -- Prepack SKU
         IF @cPrePackIndicator = '2' AND @nPackQtyIndicator > 1
            SET @nCaseCNT = @nCaseCNT * @nPackQtyIndicator
         
         -- Update it earlier, so ExtendedInfoSP could retrieve it immediately, before parent module write to MobRec. 
         UPDATE rdt.rdtMobRec SET
            EditDate = GETDATE(),
            V_Integer10 = @nCaseCNT
         WHERE Mobile = @nMobile
      END
   END
END

GO