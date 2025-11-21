SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513SuggestLOC07                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 26-04-2018  1.0  Ung      WMS-4687 Created                           */
/* 10-07-2018  1.1  Ung      WMS-5665 Add LocationCategory              */
/* 10-11-2021  1.2  James    WMS-18325 Change Min Loc logic (james01)   */
/* 09-05-2022  1.3  yeekung  WMS-19609 exclude fromloc    (yeekung01)   */
/************************************************************************/

CREATE   PROC [RDT].[rdt_513SuggestLOC07] (
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

   IF @cType = 'LOCK'
   BEGIN
      DECLARE @cSuggLOC    NVARCHAR( 10)
      DECLARE @cPutawayZone      NVARCHAR(10)

      SET @cSuggLOC = ''
      
      /*-------------------------------------------------------------------------------------------
                                   Find a friend (same SKU, L02) with min QTY
      --------------------------------------------------------------------------------------------*/
      -- Get current zone
      SELECT @cPutawayZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC

      -- Get lottable02
      DECLARE @cLottable02 NVARCHAR(18)
      SELECT TOP 1 
         @cLottable02 = LA.Lottable02 
      FROM LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LLI.LOC = @cFromLOC
         AND LLI.ID = @cFromID
         AND LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LLI.QTY-LLI.QTYPicked-LLI.QtyAllocated > 0
      
      IF EXISTS( SELECT 1 FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#tFriendLOC'))
         DROP TABLE #tFriendLOC
      
      -- Find friends (same SKU, L02) 
      SELECT DISTINCT LOC.LOC
      INTO #tFriendLOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LOC.Facility = @cFacility
         AND LOC.PutawayZone = @cPutawayZone
         AND LOC.HostWHCode = ''
         AND LOC.LocationCategory <> 'STAGE'
         AND LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LA.Lottable02 = @cLottable02
         AND LLI.QTY-LLI.QTYPicked-LLI.QtyAllocated > 0

      -- Find a friend with min QTY
      IF @@ROWCOUNT > 0
      BEGIN
         SELECT TOP 1
            @cSuggLOC = SL.LOC
         FROM #tFriendLOC F
            JOIN SKUxLOC SL WITH (NOLOCK) ON (F.LOC = SL.LOC)
         WHERE SL.loc <> @cFromLoc  --(yeekung01)
            AND SL.qty<>0 --(yeekung01)
         GROUP BY SL.LOC
         ORDER BY SUM( SL.QTY-SL.QTYPicked-SL.QtyAllocated), SL.Loc
      END
      
      /*-------------------------------------------------------------------------------------------
                                             Find an empty LOC
      --------------------------------------------------------------------------------------------*/
      IF @cSuggLOC = '' 
      BEGIN
         SELECT TOP 1 
            @cSuggLOC = LOC.LOC
         FROM LOC WITH (NOLOCK)
            LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cPutawayZone
            AND LOC.HostWHCode = ''
            AND LOC.LocationCategory <> 'STAGE'
            AND LOC.loc <> @cFromLoc --(yeekung01)
         GROUP BY LOC.PALogicalLOC, LOC.LOC
         HAVING SUM( ISNULL( LLI.QTY, 0)-ISNULL( LLI.QTYPicked, 0)-ISNULL( LLI.QtyAllocated, 0)) = 0
            AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
         ORDER BY LOC.PALogicalLOC, LOC.LOC
      END

      -- Lock suggested loc
      IF @cSuggLOC <> ''
      BEGIN
         DECLARE @cUserName NVARCHAR(10)
         SET @cUserName = SUSER_SNAME()
         
         SET @nPABookingKey = 0
         EXEC rdt.rdt_Putaway_PendingMoveIn
             @cUserName     = @cUserName
            ,@cType         = 'LOCK'
            ,@cFromLoc      = @cFromLoc
            ,@cFromID       = @cFromID
            ,@cSuggestedLOC = @cSuggLOC
            ,@cStorerKey    = @cStorerKey
            ,@nErrNo        = @nErrNo   OUTPUT
            ,@cErrMsg       = @cErrMsg  OUTPUT
            ,@cSKU          = @cSKU
            ,@nPutawayQTY   = @nQTY
            ,@nFunc         = @nFunc
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END

      -- Check no suggested LOC
      IF @cSuggLOC = ''
      BEGIN
         SET @nErrNo = 124851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoSuggestedLOC
         SET @nErrNo = -1
         GOTO Quit
      END

      -- Output suggested LOC
      SET @cOutField01 = @cSuggLOC
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
   END

   IF @cType = 'UNLOCK'
   BEGIN
      -- Unlock current session suggested LOC
      IF @nPABookingKey <> 0
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --FromLOC
            ,'' --FromID
            ,'' --SuggestedLOC
            ,'' --Storer
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0  
            GOTO Quit  
      END
   END
   
Quit:

END

GO