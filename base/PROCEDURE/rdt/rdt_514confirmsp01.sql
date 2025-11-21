SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_514ConfirmSP01                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check move allowed and transfer                                   */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2020-05-04 1.0  Ung      WMS-12637 Created                                 */
/******************************************************************************/
CREATE PROCEDURE [RDT].[rdt_514ConfirmSP01] (
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),
   @nStep          INT, 
   @nInputKey      INT, 
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cToID          NVARCHAR( 18),
   @cToLoc         NVARCHAR( 10),
   @cFromLoc       NVARCHAR( 10),
   @cFromID        NVARCHAR( 18),
   @cUCC1          NVARCHAR( 20),
   @cUCC2          NVARCHAR( 20),
   @cUCC3          NVARCHAR( 20),
   @cUCC4          NVARCHAR( 20),
   @cUCC5          NVARCHAR( 20),
   @cUCC6          NVARCHAR( 20),
   @cUCC7          NVARCHAR( 20),
   @cUCC8          NVARCHAR( 20),
   @cUCC9          NVARCHAR( 20),
   @i              INT           OUTPUT, 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cUCC           NVARCHAR( 20)
   DECLARE @cUCC_LOC       NVARCHAR( 10)
   DECLARE @cUCC_ID        NVARCHAR( 18)
   DECLARE @cUCC_SKU       NVARCHAR( 20)
   DECLARE @cUCC_LOT       NVARCHAR( 10)
   DECLARE @nUCC_QTY       INT
   DECLARE @nUCC_RowRef    INT
   DECLARE @cSwapLOT       NVARCHAR( 1)
   DECLARE @cChkQuality    NVARCHAR( 10)
   DECLARE @cITrnKey       NVARCHAR( 10)
   DECLARE @cLoseID        NVARCHAR( 1)
   DECLARE @cLoseUCC       NVARCHAR( 1)

   -- Get LOC info  
   SELECT   
      @cLoseID = LoseID,   
      @cLoseUCC = LoseUCC  
   FROM LOC WITH (NOLOCK)   
   WHERE LOC = @cToLOC  

   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_514ConfirmSP01

   SET @i = 1
   WHILE @i < 10
   BEGIN
      IF @i = 1 SET @cUCC = @cUCC1
      IF @i = 2 SET @cUCC = @cUCC2
      IF @i = 3 SET @cUCC = @cUCC3
      IF @i = 4 SET @cUCC = @cUCC4
      IF @i = 5 SET @cUCC = @cUCC5
      IF @i = 6 SET @cUCC = @cUCC6
      IF @i = 7 SET @cUCC = @cUCC7
      IF @i = 8 SET @cUCC = @cUCC8
      IF @i = 9 SET @cUCC = @cUCC9
      
      IF @cUCC <> ''
      BEGIN
         -- Get FromLOC, FromID
         SELECT TOP 1 
            @cUCC_LOC = LOC, 
            @cUCC_ID = ID
         FROM dbo.UCC (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
            AND Status = '1' -- Received
         
         -- Check move allowed
         EXEC rdt.rdt_UAMoveCheck @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility
            ,@cUCC_LOC 
            ,@cToLOC 
            ,'M' -- Type
            ,@cSwapLOT     OUTPUT
            ,@cChkQuality  OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT

         -- Loop UCC
         DECLARE @curUCC CURSOR
         SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT UCC_RowRef, SKU, QTY, LOT
            FROM dbo.UCC WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND UCCNo = @cUCC
               AND [Status] = '1'
         OPEN @curUCC
         FETCH NEXT FROM @curUCC INTO @nUCC_RowRef, @cUCC_SKU, @nUCC_QTY, @cUCC_LOT
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Swap lottables
            IF @cSwapLOT = '1'
            BEGIN
               EXEC rdt.rdt_UATransfer @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility
                  ,@cUCC_LOC
                  ,@cUCC_ID
                  ,@cUCC_LOT
                  ,@cUCC_SKU
                  ,@nUCC_QTY
                  ,@cChkQuality
                  ,@cITrnKey OUTPUT
                  ,@nErrNo   OUTPUT
                  ,@cErrMsg  OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
                  
               -- Get new LOT
               SELECT @cUCC_LOT = LOT FROM ITrn WITH (NOLOCK)WHERE ITrnKey = @cITrnKey
            END
             
            -- Execute move process
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode, 
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
               @cSourceType = 'rdt_514ConfirmSP01', 
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility, 
               @cFromLOC    = @cUCC_LOC, 
               @cToLOC      = @cToLOC, 
               @cFromID     = @cUCC_ID, 
               @cToID       = @cToID,  
               @nFunc       = @nFunc, 
               @cSKU        = @cUCC_SKU, 
               @nQTY        = @nUCC_QTY, 
               @cFromLOT    = @cUCC_LOT
            IF @nErrNo <> 0
               GOTO RollBackTran

            -- Update UCC
            UPDATE dbo.UCC WITH (ROWLOCK) SET 
               LOT = @cUCC_LOT, 
               ID = CASE WHEN @cLoseID = '1' THEN '' ELSE @cToID END,   
               LOC = @cToLOC,   
               Status = CASE WHEN @cLoseUCC = '1' THEN '6' ELSE Status END, 
               EditWho  = SUSER_SNAME(),    
               EditDate = GETDATE()
            WHERE UCC_RowRef = @nUCC_RowRef
            IF @@ERROR <> 0
            BEGIN    
               SET @nErrNo = 151701 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC FAIL 
               GOTO RollBackTran    
            END    

            FETCH NEXT FROM @curUCC INTO @nUCC_RowRef, @cUCC_SKU, @nUCC_QTY, @cUCC_LOT
         END
      
         -- Log event
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '4', -- Move
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cLocation     = @cUCC_LOC,
            @cToLocation   = @cToLOC,
            @cID           = @cUCC_ID, 
            @cToID         = @cToID, 
            @cRefNo1       = @cUCC, 
            @cUCC          = @cUCC
      END
      SET @i = @i + 1
   END
   
   COMMIT TRAN rdt_514ConfirmSP01
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_514ConfirmSP01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END


GO