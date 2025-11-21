SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store procedure: rdt_Wave_ReplenFrom                                 */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Purpose: RDT Wave Replenishment Move                                 */      
/*                                                                      */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date       Rev  Author   Purposes                                    */      
/* 2008-08-10 1.0  jwong    Created                                     */      
/* 2011-11-09 1.1  james    Update UCC info (james01)                   */      
/* 2011-11-18 1.2  james    Restamp short replen status (james02)       */      
/* 2011-12-20 1.3  ChewKP   Put TraceInfo (ChewKP02)                    */ 
/* 2011-01-01 1.4  ChewKP   Do not perform move when ReplenQty = 0      */
/*                          (ChewKP03)                                  */ 
/* 2011-01-01 1.5  ChewKP   Do not perform move when ReplenQty = 0      */
/* 2011-05-07 1.6  James    Split replen task if short replen (james03) */
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_Wave_ReplenFrom] (      
   @nFunc                INT,      
   @nMobile              INT,      
   @cLangCode            NVARCHAR( 3),       
   @nErrNo               INT          OUTPUT,      
   @cErrMsg              NVARCHAR( 20) OUTPUT,       
   @cStorerKey           NVARCHAR( 15),      
   @cFromLOC             NVARCHAR( 10),       
   @cToLOC               NVARCHAR( 10),       
   @cFromID              NVARCHAR( 18) = NULL,       
   @cToID                NVARCHAR( 18) = NULL,       
   @cSKU                 NVARCHAR( 20) = NULL,       
   @cUCC                 NVARCHAR( 20) = NULL,       
   @nQTY                 INT       = 0,          
   @cFromLOT             NVARCHAR( 10) = NULL,       
   @cWaveKey             NVARCHAR( 10),      
   @cDropID              NVARCHAR( 18),      
   @cReplenInProgressLOC NVARCHAR(10),      
   @cReplenishmentKey    NVARCHAR( 10),      
   @cLoadKey             NVARCHAR( 10),      
   @cStatus              NVARCHAR(  1)      
) AS      
      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
    
   DECLARE      
      @cUCCMixedSKUFlag NVARCHAR( 1),      
      @cConfirmed       NVARCHAR( 1),      
      @cRPL_DropID      NVARCHAR( 18),      
      @cOriginalFromLOC NVARCHAR( 10),      
      @nReplenQty       INT,      
      @nUCCQTY          INT,      
      @nRPLOriQTY       INT,      
      @nTranCount       INT,      
      @nQTY_PD          INT, -- (ChewKP01)      
      @nPickQty         INT, -- (ChewKP01)      
      @cPickDetailKey   NVARCHAR(10),      
      @cPickDetailKeyQty NVARCHAR(10),      
      @c_PDOrderkey      NVARCHAR(10),      
      @cReplenUpdatePickDetail NVARCHAR(1),      
      @c_AlertMessage    NVARCHAR(255),      
      @nPackQty          INT,      
      @cPickSlipNo       NVARCHAR(10),      
      @cOrderkey         NVARCHAR(10),      
      @cPrevPickSlipNo   NVARCHAR(10),      
      @cLabelNo          NVARCHAR(20),      
      @nPackDetailQty    NVARCHAR(10),      
      @nCartonNo         INT,    
      @cFacility         NVARCHAR(5),     
      @cPriority         NVARCHAR(10),      -- (jamesxxx)    
      @nSUM_PickQty      INT,     
      @nSUM_RPLQty       INT,    
      @nShortedQty       INT,  
      @nOriginalQty      INT  
     
   Declare @nReplenTraceQty INT  -- (ChewKP02)  
      
   DECLARE      
      @b_success        INT,      
      @n_err            INT,      
      @c_errmsg         NVARCHAR( 20)      
             
   DECLARE @c_NewLineChar NVARCHAR(2)        
         
   SET @nTranCount = @@TRANCOUNT       
   SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10) -- (ChewKP01)           
      
   DECLARE @cNewReplenishmentKey NVARCHAR( 10)      
         
   IF @cStatus = 'R'    
   BEGIN    
      --SELECT @nShortedQty = ISNULL(OriginalQty - @nQty, 0)  -- (ChewKPXX)  
      --FROM dbo.Replenishment WITH (NOLOCK)    
      --WHERE ReplenishmentKey = @cReplenishmentKey    
        
      SELECT @nOriginalQty = ISNULL(OriginalQty, 0)  -- (ChewKPXX)  
      FROM dbo.Replenishment WITH (NOLOCK)    
      WHERE ReplenishmentKey = @cReplenishmentKey    
        
   END    
       
   CREATE TABLE #TempShortPickOrder (      
         Storerkey   NVARCHAR(15) NULL      
        ,Orderkey    NVARCHAR(10) NULL      
        ,PickSlipNo  NVARCHAR(10) NULL      
        ,SKU         NVARCHAR(20) NULL      
        ,Qty         INT         NULL      
   )      
         
   DELETE FROM #TempShortPickOrder      
      
   BEGIN TRAN      
   SAVE TRAN Wave_RepleFrom      
      
   -- Get In Transit Location --      
   SELECT @cFacility = Facility FROM RDT.RDTMOBREC WITH (NOLOCK)    
   WHERE Mobile = @nMobile    
       
   SELECT @cReplenInProgressLOC = ISNULL(SValue, '') FROM dbo.StorerConfig WITH (NOLOCK)    
   WHERE StorerKey = @cStorerKey    
      AND Facility = @cFacility    
      AND ConfigKey = 'REPLENINPROGLOC'    
          
    
   --sku replenishment move handling      
   BEGIN      
      SELECT       
         @cRPL_DropID = DropID,       
         @cConfirmed  = Confirmed,       
         @cOriginalFromLOC = OriginalFromLOC,      
         @nRPLOriQTY  = OriginalQty,      
         @cFromID  = ID,      
         @cFromLOT = LOT,     
         @cSKU     = SKU   
      FROM dbo.REPLENISHMENT WITH (NOLOCK)       
      WHERE ReplenishmentKey = @cReplenishmentKey      
    
      IF @nQty = @nRPLOriQTY      
      BEGIN      
         IF ISNULL(@cRPL_DropID, '') <> '' AND @cRPL_DropID <> @cDropID      
         BEGIN      
            IF @cStatus = 'F'      
            BEGIN      
               EXECUTE dbo.nspg_GetKey      
                  'REPLENISHMENT',       
                  10 ,      
                  @cNewReplenishmentKey OUTPUT,      
                  @b_success            OUTPUT,      
                  @n_err                OUTPUT,      
                  @c_errmsg             OUTPUT      
            
               IF @b_success <> 1      
               BEGIN      
                  SET @nErrNo = 67444      
                  SET @cErrMsg = rdt.rdtgetmessage( 67444, @cLangCode, 'DSP') -- 'GetDetKey Fail'      
                  GOTO RollBackTran      
               END      
      
               INSERT INTO dbo.Replenishment (ReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, FromLoc, ToLoc,                      
                  Lot, Id, Qty, QtyMoved, QtyInPickLoc, Priority, UOM, PackKey,       
                  Confirmed, ReplenNo, Remark, RefNo, DropID, LoadKey, WaveKey, OriginalFromLoc, OriginalQty, AddWho)              
               SELECT        
                  @cNewReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, FromLoc, ToLoc,      
                  Lot, Id, Qty, QtyMoved, QtyInPickLoc, Priority, UOM, PackKey,      
                  Confirmed, @cReplenishmentKey , Remark, RefNo, DropID, LoadKey, WaveKey, OriginalFromLoc, OriginalQty, '**' + AddWho
               FROM dbo.Replenishment WITH (NOLOCK)      
               WHERE ReplenishmentKey = @cReplenishmentKey      
            
               IF @@ERROR <> 0      
               BEGIN      
                  SET @nErrNo = 67446      
                  SET @cErrMsg = rdt.rdtgetmessage( 67446, @cLangCode, 'DSP') --'INS RPL Fail'      
                  GOTO RollBackTran      
               END      
            END -- @cStatus = 'F'      

            insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5)                     
            values ('rdt_Wave_ReplenFrom_b4updqty1', getdate(), @cReplenishmentKey, @nQty, @cDropID, @cReplenInProgressLOC, @cStatus)
            UPDATE dbo.Replenishment WITH (ROWLOCK) SET       
               QTY = @nQty, --CASE WHEN @cStatus = 'R' THEN @nQty ELSE (@nQTY - Qty) END,      
               DropID = @cDropID,      
               FromLOC = @cReplenInProgressLOC,      
               Confirmed = CASE WHEN @cStatus = 'R' THEN 'R' ELSE 'S' END,     
               EditDate = GETDATE(),     
               EditWho = 'rdt.' + sUser_sName()     
            WHERE ReplenishmentKey = @cReplenishmentKey      
                     
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 67446      
               SET @cErrMsg = rdt.rdtgetmessage( 67446, @cLangCode, 'DSP') --'UPD RPL Fail'      
               GOTO RollBackTran      
            END      
         END -- IF ISNULL(@cRPL_DropID, '') <> '' AND @cRPL_DropID <> @cDropID      
         ELSE      
         BEGIN      
            -- (ChewKP02)   
            SET @nReplenTraceQty = 0  
            SELECT @nReplenTraceQty = Qty  
            FROM dbo.Replenishment WITH (NOLOCK)  
            WHERE ReplenishmentKEy = @cReplenishmentKey  
              
            INSERT TraceINFO (TraceName , TimeIN, Step1, Col1, Col2, Col3, Col4)  
            VALUES ('rdt_Wave_ReplenMove', GetDATE(), 'S5', @cReplenishmentKey, @nUCCQTY, @nQty, @nReplenTraceQty)  
                    
            --EXEC Move      
            EXEC rdt.rdt_Wave_ReplenMove       
               @nFunc                  = @nFunc,      
               @nMobile                = @nMobile,      
               @cLangCode              = @cLangCode,       
               @nErrNo                 = @nErrNo   OUTPUT,      
               @cErrMsg                = @cErrMsg  OUTPUT,      
               @cStorerKey             = @cStorerKey,      
               @cFromID                = @cFromID,      
               @cSKU                   = @cSKU,      
               @cFromLOT               = @cFromLOT,      
               @cReplenishmentKey      = @cReplenishmentKey,      
               @cOriginalFromLOC       = @cOriginalFromLOC,      
               @cReplenInProgressLOC   = @cReplenInProgressLOC      
         
            IF @nErrNo <> 0      
            BEGIN      
               GOTO RollBackTran     
            END      

            insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5)                     
            values ('rdt_Wave_ReplenFrom_b4updqty2', getdate(), @cReplenishmentKey, @nQty, @cDropID, @cReplenInProgressLOC, @cStatus)

            UPDATE dbo.Replenishment WITH (ROWLOCK) SET       
               QTY = @nQTY,      
               DropID = @cDropID,      
               FromLOC = @cReplenInProgressLOC,      
               Confirmed = 'S',    
               EditDate = GETDATE(),     
               EditWho = 'rdt.' + sUser_sName()     
            WHERE ReplenishmentKey = @cReplenishmentKey      
         
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 67446      
               SET @cErrMsg = rdt.rdtgetmessage( 67446, @cLangCode, 'DSP') --'UPD RPL Fail'      
               GOTO RollBackTran      
            END      
         END      
      END -- IF @nQty = @nRPLOriQTY      
      ELSE IF @nQty > @nRPLOriQTY      
      BEGIN      
         --if target replenishment's dropid is not blank or not equal to scanned dropid then start split rpl line      
         IF @cStatus = 'F'      
         BEGIN      
            EXECUTE dbo.nspg_GetKey      
               'REPLENISHMENT',       
               10 ,      
               @cNewReplenishmentKey OUTPUT,      
               @b_success            OUTPUT,      
               @n_err                OUTPUT,      
               @c_errmsg             OUTPUT      
    
            IF @b_success <> 1      
            BEGIN      
               SET @nErrNo = 67444      
               SET @cErrMsg = rdt.rdtgetmessage( 67444, @cLangCode, 'DSP') -- 'GetDetKey Fail'      
               GOTO RollBackTran      
            END      
      
            INSERT INTO dbo.Replenishment (ReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, FromLoc, ToLoc,                      
                  Lot, Id, Qty, QtyMoved, QtyInPickLoc, Priority, UOM, PackKey,       
  Confirmed, ReplenNo, Remark, RefNo, DropID, LoadKey, WaveKey, OriginalFromLoc, OriginalQty, AddWho)              
            SELECT        
               @cNewReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, FromLoc, ToLoc,      
               Lot, Id, @nQTY - Qty, QtyMoved, QtyInPickLoc, Priority, UOM, PackKey,      
               Confirmed, @cReplenishmentKey, Remark, RefNo, DropID, LoadKey, WaveKey, OriginalFromLoc, OriginalQty, '**' + AddWho      
            FROM dbo.Replenishment WITH (NOLOCK)      
            WHERE ReplenishmentKey = @cReplenishmentKey      
    
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 67446      
               SET @cErrMsg = rdt.rdtgetmessage( 67446, @cLangCode, 'DSP') --'INS RPL Fail'      
               GOTO RollBackTran      
            END      
         END -- @cStatus = 'F'      

         insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5)                     
         values ('rdt_Wave_ReplenFrom_b4updqty3', getdate(), @cReplenishmentKey, @nQty, @cDropID, @cReplenInProgressLOC, @cStatus)

         UPDATE dbo.Replenishment WITH (ROWLOCK) SET       
            QTY = @nQty, --CASE WHEN @cStatus = 'R' THEN @nQty ELSE (@nQTY - Qty) END,      
            DropID = @cDropID,      
            FromLOC = @cReplenInProgressLOC,      
            Confirmed = CASE WHEN @cStatus = 'R' THEN 'R' ELSE 'S' END,     
            EditDate = GETDATE(),     
            EditWho = 'rdt.' + sUser_sName()     
         WHERE ReplenishmentKey = @cReplenishmentKey      
    
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 67446      
            SET @cErrMsg = rdt.rdtgetmessage( 67446, @cLangCode, 'DSP') --'UPD RPL Fail'      
            GOTO RollBackTran      
         END      
         
         -- (ChewKP02)   
         SET @nReplenTraceQty = 0  
         SELECT @nReplenTraceQty = Qty  
         FROM dbo.Replenishment WITH (NOLOCK)  
         WHERE ReplenishmentKEy = @cReplenishmentKey  
           
         INSERT TraceINFO (TraceName , TimeIN, Step1, Col1, Col2, Col3, Col4)  
         VALUES ('rdt_Wave_ReplenMove', GetDATE(), 'S6', @cReplenishmentKey, @nUCCQTY, @nQty, @nReplenTraceQty)  
                    
         --EXEC Move      
         EXEC rdt.rdt_Wave_ReplenMove       
            @nFunc                  = @nFunc,      
            @nMobile                = @nMobile,      
            @cLangCode              = @cLangCode,       
            @nErrNo                 = @nErrNo   OUTPUT,      
            @cErrMsg                = @cErrMsg  OUTPUT,      
            @cStorerKey             = @cStorerKey,      
            @cFromID                = @cFromID,      
            @cSKU                   = @cSKU,      
            @cFromLOT               = @cFromLOT,      
            @cReplenishmentKey      = @cReplenishmentKey, --@cNewReplenishmentKey,      
            @cOriginalFromLOC       = @cOriginalFromLOC,      
            @cReplenInProgressLOC   = @cReplenInProgressLOC      
    
         IF @nErrNo <> 0      
         BEGIN      
            GOTO RollBackTran      
         END      
      END   --@nQty >= @nRPLOriQTY      
      ELSE IF @nQty < @nRPLOriQTY      
      BEGIN      
         IF @cStatus = 'F'      
         BEGIN      
            EXECUTE dbo.nspg_GetKey      
               'REPLENISHMENT',       
               10 ,      
               @cNewReplenishmentKey OUTPUT,      
               @b_success            OUTPUT,      
               @n_err                OUTPUT,      
               @c_errmsg             OUTPUT      
      
            IF @b_success <> 1      
            BEGIN      
               SET @nErrNo = 67444      
               SET @cErrMsg = rdt.rdtgetmessage( 67444, @cLangCode, 'DSP') -- 'GetDetKey Fail'      
               GOTO RollBackTran      
            END      
            
            INSERT INTO dbo.Replenishment (ReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, FromLoc, ToLoc,                      
               Lot, Id, Qty, QtyMoved, QtyInPickLoc, Priority, UOM, PackKey,       
               Confirmed, ReplenNo, Remark, RefNo, DropID, LoadKey, WaveKey, OriginalFromLoc, OriginalQty, AddWho)              
            SELECT        
               @cNewReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, FromLoc, ToLoc,      
               Lot, Id, Qty - @nQTY, QtyMoved, QtyInPickLoc, Priority, UOM, PackKey,      
               Confirmed, @cReplenishmentKey, Remark, RefNo, DropID, LoadKey, WaveKey, OriginalFromLoc, OriginalQty, '**' + AddWho      
               FROM dbo.Replenishment WITH (NOLOCK)      
            WHERE ReplenishmentKey = @cReplenishmentKey      
      
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 67446      
               SET @cErrMsg = rdt.rdtgetmessage( 67446, @cLangCode, 'DSP') --'INS RPL Fail'      
               GOTO RollBackTran      
            END      
         END -- @cStatus = 'F'      
         
         -- When PickQty = 0 Update Confirmed = 'Y' with ArchiveCop (ChewKPXX)   
         IF @nQty = 0   
         BEGIN  
            insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5)                     
            values ('rdt_Wave_ReplenFrom_b4updqty4', getdate(), @cReplenishmentKey, @nQty, @cDropID, @cReplenInProgressLOC, @cStatus)

            UPDATE dbo.Replenishment WITH (ROWLOCK) SET       
               QTY = @nQty , --CASE WHEN @cStatus = 'R' THEN @nQty ELSE (Qty - @nQTY ) END,      
               DropID = @cDropID,      
               FromLOC = @cReplenInProgressLOC,      
               Confirmed = 'Y', -- CASE WHEN @cStatus = 'R' THEN 'R' ELSE 'S' END,     
               EditDate = GETDATE(),     
               EditWho = 'rdt.' + sUser_sName(),    
               ArchiveCop = NULL,  
               Remark = 'PalletFull with 0 Qty'  
            WHERE ReplenishmentKey = @cReplenishmentKey      
       
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 67457      
               SET @cErrMsg = rdt.rdtgetmessage( 67457, @cLangCode, 'DSP') --'UPD RPL Fail'      
               GOTO RollBackTran      
            END      
         END  
         ELSE  
         BEGIN  
            insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5)                     
            values ('rdt_Wave_ReplenFrom_b4updqty5', getdate(), @cReplenishmentKey, @nQty, @cDropID, @cReplenInProgressLOC, @cStatus)

            UPDATE dbo.Replenishment WITH (ROWLOCK) SET       
               QTY = @nQty , --CASE WHEN @cStatus = 'R' THEN @nQty ELSE (Qty - @nQTY ) END,      
               DropID = @cDropID,      
               FromLOC = @cReplenInProgressLOC,      
               Confirmed = CASE WHEN @cStatus = 'R' THEN 'R' ELSE 'S' END,     
               EditDate = GETDATE(),     
               EditWho = 'rdt.' + sUser_sName()     
            WHERE ReplenishmentKey = @cReplenishmentKey      
       
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 67446      
               SET @cErrMsg = rdt.rdtgetmessage( 67446, @cLangCode, 'DSP') --'UPD RPL Fail'      
               GOTO RollBackTran      
            END      
         END  
         -- (ChewKP02)   
         SET @nReplenTraceQty = 0  
         SELECT @nReplenTraceQty = Qty  
         FROM dbo.Replenishment WITH (NOLOCK)  
         WHERE ReplenishmentKEy = @cReplenishmentKey  
           
         INSERT TraceINFO (TraceName , TimeIN, Step1, Col1, Col2, Col3, Col4)  
         VALUES ('rdt_Wave_ReplenMove', GetDATE(), 'S7', @cReplenishmentKey, @nUCCQTY, @nQty, @nReplenTraceQty)  
                                 
         --EXEC Move      
         IF @nQty > 0 -- (ChewKP03)
         BEGIN
            EXEC rdt.rdt_Wave_ReplenMove       
               @nFunc                  = @nFunc,      
               @nMobile                = @nMobile,      
               @cLangCode              = @cLangCode,       
               @nErrNo                 = @nErrNo   OUTPUT,      
               @cErrMsg                = @cErrMsg  OUTPUT,      
               @cStorerKey             = @cStorerKey,      
               @cFromID                = @cFromID,      
               @cSKU                   = @cSKU,      
               @cFromLOT               = @cFromLOT,      
               @cReplenishmentKey      = @cReplenishmentKey, --@cNewReplenishmentKey,      
           @cOriginalFromLOC       = @cOriginalFromLOC,      
               @cReplenInProgressLOC   = @cReplenInProgressLOC      
            
            IF @nErrNo <> 0      
            BEGIN      
               GOTO RollBackTran      
            END  
         END       
      END -- IF @nQty < @nRPLOriQTY     
   END      
    
   -- Check if unallocate needed.    
   -- Example #1 this load only need to pick 2 qty but replenishment is 1 ctn    
   -- then no need to unallocate or unpack.    
   -- Example #2 this load need to pick 13 qty (pickloc has 12, need replenishment 1 qty) and replenishment is 1 ctn    
   -- if short replen is 5 qty then no need unallocate also because loc will have more than needed    
   -- Example #3 this load need to pick 13 qty (pickloc has 1, need replenishment 12 qty) and replenishment is 1 ctn    
   -- if short replen 5 qty then need to unallocate 5 qty    
    
   INSERT INTO TraceINfo (TraceName , TimeIN, Step1, Step2, Step3, Step4, STep5)      
   Values ('TESTEST', GetDATE(), @cSKU, @cStatus, @nQty, @nOriginalQty,@cWaveKey )     
     
   INSERT INTO TraceINfo (TraceName , TimeIN, Step1, Step2, Step3, Step4, STep5,Col1)      
   Values ('TESTCUR', GetDATE(), @cSKU, @cStatus, @cToLOC, @cFromLot,@cLoadKey, @cSKU)     
     
    
   IF @cStatus = 'R' AND (@nQty < @nOriginalQty )  -- (ChewKPXX)  
   BEGIN    
      --Update PickDetail When Short Pick      
      SET @cReplenUpdatePickDetail =''      
      SET @cReplenUpdatePickDetail = rdt.RDTGetConfig( @nFunc, 'ReplenUpdatePickDetail', @cStorerKey)      
        
      IF @cReplenUpdatePickDetail = '1'      
      BEGIN      
         SET @nPickQty = @nQty  

         IF @cLoadKey <> ''  
         BEGIN  
            DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            SELECT PD.PickDetailKey      
                  ,PD.QTY      
                  --,PD.LOT      
                  ,PD.Orderkey      
   --               ,PH.PickSlipNo    
                  ,'' AS PickSlipNo    
                  , O.Priority     
            FROM dbo.PickDetail PD WITH (NOLOCK)      
            JOIN dbo.Orders O WITH (NOLOCK) ON  (PD.OrderKey=O.OrderKey)      
   --         JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey AND PH.Storerkey = PD.StorerKey)      
            WHERE  O.LoadKey = @cLoadKey      
               AND    PD.StorerKey = @cStorerKey      
               AND    PD.LOC = @cToLOC      
               AND    PD.Status = '0'      
               AND    PD.SKU = @cSKU      
               AND    PD.Lot = @cFromLot      
            --ORDER BY O.Orderkey, PD.PickSlipNo, CASE WHEN PD.QTY = @nPickQty THEN 0 ELSE 1 END  (jamesxxx)    
            ORDER BY O.Priority DESC      -- Lowest priority get to unallocate 1st    
           
         END  
         ELSE  
         BEGIN  
              
            DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            SELECT PD.PickDetailKey      
                  ,PD.QTY      
                  --,PD.LOT      
                  ,PD.Orderkey      
   --               ,PH.PickSlipNo    
                  ,'' AS PickSlipNo    
                  , O.Priority     
            FROM dbo.PickDetail PD WITH (NOLOCK)      
            JOIN dbo.Orders O WITH (NOLOCK) ON  (PD.OrderKey=O.OrderKey)      
            JOIN dbo.WaveDetail WD WITH (NOLOCK) ON (PD.OrderKEy = WD.OrderKEy)  
            WHERE  WD.WaveKey = @cWaveKey  
               AND    PD.StorerKey = @cStorerKey      
               AND    PD.LOC = @cToLOC      
               AND    PD.Status = '0'      
               AND    PD.SKU = @cSKU      
               AND    PD.Lot = @cFromLot      
            --ORDER BY O.Orderkey, PD.PickSlipNo, CASE WHEN PD.QTY = @nPickQty THEN 0 ELSE 1 END  (jamesxxx)    
            ORDER BY O.Priority DESC      -- Lowest priority get to unallocate 1st    
         END  
           
         OPEN CursorPickDetail       
         FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @c_PDOrderkey, @cPickSlipNo, @cPriority        
         WHILE @@FETCH_STATUS<>-1      
         BEGIN      
            IF @nPickQty <= 0      
            BEGIN   
                   
--               -- Update PickDetail      
--               UPDATE dbo.PickDetail WITH (ROWLOCK)      
--               SET Qty = 0      
--               WHERE PickDetailkey = @cPickDetailKey      
    
               -- Unallocate pickdetail line    
               DELETE FROM dbo.PickDetail WITH (ROWLOCK) WHERE PickDetailKey = @cPickDetailKeyQty    
                   
               IF @@ERROR<>0      
               BEGIN      
                 SET @nErrNo = 67447          
                 SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPDtlFail'          
                 GOTO RollBackTran      
               END      
                     
               -- Update LotxLocxID PendingMoveIn      
               UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET    
                  PendingMoveIn = CASE WHEN PendingMoveIn - @nQTY_PD > 0     
                                       THEN PendingMoveIn - @nQTY_PD     
                                       ELSE 0 END      
               WHERE Loc       = @cToLoc      
               AND  Lot       = @cFromLot      
               AND  SKU       = @cSKU      
               AND  Storerkey = @cStorerKey      
               
               IF @@ERROR<>0      
               BEGIN      
                  SET @nErrNo = 67448        
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdLLIFailed'          
                  GOTO RollBackTran      
               END      
                  
               -- Log Alert       
               SET @c_AlertMessage = ''      
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' PickDetailKey: ' + @cPickDetailKey  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' OrderKey: ' + @c_PDOrderkey  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Loc: ' + @cToLoc  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Lot: ' + @cFromLot  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DropID: ' + @cDropID  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' SKU: ' + @cSKU  + @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Qty: ' + CAST(@nQTY_PD AS NVARCHAR(10)) + @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Mobile: ' + CAST(@nMobile AS NVARCHAR(4)) + @c_NewLineChar      
                 
               -- Insert LOG Alert            
               SELECT @b_Success = 1            
    
               EXECUTE dbo.nspLogAlert            
                  @c_ModuleName   = 'rdt_wave_replenfrom',            
                  @c_AlertMessage = @c_AlertMessage,            
                  @n_Severity     = 0,            
                  @b_success      = @b_Success OUTPUT,            
                  @n_err          = @nErrNo OUTPUT,            
                  @c_errmsg       = @cErrMsg OUTPUT            
          
               IF NOT @b_Success = 1            
               BEGIN            
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP')       
                  GOTO RollBackTran      
               END        
            END      
            ELSE       
            IF @nQTY_PD=@nPickQty      
            BEGIN      
--               -- Change orginal PickDetail with exact QTY (with TrafficCop)          
--               UPDATE dbo.PickDetail WITH (ROWLOCK) SET        
--                  QTY = 0    
--               WHERE  PickDetailKey = @cPickDetailKey          
    
               -- Unallocate pickdetail line    
               DELETE FROM dbo.PickDetail WITH (ROWLOCK) WHERE PickDetailKey = @cPickDetailKeyQty    
                   
               IF @@ERROR<>0      
               BEGIN      
                  SET @nErrNo = 67452          
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPDtlFail'          
                  GOTO RollBackTran      
               END       
                   
               UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET     
                  PendingMoveIn = CASE WHEN PendingMoveIn - @nQTY_PD > 0  THEN PendingMoveIn - @nQTY_PD ELSE 0  END      
               WHERE Loc       = @cToLoc      
                  AND  Lot       = @cFromLot      
                  AND  SKU       = @cSKU      
                  AND  Storerkey = @cStorerKey      
               
               IF @@ERROR<>0      
               BEGIN      
                  SET @nErrNo = 67453        
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdLLIFailed'          
                  GOTO RollBackTran      
               END      
                   
               -- Log Alert       
               SET @c_AlertMessage = ''      
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' PickDetailKey: ' + @cPickDetailKey  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' OrderKey: ' + @c_PDOrderkey  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Loc: ' + @cToLoc  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Lot: ' + @cFromLot  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DropID: ' + @cDropID  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' SKU: ' + @cSKU  + @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Qty: ' + CAST(@nQTY_PD AS NVARCHAR(10)) + @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Mobile: ' + CAST(@nMobile AS NVARCHAR(4)) + @c_NewLineChar      
                    
               -- Insert LOG Alert            
               SELECT @b_Success = 1            
                    
               EXECUTE dbo.nspLogAlert            
                  @c_ModuleName   = 'rdt_wave_replenfrom',            
                  @c_AlertMessage = @c_AlertMessage,            
                  @n_Severity     = 0,            
                  @b_success      = @b_Success  OUTPUT,            
                  @n_err          = @nErrNo     OUTPUT,            
                  @c_errmsg       = @cErrMsg    OUTPUT            
       
               IF NOT @b_Success = 1            
               BEGIN            
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP')       
                  GOTO RollBackTran      
               END        
                  
  -- Get Short Pick Order into Temp Table      
               INSERT INTO #TempShortPickOrder       
               VALUES ( @cStorerkey, @c_PDOrderkey, @cPickSlipNo, @cSKU, @nPickQty)      
                     
               --SET @nPickQty = @nPickQty - @nQTY_PD    (jamesxxx)    
                     
               INSERT INTO TraceINfo (TraceName , TimeIN, Step1, Step2, Step3, Step4, STep5)      
               Values ('TESTEST1', GetDATE(), @cStorerkey, @c_PDOrderkey, @cSKU, @nQTY_PD, @nPickQty)      
               SET @nPickQty = 0      
            END      
            ELSE       
            IF @nPickQty > @nQTY_PD      
            BEGIN      
--               Update dbo.PickDetail WITH (ROWLOCK) SET      
----                  Qty = @nPickQty --@nPickQty - Qty    (jamesxxx)    
--                  Qty = 0    
--               WHERE PickDetailKey = @cPickDetailKeyQty      
    
               -- Unallocate pickdetail line    
               DELETE FROM dbo.PickDetail WITH (ROWLOCK) WHERE PickDetailKey = @cPickDetailKeyQty    
                   
               IF @@ERROR<>0      
               BEGIN      
                  SET @nErrNo = 67450          
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'          
                  GOTO RollBackTran      
               END      
                
               UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET     
                  PendingMoveIn = CASE WHEN PendingMoveIn - @nQTY_PD > 0  THEN PendingMoveIn - @nQTY_PD ELSE 0  END      
               WHERE   Loc       = @cToLoc      
                  AND  Lot       = @cFromLot      
                  AND  SKU       = @cSKU      
                  AND  Storerkey = @cStorerKey      
                  
               IF @@ERROR<>0      
               BEGIN      
                  SET @nErrNo = 67451        
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdLLIFailed'          
                  GOTO RollBackTran      
               END      
                
               -- Log Alert       
               SET @c_AlertMessage = ''      
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' PickDetailKey: ' + @cPickDetailKey  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' OrderKey: ' + @c_PDOrderkey  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Loc: ' + @cToLoc  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Lot: ' + @cFromLot  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DropID: ' + @cDropID  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' SKU: ' + @cSKU  + @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Qty: ' + CAST(@nQTY_PD AS NVARCHAR(10)) + @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Mobile: ' + CAST(@nMobile AS NVARCHAR(4)) + @c_NewLineChar      
                    
               -- Insert LOG Alert            
               SELECT @b_Success = 1            
                    
               EXECUTE dbo.nspLogAlert            
                  @c_ModuleName   = 'rdt_wave_replenfrom',            
                  @c_AlertMessage = @c_AlertMessage,            
                  @n_Severity     = 0,            
                  @b_success      = @b_Success  OUTPUT,            
                  @n_err          = @nErrNo     OUTPUT,            
                  @c_errmsg       = @cErrMsg    OUTPUT            
          
               IF NOT @b_Success = 1            
               BEGIN            
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP')       
                  GOTO RollBackTran      
               END        
                   
               -- Get Short Pick Order into Temp Table      
               INSERT INTO #TempShortPickOrder       
               VALUES ( @cStorerkey, @c_PDOrderkey, @cPickSlipNo, @cSKU, @nQTY_PD)      
                     
               INSERT INTO TraceINfo (TraceName , TimeIN, Step1, Step2, Step3, Step4, STep5)      
               Values ('TESTEST2', GetDATE(), @cStorerkey, @c_PDOrderkey, @cSKU, @nQTY_PD, @nPickQty)      
            END      
            ELSE       
            IF @nPickQty < @nQTY_PD AND @nPickQty > 0      
            BEGIN      
               -- Change orginal PickDetail with exact QTY (with TrafficCop)          
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET        
                  --QTY = @nPickQty --Qty - @nPickQty  (jamesxxx)    
                  QTY = Qty - @nPickQty     
               WHERE  PickDetailKey = @cPickDetailKey          
                   
               IF @@ERROR<>0      
               BEGIN      
                  SET @nErrNo = 67452          
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdPDtlFail'          
                  GOTO RollBackTran      
               END       
                   
               UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET     
                  PendingMoveIn = CASE WHEN PendingMoveIn - @nQTY_PD > 0  THEN PendingMoveIn - @nQTY_PD ELSE 0  END      
               WHERE Loc       = @cToLoc      
                  AND  Lot       = @cFromLot      
                  AND  SKU       = @cSKU      
                  AND  Storerkey = @cStorerKey      
               
               IF @@ERROR<>0      
               BEGIN      
                  SET @nErrNo = 67453        
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdLLIFailed'          
                  GOTO RollBackTran      
               END      
                
               -- Log Alert       
               SET @c_AlertMessage = ''      
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' PickDetailKey: ' + @cPickDetailKey  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' OrderKey: ' + @c_PDOrderkey  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Loc: ' + @cToLoc  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Lot: ' + @cFromLot  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DropID: ' + @cDropID  +  @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' SKU: ' + @cSKU  + @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Qty: ' + CAST(@nQTY_PD AS NVARCHAR(10)) + @c_NewLineChar       
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Mobile: ' + CAST(@nMobile AS NVARCHAR(4)) + @c_NewLineChar      
                    
               -- Insert LOG Alert            
               SELECT @b_Success = 1            
                 
               EXECUTE dbo.nspLogAlert            
                  @c_ModuleName   = 'rdt_wave_replenfrom',            
                  @c_AlertMessage = @c_AlertMessage,            
                  @n_Severity     = 0,            
                  @b_success      = @b_Success  OUTPUT,            
                  @n_err          = @nErrNo     OUTPUT,            
                  @c_errmsg       = @cErrMsg    OUTPUT            
             
               IF NOT @b_Success = 1            
               BEGIN            
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP')       
                  GOTO RollBackTran      
               END        
                     
               -- Get Short Pick Order into Temp Table      
               INSERT INTO #TempShortPickOrder       
               VALUES ( @cStorerkey, @c_PDOrderkey, @cPickSlipNo, @cSKU, @nPickQty)      
                  
               --SET @nPickQty = @nPickQty - @nQTY_PD    (jamesxxx)    
                     
               INSERT INTO TraceINfo (TraceName , TimeIN, Step1, Step2, Step3, Step4, STep5)      
               Values ('TESTEST3', GetDATE(), @cStorerkey, @c_PDOrderkey, @cSKU, @nQTY_PD, @nPickQty)      
            END          
                
            SET @nPickQty = @nPickQty - @nQTY_PD      
                
            IF @nPickQty <= 0    
            BEGIN    
               BREAK    
            END    
                   
            FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nQTY_PD, @c_PDOrderkey, @cPickSlipNo, @cPriority         
         END -- While Loop for PickDetail Key        
         CLOSE CursorPickDetail       
         DEALLOCATE CursorPickDetail      
      END    
  
   END    
       
   IF @cStatus = 'R'    
   BEGIN    
      -- Split replenishment task (jamesxx)
      SET @cNewReplenishmentKey = ''
      EXECUTE dbo.nspg_GetKey      
         'REPLENISHMENT',       
         10 ,      
         @cNewReplenishmentKey OUTPUT,      
         @b_success            OUTPUT,      
         @n_err                OUTPUT,      
         @c_errmsg             OUTPUT      

      IF @b_success <> 1      
      BEGIN      
         SET @nErrNo = 67444      
         SET @cErrMsg = rdt.rdtgetmessage( 67444, @cLangCode, 'DSP') -- 'GetDetKey Fail'      
         GOTO RollBackTran      
      END      
      
      INSERT INTO dbo.Replenishment (ReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, FromLoc, ToLoc,                      
         Lot, Id, Qty, QtyMoved, QtyInPickLoc, Priority, UOM, PackKey,       
         Confirmed, ReplenNo, Remark, RefNo, DropID, LoadKey, WaveKey, OriginalFromLoc, OriginalQty, AddWho)              
      SELECT        
         @cNewReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, OriginalFromLoc, ToLoc,      
         Lot, Id, OriginalQty - @nQTY, QtyMoved, QtyInPickLoc, Priority, UOM, PackKey,      
         'R', @cReplenishmentKey, Remark, RefNo, DropID, LoadKey, WaveKey, OriginalFromLoc, OriginalQty - @nQTY, '*' + sUser_sName()      
         FROM dbo.Replenishment WITH (NOLOCK)      
      WHERE ReplenishmentKey = @cReplenishmentKey      

      IF @@ERROR <> 0      
      BEGIN      
         SET @nErrNo = 67446      
         SET @cErrMsg = rdt.rdtgetmessage( 67446, @cLangCode, 'DSP') --'INS RPL Fail'      
         GOTO RollBackTran      
      END      
            
      -- Update back the short replen back to status 'S' so the replen to can pick up (james02)    
      UPDATE dbo.Replenishment WITH (ROWLOCK) SET 
         OriginalQty = @nQTY,   -- (jamesxx) 
         Confirmed = 'S',     
         ArchiveCop = NULL       -- not to fire replenishment trigger    
      WHERE ReplenishmentKey = @cReplenishmentKey    
         AND Confirmed IN ('R','N') -- (ChewKP04)
          
      IF @@ERROR<>0      
      BEGIN      
         SET @cErrMsg = rdt.rdtgetmessage(67458 ,@cLangCode ,'DSP') --'UPD RPL FAIL'          
         GOTO RollBackTran      
      END      
   END    
          
   GOTO Quit         
      
   RollBackTran:      
      ROLLBACK TRAN Wave_RepleFrom      
      
   Quit:      
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
         COMMIT TRAN Wave_RepleFrom

GO