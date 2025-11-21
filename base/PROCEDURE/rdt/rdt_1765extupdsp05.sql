SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_1765ExtUpdSP05                                  */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 29-10-2018  1.0  ChewKP   Created. WMS-4471                          */  
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1765ExtUpdSP05] (    
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
   SAVE TRAN rdt_1765ExtUpdSP05  
   
   
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
		
		SELECT @nQty = Qty 
		FROM dbo.UCC WITH (NOLOCK) 
		WHERE StorerKey = @cStorerKey
		AND UCCNo = @cDROPID
   
      -- Move by SKU  
      EXECUTE rdt.rdt_Move  
         @nMobile     = @nMobile,  
         @cLangCode   = @cLangCode,  
         @nErrNo      = @nErrNo  OUTPUT,  
         @cErrMsg     = @cErrMsg OUTPUT,  
         @cSourceType = 'rdt_1765ExtUpdSP05',  
         @cStorerKey  = @cStorerKey,  
         @cFacility   = @cFacility,  
         @cFromLOC    = @cFromLOC,  
         @cToLOC      = @cToLoc, -- Final LOC  
         @cFromID     = @cFromID,  
         @cToID       = '',  
         --@cUCC        = @cDROPID,  
         @cSKU        = @cSKU,  
         @nQTY        = @nQTY,  
         --@cFromLOT    = @cLOT  
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
         SET @nErrNo = 131001  
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
--      IF @cLoseUCC = '1'
--      BEGIN
--         UPDATE dbo.UCC
--         Set Status = '6' 
--           , Loc = @cToLoc
--           , ID  = ''
--         WHERE StorerKey = @cStorerKey
--         AND UCCNo = @cDropID
--      END
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
             SET @nErrNo = 131002
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
   ROLLBACK TRAN rdt_1765ExtUpdSP05 -- Only rollback change made here  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_1765ExtUpdSP05  
    
  
END    

GO