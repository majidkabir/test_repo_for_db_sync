SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Stored Procedure: nspRPRTSK2                                         */          
/* Creation Date:                                                       */          
/* Copyright: IDS                                                       */          
/* Written by:                                                          */          
/*                                                                      */          
/* Purpose: Standard Replenishment Task Release Strategy for SOS#224377 */          
/*                                                                      */          
/* Called By:                                                           */          
/*                                                                      */          
/* Version: 5.5                                                         */          
/*                                                                      */          
/* Data Modifications:                                                  */          
/*                                                                      */          
/* Updates:                                                             */          
/* Date         Author   Ver  Purposes                                  */          
/************************************************************************/          
CREATE PROC [dbo].[nspRPRTSK2]         
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
           ,@c_TaskType           NVARCHAR(10)     
           ,@n_Pallet         INT    
           ,@c_PickMethod     NVARCHAR(10)    
          
    SELECT @n_continue = 1      
          ,@n_err = 0      
          ,@c_ErrMsg = ''        
          
    SET @n_StartTranCnt = @@TRANCOUNT       
          
    BEGIN TRAN        
          
    IF @n_continue=1 OR @n_continue=2      
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
           AND   ISNULL(r.Loadkey,'') = ''    
           AND   ISNULL(r.Wavekey,'') = ''    
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
           AND   ISNULL(r.Loadkey,'') = ''    
           AND   ISNULL(r.Wavekey,'') = ''    
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
          
    IF @n_continue=1 OR @n_continue=2      
    BEGIN      
       -------------------------------------------------              
       -- Scan Pick Location For Replenishment Task       
       -- Generate Force Replenishment Task       
       -------------------------------------------------      
       IF @c_zone02 = 'ALL'     
       BEGIN    
          DECLARE Cur_ReplenishmentGroup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR       
          SELECT r.StorerKey, r.SKU, r.FROMLOC, r.ID, r.ToLOC, p.Pallet, SUM(r.Qty)               
          FROM   REPLENISHMENT r WITH (NOLOCK)     
          JOIN LOC l WITH (NOLOCK) ON r.FromLoc = l.Loc       
          JOIN SKU s WITH (NOLOCK) ON r.Storerkey = s.Storerkey AND r.Sku = s.Sku     
          JOIN PACK p WITH (NOLOCK) ON s.Packkey = p.Packkey    
          WHERE l.Facility = @c_Facility     
          AND   r.Confirmed = 'N'     
          AND   r.Storerkey = @c_Storerkey    
          AND   ISNULL(r.Loadkey,'') = ''    
          AND   ISNULL(r.Wavekey,'') = ''     
          GROUP BY r.StorerKey, r.SKU, r.FROMLOC, r.ID, r.ToLOC, p.Pallet    
       END    
       ELSE    
       BEGIN              
          DECLARE Cur_ReplenishmentGroup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR       
          SELECT r.StorerKey, r.SKU, r.FROMLOC, r.ID, r.ToLOC, p.Pallet, SUM(r.Qty)       
          FROM   REPLENISHMENT r WITH (NOLOCK)    
          JOIN LOC l WITH (NOLOCK) ON r.ToLoc = l.Loc       
          JOIN SKU s WITH (NOLOCK) ON r.Storerkey = s.Storerkey AND r.Sku = s.Sku    
          JOIN PACK p WITH (NOLOCK) ON s.Packkey = p.Packkey    
          WHERE l.Facility = @c_Facility     
          AND   r.Confirmed = 'N'     
          AND   r.Storerkey = @c_Storerkey    
          AND   l.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05,     
                                  @c_zone06, @c_zone07, @c_zone08, @c_zone09,     
                                  @c_zone10, @c_zone11, @c_zone12)                            
          AND   ISNULL(r.Loadkey,'') = ''    
          AND   ISNULL(r.Wavekey,'') = ''    
          GROUP BY r.StorerKey, r.SKU, r.FROMLOC, r.ID, r.ToLOC, p.Pallet               
       END    
               
       OPEN Cur_ReplenishmentGroup       
      
       FETCH NEXT FROM Cur_ReplenishmentGroup INTO @c_StorerKey, @c_SKU, @c_FromLoc,     
                                                 @c_ID, @c_ToLOC, @n_Pallet, @n_ReplenQty      
       WHILE @@FETCH_STATUS <> -1      
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
                     ': Unable to Get TaskDetailKey (nspRPRTSK2)'       
                    +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg   +' ) '      
              GOTO QUIT_SP    
          END      
          ELSE      
          BEGIN    
             SET @c_TaskType = 'RP'    
               
             SELECT @c_TaskType = ISNULL(sValue, 'RP')    
             FROM StorerConfig sc WITH (NOLOCK)    
             WHERE sc.StorerKey = @c_Storerkey     
             AND   sc.ConfigKey = 'ReplenReleaseTaskType'    
               
             SET @c_AreaKey = ''    
             SELECT TOP 1     
                    @c_AreaKey = ISNULL(ad.AreaKey,'')      
             FROM   LOC WITH (NOLOCK)    
             LEFT OUTER JOIN AreaDetail ad (NOLOCK) ON ad.PutawayZone = LOC.PutawayZone    
             WHERE LOC.Loc = @c_FromLoc     
                   
             IF @n_ReplenQty >= @n_Pallet AND @n_Pallet > 0    
                SET @c_PickMethod = 'FP'    
             ELSE     
                SET @c_PickMethod = 'PP'                       
                                               
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
                    @c_TaskDetailKey    
                  , @c_TaskType      
                  , @c_Storerkey      
                  , @c_SKU      
                  , ''     -- Lot,      
                  , ''     -- UOM,      
                  , 0      -- UOMQty,      
                  , @n_ReplenQty      
                  , @c_FromLoc -- FromLoc       
                  , @c_ID      -- FromID      
                  , @c_ToLoc   -- ToLoc       
                  , ''         -- ToID       
                  , 'nspRPRTSK2'  -- SourceType    
                  , ''  -- SourceKey    
                  , ''  -- Caseid      
                  , '5' -- Priority      
                  , '9' -- SourcePriority    
                  , ''  -- Orderkey,      
                  , ''  -- OrderLineNumber      
                  , ''  -- PickDetailKey      
                  , @c_PickMethod  -- PickMethod       
                  , '0' -- Status      
                  , ''      
                  , @c_AreaKey       
                  , ''  -- Message03    
                  , @n_ReplenQty --(Shong01)    
                )        
                          
             SELECT @n_err = @@ERROR          
             IF @n_err<>0      
             BEGIN      
                SELECT @n_continue = 3          
                SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)      
                      ,@n_err = 81006 -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
                SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+      
                        ': Insert Into TaskDetail Failed (nspRPRTSK2)'       
                       +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg       
                       +' ) '      
                       
                GOTO QUIT_SP      
             END    
             DECLARE Cur_ReplenishmentDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
             SELECT r.ReplenishmentKey     
             FROM   REPLENISHMENT r WITH (NOLOCK)    
             WHERE r.Storerkey = @c_Storerkey     
             AND   r.Sku = @c_SKU     
             AND   r.FromLoc = @c_FromLoc    
             AND   r.ToLoc   = @c_ToLoc     
             AND   r.id      = @c_ID      
             AND   r.Confirmed = 'N'     
     
             OPEN Cur_ReplenishmentDetail     
                 
             FETCH NEXT FROM Cur_ReplenishmentDetail INTO @c_ReplenishmentKey      
             WHILE @@FETCH_STATUS <> -1             
             BEGIN     
--                UPDATE LOTxLOCxID      
--                SET QtyReplen = QtyReplen + @n_ReplenQty       
--                WHERE LOT = @c_Lot       
--                AND   LOC = @c_FromLoc      
--                AND   ID  = @c_ID      
                       
                UPDATE REPLENISHMENT WITH (ROWLOCK)     
                SET Confirmed = 'S',     
                    ArchiveCop=NULL,     
                    RefNo = @c_TaskDetailKey,     
                    EditDate = GETDATE(),     
                    EditWho  = SUSER_SNAME()     
                WHERE ReplenishmentKey = @c_ReplenishmentKey     
                    
                SELECT @n_err = @@ERROR          
                IF @n_err<>0      
                BEGIN      
                   SELECT @n_continue = 3          
                   SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)      
                         ,@n_err = 81006 -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
                   SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+      
                          ': Update Replenishment Failed (nspRPRTSK2)'       
                         +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg       
                         +' ) '      
                        
                   GOTO QUIT_SP      
                END    
                FETCH NEXT FROM Cur_ReplenishmentDetail INTO @c_ReplenishmentKey     
            END -- If GetKey Succeed     
            CLOSE Cur_ReplenishmentDetail    
            DEALLOCATE Cur_ReplenishmentDetail                  
          END -- Gen TaskDetailKey Successful    
          FETCH NEXT FROM Cur_ReplenishmentGroup INTO @c_StorerKey, @c_SKU, @c_FromLoc,     
                                                    @c_ID, @c_ToLOC, @n_Pallet, @n_ReplenQty               
       END -- While Cur_ReplenishmentGroup loop    
       CLOSE Cur_ReplenishmentGroup      
       DEALLOCATE Cur_ReplenishmentGroup      
    END -- IF @n_continue=1 OR @n_continue=2        
      
    Quit_SP:      
          
    IF @n_continue=3      
    BEGIN      
        IF @@TRANCOUNT>@n_StartTranCnt      
            ROLLBACK TRAN       
              
        EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'nspRPRTSK2'       
        RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012       
    END      
    ELSE      
    BEGIN      
       WHILE @@TRANCOUNT>@n_StartTranCnt       
          COMMIT TRAN      
     
    END      
END       

GO