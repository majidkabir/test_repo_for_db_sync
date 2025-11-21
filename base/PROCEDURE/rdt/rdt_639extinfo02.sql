SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_639ExtInfo02                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Show sku packkey                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2023-01-25   Ung       1.0   WMS-21506 Created                             */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_639ExtInfo02]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR(3),
   @nStep           INT,
   @nAfterStep      INT,
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
   @tExtInfoVar     VariableTable READONLY,
   @cExtendedInfo   NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 639 -- Move to UCC V7
   BEGIN
      IF @nAfterStep = 6 -- QTY
      BEGIN
         -- IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get session info
            DECLARE @nCaseCNT INT
            SELECT @nCaseCNT = V_Integer10 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

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
               SET @nCaseCNT = @nCaseCNT / @nPackQtyIndicator

            DECLARE @cMsg NVARCHAR( 20)
            SET @cMsg = rdt.rdtgetmessage( 195901, @cLangCode, 'DSP') --FULL UCC: 
            SET @cExtendedInfo = RTRIM( @cMsg) + ' ' + CAST( @nCaseCNT AS NVARCHAR( 5))
         END
      END
   END
END

GO