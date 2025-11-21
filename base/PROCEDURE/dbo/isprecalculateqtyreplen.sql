SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispReCalculateQtyReplen                            */  
/* Creation Date: 15-Nov-2010                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose: UK - Republic Calculate Qty Replen                          */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By: Brio Report                                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author      Purposes                                    */  
/* 2010-12-03   ChewKP      Revise Coding to avoid DB Locking (ChewKP01)*/  
/************************************************************************/  
CREATE PROC  [dbo].[ispReCalculateQtyReplen] (  
   @cLoadkey         NVARCHAR( 20) = '',  
   @nErrNo           INT          OUTPUT,    
   @cErrMsg          NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
     
)  
  
     
AS  
BEGIN  
     
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   SET NOCOUNT ON  
  
        
      DECLARE  @cLOT    NVARCHAR(10),  
               @cLOC    NVARCHAR(10),  
               @cID     NVARCHAR(18),  
               @nQtyReplen     INT,  
               @nQtyReplenTask INT,  
               @nQtyReplenLog  INT,  
               @nQty           INT,  
               @nQtyDPK        INT,  
               @nTranCount     INT    
     
   SET @nErrNo = 0  
   SET @nTranCount = @@TRANCOUNT    
  
-- (ChewKP01)     
--   BEGIN TRAN                 
--   SAVE TRAN LLI_QtyReplen    
        
      IF @cLoadkey = ''  
      BEGIN  
         DECLARE CUR_QTYREPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT LLI.LOT, LLI.LOC, LLI.ID, ISNULL(LLI.QTYReplen,0) AS QtyReplen, LLI.Qty    
         FROM LOTxLOCxID lli WITH (NOLOCK)   
         LEFT OUTER JOIN (SELECT LOT, FROMLOC, FROMID  
                          FROM  TaskDetail WITH (NOLOCK)  
                          WHERE TaskType ='DRP'   
                          AND   Status NOT IN ('9','X')  
                          GROUP BY LOT, FROMLOC, FROMID) TD ON LLI.LOT = TD.LOT AND LLI.LOC = TD.FROMLOC AND LLI.ID = TD.FROMID  
         LEFT OUTER JOIN (SELECT RL.FromLoc, RL.FromLot, RL.FromID  
                          FROM rdt.rdtDPKLog RL WITH (NOLOCK)  
                          WHERE PAQty > 0 ) PA ON LLI.LOT = PA.FROMLOT AND LLI.LOC = PA.FROMLOC AND LLI.ID = PA.FROMID  
         WHERE LLI.QTYReplen <>0 OR   
               TD.LOT IS NOT NULL OR   
               PA.FromLOT IS NOT NULL    
         UNION ALL   
         SELECT DISTINCT PD.LOT, PD.TOLOC, PD.ID, ISNULL(LLI.QTYReplen,0) AS QtyReplen, LLI.Qty    
         FROM PICKDETAIL PD WITH (NOLOCK)         
         JOIN LOTxLOCxID lli WITH (NOLOCK) ON lli.Lot = PD.Lot AND lli.Loc = PD.TOLOC AND lli.Id = PD.ID   
         WHERE PD.Status = 0 AND CASEID = '' AND PD.LOC LIKE 'PTS%'   
      END  
      ELSE  
      BEGIN  
         DECLARE CUR_QTYREPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT LLI.LOT, LLI.LOC, LLI.ID, ISNULL(LLI.QTYReplen,0) AS QtyReplen, LLI.Qty    
               FROM LOTxLOCxID lli WITH (NOLOCK)   
               INNER JOIN (SELECT LOT, FROMLOC, FROMID  
                                FROM  TaskDetail WITH (NOLOCK)  
                                WHERE TaskType ='DRP'   
                                AND   Status NOT IN ('9','X')  
                                AND   Loadkey = @cLoadkey  
                                GROUP BY LOT, FROMLOC, FROMID) TD ON LLI.LOT = TD.LOT AND LLI.LOC = TD.FROMLOC AND LLI.ID = TD.FROMID  
         WHERE LLI.QTYReplen <> 0 OR   
               TD.LOT IS NOT NULL  
                 
      END  
              
      OPEN CUR_QTYREPLEN  
        
      FETCH NEXT FROM CUR_QTYREPLEN INTO @cLOT, @cLOC, @cID, @nQtyReplen, @nQty   
        
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SET @nQtyReplenTask = 0   
           
         IF @cLoadkey = ''  
         BEGIN  
            SET @nQtyReplenTask = 0   
  
            SELECT @nQtyReplenTask = ISNULL(SUM(Qty),0)   
            FROM  TaskDetail WITH (NOLOCK)  
            WHERE TaskType IN ('DRP')   
            AND   Status NOT IN ('9','X')  
            AND   LOT = @cLOT    
            AND   FROMLOC = @cLOC  
            AND   FROMID = @cID   
            AND   DATEDIFF(HOUR, ADDDATE, GETDATE()) < 1     
              
              
            SET @nQtyDPK=0  
            SELECT @nQtyDPK = ISNULL(SUM(PD.Qty),0)   
            FROM PICKDETAIL PD WITH (NOLOCK)         
            WHERE PD.Status = 0 AND CASEID = '' AND PD.LOC LIKE 'PTS%'   
            AND PD.LOT = @cLOT AND PD.ToLoc = @cLOC AND PD.ID = @cID    
         END  
         ELSE  
         BEGIN  
            SET @nQtyReplenTask = 0  
   
            SELECT @nQtyReplenTask = ISNULL(SUM(Qty),0)   
            FROM  TaskDetail WITH (NOLOCK)  
            WHERE TaskType IN ('DRP')   
            AND   Status NOT IN ('9','X')  
            AND   LOT = @cLOT    
            AND   FROMLOC = @cLOC  
            AND   FROMID = @cID   
            AND   LOADKEY = @cLoadkey  
            AND   DATEDIFF(HOUR, ADDDATE, GETDATE()) < 1     
              
              
            SET @nQtyDPK=0  
            SELECT @nQtyDPK = ISNULL(SUM(PD.Qty),0)   
            FROM PICKDETAIL PD WITH (NOLOCK)         
            INNER JOIN ORDERS O WITH (NOLOCK) ON O.Orderkey = Pd.Orderkey AND O.Storerkey = PD.Storerkey   
            WHERE PD.Status = 0 AND CASEID = '' AND PD.LOC LIKE 'PTS%'   
            AND PD.LOT = @cLOT AND PD.ToLoc = @cLOC AND PD.ID = @cID    
            AND O.Loadkey = @cLoadkey  
         END  
        
         SET @nQtyReplenTask = @nQtyReplenTask + @nQtyDPK  
           
         IF @nQtyReplenTask > @nQty   
            SET @nQtyReplenTask = @nQty   
           
         SET @nQtyReplenLog = 0  
        
         IF @nQtyReplen <> (@nQtyReplenTask + @nQtyReplenLog)  
         BEGIN  
--            SELECT @cLOT '@cLOT', @cLOC '@cLOC', @cID '@cID', @nQtyReplen '@nQtyReplen', @nQtyReplenTask '@nQtyReplenTask',   
--                   @nQtyDPK '@nQtyDPK', @nQty '@nQty '     
            BEGIN TRAN -- (ChewKP01)  
                 
            UPDATE LOTxLOCxID SET QtyReplen = (@nQtyReplenTask + @nQtyReplenLog)  
            WHERE  (Qty - QtyAllocated - QtyPicked) >= (@nQtyReplenTask)  
            AND    LOT = @cLOT   
            AND    LOC = @cLOC  
            AND    ID = @cID   
              
            IF @@ERROR <> 0    
            BEGIN    
               ROLLBACK TRAN    
               SET @nErrNo = 63100  
               SET @cErrMsg = 'Error Update LotxLocxID (ispReCalculateQtyReplen)'  
               GOTO RollBackTran    
            END  
            ELSE  
            BEGIN -- (ChewKP01)  
                  COMMIT TRAN  
            END    
        
         END  
                               
         FETCH NEXT FROM CUR_QTYREPLEN INTO @cLOT, @cLOC, @cID, @nQtyReplen, @nQty   
      END  
      CLOSE CUR_QTYREPLEN  
      DEALLOCATE CUR_QTYREPLEN   
        
      GOTO Quit    
    
      RollBackTran:    
--      ROLLBACK TRAN LLI_QtyReplen  -- (ChewKP01)  
    
      Quit:    
--      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
--         COMMIT TRAN LLI_QtyReplen  -- (ChewKP01)  
           
END  

SET QUOTED_IDENTIFIER OFF 

GO