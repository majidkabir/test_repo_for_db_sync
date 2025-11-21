SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764CfmExtUpd01                                 */
/* Purpose: 1. Split PickDetail                                         */
/*          2. Short PickDetail                                         */
/*             2.1 Remove booking (QTYReplen)                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2016-08-25   Ung       1.0   SOS372531 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764CfmExtUpd01]
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
   FROM TaskDetail WITH (NOLOCK) 
   WHERE TaskDetailKey = @cTaskdetailKey

--if suser_sname() = 'wmsgt'
--begin
--   select * from TaskDetail with (nolock) where TaskDetailKey in (@cNewTaskdetailKey, @cTaskdetailKey)
--   select 'rdt_1764CfmExtUpd01' 'here1', @nOrgTaskQty '@nOrgTaskQty', @nShortQTY '@nShortQTY', @cReasonCode '@cReasonCode'
--end

   -- FP, does not close pallet or short
   IF @cPickMethod = 'FP'
      RETURN

   -- Get suggested replen QTY and actual QTY
   SET @nQTY_RPL = 0
   SET @nQTY = 0
   SELECT 
      @nQTY_RPL = V_String15, 
      @nQTY = V_String18 
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Get new task info (close pallet, splitted task) 
   SET @nNewSystemQTY = 0
   SELECT @nNewSystemQTY = SystemQTY
   FROM TaskDetail WITH (NOLOCK) 
   WHERE TaskDetailKey = @cNewTaskdetailKey

   SET @nSystemQTY = @nOrgSystemQTY + @nNewSystemQTY
   SET @nNewTaskQty = @nNewSystemQTY 

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
--   select 'rdt_1764CfmExtUpd01' 'here2', @nQTY '@nQTY', @nSystemQTY '@nSystemQTY', @cReasonCode '@cReasonCode'

   IF @cPickMethod = 'PP' AND
      @cReasonCode = '' AND   -- Not short
      @nQTY >= @nSystemQTY    -- Don't need to split PickDetail
      RETURN


   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1764CfmExtUpd01

   -- Split or short PickDetail
   IF @nQTY < @nSystemQTY
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
               SET @nErrNo = 103051
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
               SET @nErrNo = 103052
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
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 103053
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
               GOTO RollBackTran
            END
   
            -- Change original PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nPickQty,
               TaskDetailKey = @cTaskDetailKey, 
               Status = CASE WHEN @cTask = 'SHT' THEN '4' ELSE Status END, 
               EditWho  = SUSER_SNAME(), 
               EditDate = GETDATE(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 103054
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
         
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cDropID
      END

      -- Must fully offset
      IF @nOrgTaskQty <> 0 OR @nNewTaskQty <> 0 OR @nShortQTY <> 0
      BEGIN
         /*
         if suser_sname() = 'wmsgt'
            select 'rdt_1764CfmExtUpd01' 'NotFullyOffset', @nOrgTaskQty '@nOrgTaskQty', @nNewTaskQty '@nNewTaskQty', @nShortQTY '@nShortQTY'
         */
         SET @nErrNo = 103055
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotFullyOffset
         GOTO RollBackTran
      END
   END
   
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
            SET @nErrNo = 103056
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD LLI Fail
            GOTO RollBackTran
         END
      END
   END

   COMMIT TRAN rdt_1764CfmExtUpd01 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764CfmExtUpd01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO