SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLWAV13                                          */  
/* Creation Date: 19-Dec-2017                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-3649 - KR Nike ECOM Release Wave Replenishment           */
/*          For sku.putawayzone <> ''                                    */
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.1                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 01-04-2020  Wan01    1.1   Sync Exceed & SCE                          */ 
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV13]      
  @c_wavekey      NVARCHAR(10)  
 ,@b_Success      int        OUTPUT  
 ,@n_err          int        OUTPUT  
 ,@c_errmsg       NVARCHAR(250)  OUTPUT  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @n_continue int,    
            @n_starttcnt int,         -- Holds the current transaction count  
            @n_debug int,
            @n_cnt int
            
    SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT  @n_debug = 0

    DECLARE  @c_Storerkey NVARCHAR(15)
            ,@c_Facility NVARCHAR(5)
            ,@c_Sku NVARCHAR(20)
            ,@c_Lot NVARCHAR(10)
            ,@c_FromLoc NVARCHAR(10)
            ,@c_ID NVARCHAR(18)
            ,@c_ToID NVARCHAR(18)
            ,@n_Qty INT
            ,@c_SourceType NVARCHAR(30)
            ,@c_TaskType NVARCHAR(10)
            ,@c_UOM NVARCHAR(10)
            ,@n_UOMQty INT
            ,@c_PickMethod NVARCHAR(10)            
            ,@c_Priority NVARCHAR(10)
            ,@c_Toloc NVARCHAR(10)
            ,@c_Taskdetailkey NVARCHAR(10)  
            ,@c_LinkTaskToPick_SQL NVARCHAR(4000)
            ,@c_PickDetailKey NVARCHAR(10)
            ,@c_PickslipNo NVARCHAR(10)            
                        
    SET @c_SourceType = 'ispRLWAV13'    
    SET @c_Priority = '9'
    SET @c_TaskType = 'RPF'
    SET @c_PickMethod = ''

    -----Wave Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype IN(@c_TaskType)
                      WHERE WD.Wavekey = @c_Wavekey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV13)'       
       END      
    END
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype = @c_SourceType
                   AND TD.Tasktype IN(@c_TaskType)
                   AND TD.Status <> 'X')
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83010    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV13)'       
        END                 
    END
    
    -----Generate Pickslip No------
    /*
    IF @n_continue = 1 or @n_continue = 2 
    BEGIN
       EXEC isp_CreatePickSlip
            @c_Wavekey = @c_Wavekey
           ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
           ,@b_Success = @b_Success OUTPUT
           ,@n_Err = @n_err OUTPUT 
           ,@c_ErrMsg = @c_errmsg OUTPUT        
       
       IF @b_Success = 0
          SELECT @n_continue = 3    
    END
    */
    
    --Initialize Pickdetail work in progress staging table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)
                 JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
                 WHERE O.Userdefine09 = @c_Wavekey
                 AND PD.WIP_RefNo = @c_SourceType)
       BEGIN
           DELETE PickDetail_WIP 
           FROM PickDetail_WIP (NOLOCK)
           JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey             
          WHERE ORDERS.Userdefine09 = @c_Wavekey 
          AND PickDetail_WIP.WIP_RefNo = @c_SourceType
       END 
       
       INSERT INTO PickDetail_WIP 
       (
         PickDetailKey,      CaseID,             PickHeaderKey,
         OrderKey,           OrderLineNumber, Lot,
         Storerkey,          Sku,                AltSku,     UOM,
         UOMQty,              Qty,               QtyMoved,   [Status],
         DropID,              Loc,             ID,        PackKey,
         UpdateSource,       CartonGroup,     CartonType,
         ToLoc,               DoReplenish,     ReplenishZone,
         DoCartonize,        PickMethod,      WaveKey,
         EffectiveDate,      AddDate,         AddWho,
         EditDate,           EditWho,         TrafficCop,
         ArchiveCop,         OptimizeCop,     ShipFlag,
         PickSlipNo,         TaskDetailKey,   TaskManagerReasonKey,
         Notes,               MoveRefKey,        WIP_RefNo 
       )
       SELECT PD.PickDetailKey,  CaseID,                    PD.PickHeaderKey, 
         PD.OrderKey,                PD.OrderLineNumber,  PD.Lot,
         PD.Storerkey,               PD.Sku,             PD.AltSku,        PD.UOM,
         PD.UOMQty,                  PD.Qty,             PD.QtyMoved,      PD.[Status],
         PD.DropID,                  PD.Loc,             PD.ID,             PD.PackKey,
         PD.UpdateSource,            PD.CartonGroup,      PD.CartonType,
         PD.ToLoc,                   PD.DoReplenish,      PD.ReplenishZone,
         PD.DoCartonize,             PD.PickMethod,       WD.Wavekey,
         PD.EffectiveDate,           PD.AddDate,           PD.AddWho,
         PD.EditDate,                PD.EditWho,           PD.TrafficCop,
         PD.ArchiveCop,              PD.OptimizeCop,      PD.ShipFlag,
         PD.PickSlipNo,              PD.TaskDetailKey,    PD.TaskManagerReasonKey,
         PD.Notes,                   PD.MoveRefKey,            @c_SourceType 
       FROM WAVEDETAIL WD (NOLOCK) 
       JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey
       WHERE WD.Wavekey = @c_Wavekey
       
       SET @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail_WIP Table. (ispRLWAV13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END      
    END

    --Remove taskdetailkey 
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       UPDATE PICKDETAIL_WIP WITH (ROWLOCK) 
       SET PICKDETAIL_WIP.TaskdetailKey = '',
           PICKDETAIL_WIP.TrafficCop = NULL
       FROM WAVEDETAIL (NOLOCK)  
       JOIN PICKDETAIL_WIP ON WAVEDETAIL.Orderkey = PICKDETAIL_WIP.Orderkey
       WHERE WAVEDETAIL.Wavekey = @c_Wavekey 
       AND PICKDETAIL_WIP.WIP_RefNo = @c_SourceType
       
       SELECT @n_err = @@ERROR
       IF @n_err <> 0 
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (ispRLWAV13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END 
    END
                   
    -----Create Replenishment task to rack pick loc (sku.putawayloc)
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN             
       DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, MAX(PD.UOM), SUM(PD.UOMQty) AS UOMQty, SKU.PutawayLoc                 
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
          JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey 
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
          WHERE WD.Wavekey = @c_Wavekey
          AND PD.Status = '0'
          AND PD.WIP_RefNo = @c_SourceType
          AND LOC.LocationType = 'BULK'
          --AND SKU.Putawayzone LIKE 'NIKEPAL%'
          AND Loc.Putawayzone IN (SELECT Short FROM CODELKUP(NOLOCK) WHERE Listname = 'RPLZONE')
          AND ISNULL(SKU.PutawayLoc,'') <> ''
          GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, LOC.LogicalLocation, SKU.PutawayLoc 
          ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot       
       
       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_ToLoc
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN             
         SET @c_LinkTaskToPick_SQL = ''--'AND PICKDETAIL.UOM = @c_UOM' --additional condition to search pickdetail         
          SET @c_PickMethod = 'FP'

           EXEC isp_InsertTaskDetail   
              @c_TaskType              = @c_TaskType             
             ,@c_Storerkey             = @c_Storerkey
             ,@c_Sku                   = @c_Sku
             ,@c_Lot                   = @c_Lot 
             ,@c_UOM                   = @c_UOM      
             ,@n_UOMQty                = 0   
             ,@n_Qty                   = @n_Qty      
             ,@c_FromLoc               = @c_Fromloc      
             ,@c_LogicalFromLoc        = @c_FromLoc 
             ,@c_FromID                = @c_ID     
             ,@c_ToLoc                 = @c_ToLoc       
             ,@c_LogicalToLoc          = @c_ToLoc 
             ,@c_ToID                  = @c_ID       
             ,@c_PickMethod            = @c_PickMethod
             ,@c_Priority              = @c_Priority     
             ,@c_SourcePriority        = '9'      
             ,@c_SourceType            = @c_SourceType      
             ,@c_SourceKey             = @c_Wavekey      
             ,@c_WaveKey               = @c_Wavekey      
             ,@c_RoundUpQty            = 'FL' --FL=Round up to full location qty
             ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
             ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
             ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
             ,@c_ReserveQtyReplen      = 'ROUNDUP' --  ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
             ,@c_ReservePendingMoveIn  = 'Y'  -- Y=Update @n_qty to @n_PendingMoveIn
             --,@c_CombineTasks          = 'Y' --Y=Combine task of same lot,from/to loc and id. usually apply for replenishment task with round up full case/pallet and systemqty is the actual pickdetail.qty
             ,@c_WIP_RefNo             = @c_SourceType
             ,@b_Success               = @b_Success OUTPUT
             ,@n_Err                   = @n_err OUTPUT 
             ,@c_ErrMsg                = @c_errmsg OUTPUT         
          
             IF @b_Success <> 1 
             BEGIN
                SELECT @n_continue = 3  
             END
                                                      
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_ToLoc
       END 
       CLOSE cur_pick  
       DEALLOCATE cur_pick                                                
    END     
                
    -----Update pickdetail_WIP work in progress staging table back to pickdetail 
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
       DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT PickDetail_WIP.PickDetailKey, PickDetail_WIP.Qty, PickDetail_WIP.UOMQty, 
                 PickDetail_WIP.TaskDetailKey, PickDetail_WIP.Pickslipno
          FROM PickDetail_WIP (NOLOCK)
          JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey
          WHERE ORDERS.Userdefine09 = @c_Wavekey 
          AND PickDetail_WIP.WIP_RefNo = @c_SourceType
          ORDER BY PickDetail_WIP.PickDetailKey 
       
       OPEN cur_PickDetailKey
       
       FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_PickslipNo
       
       WHILE @@FETCH_STATUS = 0
       BEGIN
          IF EXISTS(SELECT 1 FROM PICKDETAIL WITH (NOLOCK) 
                    WHERE PickDetailKey = @c_PickDetailKey)
          BEGIN
             UPDATE PICKDETAIL WITH (ROWLOCK) 
             SET Qty = @n_Qty, 
                 UOMQty = @n_UOMQty, 
                 TaskDetailKey = @c_TaskDetailKey,
                 PickslipNo = @c_Pickslipno,
                 WaveKey = @c_Wavekey,
                 EditDate = GETDATE(),                             
                 TrafficCop = NULL
             WHERE PickDetailKey = @c_PickDetailKey  
             
             SELECT @n_err = @@ERROR
             
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                END        
          END
          ELSE 
          BEGIN            
             INSERT INTO PICKDETAIL 
                  (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                   Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                   DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                   ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                   WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, 
                   Taskdetailkey, TaskManagerReasonkey, Notes )
             SELECT PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                   Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                   DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                   ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                   WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, 
                   Taskdetailkey, TaskManagerReasonkey, Notes
             FROM PICKDETAIL_WIP WITH (NOLOCK)
             WHERE PickDetailKey = @c_PickDetailKey
             
             SELECT @n_err = @@ERROR
             
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                END         
          END
       
           FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_Pickslipno
       END   
       CLOSE cur_PickDetailKey
       DEALLOCATE cur_PickDetailKey             
    END
      
    -----Validation taskdetail at pickdetail-----
    /*IF @n_continue = 1 or @n_continue = 2  
    BEGIN      
       IF EXISTS(SELECT 1 
                 FROM TASKDETAIL TD (NOLOCK)
                 LEFT JOIN PICKDETAIL PD (NOLOCK) ON TD.Taskdetailkey = PD.Taskdetailkey 
                 WHERE TD.Wavekey = @c_Wavekey                   
                 AND TD.Sourcetype = @c_SourceType 
                 AND TD.Tasktype IN('RFP')                 
                 AND PD.Taskdetailkey IS NULL)
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Taskdetailkey To Pickdetail Failed. (ispRLWAV13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                             
       END          
    END*/
            
    -----Update Wave Status-----
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
       UPDATE WAVE 
          --SET STATUS = '1' -- Released        --(Wan01) 
          SET TMReleaseFlag = 'Y'               --(Wan01) 
           ,  TrafficCop = NULL                 --(Wan01) 
           ,  EditWho = SUSER_SNAME()           --(Wan01) 
           ,  EditDate= GETDATE()               --(Wan01) 
       WHERE WAVEKEY = @c_wavekey  
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
   
RETURN_SP:

    IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)
              JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
              WHERE O.Userdefine09 = @c_Wavekey
              AND PD.WIP_RefNo = @c_SourceType)
    BEGIN
       DELETE PickDetail_WIP 
       FROM PickDetail_WIP (NOLOCK)
       JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey              
       WHERE ORDERS.Userdefine09 = @c_Wavekey 
       AND PickDetail_WIP.WIP_RefNo = @c_SourceType       
    END        

    IF @n_continue=3  -- Error Occured - Process And Return  
    BEGIN  
       SELECT @b_success = 0  
       IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
       BEGIN  
          ROLLBACK TRAN  
       END  
       ELSE  
       BEGIN  
          WHILE @@TRANCOUNT > @n_starttcnt  
          BEGIN  
             COMMIT TRAN  
          END  
       END  
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV13"  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
       RETURN  
    END  
    ELSE  
    BEGIN  
       SELECT @b_success = 1  
       WHILE @@TRANCOUNT > @n_starttcnt  
       BEGIN  
          COMMIT TRAN  
       END  
       RETURN  
    END      
 END --sp end

GO