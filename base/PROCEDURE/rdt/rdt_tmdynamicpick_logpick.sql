SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/  
/* Store procedure: rdt_TMDynamicPick_LogPick                                */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: SOS#175740 - Republic TM Dynamic Picking                         */  
/*                     - Called By rdtfnc_TM_DynamicPick                     */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author   Purposes                                         */  
/* 2010-07-09 1.0  AQSKC    Created                                          */  
/* 2010-07-12 1.0  AQSKC    Add OptimizeCOP = '1' when create new pickdetail */  
/*                          (KC01)                                           */  
/* 2010-07-12 1.0  AQSKC    Add creation of Pickheader and PickingInfo (KC02)*/  
/* 2010-07-12 1.0  AQSKC    Removed Pickdetail.ID checking and use           */  
/*                          Pickdetail.Taskdetailkey instead (Kc03)          */  
/* 2010-07-28 1.1  AQSKC    Standardize rdtGetmessage syntax (Kc04)          */  
/* 2010-07-29 1.2  AQSKC    Add eventlog (Kc05)                              */  
/* 2010-08-04 1.3  AQSKC    Update UCC when same CASEID scanned more than    */  
/*                          once (Kc06)                                      */  
/* 2010-08-05 1.4  AQSKC    Need to rollback the TotPickQty if error(Kc07)   */  
/* 2010-08-15 1.5  SHONG    Insert UserKey into rdtDPKLog                    */
/* 2010-08-18 1.6  AQSKC    Fix Update/Create UCC issue (Kc08)               */
/* 2010-09-18 1.7  James    Swap Pickdetail Lot to prevent creating 2 PA task*/
/*                          from 1 DPK task (james01)                        */
/* 2010-10-14 1.8  Shong    Group CaseId by PTS zone. (SHONG01)              */
/* 2010-11-02 1.9  Shong    Update Pickdetail status 3 with Trafficcop       */
/*                          (SHONG02)                                        */
/*****************************************************************************/  
CREATE PROC [RDT].[rdt_TMDynamicPick_LogPick](  
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
   @cUserName      NVARCHAR(18),  
   @nTotPickQty    INT          OUTPUT,  
   @nErrNo         INT          OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT, -- screen limitation, 20 char max  
   @nMobile        INT,                   --(Kc05)  
   @nFunc          INT,                   --(Kc05)  
   @cFacility      NVARCHAR(5)                --(Kc05)  
) AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE   
     @nCaseRemainQty INT  
   , @nAvailQty      INT  
   , @nMoveQty       INT  
   , @nPKQty         INT  
   , @nPAQty         INT  
   , @nPickRemainQty INT  
   , @nTranCount     INT  
   , @b_Success      INT  
   , @cPickdetailkey       NVARCHAR(10)  
   , @cNewpickdetailkey    NVARCHAR(10)  
   , @cOrderkey            NVARCHAR(10)  
   , @cPickSlipNo          NVARCHAR(10)  
   , @cUOM                 NVARCHAR(10) -- (Kc05)  
   , @nQtyToPicked         INT
   , @cPTS_LOC             NVARCHAR(10)
   , @cNextLOT             NVARCHAR(10)

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_TMDynamicPick_LogPick -- For rollback or commit only our own transaction  
  
   SET @nTotPickQty = @nPrevTotQty + @nCaseQty  
   SET @nCaseRemainQty = @nCaseQty  

   IF ISNULL(@cLOT, '') = ''
   BEGIN
      SELECT @cLOT = LOT 
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE TaskDetailKey = @cTaskDetailKey      
   END

   -- Commented by SHONG -- not necessary now 14-Oct-2010
   -- Check do we need to swap lot??
   --SELECT @nAvailQty = ISNULL(SUM(QTY - QtyAllocated - QTYPICKED - QTYREPLEN),0)  
--   SELECT @nAvailQty = ISNULL(SUM(QTY - QTYPICKED),0)  
--   FROM dbo.LOTxLOCxID WITH (NOLOCK)
--   WHERE LOT = @cLOT
--     AND LOC = @cFromLoc
--     AND ID = @cID

--   SELECT @nQtyToPicked = ISNULL(SUM(PK.Qty), 0)
--   FROM   dbo.PICKDETAIL PK WITH (NOLOCK)  
--   JOIN   dbo.ORDERS ORDERS WITH (NOLOCK) ON (Orders.Orderkey = PK.Orderkey)  
--   WHERE  Orders.Loadkey = @cLoadkey  
--   AND    PK.Status = '0'  
--   AND    PK.CaseID = ''  
--   AND    PK.Sku    = @cSKU  
--   AND    PK.ToLoc  = @cFromLoc  
--   AND    PK.Taskdetailkey = @cTaskdetailkey 


--   IF (@nCaseRemainQty - @nQtyToPicked) > @nAvailQty
--   BEGIN
--      -- Begin swap lot
--      -- Look for available Lot
--         SELECT  @cNextLOT = LOT
--         FROM  dbo.LOTxLOCxID WITH (NOLOCK)  
--         WHERE SKU = @cSKU  
--         AND   Storerkey = @cStorer  
--         AND   LOC = @cFromLoc  
--         AND   ID  = @cID  
--         AND   LOT <> @cLot  
--         AND   (QTY - QtyAllocated - QTYPICKED - QTYREPLEN)  > (@nCaseRemainQty - @nQtyToPicked)
--         ORDER BY LOT  
--
--         IF ISNULL(@cNextLOT, '') <> ''
--         BEGIN
--            DECLARE C_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
--            SELECT DISTINCT PK.LOC
--            FROM   dbo.PICKDETAIL PK WITH (NOLOCK)  
--            JOIN   dbo.ORDERS ORDERS WITH (NOLOCK) ON (Orders.Orderkey = PK.Orderkey)  
--            WHERE  Orders.Loadkey = @cLoadkey  
--            AND    PK.Status = '0'  
--            AND    PK.CaseID = ''  
--            AND    PK.Sku    = @cSKU  
--            AND    PK.ToLoc  = @cFromLoc  
--            AND    PK.Taskdetailkey = @cTaskdetailkey  
--            OPEN C_PICKDETAIL
--            FETCH NEXT FROM C_PICKDETAIL INTO @cPTS_LOC
--            WHILE (@@FETCH_STATUS <> -1)
--            BEGIN
--               IF NOT EXISTS (SELECT 1 FROM dbo.LOTxLOCxID WITH (NOLOCK) 
--                              WHERE Lot = @cNextLOT
--                                 AND LOC = @cPTS_LOC
--                                 AND ID = @cID)  
--               BEGIN
--                  INSERT INTO LOTxLOCxID 
--                  (Lot, Loc, Id, StorerKey, Sku)
--                  VALUES
--                  (@cNextLOT, @cPTS_LOC, @cID, @cStorer, @cSKU)
--
--                  IF @@ERROR <> 0  
--                  BEGIN  
--                     SET @nErrNo = 70129  
--                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsertLLIFail  
--                     GOTO ROLLBACKTRAN     
--                  END  
--
--               END
--               FETCH NEXT FROM C_PICKDETAIL INTO @cPTS_LOC
--            END
--            CLOSE C_PICKDETAIL
--            DEALLOCATE C_PICKDETAIL
--
--            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
--               LOT = @cNextLOT 
--            WHERE TaskDetailKey = @cTaskDetailKey
--               AND Status = '0'
--
--            IF @@ERROR <> 0  
--            BEGIN  
--               SET @nErrNo = 70129  
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsertLLIFail  
--               GOTO ROLLBACKTRAN     
--            END  
--         END
--   END

   DECLARE C_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT PK.Pickdetailkey, PK.Qty, PK.Lot, PK.Orderkey  
   FROM   dbo.PICKDETAIL PK WITH (NOLOCK)  
   JOIN   dbo.ORDERS ORDERS WITH (NOLOCK) ON (Orders.Orderkey = PK.Orderkey) 
   JOIN   dbo.LOC L WITH (NOLOCK) ON PK.Loc = L.LOC -- (SHONG01)  
   LEFT OUTER JOIN (SELECT ConsigneeKey, MIN(LOC) As LOC 
                    FROM StoreToLocDetail WITH (NOLOCK) 
                    WHERE [Status] = '1' 
                    GROUP BY ConsigneeKey ) As stld ON stld.ConsigneeKey = ORDERS.ConsigneeKey  
   WHERE  Orders.Loadkey = @cLoadkey  
   AND    PK.Status = '0'  
   AND    PK.CaseID = ''  
   AND    PK.Sku    = @cSKU  
   AND    PK.ToLoc  = @cFromLoc  
   AND    PK.Taskdetailkey = @cTaskdetailkey    --(Kc03)  
   ORDER BY L.PutawayZone, stld.LOC, Orders.Priority, Orders.Orderkey -- (SHONG01)  
  
   OPEN C_PICKDETAIL  
   FETCH NEXT FROM C_PICKDETAIL INTO  @cPickdetailkey , @nPKQty, @cLot, @cOrderkey  
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN  
      --UCC need to be in the loop to get the pickdetailkey  
      --(Kc08)
      --IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK) Where UCCNo = @cCaseID AND Pickdetailkey = @cPickdetailkey)  
      IF NOT EXISTS (SELECT 1 FROM dbo.UCC 
                     WITH (NOLOCK) Where UCCNo = @cCaseID 
                     AND SKU = @cSKU 
                     AND Sourcekey = @cTaskdetailkey) 
      BEGIN  
         INSERT dbo.UCC (UCCNO,     Storerkey,        SKU,     Qty,        Sourcekey,    SourceType,   
                        Status,     Lot,              Loc,     Id,         Orderkey,         Orderlinenumber,   
                        Wavekey,    Pickdetailkey,    Externkey)  
         SELECT @cCaseID,  Storerkey,  Sku,  @nCaseQty,  @cTaskdetailkey,  'RDTDynamicPick',  
                '0',       Lot,        Loc,  ID,         Orderkey,         Orderlinenumber,  
                Wavekey,   Pickdetailkey,    Pickdetailkey    
         FROM  dbo.PICKDETAIL WITH (NOLOCK)           
         WHERE PICKDETAILKey = @cPickdetailkey         
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70129  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsertUCCFail  
            GOTO ROLLBACKTRAN     
         END  
      END -- UCC not exists  
  
      --(Kc02) - start  
      --create pickheader  
      SET @cPickSlipno = ''    
      SELECT @cPickSlipno = PickheaderKey 
      FROM dbo.PickHeader WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey   
       -- Create Pickheader    
      IF ISNULL(@cPickSlipno, '') = ''    
      BEGIN    
         EXECUTE dbo.nspg_GetKey    
         'PICKSLIP',    
         9,    
         @cPickslipno   OUTPUT,    
         @b_success     OUTPUT,    
         @nErrNo        OUTPUT,  
         @cErrMsg       OUTPUT  
  
         IF @nErrNo <> 0    
         BEGIN    
            SET @nErrNo = 70154    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenPickSlipNoFail   
            GOTO ROLLBACKTRAN     
         END    
  
         SELECT @cPickslipno = 'P' + @cPickslipno    
  
         INSERT INTO dbo.PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)    
         VALUES (@cPickslipno, @cLoadKey, @cOrderKey, '0', 'D', '')    
  
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 70153    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickHdrFail   
            GOTO ROLLBACKTRAN     
         END    
      END --ISNULL(@cPickSlipno, '') = ''    
              
              
      IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)    
      BEGIN    
         INSERT INTO dbo.PickingInfo    
         (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)    
         VALUES    
         (@cPickSlipNo, GETDATE(), @cUserName, NULL, @cUserName)    
  
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 70155    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ScanInFail  
            GOTO RollBackTran    
         END    
      END    
      --(KC02) - end  
  
      -- (Kc05) - Start    
      SELECT @cUOM = RTRIM(PACK.PACKUOM3)    
      FROM dbo.PACK PACK WITH (NOLOCK)    
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)    
      WHERE SKU.Storerkey = @cStorer   
      AND   SKU.SKU = @cSKU    
      -- (KC05) - End    
  
      -- pickdetail  
      UPDATE dbo.PICKDETAIL WITH (ROWLOCK)  
      SET   CASEID = @cCaseID  
           ,DROPID = @cDropID  
           ,PickSlipNo = @cPickSlipNo        --(Kc02)  
           ,STATUS = '3'     
           ,TRAFFICCOP = NULL  -- (SHONG02)
      WHERE Pickdetailkey = @cPickdetailkey  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 70127  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetailFail  
         GOTO ROLLBACKTRAN     
      END  
  
      IF @nPKQty = @nCaseRemainQty  
      BEGIN  
         -- case fulfill exactly 1 pickdetail required qty  
         SET @nMoveQty = @nCaseRemainQty  
         SET @nCaseRemainQty = 0  
      END  
      ELSE IF @nPKQty > @nCaseRemainQty  
      BEGIN  
         -- case can fully fulfill 1 pickdetail and pickdetail has remaining qty to fulfill  
         -- need to split the pickdetail  
         SET @nMoveQty        = @nCaseRemainQty  
         SET @nPickRemainQty  = @nPKQty - @nCaseRemainQty  
         SET @nCaseRemainQty  = 0  
  
         -- generate new pickdetail  
         EXECUTE dbo.nspg_GetKey  
         'PICKDETAILKEY',  
         10,  
         @cNewpickdetailkey OUTPUT,  
         @b_Success         OUTPUT,  
         @nErrNo            OUTPUT,  
         @cErrMsg           OUTPUT  
  
         IF @b_Success = 0  
         BEGIN  
            SET @nErrNo = 70148  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GenPickkeyErr  
            GOTO ROLLBACKTRAN     
         END  
  
         UPDATE dbo.PICKDETAIL WITH (ROWLOCK)  
         SET   QTY         = @nMoveQty,   
               TRAFFICCOP  = NULL  
         WHERE Pickdetailkey = @cPickdetailkey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70178     --(KC04)  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetailFail  
            GOTO ROLLBACKTRAN     
         END  
  
         INSERT dbo.PICKDETAIL          
            (  PickDetailKey,    PickHeaderKey, OrderKey,      OrderLineNumber,  Lot,           Status,   
               Storerkey,        Sku,           UOM,              UOMQty,        Qty,              QtyMoved,           
               Loc,              ID,            PackKey,       UpdateSource,     CartonGroup,   CartonType,           
               ToLoc,            DoReplenish,   ReplenishZone, DoCartonize,      PickMethod,           
               WaveKey,          EffectiveDate, ShipFlag,         PickSlipNo,    Taskdetailkey,      
               ArchiveCOP,       TrafficCop,    OptimizeCop)          
         SELECT @cNewpickdetailkey,  PickHeaderKey,    OrderKey,     OrderLineNumber,  Lot,     '0',             
               Storerkey,           Sku,              UOM,           @nPickRemainQty,  @nPickRemainQty,  QtyMoved,        
               Loc,                 ID,               PackKey,       UpdateSource,     CartonGroup,      CartonType,           
               ToLoc,               DoReplenish,      ReplenishZone, DoCartonize,      PickMethod,           
               WaveKey,             EffectiveDate,    ShipFlag,         PickSlipNo,    Taskdetailkey,  
               ArchiveCOP,          NULL,             '1'               --(KC01)  
         FROM dbo.PICKDETAIL WITH (NOLOCK)           
         WHERE PICKDETAILKey = @cPickdetailkey         
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70128  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPickDetailFail  
            GOTO ROLLBACKTRAN     
         END  
  
      END --@nPKQty > @nCaseRemainQty  
      ELSE IF @nPKQty < @nCaseRemainQty  
      BEGIN  
      -- case can fully fulfill 1 pickdetail and has remaining to fulfill another pickdetail  
         SET @nMoveQty = @nPKQty  
         SET @nCaseRemainQty = @nCaseRemainQty - @nPKQty  
      END  
  
      --keep log of inventory to move later during pallet close  
      --the last caseid always stamped to rdt.rdtDPKLog so when overpicked it is always last caseid  
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtDPKLog WITH (NOLOCK) 
                     WHERE CaseID = @cCaseID 
                     AND SKU = @cSKU  
                     AND FromLoc = @cFromLoc 
                     AND FromID = @cID 
                     AND FromLot = @cLot)  
      BEGIN  
         INSERT INTO rdt.rdtDPKLog (DropID, SKU, FromLoc, FromID, Fromlot, QtyMove, PAQty, CaseID, BOMSKU, Taskdetailkey, UserKey)        
             VALUES (@cDropID, @cSKU, @cFromLoc, @cID, @cLot, @nMoveQty, 0, @cCaseID, @cBOMSku, @cTaskdetailkey, @cUserName)  
  
         IF @@ERROR <> 0  
         BEGIN  
            ROLLBACK TRAN  
            SET @nErrNo = 70143  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsDPKLogFail  
            GOTO ROLLBACKTRAN     
         END  
      END  
      ELSE  
      BEGIN  
         UPDATE rdt.rdtDPKLog WITH (ROWLOCK)  
         SET   QtyMove = QtyMove + @nMoveQty,  
               BOMSKU  = @cBOMSku,  
               CaseID  = @cCaseID  
         WHERE CaseID  = @cCaseID   
         AND   SKU     = @cSKU  
         AND   FromLoc = @cFromLoc  
         AND   FromID  = @cID  
         AND   FromLot = @cLot  
  
         IF @@ERROR <> 0  
         BEGIN  
            ROLLBACK TRAN  
            SET @nErrNo = 70144  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdDPKLogFai  
            GOTO ROLLBACKTRAN     
         END  
      END  

--      UPDATE dbo.TASKDETAIL WITH (ROWLOCK)
--         SET Qty = Qty - @nMoveQty,
--             --SystemQty = SystemQty + @nMoveQty,
--             Trafficcop = NULL 
--      WHERE TaskDetailKey = @cTaskDetailKey
--      IF @@ERROR <> 0  
--      BEGIN  
--         ROLLBACK TRAN  
--         SET @nErrNo = 70190  
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail  
--         GOTO ROLLBACKTRAN     
--      END  
     
      --(Kc05) - start  
      EXEC RDT.rdt_STD_EventLog    
           @cActionType   = '3', -- Picking    
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
           @cRefNo1       = @cOrderKey,    
           @cRefNo2       = @cCaseID,    
           @cRefNo3       = @cPickSlipNo    
      --(Kc05) - end  
  
      IF @nCaseRemainQty = 0  
      BEGIN  
         BREAK  
      END  
      FETCH NEXT FROM C_PICKDETAIL INTO  @cPickdetailkey , @nPKQty, @cLot, @cOrderkey  
   END --while  
   CLOSE C_PICKDETAIL  
   DEALLOCATE C_PICKDETAIL       
  
   --Handle overpicking  
   IF @nCaseRemainQty > 0  
   BEGIN  
      /***********************  
      * STEP 1               *  
      ***********************/  
      -- use the pickdetail defined lot as 1st priority for overpicking  
      -- taking QtyReplen into consideration for calculation of AvailQty  
      -- as we do not want to take from lot that has been promised for other DPK and DRP tasks  
      SET @nAvailQty = 0  
      SET @nPAQty = 0   
  
      --SELECT  @nAvailQty = ISNULL((LLI.QTY - LLI.QtyAllocated - LLI.QTYPICKED - LLI.QTYREPLEN),0)  
      SELECT  @nAvailQty = ISNULL((LLI.QTY - LLI.QTYPICKED),0)  
      FROM  dbo.LOTxLOCxID LLI WITH (NOLOCK)  
      JOIN  dbo.LOT WITH (NOLOCK) ON LOT.Lot = lli.Lot AND lot.Status = 'OK'    
      WHERE LLI.SKU        = @cSKU  
      AND   LLI.Storerkey  = @cStorer  
      AND   LLI.LOC        = @cFromLoc  
      AND   LLI.ID         = @cID  
      AND   LLI.Lot        = @cLot  
  
      IF @nAvailQty > 0  
      BEGIN  
         IF @nAvailQty >= @nCaseRemainQty -- 1 lot able to fulfill case qty  
         BEGIN  
            SET @nPAQty = @nCaseRemainQty  
         END  
         ELSE IF @nAvailQty < @nCaseRemainQty  
         BEGIN  
            SET @nPAQty = @nAvailQty  
         END              
         SET @nCaseRemainQty = @nCaseRemainQty - @nPAQty  
  
         -- log case qty for putaway  
         INSERT INTO rdt.rdtDPKLog (DropID, SKU, FromLoc, FromID, Fromlot, QtyMove, PAQty, CaseID, BOMSku, Taskdetailkey, UserKey)        
             VALUES (@cDropID, @cSKU, @cFromLoc, @cID, @cLot, @nPAQty, @nPAQty, @cCaseID, @cBOMSku,  @cTaskdetailkey, @cUserName)  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70179     --(Kc04)  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsDPKLogFai  
            GOTO ROLLBACKTRAN     
         END  
  
         UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)  
         SET   QtyReplen   = QtyReplen + @nPAQty   
         WHERE SKU         = @cSKU  
         AND   Storerkey   = @cStorer  
         AND   LOC         = @cFromLoc  
         AND   ID          = @cID  
         AND   LOT         = @cLot  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70173     --(Kc04)  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdLotLocIDFail  
            GOTO ROLLBACKTRAN     
         END  
      END -- @nAvailQty > 0  
  
      IF @nCaseRemainQty > 0  
      BEGIN  
      /***********************  
      * STEP 2               *  
      ***********************/  
         -- retrieve other lots to use  
         SET @nPAQty = 0  
         DECLARE C_LOTxLOCxID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT  LOT, (QTY - QTYPICKED)   
         FROM  dbo.LOTxLOCxID WITH (NOLOCK)  
         WHERE SKU = @cSKU  
         AND   Storerkey = @cStorer  
         AND   LOC = @cFromLoc  
         AND   ID  = @cID  
         AND   LOT <> @cLot  
         AND   (QTY - QTYPICKED)  > 0  
         ORDER BY LOT  
         OPEN C_LOTxLOCxID  
  
         FETCH NEXT FROM C_LOTxLOCxID INTO  @cLot, @nAvailQty  
         WHILE (@@FETCH_STATUS <> -1)  
         BEGIN  
            IF @nCaseRemainQty >= @nAvailQty  
            BEGIN  
               SET @nPAQty =  @nAvailQty  
            END  
            ELSE  
            BEGIN  
               SET @nPAQty =  @nCaseRemainQty  
            END  
  
            INSERT INTO rdt.rdtDPKLog (DropID, SKU, FromLoc, FromID, Fromlot, QtyMove, PAQty, CaseID, BOMSKU, Taskdetailkey, UserKey)        
                VALUES (@cDropID, @cSKU, @cFromLoc, @cID, @cLot, @nPAQty, @nPAQty, @cCaseID, @cBOMSku, @cTaskdetailkey, @cUserName)  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70180     --(Kc04)  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsDPKLogFai  
               GOTO ROLLBACKTRAN     
            END  
  
            UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)  
            SET   QtyReplen = QtyReplen + @nPAQty  
            WHERE SKU = @cSKU  
            AND   Storerkey = @cStorer  
            AND   LOC = @cFromLoc  
            AND   ID  = @cID  
            AND   LOT = @cLot  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70174     --(Kc04)  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdLotLocIDFail  
               GOTO ROLLBACKTRAN     
            END  
  
            SET @nCaseRemainQty = @nCaseRemainQty - @nPAQty  
            IF @nCaseRemainQty = 0  
            BEGIN  
               BREAK  
            END  
  
            FETCH NEXT FROM C_LOTxLOCxID INTO  @cLot, @nAvailQty  
         END  
         CLOSE C_LOTxLOCxID  
         DEALLOCATE C_LOTxLOCxID  
      END --@nCaseRemainQty > 0  
      IF @nCaseRemainQty > 0  
      BEGIN  
         SET @nErrNo = 70151  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FailToFindINV  
         GOTO ROLLBACKTRAN     
      END  
   END --@nCaseRemainQty > 0  
  
   COMMIT TRAN rdt_TMDynamicPick_LogPick -- Only commit change made in here  
   GOTO Quit  
  
   ROLLBACKTRAN:  
      ROLLBACK TRAN rdt_TMDynamicPick_LogPick  
      SET @nTotPickQty = @nPrevTotQty              --(Kc07)  
  
   QUIT:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN

GO