SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: ispItrnAddMoveQtyAllocated                         */      
/* Creation Date:                                                       */      
/* Copyright: LF Logistics                                              */      
/* Written by: SHONG                                                    */      
/*                                                                      */      
/* Purpose:                                                             */      
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 6.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author    Ver. Purposes                                 */      
/* 05-JUN-2014  Shong     1.0  Created                                  */
/************************************************************************/    
CREATE PROC [dbo].[ispItrnAddMoveQtyAllocated] (
   @cItrnKey    NVARCHAR(10)
  ,@cLOT        NVARCHAR(10)
  ,@cFromLOC    NVARCHAR(10) = ''
  ,@cFromID     NVARCHAR(18) = ''
  ,@cToLOC      NVARCHAR(10) = ''
  ,@cToID       NVARCHAR(18) = ''  
  ,@cUCCNo      NVARCHAR(20) = ''  -- Reserve for future used
  ,@nQty        INT          = 0
  ,@cFromToFlag CHAR(1)      = ''  -- F=From, T=To
  ,@bSuccess    INT OUTPUT    
  ,@nErr        INT OUTPUT    
  ,@cErrMsg     NVARCHAR(250) OUTPUT ) 
AS 
BEGIN
   DECLARE @nContinue         INT, 
           @nQtyToMove        INT, 
           @nCnt              INT,
           @cPickDetailKey    NVARCHAR(10),
           @nPD_Qty           INT,
           @cNewPickDetailKey NVARCHAR(10), 
           @nNonAllocatedQty  INT  
            
   
   SET @nContinue = 1
   
   IF @cFromToFlag = 'F'  
   BEGIN
      SET @nQtyToMove = 0 
      SET @nNonAllocatedQty = 0
      
      SELECT @nNonAllocatedQty = lli.Qty - (lli.QtyAllocated + lli.QtyPicked) 
      FROM LOTxLOCxID lli WITH (NOLOCK)
      WHERE lli.LOT = @cLOT
      AND lli.Loc   = @cFromLOC
      AND lli.Id    = @cFromID 
      
      IF @nNonAllocatedQty > 0 
         SET @nQtyToMove = @nQty - @nNonAllocatedQty
      ELSE
         SET @nQtyToMove = @nQty   
         
      IF @nQtyToMove <= 0 
      BEGIN
         RETURN 
      END
            
      WHILE @nQtyToMove > 0 AND (@nContinue = 1 OR @nContinue = 2)
      BEGIN
         SET @nPD_Qty = 0 
         
         SELECT TOP 1 
            @nPD_Qty = P.Qty,
            @cPickDetailKey = p.PickDetailKey
         FROM PICKDETAIL p WITH (NOLOCK)
         WHERE LOT = @cLOT 
           AND LOC = @cFromLOC 
           AND ID  = @cFromID   
           AND STATUS < '9' 
           AND Qty > 0 
         ORDER BY CASE WHEN Qty = @nQtyToMove THEN 1 
                       WHEN Qty < @nQtyToMove THEN 2
                       ELSE 9 
                  END 
         
         IF @nPD_Qty = 0 OR @nQtyToMove = 0 
            BREAK
                  
         IF @nPD_Qty > 0 AND @nPD_Qty <= @nQtyToMove
         BEGIN
            UPDATE PICKDETAIL with (ROWLOCK)   
               SET QTYMOVED = @nPD_Qty,      
                   QTY = 0 
            WHERE PickDetailKey = @cPickDetailKey      
            AND STATUS < '9'   
         
            SELECT @nErr = @@ERROR, @nCnt = @@ROWCOUNT      
            IF @nErr <> 0      
            BEGIN      
               SELECT @nContinue = 3      
               SELECT @nErr = 62029   
               SELECT @cErrMsg='NSQL'+CONVERT(varchar(5),@nErr)+': Update Failed On Table PickDetail. (ispItrnAddMoveQtyAllocated)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@cErrMsg),'') + ' ) '      
            END 
            
            SET @nQtyToMove = @nQtyToMove - @nPD_Qty      
         END
         ELSE IF @nPD_Qty > 0 AND @nPD_Qty > @nQtyToMove
         BEGIN
            -- 
            UPDATE PICKDETAIL with (ROWLOCK)   
               SET QTY = QTY - @nQtyToMove       
            WHERE PickDetailKey = @cPickDetailKey      
            AND STATUS < '9'             
            SELECT @nErr = @@ERROR, @nCnt = @@ROWCOUNT      
            IF @nErr <> 0      
            BEGIN      
               SELECT @nContinue = 3      
               SELECT @nErr = 62029   
               SELECT @cErrMsg='NSQL'+CONVERT(varchar(5),@nErr)+': Update Failed On Table PickDetail. (ispItrnAddMoveQtyAllocated)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@cErrMsg),'') + ' ) '      
            END             
            -- split PickDetail if Pick Qty > Qty to Move

            EXECUTE dbo.nspg_GetKey    
               'PICKDETAILKEY',     
               10 ,    
               @cNewPickDetailKey  OUTPUT,    
               @bSuccess        OUTPUT,    
               @nErr            OUTPUT,    
               @cErrMsg         OUTPUT    

            IF @bSuccess <> 1    
            BEGIN    
               SELECT @nContinue = 3      
               SELECT @nErr = 62029   
               SELECT @cErrMsg='NSQL'+CONVERT(varchar(5),@nErr)+': Get Pickdetail Key Fail. (ispItrnAddMoveQtyAllocated)'               
            END    

            INSERT INTO dbo.PICKDETAIL    
               (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku,     
                UOM, UOMQty, Qty, QtyMoved, Status, DropID, Loc, ID, PackKey, UpdateSource,     
                CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,     
                WaveKey, EffectiveDate, TrafficCop, ArchiveCop, OptimizeCop, ShipFlag, PickSlipNo)    
            SELECT @cNewPickDetailKey AS PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku,     
               UOM, UOMQty, 0 AS QTY, QtyMoved=@nQtyToMove, [STATUS], DropID, Loc, ID, PackKey, UpdateSource,     
               CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,     
               WaveKey, EffectiveDate, TrafficCop, ArchiveCop, OptimizeCop='1', ShipFlag, PickSlipNo     
            FROM dbo.PickDetail WITH (NOLOCK)     
            WHERE PickDetailKey = @cPickDetailKey 
            SELECT @nErr = @@ERROR, @nCnt = @@ROWCOUNT      
            IF @nErr <> 0      
            BEGIN      
               SELECT @nContinue = 3      
               SELECT @nErr = 62029   
               SELECT @cErrMsg='NSQL'+CONVERT(varchar(5),@nErr)+': Insert To PickDetail Failed. (ispItrnAddMoveQtyAllocated)'   
            END 
                                                
            SET @nQtyToMove = 0 
         END -- IF @nPD_Qty > 0 AND @nPD_Qty > @nQtyToMove                   
      END -- WHILE @nQtyToMove > 0
   END
   IF @cFromToFlag = 'T'
   BEGIN
      UPDATE PICKDETAIL WITH (ROWLOCK)   
         SET QtyMoved = 0,      
             QTY = QtyMoved,      
             LOC = @cToLoc,      
             ID  = @cToID       
      WHERE LOT = @cLOT 
        AND LOC = @cFromLoc 
        AND ID  = @cFromID      
        AND STATUS < '9' 
        AND QtyMoved > 0   
      SELECT @nErr = @@ERROR, @nCnt = @@ROWCOUNT      
      IF @nErr <> 0      
      BEGIN      
         SELECT @nContinue = 3      
         SELECT @nErr = 62029   
         SELECT @cErrMsg='NSQL'+CONVERT(varchar(5),@nErr)+': Update PickDetail Failed. (ispItrnAddMoveQtyAllocated)' 
      END                
   END -- IF @cFromToFlag = 'T'   
END      

GO