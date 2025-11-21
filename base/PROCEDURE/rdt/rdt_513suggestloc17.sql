SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513SuggestLOC17                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2023-01-05   1.0  Ung      WMS-21419 Created base on rdt_523ExtPA46  */
/************************************************************************/

CREATE   PROC [RDT].[rdt_513SuggestLOC17] (
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
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT = @@TRANCOUNT

   IF @cType = 'LOCK'
   BEGIN
      DECLARE @cSuggestedLOC  NVARCHAR( 10) = ''
      DECLARE @cBUSR4         NVARCHAR( 200)
      DECLARE @cPAZone        NVARCHAR( 10) = ''
      DECLARE @cDefaultLOC    NVARCHAR( 10) = ''
   
      -- Blank the output
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
   
      -- Get SKU info
      SELECT @cBUSR4 = ISNULL( BUSR4, '')
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU
      
      -- Get product zone and LOC
      SELECT 
         @cPAZone = ISNULL( Short, ''), 
         @cDefaultLOC = ISNULL( Long, '')
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'SEPPAZONE'
         AND Code = @cBUSR4
         AND StorerKey = @cStorerKey
         AND Code2 = CAST( @nFunc AS NVARCHAR(4))

      -- Get L2, L3, L4
      DECLARE @cLottable02 NVARCHAR( 18)
      DECLARE @cLottable03 NVARCHAR( 18)
      DECLARE @dLottable04 DATETIME
      SELECT
         @cLottable02 = LA.Lottable02,
         @cLottable03 = LA.Lottable03,
         @dLottable04 = LA.Lottable04
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LLI.LOC = @cFromLOC
         AND LLI.ID = @cFromID
         AND LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - LLI.QTYReplen > 0

      -- Single LOT
      IF @@ROWCOUNT = 1
      BEGIN
         -- Find a friend (same SKU, L2, L3, L4)
         SELECT TOP 1 @cSuggestedLOC = LLI.LOC
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LLI.StorerKey = @cStorerKey 
            AND LLI.SKU = @cSKU
            AND LLI.QTY-LLI.QTYPicked > 0
            AND LLI.LOC <> @cFromLOC
            AND LOC.LocationCategory = 'SHELVING' 
            AND LOC.LocationType = 'DYNPPICK'
            AND LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cPAZone
            AND LA.Lottable02 = @cLottable02
            AND LA.Lottable03 = @cLottable03
            AND LA.Lottable04 = @dLottable04
         ORDER BY 1
      END
      ELSE
      BEGIN
         DECLARE @cMsg NVARCHAR( 20)
         SET @cMsg = rdt.rdtgetmessage( 196301, @cLangCode, 'DSP') -- MULTI LOT IN FROMLOC
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cMsg
      END
      
      -- Find empty LOC
      IF @cSuggestedLOC = ''
      BEGIN
         SELECT TOP 1 
            @cSuggestedLOC = LOC.LOC
         FROM dbo.LOC LOC WITH (NOLOCK) 
            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) 
         WHERE LOC.Facility = @cFacility
            AND LOC.Locationflag <> 'HOLD'
            AND LOC.Locationflag <> 'DAMAGE'
            AND LOC.Status <> 'HOLD'
            AND LOC.LocationCategory = 'SHELVING' 
            AND LOC.LocationType = 'DYNPPICK'
            AND LOC.PutawayZone = @cPAZone
         GROUP BY Loc.LogicalLocation, LOC.LOC
         HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) = 0 
            AND ISNULL( SUM(LLI.PendingMoveIn), 0) = 0
         ORDER BY Loc.LogicalLocation, LOC.LOC        
      END

      -- Default LOC
      IF @cSuggestedLOC = ''
         SET @cSuggestedLOC = @cDefaultLOC

      /*-------------------------------------------------------------------------------
                                    Book suggested location
      -------------------------------------------------------------------------------*/
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_513SuggestLOC17 -- For rollback or commit only our own transaction

      IF @cSuggestedLOC <> ''
      BEGIN
         DECLARE @cUserName NVARCHAR( 18) 
         SET @cUserName = SUSER_SNAME()
         SET @nPABookingKey = 0 

         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cFromID
            ,@cSuggestedLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@cSKU          = @cSKU
            ,@nPutawayQTY   = @nQTY
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran

         SET @cOutField01 = @cSuggestedLOC         

         COMMIT TRAN rdt_513SuggestLOC17 -- Only commit change made here
      END
   END
   ELSE
   BEGIN
      -- Unlock current session suggested LOC
      IF @nPABookingKey <> 0
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --FromLOC
            ,'' --FromID
            ,'' --SuggLOC
            ,'' --Storer
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0  
            GOTO RollBackTran
      
         SET @nPABookingKey = 0
      END
   END
   
   GOTO Quit   

RollBackTran:
   ROLLBACK TRAN rdt_513SuggestLOC17 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO