SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1723DisableCtn01                                */
/*                                                                      */
/* Purpose: Diable qty field                                            */
/*                                                                      */
/* Called from: rdtfnc_PalletConsolidate_SSCC                           */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2022-03-08   1.0  YeeKung  WMS-18008 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1723DisableCtn01] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cFromID         NVARCHAR( 18),
   @cToID           NVARCHAR( 10),
   @cSKU            NVARCHAR( 20),
   @nQty            INT,
   @cOption         NVARCHAR( 1),
   @cDisableCtnField   NVARCHAR( 1)  OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @cSuggestedSKU  NVARCHAR( 20)

   IF @nFunc = 1723
   BEGIN
      IF @nStep IN(3,5,6)
      BEGIN
         SELECT TOP 1 @cSuggestedSKU = SKU
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)     
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)    
         WHERE LLI.StorerKey = @cStorerKey  
         AND   LLI.ID = @cFromID     
         AND   LOC.Facility = @cFacility    
         AND   LLI.Qty > 0    
         ORDER BY 1    

         IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND sku = @cSuggestedSKU AND LOTTABLE09LABEL <> 'SSCC')
         BEGIN
            SET @cDisableCtnField='1'
         END
         ELSE
         BEGIN
            SET @cDisableCtnField='0'
         END
      END
         
   END

   QUIT:

END

GO