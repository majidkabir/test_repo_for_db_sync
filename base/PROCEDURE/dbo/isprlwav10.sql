SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLWAV10                                          */  
/* Creation Date: 31-May-2017                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-1846 - CN DYSON Release pick task                        */  
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.4                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/* 06/07/2017  NJOW01   1.0   Fix. pass in @c_LinkTaskToPick_SQL param   */
/*                             for retrieve pickdetial orderkey filtering*/ 
/* 20/07/2017  NJOW02   1.1   WMS-2383 Map orderkey to groupkey          */
/* 28/07/2017  NJOW03   1.2   Fix. Add pickdetail.taskdetailkey checking */
/* 23/08/2017  TLTING   1.3   Performance tune                           */
/* 01-04-2020  Wan01    1.4   Sync Exceed & SCE                          */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV10]      
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
            ,@c_Sku NVARCHAR(20)
            ,@c_Lot NVARCHAR(10)
            ,@c_FromLoc NVARCHAR(10)
            ,@c_ID NVARCHAR(18)
            ,@n_Qty INT
            ,@c_Priority NVARCHAR(10)
            ,@c_PickMethod NVARCHAR(10)
            ,@c_Toloc NVARCHAR(10)
            ,@c_Taskdetailkey NVARCHAR(10)  
            ,@c_Pickdetailkey NVARCHAR(10)
            ,@c_UOM NVARCHAR(10)
            ,@c_SourceType NVARCHAR(30)
            ,@c_TaskType NVARCHAR(10)
            ,@n_UOMQty INT
            ,@c_Facility NVARCHAR(5)
            ,@c_DispatchPalletPickMethod NVARCHAR(10)
            ,@c_DispatchCasePickMethod NVARCHAR(10)
            ,@c_DispatchPiecePickMethod NVARCHAR(10)            
            ,@c_Orderkey NVARCHAR(10)
            --,@n_PickBalQty INT
            --,@n_Pallet INT
            --,@n_MaxPallet INT            
            ,@c_PickslipNo NVARCHAR(10)
            ,@c_GroupKey NVARCHAR(10) 
            
    SET @c_SourceType = 'ispRLWAV10'    
    SET @c_Priority = '9'

    -----Wave Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype IN('FPK','FCP')
                      WHERE WD.Wavekey = @c_Wavekey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV10)'       
       END
    END
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype = @c_SourceType
                   AND TD.Tasktype IN('FPK','FCP'))
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83010    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV10)'       
        END                 
    END
          
    -----Get Storerkey, facility and dispatch method
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                     @c_Facility = O.Facility,
                     @c_DispatchPalletPickMethod = W.DispatchPalletPickMethod,
                     @c_DispatchCasePickMethod =  W.DispatchCasePickMethod,
                     @c_DispatchPiecePickMethod = W.DispatchPiecePickMethod
        FROM WAVE W (NOLOCK)
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        AND W.Wavekey = @c_Wavekey 
    END    

    --Initialize Pickdetail work in progress staging table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)
                 JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
                 JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = O.Orderkey
                 WHERE WD.Wavekey = @c_Wavekey)
       BEGIN
           DELETE PickDetail_WIP WITH (ROWLOCK)
           FROM PickDetail_WIP  
           JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey 
           JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = ORDERS.Orderkey         
          WHERE WD.Wavekey = @c_Wavekey 
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
         Notes,               MoveRefKey 
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
         PD.Notes,                   PD.MoveRefKey 
       FROM WAVEDETAIL WD (NOLOCK) 
       JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey
       WHERE WD.Wavekey = @c_Wavekey
       
       SET @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83020     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail_WIP Table. (ispRLWAV10)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
       
       SELECT @n_err = @@ERROR
       IF @n_err <> 0 
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (ispRLWAV10)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END 
    END
            
    -----Create pick task 
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN                        
       DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, SUM(PD.UOMQty) AS UOMQty, PD.Orderkey
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
          JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          WHERE WD.Wavekey = @c_Wavekey
          AND PD.Status = '0'
          GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, PD.Orderkey, LOC.LogicalLocation
          ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot       
       
       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Orderkey
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN                       
           IF @c_UOM = '1' 
           BEGIN
             SET @c_TaskType = 'FPK'
             SET @c_PickMethod = 'FP'
             SET @c_GroupKey = ''
             
             SELECT @c_ToLoc = Short
             FROM CODELKUP(NOLOCK)
             WHERE Listname = 'DIPALPKMTD'
             AND Code = @c_DispatchPalletPickMethod                             
           END

           IF @c_UOM IN('2','6') 
           BEGIN
             SET @c_TaskType = 'FCP'             
             SET @c_PickMethod = 'PP'            
             SET @c_GroupKey = @c_Orderkey   --NJOW01
             
             SELECT @c_ToLoc = Short
             FROM CODELKUP(NOLOCK)
             WHERE Listname = 'DICSEPKMTD'
             AND Code = @c_DispatchCasePickMethod                            
           END

          EXEC isp_InsertTaskDetail   
              @c_TaskType              = @c_TaskType             
             ,@c_Storerkey             = @c_Storerkey
             ,@c_Sku                   = @c_Sku
             ,@c_Lot                   = @c_Lot 
             ,@c_UOM                   = @c_UOM      
             ,@n_UOMQty                = @n_UOMQty      
             ,@n_Qty                   = @n_Qty      
             ,@c_FromLoc               = @c_Fromloc      
             ,@c_FromID                = @c_ID     
             ,@c_ToLoc                 = @c_ToLoc       
             ,@c_LogicalToLoc          = @c_ToLoc 
             ,@c_ToID                  = @c_ID       
             ,@c_PickMethod            = @c_PickMethod
             ,@c_Priority              = @c_Priority     
             ,@c_SourcePriority        = '9'      
             ,@c_SourceType            = @c_SourceType      
             ,@c_SourceKey             = @c_Wavekey      
             ,@c_OrderKey              = @c_Orderkey      
             ,@c_WaveKey               = @c_Wavekey      
             ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
             ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
             ,@c_LinkTaskToPick_SQL    = 'AND PICKDETAIL.Orderkey = @c_Orderkey' --NJOW01
             ,@c_Groupkey              = @c_GroupKey 
             ,@b_Success               = @b_Success OUTPUT
             ,@n_Err                   = @n_err OUTPUT 
             ,@c_ErrMsg                = @c_errmsg OUTPUT         

          IF @b_Success <> 1 
          BEGIN
             SELECT @n_continue = 3  
          END
                                                      
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Orderkey
       END 
       CLOSE cur_pick  
       DEALLOCATE cur_pick                                                
    END     
       
    -----Create replenishment task
    /*
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       --Retreive pick loc with qty < maxpallet
       DECLARE cur_PickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT LLI.Storerkey, LLI.Sku, LLI.Loc, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) AS Qty,
                 PACK.Pallet, LOC.MaxPallet 
          FROM LOTXLOCXID LLI (NOLOCK)          
          JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
          JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey          
          JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
          WHERE SL.LocationType IN('PICK','CASE')
          AND LLI.Storerkey = @c_Storerkey       
          AND (LOC.MaxPallet - 1) > 0
          AND PACK.Pallet > 0
          GROUP BY LLI.Storerkey, LLI.Sku, LLI.Loc, PACK.Pallet, LOC.MaxPallet 
          HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) <= ((LOC.MaxPallet - 1) * PACK.Pallet)  

       OPEN cur_PickLoc
       
       FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_ToLoc, @n_PickBalQty, @n_Pallet, @n_MaxPallet
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN               
           --retrieve pallet from bulk 
          DECLARE cur_BulkPallet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
             SELECT LLI.Lot, LLI.Loc, LLI.Id, LLI.Qty 
             FROM LOTXLOCXID LLI (NOLOCK)          
             JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
             JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
             WHERE SL.LocationType NOT IN('PICK','CASE')
             AND LOC.LocationType = 'NONE' 
             AND (LLI.QtyAllocated + LLI.QtyPicked + LLI.QtyReplen) = 0
             AND LLI.Storerkey = @c_Storerkey
             AND LLI.Sku = @c_Sku
             ORDER BY SL.Qty, LOC.Logicallocation, LOC.Loc, LLI.Lot
             
          OPEN cur_BulkPallet
         
          FETCH FROM cur_BulkPallet INTO @c_Lot, @c_FromLoc, @c_ID, @n_Qty
          
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_PickBalQty <= ((@n_MaxPallet - 1) * @n_Pallet)
          BEGIN
             SET @n_PickBalQty = @n_PickBalQty + @n_Qty
             
             EXEC isp_InsertTaskDetail   
                 @c_TaskType              = 'RPF'             
                ,@c_Storerkey             = @c_Storerkey
                ,@c_Sku                   = @c_Sku
                ,@c_Lot                   = @c_Lot 
                ,@c_UOM                   = '1'      
                ,@n_UOMQty                = 1      
                ,@n_Qty                   = @n_Qty      
                ,@c_FromLoc               = @c_Fromloc      
                ,@c_FromID                = @c_ID     
                ,@c_ToLoc                 = @c_ToLoc       
                ,@c_ToID                  = @c_ID       
                ,@c_PickMethod            = 'FP'
                ,@c_Priority              = @c_Priority     
                ,@c_SourcePriority        = '9'      
                ,@c_SourceType            = @c_SourceType      
                ,@c_SourceKey             = @c_Wavekey      
                ,@c_WaveKey               = @c_Wavekey      
                ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                ,@c_ToLocPendingMoveIn    = 'R'   -- R=Use RDT pending move in locking method  
                ,@b_Success               = @b_Success OUTPUT
                ,@n_Err                   = @n_err OUTPUT 
                ,@c_ErrMsg                = @c_errmsg OUTPUT         
             
             IF @b_Success <> 1 
             BEGIN
                SELECT @n_continue = 3  
             END
             
             FETCH FROM cur_BulkPallet INTO @c_Lot, @c_FromLoc, @c_ID, @n_Qty
          END
          CLOSE cur_BulkPallet
          DEALLOCATE cur_BulkPallet 
          
          FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_ToLoc, @n_PickBalQty, @n_Pallet, @n_MaxPallet
       END
       CLOSE cur_PickLoc
       DEALLOCATE cur_PickLoc          
    END
    */

    -----Generate Pickslip No-------
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN
       DECLARE CUR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT Orderkey
          FROM   WAVEDETAIL (NOLOCK)  
          WHERE  WAVEDETAIL.Wavekey = @c_wavekey   
          ORDER BY Orderkey
  
       OPEN CUR_ORDER  
  
       FETCH NEXT FROM CUR_ORDER INTO @c_Orderkey
  
       WHILE @@FETCH_STATUS <> -1  
       BEGIN  
          SET @c_PickSlipno = ''      
          SELECT @c_PickSlipno = PickheaderKey  
          FROM   PICKHEADER (NOLOCK)  
          WHERE  Orderkey = @c_Orderkey
                             
          -- Create Pickheader      
          IF ISNULL(@c_PickSlipno, '') = ''  
          BEGIN  
             EXECUTE nspg_GetKey   
             'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_err OUTPUT,   @c_errmsg OUTPUT      
                
             SELECT @c_Pickslipno = 'P' + @c_Pickslipno      
                        
             INSERT INTO PICKHEADER  
               (PickHeaderKey, Wavekey, Orderkey, ExternOrderkey ,PickType, Zone, TrafficCop)  
             VALUES  
               (@c_Pickslipno, '', @c_Orderkey, '', '0' ,'3', '')      
               
             SELECT @n_err = @@ERROR  
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed. (ispRLWAV10)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
             END  
          END 
       
          UPDATE PICKDETAIL_WIP WITH (ROWLOCK)  
          SET    PICKDETAIL_WIP.PickSlipNo = @c_PickSlipNo  
                ,TrafficCop = NULL  
          WHERE Orderkey = @c_Orderkey
            
          SELECT @n_err = @@ERROR  
          IF @n_err <> 0  
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed (ispRLWAV10)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END  
          
          /*
          IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookUp WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
          BEGIN
             INSERT INTO dbo.RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
             SELECT PickdetailKey, PickSlipNo, OrderKey, OrderLineNumber 
             FROM PICKDETAIL_WIP (NOLOCK)  
             WHERE PickSlipNo = @c_PickSlipNo  
             SELECT @n_err = @@ERROR  
             IF @n_err <> 0   
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83055     
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookUp Table Failed. (ispRLWAV10)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
             END   
          END
          */        
            
          FETCH NEXT FROM CUR_ORDER INTO @c_OrderKey      
       END   
       CLOSE CUR_ORDER  
       DEALLOCATE CUR_ORDER 
    END      
            
    -----Update pickdetail_WIP work in progress staging table back to pickdetail 
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
       DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT PickDetail_WIP.PickDetailKey, PickDetail_WIP.Qty, PickDetail_WIP.UOMQty, 
              PickDetail_WIP.TaskDetailKey, PickDetail_WIP.Pickslipno
       FROM PickDetail_WIP (NOLOCK)
       JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey
       JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = ORDERS.Orderkey
       WHERE WD.Wavekey = @c_Wavekey 
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
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV10)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
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
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV10)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                END         
          END
       
           FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_Pickslipno
       END   
       CLOSE cur_PickDetailKey
       DEALLOCATE cur_PickDetailKey             
    END

    -----Validation taskdetail at pickdetail-----
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN      
       --NJOW03
       IF EXISTS(SELECT 1 
                 FROM TASKDETAIL TD (NOLOCK)
                 LEFT JOIN PICKDETAIL PD (NOLOCK) ON TD.Taskdetailkey = PD.Taskdetailkey 
                 WHERE TD.Wavekey = @c_Wavekey                   
                 AND TD.Sourcetype = @c_SourceType 
                 AND TD.Tasktype IN('FPK','FCP')                 
                 AND PD.Taskdetailkey IS NULL)
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83075   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Taskdetailkey To Pickdetail Failed. (ispRLWAV10)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                             
       END          
    END
    
    -----Update Wave Status-----
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
       UPDATE WAVE WITH (ROWLOCK)
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV10)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
   
RETURN_SP:

    IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)
              JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
              JOIN dbo.WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = O.Orderkey
              WHERE WD.WaveKey = @c_Wavekey)
    BEGIN
        DELETE PickDetail_WIP WITH (ROWLOCK)
        FROM PickDetail_WIP 
        JOIN dbo.WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = PickDetail_WIP.Orderkey            
       WHERE WD.WaveKey = @c_Wavekey 
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV10"  
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