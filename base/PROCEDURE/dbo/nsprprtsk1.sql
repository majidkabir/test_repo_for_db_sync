SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: nspRPRTSK1                                         */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: Loadplan Task Release Strategy for IDSUK Diana Project      */      
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* Version: 5.5                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author   Ver  Purposes                                  */      
/* 24-Jun-2010  Shong    1.0  Creation                                  */  
/* 17-Aug-2010  ChewKP   1.1  Do not create DRP task where there is     */
/*                            un-processed task in TaskDetail from the  */
/*                            same zone (ChewKP01)                      */
/* 03-Oct-2010  Shong    1.2  Insert Replen Qty into SystemQty (Shong01)*/
/************************************************************************/      
CREATE PROC [dbo].[nspRPRTSK1]     
   @c_Facility NVARCHAR(10)='',
   @c_zone02 NVARCHAR(10)='',
   @c_zone03 NVARCHAR(10)='',
   @c_zone04 NVARCHAR(10)='',
   @c_zone05 NVARCHAR(10)='',
   @c_zone06 NVARCHAR(10)='',
   @c_zone07 NVARCHAR(10)='',
   @c_zone08 NVARCHAR(10)='',
   @c_zone09 NVARCHAR(10)='',
   @c_zone10 NVARCHAR(10)='',
   @c_zone11 NVARCHAR(10)='',
   @c_zone12 NVARCHAR(10)='',
   @c_Storerkey NVARCHAR(15)='',
   @n_err       INT OUTPUT,    
   @c_ErrMsg    NVARCHAR(250) OUTPUT    
AS      
BEGIN  
    SET NOCOUNT ON       
    SET ANSI_NULLS OFF       
    SET QUOTED_IDENTIFIER OFF       
    SET CONCAT_NULL_YIELDS_NULL OFF      
      
    DECLARE @n_continue       INT  
           ,@c_TaskDetailKey  NVARCHAR(10)  
           ,@b_Success        INT  
           ,@c_RefTaskKey     NVARCHAR(10)    
      
    DECLARE @n_cnt            INT     
      
    DECLARE @c_SKU            NVARCHAR(20)  
           ,@c_ID             NVARCHAR(18)  
           ,@c_FromLoc        NVARCHAR(10)  
           ,@c_ToLoc          NVARCHAR(10)  
           ,@c_PnDLocation    NVARCHAR(10)  
           ,@n_InWaitingList  INT  
           ,@n_SKUCnt         INT  
           ,@n_PickQty        INT  
           ,@c_Status         NVARCHAR(10)  
           ,@n_StartTranCnt   INT    
           ,@c_Priority       NVARCHAR(10)  
           ,@c_OrderType      NVARCHAR(10)  
           ,@c_OrderKey       NVARCHAR(10)   
           ,@c_ConsigneeKey   NVARCHAR(15)   
           ,@c_LOT            NVARCHAR(10)   
           ,@c_AreaKey        NVARCHAR(10)  
           ,@n_ReplenQty      INT    
           ,@n_RecCount       INT   
           ,@n_TotalPick      INT 
           ,@c_ReplenishmentKey   NVARCHAR(20)   
           ,@c_Putawayzone        NVARCHAR(10)    
           ,@c_ReplenishmentGroup NVARCHAR(10)
      
    SELECT @n_continue = 1  
          ,@n_err = 0  
          ,@c_ErrMsg = ''    
      
    SET @n_StartTranCnt = @@TRANCOUNT   
      
    BEGIN TRAN    
      
    IF @n_continue=1  
       OR @n_continue=2  
    BEGIN  
        SET @n_RecCount = 0
        IF @c_zone02 = 'ALL' 
        BEGIN
           SELECT @n_RecCount = COUNT(*)
           FROM REPLENISHMENT r WITH (NOLOCK) 
           JOIN LOC l WITH (NOLOCK) ON r.FromLoc = l.Loc   
           WHERE l.Facility = @c_Facility 
           AND   r.Confirmed = 'N' 
           AND   r.Storerkey = @c_Storerkey 
        END
        ELSE
        BEGIN
           SELECT @n_RecCount = COUNT(*)
           FROM REPLENISHMENT r WITH (NOLOCK) 
           JOIN LOC l WITH (NOLOCK) ON r.ToLoc = l.Loc   
           WHERE l.Facility = @c_Facility 
           AND   r.Confirmed = 'N' 
           AND   r.Storerkey = @c_Storerkey
           AND   l.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, 
                                   @c_zone06, @c_zone07, @c_zone08, @c_zone09, 
                                   @c_zone10, @c_zone11, @c_zone12)           
        END
                      
        IF @n_RecCount = 0
        BEGIN  
            SELECT @n_continue = 3      
            SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)  
                  ,@n_err = 81002 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                   ': No task to release'+' ( '+' SQLSvr MESSAGE='+  
                   @c_ErrMsg+' ) '  
        END  
    END
      
    IF @n_continue=1  
       OR @n_continue=2  
    BEGIN  
       -------------------------------------------------          
       -- Scan Pick Location For Replenishment Task   
       -- Generate Force Replenishment Task   
       -------------------------------------------------  
       IF @c_zone02 = 'ALL' 
       BEGIN
          DECLARE Cursor_Replenishment CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
          SELECT r.StorerKey, r.SKU, r.LOT, r.FROMLOC, r.ID, r.ToLOC, r.Qty, r.ReplenishmentKey, r.Priority
               , r.ReplenishmentGroup            
          FROM   REPLENISHMENT r WITH (NOLOCK)
          JOIN LOC l WITH (NOLOCK) ON r.FromLoc = l.Loc   
          WHERE l.Facility = @c_Facility 
          AND   r.Confirmed = 'N' 
          AND   r.Storerkey = @c_Storerkey
       END
       ELSE
       BEGIN          
          DECLARE Cursor_Replenishment CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
          SELECT r.StorerKey, r.SKU, r.LOT, r.FROMLOC, r.ID, r.ToLOC, r.Qty, r.ReplenishmentKey, r.Priority
               , r.ReplenishmentGroup
          FROM   REPLENISHMENT r WITH (NOLOCK)
          JOIN LOC l WITH (NOLOCK) ON r.ToLoc = l.Loc   
          WHERE l.Facility = @c_Facility 
          AND   r.Confirmed = 'N' 
          AND   r.Storerkey = @c_Storerkey
          AND   l.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, 
                                  @c_zone06, @c_zone07, @c_zone08, @c_zone09, 
                                  @c_zone10, @c_zone11, @c_zone12)                        
       END
           
       OPEN Cursor_Replenishment   
  
       FETCH NEXT FROM Cursor_Replenishment INTO @c_StorerKey, @c_SKU, @c_LOT, @c_FromLoc, 
                                                 @c_ID, @c_ToLOC, @n_ReplenQty, @c_ReplenishmentKey, @c_Priority, 
                                                 @c_ReplenishmentGroup     
       WHILE @@FETCH_STATUS <> -1  
       BEGIN
          -- Should not allow to release this task if the ToLoc still have outstanding task   
          IF NOT EXISTS ( SELECT 1 FROM TaskDetail TD WITH (NOLOCK) 
                           WHERE TD.Status IN ( '0','3') 
                           AND TD.TaskType = 'DRP' 
                           AND TD.ToLoc = @c_ToLoc 
                           AND TD.Storerkey = @c_Storerkey  
                           AND TD.Sku       = @c_SKU  
                           AND TD.Message03 <> @c_ReplenishmentGroup     
                        )
         BEGIN 
             -- Insert Replen Task here     
             EXECUTE nspg_getkey   
             'TaskDetailKey',   
             10,   
             @c_TaskDetailKey OUTPUT,   
             @b_Success OUTPUT,   
             @n_err OUTPUT,   
             @c_ErrMsg OUTPUT      
             IF NOT @b_Success=1  
             BEGIN  
                 SELECT @n_continue = 3      
                 SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)  
                       ,@n_err = 81005 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                 SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                        ': Unable to Get TaskDetailKey (nspRPRTSK1)'   
                       +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg   
                       +' ) '  
             END  
             ELSE  
             BEGIN  
                 INSERT TASKDETAIL  
                   (  
                     TaskDetailKey, TaskType, Storerkey, Sku, Lot, UOM,   
                     UOMQty, Qty, FromLoc, FromID, ToLoc, ToId, SourceType,   
                     SourceKey, Caseid, Priority, SourcePriority, OrderKey,   
                     OrderLineNumber, PickDetailKey, PickMethod, STATUS,   
                     LoadKey, AreaKey, Message03, SystemQty   
                      )  
                 VALUES  
                   (  
                     @c_TaskDetailKey, 'DRP'  
                     , @c_Storerkey  
                     , @c_SKU  
                     , @c_LOT -- Lot,  
                     , ''     -- UOM,  
                     , 0      -- UOMQty,  
                     , @n_ReplenQty  
                     , @c_FromLoc -- FromLoc   
                     , @c_ID      -- FromID  
                     , @c_ToLoc   -- ToLoc   
                     , ''         -- ToID   
                     , 'nspRPRTSK1'  -- SourceType
                     , @c_ReplenishmentKey -- SourceKey
                     , ''  -- Caseid  
                     , '5' -- Priority  
                     , '9' -- SourcePriority
                     , ''  -- Orderkey,  
                     , ''  -- OrderLineNumber  
                     , ''  -- PickDetailKey  
                     , 'CASE' -- PickMethod   
                     , '0' -- Status  
                     , ''  
                     , ''  -- @c_AreaKey   (ChewKP01)
                     , @c_ReplenishmentGroup 
                     , @n_ReplenQty --(Shong01)
                   )    
                         
                 SELECT @n_err = @@ERROR      
                 IF @n_err<>0  
                 BEGIN  
                     SELECT @n_continue = 3      
                     SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)  
                           ,@n_err = 81006 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                            ': Insert Into TaskDetail Failed (nspRPRTSK1)'   
                           +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg   
                           +' ) '  
                       
                     GOTO QUIT_SP  
                 END

                UPDATE LOTxLOCxID  
                SET QtyReplen = QtyReplen + @n_ReplenQty   
                WHERE LOT = @c_Lot   
                AND   LOC = @c_FromLoc  
                AND   ID  = @c_ID  
                   
                UPDATE REPLENISHMENT WITH (ROWLOCK) 
                SET Confirmed = 'Y', 
                    ArchiveCop=NULL, 
                    RefNo = @c_TaskDetailKey 
                WHERE ReplenishmentKey = @c_ReplenishmentKey 
                SELECT @n_err = @@ERROR      
                IF @n_err<>0  
                BEGIN  
                   SELECT @n_continue = 3      
                   SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)  
                         ,@n_err = 81006 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                   SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                          ': Update Replenishment Failed (nspRPRTSK1)'   
                         +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg   
                         +' ) '  
                    
                  GOTO QUIT_SP  
               END
            END -- If GetKey Succeed 
          END  -- If No Pending Replenishment Task for same location, then create task         
                               
          FETCH NEXT FROM Cursor_Replenishment INTO @c_StorerKey, @c_SKU, @c_LOT, @c_FromLoc, 
                           @c_ID, @c_ToLOC, @n_ReplenQty, @c_ReplenishmentKey, @c_Priority, 
                           @c_ReplenishmentGroup        
       END  
       CLOSE Cursor_Replenishment  
       DEALLOCATE Cursor_Replenishment  
                              
    END   
  
    Quit_SP:  
      
    IF @n_continue=3  
    BEGIN  
        IF @@TRANCOUNT>@n_StartTranCnt  
            ROLLBACK TRAN   
          
        EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'nspRPRTSK1'   
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
    END  
    ELSE  
    BEGIN  
       WHILE @@TRANCOUNT>@n_StartTranCnt   
          COMMIT TRAN  
 
    END  
END   

GO