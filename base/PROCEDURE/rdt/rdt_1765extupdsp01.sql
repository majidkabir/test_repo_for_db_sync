SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_1765ExtUpdSP01                                  */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: ANF Replen To Logic                                         */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2014-06-19  1.0  ChewKP   Created                                    */  
/* 2014-09-16  1.1  Chee     Unlock PendingMoveIn (Chee01)              */  
/* 2016-10-18  1.2  ChewKP   Remove TraceInfo                           */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1765ExtUpdSP01] (    
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
          , @cSourceLineNumber  NVARCHAR(5)   
          , @cFromLoc           NVARCHAR(10)  
          , @cToLoc             NVARCHAR(10)  
          , @b_Success          INT  
          , @cListKey           NVARCHAR(10)  
          , @cRefSourceKey      NVARCHAR(30)   
          , @cTransferKey       NVARCHAR(10)  
          , @cTrasferLineNumber NVARCHAR(5)  
          , @cFromID            NVARCHAR(18)  
          , @cLot               NVARCHAR(10)  
          , @cSKU               NVARCHAR(20)   
          , @cModuleName        NVARCHAR(30)  
          , @cAlertMessage      NVARCHAR(255)  
          , @cLoseUCC           NVARCHAR(1)

   SET @nErrNo   = 0    
   SET @cErrMsg  = ''   
   SET @cSKU     = ''  
   SET @cLot     = ''  
   SET @cFromLoc = ''  
   SET @cToLoc   = ''  
   SET @cFromID  = ''  
   SET @cTransferKey = ''   
   SET @cTrasferLineNumber = ''  
   SET @cLoseUCC = ''

   SET @nTranCount = @@TRANCOUNT  

   BEGIN TRAN  
   SAVE TRAN rdt_1765ExtUpdSP01  

    -- Get TransferKey  
--   SELECT @cListKey = ListKey  
--   FROM dbo.TaskDetail WITH (NOLOCK)  
--   WHERE TaskDetailKey = @cTaskDetailKey  
--  
--   SELECT @cSourceKey = SourceKey  
--   FROM dbo.TaskDetail WITH (NOLOCK)  
--   WHERE ListKey = @cListKey  
--   AND TaskType = 'RPF'  
--   AND CaseID   = @cDROPID  
     
   -- Get TransferKey  
   SELECT @cRefSourceKey = SourceKey  
   FROM dbo.TaskDetail WITH (NOLOCK)  
   WHERE TaskDetailKey = @cTaskDetailKey  
  
   SELECT @cSourceKey = SourceKey  
   FROM dbo.TaskDetail WITH (NOLOCK)  
   WHERE TaskDetailKey = @cRefSourceKey  
   AND TaskType        = 'RPF'  
   AND CaseID          = @cDROPID  
     
   IF ISNULL(RTRIM(@cDROPID),'')  = ''  
   BEGIN  
      SET @nErrNo = 90354  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCReq'  
    GOTO RollBackTran  
   END

   SET @cTransferKey = Substring(@cSourceKey , 1 , 10)   
   SET @cTrasferLineNumber = Substring(@cSourceKey , 11 , 15 )   
     
   SELECT @cFromLoc = FromLoc  
         ,@cToLoc   = ToLoc  
         ,@cFromID  = FromID  
         ,@cLot     = Lot  
         ,@cSKU     = SKU
   FROM dbo.TaskDetail WITH (NOLOCK)   
   WHERE TaskDetailKEy = ISNULL(RTRIM(@cTaskDetailKey),'')   
     
   --INSERT INTO TraceInfo (TraceName , TimeIn , col1 , col2, Col3, Col4, col5, step1 , step2  )   
   --VALUES ( 'RPT', GetDATE(), @nQty, @CfroMLoc, @ctoLoc, @cTransferKey , @cTrasferLineNumber, '1', @cDROPID)  
     
   --INSERT INTO TraceInfo (TraceName , TimeIn , col1 , col2, Col3, Col4, col5, step1, step2 )   
   --VALUES ( 'RPT', GetDATE(), ISNULL(RTRIM(@cTaskDetailKey),'') , @cFromLoc, @cToLoc, @cFromID , @cLot, '1.1' , @cSKU )  
   
   SELECT @cLoseUCC = LoseUCC 
   FROM dbo.Loc WITH (NOLOCK)
   WHERE Loc = @cToLoc 

   -- Move by SKU  
   EXECUTE rdt.rdt_Move  
      @nMobile     = @nMobile,  
      @cLangCode   = @cLangCode,  
      @nErrNo      = @nErrNo  OUTPUT,  
      @cErrMsg     = @cErrMsg OUTPUT,  
      @cSourceType = 'rdtfnc_TM_ReplenTo',  
      @cStorerKey  = @cStorerKey,  
      @cFacility   = @cFacility,  
      @cFromLOC    = @cFromLOC,  
      @cToLOC      = @cToLoc, -- Final LOC  
      @cFromID     = @cFromID,  
      @cToID       = '',  
      @cSKU        = @cSKU,  
      @nQTY        = @nQTY,  
      @cFromLOT    = @cLOT  
        
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
      SET @nErrNo = 90351  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskDetFail'  
    GOTO RollBackTran  
   END  

   -- Unlock suggested location  (Chee01)
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
      ,@cUCCNo      = @cDROPID  
  
   IF @nErrNo <> 0  
      GOTO RollBackTran  
  
   --INSERT INTO TraceInfo (TraceName , TimeIn , col1 , col2, Col3, Col4, col5, step1 )   
   --VALUES ( 'RPT', GetDATE(), @nQty, @CfroMLoc, @ctoLoc, @cTransferKey , @cTrasferLineNumber, '2' )  
  
   UPDATE dbo.TransferDetail WITH (ROWLOCK)  
   SET --FromQty = @nQty  
      --,ToQty   = @nQty  
      FromLoc = @cToLoc  
      ,FromID  = ''  
      ,ToLoc   = @cToLoc  
      ,ToID    = ''  
      ,Status  = '9'  
      --,Trafficcop = NULL  
   WHERE TransferKey = @cTransferKey  
   AND TransferLineNumber = @cTrasferLineNumber  
     
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 90352  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTransferDetFail'  
    --ROLLBACK TRAN  -- (ChewKP01)  
    GOTO RollBackTran  
   END  
     
     
   IF NOT EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)   
                 WHERE StorerKey = @cStorerKey  
                 AND ListKey = @cListKey  
                 AND Status < '9' )   
   BEGIN  
--         EXEC ispFinalizeTransfer   
--              @cSourceKey         
--            , @b_Success        OUTPUT  
--            , @nErrNo           OUTPUT  
--            , @cErrMsg          OUTPUT  
--              
--         IF @nErrNo <> 0   
--         BEGIN  
--            SET @nErrNo = 90353  
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'FinaLizeTransferFail'  
--          --ROLLBACK TRAN  -- (ChewKP01)  
--          GOTO RollBackTran  
--         END  
  
        IF EXISTS ( SELECT 1 FROM dbo.TransferDetail WITH (NOLOCK)   
                    WHERE TransferKey = @cTransferKey  
                    AND Status <> '9' )   
        BEGIN  
--             IF EXISTS ( SELECT 1 FROM TransferDetail WITH (NOLOCK)   
--                         WHERE TransferKey = @cTransferKey   
--                         AND Status < '9' )   
--             BEGIN  
                -- Generate Supervisor Alert   
                SELECT @cModuleName = 'ReplenTo'  
         
                SET @cAlertMessage = 'Exception Occurs for Transfer. TransferKey : ' + @cTransferKey  
                  
                EXEC nspLogAlert  
                        @c_modulename       = @cModuleName  
                      , @c_AlertMessage     = @cAlertMessage  
                      , @n_Severity         = '5'  
                      , @b_success          = @b_success      OUTPUT  
                      , @n_err              = @nErrNo        OUTPUT  
                      , @c_errmsg           = @cErrMsg       OUTPUT  
                      , @c_Activity         = 'ReplenTo'  
                      , @c_Storerkey      = @cStorerKey  
                      , @c_SKU            = ''  
                      , @c_UOM            = ''  
                      , @c_UOMQty         = ''  
                      , @c_Qty            = 0  
                      , @c_Lot            = ''  
                      , @c_Loc            = ''  
                      , @c_ID               = ''  
                      , @c_TaskDetailKey   = ''  
                      , @c_UCCNo            = ''  
--             END  
        END  
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
   
   GOTO QUIT   
     
RollBackTran:  
   ROLLBACK TRAN rdt_1765ExtUpdSP01 -- Only rollback change made here  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_1765ExtUpdSP01  
    
  
END    

GO