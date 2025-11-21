SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513SuggestLOC13                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Find friend, find empty then find dedicated loc             */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2021-02-01  1.0  James       WMS-15655. Created                      */
/* 2021-07-26  1.1  James       Limit search loc to putawayzone setup   */
/*                              in codelkup (james01)                   */
/************************************************************************/

CREATE PROC [RDT].[rdt_513SuggestLOC13] (
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
   DECLARE @cLottable03       NVARCHAR( 18) = ''
   DECLARE @cStyle            NVARCHAR( 10) = ''
   DECLARE @cPAZone           NVARCHAR( 10) = ''
   
   IF @cType = 'LOCK'
   BEGIN
      SELECT TOP 1 @cLottable03 = LA.Lottable03
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
      WHERE LLI.Loc = @cFromLoc
      AND   (( ISNULL( @cFromID, '') = '') OR ( LLI.Id = @cFromID))
      AND   LLI.Sku = @cSKU  
      AND   LLI.Storerkey = @cStorerkey    
      ORDER BY 1
      
      -- Find friend
      SELECT TOP 1 @cSuggestedLoc = LOC.LOC
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
      WHERE LLI.Storerkey = @cStorerkey 
      AND   LLI.SKU = @cSKU 
      AND ( LLI.Qty - LLI.QtyPicked) > 0 
      AND   LOC.Facility  = @cFacility  
      AND   LOC.LocationType IN ( 'PICK', 'DYNPPICK')
      AND   LOC.LocationFlag <> 'HOLD'
      AND   LOC.LOC <> @cFromLoc
      AND   LA.Lottable03 = @cLottable03
      AND   EXISTS ( SELECT 1 FROM dbo.CODELKUP CL WITH (NOLOCK) 
                     WHERE CL.LISTNAME = 'LULUPAZONE' 
                     AND   CL.Storerkey = @cStorerkey 
                     AND   LOC.PutawayZone = CL.Code)
      ORDER BY LOC.PALogicalLoc, LOC.LogicalLocation, LOC.LOC

      -- Find empty
      IF ISNULL( @cSuggestedLoc, '') =  ''
      BEGIN
         SELECT @cStyle = Style
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerkey
         AND   Sku = @cSKU
         
         SET @cStyle = SUBSTRING( @cStyle, 1, 2)

         DECLARE @cCurPAZone  CURSOR
         SET @cCurPAZone = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT Code
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'LULUPAZONE'
         AND   Storerkey = @cStorerkey
         AND   Short = @cStyle
         ORDER BY 1
         OPEN @cCurPAZone
         FETCH NEXT FROM @cCurPAZone INTO @cPAZone
         WHILE @@FETCH_STATUS = 0
         BEGIN
            --IF SUSER_SNAME() = 'jameswong'
            --SELECT @cSKU '@cSKU', @cStyle '@cStyle', @cPAZone '@cPAZone'
            SELECT TOP 1 @cSuggestedLOC = LOC.LOC
            FROM dbo.LOC WITH (NOLOCK)
            LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            WHERE LOC.Facility = @cFacility
            AND   LOC.LocationType IN ( 'PICK', 'DYNPPICK')
            AND   LOC.LocationFlag <> 'HOLD'
            AND   LOC.LOC <> @cFromLoc
            AND   LOC.PutawayZone = @cPAZone
            GROUP BY LOC.PALogicalLoc, LOC.LogicalLocation, LOC.LOC
            HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
               AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
            ORDER BY LOC.PALogicalLoc, LOC.LogicalLocation, LOC.LOC
            
            IF ISNULL( @cSuggestedLoc, '') <> ''
               BREAK

            FETCH NEXT FROM @cCurPAZone INTO @cPAZone
         END
      END
            
      IF ISNULL( @cSuggestedLoc, '') =  ''
         SET @cSuggestedLoc = 'LULUQC'

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