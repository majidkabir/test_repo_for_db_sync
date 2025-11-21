SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP20                                   */
/*                                                                      */
/* Purpose: E-LAND putaway strategy. Use sku style + color to get       */
/*          suggested loc. Find a friend and then any loc               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2016-11-21  1.0  James    WMS631 Created                             */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP20] (
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
      @cSKU               NVARCHAR( 20),
      @cItemClass         NVARCHAR( 10),
      @cStyle             NVARCHAR( 20),
      @cColor             NVARCHAR( 10),
      @cSKUGroup          NVARCHAR( 10)

   SET @cSuggLOC = ''

   /*
   1.	Find Loc Putawayzone = FromLoc.Putawayzone
   2.	Find same sku.itemclass
   3.	Find same sku.skuGroup
   4.	Find same sku.style + sku.Color
   5.	Find Min LOC with minimum total Qty 
   6.	Get top1 LOC order by Putawayzone desc   
   */
   SELECT @cSuggestedPAZone = Putawayzone
   FROM dbo.LOC WITH (NOLOCK) 
   WHERE LOC = @cFromLOC

   SELECT TOP 1 
      @cItemClass = ItemClass,
      @cSKUGroup = SKUGroup,
      @cStyle = Style,
      @cColor = Color
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.SKU = SKU.SKU AND LLI.StorerKey = SKU.StorerKey)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.LOC = @cFromLoc
   AND   LLI.ID = @cID
   AND   LLI.Qty > 0
   ORDER BY LLI.SKU

   SELECT TOP 1 @cSuggLOC = LLI.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.SKU = SKU.SKU AND LLI.StorerKey = SKU.StorerKey)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.LOC <> @cFromLOC
   AND   LOC.Facility = @cFacility   
   AND   LOC.Putawayzone = @cSuggestedPAZone
   AND   SKU.ItemClass = @cItemClass
   AND   SKU.SKUGroup = @cSKUGroup
   AND   ( SKU.Style + SKU.Color) = ( @cStyle + @cColor)
   GROUP BY LLI.LOC
   HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
         (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) > 0
   ORDER BY ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
            (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0),
            LLI.Loc
   
   Quit:
   IF ISNULL( @cSuggLOC, '') = ''
      SET @nErrNo = -1
END

GO