SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/  
/* Store procedure: rdt_TMDynamicPick_LogReplen                              */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: SOS#175740 - Republic TM Dynamic Picking                         */  
/*                     - Called By rdtfnc_TM_DynamicPick                     */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author   Purposes                                         */  
/* 2010-07-09 1.0  AQSKC    Created                                          */  
/* 2010-07-28 1.1  AQSKC    Standardize rdtGetmessage ErrorNo (Kc01)         */  
/* 2010-07-29 1.2  AQSKC    Add eventlog (Kc02)                              */  
/* 2010-08-04 1.3  AQSKC    Update UCC when same CASEID scanned more than    */  
/*                          once (Kc03)                                      */  
/* 2010-08-05 1.4  AQSKC    Need to rollback the TotPickQty if error(Kc04)   */  
/* 2010-08-15 1.5  SHONG    Insert UserKey into rdtDPKLog                    */  
/* 2010-09-08 1.6  AQSKC    Fix QtyReplen for alternate lots (Kc05)          */
/* 2017-10-24 1.7  TLTING   Fix QtyReplen conflict with table prefix         */
/*****************************************************************************/  
CREATE PROC [RDT].[rdt_TMDynamicPick_LogReplen](  
   @cDropID        NVARCHAR(18),  
   @cLoadkey       NVARCHAR(10),  
   @cCaseID        NVARCHAR(10),  
   @cStorer        NVARCHAR(15),  
   @cSku           NVARCHAR(20),  
   @cFromLoc       NVARCHAR(10),  
   @cID            NVARCHAR(18),  
   @cLot           NVARCHAR(10),  
   @cBOMSku        NVARCHAR(20),  
   @cTaskdetailkey NVARCHAR(10),  
   @nPrevTotQty    INT,  
   @nCaseQty       INT,  
   @nTaskQty       INT,  
   @cLangCode      NVARCHAR( 3),   
   @nTotPickQty    INT          OUTPUT,  
   @nErrNo         INT          OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT, -- screen limitation, 20 char max  
   @nMobile        INT,                   --(Kc02)  
   @nFunc          INT,                   --(Kc02)  
   @cFacility      NVARCHAR(5),               --(Kc02)  
   @cUserName      NVARCHAR(18)               --(Kc02)  
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
   , @cUOM           NVARCHAR(10) -- (Kc02)  
  
  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_TMDynamicPick_LogReplen -- For rollback or commit only our own transaction  
  
   SET @nTotPickQty = @nPrevTotQty  
  
   -- (Kc02) - Start    
   SELECT @cUOM = RTRIM(PACK.PACKUOM3)    
   FROM dbo.PACK PACK WITH (NOLOCK)    
   JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)    
   WHERE SKU.Storerkey = @cStorer   
   AND   SKU.SKU = @cSKU    
   -- (KC02) - End    
  
   IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK) Where UCCNo = @cCaseID AND SourceKey = @cTaskdetailkey )    --(KC03)  
   BEGIN  
      INSERT dbo.UCC (UCCNO,     Storerkey,  SKU,     Qty,        Sourcekey,    SourceType,   
                     Status,     Loc,        Id,      Lot,        Externkey)  
      VALUES (@cCaseID,  @cStorer,     @cSku,  @nCaseQty,   @cTaskdetailkey,  'RDTDynamicReplen',  
             '0',        @cFromLoc,    @cID,   @cLot,       @cTaskdetailkey )   
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 70177        --(kc01)  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsertUCCFail  
         GOTO ROLLBACKTRAN     
      END  
   END -- UCC not exists  
   --(Kc03) - start  
   ELSE  
   BEGIN  
      UPDATE dbo.UCC WITH (ROWLOCK)  
      SET   Qty = Qty + @nCaseQty  
      WHERE UCCNO       = @cCaseID  
      AND   Sourcekey   = @cTaskdetailkey  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 70186          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdateUCCFail  
         GOTO ROLLBACKTRAN     
      END  
   END  
   --(Kc03) - end  
  
   -- use the taskdetail defined lot  
   SET @nAvailQty = 0  
   SET @nCaseRemainQty = @nCaseQty  
  
   SELECT  @nAvailQty = ISNULL((LLI.QTY - LLI.QTYPICKED),0)  
   FROM  dbo.LOTxLOCxID LLI WITH (NOLOCK)  
   JOIN  dbo.LOT WITH (NOLOCK) ON LOT.Lot = lli.Lot AND lot.Status = 'OK'    
   WHERE LLI.SKU        = @cSKU  
   AND   LLI.Storerkey  = @cStorer  
   AND   LLI.LOC        = @cFromLoc  
   --AND   LLI.ID         = @cID  
   --AND   LLI.Lot        = @cLot  
  
   IF @nAvailQty >= @nCaseRemainQty -- 1 lot able to fulfill case qty  
   BEGIN  
      SET @nMoveQty = @nCaseRemainQty  
   END  
   ELSE IF @nAvailQty < @nCaseRemainQty  
   BEGIN  
      SET @nMoveQty = @nAvailQty  
   END              
   SET @nCaseRemainQty = @nCaseRemainQty - @nMoveQty  
  
   -- log case qty for putaway  
   INSERT INTO rdt.rdtDPKLog (DropID, SKU, FromLoc, FromID, Fromlot, QtyMove, PAQty, CaseID, BOMSku, Taskdetailkey, UserKey)        
       VALUES (@cDropID, @cSKU, @cFromLoc, @cID, @cLot, @nMoveQty, @nMoveQty, @cCaseID, @cBOMSku,  @cTaskdetailkey, @cUserName)  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 70182     --(Kc01)  
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
        @cStorerKey    = @cStorer,    
        @cLocation     = @cFromLoc,    
        @cID           = @cID,    
        @cSKU          = @cSKU,    
        @cUOM          = @cUOM,    
        @nQTY          = @nMoveQty,    
        @cLot          = @cLOT,    
        @cRefNo1       = @cLoadkey,    
        @cRefNo2       = @cCaseID  
   --(Kc02) - end  
   END  
  
   IF @nTotPickQty + @nMoveQty > @nTaskQty   -- hit overreplen level  
   BEGIN  
      --overreplen from original lot  
      UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)  
      SET   QtyReplen  = QtyReplen + (@nTotPickQty + @nMoveQty - @nTaskQty)  
      WHERE SKU        = @cSKU  
      AND   Storerkey  = @cStorer  
      AND   Loc        = @cFromLoc  
      AND   ID         = @cID  
      AND   Lot        = @cLot  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 70175     --(Kc01)  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdLotLocIDFail  
         GOTO ROLLBACKTRAN     
      END  
   END  
  
   SET @nTotPickQty = @nTotPickQty + @nMoveQty  
  
   IF @nCaseRemainQty > 0  
   BEGIN  
      SET @nAvailQty = 0  
      -- retrieve other lots to use if original suggested lot does not have enough inventory  
      DECLARE C_REPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT  LLI.LOT, LLI.ID, (LLI.QTY - LLI.QTYPICKED)   
      FROM  dbo.LOTxLOCxID LLI WITH (NOLOCK)  
      JOIN  dbo.LOT WITH (NOLOCK) ON LOT.Lot = lli.Lot AND lot.Status = 'OK'    
      WHERE LLI.SKU        = @cSKU  
      AND   LLI.Storerkey  = @cStorer  
      AND   LLI.LOC        = @cFromLoc  
      --AND   LLI.ID         = @cID  
      AND   (LLI.QTY - LLI.QTYPICKED) > 0  
      ORDER BY LLI.LOT  
      OPEN C_REPLEN  
      FETCH NEXT FROM C_REPLEN INTO  @cLot, @cID, @nAvailQty  
  
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         IF @nAvailQty >= @nCaseRemainQty -- 1 lot able to fulfill case qty  
         BEGIN  
            SET @nMoveQty = @nCaseRemainQty  
         END  
         ELSE IF @nAvailQty < @nCaseRemainQty  
         BEGIN  
            SET @nMoveQty = @nAvailQty  
         END  
  
         -- log case qty for putaway  
         INSERT INTO rdt.rdtDPKLog (DropID, SKU, FromLoc, FromID, Fromlot, QtyMove, PAQty, CaseID, BOMSku, Taskdetailkey, UserKey)    
             VALUES (@cDropID, @cSKU, @cFromLoc, @cID, @cLot, @nMoveQty, @nMoveQty, @cCaseID, @cBOMSku,@cTaskdetailkey, @cUserName)  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70181     --(Kc01)  
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
              @cStorerKey    = @cStorer,    
              @cLocation     = @cFromLoc,    
              @cID           = @cID,    
              @cSKU          = @cSKU,    
              @cUOM          = @cUOM,    
              @nQTY          = @nMoveQty,    
              @cLot          = @cLOT,    
              @cRefNo1       = @cLoadkey,    
              @cRefNo2       = @cCaseID   
         --(Kc02) - end  
         END  
  
         SET @nCaseRemainQty  = @nCaseRemainQty - @nMoveQty  
         SET @nTotPickQty     = @nTotPickQty + @nMoveQty  
  
  
         IF @nCaseRemainQty = 0  
         BEGIN  
            BREAK --get out of loop  
         END  
           
         FETCH NEXT FROM C_REPLEN INTO  @cLot, @cID, @nAvailQty  
      END  
      CLOSE C_REPLEN  
      DEALLOCATE C_REPLEN       
   END --@nCaseRemainQty > 0  
  
   IF @nCaseRemainQty > 0  
   BEGIN  
      SET @nErrNo = 70183        --(Kc01)  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FailToFindINV  
      GOTO ROLLBACKTRAN     
   END  

   --cater for overreplen  
   UPDATE LLi WITH (ROWLOCK)  
      SET   QtyReplen = CASE WHEN (LLi.QtyReplen - TD.Qty) > 0 THEN (LLi.QtyReplen - TD.Qty) ELSE 0 END
   FROM  dbo.LOTxLOCxID LLi 
   JOIN  dbo.TaskDetail td WITH (NOLOCK) ON td.Lot = LLi.Lot AND td.FromLoc = LLi.LOC AND td.FromID = LLi.ID 
   WHERE td.TaskDetailKey = @cTaskdetailkey   
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 70176     --(Kc01)  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdLotLocIDFail  
      GOTO ROLLBACKTRAN     
   END  
           
   COMMIT TRAN rdt_TMDynamicPick_LogReplen -- Only commit change made in here  
   GOTO Quit  
  
   ROLLBACKTRAN:  
      ROLLBACK TRAN rdt_TMDynamicPick_LogReplen  
      SET @nTotPickQty = @nPrevTotQty              --(Kc04)  
  
   QUIT:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN

GO