SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_1764ExtUpd06                                          */  
/* Purpose: TM Replen From, Extended Update for                               */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 2018-06-04   ChewKP    1.0   WMS-5178 Created                              */  
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1764ExtUpd06]  
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
     
   DECLARE @cFacility   NVARCHAR( 5)  
   DECLARE @cStorerKey  NVARCHAR( 15)  
   DECLARE @cUCCNo      NVARCHAR( 20)  
   DECLARE @cFromLOC    NVARCHAR( 10)  
   DECLARE @cFromID     NVARCHAR( 18)  
   DECLARE @cToLOC      NVARCHAR( 10)  
   DECLARE @cToID       NVARCHAR( 18)  
   DECLARE @cFinalLOC   NVARCHAR( 10)  
   DECLARE @cPickMethod NVARCHAR( 10)  
   DECLARE @cStatus     NVARCHAR( 10)  
   DECLARE @cReasonKey  NVARCHAR( 10)  
   DECLARE @cUserKey    NVARCHAR( 10)  
   DECLARE @cTaskType   NVARCHAR( 10)  
   DECLARE @cTaskKey    NVARCHAR( 10)  
   DECLARE @cRefTaskKey NVARCHAR( 10)  
   DECLARE @cListKey    NVARCHAR( 10)  
   DECLARE @nTaskQTY    INT  
   DECLARE @nUCCQTY     INT  
   DECLARE @nSystemQTY  INT  
   DECLARE @cPickDetailKey NVARCHAR( 10)  
   DECLARE @nQTYAlloc      INT  
   DECLARE @cMoveQTYAlloc  NVARCHAR( 1)  
   DECLARE @nPendingMoveIn INT  
         , @cDeviceID    NVARCHAR(20)  
         , @cDeviceType  NVARCHAR(20)  
         , @cMsg03       NVARCHAR(20)   
         , @cWaveKey     NVARCHAR(10)   
         , @cWCSStation  NVARCHAR(20)  
         , @cOrderKey    NVARCHAR(10)   
         , @cWCSKey      NVARCHAR(10)   
         , @bSuccess     INT  
         , @cWCSSequence NVARCHAR(2)  
         , @cWCSMessage  NVARCHAR(255)   
         , @nInputKey    INT  
         , @cPutawayZone NVARCHAR(10)   
         , @cShipRouteLoc  NVARCHAR(10)   
         , @cPTSLoc        NVARCHAR(10)   
         , @nCount         INT  
         , @cLoadKey       NVARCHAR(10)  
         , @cSKU           NVARCHAR(20)   
         , @cSKUGroup      NVARCHAR(10)  
         , @cShort         NVARCHAR(10)   
         , @cPreWCSStation NVARCHAR(10)   
  
   DECLARE @curTask     CURSOR  
   DECLARE @curPD       CURSOR  
   DECLARE @tTask TABLE  
   (  
      TaskDetailKey NVARCHAR(10)  
   )  
  
   SET @nTranCount = @@TRANCOUNT  
    
   BEGIN TRAN  
   SAVE TRAN rdt_1764ExtUpd06  
           
   SET @cDeviceType = 'WCS'  
   SET @cDeviceID   = 'WCS'  
     
   -- TM Replen From  
   IF @nFunc = 1764  
   BEGIN  
      IF @nStep = 6 -- ToLOC  
      BEGIN  
         -- Get task info  
         SELECT  
            @cTaskType = TaskType,   
            @cPickMethod = PickMethod,  
            @cStorerKey = StorerKey,  
            @cFromID = FromID,  
            @cDropID = DropID, -- Cancel/SKIP might not have DropID  
            @cListKey = ListKey, -- Cancel/SKIP might not have ListKey (e.g. last carton SKIP)  
            @nPendingMoveIn = PendingMoveIn  
         FROM dbo.TaskDetail WITH (NOLOCK)  
         WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Get list key (quick fix)  
         IF @cListKey = ''  
            SELECT @cListKey = V_String7 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile  
  
         -- Check FP without ID  
         IF @cPickMethod = 'FP'  
         BEGIN  
            IF @cFromID = ''  
            BEGIN  
               SET @nErrNo = 124701  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need DropID  
               GOTO Quit  
            END  
            SET @cDropID = @cFromID  
         END  
  
         -- Get initial task  
         IF @cListKey <> ''  -- For protection, in case ListKey is blank  
            INSERT INTO @tTask (TaskDetailKey)  
            SELECT TaskDetailKey  
            FROM dbo.TaskDetail WITH (NOLOCK)  
            WHERE ListKey = @cListKey  
               AND TransitCount = 0  
  
         SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)  
  
           
  
         -- Loop tasks (1 UCC = 1 task)  
         SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT T.TaskDetailKey, TD.Status, TD.CaseID, TD.QTY, TD.SystemQTY, TD.ToLOC, TD.ToID, TD.FinalLOC, TD.Message03, TD.WaveKey, TD.FromLoc, TD.SKU  
            FROM dbo.TaskDetail TD WITH (NOLOCK)  
               JOIN @tTask T ON (TD.TaskDetailKey = T.TaskDetailKey)  
         OPEN @curTask  
         FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus, @cUCCNo, @nUCCQTY, @nSystemQTY, @cToLOC, @cToID, @cFinalLOC, @cMsg03, @cWaveKey,  @cFromLoc, @cSKU  
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
                  SET @nErrNo = 124702  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail  
                  GOTO RollBackTran  
               END  
            END  
  
            -- Completed task  
            IF @cStatus = '9'  
            BEGIN  
               -- Carton is in-transit  
               IF @cFinalLOC <> ''  AND ISNULL(@cUCCNo,'')  <> ''
               BEGIN  
                  -- Calc QTYAlloc  
                  IF @cMoveQTYAlloc = '1'  
                  BEGIN  
                     IF @nUCCQTY < @nSystemQTY -- Short replen  
                        SET @nQTYAlloc = @nUCCQTY  
                     ELSE  
                        SET @nQTYAlloc = @nSystemQTY     
                  END  
                  ELSE  
                     SET @nQTYAlloc = 0  
     
                  -- Get facility  
                  SELECT @cFacility = Facility FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC  
     
                   --SELECT @cToID '@cToID' , @cFinalLOC '@@cFinalLOC' , @cToLOC '@cToLOC' , @cFromID '@cFromID'
  
                  -- Move by UCC  
                  EXECUTE rdt.rdt_Move  
                     @nMobile     = @nMobile,  
                     @cLangCode   = @cLangCode,  
                     @nErrNo      = @nErrNo  OUTPUT,  
                     @cErrMsg     = @cErrMsg OUTPUT,  
                     @cSourceType = 'rdt_1764ExtUpd06',  
                     @cStorerKey  = @cStorerKey,  
                     @cFacility   = @cFacility,  
                     @cFromLOC    = @cToLOC,  
                     @cToLOC      = @cFinalLOC,  
                     @cFromID     = @cToID,  
                     @cToID       = @cToID,  
                     --@cUCC        = @cUCCNo,  
                     @cSKU        = @cSKU,  
                     @nQty        = @nUCCQty,  
                     @nQTYAlloc   = @nQTYAlloc,  
                     @nQTYReplen  = 0, -- @nQTYReplen, already deducted when move FROMLOC-->TOLOC  
                     @nFunc       = @nFunc,  
                     @cDropID     = @cUCCNo  
                  IF @nErrNo <> 0  
                     GOTO RollBackTran  
                       
                       
  
                  IF @nPendingMoveIn > 0  
                  BEGIN  
                     -- Unlock  suggested location  
                     EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
                        ,''      --@cFromLOC  
                        ,''      --@cFromID  
                        ,''      --@cSuggestedLOC  
                        ,''      --@cStorerKey  
                        ,@nErrNo  OUTPUT  
                        ,@cErrMsg OUTPUT  
                        ,@cTaskDetailKey = @cTaskKey  
                     IF @nErrNo <> 0  
                        GOTO RollBackTran  
                  END  
                    
                  -- WCS Process --   
                  IF @cMsg03 = 'PACKSTATION' AND ISNULL(@cWaveKey,'')  <> ''   
                  BEGIN  
                     -- To Packing Station  
                     SET @cWCSStation = ''  
                       
                     SELECT @cWCSStation = Short                  
                     FROM dbo.Codelkup WITH (NOLOCK)   
                     WHERE ListName = 'WCSSTATION'  
                     AND StorerKey = @cStorerKey  
                     AND Code = 'B2BPACK'  
                       
                     EXECUTE dbo.nspg_GetKey  
                     'WCSKey',  
                     10 ,  
                     @cWCSKey           OUTPUT,  
                     @bSuccess          OUTPUT,  
                     @nErrNo            OUTPUT,  
                     @cErrMsg           OUTPUT  
                       
                     IF @bSuccess <> 1  
                     BEGIN  
                        SET @nErrNo = 124705  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                        GOTO RollBackTran  
                     END  
                       
                     SET @cWCSSequence =  '01' --RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
                     SET @cWCSMessage = CHAR(2) +   + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cUCCNo) + '|' + @cTaskKey + '|' + @cWCSStation + '|' + CHAR(3)     
                    
                     EXEC [RDT].[rdt_GenericSendMsg]  
                      @nMobile      = @nMobile        
                     ,@nFunc        = @nFunc          
                     ,@cLangCode    = @cLangCode      
                     ,@nStep        = @nStep          
                     ,@nInputKey    = @nInputKey      
                     ,@cFacility    = @cFacility      
                     ,@cStorerKey   = @cStorerKey     
                     ,@cType        = @cDeviceType         
                     ,@cDeviceID    = @cDeviceID  
                     ,@cMessage     = @cWCSMessage       
                     ,@nErrNo       = @nErrNo       OUTPUT  
                     ,@cErrMsg      = @cErrMsg      OUTPUT     
                       
                     IF @nErrNo <> 0   
                     BEGIN  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                        GOTO RollBackTran  
                     END  
                       
                     -- To Shipping Route  
--                     SET @cWCSStation   = ''  
--                     SET @cPutawayZone  = ''   
--                     SET @cShipRouteLoc = ''  
--                     SET @cLoadKey      = ''  
--                       
--                     SELECT TOP 1 @cOrderKey = OrderKey   
--                     FROM dbo.PickDetail  WITH (NOLOCK)   
--                     WHERE TaskDetailKey = @cTaskKey   
--                       
--                     SELECT @cLoadKey = LoadKey   
--                     FROM dbo.LoadPlanDetail WITH (NOLOCK)   
--                     WHERE OrderKey = @cOrderKey  
--                       
--                     SELECT @cShipRouteLoc = Loc  
--                     FROM dbo.LoadPlanLaneDetail WITH (NOLOCK)   
--                     WHERE Loadkey = @cLoadKey  
--                       
--                     SELECT @cPutawayZone = PutawayZone   
--                     FROM dbo.Loc WITH (NOLOCK)   
--                     WHERE Facility = @cFacility   
--                     AND Loc = @cShipRouteLoc   
--                       
--                     SELECT @cWCSStation = Short                  
--                     FROM dbo.Codelkup WITH (NOLOCK)   
--                     WHERE ListName = 'WCSSTATION'  
--                     AND StorerKey = @cStorerKey  
--                     AND Code = @cPutawayZone  
--                       
--                       
--                     EXECUTE dbo.nspg_GetKey  
--                     'WCSKey',  
--                     10 ,  
--                     @cWCSKey           OUTPUT,  
--                     @bSuccess          OUTPUT,  
--                     @nErrNo            OUTPUT,  
--                     @cErrMsg           OUTPUT  
--                       
--                     IF @bSuccess <> 1  
--                     BEGIN  
--                        SET @nErrNo = 124706  
--                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
--                        GOTO RollBackTran  
--                     END  
--                       
--                     SET @cWCSSequence =  '02' --RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
--                     SET @cWCSMessage = CHAR(2) + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cUCCNo) + '|' + @cTaskKey + '|' + @cWCSStation + '|' + CHAR(3)   
--                       
--                     EXEC [RDT].[rdt_GenericSendMsg]  
--                      @nMobile      = @nMobile        
--                     ,@nFunc        = @nFunc          
--                     ,@cLangCode    = @cLangCode      
--                     ,@nStep        = @nStep          
--                     ,@nInputKey    = @nInputKey      
--                     ,@cFacility    = @cFacility      
--                     ,@cStorerKey   = @cStorerKey     
--                     ,@cType        = @cDeviceType         
--                     ,@cDeviceID    = @cDeviceID  
--                     ,@cMessage     = @cWCSMessage       
--                     ,@nErrNo       = @nErrNo       OUTPUT  
--                     ,@cErrMsg      = @cErrMsg      OUTPUT     
--                       
--                     IF @nErrNo <> 0   
--                     BEGIN  
--                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
--                        GOTO RollBackTran  
--                     END  
                       
                         
                  END  
                  ELSE IF @cMsg03 = 'PTS' AND ISNULL(@cWaveKey,'')  <> ''   
                  BEGIN  
                     -- To Packing Station  
--                     IF EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK)   
--                                 WHERE Facility = @cFacility  
--                                 AND Loc = @cFromLoc  
--                                 AND LocationCategory <> 'BULK')  
--                     BEGIN  
--                        SET @cWCSStation = ''  
--                        SET @cPreWCSStation = ''   
--                          
--                        SELECT @cWCSStation = Short                  
--                        FROM dbo.Codelkup WITH (NOLOCK)   
--                        WHERE ListName = 'WCSSTATION'  
--                        AND StorerKey = @cStorerKey  
--                        AND Code = 'CHECK'  
--                          
--                        EXECUTE dbo.nspg_GetKey  
--                        'WCSKey',  
--                        10 ,  
--                        @cWCSKey           OUTPUT,  
--                        @bSuccess          OUTPUT,  
--                        @nErrNo            OUTPUT,  
--                        @cErrMsg           OUTPUT  
--                          
--                        IF @bSuccess <> 1  
--                        BEGIN  
--                           SET @nErrNo = 124707  
--                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
--                           GOTO RollBackTran  
--                        END  
--                          
--                        SET @cWCSSequence =  '01' --RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
--                        SET @cWCSMessage = CHAR(2) + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cUCCNo) + '|' + @cTaskKey + '|' + @cWCSStation + '|' + CHAR(3)   
--                       
--                        EXEC [RDT].[rdt_GenericSendMsg]  
--                         @nMobile      = @nMobile        
--                        ,@nFunc        = @nFunc          
--                        ,@cLangCode    = @cLangCode      
--                        ,@nStep        = @nStep          
--                        ,@nInputKey    = @nInputKey      
--                        ,@cFacility    = @cFacility      
--                        ,@cStorerKey   = @cStorerKey     
--                        ,@cType        = @cDeviceType         
--                        ,@cDeviceID    = @cDeviceID  
--                        ,@cMessage     = @cWCSMessage       
--                        ,@nErrNo       = @nErrNo       OUTPUT  
--                        ,@cErrMsg      = @cErrMsg      OUTPUT     
--                          
--                        IF @nErrNo <> 0   
--                           GOTO RollBackTran  
--                          
--                        SET @nCount = 2   
--                     END  
--                     ELSE   
--                     BEGIN  
--                        SET @nCount = 1   
--                     END  
                         
                     SET @nCount = 1   
                       
                     SELECT @cSKUGroup = SUSR3   
                     FROM dbo.SKU WITH (NOLOCK)   
                     WHERE StorerKey = @cStorerKey  
                     AND SKU = @cSKU   
                       
                     SELECT @cShort = Short   
                     FROM dbo.Codelkup WITH (NOLOCK)   
                     WHERE ListName = 'SKUGroup'  
                     AND StorerKey = 'UA'  
                     AND Code = @cSKUGroup   
  
                     --SELECT @cSKUGroup '@cSKUGroup' , @cShort '@cShort'  ,@cSKU '@cSKU'   
                     
  
                     DECLARE CUR_PTS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
                       
                     SELECT L.PutawayZone FROM rdt.rdtPTLStationLog PTL WITH (NOLOCK)   
                     INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = PTL.OrderKey AND PD.WaveKey = PTL.WaveKey   
                     INNER JOIN dbo.LOC L WITH (NOLOCK) ON L.Facility = @cFacility AND L.Loc = PTL.LOC  
                     WHERE PTL.WaveKey = @cWaveKey  
                     --AND PTL.OrderKey  = @cOrderKey   
                     AND PTL.StorerKey = @cStorerKey   
                     AND PD.DropID = @cUCCNo   
                     AND PTL.UserDefine02 = @cShort  
                     GROUP BY L.PutawayZone  
                       
                                    
                     OPEN CUR_PTS   
                     FETCH NEXT FROM CUR_PTS INTO @cPutawayZone  
                     WHILE @@FETCH_STATUS <> -1  
                     BEGIN  
                        --SET @cPutawayZone = ''   
                        SET @cWCSStation  = ''  
                        --SET @nCount = 2   
                          
--                        SELECT @cPutawayZone = PutawayZone   
--                        FROM dbo.Loc WITH (NOLOCK)   
--                        WHERE Facility = @cFacility   
--                        AND Loc = @cPTSLoc   
                          
                        SELECT @cWCSStation = Short                  
                        FROM dbo.Codelkup WITH (NOLOCK)   
                        WHERE ListName = 'WCSSTATION'  
                        AND StorerKey = @cStorerKey  
                        AND Code = @cPutawayZone   
  
                        IF @cWCSStation <> ''--@cPreWCSStation  
                        BEGIN   
                          
                           EXECUTE dbo.nspg_GetKey  
                              'WCSKey',  
                              10 ,  
                              @cWCSKey           OUTPUT,  
                              @bSuccess          OUTPUT,  
                              @nErrNo            OUTPUT,  
                              @cErrMsg           OUTPUT  
                             
                           IF @bSuccess <> 1  
                           BEGIN  
                              SET @nErrNo = 124708  
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                              GOTO RollBackTran  
                           END  
                          
                           SET @cWCSSequence =  RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
                           SET @cWCSMessage = CHAR(2) + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cUCCNo) + '|' + @cTaskKey + '|' + @cWCSStation + '|' + CHAR(3)   
                       
                           EXEC [RDT].[rdt_GenericSendMsg]  
                            @nMobile      = @nMobile        
                           ,@nFunc        = @nFunc          
                           ,@cLangCode    = @cLangCode      
                           ,@nStep        = @nStep          
                           ,@nInputKey    = @nInputKey      
                           ,@cFacility    = @cFacility      
                           ,@cStorerKey   = @cStorerKey     
                           ,@cType        = @cDeviceType         
                           ,@cDeviceID    = @cDeviceID  
                           ,@cMessage     = @cWCSMessage       
                           ,@nErrNo       = @nErrNo       OUTPUT  
                           ,@cErrMsg      = @cErrMsg      OUTPUT    
                          
                           IF @nErrNo <> 0   
                           BEGIN  
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                              GOTO RollBackTran  
                           END  
  
                           SET @nCount = @nCount + 1   
                        END  
  
                          
                        SET @cPreWCSStation = @cWCSStation  
                          
                        FETCH NEXT FROM CUR_PTS INTO @cPutawayZone  
                     END  
                     CLOSE CUR_PTS  
                     DEALLOCATE CUR_PTS  
                         
                  END  
                  ELSE IF @cMsg03 = 'PACKSTATION' AND ISNULL(@cWaveKey,'')  = ''   
                  BEGIN  
--                     IF EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK)   
--                                 WHERE Facility = @cFacility  
--                                 AND Loc = @cFromLoc  
--                                 AND LocationCategory <> 'BULK')  
--                     BEGIN  
--                        SET @cWCSStation = ''  
--                          
--                        SELECT @cWCSStation = Short                  
--                        FROM dbo.Codelkup WITH (NOLOCK)   
--                        WHERE ListName = 'WCSSTATION'  
--                        AND StorerKey = @cStorerKey  
--                        AND Code = 'CHECK'  
--                          
--                        EXECUTE dbo.nspg_GetKey  
--                        'WCSKey',  
--                        10 ,  
--                        @cWCSKey           OUTPUT,  
--                        @bSuccess          OUTPUT,  
--                        @nErrNo            OUTPUT,  
--                        @cErrMsg           OUTPUT  
--                          
--                        IF @bSuccess <> 1  
--                        BEGIN  
--                           SET @nErrNo = 124709  
--                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
--                           GOTO RollBackTran  
--                        END  
--                          
--                        SET @cWCSSequence =  '01' --RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
--                      SET @cWCSMessage = CHAR(2) + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cUCCNo) + '|' + @cTaskKey + '|' + @cWCSStation + '|' + CHAR(3)   
--                       
--                        EXEC [RDT].[rdt_GenericSendMsg]  
--                         @nMobile      = @nMobile        
--                        ,@nFunc        = @nFunc          
--                        ,@cLangCode    = @cLangCode      
--                        ,@nStep        = @nStep          
--                        ,@nInputKey    = @nInputKey      
--                        ,@cFacility    = @cFacility      
--                        ,@cStorerKey   = @cStorerKey     
--                        ,@cType        = @cDeviceType         
--                        ,@cDeviceID    = @cDeviceID  
--                        ,@cMessage     = @cWCSMessage       
--                        ,@nErrNo       = @nErrNo       OUTPUT  
--                        ,@cErrMsg      = @cErrMsg      OUTPUT     
--                          
--                        IF @nErrNo <> 0   
--                           GOTO RollBackTran  
--                          
--                        SET @nCount = 2   
--                     END  
--                     ELSE   
--                     BEGIN  
--                        SET @nCount = 1   
--                     END  
                       
                     SET @nCount = 1   
                       
                     -- To Single Packing Area  
                     SET @cWCSStation = ''  
                       
                     SELECT @cWCSStation = Short                  
                     FROM dbo.Codelkup WITH (NOLOCK)   
                     WHERE ListName = 'WCSSTATION'  
                     AND StorerKey = @cStorerKey  
                     AND Code = 'SINGLE'  
                       
                     EXECUTE dbo.nspg_GetKey  
                     'WCSKey',  
                     10 ,  
                     @cWCSKey           OUTPUT,  
                     @bSuccess          OUTPUT,  
                     @nErrNo            OUTPUT,  
                     @cErrMsg           OUTPUT  
                       
                     IF @bSuccess <> 1  
                     BEGIN  
                        SET @nErrNo = 124710  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                        GOTO RollBackTran  
                     END  
                       
                     SET @cWCSSequence = RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
                     SET @cWCSMessage = CHAR(2) +   + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cUCCNo) + '|' + @cTaskKey + '|' + @cWCSStation + '|' + CHAR(3)     
                    
                     EXEC [RDT].[rdt_GenericSendMsg]  
                      @nMobile      = @nMobile        
                     ,@nFunc        = @nFunc          
                     ,@cLangCode    = @cLangCode      
                     ,@nStep        = @nStep          
                     ,@nInputKey    = @nInputKey      
                     ,@cFacility    = @cFacility      
                     ,@cStorerKey   = @cStorerKey     
                     ,@cType        = @cDeviceType         
                     ,@cDeviceID    = @cDeviceID  
                     ,@cMessage     = @cWCSMessage       
                     ,@nErrNo       = @nErrNo       OUTPUT  
                     ,@cErrMsg      = @cErrMsg      OUTPUT     
                       
                     IF @nErrNo <> 0   
                     BEGIN         
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                        GOTO RollBackTran  
                     END  
                  END  
                  ELSE IF @cMsg03 = 'PICKLOC'  
                  BEGIN  
--                     IF EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK)   
--                                 WHERE Facility = @cFacility  
--                                 AND Loc = @cFromLoc  
--                           AND LocationCategory <> 'BULK')  
--                     BEGIN  
--                        SET @cWCSStation = ''  
--                          
--                        SELECT @cWCSStation = Short                  
--                        FROM dbo.Codelkup WITH (NOLOCK)   
--                        WHERE ListName = 'WCSSTATION'  
--                        AND StorerKey = @cStorerKey  
--                        AND Code = 'CHECK'  
--                          
--                        EXECUTE dbo.nspg_GetKey  
--                        'WCSKey',  
--                        10 ,  
--                        @cWCSKey           OUTPUT,  
--                        @bSuccess          OUTPUT,  
--                        @nErrNo            OUTPUT,  
--                        @cErrMsg           OUTPUT  
--                          
--                        IF @bSuccess <> 1  
--                        BEGIN  
--                           SET @nErrNo = 124711  
--                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
--                           GOTO RollBackTran  
--                        END  
--                          
--                        SET @cWCSSequence =  '01' --RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
--                        SET @cWCSMessage = CHAR(2) + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cUCCNo) + '|' + @cTaskKey + '|' + @cWCSStation + '|' + CHAR(3)   
--                       
--                        EXEC [RDT].[rdt_GenericSendMsg]  
--                         @nMobile      = @nMobile        
--                        ,@nFunc        = @nFunc          
--                        ,@cLangCode    = @cLangCode      
--                        ,@nStep        = @nStep          
--                        ,@nInputKey    = @nInputKey      
--                        ,@cFacility    = @cFacility      
--                        ,@cStorerKey   = @cStorerKey     
--                        ,@cType        = @cDeviceType         
--                        ,@cDeviceID    = @cDeviceID  
--                        ,@cMessage     = @cWCSMessage       
--                        ,@nErrNo       = @nErrNo       OUTPUT  
--                        ,@cErrMsg      = @cErrMsg      OUTPUT     
--                          
--                        IF @nErrNo <> 0   
--                           GOTO RollBackTran  
--                          
--                        SET @nCount = 2   
--                     END  
--                     ELSE   
--                     BEGIN  
--                        SET @nCount = 1   
--                     END  
                       
                     SET @nCount = 1   
                       
                     SET @cPutawayZone = ''    
                     SET @cWCSStation = ''   
                       
                     SELECT @cPutawayZone = PutawayZone   
                     FROM dbo.Loc WITH (NOLOCK)   
                     WHERE Facility = @cFacility   
                     AND Loc = @cFinalLOC  
                       
                     SELECT @cWCSStation = Short                  
                     FROM dbo.Codelkup WITH (NOLOCK)   
                     WHERE ListName = 'WCSSTATION'  
                     AND StorerKey = @cStorerKey  
                     AND Code = @cPutawayZone  
                       
                       
                     EXECUTE dbo.nspg_GetKey  
                     'WCSKey',  
                     10 ,  
                     @cWCSKey           OUTPUT,  
                     @bSuccess          OUTPUT,  
                     @nErrNo            OUTPUT,  
                     @cErrMsg           OUTPUT  
                       
                     IF @bSuccess <> 1  
                     BEGIN  
                        SET @nErrNo = 124706  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                        GOTO RollBackTran  
                     END  
                       
                     SET @cWCSSequence = RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
                     SET @cWCSMessage = CHAR(2) + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cUCCNo) + '|' + @cTaskKey + '|' + @cWCSStation + '|' + CHAR(3)   
                       
                     EXEC [RDT].[rdt_GenericSendMsg]  
                      @nMobile      = @nMobile        
                     ,@nFunc        = @nFunc          
                     ,@cLangCode    = @cLangCode      
                     ,@nStep        = @nStep          
                     ,@nInputKey    = @nInputKey      
                     ,@cFacility    = @cFacility      
                     ,@cStorerKey   = @cStorerKey     
                     ,@cType        = @cDeviceType         
                     ,@cDeviceID    = @cDeviceID  
                     ,@cMessage     = @cWCSMessage       
                     ,@nErrNo       = @nErrNo       OUTPUT  
                     ,@cErrMsg      = @cErrMsg      OUTPUT     
                       
                     IF @nErrNo <> 0   
                     BEGIN  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                        GOTO RollBackTran  
                     END  
                       
                  END  
               END  
            END  
  
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus, @cUCCNo, @nUCCQTY, @nSystemQTY, @cToLOC, @cToID, @cFinalLOC, @cMsg03, @cWaveKey, @cFromLoc, @cSKU  
         END  
  
         COMMIT TRAN rdt_1764ExtUpd06 -- Only commit change made here  
      END  
  
      IF @nStep = 9 -- Reason  
      BEGIN  
            
  
         -- Get task info  
         SELECT  
            @cUserKey    = UserKey,  
            @cStatus     = Status,  
            @cReasonKey  = ReasonKey,  
            @cPickMethod = PickMethod,  
            @cFromID     = FromID,   
            @cToLOC      = ToLOC,   
            @cRefTaskKey = RefTaskKey,  
            @cTaskType   = TaskType  
         FROM dbo.TaskDetail WITH (NOLOCK)  
         WHERE TaskdetailKey = @cTaskdetailKey  
  
         -- Get TaskStatus  
         DECLARE @cTaskStatus NVARCHAR(10)  
         SELECT @cTaskStatus = TaskStatus  
         FROM dbo.TaskManagerReason WITH (NOLOCK)  
         WHERE TaskManagerReasonKey = @cReasonKey  
  
         /* TaskManagerReason must setup as:  
  
            TaskManagerReasonKey RemoveTaskFromUserQueue TaskStatus ContinueProcessing  
            -------------------- ----------------------- ---------- ------------------  
            SKIP                 1                       0          0                   
            SHORT                0                                  1                   
            CANCEL               1                       X          0                   
         */  
  
  
         IF @cTaskStatus = '' -- For short pick  
            GOTO Quit  
  
         -- Get own task  
         INSERT INTO @tTask (TaskDetailKey)  
         SELECT @cTaskDetailKey  
  
         -- Get other tasks that perform at once  
         IF @cRefTaskKey <> ''  
            INSERT INTO @tTask (TaskDetailKey)  
            SELECT TaskDetailKey  
            FROM dbo.TaskDetail WITH (NOLOCK)  
            WHERE RefTaskKey = @cRefTaskKey  
               AND TaskdetailKey <> @cTaskdetailKey  
               AND TaskType = 'RPF'  
               AND PickMethod = 'FP' -- Task perform at once in nspTTMEvaluateRPFTasks, for FP only  
  
         DECLARE @cTaskFromLOT   NVARCHAR( 10)  
         DECLARE @cTaskFromLOC   NVARCHAR( 10)   
         DECLARE @cTaskFromID    NVARCHAR( 18)  
         DECLARE @cTaskStorerKey NVARCHAR( 15)  
         DECLARE @cTaskSKU       NVARCHAR( 20)  
         DECLARE @cTaskUCC       NVARCHAR( 20)  
         DECLARE @cTransitLOC    NVARCHAR( 10)  
         DECLARE @cFinalID       NVARCHAR( 18)  
  
   
  
         IF @cTaskType = 'RPF'  
         BEGIN  
              
  
            -- Loop task  
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT TD.TaskDetailKey, TD.LOT, TD.FromLOC, TD.FromID, TD.StorerKey, TD.SKU, TD.QTY, TD.TransitLOC, TD.FinalLOC, TD.FinalID  
               FROM @tTask t  
                  JOIN TaskDetail TD WITH (NOLOCK) ON (t.TaskDetailKey = TD.TaskDetailKey)  
            OPEN @curTask  
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cTaskFromLOT, @cTaskFromLOC, @cTaskFromID, @cTaskStorerKey, @cTaskSKU, @nTaskQTY,   
               @cTransitLOC, @cFinalLOC, @cFinalID  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               -- Update other tasks  
               IF @cTransitLOC = ''  
                  UPDATE dbo.TaskDetail SET  
                      Status = @cStatus  
                     ,UserKey = @cUserKey  
                     ,ReasonKey = @cReasonKey  
                     ,RefTaskKey = ''  
                     ,ListKey = ''  
                     ,CaseID = ''  
                     ,DropID = ''  
                     ,EditDate = GETDATE()  
                     ,EditWho  = SUSER_SNAME()  
                     ,TrafficCop = NULL  
                  WHERE TaskDetailKey = @cTaskKey  
               ELSE  
                  UPDATE dbo.TaskDetail SET  
                      Status = @cStatus  
                     ,UserKey = @cUserKey  
                     ,ReasonKey = @cReasonKey  
                     ,RefTaskKey = ''  
                     ,TransitLOC = ''  
                     ,FinalLOC = ''  
                     ,FinalID = ''  
                     ,ToLOC = @cFinalLOC  
                     ,ToID = @cFinalID  
                     ,ListKey = ''  
                     ,CaseID = ''  
                     ,DropID = ''  
                     ,EditDate = GETDATE()  
                     ,EditWho  = SUSER_SNAME()  
                     ,TrafficCop = NULL  
                  WHERE TaskDetailKey = @cTaskKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 124703  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail  
                  GOTO RollBackTran  
               END  
                 
               -- Generate alert  
               EXEC nspLogAlert  
                    @c_modulename       = 'RPF'  
                  , @c_AlertMessage     = 'SHORT/CANCEL'  
                  , @n_Severity         = '5'  
                  , @b_Success          = @b_Success      OUTPUT  
                  , @n_err              = @n_Err          OUTPUT  
                  , @c_errmsg           = @c_ErrMsg       OUTPUT  
                  , @c_Activity         = 'RPF'  
                  , @c_Storerkey        = @cTaskStorerKey  
                  , @c_SKU              = @cTaskSKU  
                  , @c_UOM              = ''  
                  , @c_UOMQty           = ''  
                  , @c_Qty              = @nTaskQTY  
                  , @c_Lot              = @cTaskFromLOT  
                  , @c_Loc              = @cTaskFromLOC  
                  , @c_ID               = @cTaskFromID  
                  , @c_TaskDetailKey    = @cTaskKey  
                 
               FETCH NEXT FROM @curTask INTO @cTaskKey, @cTaskFromLOT, @cTaskFromLOC, @cTaskFromID, @cTaskStorerKey, @cTaskSKU, @nTaskQTY,   
                  @cTransitLOC, @cFinalLOC, @cFinalID  
            END  
     
            -- Loop PickDetail  
            SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
               SELECT PickDetailKey  
               FROM dbo.PickDetail WITH (NOLOCK)  
               WHERE TaskdetailKey IN (SELECT TaskdetailKey FROM @tTask)  
            OPEN @curPD  
            FETCH NEXT FROM @curPD INTO @cPickDetailKey  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               -- Reset Status  
               UPDATE dbo.PickDetail SET  
                   DropID = ''  
                  ,EditDate = GETDATE()  
                  ,EditWho  = SUSER_SNAME()  
                  ,TrafficCop = NULL  
               WHERE PickDetailKey = @cPickDetailKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 124704  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
                  GOTO RollBackTran  
               END  
               FETCH NEXT FROM @curPD INTO @cPickDetailKey  
            END  
         END  
  
         IF @cPickMethod = 'FP'  
         BEGIN  
            -- Unlock SuggestedLOC  
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
               ,'' --@cSuggFromLOC  
               ,@cFromID   
               ,'' --@cSuggToLOC  
               ,@cStorerKey  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
            IF @nErrNo <> 0  
               GOTO RollBackTran  
         END  
  
         IF @cPickMethod = 'PP'  
         BEGIN  
            -- Unlock  suggested location  
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
               ,''      --@cFromLOC  
               ,@cFromID--@cFromID  
               ,@cToLOC --@cSuggestedLOC  
               ,''      --@cStorerKey  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
            IF @nErrNo <> 0  
               GOTO RollBackTran  
         END  
  
         COMMIT TRAN rdt_1764ExtUpd06 -- Only commit change made here  
      END  
   END  
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_1764ExtUpd06 -- Only rollback change made here  
Fail:  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO