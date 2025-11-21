SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLWAV09                                          */  
/* Creation Date: 13-Apr-2017                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-1578 - CN Victoria Secret Ecom - Wave Release Repl Tasks */  
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.2                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/* 05-Jul-2017 NJOW01   1.0   WMS-1578 Release by UCC                    */
/* 08-Mar-2018 NJOW02   1.1   WMS-4020 Add UOM 2 for B2B. Remove UCC#    */
/* 01-04-2020  Wan01    1.2   Sync Exceed & SCE                          */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV09]      
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
            ,@n_CaseCnt INT
            ,@c_Priority NVARCHAR(10)
            ,@c_Areakey NVARCHAR(10)
            ,@c_PickMethod NVARCHAR(10)
            ,@c_Toloc NVARCHAR(10)
            ,@c_Taskdetailkey NVARCHAR(10)  
            ,@c_UOM NVARCHAR(10)
            ,@c_SourceType NVARCHAR(30)
            ,@c_Pickdetailkey NVARCHAR(18)
            ,@c_NewPickdetailKey NVARCHAR(18)
            ,@n_Pickqty INT
            ,@n_ReplenQty INT
            ,@n_SplitQty  INT
            ,@c_TaskType NVARCHAR(10)
            ,@c_MEZLoc NVARCHAR(10) --MEZZANINE location 
            ,@n_UOMQty INT
            ,@c_Facility NVARCHAR(5)
            ,@dt_Lottable04 DATETIME
            ,@c_UCCNo NVARCHAR(20)
            ,@n_UCCQty INT
            ,@C_UCCStatus NVARCHAR(1)
            ,@n_BalQty INT   
            ,@n_SysQty INT
            ,@c_DropID NVARCHAR(20) --NJOW01
            ,@c_ReplenFullCaseToTMPLoc NVARCHAR(10) --NJOW02
            ,@n_InsertQty INT
            ,@n_noofcarton INT
            ,@c_RoundUpQty NVARCHAR(5)
            ,@c_CasecntbyLocUCC NVARCHAR(5)

    SET @c_SourceType = 'ispRLWAV09'    
    SET @c_Priority = '9'
   SET @c_Areakey = ''
      SET @c_TaskType = 'RPF'
      
    -----Wave Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype = 'RPF'
                      WHERE WD.Wavekey = @c_Wavekey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 82010  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV09)'       
       END
    END
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype = @c_SourceType
                   AND TD.Tasktype = 'RPF')
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 82020    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV09)'       
        END                 
    END
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF NOT EXISTS (SELECT 1
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
                      WHERE WD.Wavekey = @c_Wavekey
                      AND PD.Status = '0'
                      AND PD.UOM = '7')
       BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 82025    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No available VNA(UOM7) Task to release for this Wave. (ispRLWAV09)'       
       END                 
    END
    
    -----Get Storerkey, facility and dispatch method
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                     @c_Facility = O.Facility
        FROM WAVE W (NOLOCK)
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        AND W.Wavekey = @c_Wavekey 
        
        --NJOW02            
        EXEC nspGetRight
          @c_Facility  = NULL,
          @c_StorerKey = @c_StorerKey,
          @c_sku       = NULL,
          @c_ConfigKey = 'ReplenFullCaseToTMPLoc',
          @b_Success   = @b_Success                  OUTPUT,
          @c_authority = @c_ReplenFullCaseToTMPLoc   OUTPUT,
          @n_err       = @n_err                      OUTPUT,
          @c_errmsg    = @c_errmsg                   OUTPUT
    END

    --Initialize Pickdetail work in progress staging table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS(SELECT 1 FROM PickDetail_WIP WITH (NOLOCK)
                 WHERE WaveKey = @c_Wavekey)
       BEGIN
           DELETE PickDetail_WIP 
          WHERE WaveKey = @c_Wavekey 
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82040     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail_WIP Table. (ispRLWAV09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82050  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (ispRLWAV09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END 
    END
    
    -----Create data temporary table 
    IF (@n_continue = 1 OR @n_continue = 2) 
    BEGIN      
       --Current wave assigned MEZZANINE pick location
       CREATE TABLE #MEZZANINE_LOCASSIGNED (RowId BIGINT Identity(1,1) PRIMARY KEY
                                         ,STORERKEY NVARCHAR(15) NULL
                                         ,SKU NVARCHAR(20) NULL
                                         ,TOLOC NVARCHAR(10) NULL
                                         ,LOTTABLE04 DATETIME NULL)
       CREATE INDEX IX_AS ON #MEZZANINE_LOCASSIGNED (STORERKEY,SKU,LOTTABLE04)

       CREATE TABLE #MEZZANINE_TASK (RowId BIGINT Identity(1,1) PRIMARY KEY, TOLOC NVARCHAR(10) NULL)

       CREATE TABLE #MEZZANINE_NON_EMPTY (RowId BIGINT Identity(1,1) PRIMARY KEY, LOC NVARCHAR(10) NULL)
       CREATE INDEX IDX_EMPTY ON #MEZZANINE_NON_EMPTY (LOC)

       --MEZZANINE pick loc have qty and pending move in
       INSERT INTO #MEZZANINE_NON_EMPTY (LOC)
       SELECT LLI.LOC
       FROM   LOTxLOCxID LLI (NOLOCK)
       JOIN   LOC L (NOLOCK) ON LLI.LOC = L.LOC
       WHERE  L.LocationType = 'OTHER' 
       AND    L.LocationCategory = 'MEZZANINE'
       AND    L.Facility = @c_Facility
       GROUP BY LLI.LOC
       HAVING SUM((LLI.Qty + LLI.PendingMoveIN + LLI.QtyExpected) - LLI.QtyPicked ) > 0

       --location have pending Replenishment tasks
       INSERT INTO #MEZZANINE_TASK (TOLOC)
       SELECT TD.ToLoc 
       FROM TASKDETAIL TD (NOLOCK)
       JOIN LOC L (NOLOCK) ON TD.ToLoc = L.Loc
       WHERE L.LocationType = 'OTHER' 
       AND L.LocationCategory = 'MEZZANINE' 
       AND TD.TaskType = 'RPF'
       AND L.Facility = @c_Facility
       AND TD.SourceType = @c_SourceType
       AND TD.Status = '0'
       AND TD.Qty > 0
       GROUP BY TD.ToLoc       
    END
     
    -----Create replenishment task from VNA to DPP, 1 UCC 1 task
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN                     
       --NJOW02   
       SELECT PD.Lot, PD.Loc, PD.ID, MAX(ISNULL(UCC.Qty,0)) AS UCCQty
       INTO #TMP_UCC
       FROM PICKDETAIL PD(NOLOCK)
       JOIN WAVEDETAIL WD (NOLOCK) ON PD.Orderkey = WD.Orderkey
       LEFT JOIN UCC (NOLOCK) ON UCC.StorerKey = PD.StorerKey AND UCC.SKU = PD.SKU AND 
                               UCC.LOT = PD.LOT AND UCC.LOC = PD.LOC AND UCC.ID = PD.ID AND UCC.Status < '3' 
       WHERE WD.Wavekey = @c_Wavekey
       AND PD.Status = '0'
       AND PD.UOM IN('7','2')
       GROUP BY PD.Lot, PD.Loc, PD.ID         
       
       DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, 'PP' AS PickMethod, LA.Lottable04, ISNULL(UCC.UCCQty,0)
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
          JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey
          JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          LEFT JOIN #TMP_UCC UCC ON PD.Lot = UCC.Lot AND PD.Loc = UCC.Loc AND PD.Id = UCC.Id 
          WHERE WD.Wavekey = @c_Wavekey
          AND PD.Status = '0'
          AND PD.UOM IN('7','2') --VNA  --NJOW02
          GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM,  LA.Lottable04, ISNULL(UCC.UCCQty,0)
          ORDER BY PD.Storerkey, PD.Sku, PD.Lot       
       
       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @c_PickMethod, @dt_Lottable04, @n_UCCQty
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN            
           SET @c_ToLoc = ''
            SET @n_noofcarton = 1
           SET @n_UOMQty = @n_UCCQty
           
           IF @c_UOM = '2'
           BEGIN            
              SELECT @c_Toloc = Loc
             FROM LOC (NOLOCK)
             WHERE LocationType = 'RPLTMP'
             AND Loc = @c_ReplenFullCaseToTMPLoc
             
             IF ISNULL(@c_ToLoc,'') <> ''
             BEGIN                 
                 IF @n_UCCQty > 0 
                    SET @n_noofcarton = CEILING(@n_Qty / (@n_UCCQty * 1.00)) 
                 
                WHILE @n_noofcarton > 0 AND @n_continue IN(1,2)
                BEGIN                   
                   IF @n_Qty >= @n_UCCQty AND @n_UCCQty > 0
                      SET @n_InsertQty = @n_UCCQty
                   ELSE 
                      SET @n_InsertQty = @n_Qty
                   
                   EXEC isp_InsertTaskDetail   
                    @c_TaskType              = @c_TaskType             
                   ,@c_Storerkey             = @c_Storerkey
                   ,@c_Sku                   = @c_Sku
                   ,@c_Lot                   = @c_Lot 
                   ,@c_UOM                   = @c_UOM      
                   ,@n_UOMQty                = @n_UOMQty      
                   ,@n_Qty                   = @n_InsertQty
                   ,@n_SystemQty             = @n_InsertQty      
                   ,@c_FromLoc               = @c_Fromloc      
                   ,@c_LogicalFromLoc        = @c_Fromloc    
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
                   ,@c_AreaKey               = @c_Areakey
                   ,@c_Caseid                = ''
                   ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
                   ,@c_LinkTaskToPick_SQL    = 'AND PICKDETAIL.UOM = @c_UOM'  --Additional sql condition to retrieve the pickdetail
                   ,@c_ReservePendingMoveIn  = 'N' --Y=Update @n_qty to @n_PendingMoveIn
                   ,@b_Success               = @b_Success OUTPUT
                   ,@n_Err                   = @n_err OUTPUT 
                   ,@c_ErrMsg                = @c_errmsg OUTPUT       
                   
                   IF @b_success <> 1
                      SELECT @n_continue = 3
                   
                   SET @n_Qty = @n_Qty - @n_InsertQty   
                   SET @n_noofcarton = @n_noofcarton - 1                                 
                END      
                GOTO NEXT_REC                                                                              
             END                               
          END      
             
         GOTO FIND_MEZ_LOC
          RTN_FIND_MEZ_LOC:
                                    
            SET @c_ToLoc = @c_MEZLoc
            

          IF @n_UCCQty > 0
          BEGIN 
             SET @n_noofcarton = CEILING(@n_Qty / (@n_UCCQty * 1.00))
             SET @c_RoundUpQty = 'FC'
             SET @c_CasecntbyLocUCC = 'Y'
          END
          ELSE
          BEGIN 
             SET @c_RoundUpQty = ''
             SET @c_CasecntbyLocUCC = 'N'
          END
          
          WHILE @n_noofcarton > 0 AND @n_continue IN(1,2)
          BEGIN                   
             IF @n_Qty >= @n_UCCQty AND @n_UCCQty > 0
                SET @n_InsertQty = @n_UCCQty
             ELSE 
                SET @n_InsertQty = @n_Qty
                
             EXEC isp_InsertTaskDetail   
                 @c_TaskType              = @c_TaskType             
                ,@c_Storerkey             = @c_Storerkey
                ,@c_Sku                   = @c_Sku
                ,@c_Lot                   = @c_Lot 
                ,@c_UOM                   = @c_UOM      
                ,@n_UOMQty                = @n_UOMQty      
                ,@n_Qty                   = @n_InsertQty
                ,@n_SystemQty             = @n_InsertQty      
                ,@c_FromLoc               = @c_Fromloc      
                ,@c_LogicalFromLoc        = @c_Fromloc    
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
                ,@c_AreaKey               = @c_Areakey
                ,@c_Caseid                = ''
                ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
                ,@c_LinkTaskToPick_SQL    = 'AND PICKDETAIL.UOM = @c_UOM'  --Additional sql condition to retrieve the pickdetail
                ,@c_ReserveQtyReplen      = 'ROUNDUP' -- ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
                ,@c_ReservePendingMoveIn  = 'Y' --Y=Update @n_qty to @n_PendingMoveIn
                ,@c_CombineTasks          = 'C' --C=Same as Y option but only combine when extra qty (qty-systemqty) is sufficient to cover systemqty. Usually apply for combine carton per task.
                ,@c_CasecntbyLocUCC       = @c_CasecntbyLocUCC --Y=Get casecnt by UCC Qty of the lot,loc & ID. All UCC must have same qty.    
                ,@c_RoundUpQty            = @c_RoundUpQty --FC=Round up qty to full carton by packkey/ucc
                ,@b_Success               = @b_Success OUTPUT
                ,@n_Err                   = @n_err OUTPUT 
                ,@c_ErrMsg                = @c_errmsg OUTPUT       
                
                IF @b_success <> 1
                   SELECT @n_continue = 3          
    
              SET @n_Qty = @n_Qty - @n_InsertQty   
              SET @n_noofcarton = @n_noofcarton - 1                                                    
          END                                                               
                                 
          NEXT_REC:
                                    
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @c_PickMethod, @dt_Lottable04, @n_UCCQty
       END 
       CLOSE cur_pick  
       DEALLOCATE cur_pick                                                
    END  
            
    -----Update pickdetail_WIP work in progress staging table back to pickdetail 
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
       DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT PickDetailKey, Qty, UOMQty, TaskDetailKey
       FROM PickDetail_WIP WITH (NOLOCK)
       WHERE WaveKey = @c_Wavekey 
       ORDER BY PickDetailKey 
       
       OPEN cur_PickDetailKey
       
       FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey
       
       WHILE @@FETCH_STATUS = 0
       BEGIN
          IF EXISTS(SELECT 1 FROM PICKDETAIL WITH (NOLOCK) 
                    WHERE PickDetailKey = @c_PickDetailKey)
          BEGIN
             UPDATE PICKDETAIL WITH (ROWLOCK) 
             SET Qty = @n_Qty, 
                 UOMQty = @n_UOMQty, 
                 TaskDetailKey = @c_TaskDetailKey,
                 WaveKey = @c_Wavekey,
                 EditDate = GETDATE(),                             
                 TrafficCop = NULL
             WHERE PickDetailKey = @c_PickDetailKey  
             
             SELECT @n_err = @@ERROR
             
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
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
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
                END         
          END
       
           FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey
       END   
       CLOSE cur_PickDetailKey
       DEALLOCATE cur_PickDetailKey      

       IF EXISTS(SELECT 1 FROM PickDetail_WIP WITH (NOLOCK)
                 WHERE WaveKey = @c_Wavekey)
       BEGIN
          DELETE PickDetail_WIP 
          WHERE WaveKey = @c_Wavekey 
       END               
    END
    
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
   
RETURN_SP:

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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV09"  
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

 --------------------Function to insert taskdetail & pickdetail update (qtyreplen, taskdetailkey)---------------------     
 /*INSERT_TASKS:

 SELECT @b_success = 1  
 EXECUTE   nspg_getkey  
 "TaskDetailKey"  
 , 10  
 , @c_taskdetailkey OUTPUT  
 , @b_success OUTPUT  
 , @n_err OUTPUT  
 , @c_errmsg OUTPUT  
 IF NOT @b_success = 1  
 BEGIN  
    SELECT @n_continue = 3  
 END  

 IF @b_success = 1  
 BEGIN      
   INSERT TASKDETAIL  
    (  
      TaskDetailKey  
     ,TaskType  
     ,Storerkey  
     ,Sku  
     ,UOM  
     ,UOMQty  
     ,Qty  
     ,SystemQty
     ,Lot  
     ,FromLoc  
     ,FromID  
     ,ToLoc  
     ,ToID  
     ,SourceType  
     ,SourceKey  
     ,Priority  
     ,SourcePriority  
     ,Status  
     ,LogicalFromLoc  
     ,LogicalToLoc  
     ,PickMethod
     ,Wavekey
     ,Areakey
     ,CaseID
     ,StatusMsg
    )  
    VALUES  
    (  
      @c_taskdetailkey  
     ,@c_TaskType --Tasktype  FPK/SCP 
     ,@c_Storerkey  
     ,@c_Sku  
     ,@c_UOM -- UOM,  
     ,@n_UOMQty  -- UOMQty (UCC Qty)  
     ,@n_Qty  --replenishment qty
     ,@n_SysQty  --systemqty allocated qty
     ,@c_Lot   
     ,@c_fromloc   
     ,@c_ID -- from id  
     ,@c_toloc 
     ,@c_ID -- to id  
     ,@c_SourceType --Sourcetype  
     ,@c_Wavekey --Sourcekey  
     ,@c_Priority -- Priority  
     ,'9' -- Sourcepriority  
     ,'0' -- Status  
     ,@c_FromLoc --Logical from loc  
     ,@c_ToLoc --Logical to loc  
     ,@c_PickMethod
     ,@c_Wavekey
     ,@c_Areakey
     ,'' --@c_UCCNo
     ,''--@c_UCCStatus
    )
    
    SELECT @n_err = @@ERROR  
    IF @n_err <> 0  
    BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
        GOTO RETURN_SP
    END   
 END
  
 --Update taskdetailkey to pickdetail
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
     SELECT @c_Pickdetailkey = '', @n_ReplenQty = @n_Qty
     WHILE @n_ReplenQty > 0 
    BEGIN                        
       SET ROWCOUNT 1   
       
       SELECT @c_PickdetailKey = PICKDETAIL_WIP.Pickdetailkey, @n_PickQty = Qty
       FROM WAVEDETAIL (NOLOCK) 
       JOIN PICKDETAIL_WIP (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL_WIP.Orderkey
       WHERE WAVEDETAIL.Wavekey = @c_Wavekey
       AND ISNULL(PICKDETAIL_WIP.Taskdetailkey,'') = ''
       AND PICKDETAIL_WIP.Storerkey = @c_Storerkey
       AND PICKDETAIL_WIP.Sku = @c_sku
       AND PICKDETAIL_WIP.Lot = @c_Lot
       AND PICKDETAIL_WIP.Loc = @c_FromLoc
       AND PICKDETAIL_WIP.ID = @c_ID
       AND PICKDETAIL_WIP.UOM = @c_UOM
       AND PICKDETAIL_WIP.Pickdetailkey > @c_pickdetailkey
       ORDER BY PICKDETAIL_WIP.Pickdetailkey
       
       SELECT @n_cnt = @@ROWCOUNT
       SET ROWCOUNT 0
       
       IF @n_cnt = 0
           BREAK
       
       IF @n_PickQty <= @n_ReplenQty
       BEGIN
          UPDATE PICKDETAIL_WIP WITH (ROWLOCK)
          SET Taskdetailkey = @c_TaskdetailKey,
              TrafficCop = NULL
          WHERE Pickdetailkey = @c_PickdetailKey
          SELECT @n_err = @@ERROR
          IF @n_err <> 0 
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82110   
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (ispRLWAV09)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             BREAK
         END 
         SELECT @n_ReplenQty = @n_ReplenQty - @n_PickQty
       END
       ELSE
       BEGIN  -- pickqty > replenqty   
          SELECT @n_SplitQty = @n_PickQty - @n_ReplenQty
          EXECUTE nspg_GetKey      
          'PICKDETAILKEY',      
          10,      
          @c_NewPickdetailKey OUTPUT,         
          @b_success OUTPUT,      
          @n_err OUTPUT,      
          @c_errmsg OUTPUT      
          IF NOT @b_success = 1      
          BEGIN
             SELECT @n_continue = 3      
             BREAK      
          END      
                
          INSERT PICKDETAIL_WIP      
                 (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                  Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],       
                  DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                  WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, 
                  TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey)      
          SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                 Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                 '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                 ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                 WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,
                 TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey                 
          FROM PICKDETAIL_WIP (NOLOCK)
          WHERE PickdetailKey = @c_PickdetailKey
                             
          SELECT @n_err = @@ERROR
          IF @n_err <> 0     
          BEGIN     
             SELECT @n_continue = 3      
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82120   
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV09)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             BREAK    
          END
          
          UPDATE PICKDETAIL_WIP WITH (ROWLOCK)
          SET Taskdetailkey = @c_TaskdetailKey,
             Qty = @n_ReplenQty,
             UOMQTY = CASE UOM WHEN '6' THEN @n_ReplenQty ELSE UOMQty END,            
             TrafficCop = NULL
          WHERE Pickdetailkey = @c_PickdetailKey
          SELECT @n_err = @@ERROR
          IF @n_err <> 0 
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82130   
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV09)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             BREAK
          END
          SELECT @n_ReplenQty = 0
       END     
     END -- While Qty > 0
 END        

 --return back to calling point
 GOTO RTN_INSERT_TASKS
*/

 --------------------Function to find MEZZANINE Loc---------------------     
 FIND_MEZ_LOC:

 SET @c_MEZLoc = ''

  -- Assign loc with same sku qty already assigned in current replenishment
 IF ISNULL(@c_MEZLoc,'')=''
 BEGIN
     SELECT TOP 1 @c_MEZLoc = DL.ToLoc
     FROM #MEZZANINE_LOCASSIGNED DL
     JOIN LOC (NOLOCK) ON LOC.Loc = DL.ToLoc
     WHERE DL.Storerkey = @c_Storerkey
     AND DL.Sku = @c_Sku
     AND DATEDIFF(day, DL.Lottable04, @dt_Lottable04) = 0
     ORDER BY LOC.LogicalLocation, DL.ToLoc
 END

  -- Assign loc with same sku & lottable04 already assigned in other wave replenishment 
 /* --NJOW01
 IF ISNULL(@c_MEZLoc,'')=''
 BEGIN   
      SELECT TOP 1 @c_MEZLoc = TD.ToLoc 
     FROM TASKDETAIL TD (NOLOCK)
     JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot
     JOIN LOC L (NOLOCK) ON TD.Toloc = L.Loc
     WHERE TD.TaskType = 'RPF'
     AND TD.SourceType = @c_SourceType
     AND TD.Storerkey = @c_Storerkey
     AND TD.Sku = @C_sKU
     AND TD.Status = '0'
     AND TD.Qty > 0
     AND DATEDIFF(day, LA.Lottable04, @dt_Lottable04) = 0
     ORDER BY L.LogicalLocation, TD.ToLoc
 END
 */

  -- Assign loc with same sku, lottable04, qty available / pending move in
 IF ISNULL(@c_MEZLoc,'')=''
 BEGIN
     SELECT TOP 1 @c_MEZLoc = L.LOC
     FROM LOTxLOCxID LLI (NOLOCK)
     JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
     JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC
     WHERE L.LocationType = 'OTHER' 
     AND L.LocationCategory = 'MEZZANINE'
     AND   L.Facility = @c_Facility
     --AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0
     --AND (LLI.Qty + LLI.PendingMoveIN + LLI.QtyExpected) > 0
     AND LLI.Qty + LLI.QtyExpected > 0 --NJOW01
     AND  LLI.Storerkey = @c_Storerkey
     AND  LLI.Sku = @c_Sku
     AND DATEDIFF(day, LA.Lottable04, @dt_Lottable04) = 0
     ORDER BY LLI.Qty, L.LogicalLocation, L.Loc
 END

 -- If no location with same sku found, then assign the empty location
 IF ISNULL(@c_MEZLoc,'')=''
 BEGIN
     SELECT TOP 1 @c_MEZLoc = L.LOC
     FROM   LOC L (NOLOCK)
     WHERE  L.LocationType = 'OTHER'
     AND    L.LocationCategory = 'MEZZANINE'
     AND    L.Facility = @c_Facility
     AND    NOT EXISTS(
                SELECT 1
                FROM   #MEZZANINE_NON_EMPTY E
                WHERE  E.LOC = L.LOC
            ) AND
            NOT EXISTS(
                SELECT 1
                FROM   #MEZZANINE_TASK AS ReplenLoc
                WHERE  ReplenLoc.TOLOC = L.LOC
            ) AND
            NOT EXISTS(
                SELECT 1
                FROM   #MEZZANINE_LOCASSIGNED AS DynPick
                WHERE  DynPick.ToLoc = L.LOC
            )
     ORDER BY L.LogicalLocation, L.Loc
 END

 IF @n_debug = 1
    SELECT '@c_MEZLoc', @c_MEZLoc

 -- Terminate. Can't find any dynamic location
 IF ISNULL(@c_MEZLoc,'')=''
 BEGIN
    SELECT @n_continue = 3  
    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
    SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': MEZZANINE Location Not Setup / Not enough MEZZANINE Location. (ispRLWAV09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '       
    GOTO RETURN_SP
 END

 SELECT @c_ToLoc = @c_MEZLoc

 --Insert current location assigned
 IF NOT EXISTS (SELECT 1 FROM #MEZZANINE_LOCASSIGNED
                WHERE Storerkey = @c_Storerkey
                AND Sku = @c_Sku
                AND ToLoc = @c_ToLoc
                AND DATEDIFF(day, Lottable04, @dt_Lottable04) = 0)
 BEGIN
    INSERT INTO #MEZZANINE_LOCASSIGNED (Storerkey, Sku, ToLoc, Lottable04)
    VALUES (@c_Storerkey, @c_Sku, @c_Toloc, @dt_Lottable04)
 END

 GOTO RTN_FIND_MEZ_LOC    
      
 END --sp end

GO