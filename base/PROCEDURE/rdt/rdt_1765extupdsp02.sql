SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_1765ExtUpdSP02                                  */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: CARTERSZ Replen To Logic                                    */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 23-03-2016  1.0  ChewKP   Created. SOS#366906                        */  
/* 06-03-2018  1.1  Ung      WMS-3935 Support OverrideLOC               */
/* 11-07-2018  1.2  Ung      WMS-3935 Fix booking unlock by RPF task    */
/* 24-06-2019  1.3  Ung      WMS-8496 Fix booking unlock by RPT task    */
/* 01-08-2019  1.4  James    WMS-9982 Add stdeventlog (james01)         */
/* 15-06-2021  1.5  James    WMS-17060 Add insert TransmitLog2 (james02)*/
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1765ExtUpdSP02] (    
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
          , @cCaseID            NVARCHAR(20)
          , @cPriority          NVARCHAR(10)
          , @cWaveKey           NVARCHAR(10)

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
   SAVE TRAN rdt_1765ExtUpdSP02  
   
   
   SELECT 
            @cFromLoc = FromLoc
          , @cToLoc   = ToLoc
          , @cFromID  = FromID
          , @cSKU     = SKU
          , @cLot     = Lot 
          , @cCaseID  = CaseID
          , @cPriority = Priority
          , @cWaveKey = WaveKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey 
   
   IF @nStep = 4 
   BEGIN 
      -- OverrideLOC
      SELECT @cToLoc = V_String1 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

      SELECT @cLoseUCC = LoseUCC 
      FROM dbo.Loc WITH (NOLOCK)
      WHERE Loc = @cToLoc 
   
      -- Move by SKU  
      EXECUTE rdt.rdt_Move  
         @nMobile     = @nMobile,  
         @cLangCode   = @cLangCode,  
         @nErrNo      = @nErrNo  OUTPUT,  
         @cErrMsg     = @cErrMsg OUTPUT,  
         @cSourceType = 'rdt_1765ExtUpdSP02',  
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
          , ToLOC = @cToLOC
          , EditDate = GetDate()  
          , EditWho  = SUSER_SNAME()    
          , TrafficCop = NULL  
      WHERE TaskDetailKey = @cTaskDetailKey  
        
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 98301  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskDetFail'  
         GOTO RollBackTran  
      END  
   
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
      
      -- Get RPF task
      DECLARE @cRPFTaskKey NVARCHAR(10)
      SELECT @cRPFTaskKey = TaskDetailKey
      FROM TaskDetail WITH (NOLOCK)
      WHERE TaskType = 'RPF'
         AND StorerKey = @cStorerKey
         AND CaseID = @cCaseID
         AND Status = '9'

      -- Unlock by RPF task
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,'' --FromLOC
         ,'' --FromID
         ,'' --cSuggLOC
         ,'' --Storer
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cTaskDetailKey = @cRPFTaskKey

      -- Unlock by RPT task
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,'' --FromLOC
         ,'' --FromID
         ,'' --cSuggLOC
         ,'' --Storer
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cTaskDetailKey = @cTaskDetailKey

      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE LISTNAME = 'RPTFNLLOC'
                  AND   Code = @cFacility
                  AND   Storerkey = @cStorerKey
                  AND   Long = @cToLoc)
      BEGIN
         -- Insert transmitlog2 here
         EXECUTE ispGenTransmitLog2 
            @c_TableName      = 'WSREPLAGV', 
            @c_Key1           = @cTaskDetailKey, 
            @c_Key2           = '', 
            @c_Key3           = @cStorerkey, 
            @c_TransmitBatch  = '', 
            @b_Success        = @b_Success   OUTPUT,    
            @n_err            = @nErrNo      OUTPUT,    
            @c_errmsg         = @cErrMsg     OUTPUT    

         IF @b_Success <> 1    
         BEGIN 
             SET @nErrNo = 98303
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins TL2 Fail'  
             GOTO RollBackTran  
         END
      END
      
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '5',
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @cLocation   = @cFromLOC,
         @cID         = @cFromID,
         @cSKU        = @cSKU,
         @nQty        = @nQty,
         @cToLocation = @cToLOC,
         @nStep       = @nStep,
         @cDROPID     = @cDROPID,
         @cRemark     = @cPriority,
         @cWaveKey    = @cWaveKey
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
             SET @nErrNo = 98302
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
   ROLLBACK TRAN rdt_1765ExtUpdSP02 -- Only rollback change made here  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_1765ExtUpdSP02  
    
  
END    

GO