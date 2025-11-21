SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1764CfmExtUpd05                                    */
/* Purpose: 1. short Split PickDetail                                      */
/* Customer: Levis                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Author    Ver.   Purposes                                  */
/* 2024-12-05    JCH507    1.0.0  FCR-1157 for Levis                       */
/*                               (Copy from 1764CfmExtUp01)                */
/* 2025-01-07    JCH507    1.0.1  FCR-1157 Handle full ucc short since     */
/*                               systemQty <> PD Qty                       */
/* 2025-02-27    JCH507    1.1.0  FCR-1157 Unlock toLoc when full short    */
/***************************************************************************/

CREATE   PROCEDURE rdt.rdt_1764CfmExtUpd05
    @nMobile            INT 
   ,@nFunc              INT 
   ,@cLangCode          NVARCHAR( 3) 
   ,@cTaskdetailKey     NVARCHAR( 10) 
   ,@cNewTaskdetailKey  NVARCHAR( 10) 
   ,@nErrNo             INT           OUTPUT 
   ,@cErrMsg            NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bDebugFlag     BINARY
   DECLARE @cPickDetailKey NVARCHAR(10)
   DECLARE @cDropID        NVARCHAR(20)
   DECLARE @bSuccess       INT
   DECLARE @nQTY           INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_RPL       INT
   DECLARE @nNewTaskQty    INT
   DECLARE @nOrgTaskQty    INT
   DECLARE @nSystemQTY     INT
   DECLARE @nOrgSystemQTY  INT
   DECLARE @nNewSystemQTY  INT
   DECLARE @nPickQTY       INT
   DECLARE @nShortQTY      INT
   DECLARE @nQTYReplen     INT
   DECLARE @cReasonCode    NVARCHAR(10)
   DECLARE @cTask          NVARCHAR(3)
   DECLARE @cPickMethod    NVARCHAR(10)
   DECLARE @cLOT           NVARCHAR(10)
   DECLARE @cFromLOC       NVARCHAR(10)
   DECLARE @cFromID        NVARCHAR(18)

   -- All logics are copied from 1764CfmExtUpd01, update the rdtmobrec retrieving logic.  By JCH507

   -- Get orginal task info
   SELECT 
      @cPickMethod = PickMethod, 
      @cReasonCode = ReasonKey, 
      @cLOT = LOT, 
      @cFromLOC = FromLOC, 
      @cFromID = FromID, 
      @nOrgSystemQTY = SystemQTY, 
      @nOrgTaskQty = CASE WHEN QTY < SystemQTY THEN QTY ELSE SystemQTY END, -- QTY for PickDetail
      @nShortQTY   = CASE WHEN QTY < SystemQTY THEN SystemQTY - QTY ELSE 0 END
   FROM dbo.TaskDetail WITH (NOLOCK) 
   WHERE TaskDetailKey = @cTaskdetailKey

   IF @bDebugFlag = 1
      SELECT @nOrgSystemQTY AS nOrgSystemQTY, @nOrgTaskQty AS OrgTaskQty, @nShortQTY AS ShortQTY, @cPickMethod AS PickMethod,
               @cReasonCode AS ReasonCode, @cLOT AS LOT, @cFromLOC AS FromLOC, @cFromID AS FromID

   -- FP, does not close pallet or short
   IF @cPickMethod = 'FP'
      RETURN

   -- Get suggested replen QTY and actual QTY
   SET @nQTY_RPL = 0
   SET @nQTY = 0
   SELECT 
      --@nQTY_RPL = V_String15, -- old logic
      --@nQTY = V_String18 -- old logic
      @nQTY_RPL = V_Integer1, -- V1.0 JCH507
      @nQTY = V_Integer4 -- V1.0 JCH507 
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @bDebugFlag = 1
      SELECT @nQTY_RPL AS nQTY_RPL, @nQTY AS nQTY

   -- Get new task info (close pallet, splitted task) 
   SET @nNewSystemQTY = 0
   SELECT @nNewSystemQTY = SystemQTY
   FROM dbo.TaskDetail WITH (NOLOCK) 
   WHERE TaskDetailKey = @cNewTaskdetailKey

   SET @nSystemQTY = @nOrgSystemQTY + @nNewSystemQTY
   SET @nNewTaskQty = @nNewSystemQTY

   IF @bDebugFlag = 1
      SELECT @nSystemQTY AS SystemQTY, @nNewSystemQTY AS NewSystemQTY, @nNewTaskQty AS NewTaskQty 

   /*
   PP, does:
      Close pallet without balance (TaskDetail not splitted)
      Close pallet with balance (TaskDetail splitted in parent)
      Short (TaskDetail not split)

   SuggQTY  SystemQTY   QTYReplen   ActQTY   User action    Program action
   10       5           5           10       Close pallet   Return
   
   10       5           5           5        Close pallet   Return
   10       5           5           5        Short          Reduce booking
                                             
   10       5           5           7        Close pallet   Return
   10       5           5           7        Short          Reduce booking
                                             
   10       5           5           4        Close pallet   Split PickDetail
   10       5           5           4        Short          Split & short PickDetail, reduce booking
   */ 

--if suser_sname() = 'wmsgt'
--   select 'rdt_1764CfmExtUpd05' 'here2', @nQTY '@nQTY', @nSystemQTY '@nSystemQTY', @cReasonCode '@cReasonCode'

   IF @cPickMethod = 'PP' AND
      @cReasonCode = '' AND   -- Not short
      @nQTY >= @nSystemQTY    -- Don't need to split PickDetail
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'Return directly'
      RETURN
   END


   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1764CfmExtUpd05

   -- Split or short PickDetail
   IF @nQTY < @nSystemQTY
   BEGIN
      --V1.0.1 start --fullshort
      IF @nQTY = 0 AND @nShortQTY > 0 AND @nShortQty = @nSystemQTY
      BEGIN
         IF @bDebugFlag = 1
            SELECT 'Full UCC short'
         BEGIN TRY
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               TaskDetailKey = @cTaskDetailKey, 
               Status =  '4', 
               EditWho  = SUSER_SNAME(), 
               EditDate = GETDATE(),
               Trafficcop = NULL
            WHERE TaskDetailKey = @cTaskDetailKey
         END TRY
         BEGIN CATCH
            SET @nErrNo = 231257
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END CATCH

         --V1.1.0 Start
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,''      --@cFromLOC
            ,''      --@cFromID
            ,''      --@cSuggestedLOC
            ,''      --@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,''      -- @cSKU
            , 0      -- @nPutawayQty
            , ''     -- @cUCCNo
            , ''     -- @cFromLOT
            , ''     -- @cToID
            , @cTaskDetailKey -- @cTaskDetailKey

         IF @nErrNo <> 0
            GOTO RollbackTran
         --V1.1.0 End
         SET @nShortQTY = 0
      END --Qty=0 --V1.0.1 end
      ELSE
      BEGIN
         -- Loop PickDetail for original task
         DECLARE @curPD CURSOR
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickDetailKey, PD.QTY, PD.DropID
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.TaskDetailKey = @cTaskDetailKey
               AND PD.QTY > 0
               AND PD.Status = '0'
      
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cDropID
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Decide which task and what QTY to offset
            IF @nOrgTaskQty > 0
            BEGIN
               SET @cTask = 'ORG'
               SET @nPickQty = @nOrgTaskQty
               SET @cTaskDetailKey = @cTaskDetailKey
            END
            ELSE IF @nShortQTY > 0
            BEGIN
               SET @cTask = 'SHT'
               SET @nPickQty = @nShortQty
               SET @cTaskDetailKey = @cTaskDetailKey
            END
            ELSE IF @nNewTaskQTY > 0
            BEGIN
               SET @cTask = 'NEW'
               SET @nPickQty = @nNewTaskQty
               SET @cTaskDetailKey = @cNewTaskDetailKey
            END
      
            -- PickDetail have less or exact match
            IF @nQTY_PD <= @nPickQty
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  TaskDetailKey = @cTaskDetailKey, 
                  Status = CASE WHEN @cTask = 'SHT' THEN '4' ELSE Status END, 
                  EditWho  = SUSER_SNAME(), 
                  EditDate = GETDATE(),
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 231251
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
                  SET @nErrNo = 231252
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
                  GOTO RollBackTran
               END
      
               -- Create a new PickDetail to hold the balance
               BEGIN TRY
                  INSERT INTO dbo.PickDetail (
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
                     DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
                     PickDetailKey,
                     Status, 
                     QTY,
                     TrafficCop,
                     OptimizeCop)
                  SELECT
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
                     DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
                     @cNewPickDetailKey,
                     '0', 
                     @nQTY_PD - @nPickQty, -- QTY
                     NULL, --TrafficCop
                     '1'   --OptimizeCop
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE PickDetailKey = @cPickDetailKey
               END TRY
               BEGIN CATCH
                  SET @nErrNo = 231253
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
                  GOTO RollBackTran
               END CATCH
      
               -- Change original PickDetail with exact QTY (with TrafficCop)
               BEGIN TRY
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     QTY = @nPickQty,
                     TaskDetailKey = @cTaskDetailKey, 
                     Status = CASE WHEN @cTask = 'SHT' THEN '4' ELSE Status END, 
                     EditWho  = SUSER_SNAME(), 
                     EditDate = GETDATE(),
                     Trafficcop = NULL
                  WHERE PickDetailKey = @cPickDetailKey
               END TRY
               BEGIN CATCH
                  SET @nErrNo = 231254
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END CATCH
               
               -- Set QTY taken
               SET @nQTY_PD = @nPickQty
            END
      
            -- Reduce balance
            IF @cTask = 'ORG' SET @nOrgTaskQty = @nOrgTaskQty - @nQTY_PD
            IF @cTask = 'SHT' SET @nShortQty   = @nShortQty   - @nQTY_PD
            IF @cTask = 'NEW' SET @nNewTaskQty = @nNewTaskQty - @nQTY_PD
            
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cDropID
         END
      END -- QtY<>0

      -- Must fully offset
      IF @nOrgTaskQty <> 0 OR @nNewTaskQty <> 0 OR @nShortQTY <> 0
      BEGIN
         /*
         if suser_sname() = 'wmsgt'
            select 'rdt_1764CfmExtUpd05' 'NotFullyOffset', @nOrgTaskQty '@nOrgTaskQty', @nNewTaskQty '@nNewTaskQty', @nShortQTY '@nShortQTY'
         */
         SET @nErrNo = 231255
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotFullyOffset
         GOTO RollBackTran
      END
   END --Qty<SystemQty
   
   --V1.0.1 the fromLoc inventory record not have QtyReplen value start
   /*
   -- Reduce booking (when short)
   IF @cReasonCode <> '' -- Short
   BEGIN
      -- Get booking QTY
      SET @nQTYReplen = @nQTY_RPL - @nSystemQTY
      
      -- Short replen
      IF @nQTY > @nSystemQTY
         SET @nQTYReplen = @nQTYReplen - (@nQTY - @nSystemQTY)

      --if suser_sname() = 'wmsgt'
      --   select @nQTYReplen '@nQTYReplen'
   
      -- Reduce booking
      IF @nQTYReplen > 0
      BEGIN
         UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET
            QTYReplen = CASE WHEN (QTYReplen - @nQTYReplen) >= 0 THEN (QTYReplen - @nQTYReplen) ELSE 0 END
         WHERE LOT = @cLOT
            AND LOC = @cFromLOC
            AND ID = @cFromID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 231256
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD LLI Fail
            GOTO RollBackTran
         END
      END
   END */
   --V1.0.1 the fromLoc inventory record not have QtyReplen value end

   COMMIT TRAN rdt_1764CfmExtUpd05 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764CfmExtUpd05 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO