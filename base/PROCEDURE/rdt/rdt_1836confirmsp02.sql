SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/    
/* Store procedure: rdt_1836ConfirmSP02                                       */    
/* Copyright      : LF Logistics                                              */    
/*                                                                            */    
/* Date         Author    Ver.  Purposes                                      */    
/* 2020-08-10   YeeKung   1.0   WMS-14059 Created                             */    
/******************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1836ConfirmSP02]    
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
   DECLARE @cCaseID  NVARCHAR(20)    
   DECLARE @cUserID  NVARCHAR( 20)  
   DECLARE @cSKU     NVARCHAR( 20)    
   DECLARE @nQTY     INT   
    
   -- Get task info    
   SELECT     
      @cFromLOC = FromLOC,   
      @cSKU     = sku,   
      @nQTY     = Qty,   
      @cFromID = FromID  
      --@cCaseID = CaseID    
   FROM TaskDetail WITH (NOLOCK)    
   WHERE TaskDetailKey = @cTaskDetailKey    
    
   SELECT @cUserID  = username,  
          @cFacility = FACILITY  
   FROM rdt.RDTMOBREC WITH (NOLOCK)     
   WHERE Mobile = @nMobile   
       
   ---- Get original task    
   --DECLARE @cRPFTaskKey NVARCHAR(10) = ''    
   --SELECT TOP 1     
   --   @cRPFTaskKey = TaskDetailKey    
   --FROM TaskDetail WITH (NOLOCK)    
   --WHERE StorerKey = @cStorerKey    
   --   AND TaskType = 'RPF'    
   --   AND Status = '9'    
   --   AND CaseID = @cCaseID    
   --ORDER BY TaskDetailKey DESC    
       
   -- Handling transaction    
   DECLARE @nTranCount INT    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
   SAVE TRAN rdt_1836ConfirmSP02 -- For rollback or commit only our own transaction    
    
   -- Move by UCC    
   EXECUTE rdt.rdt_Move    
      @nMobile     = @nMobile,    
      @cLangCode   = @cLangCode,     
      @nErrNo      = @nErrNo  OUTPUT,    
      @cErrMsg     = @cErrMsg OUTPUT,    
      @cSourceType = 'rdt_1836ConfirmSP02',     
      @cStorerKey  = @cStorerKey,    
      @cFacility   = @cFacility,     
      @cFromLOC    = @cFromLOC,     
      @cFromID     = @cFromID,      
      @cToLOC      = @cFinalLoc,     
      @cUCC        = @cCaseID,     
      @cToID       = NULL,  -- NULL means not changing ID    
      @nFunc       = @nFunc     
   IF @nErrNo <> 0    
      GOTO RollbackTran    
    
  
   EXEC rdt.rdt_Putaway_PendingMoveIn    
   @cUserName        = @cUserID,     
   @cType            = 'UNLOCK'      
   ,@cFromLoc        = @cFromLoc      
   ,@cFromID         = @cFromID      
   ,@cSuggestedLOC   = @cFinalLoc      
   ,@cStorerKey      = @cStorerKey      
   ,@nErrNo          = @nErrNo    OUTPUT      
   ,@cErrMsg         = @cErrMsg OUTPUT      
   ,@cSKU            = @cSKU      
   ,@nPutawayQTY     = @nQTY      
   ,@nFunc           = 1836      
   IF @nErrNo <> 0    
      GOTO RollbackTran    
       
   -- Update task    
   UPDATE dbo.TaskDetail SET    
      Status = '9',    
      ToLOC = @cFinalLoc,    
      UserKey = SUSER_SNAME(),    
      EditWho = SUSER_SNAME(),    
      EditDate = GETDATE(),     
      Trafficcop = NULL    
   WHERE TaskDetailKey = @cTaskDetailKey    
   IF @@ERROR <> 0    
   BEGIN    
      SET @nErrNo = 145051    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail    
      GOTO RollbackTran    
   END    
    
   COMMIT TRAN rdt_1836ConfirmSP02 -- Only commit change made here    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_1836ConfirmSP02 -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END      

GO