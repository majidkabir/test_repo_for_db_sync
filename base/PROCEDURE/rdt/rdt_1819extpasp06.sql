SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP06                                   */
/*                                                                      */
/* Purpose: E-LAND putaway strategy. Use sku style + color to get       */
/*          suggested loc. Find a friend and then any loc               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2016-11-21  1.0  James    WMS631 Created                             */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP06] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10)  OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT,
   @nPABookingKey    INT            OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE 
      @cSuggestArticle    NVARCHAR( 30),
      @cSuggestedPAZone   NVARCHAR( 10),
      @cSKU               NVARCHAR( 20)

   SET @cSuggLOC = ''

   -- Check if pallet contain only 1 style+color
   IF (
      SELECT COUNT( 1) FROM (
         SELECT ISNULL( RTRIM( SKU.Style), '') + ISNULL( RTRIM( SKU.Color), '') AS a
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.SKU SKU WITH (NOLOCK) ON 
            ( LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey
         AND   LLI.ID = @cID
         AND   LLI.LOC = @cFromLOC
         AND   LOC.Facility = @cFacility
         GROUP BY ISNULL( RTRIM( SKU.Style), '') + ISNULL( RTRIM( SKU.Color), '')
         HAVING ISNULL( SUM( LLI.Qty - LLI.QtyPicked), 0) > 0 
         ) AS T ) > 1
         -- > 1 Style + Color
         GOTO Quit   
   ELSE
   BEGIN
      -- pallet only 1 style + color
      SELECT TOP 1 
             @cSuggestArticle = ISNULL( LTRIM(RTRIM( SKU.Style)) + 
                                         LTRIM(RTRIM( SKU.Color)), ''),
             @cSKU = LLI.SKU
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON 
         ( LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.ID = @cID
      AND   LLI.LOC = @cFromLOC
      AND   LOC.Facility = @cFacility      

      SELECT TOP 1 @cSuggLOC = LOC.LOC
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON 
         ( LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LOC.Facility = @cFacility   
      AND   ISNULL( LTRIM(RTRIM( SKU.Style)) + 
            LTRIM(RTRIM( SKU.Color)), '') = @cSuggestArticle
      AND   LOC.LOC <> @cFromLOC
      GROUP BY LOC.LOC
      HAVING ISNULL(SUM(LLI.Qty - LLI.QtyPicked), 0) > 0 
      ORDER BY ISNULL(SUM(LLI.Qty - LLI.QtyPicked), 0), LOC.LOC
      
      IF ISNULL( @cSuggLOC, '') = ''
      BEGIN
         SELECT TOP 1 @cSuggestedPAZone = CKL.UDF01
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON 
            ( LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         JOIN dbo.CODELKUP CKL ON (CKL.Code = SKU.BUSR7)
         WHERE LLI.StorerKey = @cStorerKey
         AND   LLI.SKU = @cSKU
         AND   LOC.Facility = @cFacility   
         AND   ISNULL( LTRIM(RTRIM( SKU.Style)) + 
               LTRIM(RTRIM( SKU.Color)), '') = @cSuggestArticle
         AND   CKL.Listname = 'BUSR7'
         AND   CKL.StorerKey = @cStorerKey
         ORDER BY CKL.UDF01

         SELECT TOP 1 @cSuggLOC = LOC
         FROM dbo.LOC WITH (NOLOCK) 
         WHERE Facility = @cFacility   
         AND   LOC <> @cFromLOC
         And   PutAwayZone = @cSuggestedPAZone
         ORDER BY LOC 
      END
   END
   
   Quit:
   IF ISNULL( @cSuggLOC, '') = ''
      SET @nErrNo = -1
END

GO