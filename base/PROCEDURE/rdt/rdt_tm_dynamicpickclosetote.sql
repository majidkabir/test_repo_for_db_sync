SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdt_TM_DynamicPickCloseTote                              */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#315989 - Jack Will TM Dynamic Picking close tote             */
/*                     - Called By rdtfnc_TM_DynamicPick                     */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2014-08-15 1.0  James    Created                                          */
/* 2014-12-18 1.1  James    SOS323699 - Bug fix on qty insert into           */
/*                                      taskdetail (james01)                 */
/* 2015-06-23 1.2  James    SOS345188 - Fix 0 qty in taskdetail (james02)    */
/*****************************************************************************/

CREATE PROC [RDT].[rdt_TM_DynamicPickCloseTote](
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cDropID             NVARCHAR( 20),
   @cToToteNo           NVARCHAR( 20),
   @cLoadkey            NVARCHAR( 10),
   @cTaskStorer         NVARCHAR( 15),
   @cSKU                NVARCHAR( 20),
   @cFromLoc            NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cLot                NVARCHAR( 10),
   @cTaskdetailkey      NVARCHAR( 10),
   @nPrevTotQty         INT,
   @nBoxQty             INT,
   @nTaskQty            INT,
   @cPickType           NVARCHAR( 10),
   @cNewTaskDetailKey   NVARCHAR( 10)  OUTPUT,
   @nTotPickQty         INT            OUTPUT,
   @nErrNo              INT            OUTPUT,
   @cErrMsg             NVARCHAR( 20)  OUTPUT
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @nTranCount          INT,
            @nRemainQty          INT,
            @b_success           INT,
            @cTaskDetailKeyPK    NVARCHAR( 10),
            @cExtendedUpdateSP   NVARCHAR( 20),
            @cSQL                NVARCHAR( MAX),
            @cSQLParam           NVARCHAR( MAX),
            @cUserName           NVARCHAR( 15),
            @cFacility           NVARCHAR( 5),
            @cPickMethod         NVARCHAR( 10),
            @cRTaskDetailkey     NVARCHAR( 10),
            @cDefaultToLoc       NVARCHAR( 10),
            @nQtyMoved           INT,
            @cPrevToteQty        INT   -- (james01)

   -- Change tote we need to split task detail
   -- Change the open pickdetail to new taskdetailkey

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN Dy_CloseTote

   SELECT @cUserName = UserName, @cFacility = Facility FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   SELECT @nTaskQTY = Qty FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskdetailkey

   SET @nRemainQty =  @nTaskQTY - @nBoxQty

   EXECUTE dbo.nspg_getkey
   'TaskDetailKey'
   , 10
   , @cTaskDetailKeyPK OUTPUT
   , @b_success         OUTPUT
   , @nErrNo            OUTPUT
   , @cErrMsg           OUTPUT

   IF NOT @b_success = 1
   BEGIN
      SET @nErrNo = @nErrNo
      SET @cErrMsg = @cErrMsg
      GOTO RollBackTran
   END

   INSERT INTO dbo.TaskDetail
     (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
     ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
     ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
     ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty)
   SELECT  @cTaskDetailKeyPK,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,@nBoxQty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc  -- (james01)
     ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
     ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
     ,Message01,Message02,'PREVFULL',@cTaskDetailKey,LoadKey,AreaKey, DropID, SystemQty-@nPrevTotQty--SystemQty-@nBoxQty
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE Taskdetailkey = @cTaskDetailKey
   AND Storerkey = @cTaskStorer

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 50157
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsTaskFailed'
      GOTO RollBackTran
   END

   SET @cNewTaskDetailKey = @cTaskDetailKeyPK

   UPDATE dbo.PickDetail WITH (ROWLOCK) SET
      TaskDetailKey = @cTaskDetailKeyPK,
      TrafficCop = NULL
   WHERE StorerKey = @cTaskStorer
   AND   TaskDetailKey = @cTaskDetailKey
   AND   [Status] = '0'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 70048
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
      GOTO RollBackTran
   END

   SELECT TOP 1 @cDefaultToLoc = ISNULL(RTRIM(CL.Short),'')
   FROM  dbo.Codelkup CL WITH (NOLOCK)
   WHERE CL.Listname = 'WCSROUTE'
   AND   CL.Code     = @cPickType

   EXEC rdt.rdt_TMDynamicPick_MoveCase
      @cDropID             =@cDropID,
      @cTaskdetailkey      =@cTaskdetailkey,
      @cUserName           =@cUserName,
      @cToLoc              =@cDefaultToLoc,
      @nErrNo              =@nErrNo  OUTPUT,
      @cErrMsg             =@cErrMsg OUTPUT

   IF @nErrno <> 0
   BEGIN
      SET @nErrNo = @nErrNo
      SET @cErrMsg = @cErrMsg
      GOTO RollBackTran
   END

--   SET @nQtyMoved = 0
--   SELECT @nQtyMoved = ISNULL(SUM(QTY), 0)
--   FROM dbo.UCC WITH (NOLOCK)
--   WHERE StorerKey = @cTaskStorer
--      AND SourceKey = @cTaskdetailkey

   -- (james01)
   SELECT @cPrevToteQty = ISNULL( SUM( QTY), 0)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE SourceKey = @cTaskdetailkey
   AND   Status = '0'
   AND   UCCNo <> @cToToteNo

   UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
      Qty = @cPrevToteQty,
      Trafficcop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 50157
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsTaskFailed'
      GOTO RollBackTran
   END

   SET @nTotPickQty = 0

   -- Confirm Current Task
   UPDATE dbo.TaskDetail WITH (ROWLOCK)
       SET Status = '9' ,
       EndTime = GETDATE(),
       EditDate = GETDATE(),
       EditWho = @cUserName,
       TrafficCop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 50160
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Task Fail'
      GOTO RollBackTran
   END

   SELECT @cPickMethod = PickMethod
   From dbo.TaskDetail (NOLOCK)
   WHERE TaskDetailkey = @cTaskDetailKey

   -- Look for other task that currently locked by user
   DECLARE curDropID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TaskDetailkey
   FROM dbo.TaskDetail TD WITH (NOLOCK)
   INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
   WHERE TD.Loadkey = @cLoadkey
   AND TD.PickMethod = @cPickMethod
   AND TD.Status < '9'
   AND TD.UserKey = @cUserName
   AND TD.DropID = @cDropID

   OPEN curDropID
   FETCH NEXT FROM curDropID INTO @cRTaskDetailkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE dbo.TaskDetail WITH (ROWLOCK)
         SET Message03 = 'PREVFULL',
             Trafficcop = NULL,
             DropID = '' -- Tote Close, should set the dropid to blank (shong02)
      WHERE TaskDetailkey = @cRTaskDetailkey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 70048
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
         GOTO RollBackTran
      END

      FETCH NEXT FROM curDropID INTO @cRTaskDetailkey
   END
   CLOSE curDropID
   DEALLOCATE curDropID

   UPDATE dbo.UCC WITH (ROWLOCK) SET
      [Status] = '4',
      TrafficCop = NULL
   WHERE SourceKey = @cTaskdetailkey
   AND   Status = '0'
   AND   UCCNo <> @cToToteNo

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 70048
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
      GOTO RollBackTran
   END

   GOTO Quit

   ROLLBACKTRAN:
      ROLLBACK TRAN Dy_CloseTote

   QUIT:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN Dy_CloseTote

GO