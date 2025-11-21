SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_1765ExtUpdSP03                                  */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: VICTORIA SECRET Replen To Logic                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 07-04-2017  1.0  ChewKP   Created. WMS-1580                          */  
/* 28-06-2017  1.1  ChewKP   UnLock PendingMoveIn                       */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1765ExtUpdSP03] (    
   @nMobile        INT,    
   @nFunc          INT,    
   @cLangCode      NVARCHAR( 3),    
   @cUserName      NVARCHAR( 15),    
   @cFacility      NVARCHAR( 5),    
   @cStorerKey     NVARCHAR( 15),    
   @cDROPID        NVARCHAR( 20),    
   @nStep          INT,  
   @cTaskDetailKey NVARCHAR(10),  
   @nQty           INT,  
   @nErrNo         INT           OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
) AS
BEGIN
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE  @cUCC               NVARCHAR(20)   
          , @cSourceKey         NVARCHAR(30)  
          , @nTrancount         INT  
        
          , @cFromLoc           NVARCHAR(10)  
          , @cToLoc             NVARCHAR(10)  
          , @b_Success          INT  
          , @cListKey           NVARCHAR(10)  
          , @cRefSourceKey      NVARCHAR(30)   
          , @cFromID            NVARCHAR(18)  
          , @cLot               NVARCHAR(10)  
          , @cSKU               NVARCHAR(20)   
          , @cModuleName        NVARCHAR(30)  
          , @cAlertMessage      NVARCHAR(255)  
          , @cLoseUCC           NVARCHAR(1)
          , @cTDTaskDetailKey   NVARCHAR(10)

   SET @nErrNo   = 0    
   SET @cErrMsg  = ''   
   SET @cSKU     = ''  
   SET @cLot     = ''  
   SET @cFromLoc = ''  
   SET @cToLoc   = ''  
   SET @cFromID  = ''  
   SET @cLoseUCC = ''

   SET @nTranCount = @@TRANCOUNT  

   BEGIN TRAN  
   SAVE TRAN rdt_1765ExtUpdSP03  
   
   
   SELECT 
            @cFromLoc = FromLoc
          , @cToLoc   = ToLoc
          , @cFromID  = FromID
          , @cSKU     = SKU
          , @cLot     = Lot   
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey 
   
   IF @nStep = 4 
   BEGIN 
		
		SELECT @cToLoc = V_String1
		FROM rdt.rdtMobRec WITH (NOLOCK) 
		WHERE Mobile = @nMobile
   
      -- Move by SKU  
      EXECUTE rdt.rdt_Move  
         @nMobile     = @nMobile,  
         @cLangCode   = @cLangCode,  
         @nErrNo      = @nErrNo  OUTPUT,  
         @cErrMsg     = @cErrMsg OUTPUT,  
         @cSourceType = 'rdt_1765ExtUpdSP03',  
         @cStorerKey  = @cStorerKey,  
         @cFacility   = @cFacility,  
         @cFromLOC    = @cFromLOC,  
         @cToLOC      = @cToLoc, -- Final LOC  
         @cFromID     = @cFromID,  
         @cToID       = '',  
         @cUCC        = @cDROPID,  
         --@nQTY        = @nQTY,  
         --@cFromLOT    = @cLOT,  
         @nFunc       = @nFunc
           
      IF @nErrNo <> 0  
         GOTO RollBackTran  
   
      UPDATE dbo.TaskDetail WITH (ROWLOCK)   
      SET   Status = '9'  
          --, Qty    = @nQty  
          , EditDate = GetDate()  
          , EditWho  = SUSER_SNAME()    
          , TrafficCop = NULL  
      WHERE TaskDetailKey = @cTaskDetailKey  
        
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 107501  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskDetFail'  
       GOTO RollBackTran  
      END  
      
      -- UNLOCK PendingMoveIn
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'      
      ,@cFromLOC 
      ,'' -- @cFromID could be changed if have transit  
      ,@cToLOC
      ,@cStorerKey
      ,@nErrNo  OUTPUT
      ,@cErrMsg OUTPUT
      ,@cSKU        = @cSKU      
      ,@nPutawayQTY = @nQTY      
      ,@cFromLOT    = @cLOT  
      --,@cUCCNo      = @cDROPID  
      
      IF @nErrNo <> 0  
      GOTO RollBackTran  
      
           
      -- Update UCC 
      IF @cLoseUCC = '1'
      BEGIN
         UPDATE dbo.UCC
         Set Status = '6' 
           , Loc = @cToLoc
           , ID  = ''
         WHERE StorerKey = @cStorerKey
         AND UCCNo = @cDropID
      END
   END
   
   IF @nStep = 5
   BEGIN
      
      DECLARE C_TaskDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT TaskDetailKey 
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND UserKey = @cUserName
      AND Status = '3' 
      ORDER BY TaskDetailKey 
      
      OPEN C_TaskDetail  
      FETCH NEXT FROM C_TaskDetail INTO  @cTDTaskDetailKey
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         

         UPDATE dbo.TaskDetail WITH (ROWLOCK) 
         SET Status = '0'
            ,UserKey = ''
            ,EditDate = GetDate() 
            ,EditWho  = SUSER_SNAME()    
            ,TrafficCop = NULL  
         WHERE TaskDetailKey = @cTDTaskDetailKey  
         
         IF @@ERROR <> 0 
         BEGIN 
             SET @nErrNo = 107502
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskDetFail'  
             GOTO RollBackTran  
         END
         
         FETCH NEXT FROM C_TaskDetail INTO  @cTDTaskDetailKey
         
      END
      CLOSE C_TaskDetail  
      DEALLOCATE C_TaskDetail 
      
      
      
   END
   GOTO QUIT   
     
RollBackTran:  
   ROLLBACK TRAN rdt_1765ExtUpdSP03 -- Only rollback change made here  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_1765ExtUpdSP03  
    
  
END    

GO