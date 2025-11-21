SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513SuggestLOC18                                 */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2023-04-03 1.0  Ung     WMS-22104 base on rdt_523ExtInfo08           */
/************************************************************************/

CREATE   PROC [RDT].[rdt_513SuggestLOC18]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerkey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cFromLOC      NVARCHAR( 10),
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
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @cType = 'LOCK'
   BEGIN
      -- Blank the output
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''

      DECLARE @i              INT = 1
      DECLARE @cSuggLOC       NCHAR( 10) = ''
      DECLARE @cPutawayZone   NVARCHAR( 10)
      DECLARE @nQTYAvail      INT
      
      -- Get SKU info
      SELECT @cPutawayZone = ISNULL( PutawayZone, '') 
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU

      -- Find up to 5 friends (SKU)
      DECLARE @curFriend CURSOR
      SET @curFriend = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT TOP 5
             LOC.LOC, SUM(LLI.QTY - LLI.QTYAllocated - LLI.QtyPicked)
         FROM dbo.LOC LOC WITH (NOLOCK)
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
            AND LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND LOC.LocationType = 'DYNPPICK'
            AND LOC.PutawayZone = @cPutawayZone
            AND (LLI.QTY - LLI.QTYAllocated - LLI.QtyPicked) > 0
            AND LOC.LOC <> @cFromLOC   -- exclude from loc
         GROUP BY LOC.LOC
         ORDER BY LOC.LOC
      OPEN @curFriend
      FETCH NEXT FROM @curFriend INTO @cSuggLOC, @nQTYAvail
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @i = 1 SET @cOutField02 = @cSuggLOC + ': ' + CAST( @nQTYAvail AS NVARCHAR( 5)) ELSE
         IF @i = 2 SET @cOutField03 = @cSuggLOC + ': ' + CAST( @nQTYAvail AS NVARCHAR( 5)) ELSE
         IF @i = 3 SET @cOutField04 = @cSuggLOC + ': ' + CAST( @nQTYAvail AS NVARCHAR( 5)) ELSE
         IF @i = 4 SET @cOutField05 = @cSuggLOC + ': ' + CAST( @nQTYAvail AS NVARCHAR( 5)) ELSE
         IF @i = 5 SET @cOutField06 = @cSuggLOC + ': ' + CAST( @nQTYAvail AS NVARCHAR( 5)) 

         SET @i = @i + 1
         FETCH NEXT FROM @curFriend INTO @cSuggLOC, @nQTYAvail
      END

      -- Header
      IF @cSuggLOC = ''
         SET @cOutField01 = rdt.rdtgetmessage( 199101, @cLangCode, 'DSP') --NEW LOCATION:
      ELSE
         SET @cOutField01 = rdt.rdtgetmessage( 199102, @cLangCode, 'DSP') --SUGGESTED LOCATION:

      -- Find empty LOC
      IF @cSuggLOC = ''
         SELECT TOP 1
             @cOutField02 = LOC.LOC
         FROM dbo.LOC LOC WITH (NOLOCK)
            LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
            AND LOC.LocationType = 'DYNPPICK'
            AND LOC.PutawayZone = @cPutawayZone
            AND LOC.LOC <> @cFromLOC   -- exclude from loc
         GROUP BY LOC.LOC
         HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QtyPicked, 0)) = 0
            AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
         ORDER BY LOC.LOC
   END
END

GO