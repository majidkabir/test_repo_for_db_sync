SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1764ClosePlt02                                     */
/* Copyright      : IDS                                                    */
/*                                                                         */
/* Purpose: Confirm replenish. Update ToID = DropID                        */
/*                                                                         */
/* Called from:                                                            */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date        Rev  Author    Purposes                                     */
/* 2021-05-07  1.0  James     WMS-16964. Created                           */
/***************************************************************************/

CREATE PROC [RDT].[rdt_1764ClosePlt02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR(3),
   @cUserName      NVARCHAR(18),
   @cListKey       NVARCHAR(10),
   @nErrNo         INT         OUTPUT,
   @cErrMsg        NVARCHAR(20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cFromLOC       NVARCHAR( 10)
   DECLARE @cFromID        NVARCHAR( 18)
   DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cToID          NVARCHAR( 18)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cUCCNo         NVARCHAR( 20)
   DECLARE @nQTY           INT
   DECLARE @nSystemQTY     INT
   DECLARE @nQTYAlloc      INT
   DECLARE @nQTYReplen     INT
   DECLARE @nUCCQTY        INT
   DECLARE @cMoveQTYAlloc  NVARCHAR( 1)
   DECLARE @cMoveQTYReplen NVARCHAR( 1)
   DECLARE @cToLocType     NVARCHAR( 10)
   DECLARE @cLoseUCC       NVARCHAR( 1)
   DECLARE @cLoseID        NVARCHAR( 1)
   DECLARE @cClosePalletSP NVARCHAR( 20)
   DECLARE @cDefaultSuggToLOC NVARCHAR( 10)
   DECLARE @cLocAisle      NVARCHAR( 10)
   DECLARE @cPND           NVARCHAR( 10) = ''

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   SELECT @cStorerKey = StorerKey
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1764ClosePlt02 -- For rollback or commit only our own transaction

   -- Lock orders to prevent deadlock
   DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OrderKey
      FROM PickDetail WITH (NOLOCK)
      WHERE TaskDetailKey IN (
         SELECT TaskDetailKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE ListKey = @cListKey
            AND UserKey = @cUserName
            AND Status = '5') -- 3=Fetch, 5=Picked, 9=Complete
      ORDER BY OrderKey
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cOrderKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Dummy update to lock order
      UPDATE Orders SET
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME(),
         TrafficCop = NULL
      WHERE OrderKey = @cOrderKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 167706
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- LockOrderFail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPD INTO @cOrderKey
   END

   -- Loop tasks
   DECLARE @curRPTask CURSOR
   SET @curRPTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT TaskDetailKey, PickMethod, StorerKey, FromLOC, FromID, ToLOC, ToID, SKU, LOT, QTY, SystemQTY, WaveKey
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE ListKey = @cListKey
         AND UserKey = @cUserName
         AND Status = '5' -- 3=Fetch, 5=Picked, 9=Complete
      ORDER BY TaskDetailKey
   OPEN @curRPTask
   FETCH NEXT FROM @curRPTask INTO @cTaskDetailKey, @cPickMethod, @cStorerKey, @cFromLOC, @cFromID, @cToLOC, @cToID, @cSKU, @cLOT, @nQTY, @nSystemQTY, @cWaveKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT @cFacility = Facility FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC

      SELECT @cLocAisle = LocAisle
      FROM dbo.LOC WITH (NOLOCK)
      WHERE Loc = @cToLoc
      AND   Facility = @cFacility
   
      SELECT @cPND = Code
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'PND'
      AND   Storerkey = @cStorerKey
      AND   Long = 'IN'
      AND   code2 = @cLocAisle

      IF @cPND <> ''
         SET @cToLOC = @cPND

      -- Full pallet replenish
      IF @cPickMethod = 'FP'
      BEGIN
         -- Reduce QTYReplen
         UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET
            QTYReplen = 0
         WHERE LOC = @cFromLOC
            AND ID = @cFromID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 167701
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
            GOTO RollBackTran
         END

         -- Move inventory
         EXECUTE rdt.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode,
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT,
            @cSourceType = 'rdt_1764ClosePlt02',
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility,
            @cFromLOC    = @cFromLOC,
            @cToLOC      = @cToLOC,
            @cFromID     = @cFromID,
            @cToID       = @cFromID,
            @nFunc       = @nFunc
         IF @nErrNo <> 0
            GOTO RollBackTran

         EXEC RDT.rdt_STD_EventLog
            @cActionType    = '5', -- Replenish
            @cUserID        = @cUserName,
            @nMobileNo      = @nMobile,
            @nFunctionID    = @nFunc,
            @cFacility      = @cFacility,
            @cStorerKey     = @cStorerKey,
            @cLocation      = @cFromLOC,
            @cToLocation    = @cToLOC,
            @cID            = @cFromID,
            @cToID          = @cToID,
            @cRefNo5        = @cListKey,
            @cTaskDetailKey = @cTaskDetailKey,
            @cSKU           = @cSKU,
            @nQTY           = @nQTY
      END

      -- Partial pallet replenish
      IF @cPickMethod = 'PP'
      BEGIN
         -- Move inventory
         IF EXISTS( SELECT 1 FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey)
         BEGIN
            SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
            SET @cMoveQTYReplen = rdt.RDTGetConfig( @nFunc, 'MoveQTYReplen', @cStorerKey)

            DECLARE @curUCC CURSOR
            SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT UCCNo, QTY
               FROM rdt.rdtRPFLog WITH (NOLOCK)
               WHERE TaskDetailKey = @cTaskDetailKey
            OPEN @curUCC
            FETCH NEXT FROM @curUCC INTO @cUCCNo, @nUCCQTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Single sku ucc
               IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                           WHERE Storerkey = @cStorerKey
                           AND   UCCNo = @cUCCNo
                           GROUP BY UCCNo
                           HAVING COUNT( DISTINCT SKU) = 1)
               BEGIN
                  -- Calc QTYAlloc
                  IF @cMoveQTYAlloc = '1'
                  BEGIN
                     IF @nUCCQTY < @nSystemQTY -- Short replen
                        SET @nQTYAlloc = @nUCCQTY
                     ELSE
                        SET @nQTYAlloc = @nSystemQTY

                     SET @nSystemQTY = @nSystemQTY - @nQTYAlloc
                  END
                  ELSE
                     SET @nQTYAlloc = 0

                  -- Calc QTYReplen
                  IF @cMoveQTYReplen = '1'
                  BEGIN
                     IF @cMoveQTYAlloc = '1'
                        SET @nQTYReplen = @nUCCQTY - @nQTYAlloc
                     ELSE
                        SET @nQTYReplen = @nUCCQTY
                  END
                  ELSE
                     SET @nQTYReplen = 0
                  
                  -- Move by UCC
                  EXECUTE rdt.rdt_Move
                     @nMobile     = @nMobile,
                     @cLangCode   = @cLangCode,
                     @nErrNo      = @nErrNo  OUTPUT,
                     @cErrMsg     = @cErrMsg OUTPUT,
                     @cSourceType = 'rdt_1764ClosePlt02',
                     @cStorerKey  = @cStorerKey,
                     @cFacility   = @cFacility,
                     @cFromLOC    = @cFromLOC,
                     @cToLOC      = @cToLOC,
                     @cFromID     = @cFromID,
                     @cToID       = @cToID,
                     @cUCC        = @cUCCNo,
                     @nQTYAlloc   = @nQTYAlloc,
                     @nQTYReplen  = @nQTYReplen,
                     @nFunc       = @nFunc,
                     @cDropID     = @cUCCNo
                  IF @nErrNo <> 0
                     GOTO RollBackTran

                  EXEC RDT.rdt_STD_EventLog
                     @cActionType    = '5', -- Replenish
                     @cUserID        = @cUserName,
                     @nMobileNo      = @nMobile,
                     @nFunctionID    = @nFunc,
                     @cFacility      = @cFacility,
                     @cStorerKey     = @cStorerKey,
                     @cLocation      = @cFromLOC,
                     @cToLocation    = @cToLOC,
                     @cID            = @cFromID,
                     @cToID          = @cToID,
                     @cRefNo1        = @cUCCNo,
                     @cRefNo5        = @cListKey,
                     @cTaskDetailKey = @cTaskDetailKey
               END
               ELSE  -- Multi sku ucc
               BEGIN
                  DECLARE @nPD_Qty     INT = 0
                  SELECT @nPD_Qty = ISNULL( SUM( Qty), 0) 
                  FROM dbo.PICKDETAIL WITH (NOLOCK)
                  WHERE TaskDetailKey = @cTaskDetailKey
                           
                  DECLARE @cUCC_SKU    NVARCHAR (20)
                  DECLARE @curMultiSKUUCC CURSOR
                  SET @curMultiSKUUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT SKU, Lot, SUM( Qty)
                  FROM dbo.UCC WITH (NOLOCK)
                  WHERE Storerkey = @cStorerKey
                  AND   UCCNo = @cUCCNo
                  GROUP BY SKU, Lot
                  OPEN @curMultiSKUUCC
                  FETCH NEXT FROM @curMultiSKUUCC INTO @cUCC_SKU, @cLOT, @nUCCQTY
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Calc QTYAlloc
                     SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
                     IF @cMoveQTYAlloc = '1'
                     BEGIN
                        IF @nUCCQTY < @nSystemQTY -- Short replen
                        BEGIN
                           SET @nQTYAlloc = @nUCCQTY
                           
                           IF @nPD_Qty > 0
                           BEGIN
                              IF @nPD_Qty < @nQTYAlloc
                              BEGIN
                                 SET @nQTYAlloc = @nPD_Qty
                                 SET @nPD_Qty = 0
                              END
                              ELSE
                                 SET @nPD_Qty = @nPD_Qty - @nQTYAlloc
                           END
                           ELSE
                              SET @nQTYAlloc = 0
                        END
                        ELSE
                           SET @nQTYAlloc = @nSystemQTY
                     END
                     ELSE
                        SET @nQTYAlloc = 0

                     -- Calc QTYReplen
                     SET @cMoveQTYReplen = rdt.RDTGetConfig( @nFunc, 'MoveQTYReplen', @cStorerKey)
                     IF @cMoveQTYReplen = '1'
                     BEGIN
                        IF @cMoveQTYAlloc = '1'
                           SET @nQTYReplen = @nUCCQTY - @nQTYAlloc
                        ELSE
                           SET @nQTYReplen = @nUCCQTY
                     END
                     ELSE
                        SET @nQTYReplen = 0

                     -- move ucc with multi sku (rdt_move not support yet)
                     EXECUTE rdt.rdt_Move
                        @nMobile     = @nMobile,
                        @cLangCode   = @cLangCode,
                        @nErrNo      = @nErrNo  OUTPUT,
                        @cErrMsg     = @cErrMsg OUTPUT,
                        @cSourceType = 'rdt_1764ClosePlt02',
                        @cStorerKey  = @cStorerKey,
                        @cFacility   = @cFacility,
                        @cFromLOC    = @cFromLOC,
                        @cToLOC      = @cToLOC,
                        @cFromID     = @cFromID,
                        @cToID       = @cToID,
                        @cSKU        = @cUCC_SKU,
                        @nQTY        = @nUCCQTY,
                        @nQTYAlloc   = @nQTYAlloc,
                        @nQTYReplen  = @nQTYReplen,
                        @cFromLOT    = @cLOT,
                        @nFunc       = @nFunc,
                        @cTaskDetailKey = @cTaskDetailKey

                     IF @nErrNo <> 0
                        GOTO RollBackTran

                     -- Get LocationType
                     SELECT @cToLocType = SL.LocationType
                     FROM dbo.SKUxLOC SL (NOLOCK)
                     WHERE SL.StorerKey = @cStorerKey
                     AND   SL.SKU = @cUCC_SKU
                     AND   SL.LOC = @cToLOC

                     SET @cLoseUCC = ''
                     SET @cLoseID = ''
                     SELECT
                        @cLoseID = LoseID,
                        @cLoseUCC = LoseUCC
                     FROM dbo.LOC (NOLOCK)
                     WHERE LOC = @cToLOC
   
                     -- Update UCC (rdt_move not support move ucc with multisku ucc)
                     UPDATE dbo.UCC WITH (ROWLOCK) SET
                        LOC = @cToLOC,
                        ID = CASE
                              WHEN @cLoseID = '1' THEN '' -- Lose ID
                              WHEN @cToID IS NULL THEN ID -- ID not change
                              ELSE @cToID
                              END,
                        -- Lose UCC. Status 5=Picked/Repl
                        Status = CASE WHEN (@cToLocType = 'PICK' OR @cToLocType = 'CASE')  THEN '5'
                                      WHEN @cLoseUCC = '1' THEN '6' 
                                      ELSE Status
                                 END,
                        EditWho = SUSER_SNAME(),
                        EditDate = GETDATE(),
                        TrafficCop = NULL
                     WHERE StorerKey = @cStorerKey
                     AND   LOT = @cLOT 
                     AND   LOC = @cFromLOC 
                     AND   ID  = @cFromID  
                     AND   UCCNo = @cUCCNo
                     AND   SKU = @cUCC_SKU
                     AND   Status IN ('1', '3') -- Received, , Allocated
                     AND   Status <> ''

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 167708
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC Fail
                        GOTO RollBackTran
                     END

                     EXEC RDT.rdt_STD_EventLog
                        @cActionType    = '5', -- Replenish
                        @cUserID        = @cUserName,
                        @nMobileNo      = @nMobile,
                        @nFunctionID    = @nFunc,
                        @cFacility      = @cFacility,
                        @cStorerKey     = @cStorerKey,
                        @cLocation      = @cFromLOC,
                        @cToLocation    = @cToLOC,
                        @cID            = @cFromID,
                        @cToID          = @cToID,
                        @cSKU           = @cSKU,
                        @nQTY           = @nQTY,
                        @cLOT           = @cLOT,
                        @cRefNo5        = @cListKey,
                        @cTaskDetailKey = @cTaskDetailKey
                        
                     FETCH NEXT FROM @curMultiSKUUCC INTO @cUCC_SKU, @cLOT, @nUCCQTY
                  END
               END

               -- Clear rdtRPFLog
               DELETE rdt.rdtRPFLog WHERE TaskDetailKey = @cTaskDetailKey AND UCCNo = @cUCCNo
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 167705
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelRPFLogFail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curUCC INTO @cUCCNo, @nUCCQTY
            END
         END
         ELSE
         BEGIN
            -- Calc QTYAlloc
            SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
            IF @cMoveQTYAlloc = '1'
            BEGIN
               IF @nQTY < @nSystemQTY -- Short replen
                  SET @nQTYAlloc = @nQTY
               ELSE
                  SET @nQTYAlloc = @nSystemQTY
            END
            ELSE
               SET @nQTYAlloc = 0

            -- Calc QTYReplen
            SET @cMoveQTYReplen = rdt.RDTGetConfig( @nFunc, 'MoveQTYReplen', @cStorerKey)
            IF @cMoveQTYReplen = '1'
            BEGIN
               IF @cMoveQTYAlloc = '1'
                  SET @nQTYReplen = @nQTY - @nQTYAlloc
               ELSE
                  SET @nQTYReplen = @nQTY
            END
            ELSE
               SET @nQTYReplen = 0

            -- Move by SKU
            IF @nQTY > 0
            BEGIN
               -- RPF task grouped for same loc, same sku into 1 task then
               -- Taskdetail.Lot = '' (empty). Need to retrieve from pickdetail 
               SELECT @cLOT = Lot
               FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE TaskDetailKey = @cTaskDetailKey
               
               EXECUTE rdt.rdt_Move
                  @nMobile     = @nMobile,
                  @cLangCode   = @cLangCode,
                  @nErrNo      = @nErrNo  OUTPUT,
                  @cErrMsg     = @cErrMsg OUTPUT,
                  @cSourceType = 'rdt_1764ClosePlt02',
                  @cStorerKey  = @cStorerKey,
                  @cFacility   = @cFacility,
                  @cFromLOC    = @cFromLOC,
                  @cToLOC      = @cToLOC,
                  @cFromID     = @cFromID,
                  @cToID       = @cToID,
                  @cSKU        = @cSKU,
                  @nQTY        = @nQTY,
                  @nQTYAlloc   = @nQTYAlloc,
                  @nQTYReplen  = @nQTYReplen,
                  @cFromLOT    = @cLOT,
                  @nFunc       = @nFunc,
                  @cTaskDetailKey = @cTaskDetailKey
                  --@cWaveKey    = @cWaveKey
               IF @nErrNo <> 0
                  GOTO RollBackTran

               EXEC RDT.rdt_STD_EventLog
                  @cActionType    = '5', -- Replenish
                  @cUserID        = @cUserName,
                  @nMobileNo      = @nMobile,
                  @nFunctionID    = @nFunc,
                  @cFacility      = @cFacility,
                  @cStorerKey     = @cStorerKey,
                  @cLocation      = @cFromLOC,
                  @cToLocation    = @cToLOC,
                  @cID            = @cFromID,
                  @cToID          = @cToID,
                  @cSKU           = @cSKU,
                  @nQTY           = @nQTY,
                  @cLOT           = @cLOT,
                  @cRefNo5        = @cListKey,
                  @cTaskDetailKey = @cTaskDetailKey
            END
         END
      END

      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey AND ISNULL( TransitLOC, '') <> '')
      BEGIN
         -- Unlock  suggested location
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,''      --@cFromLOC
            ,@cFromID--@cFromID
            ,@cToLOC --@cSuggestedLOC
            ,''      --@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END

      -- Update Task
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         Status = '9', -- Closed
         FinalLOC = ToLoc,
         ToLoc = @cPND,
         ToID = CASE WHEN PickMethod = 'PP' THEN DropID ELSE FromID END,
         EndTime = GETDATE(),
         EditDate = GETDATE(),
         EditWho  = @cUserName,
         Trafficcop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 167704
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curRPTask INTO @cTaskDetailKey, @cPickMethod, @cStorerKey, @cFromLOC, @cFromID, @cToLOC, @cToID, @cSKU, @cLOT, @nQTY, @nSystemQTY, @cWaveKey
   END

   -- Create next task
   EXEC rdt.rdt_TM_Replen_CreateNextTask @nMobile, @nFunc, @cLangCode,
      @cUserName,
      @cListKey,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

-- Debug code
IF EXISTS( SELECT TOP 1 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC AND LocationCategory = 'PND_OUT')
BEGIN
   IF @cStorerKey = '18405'
   BEGIN
      IF NOT EXISTS( SELECT TOP 1 1 FROM TaskDetail WITH (NOLOCK) WHERE ListKey = @cListKey AND ListKey <> '' AND TaskType = 'RP1')
      BEGIN
         SET @nErrNo = 167707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No RP1 created
         GOTO RollBackTran
      END
   END
END

      DECLARE @nRPLQty     INT
      DECLARE @nSysQty     INT
      
      SELECT @nRPLQty = Qty, 
             @nSysQty = SystemQty, 
             @cFromLOC = FromLoc, 
             @cFromID = FromID, 
             @cLOT = Lot
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey
      
      -- Check short replen, clear QtyReplen
      IF @nSysQty > @nRPLQty
      BEGIN
         UPDATE dbo.LOTxLOCxID SET 
            QtyReplen = QtyReplen - ( @nSysQty - @nRPLQty)
         WHERE Lot = @cLOT
         AND   Loc = @cFromLOC
         AND   Id = @cFromID
         
         IF @@ERROR <> 0
            GOTO RollBackTran
      END

   COMMIT TRAN rdt_1764ClosePlt02 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764ClosePlt02 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO