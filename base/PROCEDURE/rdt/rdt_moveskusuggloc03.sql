SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_MoveSKUSuggLoc03                                */
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
/* Date        Rev  Author    Purposes                                  */
/* 03-12-2013  1.0  ChewKP    Created SOS#292549                        */
/* 17-09-2014  1.1  Chee      Bug Fix, PKLOTxLOCxID error (Chee01)      */
/* 05-01-2015  1.2  ChewKP    Add ActionFlag to Unlock PendingMoveIn    */
/*                            (ChewKP02)                                */
/* 23-04-2015  1.3  Ung       SOS337296 Add PABookingKey                */
/*                            Support booking for return                */
/************************************************************************/

CREATE PROC [RDT].[rdt_MoveSKUSuggLoc03] (
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

   DECLARE @cUserName   NVARCHAR(18)
   DECLARE @nTranCount  INT
   DECLARE @cSuggestedLOC NVARCHAR(10)
   DECLARE @nRowRef     INT
   DECLARE @nRF_QTY     INT
   DECLARE @nBal        INT
   DECLARE @nDeduct     INT
   DECLARE @cLOT        NVARCHAR(10)
   DECLARE @cLOC        NVARCHAR(10)
   DECLARE @cID         NVARCHAR(18)
   DECLARE @nDelRFPutaway INT
   DECLARE @curPending CURSOR

   SET @nTranCount = @@TRANCOUNT
   SET @cUserName = SUSER_SNAME()
   SET @nErrNo = 0

   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_MoveSKUSuggLoc03 -- For rollback or commit only our own transaction

   IF @cType = 'LOCK' -- (ChewKP02)
   BEGIN
      SET @cSuggestedLOC = ''

      -- Return (already booked in RDT piece receiving without ID)
      IF @cFromID = '' AND EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC AND LocationType = 'OTHER' and LocationCategory = 'MEZZANINE')
         SELECT TOP 1
            @cSuggestedLOC = SuggestedLOC
         FROM RFPutaway WITH (NOLOCK)
         WHERE FromLOC = @cFromLoc
            AND FromID = @cFromID
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
      ELSE
      BEGIN
         -- Get LOT
         SELECT TOP 1 @cLOT = LOT
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND ID = @cFromID
            AND LOC = @cFromLOC
            AND QTY > 0

         -- Putaway
         EXEC dbo.nspRDTPASTD
              @c_userid          = 'RDT'
            , @c_storerkey       = @cStorerKey
            , @c_lot             = @cLot
            , @c_sku             = @cSKU
            , @c_id              = @cFromID
            , @c_fromloc         = @cFromLoc
            , @n_qty             = @nQTY
            , @c_uom             = '' -- not used
            , @c_packkey         = '' -- optional, if pass-in SKU
            , @n_putawaycapacity = 0
            , @c_final_toloc     = @cSuggestedLOC OUTPUT

         -- Lock SuggestedLOC
         IF @cSuggestedLOC <> '' AND @cSuggestedLOC <> 'SEE_SUPV'
         BEGIN
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
               GOTO RollbackTran
         END
      END

      -- Check no suggested LOC
      IF @cSuggestedLOC = ''
      BEGIN
         SET @nErrNo = 84001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoSuitableLOC
         GOTO RollbackTran
      END

      -- Check no suggested LOC
      IF @cSuggestedLOC = 'SEE_SUPV'
      BEGIN
         SET @nErrNo = 84002
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoSuggestedLOC
         GOTO RollbackTran
      END

      -- Output suggested LOC
      SET @cOutField01 = @cSuggestedLOC
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
   ROLLBACK TRAN rdt_MoveSKUSuggLoc03 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_MoveSKUSuggLoc03
END

GO