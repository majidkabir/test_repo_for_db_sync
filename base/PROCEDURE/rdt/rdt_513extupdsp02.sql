SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513ExtUpdSP02                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Unlock return booked location                                     */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2015-08-13   Ung       1.0   SOS337296 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513ExtUpdSP02]
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
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   -- Move by SKU
   IF @nFunc = 513
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- Enter
         BEGIN
            -- Return (booked in RDT piece receiving without ID)
            IF @cFromID = '' 
            BEGIN
               -- Return location
               IF EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC AND LocationType = 'OTHER' and LocationCategory = 'MEZZANINE')
               BEGIN
                  -- Get suggested LOC
                  DECLARE @cSuggestedLOC NVARCHAR(10)
                  SET @cSuggestedLOC = ''
                  SELECT TOP 1
                     @cSuggestedLOC = SuggestedLOC
                  FROM RFPutaway WITH (NOLOCK)
                  WHERE FromLOC = @cFromLoc
                     AND FromID = @cFromID
                     AND StorerKey = @cStorerKey
                     AND SKU = @cSKU
                     
                  -- Move to different LOC (both LOTxLOCxID and RFPutaway need to unlock)
                  IF @cSuggestedLOC <> @cToLOC
                  BEGIN
                     EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
                        ,@cFromLOC
                        ,@cFromID
                        ,'' -- @cToLOC can be diff from booked
                        ,@cStorerKey
                        ,@nErrNo  OUTPUT
                        ,@cErrMsg OUTPUT
                        ,@cSKU = @cSKU
                        ,@nPutawayQTY = @nQTY
                  END
                  ELSE
                  BEGIN
                     -- LOTxLOCxID.PendingMoveIn only is deducted by Exceed base when stock move-in
                     -- Manually deduct in RFPutaway
                     DECLARE @cLOT     NVARCHAR(10)
                     DECLARE @cLOC     NVARCHAR(10)
                     DECLARE @cID      NVARCHAR(18)
                     DECLARE @nRF_QTY  INT
                     DECLARE @nBal     INT
                     DECLARE @nDeduct  INT
                     DECLARE @nRowRef  INT
                     DECLARE @nDelRFPutaway INT
                     DECLARE @curPending CURSOR 
                     
                     BEGIN TRAN  -- Begin our own transaction
                     SAVE TRAN rdt_513ExtUpdSP02 -- For rollback or commit only our own transaction
   
                     SET @nBal = @nQTY
                     
                     SET @curPending = CURSOR FOR
                        SELECT LOT, SuggestedLOC, ID, QTY, RowRef
                        FROM dbo.RFPutaway WITH (NOLOCK)
                        WHERE FromLOC = @cFromLOC
                           AND FromID = @cFromID
                           AND StorerKey = @cStorerKey
                           AND SKU = @cSKU
            
                     OPEN @curPending
                     FETCH NEXT FROM @curPending INTO @cLOT, @cLOC, @cID, @nRF_QTY, @nRowRef
                     WHILE @@FETCH_STATUS = 0
                     BEGIN
                        -- Unlock by QTY, calc delete or update RFPutaway
                        IF @nRF_QTY <= @nBal
                        BEGIN
                           SET @nDelRFPutaway = 1 -- Yes
                           SET @nDeduct = @nRF_QTY
                           SET @nBal = @nBal - @nRF_QTY
                        END
                        ELSE
                        BEGIN
                           SET @nDelRFPutaway = 0 -- No
                           SET @nDeduct = @nBal
                           SET @nBal = 0
                        END
               
                        IF @nDelRFPutaway = 1
                        BEGIN
                           DELETE dbo.RFPutaway WITH (ROWLOCK)
                           WHERE  RowRef = @nRowRef
                           IF @@ERROR <> 0
                              GOTO RollBackTran
                        END
                        ELSE
                        BEGIN
                           UPDATE dbo.RFPutaway SET 
                              QTY = QTY - @nDeduct
                           WHERE RowRef = @nRowRef
                           IF @@ERROR <> 0
                              GOTO RollBackTran
                        END 
               
                        -- Unlock by QTY and no balance
                        IF @nBal = 0
                           BREAK
               
                        FETCH NEXT FROM @curPending INTO @cLOT, @cLOC, @cID, @nRF_QTY, @nRowRef
                     END
                  END
               END
            END
         END
      END
   END
END
GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_513ExtUpdSP02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_513ExtUpdSP02

GO