SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_TM_Assist_PalletPA_Cfm                       */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Confirm pick pallet                                         */
/*                                                                      */
/* Date       Ver. Author   Purposes                                    */
/* 2020-10-12 1.0  YeeKung  WMS-15379 Created                           */  
/* 2022-05-26 1.1  YeeKung  JSM-70023 Add PickLock (yeekung01)         */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_TM_Assist_PalletPA_Cfm]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cFinalLOC       NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFromLOC NVARCHAR(10)
   DECLARE @cFromID  NVARCHAR(18)
   DECLARE @nPalletCount INT 
   DECLARE @nCount INT 
   DECLARE @c_TaskDetailKey NVARCHAR(10)
   DECLARE @bSuccess INT
   DECLARE @cLogicalToLoc NVARCHAR(10)
   DECLARE @cToLOC NVARCHAR(10)

   -- Get task info
   SELECT 
      @cFromLOC = FromLOC, 
      @cFromID = FromID,
      @cToLOC=toloc,
      @cFinalLOC=finalloc
   FROM TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   
   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdtfnc_TM_Assist_PalletPA_Cfm -- For rollback or commit only our own transaction

   -- Move by ID
   EXECUTE rdt.rdt_Move
      @nMobile     = @nMobile,
      @cLangCode   = @cLangCode, 
      @nErrNo      = @nErrNo  OUTPUT,
      @cErrMsg     = @cErrMsg OUTPUT,
      @cSourceType = 'rdtfnc_TM_Assist_PalletPA_Cfm', 
      @cStorerKey  = @cStorerKey,
      @cFacility   = @cFacility, 
      @cFromLOC    = @cFromLOC, 
      @cToLOC      = @cToLOC, 
      @cFromID     = @cFromID, 
      @cToID       = NULL,  -- NULL means not changing ID
      @nFunc       = @nFunc 
   IF @nErrNo <> 0
      GOTO RollbackTran

   SELECT @bSuccess = 1    
   EXECUTE dbo.nspg_getkey    
      @KeyName       = 'TaskDetailKey',  
      @fieldlength   = 10,  
      @keystring     = @c_TaskDetailKey  OUTPUT,  
      @b_Success     = @bSuccess         OUTPUT,  
      @n_err         = @nErrNo           OUTPUT,  
      @c_errmsg      = @cErrMsg          OUTPUT    
  
   IF NOT @bSuccess = 1 OR ISNULL( @c_Taskdetailkey, '') = ''  
   BEGIN  
      SET @nErrNo = 157151  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail  
      GOTO RollBackTran  
   END 

   -- Unlock SuggestedLOC    
   EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'    
      ,'' --@cSuggFromLOC    
      ,''     
      ,@cToLOC --@cSuggToLOC    
      ,@cStorerKey    
      ,@nErrNo  OUTPUT    
      ,@cErrMsg OUTPUT    
   IF @nErrNo <> 0    
      GOTO RollBackTran  

   SELECT @cLogicalToLoc= LogicalLocation  
   FROM dbo.LOC WITH (NOLOCK)  
   WHERE LOC = @cFinalLOC  

   INSERT dbo.TASKDETAIL   --(yeekung01)
   ( TaskDetailKey, TaskType, Storerkey, Sku, UOM, UOMQty, Qty, SystemQty, Lot,  
      FromLoc, FromID, ToLoc, ToID, SourceType,SourceKey, Priority, SourcePriority,  
      Status, LogicalFromLoc, LogicalToLoc,Finalloc, PickMethod)    
   SELECT @c_TaskDetailKey, 'PA1', @cStorerkey, '', '', 0, 0, 0, '',   
      toloc, fromid, finalloc, fromid, 'rdtfnc_TM_Assist_PalletPA_Cfm',SourceKey, Priority, SourcePriority,  
      '0', LogicalToLoc, @cLogicalToLoc,finalloc, 'FP'
   FROM taskdetail (nolock)
   where taskdetailkey=@cTaskDetailKey

   IF @@ERROR <> 0    
   BEGIN  
      SET @nErrNo = 157152  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CreatePATaskFail  
      GOTO RollBackTran  
   END   

      -- Unlock SuggestedLOC    
   EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'    
      ,'' --@cSuggFromLOC    
      ,''     
      ,@cFinalLOC -- yeekung01    
      ,@cStorerKey    
      ,@nErrNo  OUTPUT    
      ,@cErrMsg OUTPUT    
   IF @nErrNo <> 0    
      GOTO RollBackTran  
   
   -- Update task
   UPDATE dbo.TaskDetail WITH (ROWLOCK)
   SET
      Status = '9',
      toid=fromid,
      UserKey = SUSER_SNAME(),
      EditWho = SUSER_SNAME(),
      EditDate = GETDATE(), 
      Trafficcop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 159901 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
      GOTO RollbackTran
   END 

   COMMIT TRAN rdtfnc_TM_Assist_PalletPA_Cfm -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdtfnc_TM_Assist_PalletPA_Cfm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO