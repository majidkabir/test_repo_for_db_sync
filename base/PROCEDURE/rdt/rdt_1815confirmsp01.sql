SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_1815ConfirmSP01                                       */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 2020-08-10   YeeKung   1.0   WMS-14344 Created                             */   
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1815ConfirmSP01]  
   @nMobile          INT,                  
   @nFunc            INT,                  
   @cLangCode        NVARCHAR( 3),         
   @nStep            INT,                  
   @nInputKey        INT,                  
   @cStorerKey       NVARCHAR( 15),        
   @cFacility        NVARCHAR( 5),         
   @cTaskDetailKey   NVARCHAR( 10),        
   @cFromLOC         NVARCHAR( 10),        
   @cFromID          NVARCHAR( 18),        
   @cSuggLOC         NVARCHAR( 10),        
   @cPickAndDropLOC  NVARCHAR( 10),        
   @cToLOC           NVARCHAR( 10),        
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  @cToID       NVARCHAR( 18),
            @bSuccess    INT,
            @c_TaskDetailKey NVARCHAR( 20)

   DECLARE  @c_LOCAisle NVARCHAR(20),
            @c_ToLoc nvarchar(20),
            @cToLogicalLocation   NVARCHAR( 10),  
            @cLogicalLocation     NVARCHAR( 10)

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get LoseID
   DECLARE @cLoseID NVARCHAR(1)
   SELECT @cLoseID = @cLoseID FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLOC
   IF @cLoseID = '1'
      SET @cToID = ''
   ELSE
      SET @cToID = @cFromID

   -- Handling transaction  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_1815ConfirmSP01 -- For rollback or commit only our own transaction  

   -- Execute move process
   EXECUTE rdt.rdt_Move
      @nMobile     = @nMobile,
      @cLangCode   = @cLangCode, 
      @nErrNo      = @nErrNo  OUTPUT,
      @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
      @cSourceType = 'rdt_1815ConfirmSP01', 
      @cStorerKey  = @cStorerKey,
      @cFacility   = @cFacility, 
      @cFromLOC    = @cFromLOC, 
      @cToLOC      = @cToLOC, 
      @cFromID     = @cFromID, 
      @cToID       = NULL,  -- NULL means not changing ID
      @nFunc       = @nFunc
   IF @nErrNo <> 0
      GOTO RollBackTran

   IF @cPickAndDropLOC <> ''
      SET @cSuggLOC = @cPickAndDropLOC

   -- Unlock SuggestedLOC
   EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK' 
      ,''        --@cLOC      
      ,@cToID    --@cID       
      ,@cSuggLOC --@cSuggLOC 
      ,''        --@cStorerKey
      ,@nErrNo  OUTPUT
      ,@cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

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

      -- Get from LOC info  
      SELECT   
         @c_ToLoc = finalloc    
      FROM taskdetail WITH (NOLOCK)   
      where taskdetailkey=@cTaskDetailKey  

      DECLARE @careakey NVARCHAR (20),
              @cputawayzone nvarchar(20)

      SELECT @cToLogicalLocation = LogicalLocation , @cputawayzone=putawayzone
      FROM dbo.LOC WITH (NOLOCK)  
      WHERE LOC = @cSuggLoc  

      SELECT @careakey=AREAKEY
      from areadetail A (NOLOCK) 
      where putawayzone=@cputawayzone
  
      SELECT @cLogicalLocation = LogicalLocation  
      FROM dbo.LOC WITH (NOLOCK)  
      WHERE LOC = @cSuggLoc  

      IF ISNULL(@c_ToLoc,'')<>''
      BEGIN

         INSERT dbo.TASKDETAIL   --(yeekung01)
         ( TaskDetailKey, TaskType, Storerkey, Sku, UOM, UOMQty, Qty, SystemQty, Lot,  
            FromLoc, FromID, ToLoc, ToID, SourceType,SourceKey, Priority, SourcePriority,  
            Status, LogicalFromLoc, LogicalToLoc,Finalloc, PickMethod,areakey)    
         SELECT @c_TaskDetailKey, 'PA1', @cStorerkey, '', '', 0, 0, 0, '',   
            toloc, toid, Finalloc, toid, 'rdt_1815ConfirmSP01',SourceKey, Priority, SourcePriority,  
            '0', @cLogicalLocation, @cToLogicalLocation,Finalloc, 'FP',@careakey
         FROM taskdetail (nolock)
         where taskdetailkey=@cTaskDetailKey
              
         IF @@ERROR <> 0    
         BEGIN  
            SET @nErrNo = 157152  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CreatePATaskFail  
            GOTO RollBackTran  
         END   
      END
      
      -- Update task
      UPDATE dbo.TaskDetail SET
         Status = '9',
         ToLOC = @cSuggLOC,
         UserKey = SUSER_SNAME(),
         EditWho = SUSER_SNAME(),
         EditDate = GETDATE(), 
         Trafficcop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 157153
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
         GOTO RollBackTran
      END      
     
  
   COMMIT TRAN rdt_1815ConfirmSP01 -- Only commit change made here  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_1815ConfirmSP01 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO