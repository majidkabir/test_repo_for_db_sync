SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_MoveSKUSuggLoc12                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get suggested loc to move                                   */
/*                                                                      */
/* Called from: rdtfnc_Move_SKU                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 28-10-2022 1.0  yeekung      WMS-21064 - Created                     */
/************************************************************************/

CREATE   PROC [RDT].[rdt_MoveSKUSuggLoc12] (
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

   DECLARE @cSuggestedLoc  NVARCHAR( 10),
           @nLoop          INT,
           @nQTYAvail      INT

   IF @cType = 'LOCK'
   BEGIN
      /*
      Suggest location logical:

      If the scanned sku have stock in normal location (Loc.hostwhcode = µITX-AVA╞),
      show the five location IDs of least stock on screen by acsending .If no stock,
      show the  alert message µNew location ╞ on  screen
      */

      SET @nLoop = 1
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''

      DECLARE @curLook4Loc CURSOR
      SET @curLook4Loc = CURSOR FOR
         SELECT TOP 10
             LOC.LOC, SUM(LLI.QTY - LLI.QTYAllocated - LLI.QtyPicked)
         FROM dbo.LOC LOC WITH (NOLOCK)
            JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
            AND Loc.LocationType in ('DPBULK','DYNPPICK')
            AND Loc.Status= 'OK'
            AND Loc.Hostwhcode='UU0001'
            -- AND LOC.HostWHCode ='ITX-AVA'
            AND LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND (LLI.QTY - LLI.QTYAllocated - LLI.QtyPicked) > 0
            AND LOC.LOC <> @cFromLoc   -- exclude from loc
         GROUP BY LOC.LOC
         Order By SUM(LLI.QTY - LLI.QTYAllocated - LLI.QtyPicked) DESC

      OPEN @curLook4Loc
      FETCH NEXT FROM @curLook4Loc INTO @cSuggestedLoc, @nQTYAvail
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nLoop = 1 SET @cOutField02 = @cSuggestedLoc + '  '+ CAST (@nQTYAvail AS NVARCHAR(3))
         IF @nLoop = 2 SET @cOutField03 = @cSuggestedLoc  + '  '+ CAST (@nQTYAvail AS NVARCHAR(3))
         IF @nLoop = 3 SET @cOutField04 = @cSuggestedLoc  + '  '+ CAST (@nQTYAvail AS NVARCHAR(3))
         IF @nLoop = 4 SET @cOutField05 = @cSuggestedLoc  + '  '+ CAST (@nQTYAvail AS NVARCHAR(3))
         IF @nLoop = 5 SET @cOutField06 = @cSuggestedLoc  + '  '+ CAST (@nQTYAvail AS NVARCHAR(3))
         IF @nLoop = 6 SET @cOutField02 = @cSuggestedLoc  + '  '+ CAST (@nQTYAvail AS NVARCHAR(3))
         IF @nLoop = 7 SET @cOutField03 = @cSuggestedLoc  + '  '+ CAST (@nQTYAvail AS NVARCHAR(3))
         IF @nLoop = 8 SET @cOutField04 = @cSuggestedLoc  + '  '+ CAST (@nQTYAvail AS NVARCHAR(3))
         IF @nLoop = 9 SET @cOutField05 = @cSuggestedLoc  + '  '+ CAST (@nQTYAvail AS NVARCHAR(3))
         IF @nLoop = 10 SET @cOutField06 = @cSuggestedLoc + '  '+ CAST (@nQTYAvail AS NVARCHAR(3))
         IF @nLoop >= 10
            BREAK

         SET @nLoop = @nLoop + 1
         FETCH NEXT FROM @curLook4Loc INTO @cSuggestedLoc, @nQTYAvail
      END

      -- If inventory is new then will return blank suggested loc
      -- Then show message 'NEW LOCATION'
      IF @cOutField02 = ''
         SET @cOutField01 = 'NEW LOCATION'
      ELSE
         SET @cOutField01 = 'SUGGESTED LOCATION:'
   END

Quit:

END

GO