SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/  
/* Store procedure: rdt_TM_DyReplenJW01                                      */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: SOS#175740 - Jack Will TM Dynamic Picking                        */  
/*                     - Called By rdtfnc_TM_DynamicPick                     */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author   Purposes                                         */  
/* 2014-07-24 1.0  James    Modified from rdt_TMDynamicPick_LogPick (james01)*/  
/* 2014-12-02 1.1  James    SOS326850 - Clear pending route (james02)        */
/* 2015-10-05 1.3  TLTING   Deadlock Tune                                    */
/* 2017-07-04 1.4  James    Add table prefix (james03)                       */
/*****************************************************************************/  
CREATE PROC [RDT].[rdt_TM_DyReplenJW01](  
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT, 
   @nInputKey       INT, 
   @cDropID         NVARCHAR( 20), 
   @cToToteno       NVARCHAR( 20), 
   @cLoadkey        NVARCHAR( 10), 
   @cTaskStorer     NVARCHAR( 15), 
   @cSKU            NVARCHAR( 20), 
   @cFromLoc        NVARCHAR( 10), 
   @cID             NVARCHAR( 18), 
   @cLot            NVARCHAR( 10), 
   @cTaskdetailkey  NVARCHAR( 10), 
   @nPrevTotQty     INT, 
   @nBoxQty         INT, 
   @nTaskQty        INT, 
   @nTotPickQty     INT   OUTPUT, 
   @nErrNo          INT   OUTPUT, 
   @cErrMsg         NVARCHAR( 20)  OUTPUT 
) AS
SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE   
     @nCaseRemainQty INT  
   , @nAvailQty      INT  
   , @nMoveQty       INT  
   , @nTranCount     INT  
   , @cUOM           NVARCHAR(10) 
   , @cUserName      NVARCHAR(15)
   , @cFacility      NVARCHAR(5)

   DECLARE 
      @b_Success           INT,            -- (james02)   
      @cInit_Final_Zone    NVARCHAR( 10),  -- (james02)   
      @cFinalWCSZone       NVARCHAR( 10),  -- (james02)   
      @cWCSKey             NVARCHAR( 10),   -- (james02)   
      @c_curWCSkey         NVARCHAR( 10)
  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_TM_DyReplenJW01 -- For rollback or commit only our own transaction  

   SELECT @cUserName = UserName, @cFacility = Facility FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   SET @nTotPickQty = @nPrevTotQty  
  
   SELECT @cUOM = RTRIM(PACK.PACKUOM3)    
   FROM dbo.PACK PACK WITH (NOLOCK)    
   JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)    
   WHERE SKU.Storerkey = @cTaskStorer   
   AND   SKU.SKU = @cSKU    

   IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK) Where UCCNo = @cToToteno AND SourceKey = @cTaskdetailkey )    --(KC03)  
   BEGIN  
      INSERT dbo.UCC (UCCNO,     Storerkey,  SKU,     Qty,        Sourcekey,    SourceType,   
                     Status,     Loc,        Id,      Lot,        Externkey, UserDefined04)  
      VALUES (@cToToteno,  @cTaskStorer,     @cSku,  @nBoxQty,   @cTaskdetailkey,  'RDTDynamicReplen',  
             '0',        @cFromLoc,    @cID,   @cLot,       @cTaskdetailkey, @cDropID )   
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 50251        --(kc01)  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsertUCCFail  
         GOTO ROLLBACKTRAN     
      END  

      -- (james02)   
      -- Cancel all pending route for tote
      SET @cInit_Final_Zone = ''    
      SET @cFinalWCSZone = ''    

      SELECT TOP 1 
         @cFinalWCSZone = Final_Zone,    
         @cInit_Final_Zone = Initial_Final_Zone    
      FROM dbo.WCSRouting WITH (NOLOCK)    
      WHERE ToteNo = @cToToteno    
      AND ActionFlag = 'I'    
      ORDER BY WCSKey Desc    

      SET @cWCSKey = ''
      EXECUTE nspg_GetKey         
         'WCSKey',         
         10,         
         @cWCSKey   OUTPUT,         
         @b_Success OUTPUT,         
         @nErrNo    OUTPUT,         
         @cErrMsg   OUTPUT          
            
      IF @nErrNo<>0        
      BEGIN        
         SET @nErrNo = 50258
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetWCSKey Fail
         GOTO ROLLBACKTRAN  
      END          
                  
      INSERT INTO WCSRouting        
      (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType)        
      VALUES        
      ( @cWCSKey, @cToToteno, ISNULL(@cInit_Final_Zone,''), ISNULL(@cFinalWCSZone,''), 'D', @cTaskStorer, @cFacility, '', 'PK') 
            
      SELECT @nErrNo = @@ERROR          

      IF @nErrNo<>0        
      BEGIN        
         SET @nErrNo = 50259
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CrtRouteFail
         GOTO ROLLBACKTRAN  
      END         

      -- tlting start
	   DECLARE Item_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		   Select  WCSKey 
         FROM WCSRouting WITH (NOLOCK)      
         WHERE  ToteNo = @cToToteno   
 
	   OPEN Item_cur 
	   FETCH NEXT FROM Item_cur INTO @c_curWCSkey  
	   WHILE @@FETCH_STATUS = 0 
	   BEGIN 

         -- Update WCSRouting.Status = '5' When Delete          
         UPDATE WCSRouting WITH (ROWLOCK)        
         SET    STATUS = '5', 
         EditDate = GETDATE(), 
         EditWho =SUSER_SNAME()        
         WHERE  WCSkey = @c_curWCSkey          

         SELECT @nErrNo = @@ERROR          
         IF @nErrNo<>0        
         BEGIN        
            SET @nErrNo = 50260
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdRouteFail
            GOTO ROLLBACKTRAN   
         END         
   		
		   FETCH NEXT FROM Item_cur INTO @c_curWCSkey 
	   END
	   CLOSE Item_cur 
	   DEALLOCATE Item_cur   
	                  
      -- end tlting  

      EXEC dbo.isp_WMS2WCSRouting  
           @cWCSKey,  
           @cTaskStorer,  
           @b_Success   OUTPUT,  
           @nErrNo      OUTPUT,   
           @cErrMsg     OUTPUT  
     
      IF @nErrNo <> 0   
      BEGIN  
         SET @nErrNo = 50261
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CrtWCSRECFail
         GOTO ROLLBACKTRAN  
      END
   END -- UCC not exists  
   --(Kc03) - start  
   ELSE  
   BEGIN  
      UPDATE dbo.UCC WITH (ROWLOCK)  
      SET   Qty = Qty + @nBoxQty  
      WHERE UCCNO       = @cToToteno  
      AND   Sourcekey   = @cTaskdetailkey  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 50252          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdateUCCFail  
         GOTO ROLLBACKTRAN     
      END  
   END  

   -- use the taskdetail defined lot  
   SET @nAvailQty = 0  
  
   SELECT  @nAvailQty = ISNULL((LLI.QTY - LLI.QTYPICKED),0)  
   FROM  dbo.LOTxLOCxID LLI WITH (NOLOCK)  
   JOIN  dbo.LOT WITH (NOLOCK) ON LOT.Lot = lli.Lot AND lot.Status = 'OK'    
   WHERE LLI.SKU        = @cSKU  
   AND   LLI.Storerkey  = @cTaskStorer  
   AND   LLI.LOC        = @cFromLoc  
  
   IF @nAvailQty >= @nBoxQty -- 1 lot able to fulfill case qty  
   BEGIN  
      SET @nMoveQty = @nBoxQty  
   END  
   ELSE IF @nAvailQty < @nBoxQty  
   BEGIN  
      SET @nMoveQty = @nAvailQty  
   END              
   SET @nBoxQty = @nBoxQty - @nMoveQty  

   -- log case qty for putaway  
   INSERT INTO rdt.rdtDPKLog (DropID, SKU, FromLoc, FromID, Fromlot, QtyMove, PAQty, CaseID, BOMSku, Taskdetailkey, UserKey)        
       VALUES (@cDropID, @cSKU, @cFromLoc, @cID, @cLot, @nMoveQty, @nMoveQty, @cToToteNo, @cSku,  @cTaskdetailkey, @cUserName)  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 50253     --(Kc01)  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsDPKLogFai  
      GOTO ROLLBACKTRAN     
   END  
   ELSE  
   BEGIN  
      --(Kc02) - start  
      EXEC RDT.rdt_STD_EventLog    
        @cActionType   = '5', -- Replenishment    
        @cUserID       = @cUserName,    
        @nMobileNo     = @nMobile,    
        @nFunctionID   = @nFunc,    
        @cFacility     = @cFacility,    
        @cStorerKey    = @cTaskStorer,    
        @cLocation     = @cFromLoc,    
        @cID           = @cID,    
        @cSKU          = @cSKU,    
        @cUOM          = @cUOM,    
        @nQTY          = @nMoveQty,    
        @cLot          = @cLOT,    
        @cRefNo1       = @cLoadkey,    
        @cRefNo2       = @cDropID  
   END
  
   IF @nTotPickQty + @nMoveQty > @nTaskQty   -- hit overreplen level  
   BEGIN  
      --overreplen from original lot  
      UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)  
      SET   QtyReplen  = QtyReplen + (@nTotPickQty + @nMoveQty - @nTaskQty)  
      WHERE SKU        = @cSKU  
      AND   Storerkey  = @cTaskStorer  
      AND   Loc        = @cFromLoc  
      AND   ID         = @cID  
      AND   Lot        = @cLot  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 50254     --(Kc01)  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdLotLocIDFail  
         GOTO ROLLBACKTRAN     
      END  
   END  
  
   SET @nTotPickQty = @nTotPickQty + @nMoveQty  
  
   IF @nBoxQty > 0  
   BEGIN  
      SET @nAvailQty = 0  
      -- retrieve other lots to use if original suggested lot does not have enough inventory  
      DECLARE C_REPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT  LLI.LOT, LLI.ID, (LLI.QTY - LLI.QTYPICKED)   
      FROM  dbo.LOTxLOCxID LLI WITH (NOLOCK)  
      JOIN  dbo.LOT WITH (NOLOCK) ON LOT.Lot = lli.Lot AND lot.Status = 'OK'    
      WHERE LLI.SKU        = @cSKU  
      AND   LLI.Storerkey  = @cTaskStorer  
      AND   LLI.LOC        = @cFromLoc  
      --AND   LLI.ID         = @cID  
      AND   (LLI.QTY - LLI.QTYPICKED) > 0  
      ORDER BY LLI.LOT  
      OPEN C_REPLEN  
      FETCH NEXT FROM C_REPLEN INTO  @cLot, @cID, @nAvailQty  
  
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         IF @nAvailQty >= @nBoxQty -- 1 lot able to fulfill case qty  
         BEGIN  
            SET @nMoveQty = @nBoxQty  
         END  
         ELSE IF @nAvailQty < @nBoxQty  
         BEGIN  
            SET @nMoveQty = @nAvailQty  
         END  

         -- log case qty for putaway  
         INSERT INTO rdt.rdtDPKLog (DropID, SKU, FromLoc, FromID, Fromlot, QtyMove, PAQty, CaseID, BOMSku, Taskdetailkey, UserKey)    
             VALUES (@cDropID, @cSKU, @cFromLoc, @cID, @cLot, @nMoveQty, @nMoveQty, @cToToteno, @cSku,@cTaskdetailkey, @cUserName)  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 50255     --(Kc01)  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsDPKLogFai  
            GOTO ROLLBACKTRAN     
         END  
         ELSE  
         BEGIN  
            EXEC RDT.rdt_STD_EventLog    
              @cActionType   = '5', -- Replenishment    
              @cUserID       = @cUserName,    
              @nMobileNo     = @nMobile,    
              @nFunctionID   = @nFunc,    
              @cFacility     = @cFacility,    
              @cStorerKey    = @cTaskStorer,    
              @cLocation     = @cFromLoc,    
              @cID           = @cID,    
              @cSKU          = @cSKU,    
              @cUOM          = @cUOM,    
              @nQTY          = @nMoveQty,    
              @cLot          = @cLOT,    
              @cRefNo1       = @cLoadkey,    
              @cRefNo2       = @cDropID   
         END
  
         SET @nBoxQty  = @nBoxQty - @nMoveQty  
         SET @nTotPickQty     = @nTotPickQty + @nMoveQty  
  
  
         IF @nBoxQty = 0  
         BEGIN  
            BREAK --get out of loop  
         END  
           
         FETCH NEXT FROM C_REPLEN INTO  @cLot, @cID, @nAvailQty  
      END  
      CLOSE C_REPLEN  
      DEALLOCATE C_REPLEN       
   END --@nCaseRemainQty > 0  
  
   IF @nBoxQty > 0  
   BEGIN  
      SET @nErrNo = 50256        --(Kc01)  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FailToFindINV  
      GOTO ROLLBACKTRAN     
   END  

   --cater for overreplen  
   UPDATE LLi WITH (ROWLOCK)  
      SET   LLi.QtyReplen = CASE WHEN (LLi.QtyReplen - TD.Qty) > 0 THEN (LLi.QtyReplen - TD.Qty) ELSE 0 END
   FROM  dbo.LOTxLOCxID LLi 
   JOIN  dbo.TaskDetail td WITH (NOLOCK) ON td.Lot = LLi.Lot AND td.FromLoc = LLi.LOC AND td.FromID = LLi.ID 
   WHERE td.TaskDetailKey = @cTaskdetailkey   
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 50257     --(Kc01)  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdLotLocIDFail  
      GOTO ROLLBACKTRAN     
   END  
           
   COMMIT TRAN rdt_TM_DyReplenJW01 -- Only commit change made in here  
   GOTO Quit  
  
   ROLLBACKTRAN:  
      ROLLBACK TRAN rdt_TM_DyReplenJW01  
      SET @nTotPickQty = @nPrevTotQty              --(Kc04)  
  
   QUIT:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN

GO