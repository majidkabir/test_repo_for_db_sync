SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513SuggestLOC14                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Find friend, find same style then find 1st loc of same fac  */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2021-09-14  1.0  James       WMS-17911. Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_513SuggestLOC14] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerkey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cFromLoc      NVARCHAR( 10),
   @cFromID       NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cToID         NVARCHAR( 18),
   @cToLOC        NVARCHAR( 10),
   @cType         NVARCHAR( 10), -- LOCK/UNLOCK
   @nPABookingKey INT           OUTPUT,
	@cOutField01   NVARCHAR( 20) OUTPUT,
	@cOutField02   NVARCHAR( 20) OUTPUT,
   @cOutField03   NVARCHAR( 20) OUTPUT,
   @cOutField04   NVARCHAR( 20) OUTPUT,
   @cOutField05   NVARCHAR( 20) OUTPUT,
   @cOutField06   NVARCHAR( 20) OUTPUT,
   @cOutField07   NVARCHAR( 20) OUTPUT,
   @cOutField08   NVARCHAR( 20) OUTPUT,
   @cOutField09   NVARCHAR( 20) OUTPUT,
   @cOutField10   NVARCHAR( 20) OUTPUT,
	@cOutField11   NVARCHAR( 20) OUTPUT,
	@cOutField12   NVARCHAR( 20) OUTPUT,
   @cOutField13   NVARCHAR( 20) OUTPUT,
   @cOutField14   NVARCHAR( 20) OUTPUT,
   @cOutField15   NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSuggestedLoc     NVARCHAR( 10) = ''
   DECLARE @cStyle            NVARCHAR( 20) = ''
   
   IF @cType = 'LOCK'
   BEGIN         
      -- Find friend
      SELECT TOP 1 @cSuggestedLoc = LOC.LOC
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.Storerkey = @cStorerkey 
      AND   LLI.SKU = @cSKU 
      AND ( LLI.Qty - LLI.QtyPicked) > 0 
      AND   LOC.Facility  = @cFacility  
      AND   LOC.LocationType IN ( 'PICK', 'DYNPPICK')
      AND   LOC.LocationFlag <> 'HOLD'
      AND   LOC.LOC <> @cFromLoc
      ORDER BY LOC.PALogicalLoc, LOC.LogicalLocation, LOC.LOC

      -- Find friend with same style
      IF ISNULL( @cSuggestedLoc, '') =  ''
      BEGIN
         SELECT @cStyle = Style
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerkey
         AND   Sku = @cSKU

         SELECT TOP 1 @cSuggestedLoc = LOC.LOC
         FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.Sku)
         WHERE LLI.Storerkey = @cStorerkey 
         AND ( LLI.Qty - LLI.QtyPicked) > 0 
         AND   LOC.Facility  = @cFacility  
         AND   LOC.LocationType IN ( 'PICK', 'DYNPPICK')
         AND   LOC.LocationFlag <> 'HOLD'
         AND   LOC.LOC <> @cFromLoc
         AND   SKU.Style = @cStyle
         ORDER BY LOC.PALogicalLoc, LOC.LogicalLocation, LOC.LOC
      END
      
      -- Find 1st loc from same facility (empty loc)
      IF ISNULL( @cSuggestedLoc, '') =  ''
      BEGIN
         SELECT TOP 1 @cSuggestedLoc = LOC.LOC
         FROM dbo.LOC LOC WITH (NOLOCK) 
         LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility   
         AND   LOC.LocationFlag <> 'HOLD'
         AND   LOC.LocationType IN ( 'PICK', 'DYNPPICK')
         GROUP BY LOC.PALogicalLoc, LOC.LogicalLocation, LOC.LOC      
         -- Empty LOC
         HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked + LLI.PendingMoveIn), 0) = 0
         ORDER BY LOC.PALogicalLoc, LOC.LogicalLocation, LOC.LOC         
      END

      -- Output ExtendedField02
      SET @cOutField01 = @cSuggestedLoc
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
   END

Quit:

END

GO