SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_Wave_ReplenMove                                 */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: RDT Wave Replenishment Move                                 */  
/*                                                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2008-08-10 1.0  jwong    Created                                     */  
/* 2011-12-14 1.1  james    Bug fix (james01)                           */  
/* 2011-12-28 1.2  ChewKP   Update Replen Task with same Loc,Lot,ID,SKU */  
/*                          to Confirmed = 'S' by ArichiveCop (ChewKP01)*/  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_Wave_ReplenMove] (  
   @nFunc       INT,  
   @nMobile     INT,  
   @cLangCode   NVARCHAR( 3),   
   @nErrNo      INT          OUTPUT,  
   @cErrMsg     NVARCHAR( 20) OUTPUT,   
   @cStorerKey  NVARCHAR( 15),  
   @cFromID     NVARCHAR( 18) = NULL,   
   @cSKU        NVARCHAR( 20) = NULL,   
   @cFromLOT    NVARCHAR( 10) = NULL,   
   @cReplenishmentKey  NVARCHAR( 10),  
   @cOriginalFromLOC NVARCHAR( 10),  
   @cReplenInProgressLOC NVARCHAR( 10)  
) AS  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE   
      @nTranCount       INT,  
      @nReplenQtyToMove INT,  
      @b_Success        INT,  
      @n_err            INT,  
      @c_errmsg         NVARCHAR( 20),  
      @cDropID          NVARCHAR( 20),  
      @cReplenToByBatch NVARCHAR(  1),  
      @cDPReplenishmentKey NVARCHAR( 10),  
      @nDPQty           INT,  
      @nOriginalQty     INT,  
      @nTotalReplenQty  INT  
        
  
--   WHILE @@TRANCOUNT > 0   
--      COMMIT TRAN  
  
   SET @nTranCount = @@TRANCOUNT   
     
   BEGIN TRAN  
   SAVE TRAN Wave_RepleMove  
  
   SELECT @nReplenQtyToMove = Qty   
          ,@cDropID = DropID -- (ChewKP01)  
          ,@nOriginalQty = OriginalQty -- (ChewKP01)  
   FROM dbo.Replenishment WITH (NOLOCK)   
   WHERE ReplenishmentKey = @cReplenishmentKey  
     
   SET @nTotalReplenQty = 0  
   SET @nTotalReplenQty = @nReplenQtyToMove - @nOriginalQty  
     
  
   EXECUTE dbo.nspItrnAddMove  
      NULL,  
      @cStorerkey,  
      @cSKU,  
      @cFromLOT,  
      @cOriginalFromLOC,  
      @cFromID,  
      @cReplenInProgressLOC,  
      @cFromID,  
      'OK',  
      '',  
      '',  
      '',  
      NULL,  
      NULL,  
      0,  
      0,  
      @nReplenQtyToMove,  
      0,  
      0,  
      0,  
      0,  
      0,  
      0,  
      @cReplenishmentKey,  
      'rdt_Wave_ReplenMove',  
      '',  
      '',  
      1,  
      NULL,  
      '',  
      @b_Success  OUTPUT,  
      @n_err      OUTPUT,  
      @c_errmsg   OUTPUT  
  
   IF NOT @b_success = 1  
   BEGIN  
      SET @nErrNo = 64323  
      SET @cErrMsg = rdt.rdtgetmessage( 64323, @cLangCode, 'DSP') --'ItrnMovefailed'  
      GOTO RollBackTran  
   END  
  
   UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET   
      QTYReplen = CASE WHEN @nReplenQtyToMove > QTYReplen THEN 0   
                  ELSE  QTYReplen - @nReplenQtyToMove END      -- (james01)  
   WHERE StorerKey = @cStorerKey  
      AND LOT = @cFromLOT  
      AND LOC = @cOriginalFromLOC  
      AND ID  = @cFromID  
      AND SKU = @cSKU  
  
   IF @@ERROR <> 0  
   BEGIN  
    SET @nErrNo = 67446  
      SET @cErrMsg = rdt.rdtgetmessage( 67446, @cLangCode, 'DSP') --'UPD LLI Fail'  
      GOTO RollBackTran  
   END  
  
   UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET   
      QTYReplen = CASE WHEN @nReplenQtyToMove > QTYReplen THEN 0   
                  ELSE  QTYReplen - @nReplenQtyToMove END      -- (james01)  
   WHERE StorerKey = @cStorerKey  
      AND LOT = @cFromLOT  
      AND LOC = @cReplenInProgressLOC  
      AND ID  = @cFromID  
      AND SKU = @cSKU  
  
   IF @@ERROR <> 0  
   BEGIN  
    SET @nErrNo = 67446  
      SET @cErrMsg = rdt.rdtgetmessage( 67446, @cLangCode, 'DSP') --'UPD LLI Fail'  
      GOTO RollBackTran  
   END  
     
   --Update Replen Task with same Loc,Lot,ID,SKU   
   -- to Confirmed = 'S' by ArichiveCop -- (Start) (ChewKP01)  
     
     
   SET @cReplenToByBatch = ''  
   SET @cReplenToByBatch = rdt.RDTGetConfig( @nFunc, 'ReplenToByBatch', @cStorerKey)      
     
   IF @cReplenToByBatch = '1'  
   BEGIN  
        
      --SET @nTotalReplenQty = 0  
        
        
            
        
      DECLARE CUR_DPREPELN CURSOR LOCAL READ_ONLY FAST_FORWARD FOR       
      SELECT RPL.ReplenishmentKey, RPL.Qty  
      FROM dbo.Replenishment RPL WITH (NOLOCK)      
      Where RPL.StorerKey   = @cStorerKey      
          AND RPL.Confirmed  = 'N'      
          AND RPL.SKU        = @cSKU  
          AND RPL.FromLoc    = @cOriginalFromLOC        
          AND RPL.Lot        = @cFromLot  
          AND RPL.ReplenishmentKey <> @cReplenishmentKey  
      ORDER BY ReplenishmentKey  
        
      OPEN CUR_DPREPELN       
      FETCH NEXT FROM CUR_DPREPELN INTO @cDPReplenishmentKey, @nDPQty  
      WHILE @@FETCH_STATUS <> -1      
      BEGIN      
           
            If @nTotalReplenqty >= @nDPQty  
            BEGIN  
               UPDATE dbo.Replenishment   
               SET Confirmed = 'S'  
                   ,ReplenNo = @cReplenishmentKey  
                   ,FromLoc = @cReplenInProgressLOC
                   ,DropID = @cDropID  
                   ,EditDate = GETDATE()   
                   ,EditWho = 'rdt.' + sUser_sName()     
               WHERE ReplenishmentKey = @cDPReplenishmentKey  
                 
               SET @nTotalReplenQty = @nTotalReplenQty - @nDPQty  
            END  
              
              
         FETCH NEXT FROM CUR_DPREPELN INTO @cDPReplenishmentKey, @nDPQty     
      END  
      CLOSE CUR_DPREPELN         
      DEALLOCATE CUR_DPREPELN    
        
      IF @nTotalReplenQty <> 0  
      BEGIN  
               UPDATE dbo.Replenishment   
               SET Qty = OriginalQty + @nTotalReplenQty  
                   ,EditDate = GETDATE()   
                   ,EditWho = 'rdt.' + sUser_sName()     
               WHERE ReplenishmentKey = @cReplenishmentKey  
      END  
      ELSE
      BEGIN
               UPDATE dbo.Replenishment   
               SET Qty = OriginalQty
                   ,EditDate = GETDATE()   
                   ,EditWho = 'rdt.' + sUser_sName()     
               WHERE ReplenishmentKey = @cReplenishmentKey  
      END
        
        
        
   END  
     
     
     
   --Update Replen Task with same Loc,Lot,ID,SKU   
   -- to Confirmed = 'S' by ArichiveCop -- (End) (ChewKP01)  
  
   GOTO Quit     
  
   RollBackTran:  
      ROLLBACK TRAN Wave_RepleMove  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN Wave_RepleMove  

GO