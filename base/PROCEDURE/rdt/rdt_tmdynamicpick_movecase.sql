SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/          
/* Store procedure: rdt_TMDynamicPick_MoveCase                               */          
/* Copyright      : IDS                                                      */          
/*                                                                           */          
/* Purpose: Move Dynamic DPK/DRP Case to Induction Area                      */          
/*          Called By rdtfnc_TM_DynamicPick                                  */          
/*                                                                           */          
/* Modifications log:                                                        */          
/*                                                                           */          
/* Date       Rev  Author   Purposes                                         */          
/* 09-10-2010 1.0  Shong    Created                                          */    
/* 20-10-2010 1.1  Shong    Include Loadkey into PA Task                     */        
/* 25-01-2011 1.2  James    Only create 1 PA Task eventhough >1 Lot (james01)*/      
/* 16-02-2011 1.3  James    SOS205891 - Bug fix (james02)                    */      
/* 04-05-2011 1.4  James    SOS214200 - Cater for DPK/DRP task which do not  */  
/*                          have any more qty to take (james03)              */      
/* 11-07-2011 1.5  James    Bug fix (james04)                                */  
/* 01-06-2012 1.6  TLTING01 Deadlock Tune - move update taskdetail down      */  
/* 28-07-2016 1.7  James    IN00107908-Pass in taskdetailkey as MoveRefKey to*/  
/*                          prevent pickdetail been update to ws01 (james05) */
/*****************************************************************************/          
CREATE PROC [RDT].[rdt_TMDynamicPick_MoveCase]   
   @cDropID             NVARCHAR(18),  
   @cTaskdetailkey      NVARCHAR(10),  
   @cUserName           NVARCHAR(18),          
   @cToLoc              NVARCHAR(10),  
   @nErrNo              INT OUTPUT,  
   @cErrMsg             NVARCHAR(215) OUTPUT      
AS
-- Misc variable              
DECLARE              
   @b_success           INT              
  
-- Define a variable              
DECLARE                
   @nFunc               INT,              
   @nScn                INT,              
   @nStep               INT,              
   @cLangCode           NVARCHAR(3),              
   @nMenu               INT,              
   @nInputKey           NVARCHAR(3),              
   @cPrinter            NVARCHAR(10),              
   @nTranCount          INT,            
   @cStorerKey          NVARCHAR(15),            
   @cCaseID             NVARCHAR(10),  
              
                 
   @cFacility           NVARCHAR(5),              
   @cSku                NVARCHAR(20),              
   @cAltSKU             NVARCHAR(20),              
   @cDescr              NVARCHAR(60),              
   @cSuggFromLoc        NVARCHAR(10),              
   @cSuggLot            NVARCHAR(10),              
   @cSuggToLoc          NVARCHAR(10),              
   @cFromLoc            NVARCHAR(10),              
   @cDefaultToLoc       NVARCHAR(10),              
             
   @cSuggID             NVARCHAR(18),              
   @cID                 NVARCHAR(18),              
   @cMUOM_Desc          NVARCHAR( 5),              
                 
   @cPickType           NVARCHAR(10),              
   @cUserPosition       NVARCHAR(1),              
                            
   @cLoadkey            NVARCHAR(10),              
   @nTaskQty            INT,              
   @nPAQty              INT,              
   @nPickDetQty         INT,              
   @nAllocatedQty       INT,              
   @nQtyToTake          INT,              
   @nQtyAllocToTake     INT,              
   @nQtyExtra           INT,              
   @cAreaKey            NVARCHAR(10),              
   @cPickLoc            NVARCHAR(10),               
   @cTTMStrategykey     NVARCHAR(10),               
   @cTTMTasktype        NVARCHAR(10),              
   @nFromStep           INT,              
   @nFromScn            INT,              
   @cRefKey01           NVARCHAR(20),              
   @cRefKey02           NVARCHAR(20),              
   @cRefKey03           NVARCHAR(20),              
   @cRefKey04           NVARCHAR(20),              
   @cRefKey05           NVARCHAR(20),              
   @cPrepackByBOM       NVARCHAR( 1),                 @cBOMSku             NVARCHAR(20),              
   @nBomCnt             INT,              
   @cComponentSku       NVARCHAR(20),              
   @cUom                NVARCHAR(5),              
                 
   @cPickdetailkey NVARCHAR(10),              
   @nPKQty              INT,              
   @nPickRemainQty      INT,              
   @nAvailQty           INT,              
   @nMoveQty            INT,              
   @cNewPickdetailkey   NVARCHAR(10),              
   @c_outstring         NVARCHAR(255),              
   @cOption             NVARCHAR(1),              
   @cNextTaskdetailkey  NVARCHAR(10),              
   @cNewLoc             NVARCHAR(10),              
   @cNewID              NVARCHAR(18),              
   @cLogSku             NVARCHAR(20),              
   @cLot                NVARCHAR(10),              
   @cLogLoc             NVARCHAR(10),              
   @cLogID              NVARCHAR(18),              
   @cLogLot             NVARCHAR(10),              
   @nLogQty             INT,              
   @cLogCaseID          NVARCHAR(10),              
   @cLogBOMSku          NVARCHAR(20),              
   @cPrevCaseID         NVARCHAR(10),              
  
   @cPALoc              NVARCHAR(10),              
   @cPATaskdetailkey    NVARCHAR(10),              
   @nToFunc             INT,              
   @nToScn              INT,              
   @cReasonCode         NVARCHAR(10),              
   @cPickToZone         NVARCHAR(10),              
   @cTitle              NVARCHAR(20),              
   @cSuggSKU            NVARCHAR(20),              
   @cPackKey            NVARCHAR(10),              
   @bProcessStart       INT,              
   @cLogicalFromLoc     NVARCHAR(18),              
   @cLogicalToLoc       NVARCHAR(18),              
   @cPAStatus           NVARCHAR(1),              
   @nSumQtyShort        INT,              
   @cShortLot           NVARCHAR(10),              
   @cBoxQty             NVARCHAR(5),              
   @nBoxQty             INT,              
   @cContinueProcess    NVARCHAR(10),              
   @nCompSKU            INT,        --(Kc07)              
   @bSuccess            INT,        --(KC10)              
   @cActionFlag         NVARCHAR(1),    --(Shong01)           
   @nQtyPicked          INT,        --(james01)          
   @nTD_Qty             INT,        
   @nPD_Qty             INT,        
   @cTTMTaskTypeLog     NVARCHAR(10),   -- (ChewKP02)    
   @cTTMTaskLot         NVARCHAR(10),     
   @cTTMTaskID          NVARCHAR(18),  
   @cReplenPriority     NVARCHAR(5),    -- (james03)    
   @nReplenQty          INT,        -- (james04)    
   @nQtyMoved           INT,        -- (james05)    
   @cReasonStatus       NVARCHAR(10),   -- (james06)    
   @nQtyToMoved         INT,        -- (jamesxx)  
   @nRowRef             INT,        -- (Shong10)  
   @cNewTaskDetailKey   NVARCHAR(10),   -- (james03)    
  
   @nQtyAvailable       INT,  
   @nQty                INT,   
   @nTK_Qty             INT,   
   @nNewTK_Qty          INT,   
   @nOri_Qty            INT   
  
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
     
   SET @cPrevCaseID = ''              
   SET @cLogSKU = ''              
   SET @cLogID = ''              
   SET @cLogLot = ''              
   SET @nPAQty = 0                         
   SET @cLogCaseID = ''              
   SET @cUserPosition = '2'  
  
--   INSERT INTO TRACEINFO (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5,  
--               Col1, Col2, Col3, Col4, Col5) VALUES   
--               ('DPK_MOVE', GETDATE(), @cTaskdetailkey, @cUserName, @cToLoc,@cDropID,'','','','','','')  
                  
                 
   SELECT @cTTMTaskTypeLog = TaskType,   
          @cTTMTaskLot     = Lot,  
          @cTTMTaskID      = FROMID,      
          @nTaskQty        = Qty,   
          @cStorerKey      = Storerkey,  
          @cTTMTaskType    = TaskType,  
          @cLoadkey        = ISNULL(LoadKey,'')     
   FROM TaskDetail WITH (NOLOCK)      
   WHERE TaskDetailkey = @cTaskdetailkey      
  
  
   -- Check Inv available here  
   SET @nQtyToMoved=0  
   SELECT @cLogLoc = FromLOC,   
          @cLogSKU = SKU,   
  @nQtyToMoved = SUM(QtyMove)  
   FROM   rdt.rdtDPKLog WITH (NOLOCK)              
   WHERE  UserKey = @cUserName -- (Shong10)              
   AND    Taskdetailkey = @cTaskdetailkey   
   AND    DropID = @cDropID    
   GROUP BY FromLOC, SKU              
     
   SET @nQtyAvailable=0  
   SELECT @nQtyAvailable = ISNULL(SUM(Qty-QtyPicked),0)       
   FROM SKUxLOC (NOLOCK)               
   WHERE StorerKey = @cStorerKey  
   AND   SKU = @cLogSKU                         
   AND   LOC = @cLogLoc               
     
   IF @nQtyAvailable < @nQtyToMoved  
   BEGIN              
      ROLLBACK TRAN              
      SET @nErrNo = 70145              
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvMVNotAvail              
      GOTO QUIT                 
   END              
     
   -- Clean Up WCSRouting Table   
   DECLARE CUR_CLEAN_WCS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT WCS.ToteNo  
   FROM WCSRouting WCS WITH (NOLOCK)  
   JOIN rdt.rdtDPKLog DPK WITH (NOLOCK) ON WCS.ToteNo = DPK.CaseID              
   WHERE DPK.DROPID = @cDropID   
   AND   DPK.UserKey = @cUserName -- (Shong10)                 
   AND   DPK.Taskdetailkey = @cTaskdetailkey   
      
   OPEN  CUR_CLEAN_WCS   
     
   FETCH NEXT FROM  CUR_CLEAN_WCS INTO @cCaseID   
   BEGIN  
      UPDATE WCSRouting   
      SET [Status] = '9',  
          EditWho = SUSER_SNAME(),   
          EditDate = GETDATE()   
      WHERE ToteNo = @cCaseID   
        
      FETCH NEXT FROM  CUR_CLEAN_WCS INTO @cCaseID  
   END   
   CLOSE CUR_CLEAN_WCS   
   DEALLOCATE CUR_CLEAN_WCS   
   SET @cCaseID = ''  
   -- END Clean Old WCSRouting  
                              
   -- perform inventory move              
   DECLARE C_DPK_MOVE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
   SELECT SKU, FromLoc,  QtyMove,  
          CaseId, BOMSku,  
          PAQty, RowRef, FromLot  
   FROM   rdt.rdtDPKLog WITH (NOLOCK)              
   WHERE  DROPID = @cDropID   
   AND    UserKey = @cUserName -- (Shong10)                 
   AND    Taskdetailkey = @cTaskdetailkey   
   ORDER BY CaseID             
              
   OPEN C_DPK_MOVE  
              
   FETCH NEXT FROM C_DPK_MOVE INTO    
               @cLogSKU, @cLogLoc,    
               @nLogQty, @cCaseId,  @cLogBOMSku,   
               @nPAQty,  @nRowRef,  @cSuggLot  
                                                                  
   WHILE (@@FETCH_STATUS <> -1)              
   BEGIN  
      SET @nTaskQty=0  
        
      SET @nQtyAvailable=0  
      SELECT @nQtyAvailable = ISNULL(SUM(Qty-QtyPicked),0)       
      FROM SKUxLOC (NOLOCK)               
      WHERE StorerKey = @cStorerKey  
      AND   SKU = @cLogSKU                         
      AND   LOC = @cLogLoc               
  
      SELECT @cFacility = FACILITY   
      FROM   LOC (NOLOCK)   
      WHERE  LOC = @cLogLoc    
                    
      IF @nQtyAvailable < @nLogQty   
      BEGIN              
         ROLLBACK TRAN              
         SET @nErrNo = 70145              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvMVNotAvail              
         GOTO QUIT                 
      END              
        
/*********************************************************************/   
--   Move Update taskddetail script FROM  
/*********************************************************************/   
              
  
      WHILE @nLogQty > 0   
      BEGIN  
         --(SHONGxx)  
         -----------------  
         IF @cTTMTaskType = 'DPK'              
         BEGIN              
            IF NOT EXISTS (SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK) WHERE ToteNo = @cCaseID AND Status = '0')  
BEGIN  
          SET @cErrMsg = ''              
               EXEC dbo.nspInsertWCSRouting              
                @c_Storerkey     = @cStorerKey              
               ,@c_Facility      = @cFacility              
               ,@c_ToteNo        = @cCaseID      
               ,@c_TaskType      = 'PK'              
               ,@c_ActionFlag    = 'N'              
               ,@c_TaskDetailKey = @cTaskdetailkey              
               ,@c_Username      = @cUsername              
               ,@b_debug         = 0              
               ,@b_Success       = @b_Success   OUTPUT              
               ,@n_ErrNo         = @nErrNo      OUTPUT              
               ,@c_ErrMsg        = @cErrMsg     OUTPUT              
                 
               IF ISNULL(RTRIM(@cErrMsg),'') <> ''              
               BEGIN              
                  ROLLBACK TRAN              
                  SET @nErrNo = @nErrNo              
                  SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'              
                  GOTO QUIT                 
               END              
            END  
         END -- @cTTMTaskType = 'DPK'                       
         -----------------  
         SET @nQty=0  
           
         DECLARE CUR_LOTxLOCxID_MOVE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT LOT, ID,   
                ISNULL(QTY-QtyPicked,0),  
                ISNULL(QtyAllocated,0)    
         FROM   LOTxLOCxID WITH (NOLOCK)  
         WHERE  StorerKey = @cStorerKey   
         AND    SKU = @cLogSku   
         AND    LOC = @cLogLoc      
         AND    QTY-QtyPicked > 0   
         ORDER BY CASE WHEN LOT = @cSuggLot THEN 1   
                       WHEN LOT = @cTTMTaskLot THEN 2   
                       WHEN QtyAllocated = 0 THEN 3  
                       ELSE 9  
                  END  
              
         OPEN CUR_LOTxLOCxID_MOVE   
           
         FETCH NEXT FROM CUR_LOTxLOCxID_MOVE INTO @cLogLot, @cLogID, @nQty, @nAllocatedQty   
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            SET @nQtyToTake = 0   
              
            -- If Qty Available > Qty Move   
            IF @nQty >= @nLogQty   
            BEGIN  
               SET @nQtyToTake = @nLogQty   
               SET @nQtyAllocToTake=0                 
            END  
            ELSE IF @nQty + @nAllocatedQty >= @nLogQty   
            BEGIN  
               SET @nQtyToTake = @nLogQty  
               SET @nQtyAllocToTake = @nLogQty - @nQty    
            END  
            ELSE  
            BEGIN  
               SET @nQtyToTake = @nQty + @nAllocatedQty   
               SET @nQtyAllocToTake = @nAllocatedQty  
            END  
  
            IF @nQtyAllocToTake > 0   
            BEGIN  
               SET @cPickLoc=''  
                 
               SELECT TOP 1 @cPickLoc = LOC  
               FROM   SKUxLOC WITH (NOLOCK)  
               WHERE  StorerKey = @cStorerKey   
               AND    SKu = @cSku  
               AND    LocationType IN ('PICK','CASE')  
                 
               IF ISNULL(RTRIM(@cPickLoc),'') = ''   
               BEGIN  
                  ROLLBACK TRAN              
                  SET @nErrNo = 70147              
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPPALoc              
                  GOTO QUIT                 
               END  
                 
               -- Swap The PickDetail Loc from BULK to Pick LOC  
               DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT p.PickDetailKey, p.Qty   
               FROM PICKDETAIL p WITH (NOLOCK)   
               WHERE p.Lot = @cLogLot   
               AND   p.loc = @cLogLoc   
               AND   p.id  = @cLogID   
               AND   p.[Status] = '0'   
               AND   (p.TaskDetailKey = '' OR p.TaskDetailKey IS NULL)  
               AND   p.Qty > 0  
               ORDER BY p.LOC, p.PickDetailKey DESC  
      
               OPEN CUR_PICKDETAIL   
                 
               FETCH NEXT FROM CUR_PICKDETAIL INTO @cPickdetailkey, @nPickDetQty   
               WHILE @@FETCH_STATUS <> -1  
               BEGIN  
                  UPDATE Pickdetail WITH (ROWLOCK)   
                     SET LOC = @cPickLoc,   
                         ID  = ''  
                  WHERE Pickdetail.PickDetailKey = @cPickdetailkey   
                  IF @@ERROR<> 0   
                  BEGIN  
                     ROLLBACK TRAN              
                     SET @nErrNo = 70127    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetailFail    
                     GOTO QUIT                                      
                  END  
                                      
                  SET @nQtyAllocToTake = @nQtyAllocToTake - @nPickDetQty  
                     
                  IF @nQtyAllocToTake <= 0   
                     BREAK   
                    
                  FETCH NEXT FROM CUR_PICKDETAIL INTO @cPickdetailkey, @nPickDetQty   
               END  
               CLOSE CUR_PICKDETAIL  
               DEALLOCATE CUR_PICKDETAIL   
            END  
  
            SELECT @cPackKey = SKU.PackKey,   
                   @cUOM     = PACK.PACKUOM3   
            FROM   SKU WITH (NOLOCK)   
            JOIN   PACK WITH (NOLOCK) ON SKU.PACKKEY = PACK.PackKey   
            WHERE  StorerKey = @cStorerKey   
              AND  SKU = @cSKU   
                 
            EXECUTE nspItrnAddMove                  
               @n_ItrnSysId    = NULL,                    
               @c_itrnkey      = NULL,                  
               @c_Storerkey    = @cStorerKey,                  
               @c_SKU          = @cLogSKU,                  
               @c_Lot          = @cLogLot,                  
               @c_FromLoc      = @cLogLoc,                  
               @c_FromID       = @cLogID,                   
               @c_ToLoc        = @cToLoc,                   
               @c_ToID         = '',                  
               @c_Status       = '',                  
               @c_Lottable01   = @cCaseId,                  
               @c_Lottable02   = '',                  
               @c_Lottable03   = '',                  
               @d_Lottable04   = NULL,                  
               @d_Lottable05   = NULL,                  
               @n_casecnt      = 0,                  
               @n_innerpack    = 0,                        
               @n_Qty          = @nQtyToTake,                  
               @n_Pallet       = 0,                  
               @f_Cube         = 0,                  
               @f_GrossWgt     = 0,                  
               @f_NetWgt       = 0,                 
               @f_OtherUnit1   = 0,                  
               @f_OtherUnit2   = 0,                  
               @c_SourceKey    = @cTaskdetailkey,                  
               @c_SourceType   = @cTTMTaskType,                  
               @c_PackKey      = @cPackKey,                  
               @c_UOM          = @cUOM,                  
               @b_UOMCalc      = 1,                  
               @d_EffectiveDate = NULL,                  
               @b_Success      = @b_Success  OUTPUT,                  
               @n_err          = @nErrNo     OUTPUT,                  
               @c_errmsg       = @cErrmsg    OUTPUT,
               @c_MoveRefKey   = @cTaskdetailkey
                    
            IF ISNULL(RTRIM(@cErrMsg),'') <> ''              
            BEGIN              
               ROLLBACK TRAN              
               SET @nErrNo = @nErrNo              
               SET @cErrMsg = @cErrmsg              
               GOTO QUIT                 
            END              
                    
            SET @nLogQty = @nLogQty - @nQtyToTake   
            IF @nLogQty = 0  
               BREAK   
                 
            FETCH NEXT FROM CUR_LOTxLOCxID_MOVE INTO @cLogLot, @cLogID, @nQty, @nAllocatedQty  
         END  
         CLOSE CUR_LOTxLOCxID_MOVE   
         DEALLOCATE CUR_LOTxLOCxID_MOVE   
      END  

/*********************************************************************/    
      -- TLTING01     - after Itrn move.  
      -- Possible deadlock - update taskdetail before & update itrn move.   
      UPDATE dbo.TASKDETAIL WITH (ROWLOCK)                
      SET   LogicalToloc = @cToLoc,    
            DropID = @cDropID,                
            UserPosition = @cUserPosition, --(Kc09)                
            TrafficCOP = NULL                
      WHERE Taskdetailkey = @cTaskdetailkey                
      IF @@ERROR <> 0                
      BEGIN                
         ROLLBACK TRAN                
         SET @nErrNo = 70164                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail                
         GOTO QUIT                   
      END                   
  
/*********************************************************************/  
          
      IF @nPAQty > 0   
      BEGIN  
         -- (Shong10)  
         SET @cPALoc = ''  
         SELECT @cTTMTaskTypeLog = TaskType,   
                @cPALoc = ToLoc     
         FROM TaskDetail WITH (NOLOCK)      
         WHERE TaskDetailkey = @cTaskdetailkey      
                       
         SET @cLogicalToloc = ''              
               
         IF @cTTMTaskTypeLog = 'DPK'           
         BEGIN  
            SET @cPALoc = ''     
            SELECT @cPALoc = ISNULL(RTRIM(SL.LOC),'')              
                  ,@cLogicalToLoc = ISNULL(RTRIM(LOC.LogicalLocation),'')     
                  ,@cReplenPriority = ISNULL(ReplenishmentPriority, '9')       
            FROM dbo.SKUXLOC SL  WITH (NOLOCK)              
            JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.LOC = SL.LOC              
            WHERE SL.Sku = @cLogSKU              
            AND   SL.LocationType = 'PICK'          
                 
            SET @cPAStatus   = 'W' -- (Vicky01)        
            SET @cActionFlag = 'R' -- (Shong01)          
         END          
         ELSE IF @cTTMTaskTypeLog = 'DRP' -- (Vicky04)              
         BEGIN         
            -- (Shong10)   
            SELECT @cLogicalToLoc = ISNULL(RTRIM(LOC.LogicalLocation),'')     
            FROM dbo.LOC LOC WITH (NOLOCK)                     
            WHERE LOC = @cPALoc  
              
            SET @cReplenPriority = '5'   
            SET @cPAStatus   = '0'          
            SET @cActionFlag = 'N' -- (Shong01)          
         END              
         -- End (ChewKP02)      
  
         IF ISNULL(RTRIM(@cPALoc),'') = ''              
         BEGIN              
            ROLLBACK TRAN              
            SET @nErrNo = 70147              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPPALoc              
            GOTO QUIT                 
         END              
  
         -- (james01)  
         IF NOT EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)   
            WHERE Storerkey = @cStorerKey  
               AND RefTaskKey = @cTaskdetailkey  
               AND TaskType = 'PA'  
               AND CaseID = @cCaseId)  -- james02  
         BEGIN  
            SELECT @b_success = 1                    
            EXECUTE   dbo.nspg_getkey                     
            'TaskDetailKey'                    
            , 10                    
            , @cPATaskdetailkey OUTPUT                    
            , @b_success OUTPUT                    
            , @nErrNo   OUTPUT                    
            , @cErrMsg  OUTPUT                 
                 
            IF NOT @b_success = 1                    
            BEGIN                    
               ROLLBACK TRAN              
               GOTO QUIT                                    
            END                 
  
            --(KC01)              
            INSERT TASKDETAIL                    
               ( TaskDetailKey   ,TaskType      ,Storerkey        ,Sku                                      
                ,Lot             ,FromLoc       ,LogicalFromLoc   ,LoadKey                                    
                ,ToLoc           ,LogicalToLoc  ,CaseID           ,SourceType                               
                ,UOM             ,UOMQTY        ,QTY              ,Sourcekey                
                ,RefTaskKey      ,Priority      ,STATUS           ,SystemQty                   
                )                    
            VALUES                    
                ( @cPATaskdetailkey    ,'PA'             ,@cStorerKey      ,@cLogSKU                    
                ,@cLogLot              ,@cToLoc          ,@cToLoc          ,ISNULL(@cLoadkey,'')           
                ,@cPALoc               ,@cLogicalToloc   ,@cCaseId         ,@cTTMTaskTypeLog     
                ,'6' ,@nPAQty    ,@nPAQty          ,@cLogBOMSKU                   
                ,@cTaskdetailkey       ,@cReplenPriority ,@cPAStatus  
                ,@nPAQty               
                )                    
                 
            IF @@ERROR <> 0              
            BEGIN              
               ROLLBACK TRAN              
               SET @nErrNo = 70157              
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsTaskdetFail'              
               GOTO  QUIT               
            END              
  
            --generate WCSRouting              
--            BEGIN              
            IF NOT EXISTS (SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK) WHERE ToteNo = @cCaseID AND Status = '0')   
               OR @cTTMTaskTypeLog = 'DPK'   
            BEGIN  
               SET @cErrMsg = ''              
               EXEC dbo.nspInsertWCSRouting              
                @c_Storerkey     = @cStorerkey              
               ,@c_Facility      = @cFacility              
               ,@c_ToteNo        = @cCaseId              
               ,@c_TaskType     = 'PA'              
               ,@c_ActionFlag     = @cActionFlag -- (Shong01)          
               ,@c_TaskDetailKey = @cPATaskdetailkey              
               ,@c_Username      = @cUsername              
               ,@b_debug         = 0              
               ,@b_Success       = @b_Success   OUTPUT              
               ,@n_ErrNo         = @nErrNo      OUTPUT              
               ,@c_ErrMsg        = @cErrMsg     OUTPUT              
                 
               IF ISNULL(RTRIM(@cErrMsg),'') <> ''              
               BEGIN              
                  ROLLBACK TRAN              
                  SET @nErrNo = @nErrNo              
                  SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'              
                  GOTO  QUIT               
               END              
--               END           
            END   -- (james01)  
         END  
         ELSE  
         BEGIN  
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET   
               QTY = QTY + @nPAQty,   
               EditWho = @cUserName,   
               EditDate = GETDATE(),   
               TrafficCop = NULL   
            WHERE Storerkey = @cStorerKey  
               AND RefTaskKey = @cTaskdetailkey  
               AND TaskType = 'PA'   
  
            IF @@ERROR <> 0              
            BEGIN              
               ROLLBACK TRAN              
               SET @nErrNo = 70210              
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'              
               GOTO  QUIT               
            END              
         END  
  
         SET @cPrevCaseID = @cCaseId              
         --END --@cLogCaseID <> @cPrevCaseID                       
      END -- IF @nPAQty > 0  
  
      -- Reset QtyReplen              
      UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)              
      SET QTYREPLEN = CASE WHEN ISNULL(QTYREPLEN - @nTaskQty, 0) < 0   
                           THEN 0   
                           ELSE QTYREPLEN - @nTaskQty   
                      END    
      WHERE LOT = @cTTMTaskLot               
      AND LOC   = @cLogLoc               
      AND ID    = @cTTMTaskID              
           
      IF @@ERROR <> 0              
      BEGIN              
         ROLLBACK TRAN              
         SET @nErrNo = 70150              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdLotLOCIDFail              
         GOTO QUIT                 
      END              
  
      DELETE rdt.rdtDPKLog WHERE RowRef = @nRowRef   
                       
      FETCH NEXT FROM C_DPK_MOVE INTO    
               @cLogSKU, @cLogLoc,    
               @nLogQty, @cCaseID,  @cLogBOMSku,   
               @nPAQty,  @nRowRef,  @cSuggLot  
   END              
   CLOSE C_DPK_MOVE              
 DEALLOCATE C_DPK_MOVE              
  
   -- (james03)  
   SELECT @cTTMTaskTypeLog = '', @cLogSKU = '', @cLogLoc = '', @cLoadKey = '', @cNewTaskDetailKey = ''  
   SELECT   
      @cTTMTaskTypeLog = TaskType,   
      @cLogSKU = SKU,   
      @cLogLoc = FromLoc,   
      @cLoadKey = LoadKey   
   FROM dbo.TaskDetail WITH (NOLOCK)   
   WHERE TaskDetailKey = @cTaskdetailkey  
  
   SELECT @cNewTaskDetailKey = TaskDetailKey   
   FROM dbo.TaskDetail WITH (NOLOCK)   
   WHERE FromLoc = @cLogLoc  
      AND SKU = @cLogSKU  
      AND Status = '0'  
      AND LoadKey = @cLoadKey   
      AND TaskType = CASE WHEN @cTTMTaskTypeLog = 'DPK' THEN 'DRP' ELSE 'DRP' END   
  
   IF ISNULL(@cNewTaskDetailKey, '') <> ''  
   BEGIN  
      SELECT   
         @nTK_Qty = ISNULL(SUM(QTY), 0),   
         @nOri_Qty = ISNULL(SUM(SYSTEMQTY), 0) 	-- (james04)  
      FROM dbo.TaskDetail WITH (NOLOCK)   
      WHERE TaskDetailKey = @cTaskdetailkey  
  
      SELECT @nNewTK_Qty = ISNULL(SUM(QTY), 0)   
      FROM dbo.TaskDetail WITH (NOLOCK)   
      WHERE TaskDetailKey = @cNewTaskDetailKey  
  
      -- If the qty taken is more that qty in available task then cancel the task  
      -- else minus the task qty with the qty moved  
      -- so that the task will not have "not enuf inv"  
      IF @nTK_Qty - @nOri_Qty > 0  					-- (james04)
      BEGIN  
         IF @nNewTK_Qty > (@nTK_Qty - @nOri_Qty)  
         BEGIN  
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET   
               ListKey = Qty, -- store original qty  
               Qty = Qty - (@nTK_Qty - @nOri_Qty),   
               StatusMsg = 'Qty deducted from taskdetailkey ' + @cTaskDetailKey   
            WHERE TaskDetailKey = @cNewTaskDetailKey  
         END  
         ELSE  
         BEGIN  
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET   
               Status = 'X',   
               StatusMsg = 'Qty deducted from taskdetailkey ' + @cTaskDetailKey   
            WHERE TaskDetailKey = @cNewTaskDetailKey  
         END  
  
         IF @@ERROR <> 0              
         BEGIN              
            ROLLBACK TRAN              
            SET @nErrNo = 70213              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskFailed              
            GOTO QUIT                 
         END              
      END  
   END  
  
SUCCESS:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN  
  
QUIT:

GO