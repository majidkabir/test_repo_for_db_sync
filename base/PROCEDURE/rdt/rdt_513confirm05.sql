SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513Confirm05                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: copy from 02->05                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2022-10-17   yeekung   1.0   WMS-20987 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513Confirm05] (
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cStorerKey      NVARCHAR( 15)
   ,@cFacility       NVARCHAR(  5)
   ,@cFromLOC        NVARCHAR( 10)
   ,@cFromID         NVARCHAR( 18)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cToID           NVARCHAR( 18)
   ,@cToLOC          NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Handling transaction
   DECLARE @nTranCount INT
   DECLARE @cFrPutawayZone NVARCHAR(10)
   SET @nTranCount = @@TRANCOUNT

   -- Move by SKU
   IF @nFunc = 513
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- Enter
         BEGIN
            DECLARE @cLOCCat NVARCHAR(10)
            SELECT @cLOCCat = LocationCategory,@cFrPutawayZone = Putawayzone FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC

            IF  @cFrPutawayZone ='CRWZONE'
            BEGIN
               -- Receiving stage
               IF @cLOCCat = 'STAGING' 
               BEGIN
            
                  DECLARE @nQTY_Bal    INT
                  DECLARE @nQTY_RF     INT
                  DECLARE @nQTY_Print  INT
                  DECLARE @nQTY_Move   INT
                  DECLARE @cLOT        NVARCHAR(10)
                  DECLARE @nRowRef     INT
               
                  SET @nQTY_Bal = @nQTY

                  BEGIN TRAN 
                  SAVE TRAN rdt_513Confirm05

                  -- Loop RFPutaway
                  DECLARE @curRF CURSOR
                  SET @curRF = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                     SELECT RowRef, LOT, QTY, QTYPrinted
                     FROM dbo.RFPutaway WITH (NOLOCK)
                     WHERE FromLOC = @cFromLOC
                        AND FromID = @cFromID
                        AND StorerKey = @cStorerKey
                        AND SKU = @cSKU
                        AND SuggestedLOC = @cToLOC
                        AND QTYPrinted > 0
                     ORDER BY RowRef
                  OPEN @curRF
                  FETCH NEXT FROM @curRF INTO @nRowRef, @cLOT, @nQTY_RF, @nQTY_Print
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Calc QTY to move
                     IF @nQTY_Print >= @nQTY_Bal
                        SET @nQTY_Move = @nQTY_Bal
                     ELSE
                        SET @nQTY_Move = @nQTY_Print
               
                     EXECUTE rdt.rdt_Move
                        @nMobile     = @nMobile,
                        @cLangCode   = @cLangCode,
                        @nErrNo      = @nErrNo  OUTPUT,
                        @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
                        @cSourceType = 'rdt_513Confirm05',
                        @cStorerKey  = @cStorerKey,
                        @cFacility   = @cFacility,
                        @cFromLOC    = @cFromLOC,
                        @cToLOC      = @cToLOC,
                        @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
                        @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
                        @cSKU        = @cSKU,
                        @nQTY        = @nQTY_Move,
                        @cFromLOT    = @cLOT 
                     IF @nErrNo <> 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                        GOTO RollBackTran
                     END

                     -- Deduct RFPutaway
                     IF @nQTY_Move = @nQTY_RF AND @nQTY_Move = @nQTY_Print
                     BEGIN
                        DELETE dbo.RFPutaway WITH (ROWLOCK)
                        WHERE  RowRef = @nRowRef
                        IF @@ERROR <> 0
                           GOTO RollBackTran
                     END
                     ELSE
                     BEGIN
                        UPDATE dbo.RFPutaway SET 
                           QTY = QTY - @nQTY_Move,
                           QTYPrinted = QTYPrinted - @nQTY_Move
                        WHERE RowRef = @nRowRef

                        IF @@ERROR <> 0
                           GOTO RollBackTran
                     END

                     -- Reduce QTY
                     SET @nQTY_Bal = @nQTY_Bal - @nQTY_Move

                     -- Check exit point
                     IF @nQTY_Bal = 0
                        BREAK

                     FETCH NEXT FROM @curRF INTO @nRowRef, @cLOT, @nQTY_RF, @nQTY_Print
                  END
               
                  -- Check fully offset
                  IF @nQTY_Bal <> 0
                  BEGIN
                     SET @nErrNo = 192851 
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoBookingQTY
                     GOTO RollBackTran
                  END

                  COMMIT TRAN rdt_513Confirm05
               END
            
               ELSE
               BEGIN
                  BEGIN TRAN 
                  SAVE TRAN rdt_513Confirm05

                  EXECUTE rdt.rdt_Move
                     @nMobile     = @nMobile,
                     @cLangCode   = @cLangCode,
                     @nErrNo      = @nErrNo  OUTPUT,
                     @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
                     @cSourceType = 'rdt_513Confirm05',
                     @cStorerKey  = @cStorerKey,
                     @cFacility   = @cFacility,
                     @cFromLOC    = @cFromLOC,
                     @cToLOC      = @cToLOC,
                     @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
                     @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
                     @cSKU        = @cSKU,
                     @nQTY        = @nQTY
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END

                  COMMIT TRAN rdt_513Confirm05
               END
            END
            ELSE
            BEGIN
               BEGIN TRAN 
               SAVE TRAN rdt_513Confirm05

               EXECUTE rdt.rdt_Move
                  @nMobile     = @nMobile,
                  @cLangCode   = @cLangCode,
                  @nErrNo      = @nErrNo  OUTPUT,
                  @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
                  @cSourceType = 'rdt_513Confirm05',
                  @cStorerKey  = @cStorerKey,
                  @cFacility   = @cFacility,
                  @cFromLOC    = @cFromLOC,
                  @cToLOC      = @cToLOC,
                  @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
                  @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
                  @cSKU        = @cSKU,
                  @nQTY        = @nQTY
               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollBackTran
               END

               COMMIT TRAN rdt_513Confirm05
            END
         END
      END
   END
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_513Confirm05 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO