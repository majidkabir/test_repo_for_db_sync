SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513SuggestLOC03                                 */
/*                                                                      */
/* Purpose: E-LAND get suggested loc strategy. Use sku style + color    */
/*          to get suggested loc. Find a friend and then any loc        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2016-11-21  1.0  James    WMS631 Created                             */
/* 2017-03-15  1.1  James    WMS1347-Enhancement (james01)              */
/* 2017-07-10  1.2  James    WMS2370-Enhancement (james02)              */
/************************************************************************/

CREATE PROC [RDT].[rdt_513SuggestLOC03] (
   @nMobile         INT,                    
   @nFunc           INT,                    
   @cLangCode       NVARCHAR( 3),           
   @cStorerKey      NVARCHAR( 15),          
   @cFacility       NVARCHAR(  5),          
   @cFromLOC        NVARCHAR( 10),          
   @cFromID         NVARCHAR( 18),          
   @cSKU            NVARCHAR( 20),          
   @nQTY            INT,                    
   @cToID           NVARCHAR( 18),          
   @cToLOC          NVARCHAR( 10),          
   @cType           NVARCHAR( 10),          
   @nPABookingKey   INT           OUTPUT,    
   @cOutField01     NVARCHAR( 20) OUTPUT,   
   @cOutField02     NVARCHAR( 20) OUTPUT,   
   @cOutField03     NVARCHAR( 20) OUTPUT,   
   @cOutField04     NVARCHAR( 20) OUTPUT,   
   @cOutField05     NVARCHAR( 20) OUTPUT,   
   @cOutField06     NVARCHAR( 20) OUTPUT,   
   @cOutField07     NVARCHAR( 20) OUTPUT,   
   @cOutField08     NVARCHAR( 20) OUTPUT,   
   @cOutField09     NVARCHAR( 20) OUTPUT,   
   @cOutField10     NVARCHAR( 20) OUTPUT,   
   @cOutField11     NVARCHAR( 20) OUTPUT,   
   @cOutField12     NVARCHAR( 20) OUTPUT,   
   @cOutField13     NVARCHAR( 20) OUTPUT,   
   @cOutField14     NVARCHAR( 20) OUTPUT,   
   @cOutField15     NVARCHAR( 20) OUTPUT,   
   @nErrNo          INT           OUTPUT,   
   @cErrMsg         NVARCHAR( 20) OUTPUT    
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE 
      @cSuggestArticle    NVARCHAR( 30),
      @cSuggestedPAZone   NVARCHAR( 10),
      @cSuggLOC           NVARCHAR( 10) 

   SET @cSuggLOC = ''
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''
   SET @cOutField07 = ''
   SET @cOutField08 = ''
   SET @cOutField09 = ''
   SET @cOutField10 = ''
   SET @cOutField11 = ''
   SET @cOutField12 = ''
   SET @cOutField13 = ''
   SET @cOutField14 = ''
   SET @cOutField15 = ''

   SELECT TOP 1 @cSuggestArticle = ISNULL( LTRIM(RTRIM( SKU.Style)) + 
                                           LTRIM(RTRIM( SKU.Color)), '')
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.SKU SKU WITH (NOLOCK) ON 
      ( LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = @cStorerKey
   AND   ( @cFromID = '' OR LLI.ID = @cFromID)
   AND   LLI.LOC = @cFromLOC
   AND   LLI.SKU = @cSKU
   AND   LOC.Facility = @cFacility      

   SELECT TOP 1 @cSuggestedPAZone = Code
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'BUSR7'
   AND   UDF02 = @cFromID
   AND   Storerkey = @cStorerKey

   IF ISNULL( @cSuggestedPAZone, '') = ''
      SELECT @cSuggestedPAZone = BUSR7
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

   IF ISNULL( @cSuggestedPAZone, '') = ''
   BEGIN
      SET @nErrNo = 112351
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PAZone
      GOTO Quit
   END

   -- Search suggested loc within the same sku (find a friend) with min qty (not empty)
   SELECT TOP 1 @cSuggLOC = LLI.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.Sku = @cSKU
   AND   LOC.Facility = @cFacility   
   AND   LOC.Putawayzone = @cSuggestedPAZone
   AND   LLI.LOC <> @cFromLOC
   GROUP BY LLI.LOC
   HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
         (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) > 0
   ORDER BY ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
            (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0),
            LLI.Loc

   -- No loc found, find a loc with same sku style+color. Take the non empty loc with min qty 
   IF ISNULL( @cSuggLOC, '') = ''
      SELECT TOP 1 @cSuggLOC = LLI.LOC
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON 
         ( LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LOC.Facility = @cFacility   
      And   LOC.Putawayzone = @cSuggestedPAZone
      AND   ISNULL( LTRIM(RTRIM( SKU.Style)) + 
            LTRIM(RTRIM( SKU.Color)), '') = @cSuggestArticle
      AND   LLI.LOC <> @cFromLOC
      GROUP BY LLI.LOC,SKU.STYLE+SKU.COLOR
      HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
               (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) > 0
      ORDER BY ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
               (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0),
               LLI.Loc

   Quit:
   IF ISNULL( @cSuggLOC, '') = ''
   BEGIN
      SET @cOutField01 = 'NO SUGGESTED LOC'
      SET @cOutField02 = ''
   END
   ELSE
   BEGIN
      SET @cOutField01 = 'SUGGESTED LOC:'
      SET @cOutField02 = ISNULL( @cSuggLOC, '')
   END
END

GO