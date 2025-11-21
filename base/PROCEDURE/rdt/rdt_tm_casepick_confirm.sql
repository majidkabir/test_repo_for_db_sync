SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_TM_CasePick_Confirm                             */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Confirm pick                                                */
/*    1. Split task                                                     */
/*    2. Update TaskDetail to 5-Picked                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 17-12-2014 1.0  Ung       Created                                    */
/* 17-07-2017 1.1  Ung       WMS-2439 Support GroupKey                  */
/* 04-12-2017 1.2  Ung       WMS-3273 Add PickConfirmStatus             */
/* 13-06-2018 1.3  Ung       WMS-3333 Add ConfirmSP                     */
/* 15-12-2018 1.4  TLTING01  Missing nolock                             */
/* 20-03-2019 1.5  Ung       WMS-8058 UCCNo on PickDetail.DropID        */
/* 09-09-2022 1.6  yeekung   WMS-20712 Add Toloc (yeekung01)            */
/* 28-08-2023 1.7  Ung       WMS-22681 Add Channel                      */
/************************************************************************/

CREATE   PROC [RDT].[rdt_TM_CasePick_Confirm] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cTaskDetailKey NVARCHAR( 10),
   @cDropID        NVARCHAR( 20),
   @nQTY           INT,
   @cFinalLoc      NVARCHAR( 10), --(yeekung01)
   @cReasonKey     NVARCHAR( 10),
   @cListKey       NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT,
   @nDebug         INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)
   DECLARE @cConfirmSP     NVARCHAR(20)

   -- Get storer config
   SET @cConfirmSP = rdt.rdtGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''

   SET @nTranCount = @@TRANCOUNT

   /***********************************************************************************************
                                          Custom confirm
   ***********************************************************************************************/
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cTaskDetailKey, @cDropID, @nQTY,@cFinalLoc, @cReasonKey, @cListKey, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @cUserName      NVARCHAR( 18), ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cTaskDetailKey NVARCHAR( 10), ' +
            ' @cDropID        NVARCHAR( 20), ' +
            ' @nQTY           INT,           ' +
            ' @cFinalLoc      NVARCHAR( 20), ' +
            ' @cReasonKey     NVARCHAR( 10), ' +
            ' @cListKey       NVARCHAR( 10), ' +
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT, ' +
            ' @nDebug         INT = 0               '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cTaskDetailKey, @cDropID, @nQTY,@cFinalLoc, @cReasonKey, @cListKey,
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                          Standard confirm
   ***********************************************************************************************/
   DECLARE @cNewTaskDetailKey NVARCHAR(10)
   DECLARE @cPickDetailKey NVARCHAR(10)
   DECLARE @cTaskType   NVARCHAR( 10)
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cToLOC      NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cLOT        NVARCHAR( 10)
   DECLARE @cPickMethod NVARCHAR( 10)
   DECLARE @nSystemQTY  INT
   DECLARE @bSuccess    INT
   DECLARE @cStatus     NVARCHAR( 10)
   DECLARE @nQTY_PD     INT
   DECLARE @nPickQTY    INT
   DECLARE @nNewTaskQty INT
   DECLARE @nOrgTaskQty INT
   DECLARE @nShortQTY   INT
   DECLARE @cTask       NVARCHAR(3)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''
   SET @cNewTaskDetailKey = ''
   SET @nNewTaskQTY = 0

   -- Get task info
   SET @nSystemQTY = 0
   SELECT
      @cTaskType = TaskType,
      @cFromLOC = FromLOC,
      @cFromID = FromID,
      @cToLOC = ToLOC,
      @nSystemQTY = QTY,
      @cLOT = LOT,
      @cPickMethod = PickMethod,
      @cStatus = Status
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey


   IF ISNULL(@cFinalLoc,'')=''
      SET @cFinalLoc=@cToLOC

   -- Check task already confirm/SKIP/CANCEL
   IF @cStatus IN ('5', '0', 'X')
      RETURN

   -- Storer configure
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   IF @cPickConfirmStatus NOT IN ('3', '5')
      SET @cPickConfirmStatus = '5'

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TM_CasePick_Confirm -- For rollback or commit only our own transaction

   /***********************************************************************************************

                                          Split TaskDetail, PickDetail

   ***********************************************************************************************/
   -- Split task
   IF @nQTY < @nSystemQTY AND -- not full replen
      @cPickMethod <> 'FP'    -- not full pallet
   BEGIN
      -- Calc QTY
      SET @nOrgTaskQTY = @nQTY
      IF @cReasonKey <> '' AND @nQTY < @nSystemQTY
      BEGIN
         SET @nShortQTY = @nSystemQTY - @nQTY
         SET @nNewTaskQTY = 0
      END
      ELSE
      BEGIN
         SET @nShortQTY = 0
         SET @nNewTaskQTY = @nSystemQTY - @nQTY
      END

IF @nDebug = 1
   SELECT @nOrgTaskQty '@nOrgTaskQty', @nNewTaskQty '@nNewTaskQty', @nShortQTY '@nShortQTY'

      IF @nNewTaskQTY > 0
      BEGIN
         -- Get new TaskDetailKey
         DECLARE @b_success INT
         SET @b_success = 1
         EXECUTE dbo.nspg_getkey
            'TaskDetailKey'
            , 10
            , @cNewTaskDetailKey OUTPUT
            , @b_success OUTPUT
            , @nErrNo    OUTPUT
            , @cErrMsg   OUTPUT
         IF @b_success <> 1
         BEGIN
            SET @nErrNo = 51201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
            GOTO RollBackTran
         END

         -- Insert TaskDetail
         INSERT INTO TaskDetail (
            TaskDetailKey, RefTaskKey, ListKey, Status, UserKey, ReasonKey, DropID, QTY, SystemQTY, ToLOC, ToID,
            TaskType, Storerkey, Sku, LOT, UOM, UOMQTY, FromLOC, LogicalFromLOC, FromID, LogicalToLOC, CaseID, PickMethod,
            StatusMsg, Priority, SourcePriority, HoldKey, UserPosition, UserKeyOverRide, SourceType, SourceKey,
            PickDetailKey, OrderKey, OrderLineNumber, WaveKey, Message01, Message02, Message03, LoadKey, AreaKey, GroupKey)
         SELECT
            @cNewTaskDetailKey, @cTaskDetailKey, '', '0', '', '', '', @nNewTaskQTY, @nNewTaskQTY,
            ToLOC = CASE WHEN FinalLOC = '' THEN ToLOC ELSE FinalLOC END,
            ToID  = CASE WHEN FinalID  = '' THEN ToID  ELSE FinalID  END,
            TaskType, Storerkey, Sku, LOT, UOM, UOMQTY, FromLOC, LogicalFromLOC, FromID, LogicalToLOC, CaseID, PickMethod,
            StatusMsg, Priority, SourcePriority, HoldKey, UserPosition, UserKeyOverRide, SourceType, SourceKey,
            PickDetailKey, OrderKey, OrderLineNumber, WaveKey, Message01, Message02, Message03, LoadKey, AreaKey, GroupKey
         FROM TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 51202
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskdetFail
            GOTO RollBackTran
         END
      END

      -- Loop PickDetail for original task
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey, PD.QTY
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.TaskDetailKey = @cTaskDetailKey
            AND PD.QTY > 0
            AND PD.Status = '0'
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Decide which task and what QTY to offset
         IF @nOrgTaskQty > 0
         BEGIN
            SET @cTask = 'ORG'
            SET @nPickQty = @nOrgTaskQty
            --SET @cTaskDetailKey = @cTaskDetailKey
         END
         ELSE IF @nShortQTY > 0
         BEGIN
            SET @cTask = 'SHT'
            SET @nPickQty = @nShortQty
            --SET @cTaskDetailKey = @cTaskDetailKey
         END
         ELSE IF @nNewTaskQTY > 0
         BEGIN
            SET @cTask = 'NEW'
            SET @nPickQty = @nNewTaskQty
            --SET @cTaskDetailKey = @cNewTaskDetailKey
         END

         -- PickDetail have less or exact match
         IF @nQTY_PD <= @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               TaskDetailKey = CASE WHEN @cTask = 'NEW' THEN @cNewTaskDetailKey ELSE @cTaskDetailKey END,
               Status = CASE WHEN @cTask = 'SHT' THEN '4' ELSE Status END,
               EditWho  = SUSER_SNAME(),
               EditDate = GETDATE(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 51203
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
         END

         -- PickDetail have more, need to split
         ELSE IF @nQTY_PD > @nPickQty
         BEGIN
            -- Get new PickDetailkey
            DECLARE @cNewPickDetailKey NVARCHAR( 10)
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @nErrNo            OUTPUT,
               @cErrMsg           OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 51204
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
               GOTO RollBackTran
            END

            -- Create a new PickDetail to hold the balance
            INSERT INTO dbo.PickDetail (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
               DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               PickDetailKey,
               Status,
               QTY,
               TrafficCop,
               OptimizeCop,
               Channel_ID)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
               DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               @cNewPickDetailKey,
               Status,
               @nQTY_PD - @nPickQty, -- QTY
               NULL, --TrafficCop
               '1',  --OptimizeCop
               Channel_ID
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 51205
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
               GOTO RollBackTran
            END

            -- Change original PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nPickQty,
               TaskDetailKey = CASE WHEN @cTask = 'NEW' THEN @cNewTaskDetailKey ELSE @cTaskDetailKey END,
               Status = CASE WHEN @cTask = 'SHT' THEN '4' ELSE Status END,
               EditWho  = SUSER_SNAME(),
               EditDate = GETDATE(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 51206
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END

            -- Set QTY taken
            SET @nQTY_PD = @nPickQty
         END

         -- Reduce balance
         IF @cTask = 'ORG' SET @nOrgTaskQty = @nOrgTaskQty - @nQTY_PD
         IF @cTask = 'SHT' SET @nShortQty   = @nShortQty   - @nQTY_PD
         IF @cTask = 'NEW' SET @nNewTaskQty = @nNewTaskQty - @nQTY_PD

         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
      END

IF @nDebug = 1
   SELECT @nOrgTaskQty '@nOrgTaskQty', @nNewTaskQty '@nNewTaskQty', @nShortQTY '@nShortQTY'

      -- Must fully offset
      IF @nOrgTaskQty <> 0 OR @nNewTaskQty <> 0 OR @nShortQTY <> 0
      BEGIN
         SET @nErrNo = 51207
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotFullyOffset
         GOTO RollBackTran
      END

      -- After split, set confirmed task SystemQTY = QTY
      SET @nSystemQTY = @nQTY
   END


   /***********************************************************************************************

                                          Update TaskDetail, PickDetail

   ***********************************************************************************************/
   -- Update Task
   UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
      Status = '5', -- Picked
      DropID = @cDropID,
      ToID = CASE WHEN PickMethod = 'PP' THEN @cDropID ELSE ToID END,
      QTY = @nQTY,
      SystemQTY = @nSystemQTY,
      toloc    = @cFinalLoc,
      ReasonKey = @cReasonKey,
      EndTime = GETDATE(),
      EditDate = GETDATE(),
      EditWho  = @cUserName,
      Trafficcop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 51208
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
      GOTO RollBackTran
   END

   -- Get UCC info
   DECLARE @cUCC NVARCHAR(1)
   IF EXISTS( SELECT TOP 1 1 FROM rdt.rdtFCPLog WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey)
      SET @cUCC = 'Y'

   -- Loop PickDetail
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickDetailKey
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.TaskDetailKey = @cTaskDetailKey
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status < @cPickConfirmStatus
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickDetailKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Confirm PickDetail
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         Status   = @cPickConfirmStatus,
         DropID   = CASE WHEN @cUCC = 'Y' THEN DropID ELSE @cDropID END, -- Not stamp if UCC
         EditWho  = SUSER_SNAME(),
         EditDate = GETDATE()
      WHERE PickDetailKey = @cPickDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 51209
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
         GOTO RollBackTran
      END

      FETCH NEXT FROM @curPD INTO @cPickDetailKey
   END


   /***********************************************************************************************

                                          Confirm Extended Update

   ***********************************************************************************************/
   -- Get Confirm Extended config
   DECLARE @cConfirmExtUpdSP NVARCHAR(20)
   SET @cConfirmExtUpdSP = rdt.rdtGetConfig( @nFunc, 'ConfirmExtUpdSP', @cStorerKey)
   IF @cConfirmExtUpdSP = '0'
      SET @cConfirmExtUpdSP = ''

   -- Confirm Extended update
   IF @cConfirmExtUpdSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmExtUpdSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmExtUpdSP) +
            ' @nMobile, @nFunc, @cLangCode, @cTaskdetailKey, @cNewTaskDetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile            INT,           ' +
            '@nFunc              INT,           ' +
            '@cLangCode          NVARCHAR( 3),  ' +
            '@cTaskdetailKey     NVARCHAR( 10), ' +
            '@cNewTaskDetailKey  NVARCHAR( 10), ' +
            '@nErrNo             INT OUTPUT,    ' +
            '@cErrMsg            NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @cTaskdetailKey, @cNewTaskDetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO RollBackTran
      END
   END

IF @nDebug = 1
begin
   select * from taskdetail (NOLOCK) where @cTaskDetailKey in (taskdetailkey, RefTaskKey)
   select * from pickdetail (NOLOCK) where taskdetailkey = @ctaskdetailkey or (taskdetailkey = @cNewTaskDetailKey and @cNewTaskDetailKey <> '')
   GOTO RollBackTran
end

   COMMIT TRAN rdt_TM_CasePick_Confirm -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TM_CasePick_Confirm -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO