SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispReverseDynamicLocReplenishment                  */  
/* Creation Date: 30-Jun-2009                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose: SOS140686                                                   */  
/*          Replenishment and Dynamic Pick location assignment          */  
/*                                                                      */  
/* Called By: RCM Option From Wave maintenance Screen                   */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 6.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.    Purposes                              */ 
/* 27-May-2011  NJOW01    1.1     216932-Reverse original id            */
/* 02-Aug-2011  TLTING    1.2     Commit by Line                        */
/************************************************************************/ 
CREATE PROC [dbo].[ispReverseDynamicLocReplenishment] 
   @cWaveKey NVARCHAR(10),
   @bSuccess INT OUTPUT,
   @nErrNo   INT OUTPUT,
   @cErrMsg  NVARCHAR(215) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @nContinue              INT
           ,@nStartTranCount        INT
           ,@cStorerKey             NVARCHAR(15)
           ,@cSKU                   NVARCHAR(20)
           ,@cLOT                   NVARCHAR(10)
           ,@cLOC                   NVARCHAR(10)
           ,@cID                    NVARCHAR(18)
           ,@bDebug                 INT
           ,@cReplenishmentKey      NVARCHAR(10)
           ,@cPickDetailKey         NVARCHAR(10)
           ,@nErr                   INT
           ,@nQty                   INT
           ,@cOriginalFromLoc       NVARCHAR(10)
           ,@cOriginalFromID        NVARCHAR(18) --NJOW01
           ,@cPackKey               NVARCHAR(10)
           ,@cUOM                   NVARCHAR(10)
           ,@cPrevReplenishmentKey  NVARCHAR(10)
    
    
    SET @nContinue = 1
    SET @nErrNo = 0
    SET @cErrMsg = ''
    SET @nStartTranCount = @@TRANCOUNT 
    SET @nErrNo = 70500
    
    SET @bDebug = 0
    IF @bSuccess=9
        SET @bDebug = 1
    
    --BEGIN TRAN 
    
    SET @cPrevReplenishmentKey = ''

    WHILE @@TRANCOUNT>0 
          COMMIT TRAN 
              
    -- Remove Previous Generated Replenishment Record
    -- Begin
    DECLARE CUR_DELETE_REPLEN  CURSOR LOCAL FAST_FORWARD READ_ONLY 
    FOR
        SELECT ReplenishmentKey
              ,REPLENISHMENT.OriginalFromLoc
              ,REPLENISHMENT.ID --NJOW01
        FROM   REPLENISHMENT WITH (NOLOCK)
        WHERE  WaveKey = @cWaveKey
               AND REPLENISHMENT.Confirmed NOT IN ('S' ,'Y')
        ORDER BY
               ReplenishmentKey 
    
    OPEN CUR_DELETE_REPLEN
    FETCH NEXT FROM CUR_DELETE_REPLEN INTO @cReplenishmentKey, @cOriginalFromLoc, @cOriginalFromID --NJOW01                               
    
    WHILE @@FETCH_STATUS<>-1
    BEGIN
    		BEGIN TRAN
    			
        DECLARE CUR_PickDetail  CURSOR LOCAL FAST_FORWARD READ_ONLY 
        FOR
            SELECT PICKDETAIL.LOT
                  ,PICKDETAIL   .LOC
                  ,PICKDETAIL   .ID
                  ,PICKDETAIL   .Qty
                  ,PICKDETAIL   .PickDetailKey
            FROM   PICKDETAIL WITH (NOLOCK)
                   JOIN WAVEDETAIL WITH (NOLOCK)
                        ON  WAVEDETAIL.OrderKey = PICKDETAIL.OrderKey
            WHERE  PICKDETAIL.PickHeaderKey = @cReplenishmentKey
                   AND WAVEDETAIL.WaveKey = @cWaveKey
            ORDER BY
                   PICKDETAIL.PickDetailKey 
        
        OPEN CUR_PickDetail 
        
        FETCH NEXT FROM CUR_PickDetail INTO @cLOT, @cLOC, @cID, @nQty, @cPickDetailKey                                
        
        WHILE @@FETCH_STATUS<>-1
        BEGIN
            IF @bDebug=1
            BEGIN
                SELECT @cReplenishmentKey '@cReplenishmentKey'
                      ,@cLOT '@cLOT'
                      ,@cLOC '@cLOC'
                      ,@cID '@cID'
                      ,@nQty '@nQty'
                      ,@cPickDetailKey '@cPickDetailKey'
                      ,@cOriginalFromLoc '@cOriginalFromLoc'
            END
            
            -- Reverse the Dynamic Pick Location back to the Original Pick Location (Bulk)
            UPDATE PickDetail WITH (ROWLOCK)
            SET    LOC = @cOriginalFromLoc,
                   ID = @cOriginalFromID  --NJOW01
            WHERE  PickDetailKey = @cPickDetailKey
            
            IF @@ERROR<>0
            BEGIN
                SET @nErrNo = @nErrNo+1
                SET @cErrMsg = 'Update PickDetail Failed!'
                SET @nContinue = 3 
                GOTO ErrorHandling
            END
            
            UPDATE LOTxLOCxID WITH (ROWLOCK)
            SET    QtyReplen = CASE 
                                    WHEN QtyReplen<@nQty THEN 0
                                    ELSE QtyReplen- @nQty
                               END
            WHERE  LOT = @cLOT
                   AND LOC = @cOriginalFromLoc
                   AND ID = @cOriginalFromID  --NJOW01
                  -- AND ID = @cID
            
            IF @@ERROR<>0
            BEGIN
                SET @nErrNo = @nErrNo+1
                SET @cErrMsg = 'Update LOTxLOCxID Failed!'
                SET @nContinue = 3 
                GOTO ErrorHandling
            END
            
            --NJOW01
            UPDATE LOTxLOCxID WITH (ROWLOCK)
            SET    PendingMoveIN = CASE 
                           WHEN PendingMoveIN<@nQty THEN 0
                               ELSE PendingMoveIN - @nQty
                           END
            WHERE  LOT = @cLOT 
            AND LOC = @cLOC
            AND ID =''
            
            IF @@ERROR<>0
            BEGIN
               SET @nErrNo = @nErrNo+1
               SET @cErrMsg = 'Update LOTxLOCxID Failed!'
               SET @nContinue = 3 
               GOTO ErrorHandling
            END
            
            FETCH NEXT FROM CUR_PickDetail INTO @cLOT, @cLOC, @cID, @nQty, @cPickDetailKey
        END
        CLOSE CUR_PickDetail
        DEALLOCATE CUR_PickDetail
        
        
        DELETE REPLENISHMENT with (ROWLOCK)
        WHERE  ReplenishmentKey = @cReplenishmentKey
        
        IF @@ERROR<>0
        BEGIN
            SET @nErrNo = @nErrNo+1
            SET @cErrMsg = 'Delete Replenishment Record Fail!'
            SET @nContinue = 3 
            GOTO ErrorHandling
        END

        COMMIT TRAN 
		                  
        FETCH NEXT FROM CUR_DELETE_REPLEN INTO @cReplenishmentKey, @cOriginalFromLoc, @cOriginalFromID --NJOW01
    END
    CLOSE CUR_DELETE_REPLEN
    DEALLOCATE CUR_DELETE_REPLEN
    
    WHILE @@TRANCOUNT<@nStartTranCount 
          BEGIN TRAN 
    
    RETURN
    
    ErrorHandling:
    IF @nContinue=3
    BEGIN
        IF @@TRANCOUNT>@nStartTranCount
            ROLLBACK TRAN
        
        EXECUTE nsp_Logerror @nErrNo, @cErrMsg, 
        'ispReverseDynamicLocReplenishment'
        RAISERROR (@cErrMsg, 16, 1) WITH SETERROR    -- SQL2012
        RETURN
    END
END -- Procedure

GO