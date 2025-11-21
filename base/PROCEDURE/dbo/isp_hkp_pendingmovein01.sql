SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_HKP_PendingMoveIn01                             */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Clean Up PendingMoveIn                                      */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 22-01-2015 1.0  ChewKP   Created. SOS#321239                         */
/************************************************************************/

CREATE PROC [dbo].[isp_HKP_PendingMoveIn01] (
     @cStorerKey           NVARCHAR( 15) 
    ,@nErrNo               INT          OUTPUT
    ,@cErrMsg              NVARCHAR(20) OUTPUT -- screen limitation, 20 char max

 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success     INT
       , @nTranCount      INT
       , @bDebug          INT
       , @cMaxAddDate     DATETIME
       , @nRowRef         INT
       , @cSKU            NVARCHAR(20)
       , @cLot            NVARCHAR(10)
       , @cFromLoc        NVARCHAR(10)
       , @cToLoc          NVARCHAR(10)
       , @cToID           NVARCHAR(18)
       , @nQty            INT
       , @cCaseID         NVARCHAR(20)
       , @cFromID         NVARCHAR(18)
       , @cUCCNo          NVARCHAR(20)
       , @cCondition      NVARCHAR(1)


       
     
   SET @nTranCount = @@TRANCOUNT
   SET @nErrNo     = 0

   BEGIN TRAN
   SAVE TRAN ClearPendingMoveIn
   


   
   -- Exist in PendingMoveIn but do not have RFPutaway, Update PendingMove to 0
   DECLARE CursorPendingMoveIn CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT LLI.LOT, LLI.LOC, LLI.ID, LLI.SKU FROM LOTXLOCXID LLI WITH (NOLOCK)
   WHERE LLI.STORERKEY = @cStorerKey
   AND LLI.PENDINGMOVEIN > 0 
   
   OPEN CursorPendingMoveIn            
   
   FETCH NEXT FROM CursorPendingMoveIn INTO @cLot, @cFromLoc, @cFromID, @cSKU
   WHILE @@FETCH_STATUS <> -1     
   BEGIN

         IF NOT EXISTS ( SELECT 1 FROM dbo.RFPutaway WITH (NOLOCK)
                         WHERE SuggestedLoc  = @cFromLoc
                         AND   SKU           = @cSKU
                         AND   LOT           = @cLot
                         AND   StorerKey     = @cStorerKey
                         AND   ID            = @cFromID ) 
                         
         BEGIN   
            UPDATE dbo.LotxLocxID WITH (ROWLOCK)
               SET PendingMoveIn = CASE WHEN PendingMoveIn > @nQty THEN PendingMoveIN - @nQty ELSE 0 END
            WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND Lot = @cLot
            AND Loc = @cFromLoc
            AND ID  = @cFromID
            
            IF @@ERROR  <> 0 
            BEGIN
                   SET @nErrNo = 62776  
                   SET @cErrMsg = 'Update PendingMoveIn Fail.'  
                   GOTO RollBackTran
            END
         
         END
      
          
      FETCH NEXT FROM CursorPendingMoveIn INTO @cLot, @cFromLoc, @cFromID, @cSKU
      
   END
   CLOSE CursorPendingMoveIn            
   DEALLOCATE CursorPendingMoveIn      
   
   
   
   -- Have RFPutaway but do not have corresponding PendingMoveIn records in LLI , delete RFPutaway
   DECLARE CursorRFPutaway CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT LOT, SuggestedLoc, ID, SKU, RowRef
   FROM dbo.RFPutaway WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey
   ORDER BY SuggestedLoc
   
   OPEN CursorRFPutaway            
   
   FETCH NEXT FROM CursorRFPutaway INTO @cLot, @cFromLoc, @cFromID, @cSKU, @nRowRef
   WHILE @@FETCH_STATUS <> -1     
   BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.LotXLocxID WITH (NOLOCK)
                         WHERE Loc           = @cFromLoc
                         AND   SKU           = @cSKU
                         AND   LOT           = @cLot
                         AND   StorerKey     = @cStorerKey
                         AND   ID            = @cFromID
                         AND   PendingMoveIn   > 0  ) 
         BEGIN
                         
           DELETE dbo.RFPutaway WITH (ROWLOCK)
           WHERE RowRef = @nRowRef
           
           IF @@ERROR  <> 0 
           BEGIN
                   SET @nErrNo = 62777  
                   SET @cErrMsg = 'Delete RFPutaway Fail'  
                   GOTO RollBackTran
           END
            
         END
         FETCH NEXT FROM CursorRFPutaway INTO @cLot, @cFromLoc, @cFromID, @cSKU, @nRowRef
      
   END
   
   CLOSE CursorRFPutaway            
   DEALLOCATE CursorRFPutaway
   
   
   
   DECLARE CursorRFPutawayTD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   
   SELECT RF.LOT, RF.SuggestedLoc, RF.ID, RF.SKU, RF.FromLoc, RF.CaseID, RowRef
   FROM dbo.RFPutaway RF WITH (NOLOCK)
   INNER JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON LLI.StorerKey = RF.StorerKey AND LLI.Lot = RF.Lot AND LLI.Loc = RF.SuggestedLoc AND LLI.ID = RF.ID AND LLI.SKU = RF.SKU
   WHERE RF.Storerkey = @cStorerKey
   AND LLI.PendingMoveIn > 0 
   ORDER BY RF.SuggestedLoc     
   
   OPEN CursorRFPutawayTD            
   
   FETCH NEXT FROM CursorRFPutawayTD INTO @cLot, @cToLoc, @cFromID, @cSKU, @cFromLoc, @cUCCNo, @nRowRef
   WHILE @@FETCH_STATUS <> -1     
   BEGIN
      
      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKEy
                  AND TaskType    = 'PA'
                  AND Status      IN ( 'X', '9') 
                  AND FromLoc     = @cFromLoc
                  AND FromID      = @cFromID
                  AND ToLoc       = @cToLoc
                  AND CaseID      = @cUCCNo ) 
      BEGIN

         SET @cCondition = '1'
      END
      ELSE
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKEy
            AND TaskType    = 'RPF'
            AND Status      IN ( 'X', '9') 
            AND FromLoc     = @cFromLoc
            AND FromID      = @cFromID
            AND Message02   = @cToLoc
            AND CaseID      = @cUCCNo
            AND SourceType  = 'ispTransferAlloction' ) 
         BEGIN
         
            SET @cCondition = '1'
         END
      END
      
      IF @cCondition = '1'
      BEGIN
         
            UPDATE dbo.LotxLocxID WITH (ROWLOCK)
               SET PendingMoveIn = CASE WHEN PendingMoveIn > @nQty THEN PendingMoveIN - @nQty ELSE 0 END
            WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND Lot = @cLot
            AND Loc = @cToLoc
            AND ID  = @cFromID
            
            IF @@ERROR  <> 0 
            BEGIN
                   SET @nErrNo = 62778  
                   SET @cErrMsg = 'Update PendingMoveIn Fail'  
                   GOTO RollBackTran
            END
            
            DELETE FROM dbo.RFPutaway WITH (ROWLOCK)
            WHERE RowRef = @nRowRef
            
            IF @@ERROR <> 0 
            BEGIN
                   SET @nErrNo = 62779
                   SET @cErrMsg = 'Delete RFPutaway Fail'  
                   GOTO RollBackTran
            END
      END
      
      FETCH NEXT FROM CursorRFPutawayTD INTO @cLot, @cToLoc, @cFromID, @cSKU, @cFromLoc, @cUCCNo, @nRowRef
   END
   
   CLOSE CursorRFPutawayTD            
   DEALLOCATE CursorRFPutawayTD
    
   GOTO QUIT

   RollBackTran:
   ROLLBACK TRAN ClearPendingMoveIn     
   
   
  
    
   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
         COMMIT TRAN ClearPendingMoveIn
         
   IF @nErrNo <> 0 
   BEGIN
      EXECUTE nsp_logerror @nErrNo, @cErrMsg, 'isp_HKP_PendingMoveIn01'  
      RAISERROR (@cErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
   END
   
END

GO