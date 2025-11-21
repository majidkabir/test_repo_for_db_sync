SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/******************************************************************************/    
/* Store procedure: rdt_1764ExtUpd14                                          */    
/* Purpose: TM Replen From, Extended Update for HK ANF                        */    
/*                                                                            */    
/* Modifications log:                                                         */    
/*                                                                            */    
/* Date         Author    Ver.  Purposes                                      */    
/* 2021-04-01   Chermaine 1.0   WMS-16609 Created (dup rdt_1764ExtUpd11)      */    
/******************************************************************************/    
  
CREATE PROCEDURE [RDT].[rdt_1764ExtUpd14]    
    @nMobile         INT    
   ,@nFunc           INT    
   ,@cLangCode       NVARCHAR( 3)    
   ,@nStep           INT    
   ,@cTaskdetailKey  NVARCHAR( 10)    
   ,@nErrNo          INT           OUTPUT    
   ,@cErrMsg         NVARCHAR( 20) OUTPUT    
   ,@nAfterStep      INT = 0    
   ,@cDropID         NVARCHAR( 20) = ''    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @b_Success   INT    
   DECLARE @n_err       INT    
   DECLARE @c_errmsg    NVARCHAR( 250)    
   DECLARE @nTranCount  INT    
   DECLARE @bSuccess    INT    
    
   DECLARE @cStorerKey  NVARCHAR( 15)    
   DECLARE @cFacility   NVARCHAR( 5)    
   DECLARE @cSKU        NVARCHAR( 20)    
   DECLARE @cUCC        NVARCHAR( 20)    
   DECLARE @cFromLOT    NVARCHAR( 10)    
   DECLARE @cFromLOC    NVARCHAR( 10)    
   DECLARE @cFromID     NVARCHAR( 18)    
   DECLARE @cToLOC      NVARCHAR( 10)    
   DECLARE @cToID       NVARCHAR( 18)    
   DECLARE @cPickMethod NVARCHAR( 10)    
   DECLARE @cStatus     NVARCHAR( 10)    
   DECLARE @cReasonKey  NVARCHAR( 10)    
   DECLARE @cUserKey    NVARCHAR( 10)    
   DECLARE @cTaskType   NVARCHAR( 10)    
   DECLARE @cTaskKey    NVARCHAR( 10)    
   DECLARE @cRefTaskKey NVARCHAR( 10)    
   DECLARE @cTaskUOM    NVARCHAR( 10)    
   DECLARE @cListKey    NVARCHAR( 10)    
   -- DECLARE @cDropID     NVARCHAR( 20)    
   DECLARE @cCaseID     NVARCHAR( 20)    
   DECLARE @cTransitLOC NVARCHAR( 10)    
   DECLARE @cFinalLOC   NVARCHAR( 10)    
   DECLARE @cLogicToLoc NVARCHAR( 10)
   DECLARE @cFinalID    NVARCHAR( 18)    
   DECLARE @nTaskQTY    INT    
   DECLARE @cPickDetailKey  NVARCHAR( 10)    
   DECLARE @cPriority       NVARCHAR( 10)    
   DECLARE @cSourcePriority NVARCHAR( 10)    
   DECLARE @cSourceKey      NVARCHAR( 30)    
   DECLARE @nInterFaceRec   INT
    
   DECLARE @curTask     CURSOR    
   DECLARE @curITF       CURSOR    
   DECLARE @curUCC      CURSOR    
   DECLARE @tTask TABLE    
   (    
      TaskDetailKey NVARCHAR(10)    
   )    
    
   SET @nTranCount = @@TRANCOUNT    
    
   -- TM Replen From    
   IF @nFunc = 1764    
   BEGIN    
      IF @nStep = 6 -- ToLOC    
      BEGIN    
         DECLARE @cPickSlipNo     NVARCHAR(10)    
         DECLARE @cOrderKey       NVARCHAR(10)    
         DECLARE @cLoadKey        NVARCHAR(10)    
         DECLARE @cFinalLOCPAZone NVARCHAR(10)    
         DECLARE @cFromLOCType    NVARCHAR(10)    
         DECLARE @cToLOCCategory  NVARCHAR(10)    
         DECLARE @cWaveKey        NVARCHAR(10)    
         DECLARE @cOrderStatus    NVARCHAR(10)      
         DECLARE @cMessage02      NVARCHAR(20)    
         DECLARE @cNewTaskDetailKey NVARCHAR(10)    
         DECLARE @cLocationType     NVARCHAR( 10)    
         DECLARE @cLocationCategory NVARCHAR( 10)    
         
         SET @nInterFaceRec = 1
    
         -- Get task info    
         SELECT    
            @cPickMethod = PickMethod,    
            @cStorerKey = StorerKey,    
            @cFromID = FromID,    
            @cUserKey = UserKey,    
            @cReasonKey = ReasonKey,    
            -- @cDropID = DropID, -- Cancel/SKIP might not have DropID    
            @cListKey = ListKey,    
            @cToLoc = ToLoc
         FROM dbo.TaskDetail WITH (NOLOCK)    
         WHERE TaskdetailKey = @cTaskdetailKey    
           
         SELECT @cFacility = Facility    
         FROM rdt.rdtMobrec WITH (NOLOCK)    
         WHERE UserName = SUSER_SNAME()    
         
         SELECT     
            @cLocationType = LocationType     
         FROM dbo.LOC WITH (NOLOCK)     
         WHERE Loc = @cToLOC     
         AND   Facility = @cFacility  
           
         -- Check FP without ID    
         IF @cPickMethod = 'FP'    
         BEGIN    
            IF @cFromID = ''    
               BEGIN    
                  SET @nErrNo = 166004    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID    
                  GOTO Quit    
               END    
               SET @cDropID = @cFromID    
         END    
    
         -- Get initial task    
         INSERT INTO @tTask (TaskDetailKey)    
         SELECT TaskDetailKey    
         FROM dbo.TaskDetail WITH (NOLOCK)    
         WHERE ListKey = @cListKey    
            AND TransitCount = 0    
    
         BEGIN TRAN    
         SAVE TRAN rdt_1764ExtUpd14    
    
         -- Loop tasks    
         SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT T.TaskDetailKey, TD.Status, TD.DropID, TD.CaseID, TD.FromLOC, TD.ToLOC, TD.ToID, TD.FinalLOC, TD.FinalID, TD.WaveKey, TD.SourceKey, TD.Priority, TD.SourcePriority, Message02 , TD.LogicalToLoc  
            FROM dbo.TaskDetail TD WITH (NOLOCK)    
               JOIN @tTask T ON (TD.TaskDetailKey = T.TaskDetailKey)    
         OPEN @curTask    
         FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus, @cDropID, @cCaseID, @cFromLOC, @cToLOC, @cToID, @cFinalLOC, @cFinalID, @cWaveKey, @cSourceKey, @cPriority, @cSourcePriority, @cMessage02 ,@cLogicToLoc    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
            -- Cancel/skip task    
            IF @cStatus IN ('X', '0')    
            BEGIN    
               -- Update Task    
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET    
                  ListKey = '',    
                  DropID = '',    
                  EndTime = GETDATE(),    
                  EditDate = GETDATE(),    
                  EditWho  = SUSER_SNAME(),    
                  Trafficcop = NULL    
               WHERE TaskDetailKey = @cTaskKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 166005    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskdetFail    
                  GOTO RollBackTran    
               END    
            END    
    
            -- Completed task    
            IF @cStatus = '9'    
            BEGIN    
               -- For Non PTS    
               IF @cWaveKey = ''    
               BEGIN    
                  DECLARE @cTransferKey NVARCHAR(10)    
                  DECLARE @cTransferLineNo NVARCHAR(5)    
                  DECLARE @cUCCLOT NVARCHAR( 10)     
                  DECLARE @cUCCLOC NVARCHAR( 10)     
                  DECLARE @cUCCID  NVARCHAR( 18)    
                  DECLARE @cUCCSKU NVARCHAR( 20)     
                  DECLARE @nUCCQTY INT    
                               
                  -- Get transfer info    
                  SET @cTransferKey = LEFT( @cSourceKey, 10)    
                  SET @cTransferLineNo = SUBSTRING( @cSourceKey, 11, 5)    
    
                  -- Get UCC info    
                  SET @cUCCLOC = ''    
                  SET @cUCCID = ''    
                  SELECT     
                     @cUCCLOT = LOT,     
                     @cUCCLOC = LOC,     
                     @cUCCID = ID,     
                     @cUCCSKU = SKU,     
                     @nUCCQTY = QTY    
                  FROM UCC WITH (NOLOCK)     
                  WHERE StorerKey = @cStorerKey     
                     AND UCCNo = @cCaseID    
                         
                  -- Get LOC info    
                  --SELECT @cToLOCCategory = LocationCategory FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC   
				      SELECT @cToLOCCategory = LocationCategory FROM LOC WITH (NOLOCK) WHERE LOC = @cLogicToLoc 
                  SELECT @cFromLOCType = LocationType FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC    
    
                  -- Transfer for kitting     
                  -- Only apply for bulk to VAS. DPP to VAS, already finalize by schedule job    
                  --IF @cToLOCCategory = 'VAS' AND @cFromLOCType <> 'DYNPPICK'    
	               IF @cFromLOCType <> 'DYNPPICK'   AND  @cToLOCCategory <> 'VAS'
				         BEGIN
				           IF EXISTS( SELECT TOP 1 1     
                        FROM TransferDetail WITH (NOLOCK)     
                        WHERE TransferKey = @cTransferKey     
                           AND TransferLineNumber = @cTransferLineNo     
                           AND FromStorerKey = @cStorerKey    
                           AND UserDefine01 = @cCaseID    
                           AND Status <> '9') 
					         BEGIN
						         UPDATE TransferDetail SET    
                              Status = '9',    
                              FromLOC = @cUCCLOC,     
                              FromID = @cUCCID,     
                              ToLOC = @cUCCLOC,     
                              ToID = @cUCCID,     
                              EditWho = SUSER_SNAME(),    
                              EditDate = GETDATE()    
                           WHERE TransferKey = @cTransferKey    
                              AND TransferLineNumber = @cTransferLineNo    
                           SET @nErrNo = @@ERROR    
                           IF @nErrNo <> 0    
                           BEGIN    
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
                              GOTO RollBackTran    
                           END    
					         END
				         END
				         ELSE IF  @cFromLOCType <> 'DYNPPICK'   AND  @cToLOCCategory = 'VAS'  
                     BEGIN    
                        -- TransferDetail    
                        IF EXISTS( SELECT TOP 1 1     
                           FROM TransferDetail WITH (NOLOCK)     
                           WHERE TransferKey = @cTransferKey     
                              AND TransferLineNumber = @cTransferLineNo     
                              AND FromStorerKey = @cStorerKey    
                              AND UserDefine01 = @cCaseID    
                              AND Status <> '9')    
                        BEGIN    
                           -- Finalize TransferDetail    
                           UPDATE TransferDetail SET    
                              Status = '9',    
                              FromLOC = @cUCCLOC,     
                              FromID = @cUCCID,     
                              ToLOC = @cUCCLOC,     
                              ToID = @cUCCID,     
                              EditWho = SUSER_SNAME(),    
                              EditDate = GETDATE()    
                           WHERE TransferKey = @cTransferKey    
                              AND TransferLineNumber = @cTransferLineNo    
                           SET @nErrNo = @@ERROR    
                           IF @nErrNo <> 0    
                           BEGIN    
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
                              GOTO RollBackTran    
                           END   
						
						         IF NOT EXISTS( SELECT TOP 1 1 FROM TransferDetail WITH (NOLOCK) WHERE TransferKey = @cTransferKey AND Status <> '9')    
                           BEGIN    
                              DECLARE @c_PostFinalizeTransferSP NVARCHAR( 30)    
                              EXEC nspGetRight      
                                    @c_Facility  = NULL     
                                  , @c_StorerKey = @cStorerKey    
                                  , @c_sku       = NULL    
                                  , @c_ConfigKey = 'PostFinalizeTranferSP'      
                                  , @b_Success   = @b_Success                  OUTPUT      
                                  , @c_authority = @c_PostFinalizeTransferSP   OUTPUT       
                                  , @n_err       = @nErrNo                     OUTPUT       
                                  , @c_errmsg    = @cErrMsg                    OUTPUT      
                
                              IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostFinalizeTransferSP AND TYPE = 'P')    
                              BEGIN    
                                 SET @b_Success = 0      
                                 EXECUTE dbo.ispPostFinalizeTransferWrapper     
                                         @c_TransferKey             = @cTransferKey    
                                       , @c_PostFinalizeTransferSP  = @c_PostFinalizeTransferSP    
                                       , @b_Success = @b_Success     OUTPUT      
                                       , @n_Err     = @nErrNo        OUTPUT       
                                       , @c_ErrMsg  = @cErrMsg       OUTPUT      
                                       , @b_debug   = 0     
                                 IF @nErrNo <> 0    
                                    GOTO RollBackTran    
                              END    
                           END 
                        END    
    
                     -- Generate Kit, if all TransferDetail finalized    
                    /* IF NOT EXISTS( SELECT TOP 1 1 FROM TransferDetail WITH (NOLOCK) WHERE TransferKey = @cTransferKey AND Status <> '9')    
                     BEGIN    
                        DECLARE @c_PostFinalizeTransferSP NVARCHAR( 30)    
                        EXEC nspGetRight      
                              @c_Facility  = NULL     
                            , @c_StorerKey = @cStorerKey    
                            , @c_sku       = NULL    
                            , @c_ConfigKey = 'PostFinalizeTranferSP'      
                            , @b_Success   = @b_Success                  OUTPUT      
                            , @c_authority = @c_PostFinalizeTransferSP   OUTPUT       
                            , @n_err       = @nErrNo                     OUTPUT       
                            , @c_errmsg    = @cErrMsg                    OUTPUT      
                
                        IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostFinalizeTransferSP AND TYPE = 'P')    
                        BEGIN    
                           SET @b_Success = 0      
                           EXECUTE dbo.ispPostFinalizeTransferWrapper     
                                   @c_TransferKey             = @cTransferKey    
                                 , @c_PostFinalizeTransferSP  = @c_PostFinalizeTransferSP    
                                 , @b_Success = @b_Success     OUTPUT      
                                 , @n_Err     = @nErrNo        OUTPUT       
                                 , @c_ErrMsg  = @cErrMsg       OUTPUT      
                                 , @b_debug   = 0     
                           IF @nErrNo <> 0    
                              GOTO RollBackTran    
                        END    
                     END    --*/
                     END    
    
                  /*    
                  -- Generate PA task to DPP (those not for PTS, but use conveyor go to DPP)    
                  IF @cToLOCCategory = 'INDUCTION'     
                  BEGIN    
                     IF NOT EXISTS( SELECT 1 FROM TaskDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND TaskType = 'PA' AND CaseID = @cCaseID)    
                     BEGIN    
                        -- Get new TaskDetailKeys    
                      SET @b_Success = 1    
                      EXECUTE dbo.nspg_getkey    
                       'TASKDETAILKEY'    
                       , 10    
                       , @cNewTaskDetailKey OUTPUT    
                , @b_Success         OUTPUT    
                       , @nErrNo            OUTPUT    
                   , @cErrMsg           OUTPUT    
                        IF @b_Success <> 1    
                        BEGIN    
                           SET @nErrNo = 166010    
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey    
                           GOTO RollBackTran    
                        END    
          
                        -- Insert final task    
                        INSERT INTO TaskDetail (    
                           TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, CaseID, QTY,     
                           StorerKey, SKU, LOT, SourceType, SourceKey, Priority, SourcePriority, TrafficCop)    
                        VALUES (    
                           @cNewTaskDetailKey, 'PA', '0', '', @cUCCLOC, @cUCCID, LEFT( @cMessage02, 10), '', @cCaseID, @nUCCQTY,     
                           @cStorerKey, @cUCCSKU, @cUCCLOT, 'RPF', @cSourceKey, @cPriority, @cSourcePriority, NULL)    
                        IF @@ERROR <> 0    
                        BEGIN    
                           SET @nErrNo = 166011    
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTaskDetFail    
                           GOTO RollBackTran    
                        END    
                     END    
                  END    
    
                  -- Normal replenish    
                  IF @cToLOCCategory NOT IN ('INDUCTION', 'VAS')    
                  BEGIN     
                     -- Check RP1 generated (RPF generate RP1 if only 1 case)    
                     IF EXISTS( SELECT TOP 1 1 FROM TaskDetail WITH (NOLOCK) WHERE ListKey = @cListKey AND TaskType = 'RP1')    
                     BEGIN    
                        -- Delete RP1     
                        DELETE TaskDetail WHERE ListKey = @cListKey AND TaskType = 'RP1'    
                        SET @nErrNo = @@ERROR    
                        IF @nErrNo <> 0    
                        BEGIN    
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
                           GOTO RollBackTran    
                        END    
                     END    
                         
                     -- Check RPT generated    
                     IF NOT EXISTS( SELECT TOP 1 1 FROM TaskDetail WITH (NOLOCK) WHERE TaskType = 'RPT' AND CaseID = @cCaseID AND SourceKey = @cTaskKey)      
                     BEGIN    
                        -- Get new TaskDetailKeys    
                      SET @b_Success = 1    
                      EXECUTE dbo.nspg_getkey    
                       'TASKDETAILKEY'    
                       , 10    
                       , @cNewTaskDetailKey OUTPUT    
                       , @b_Success         OUTPUT    
                       , @nErrNo            OUTPUT    
                       , @cErrMsg           OUTPUT    
                        IF @b_Success <> 1    
                        BEGIN    
                           SET @nErrNo = 166012    
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey    
                           GOTO RollBackTran    
                        END    
                         
                        -- Insert RPT    
                        INSERT INTO TaskDetail (    
                           TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY, CaseID,     
                           PickMethod, StorerKey, SKU, LOT, SourceType, SourceKey, WaveKey, Priority, SourcePriority, TrafficCop)    
                        VALUES (    
                           @cNewTaskDetailKey, 'RPT', '0', '', @cUCCLOC, @cUCCID,     
                           CASE WHEN @cFinalLOC <> '' THEN @cFinalLOC ELSE @cToLOC END,     
                           CASE WHEN @cFinalID  <> '' THEN @cFinalID  ELSE @cToID  END,     
        @nUCCQTY, @cCaseID,     
                           'PP', @cStorerKey, @cUCCSKU, @cUCCLOT, 'rdt_1764ExtUpd11', @cTaskKey, @cWaveKey, @cPriority, @cSourcePriority, NULL)    
                        IF @@ERROR <> 0    
     BEGIN    
                           SET @nErrNo = 166013    
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTaskDetFail    
                           GOTO RollBackTran    
                        END    
                     END    
                  END    
                  */    
               END    
    
               -- Route each UCC    
               IF @cWaveKey = '' -- Non PTS      
               BEGIN      
                  EXEC [dbo].[ispWCSRO01]        
                       @c_StorerKey     =  @cStorerKey        
                     , @c_Facility      =  @cFacility        
                     , @c_ToteNo        =  @cCaseID        
                     , @c_TaskType      =  'RPF'        
                     , @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual        
                     , @c_TaskDetailKey =  @cNewTaskDetailKey         
                     , @c_Username      =  @cUserKey        
                     , @c_RefNo01       =  ''        
                     , @c_RefNo02       =  ''        
                     , @c_RefNo03       =  ''        
                     , @c_RefNo04       =  ''        
                     , @c_RefNo05       =  ''        
                     , @b_debug         =  '0'        
                     , @c_LangCode      =  'ENG'        
                     , @n_Func          =  0        
                     , @b_Success       = @b_Success OUTPUT        
                     , @n_ErrNo         = @nErrNo    OUTPUT        
                     , @c_ErrMsg        = @cErrMSG   OUTPUT        
               END      
               ELSE      
               BEGIN    
                  EXEC [dbo].[ispWCSRO01]    
                       @c_StorerKey     =  @cStorerKey    
                     , @c_Facility      =  @cFacility    
                     , @c_ToteNo        =  @cCaseID    
                     , @c_TaskType      =  'RPF'    
                     , @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual    
                     , @c_TaskDetailKey =  @cTaskKey    
                     , @c_Username      =  @cUserKey    
                     , @c_RefNo01       =  ''    
                     , @c_RefNo02       =  ''    
                     , @c_RefNo03       =  ''    
                     , @c_RefNo04       =  ''    
                     , @c_RefNo05       =  ''    
                     , @b_debug         =  '0'    
                     , @c_LangCode      =  'ENG'    
                     , @n_Func          =  0    
                     , @b_Success       = @b_Success OUTPUT    
                     , @n_ErrNo         = @nErrNo    OUTPUT    
                     , @c_ErrMsg        = @cErrMSG   OUTPUT    
               END    
               IF @nErrNo <> 0    
                  GOTO RollBackTran    
                  
            END    
    
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus, @cDropID, @cCaseID, @cFromLOC, @cToLOC, @cToID, @cFinalLOC, @cFinalID, @cWaveKey, @cSourceKey, @cPriority, @cSourcePriority, @cMessage02, @cLogicToLoc      
         END   
         
        
         -- interface to RPF - caseID
         IF EXISTS (SELECT 1 FROM pickDetail WITH (NOLOCK) WHERE storerKey = @cStorerKey AND taskDetailkey = @cTaskdetailKey)  
         BEGIN
         	IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)     
                        JOIN Loc L WITH (NOLOCK) ON L.LocationType = C.code
                        WHERE LISTNAME = 'AGVSTG'      
                        AND   Storerkey = @cStorerKey
                        AND L.loc = @cLogicToLoc) 
            BEGIN
               SET @curITF = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                  SELECT TD.CaseID  
                  FROM dbo.TaskDetail TD WITH (NOLOCK)    
                  JOIN @tTask T ON (TD.TaskDetailKey = T.TaskDetailKey)    
               OPEN @curITF    
               FETCH NEXT FROM @curITF INTO @cCaseID
               WHILE @@FETCH_STATUS = 0    
               BEGIN    
         	
            	   SET @nErrNo = 0    
                  EXEC [CNDTSITF].[dbo].[isp5214P_WOL_ANFQHW_CN_FCR_Export]     
                        @c_DataStream = '5214'
                        , @c_StorerKey   = @cStorerKey
                        --, @c_PalletId    = @cFromID
                        --, @c_Facility    = @cFacility
                        , @b_Debug       = 0
                        , @b_Success     = @bSuccess OUTPUT  
                        , @n_Err         = @nErrNo  OUTPUT  
                        , @c_ErrMsg      = @cErrMsg OUTPUT  
                        , @c_Caseid      = @cCaseID     
          
                  IF @nErrNo <> 0     
                  BEGIN    
                     SET @nErrNo = 166014    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AGV API Error    
                     GOTO Quit    
                  END
                  FETCH NEXT FROM @curITF INTO @cCaseID  
               END 
            END
         END
         ELSE
         BEGIN
         	IF NOT EXISTS (SELECT 1 FROM pickDetail WITH (NOLOCK) WHERE storerKey = @cStorerKey AND taskDetailkey = @cTaskKey)  
         	BEGIN
         		-- interface to RP1 - FromID
               IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)     
                           WHERE LISTNAME = 'AGVSTG'    
                           AND   Code = @cLocationType    
                           AND   Storerkey = @cStorerKey) 
               BEGIN
               	SET @nErrNo = 0    
                  EXEC [CNDTSITF].[dbo].[isp5199P_WOL_ANFQHW_CN_REC_Export]     
                        @c_DataStream = '5199'
                        , @c_StorerKey   = @cStorerKey
                        --, @c_PalletId    = @cFromID
                        --, @c_Facility    = @cFacility
                        , @b_Debug       = 0
                        , @b_Success     = @bSuccess OUTPUT  
                        , @n_Err         = @nErrNo  OUTPUT  
                        , @c_ErrMsg      = @cErrMsg OUTPUT  
                        , @c_LLI_ID      = @cFromID     
                
                  IF @nErrNo <> 0     
                  BEGIN    
                     SET @nErrNo = 166015    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AGV API Error    
                     GOTO Quit    
                  END  
               END
         	END
         END
                           
         COMMIT TRAN rdt_1764ExtUpd14 -- Only commit change made here    
      END    
   END    
    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_1764ExtUpd14 -- Only rollback change made here    
Fail:    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END 

GO