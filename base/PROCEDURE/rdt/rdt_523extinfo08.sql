SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtInfo08                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2023-03-21 1.0  Ung     WMS-22032 Created                            */
/************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtInfo08]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nAfterStep      INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cLOC            NVARCHAR( 10),
   @cID             NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cSuggestedLOC   NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @cOption         NVARCHAR( 1),
   @cExtendedInfo1  NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
      IF @nStep = 3 AND  -- QTY
         @nAfterStep = 4 -- Suggested LOC
      BEGIN
         DECLARE @i              INT = 1
         DECLARE @cMsg1          NVARCHAR( 20) = ''
         DECLARE @cMsg2          NVARCHAR( 20) = ''
         DECLARE @cMsg3          NVARCHAR( 20) = ''
         DECLARE @cMsg4          NVARCHAR( 20) = ''
         DECLARE @cMsg5          NVARCHAR( 20) = ''
         DECLARE @cMsg6          NVARCHAR( 20) = ''
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
               AND LOC.LOC <> @cLOC   -- exclude from loc
            GROUP BY LOC.LOC
            ORDER BY LOC.LOC
         OPEN @curFriend
         FETCH NEXT FROM @curFriend INTO @cSuggLOC, @nQTYAvail
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @i = 1 SET @cMsg2 = @cSuggLOC + ': ' + CAST( @nQTYAvail AS NVARCHAR( 5)) ELSE
            IF @i = 2 SET @cMsg3 = @cSuggLOC + ': ' + CAST( @nQTYAvail AS NVARCHAR( 5)) ELSE
            IF @i = 3 SET @cMsg4 = @cSuggLOC + ': ' + CAST( @nQTYAvail AS NVARCHAR( 5)) ELSE
            IF @i = 4 SET @cMsg5 = @cSuggLOC + ': ' + CAST( @nQTYAvail AS NVARCHAR( 5)) ELSE
            IF @i = 5 SET @cMsg6 = @cSuggLOC + ': ' + CAST( @nQTYAvail AS NVARCHAR( 5)) 

            SET @i = @i + 1
            FETCH NEXT FROM @curFriend INTO @cSuggLOC, @nQTYAvail
         END

         -- Header
         IF @cSuggLOC = ''
            SET @cMsg1 = rdt.rdtgetmessage( 197901, @cLangCode, 'DSP') --NEW LOCATION:
         ELSE
            SET @cMsg1 = rdt.rdtgetmessage( 197902, @cLangCode, 'DSP') --SUGGESTED LOCATION:

         -- Find empty LOC
         IF @cSuggLOC = ''
            SELECT TOP 1
                @cMsg2 = LOC.LOC
            FROM dbo.LOC LOC WITH (NOLOCK)
               LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            WHERE LOC.Facility = @cFacility
               AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
               AND LOC.LocationType = 'DYNPPICK'
               AND LOC.PutawayZone = @cPutawayZone
               AND LOC.LOC <> @cLOC   -- exclude from loc
            GROUP BY LOC.LOC
            HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QtyPicked, 0)) = 0
               AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
            ORDER BY LOC.LOC

         -- Prompt suggested LOC
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cMsg1, @cMsg2, @cMsg3, @cMsg4, @cMsg5, @cMsg6
      END
   END
END

GO