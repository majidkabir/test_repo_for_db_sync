SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispTM_PendingMoveInRecalculate                     */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.4                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 03/08/2010   ChewKP        Created SOS#183050                        */  
/* 08/09/2010   ChewKP        Prevent NULL Record being select to insert*/  
/*                            (ChewKP01)                                */  
/************************************************************************/  
  
CREATE PROC [dbo].[ispTM_PendingMoveInRecalculate]  
AS  
BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
      
    DECLARE @c_Storerkey         NVARCHAR(15)  
           ,@c_TaskType          NVARCHAR(10)  
           ,@c_Loc               NVARCHAR(10)  
           ,@c_ID                NVARCHAR(18)  
           ,@n_PendingQty        INT  
           ,@n_Qty               INT  
           ,@c_LocationCategory  NVARCHAR(10)  
           ,@n_TDQty             INT  
           ,@c_Lot               NVARCHAR(10)  
           ,@c_Status            NVARCHAR(10)  
           ,@c_TaskDetailKey     NVARCHAR(10)  
           ,@n_CursorDeclare     int  
           ,@c_FromLoc           NVARCHAR(10)  
           ,@c_SKU               NVARCHAR(20)
      
    IF OBJECT_ID('tempdb..#LLI_Pending') IS NOT NULL  
        DROP TABLE #LLI_Pending  
      
    CREATE TABLE #LLI_Pending  
    (  
       Storerkey          NVARCHAR(15)  
       ,LOT               NVARCHAR(10)  
       ,LOC               NVARCHAR(10)  
       ,ID                NVARCHAR(18)  
       ,PendingMoveIn     INT  
       ,TaskType          NVARCHAR(10)  
       ,LocationCategory  NVARCHAR(10)  
    )  
      
    DELETE   
    FROM   #LLI_Pending  
      
      
    DECLARE curPending  CURSOR LOCAL FAST_FORWARD READ_ONLY   
    FOR  
        SELECT TD.Storerkey  
              ,TD.TaskType  
              ,TD.ToLoc  
              ,TD.ToID  
              ,TD.Qty  
              ,LOC.LocationCategory  
              ,TD.Status  
              ,TD.TaskDetailKey  
              ,TD.FromLoc    
        FROM   TaskDetail TD WITH (NOLOCK)  
               LEFT OUTER JOIN LOC LOC WITH (NOLOCK)  
                    ON  TD.ToLOC = LOC.LOC  
        WHERE  TD.Status NOT IN ('9' ,'Q')  
        AND    (  
                   TD.TaskType IN ('PA')  
               OR  (  
                       TD.Tasktype='PK'  
                   AND LOC.LocationCategory IN ('PnD_Ctr' ,'PnD_Out')  
                   )  
               )  
        ORDER BY  
               TD.TaskType  
      
    OPEN curPending  
    FETCH NEXT FROM curPending INTO @c_Storerkey, @c_TaskType, @c_Loc, @c_ID, @n_TDQty,   
                                    @c_LocationCategory, @c_Status, @c_TaskDetailKey  
                                    ,@c_FromLoc                          
    WHILE @@FETCH_STATUS<>-1  
    BEGIN  
        SET @n_CursorDeclare = 0   
        IF @c_TaskType='PA' AND @c_LocationCategory='VNA'  
        BEGIN  
            -- Get PendingMoveIn  
            IF @c_Status<>'W'  
            BEGIN  
                DECLARE CUR_LOTxLOCxID_PendingQty CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
                SELECT Qty  
                      ,Lot  
                FROM   LOTxLOCxID WITH (NOLOCK)  
                WHERE  ID = @c_ID  
                AND    Storerkey = @c_Storerkey  
                AND    Loc = @c_Loc  
                AND    Qty>0  
                SET @n_CursorDeclare = 1  
            END  
            IF @c_Status='W'  
            BEGIN  
                DECLARE CUR_LOTxLOCxID_PendingQty CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                SELECT LLI.Qty  
                      ,LLI.Lot  
                FROM   LOTxLOCxID LLI WITH (NOLOCK)   
                JOIN   TaskDetail TD  WITH (NOLOCK) ON LLI.LOC = TD.FromLOC AND LLI.ID = TD.FromID   
                WHERE  TD.RefTaskKey = @c_TaskDetailKey   
                AND    LLI.Storerkey = @c_Storerkey  
                AND    LLI.Loc = @c_Loc   
                AND    LLI.Qty>0  
                AND    LLI.ID = @c_ID  
  
                SET @n_CursorDeclare = 1   
            END   
        END -- END               
        IF @c_TaskType='PK'  
        BEGIN  
           DECLARE CUR_LOTxLOCxID_PendingQty CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
           SELECT SUM(Qty), LOT    
           FROM   PICKDETAIL WITH (NOLOCK)  
           WHERE  TaskDetailKey = @c_TaskDetailKey   
           AND    StorerKey = @c_StorerKey   
           AND    LOC = @c_FromLOC   
           AND    Status <> '9'   
           AND    ID = @c_ID   
           GROUP BY LOT   
  
           SET @n_CursorDeclare = 1  
        END         
  
        IF @n_CursorDeclare = 1  
        BEGIN  
         OPEN CUR_LOTxLOCxID_PendingQty  
         FETCH NEXT FROM CUR_LOTxLOCxID_PendingQty INTO @n_PendingQty, @c_LOT   
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            -- Insert into TempTable  
            IF NOT EXISTS (  
                   SELECT 1  
                   FROM   #LLI_Pending WITH (NOLOCK)  
                   WHERE  Lot = @c_Lot  
                   AND    Loc = @c_Loc  
                   AND    ID = @c_ID  
                   AND    Storerkey = @c_Storerkey  
               )  
            BEGIN  
                INSERT INTO #LLI_Pending  
                  (  
                    Storerkey  
                   ,Lot  
                   ,Loc  
                   ,ID  
                   ,PendingMoveIn  
                   ,TaskType  
                   ,LocationCategory  
                  )  
                VALUES  
                  (  
                    @c_Storerkey  
                   ,@c_Lot  
                   ,@c_Loc  
                   ,@c_ID  
                   ,@n_PendingQty  
                   ,@c_TaskType  
                   ,@c_LocationCategory  
                  )  
            END  
            ELSE  
            BEGIN  
                UPDATE #LLI_Pending  
                SET    PendingMoveIn = PendingMoveIn+@n_PendingQty  
                WHERE  Lot = @c_Lot  
                AND    Loc = @c_Loc  
                AND    ID = @c_ID  
                AND    Storerkey = @c_Storerkey  
            END  
            FETCH NEXT FROM CUR_LOTxLOCxID_PendingQty INTO @n_PendingQty, @c_LOT  
         END -- WHILE   
         CLOSE CUR_LOTxLOCxID_PendingQty   
         DEALLOCATE CUR_LOTxLOCxID_PendingQty   
      END -- @n_CursorDeclare = 1  
      --SELECT @c_TaskDetailKey '@c_TaskDetailKey', @c_Loc '@c_Loc', @c_ID '@c_ID', @n_PendingQty '@n_PendingQty'  
          
        FETCH NEXT FROM curPending INTO @c_Storerkey, @c_TaskType, @c_Loc, @c_ID, @n_TDQty,   
                                        @c_LocationCategory, @c_Status, @c_TaskDetailKey  
                                        ,@c_FromLoc  
    END  
      
    CLOSE curPending  
    DEALLOCATE curPending   
      
    -- Compare with LOTxLOCxID  
  
    SELECT LLI.LOT, LLI.LOC, LLI.ID, ISNULL(LLI_TEMP.PendingMoveIn,0) as PendingMoveIn   
    FROM LOTxLOCxID LLI WITH (NOLOCK)  
    LEFT OUTER JOIN #LLI_Pending LLI_TEMP ON (LLI.lot = LLI_TEMP.lot  AND LLI.Loc = LLI_TEMP.Loc  
            AND LLI.ID = LLI_TEMP.ID AND LLI.Storerkey = LLI_TEMP.Storerkey)  
    WHERE ISNULL(LLI.PendingMoveIn,0) <> ISNULL(LLI_TEMP.PendingMoveIn,0)  
    UNION ALL  
    SELECT LLI_TEMP.LOT, LLI_TEMP.LOC, LLI_TEMP.ID, ISNULL(LLI_TEMP.PendingMoveIn,0) as PendingMoveIn   
    FROM #LLI_Pending LLI_TEMP   
    LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK)   
                                 ON (LLI.lot = LLI_TEMP.lot  AND LLI.Loc = LLI_TEMP.Loc  
                                 AND LLI.ID = LLI_TEMP.ID AND LLI.Storerkey = LLI_TEMP.Storerkey)  
    WHERE LLI.LOT IS NULL   
  
  
    /* UPDATE PENDINGMOVEIN (START) */   
    /*  
    UPDATE LOTxLOCxID WITH (ROWLOCK)  
    SET    PendingMoveIn = 0  
    WHERE  PendingMoveIn<>0  
    */  
  
    -- Loop Temp Table to Update PendingMoveIn Qty  
    SET @c_Storerkey = ''  
    SET @c_Lot = ''  
    SET @c_Loc = ''  
    SET @c_ID = ''  
    SET @n_PendingQty = 0  

        
      
    DECLARE curPendingLLI  CURSOR LOCAL FAST_FORWARD READ_ONLY   
    FOR  
        SELECT LLI.StorerKey  
              ,LLI  .LOT  
              ,LLI  .LOC  
              ,LLI  .ID  
              ,ISNULL(LLI_TEMP.PendingMoveIn ,0)  
        FROM   LOTxLOCxID LLI WITH (NOLOCK)  
               FULL OUTER JOIN #LLI_Pending LLI_TEMP  
                    ON  (  
                            LLI.lot=LLI_TEMP.lot  
                        AND LLI.Loc=LLI_TEMP.Loc  
                        AND LLI.ID=LLI_TEMP.ID  
                        AND LLI.Storerkey=LLI_TEMP.Storerkey  
                        )  
        WHERE  ISNULL(LLI.PendingMoveIn ,0)<>ISNULL(LLI_TEMP.PendingMoveIn ,0)   
        UNION ALL  
        SELECT LLI_TEMP.StorerKey, LLI_TEMP.LOT, LLI_TEMP.LOC,   
               LLI_TEMP.ID, ISNULL(LLI_TEMP.PendingMoveIn,0) as PendingMoveIn   
        FROM #LLI_Pending LLI_TEMP   
        LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK)   
                                    ON (LLI.lot = LLI_TEMP.lot  AND LLI.Loc = LLI_TEMP.Loc  
                                    AND LLI.ID = LLI_TEMP.ID AND LLI.Storerkey = LLI_TEMP.Storerkey)  
        WHERE LLI.LOT IS NULL   
      
    OPEN curPendingLLI  
    FETCH NEXT FROM curPendingLLI INTO @c_Storerkey, @c_Lot, @c_Loc, @c_ID, @n_PendingQty                             
    WHILE @@FETCH_STATUS<>-1  
    BEGIN  
  
        IF ISNULL(@c_Lot , '') <> '' -- (ChewKP01)  
        BEGIN  
           IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOT = @c_Lot  
                         AND    LOC = @c_Loc  
                         AND    ID = @c_ID)  
           BEGIN  
              SELECT @c_SKU = SKU FROM Lot WITH (NOLOCK)
              WHERE LOT = @c_LOT
              AND Storerkey = @c_Storerkey           
 
--              INSERT INTO TraceInfo ( TraceName, TimeIn, col1, col2, col3, col4, col5  )   
--              VALUES (  'ispTM_PendingMoveInRecalculate' , GETDATE(), @c_LOT, @c_LOC, @c_ID, @c_SKU, @n_PendingQty )  
  
              INSERT INTO LOTxLOCxID (LOT, LOC, ID, Storerkey, SKU, Qty, PendingMoveIn)   
              VALUES( @c_LOT, @c_LOC, @c_ID, @c_Storerkey, @c_SKU, 0, @n_PendingQty )  
           END  
           ELSE  
           BEGIN   
              UPDATE LOTxLOCxID WITH (ROWLOCK)  
              SET    PendingMoveIn = @n_PendingQty  
              WHERE  Storerkey = @c_Storerkey  
              AND    LOT = @c_Lot  
              AND    LOC = @c_Loc  
              AND    ID = @c_ID  
           END  
        END  
          
        FETCH NEXT FROM curPendingLLI INTO @c_Storerkey, @c_Lot, @c_Loc, @c_ID, @n_PendingQty  
    END  
      
    CLOSE curPendingLLI  
    DEALLOCATE curPendingLLI   
      
    /* UPDATE PENDINGMOVEIN (END) */   
  
    DROP TABLE #LLI_Pending  
END

GO