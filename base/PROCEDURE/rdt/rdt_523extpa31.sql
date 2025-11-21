SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtPA31                                      */
/*                                                                      */
/* Purpose: Use RDT config to get suggested loc else return blank loc   */
/*                                                                      */
/* Called from: rdt_PutawayBySKU_GetSuggestLOC                          */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2020-03-09   1.0  James    WMS-12060. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA31] (
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
   
   --should not check the capacity even it is already full 
   --system should putaway to the PickLoc that's their rule
   SELECT TOP 1 @cSuggestedLOC = SL.LOC
   FROM dbo.SKUxLOC SL WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
   AND   SL.SKU = @cSKU
   AND   SL.StorerKey = @cStorerKey
   AND   SL.LocationType = 'PICK'
   ORDER BY SL.LOC

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
   ELSE
   BEGIN
      SET @nErrNo = 150401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Home Loc
      GOTO Quit
   END

   Quit:

END

GO