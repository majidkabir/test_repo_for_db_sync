SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store procedure: rdt_DropID_Replen_To                                */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Purpose: Confirm Replen                                              */      
/*                                                                      */      
/* Called from: rdt_DropID_Replen_To                                    */      
/*                                                                      */      
/* Exceed version: 5.4                                                  */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date       Rev  Author   Purposes                                    */      
/* 2011-07-06 1.0  ChewKP   Created                                     */      
/* 2011-12-29 1.1  James    Bug fix (james01)                           */      
/* 2011-12-31 1.2  ChewKP   Multi Wave Fixes (ChewKPXX)                 */   
/* 2012-01-01 1.3  Shong    Bug fix                                     */  
/* 2012-01-02 1.4  Shong    Add ToID when Offset other replen task      */  
/* 2012-01-06 1.5  James    Fix cursor variables problem (james02)      */  
/* 2012-01-12 1.6  SHONG001 Passing LOT and ID to Replen To SP          */  
/* 2012-02-01 1.7  SHONG002 Remove Multi Batch Replenishment            */  
/* 2012-02-02 1.8  SHONG    Revise Logic again                          */  
/* 2012-02-04 1.9  SHONG    Fix No Residual Replen task creat issues    */  
/* 2012-04-02 2.0  SHONG    Exclude HOLD Location when search DPP Loc   */  
/*                          SOS#240525                                  */  
/* 2012-04-19 2.1  James    SOS242077 - Bug fix (james03)               */
/* 2012-05-03 2.2  SHONG    Fixing multiple record offset issues        */  
/************************************************************************/      
CREATE PROC [RDT].[rdt_DropID_Replen_To] (    
     @nMobile        INT    
    ,@nFunc          INT    
    ,@cStorerKey     NVARCHAR(15)    
    ,@cUserName      NVARCHAR(15)    
    ,@cDropID        NVARCHAR(18)    
    ,@cSKU           NVARCHAR(20)    
    ,@cToLoc         NVARCHAR(10)        
    ,@cLangCode      NVARCHAR(3)    
    ,@nErrNo         INT         OUTPUT    
    ,@cErrMsg        NVARCHAR(20) OUTPUT -- screen limitation, 20 char max    
    ,@nTotalQtyToMove       INT    
    ,@cFromLOT       NVARCHAR(10) = ''  -- SHONG001  
    ,@cFromID        NVARCHAR(18) = ''  -- SHONG001  
 )        
AS    
BEGIN    
    SET NOCOUNT ON        
    SET QUOTED_IDENTIFIER OFF        
    SET ANSI_NULLS OFF        
    SET CONCAT_NULL_YIELDS_NULL OFF        
        
    DECLARE @b_success             INT    
           
           ,@nTranCount            INT        
        
    DECLARE @cLot                  NVARCHAR(10)    
           ,@cFromLoc              NVARCHAR(10)    
           ,@cID                   NVARCHAR(18)    
           ,@cReplenishmentKey     NVARCHAR(10)    
           ,@nQTY                  INT    
           ,@nQtyExceeded            INT    
           ,@cReplenByOriginalQty  NVARCHAR(1)    
           ,@nOriginalQty          INT    
           ,@cNewReplenishmentKey  NVARCHAR(10)    
           ,@cFacility             NVARCHAR(5)    
           ,@cLoc                  NVARCHAR(10)    
           ,@cOriginalFromLoc      NVARCHAR(10)    
           ,@cLottable02           NVARCHAR(18)    
           ,@cGenDynLocReplenBySKUBatch NVARCHAR(1)    
           ,@cReplenToByBatch      NVARCHAR(1)     
           ,@cDPReplenishmentKey   NVARCHAR(10)    
           ,@nDPQty                INT    
           ,@cDPCount              INT    
           ,@nDPOriginalQty        INT -- (ChewKPXX)     
           ,@cDPID                 NVARCHAR(18)    
           ,@cDPLoc                NVARCHAR(10)   
           ,@nResidualQty          INT  
           ,@cResidualReplKey      NVARCHAR(10)
           ,@nTotalOrigQty         INT
           ,@nTotalQty             INT   
  
    SET @nResidualQty = 0  
    SET @cResidualReplKey = ''  
               
    SET @nTranCount = @@TRANCOUNT     
        
    BEGIN TRAN     
    SAVE TRAN DropID_Replen_Confirm        
        
    SET @cFacility = ''    
    SELECT  @cFacility = Facility    
    FROM rdt.rdtMobRec WITH (NOLOCK)    
    WHERE Mobile = @nMobile    
        
        
    -- ConfigKey ReplenByOriginalQty    
    -- This configkey will only replen by Original Qty     
    -- Residual Replen task will be created and move to DPP Loc    
     
    SET @cGenDynLocReplenBySKUBatch = ''    
    SELECT @cGenDynLocReplenBySKUBatch = SValue     
    FROM dbo.StorerConfig WITH (NOLOCK)    
    WHERE Configkey = 'GenDynLocReplenBySKUBatch'    
    AND StorerKEy = @cStorerKey    
        
    SET @cReplenToByBatch = ''    
    SET @cReplenToByBatch = rdt.RDTGetConfig( @nFunc, 'ReplenToByBatch', @cStorerKey)         
        
    IF @cReplenToByBatch = '1'    
    BEGIN    
       SET @nTotalQty = 0
       SET @nTotalOrigQty = 0 

       SELECT @nTotalQty     = SUM(RPL.Qty),    
              @nTotalOrigQty = SUM(RPL.OriginalQTY)    
       FROM dbo.Replenishment RPL WITH (NOLOCK)        
       INNER JOIN LotAttribute LA WITH (NOLOCK) ON (LA.Lot = RPL.Lot)     
       Where RPL.StorerKey   = @cStorerKey        
         AND RPL.DropID     = @cDropID        
         AND RPL.Confirmed  = ('S')        
         AND RPL.SKU        = @cSKU    
         AND RPL.TOLOC      = @cToLoc    
         AND RPL.LOT        = @cFromLOT    

       IF @nTotalQtyToMove > @nTotalOrigQty    
       BEGIN    
          SET @nQtyExceeded = @nTotalQtyToMove - @nTotalOrigQty     
       END    
       ELSE IF @nTotalOrigQty = @nTotalQtyToMove    
       BEGIN    
          IF @nTotalQty > @nTotalQtyToMove    
          BEGIN    
             SET @nQtyExceeded = @nTotalQty - @nTotalQtyToMove    
          END    
          ELSE    
          BEGIN    
             SET @nQtyExceeded = 0    
          END    
       END    
       ELSE IF @nTotalQtyToMove  < @nTotalOrigQty     
       BEGIN    
          SET @nQtyExceeded = 0     
       END    

       IF (SELECT SUM(QTY - QTYALLOCATED - QTYPICKED) 
                      FROM dbo.LotxLocxID WITH (NOLOCK)    
                      WHERE Lot = @cLOT    
                      AND Loc = @cFromLOC    
                      AND ID = @cID) < @nTotalQtyToMove  
       BEGIN    
         SET @nErrNo = 73457            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Qty      
         GOTO RollBackTran     
       END   
       
       DECLARE CUR_UPDRPL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR         
       SELECT RPL.ReplenishmentKey, RPL.LOT, RPL.FromLOC, RPL.ID, RPL.Qty,    
              RPL.OriginalQTY, RPL.OriginalFromLoc, LA.Lottable02    
       FROM dbo.Replenishment RPL WITH (NOLOCK)        
       INNER JOIN LotAttribute LA WITH (NOLOCK) ON (LA.Lot = RPL.Lot)     
       Where RPL.StorerKey   = @cStorerKey        
         AND RPL.DropID     = @cDropID        
         AND RPL.Confirmed  = ('S')        
         AND RPL.SKU        = @cSKU    
         AND RPL.TOLOC      = @cToLoc    
         AND RPL.LOT        = @cFromLOT    
       ORDER BY CASE WHEN ID = @cFromID THEN 1   
                     ELSE 9   
                END,  
                ReplenNo,    
                ReplenishmentKey  
       --ORDER BY ReplenishmentKey  (SHONG001)  
               
       OPEN CUR_UPDRPL         
         
       FETCH NEXT FROM CUR_UPDRPL INTO @cReplenishmentKey, @cLOT, @cFromLOC, @cID, @nQTY,   
                                       @nOriginalQty, @cOriginalFromLoc, @cLottable02     
       WHILE @@FETCH_STATUS <> -1        
       BEGIN        
          -- Validate Have Enough Qty to Move     
          IF NOT EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK)    
                         WHERE Lot = @cLOT    
                         AND Loc = @cFromLOC    
                         AND ID = @cID  
                         AND (QTY - QTYALLOCATED - QTYPICKED) >= @nOriginalQty    
                        )    
          BEGIN    
            SET @nErrNo = 73457            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Qty      
            GOTO RollBackTran     
          END         
             
          --IF @nQty > 0    
          IF @nOriginalQty > 0           
          BEGIN    
             UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)       
                SET QTYReplen = CASE WHEN QTYReplen > @nOriginalQty       
                                     THEN QTYReplen - @nOriginalQty      
                                     ELSE 0      
                                END         
             WHERE  LOT = @cLOT        
               AND LOC = @cFromLOC        
               AND ID  = @cID        
             IF @@ERROR <> 0         
             BEGIN        
                SET @nErrNo = 73453        
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Conf RPL Fail        
                GOTO RollBackTran        
             END        
             
             -- If move qty less then Original Qty, split replenishment record
             IF @nTotalQtyToMove < @nOriginalQty AND @nTotalQtyToMove > 0 
             BEGIN
                SET @cNewReplenishmentKey = ''  
                EXECUTE dbo.nspg_GetKey        
                   'REPLENISHMENT',        
                   10 ,        
                   @cNewReplenishmentKey OUTPUT,        
                   @b_success            OUTPUT,        
                   @nErrNo               OUTPUT,        
                   @cErrMsg              OUTPUT        
                   
                IF @b_success <> 1        
                BEGIN        
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKey Fail'        
                   GOTO RollBackTran        
                END        
                            
                INSERT INTO dbo.Replenishment (ReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, FromLoc, ToLoc,                        
                Lot, Id, Qty, QtyMoved, QtyInPickLoc, Priority, UOM, PackKey,         
                Confirmed, ReplenNo, Remark, RefNo, DropID, LoadKey, WaveKey, OriginalFromLoc, 
                OriginalQty, AddWho)                
                SELECT          
                   @cNewReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, FromLOC, ToLoc,      
                   Lot, Id, Qty - @nTotalQtyToMove, QtyMoved, QtyInPickLoc, '9', UOM, PackKey, 'S',                
                   @cReplenishmentKey, '', RefNo, @cDropID, LoadKey, WaveKey, OriginalFromLoc,   
                   @nTotalQtyToMove, '**'+AddWho  
                FROM dbo.Replenishment WITH (NOLOCK)        
                WHERE ReplenishmentKey = @cReplenishmentKey        
                      
                IF @@ERROR <> 0        
                BEGIN        
                   SET @nErrNo = 73455        
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins RPL Fail'        
                   GOTO RollBackTran        
                END     
                
                UPDATE REPLENISHMENT 
                  SET Qty = @nTotalQtyToMove 
                     ,OriginalQty = @nTotalQtyToMove
                     ,ArchiveCop = NULL 
                WHERE ReplenishmentKey = @cReplenishmentKey
                IF @@ERROR <> 0        
                BEGIN        
                   SET @nErrNo = 73454        
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'73454^Conf RPL Fail'        
                   GOTO RollBackTran        
                END     
                             	 
             	 SET @nOriginalQty = @nTotalQtyToMove 
             END
             
             -- Insert New Replen Record    
             IF @nQty > @nOriginalQty    
             BEGIN                        
                SET @nResidualQty = (@nQty - @nOriginalQty)  
                SET @cResidualReplKey = @cReplenishmentKey
                
                -- Confirm Source Original Replenishment Record  
                UPDATE dbo.Replenishment WITH (ROWLOCK)     
                   SET DropId = @cDropID,     
                       Confirmed = 'Y',  
                       Qty = OriginalQty 
                WHERE ReplenishmentKey = @cReplenishmentKey        
                      
                IF @@ERROR <> 0         
                BEGIN        
                   SET @nErrNo = 73463        
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Conf RPL Fail        
                   GOTO RollBackTran         
                END    
                  
                -- No More DP Location to be Replen , Generate DPP Task    
                -- After Done the Replenishment, if still have outstanding qty  
                IF @nResidualQty > 0     
                BEGIN    
                   -- GET TOLOC    
                   SET @cLoc = ''    
                      
                   -- Get existing DPP Location with same SKU x Lottable02 first    
                   SELECT TOP 1 @cLoc = LLI.LOC     
                   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)    
                   JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = LLI.Lot     
                   JOIN dbo.LOC WITH (NOLOCK) ON LOC.Loc = LLI.Loc    
                   WHERE LOC.locationtype = 'DYNPPICK'    
                   AND LOC.LocationFlag NOT IN ('HOLD','DAMAGE')   
                   AND LOC.[Status]     <> 'HOLD'  
                   AND LOC.Facility = @cFacility    
                   AND LLI.StorerKey = @cStorerKey     
                   AND LLI.Sku = @cSKU     
                   AND LA.Lottable02 = @cLottable02    
                   AND LLI.Qty - LLI.QtyPicked > 0 -- (Shongxxx)  
                       
                      
                   IF ISNULL(RTRIM(@cLoc),'') = ''     
                   BEGIN    
                      -- Get any other DPP location which is empty and no record in Replenishment Table    
                      SELECT TOP 1 @cLoc = LOC.LOC     
                      FROM dbo.LOC WITH (NOLOCK)    
                      LEFT OUTER JOIN dbo.SKUxLOC (NOLOCK) ON LOC.Loc = SKUxLOC.Loc     
                      WHERE LOC.locationtype = 'DYNPPICK'    
                      AND LOC.LocationFlag NOT IN ('HOLD','DAMAGE')   
                      AND LOC.[Status]     <> 'HOLD'                 
                      AND LOC.Facility = @cFacility    
                      AND LOC.LOC NOT IN (SELECT DISTINCT TOLOC FROM REPLENISHMENT R (NOLOCK) WHERE R.Confirmed = 'S')     
                      GROUP BY LOC.LOC     
                      HAVING SUM(ISNULL(SKUxLOC.Qty,0) - ISNULL(SKUxLOC.QtyPicked,0) ) = 0      
                      ORDER BY LOC.LOC     
                      
                      IF ISNULL(RTRIM(@cLoc),'') = ''    
                      BEGIN    
                         SET @nErrNo = 73456        
                         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DPPLocNotAvail'        
                         GOTO RollBackTran       
                     END    
                  END    
                       
                  SET @cNewReplenishmentKey = ''  
                  EXECUTE dbo.nspg_GetKey        
                   'REPLENISHMENT',        
                   10 ,        
                   @cNewReplenishmentKey OUTPUT,        
                   @b_success            OUTPUT,        
                   @nErrNo               OUTPUT,        
                   @cErrMsg              OUTPUT        
                   
                  IF @b_success <> 1        
                  BEGIN        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKey Fail'        
                     GOTO RollBackTran        
                  END        
                            
                  INSERT INTO dbo.Replenishment (ReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, FromLoc, ToLoc,                        
                  Lot, Id, Qty, QtyMoved, QtyInPickLoc, Priority, UOM, PackKey,         
                  Confirmed, ReplenNo, Remark, RefNo, DropID, LoadKey, WaveKey, OriginalFromLoc, OriginalQty, AddWho)                
                  SELECT          
                     @cNewReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, @cFromLOC, @cLoc,      
                     Lot, Id, @nResidualQty, QtyMoved, QtyInPickLoc, '9', UOM, PackKey, 'S',                
                     CASE WHEN ISNULL(RTRIM(@cResidualReplKey),'') <> '' THEN @cResidualReplKey   
                          ELSE @cReplenishmentKey  
                     END,   
                     '', RefNo, @cDropID, LoadKey, WaveKey, OriginalFromLoc,   
                     @nResidualQty, '**'+AddWho  
                  FROM dbo.Replenishment WITH (NOLOCK)        
                  WHERE ReplenishmentKey = @cReplenishmentKey        
                      
                  IF @@ERROR <> 0        
                  BEGIN        
                     SET @nErrNo = 73455        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins RPL Fail'        
                     GOTO RollBackTran        
                  END     
                       
                  SET @nQtyExceeded = @nQtyExceeded - @nResidualQty     
                  SET @nResidualQty = 0    
               END  -- IF @nResidualQty > 0                                     
             END -- IF @nQty > @nOriginalQty
             ELSE      
             BEGIN    
               UPDATE dbo.Replenishment WITH (ROWLOCK)     
               SET DropId = @cDropID,     
                   Confirmed = 'Y'       
               WHERE ReplenishmentKey = @cReplenishmentKey        
               IF @@ERROR <> 0         
               BEGIN        
                  SET @nErrNo = 73464        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Conf RPL Fail        
                  GOTO RollBackTran         
               END      
            END  
            
            SET @nTotalQtyToMove = @nTotalQtyToMove - @nOriginalQty
            
            IF @nTotalQtyToMove <= 0 
               BREAK
                   
         END -- If @nOriginalQty > 0     
         ELSE    
         BEGIN    
            UPDATE dbo.Replenishment WITH (ROWLOCK)     
               SET DropId = @cDropID,     
                   Confirmed = 'Y',        
                   ArchiveCop = NULL    
            WHERE ReplenishmentKey = @cReplenishmentKey        
                   
            IF @@ERROR <> 0         
            BEGIN        
               SET @nErrNo = 73461        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Conf RPL Fail        
               GOTO RollBackTran         
            END      
         END    
           
         -- SHONG 28th Jan 2012  
         -- No Loop required, all the records should updated at inner loop  
         -- DPP loc shouldn't have any left over  
         --IF NOT EXISTS (SELECT 1 FROM dbo.Loc WITH (NOLOCK)    -- (james03)  
         --      WHERE Loc = @cOriginalFromLoc    
         --      AND LocationType =  'DYNPPICK')    
         --BEGIN  
         --   BREAK  
         --END  
         --ELSE  
         --BEGIN  
            FETCH NEXT FROM CUR_UPDRPL INTO @cReplenishmentKey, @cLOT, @cFromLOC, @cID, @nQTY, @nOriginalQty, @cOriginalFromLoc, @cLottable02              
         --END  
      END        
      CLOSE CUR_UPDRPL        
      DEALLOCATE CUR_UPDRPL     
   END -- IF @cReplenToByBatch = '1'  
   ELSE    
   BEGIN    
      DECLARE CUR_UPDRPL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR         
      SELECT ReplenishmentKey, LOT, FromLOC, ID, QTY--, ToLoc         
      FROM dbo.Replenishment WITH (NOLOCK)        
      Where StorerKey   = @cStorerKey        
         AND DropID     = @cDropID        
         AND Confirmed  = ('S')        
         AND SKU        = @cSKU    
         AND TOLOC      = @cToLoc          
      ORDER BY ReplenishmentKey        
      OPEN CUR_UPDRPL         
      FETCH NEXT FROM CUR_UPDRPL INTO @cReplenishmentKey, @cLOT, @cFromLOC, @cID, @nQTY--, @cToLoc         
      WHILE @@FETCH_STATUS <> -1        
      BEGIN        
         -- Validate Have Enough Qty to Move     
         IF NOT EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK)    
                       WHERE Lot = @cLOT  
                       AND Loc = @cFromLOC  
                       AND ID = @cID    
                       AND (QTY - QTYALLOCATED - QTYPICKED) >= @nQty    
                        )    
         BEGIN    
            SET @nErrNo = 73458            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Qty      
            GOTO RollBackTran     
         END         
          
         UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)       
            SET QTYReplen = CASE WHEN QTYReplen > @nQTY       
                                 THEN QTYReplen - @nQTY      
                                 ELSE 0      
                            END         
        WHERE  LOT = @cLOT        
            AND LOC = @cFromLOC        
            AND ID  = @cID        
            AND SKU = @cSKU    
         IF @@ERROR <> 0         
         BEGIN        
            SET @nErrNo = 73451        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Conf RPL Fail        
            GOTO RollBackTran        
         END        
          
         UPDATE dbo.Replenishment WITH (ROWLOCK)     
               SET DropId = @cDropID,     
                   Confirmed = 'Y'        
         WHERE ReplenishmentKey = @cReplenishmentKey        
         IF @@ERROR <> 0         
         BEGIN        
            SET @nErrNo = 73452     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Conf RPL Fail        
            GOTO RollBackTran         
         END        
          
         FETCH NEXT FROM CUR_UPDRPL INTO @cReplenishmentKey, @cLOT, @cFromLOC, @cID, @nQTY--, @cToLoc         
      END        
      CLOSE CUR_UPDRPL        
      DEALLOCATE CUR_UPDRPL       
    END -- IF @cReplenToByBatch <> '1'  
     
     
 GOTO Quit     
        
 RollBackTran:     
 ROLLBACK TRAN DropID_Replen_Confirm     
     
 Quit:        
 WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started        
       COMMIT TRAN DropID_Replen_Confirm    
END

GO