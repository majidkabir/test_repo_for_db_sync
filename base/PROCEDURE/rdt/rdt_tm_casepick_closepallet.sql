SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/***************************************************************************/
/* Store procedure: rdt_TM_CasePick_ClosePallet                            */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Purpose: Confirm pick                                                   */
/*                                                                         */
/* Date        Rev     Author    Purposes                                  */
/* 17-Dec-2014 1.0     Ung       SOS327467 Created                         */
/* 17-Apr-2018 1.1     Ung       WMS-3273                                  */
/*                               Add MoveQTYAlloc, MoveQTYPick             */
/*                               Add PickConfirmStatus                     */
/*                               Add ClosePalletSP                         */
/* 03-Jan-2019 1.2     Ung       WMS-3273 Fix full short                   */
/* 07-Mar-2019 1.3     Ung       WMS-8058 Fix move UCC                     */
/* 01-Apr-2024 1.4     CYU027    UWP-17449 Create Replen task              */
/* 29-Oct-2024 1.5.0   YYS027    FCR-989 add ReplenTaskSP                  */
/* 01-Oct-2024 1.6     James     WMS-26122 Stamp TaskDetail.ToLoc (james01)*/
/* 12-Nov-2024 1.7     PXL009    FCR-1125 Merged 1.4->1.6 from v0 branch   */
/* 27-Nov-2024 1.8     Dennis    FCR-1483 Remove ReplenTask                */
/***************************************************************************/

CREATE   PROC [rdt].[rdt_TM_CasePick_ClosePallet] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR(3),
   @cUserName      NVARCHAR(18),
   @cListKey       NVARCHAR(10),
   @nErrNo         INT          OUTPUT,
   @cErrMsg        NVARCHAR(20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)

   DECLARE @cClosePalletSP NVARCHAR(20)
   DECLARE @cReplenTaskSP  NVARCHAR(20)
   DECLARE @cReplenFlag    NVARCHAR(20)
   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cFromLOC       NVARCHAR( 10)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @b_Success      INT
   DECLARE @nInputKey      INT
   DECLARE @nStep          INT
   DECLARE @cSuggToLOC     NVARCHAR( 10)
   DECLARE @cInToLOC       NVARCHAR( 10)
   DECLARE @nDebugMode     INT = 0

   SELECT 
      @nInputKey = InputKey,
      @nStep = Step,
      @cSuggToLOC = V_String5,
      @cInToLOC = I_Field03   -- Input ToLoc from user
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get storer
   SELECT TOP 1 
      @cStorerKey = StorerKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
      AND UserKey = @cUserName
      AND Status = '5' -- 3=Fetch, 5=Picked, 9=Complete
   ORDER BY TaskDetailKey   

   -- Get storer config
   SET @cClosePalletSP = rdt.rdtGetConfig( @nFunc, 'ClosePalletSP', @cStorerKey)
   IF @cClosePalletSP = '0'
      SET @cClosePalletSP = ''

   -- Get storer config
   SET @cReplenFlag = rdt.rdtGetConfig( @nFunc, 'ReplenFlag', @cStorerKey)
   IF @cReplenFlag = '0'
      SET @cReplenFlag = ''

   -- Get storer config
   SET @cReplenTaskSP = rdt.rdtGetConfig( @nFunc, 'ReplenTaskSP', @cStorerKey)
   IF @cReplenTaskSP = '0'
      SET @cReplenTaskSP = ''

   SET @nTranCount = @@TRANCOUNT
   
   /***********************************************************************************************
                                          Custom close pallet
   ***********************************************************************************************/
   IF @cClosePalletSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cClosePalletSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cClosePalletSP) +
            ' @nMobile, @nFunc, @cLangCode, @cUserName, @cListKey, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile   INT,           ' +
            '@nFunc     INT,           ' +
            '@cLangCode NVARCHAR( 3),  ' +
            '@cUserName NVARCHAR(18),  ' +
            '@cListKey  NVARCHAR( 10), ' +
            '@nErrNo    INT           OUTPUT, ' +
            '@cErrMsg   NVARCHAR( 20) OUTPUT  ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @cUserName, @cListKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO REPLEN_TASK
      END
   END

   /***********************************************************************************************
                                          Standard close pallet
   ***********************************************************************************************/
   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cFromID        NVARCHAR( 18)
   DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cToID          NVARCHAR( 18)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cUCCNo         NVARCHAR( 20)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cMoveQTYAlloc  NVARCHAR( 1)
   DECLARE @cMoveQTYPick   NVARCHAR( 1)
   DECLARE @cMoveSKU       NVARCHAR( 20)
   DECLARE @cMoveLOT       NVARCHAR( 10)
   DECLARE @nQTYAlloc      INT
   DECLARE @nQTYPick       INT
   DECLARE @nQTY           INT
   DECLARE @nSystemQTY     INT
   DECLARE @nUCCQTY        INT
   DECLARE @nMoveQTY       INT
   DECLARE @nIsToLOCDiff   INT = 0
   DECLARE @nRowCount      INT = 0
   DECLARE @cUCCWithMultiSKU  NVARCHAR( 1)
   DECLARE @cUCCStatus        NVARCHAR( 10) = '5'  -- Default picked status for ucc

   SET @cUCCWithMultiSKU = rdt.RDTGetConfig( @nFunc, 'UCCWithMultiSKU', @cStorerKey)

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TM_CasePick_ClosePallet -- For rollback or commit only our own transaction

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
      SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
      SET @cMoveQTYPick = rdt.RDTGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
      SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
      IF @cPickConfirmStatus = '0'
         SET @cPickConfirmStatus = '5'
      
      -- (james02)
      IF ISNULL( @cInToLOC, '') <> '' AND ( @cInToLOC <> @cToLOC)
      BEGIN
         SET @cToLOC = @cInToLOC
         SET @nIsToLOCDiff = 1
      END
      ELSE
         SET @nIsToLOCDiff = 0
   
      -- Check move alloc, but picked
      IF @cMoveQTYAlloc = '1' AND @cPickConfirmStatus = '5'
      BEGIN
         SET @nErrNo = 51153
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IncorrectSetup
         GOTO RollBackTran
      END
         
      -- Check move picked, but not pick confirm
      IF @cMoveQTYPick = '1' AND @cPickConfirmStatus < '5'
      BEGIN
         SET @nErrNo = 51154
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IncorrectSetup
         GOTO RollBackTran
      END
   
      SELECT @cFacility = Facility FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC

      -- Full pallet pick
      IF @cPickMethod = 'FP'
         EXEC RDT.rdt_STD_EventLog
            @cActionType    = '3', -- Pick
            @cUserID        = @cUserName,
            @nMobileNo      = @nMobile,
            @nFunctionID    = @nFunc,
            @cFacility      = @cFacility,
            @cStorerKey     = @cStorerKey,
            @cLocation      = @cFromLOC,
            @cToLocation    = @cToLOC,
            @cID            = @cFromID,
            @cToID          = @cToID,
            @cTaskDetailKey = @cTaskDetailKey

      -- Partial pallet pick
      IF @cPickMethod = 'PP'
      BEGIN
         -- Move inventory
         IF EXISTS( SELECT 1 FROM rdt.rdtFCPLog WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey)
         BEGIN
            DECLARE @curUCC CURSOR
            SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT UCCNo, QTY
               FROM rdt.rdtFCPLog WITH (NOLOCK) 
               WHERE TaskDetailKey = @cTaskDetailKey
            OPEN @curUCC
            FETCH NEXT FROM @curUCC INTO @cUCCNo, @nUCCQTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SET @nRowCount = 0
               SELECT @nRowCount = COUNT( 1)
               FROM dbo.UCC WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   UCCNo = @cUCCNo
               AND   Status = @cUCCStatus
               GROUP BY UCCNO

               SET @cMoveSKU = ''
               SET @nMoveQTY = 0
               SET @cMoveLOT = ''

               -- Multi SKU UCC
               IF @cUCCWithMultiSKU = '1' AND @nRowCount > 1
               BEGIN
                  -- Loop SKU
                  DECLARE @curSKU CURSOR
                  SET @curSKU = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT SKU, QTY, LOT
                  FROM dbo.UCC (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   UCCNo = @cUCCNo
                  AND   Status = @cUCCStatus
                  ORDER BY SKU
                  OPEN @curSKU
                  FETCH NEXT FROM @curSKU INTO @cMoveSKU, @nMoveQTY, @cMoveLOT
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Calc QTY to move
                     IF @cMoveQTYAlloc = '1'
                     BEGIN
                        SET @nQTYAlloc = @nMoveQTY
                        SET @nQTYPick = 0
                     END
                     ELSE IF @cMoveQTYPick = '1'
                     BEGIN
                        SET @nQTYAlloc = 0
                        SET @nQTYPick = @nMoveQTY
                     END
                     ELSE
                     BEGIN
                        SET @nQTYAlloc = 0
                        SET @nQTYPick = 0
                     END

                     -- Move by SKU (Multi sku ucc)
                     EXEC RDT.rdt_Move
                        @nMobile     = @nMobile,
                        @cLangCode   = @cLangCode, 
                        @nErrNo      = @nErrNo  OUTPUT,
                        @cErrMsg     = @cErrMsg OUTPUT, 
                        @cSourceType = 'rdt_TM_CasePick_ClosePallet', 
                        @cStorerKey  = @cStorerKey,
                        @cFacility   = @cFacility, 
                        @cFromLOC    = @cFromLOC, 
                        @cToLOC      = @cToLOC, 
                        @cFromID     = @cFromID,
                        @cToID       = @cToID,
                        @cSKU        = @cMoveSKU, 
                        @nQTY        = @nMoveQTY,
                        @nFunc       = @nFunc, 
                        @nQTYAlloc   = @nQTYAlloc,
                        @nQTYPick    = @nQTYPick,
                        @cDropID     = @cUCCNo, 
                        @cFromLOT    = @cMoveLOT 
                     IF @nErrNo <> 0
                        GOTO RollBackTran
         
                     FETCH NEXT FROM @curSKU INTO @cMoveSKU, @nMoveQTY, @cMoveLOT
                  END
               END
               ELSE  --Single sku ucc
               BEGIN
                  IF @cMoveQTYAlloc = '1' OR @cMoveQTYPick = '1'
                  BEGIN
                     -- Calc QTY to move
                     IF @cMoveQTYAlloc = '1'
                     BEGIN
                        SET @nQTYAlloc = @nUCCQTY
                        SET @nQTYPick = 0
                     END
                     ELSE IF @cMoveQTYPick = '1'
                     BEGIN
                        SET @nQTYAlloc = 0
                        SET @nQTYPick = @nUCCQTY
                     END
                     ELSE
                     BEGIN
                        SET @nQTYAlloc = 0
                        SET @nQTYPick = 0
                     END

                     -- Move by UCC
                     EXECUTE rdt.rdt_Move
                        @nMobile     = @nMobile,
                        @cLangCode   = @cLangCode,
                        @nErrNo      = @nErrNo  OUTPUT,
                        @cErrMsg     = @cErrMsg OUTPUT,
                        @cSourceType = 'rdt_TM_CasePick_ClosePallet',
                        @cStorerKey  = @cStorerKey,
                        @cFacility   = @cFacility,
                        @cFromLOC    = @cFromLOC,
                        @cToLOC      = @cToLOC,
                        @cFromID     = @cFromID,
                        @cToID       = @cToID,
                        @cUCC        = @cUCCNo,
                        @nQTYAlloc   = @nQTYAlloc,
                        @nQTYPick    = @nQTYPick,
                        @nFunc       = @nFunc,
                        @cDropID     = @cUCCNo
                     IF @nErrNo <> 0
                        GOTO RollBackTran
                  END
               END
               
               -- Clear rdtFCPLog
               DELETE rdt.rdtFCPLog WHERE TaskDetailKey = @cTaskDetailKey AND UCCNo = @cUCCNo
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 51151
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelRPFLogFail
                  GOTO RollBackTran
               END

               -- Eventlog
               EXEC RDT.rdt_STD_EventLog
                  @cActionType    = '3', -- Pick
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

               FETCH NEXT FROM @curUCC INTO @cUCCNo, @nUCCQTY
            END
         END
         ELSE
         BEGIN
            -- Calc QTY to move
            IF @cMoveQTYAlloc = '1'
            BEGIN
               SET @nQTYAlloc = @nQTY
               SET @nQTYPick = 0
            END
            ELSE IF @cMoveQTYPick = '1'
            BEGIN
               SET @nQTYAlloc = 0
               SET @nQTYPick = @nQTY
            END
            ELSE
            BEGIN
               SET @nQTYAlloc = 0
               SET @nQTYPick = 0
            END
               
            IF @cLOT = ''
               SET @cLOT = NULL
            
            -- Move by SKU
            IF @nQTY > 0
            BEGIN
               IF (@cMoveQTYAlloc = '1' OR @cMoveQTYPick = '1') 
               BEGIN
                  EXECUTE rdt.rdt_Move
                     @nMobile     = @nMobile,
                     @cLangCode   = @cLangCode,
                     @nErrNo      = @nErrNo  OUTPUT,
                     @cErrMsg     = @cErrMsg OUTPUT,
                     @cSourceType = 'rdt_TM_CasePick_ClosePallet',
                     @cStorerKey  = @cStorerKey,
                     @cFacility   = @cFacility,
                     @cFromLOC    = @cFromLOC,
                     @cToLOC      = @cToLOC,
                     @cFromID     = @cFromID,
                     @cToID       = @cToID,
                     @cSKU        = @cSKU,
                     @nQTY        = @nQTY,
                     @nQTYAlloc   = @nQTYAlloc,
                     @nQTYPick    = @nQTYPick,
                     @cFromLOT    = @cLOT,
                     @nFunc       = @nFunc,
                     @cTaskDetailKey = @cTaskDetailKey
                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END
               
               -- Eventlog
               EXEC RDT.rdt_STD_EventLog
                  @cActionType    = '3', -- Pick
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
                  @cTaskDetailKey = @cTaskDetailKey
            END
         END
      END

      -- Unlock  suggested location
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,''      --@cFromLOC
         ,@cFromID--@cFromID
         ,@cToLOC --@cSuggestedLOC
         ,''      --@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO REPLEN_TASK

      -- Update Task
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         Status = '9', -- Closed
         -- UserPosition = @cUserPosition,
         EndTime = GETDATE(),
         EditDate = GETDATE(),
         EditWho  = @cUserName, 
         Trafficcop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 51152
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curRPTask INTO @cTaskDetailKey, @cPickMethod, @cStorerKey, @cFromLOC, @cFromID, @cToLOC, @cToID, @cSKU, @cLOT, @nQTY, @nSystemQTY, @cWaveKey
   END

   -- Create next task
   EXEC rdt.rdt_TM_CasePick_CreateNextTask @nMobile, @nFunc, @cLangCode,
      @cUserName,
      @cListKey,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

   COMMIT TRAN rdt_TM_CasePick_ClosePallet -- Only commit change made here

   GOTO REPLEN_TASK

RollBackTran:
   ROLLBACK TRAN rdt_TM_CasePick_ClosePallet -- Only rollback change made here
Fail:

REPLEN_TASK:

   GOTO Quit

Quit:
WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
   COMMIT TRAN
END

GO