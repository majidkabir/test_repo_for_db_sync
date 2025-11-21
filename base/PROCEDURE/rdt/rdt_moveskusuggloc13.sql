SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_MoveSKUSuggLoc13                                */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 18-06-2023  1.0  Ung         WMS-22818 base on rdt_MoveSKUSuggLoc02  */
/************************************************************************/

CREATE   PROC [RDT].[rdt_MoveSKUSuggLoc13] (
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
   
      If the scanned sku have stock in normal location (Loc.hostwhcode = æITX-AVAÆ),
      show the five location IDs of least stock on screen by acsending .If no stock,
      show the  alert message æNew location Æ on  screen
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
         SELECT TOP 5
             LOC.LOC, SUM(LLI.QTY - LLI.QTYAllocated - LLI.QtyPicked)
         FROM dbo.LOC LOC WITH (NOLOCK)
            JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE')
            -- AND LOC.HostWHCode ='ITX-AVA'
            AND LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND (LLI.QTY - LLI.QTYAllocated - LLI.QtyPicked) > 0
            AND LOC.LOC <> @cFromLoc   -- exclude from loc
         GROUP BY LOC.LOC
         ORDER BY 2 DESC
   
      OPEN @curLook4Loc
      FETCH NEXT FROM @curLook4Loc INTO @cSuggestedLoc, @nQTYAvail
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nLoop = 1 SET @cOutField02 = @cSuggestedLoc
         IF @nLoop = 2 SET @cOutField03 = @cSuggestedLoc
         IF @nLoop = 3 SET @cOutField04 = @cSuggestedLoc
         IF @nLoop = 4 SET @cOutField05 = @cSuggestedLoc
         IF @nLoop = 5 SET @cOutField06 = @cSuggestedLoc
         IF @nLoop >= 5
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