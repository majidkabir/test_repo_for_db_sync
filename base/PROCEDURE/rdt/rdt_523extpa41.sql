SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtPA41                                      */
/*                                                                      */
/* Purpose: Find pick loc, find friend with same pa zone, find empty loc*/
/*                                                                      */
/* Called from: rdt_PutawayBySKU_GetSuggestLOC                          */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2021-07-30   1.0  James    WMS-17579. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA41] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18), 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),
   @cLOC             NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cLOT             NVARCHAR( 10),
   @cUCC             NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cSuggestedLOC    NVARCHAR( 10) = ''   OUTPUT,
   @nPABookingKey    INT                  OUTPUT,
   @nErrNo           INT                  OUTPUT,
   @cErrMsg          NVARCHAR( 20)        OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @cSuggestedLOC = ''

   --PICKFACE
   SELECT TOP 1
      @cSuggestedLOC = SL.Loc
   FROM dbo.SKUxLOC SL WITH (NOLOCK)
   INNER JOIN dbo.LOC L WITH (NOLOCK) ON ( L.Loc = SL.Loc)
   WHERE SL.StorerKey = @cStorerKey
   AND   SL.Sku = @cSKU
   AND   SL.LocationType IN ( 'PICK', 'CASE' )
   AND   L.Facility = @cFacility
   AND   EXISTS
       (
           SELECT 1
           FROM dbo.CODELKUP FC WITH (NOLOCK)
           INNER JOIN dbo.CODELKUP PC WITH (NOLOCK) 
               ON ( PC.LISTNAME = FC.Short AND PC.Storerkey = FC.Storerkey)
           WHERE FC.LISTNAME = 'LOC2PAZONE'
           AND   FC.Storerkey = @cStorerKey  
           AND   FC.Code = @cLOC          ----Update by Chloe on 2021/8/4
           AND   PC.Code = L.PutawayZone
       )  
   ORDER BY 1

   
   --Same SKU LOC
   IF ISNULL(@cSuggestedLOC, '') = ''
   BEGIN
       SELECT TOP 1 @cSuggestedLOC = LLI.Loc
       FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
       INNER JOIN dbo.LOC L WITH (NOLOCK) ON ( L.Loc = LLI.Loc)
       WHERE LLI.StorerKey = @cStorerKey
       AND   LLI.Sku = @cSKU
       AND   LLI.Qty > 0
       AND   L.Facility = @cFacility
       AND   EXISTS
       (
           SELECT 1
           FROM dbo.CODELKUP FC WITH (NOLOCK)
           INNER JOIN dbo.CODELKUP PC WITH (NOLOCK) 
               ON ( PC.LISTNAME = FC.Short AND PC.Storerkey = FC.Storerkey)
           WHERE FC.LISTNAME = 'LOC2PAZONE'
           AND   FC.Storerkey = @cStorerKey
           AND   FC.Code = @cLOC
           AND   PC.Code = L.PutawayZone
       )
       ORDER BY LLI.Qty,L.LogicalLocation
   END

   ---Empty LOC
   IF ISNULL(@cSuggestedLOC,'') = ''
   BEGIN
       SELECT TOP 1 @cSuggestedLOC = Loc
       FROM dbo.LOC L WITH (NOLOCK)
       WHERE L.Facility = @cFacility
       AND EXISTS
       (
           SELECT 1
           FROM dbo.CODELKUP FC WITH (NOLOCK)
           INNER JOIN dbo.CODELKUP PC WITH (NOLOCK)
               ON ( PC.LISTNAME = FC.Short AND PC.Storerkey = FC.Storerkey)
           WHERE FC.LISTNAME = 'LOC2PAZONE'
           AND   FC.Storerkey = @cStorerKey
           AND   FC.Code = @cLOC
           AND   PC.Code = L.PutawayZone
       ) AND NOT EXISTS
       (        
           SELECT 1
           FROM dbo.SKUXLOC SL WITH (NOLOCK)
           WHERE SL.StorerKey = @cStorerKey
           AND (SL.Qty > 0 OR SL.LocationType IN ( 'PICK', 'CASE' ))
           AND  SL.LOC = L.Loc
       )
       ORDER BY L.LogicalLocation
   END

   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   IF ISNULL( @cSuggestedLOC, '') <> ''
   BEGIN
      SET @nErrNo = 0
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cLOC
         ,@cID
         ,@cSuggestedLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU          = @cSKU
         ,@nPutawayQTY   = @nQTY
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END

   Quit:

END

GO