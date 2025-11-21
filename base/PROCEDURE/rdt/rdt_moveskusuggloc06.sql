SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_MoveSKUSuggLoc06                                */
/* Purpose: Extended update sp for carton id receiving. Calc suggested  */
/*          loc based on Find a friend & then find a empty loc          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2016-04-18   ChewKP     1.0  SOS#368702 - Created                    */
/************************************************************************/


CREATE PROC [RDT].[rdt_MoveSKUSuggLoc06] (
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

DECLARE
   @nLoop         INT,
   @cLottable01   NVARCHAR(18),
   @cLottable02   NVARCHAR(18),
   @cLottable03   NVARCHAR(18),
   @dLottable04   DATETIME,
   @cLot          NVARCHAR(10),
   @cSuggestedLOC NVARCHAR(10),
   @nTranCount    INT,
   @cUserName     NVARCHAR(18),
   @cPickZone     NVARCHAR(10)

   SET @nTranCount = @@TRANCOUNT
   SET @cUserName = suser_sname()
   SET @nErrNo = 0

   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_MoveSKUSuggLoc06 -- For rollback or commit only our own transaction

   SET @cLottable01 = ''
   SET @cLottable02 = ''
   SET @cLottable03 = ''
   SET @dLottable04 = NULL
   SET @cLot  = ''
   SET @cSuggestedLOC = ''

   IF @cType = 'LOCK' -- (ChewKP02)
   BEGIN
     
     SELECT TOP 1 @cPickZone = PickZone 
     FROM dbo.Loc WITH (NOLOCK)
     WHERE Loc = @cFromLoc
     AND Facility = @cFacility 
     
     IF @cPickZone = 'PTS'
     BEGIN
     
        EXEC @nErrNo = [dbo].[nspRDTPASTD]
              @c_userid          = 'RDT'
            , @c_storerkey       = @cStorerKey
            , @c_lot             = ''
            , @c_sku             = @cSKU
            , @c_id              = @cFromID
            , @c_fromloc         = @cFromLOC
            , @n_qty             = 0
            , @c_uom             = '' -- not used
            , @c_packkey         = '' -- optional, if pass-in SKU
            , @n_putawaycapacity = 0
            , @c_final_toloc     = @cSuggestedLOC     OUTPUT
            --, @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT
            --, @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT
            , @c_PAStrategyKey   = 'CARTERSZDP' --@cPAStrategyKey
            , @n_PABookingKey    = @nPABookingKey     OUTPUT
            
         -- Call RDTPASTD to find Final Loc
   --      EXEC [dbo].[nspRDTPASTD]
   --              @c_userid          = 'RDT'
   --            , @c_storerkey       = @cStorerKey
   --            , @c_lot             = @cLot
   --            , @c_sku             = @cSKU
   --            , @c_id              = @cFromID
   --            , @c_fromloc         = @cFromLoc
   --            , @n_qty             = @nQTY
   --            , @c_uom             = '' -- not used
   --            , @c_packkey         = '' -- optional, if pass-in SKU
   --            , @n_putawaycapacity = 0
   --            , @c_final_toloc     = @cSuggestedLOC OUTPUT
   --            , @c_Param1          = @cLottable01
   --            , @c_Param2          = @cLottable02
   --            , @c_Param3          = @cLottable03
   --            , @c_Param4          = @dLottable04
   --            , @c_Param5          = ''
   
         SET @cOutField01 = @cSuggestedLOC
   
         -- If inventory is new then will return blank suggested loc
         -- Then show message 'NEW LOCATION'
         IF ISNULL(@cOutField01, '') = ''
         BEGIN
            SET @nErrNo = 98851
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoSuggLocFound
            GOTO RollbackTran
         END
         ELSE
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM RFPutaway WITH (NOLOCK)
                          WHERE StorerKey = @cStorerKey
                            AND SKU = @cSKU
                            AND FromLOC = @cFromLoc
                            AND FromID = @cFromID
                            AND SuggestedLOC = @cSuggestedLOC)
            BEGIN
               -- Use rdt_Putaway_PendingMoveIn for booking (Chee01)
               SET @nPABookingKey = 0
               EXEC rdt.rdt_Putaway_PendingMoveIn
                   @cUserName     = @cUserName
                  ,@cType         = 'LOCK'
                  ,@cFromLoc      = @cFromLoc
                  ,@cFromID       = @cFromID
                  ,@cSuggestedLOC = @cSuggestedLOC
                  ,@cStorerKey    = @cStorerKey
                  ,@nErrNo        = @nErrNo   OUTPUT
                  ,@cErrMsg       = @cErrMsg  OUTPUT
                  ,@cSKU          = @cSKU
                  ,@nPutawayQTY   = @nQTY
                  ,@nFunc         = @nFunc
                  ,@nPABookingKey = @nPABookingKey OUTPUT
               IF @nErrNo <> 0
               BEGIN
                  GOTO RollbackTran
               END
            END
         END
     END
     ELSE 
     BEGIN
         SET @cOutField01 = ''
     END
   END

   IF @cType = 'UNLOCK' -- (ChewKP02)
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
            GOTO RollbackTran
      END

      -- Unlock transfer allocation suggested LOC
      IF @cFromID <> ''
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --FromLOC
            ,@cFromID
            ,'' --SuggestedLOC
            ,'' --Storer
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO RollbackTran
      END
   END
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_MoveSKUSuggLoc06 -- Only rollback change made here

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_MoveSKUSuggLoc06
END


GO