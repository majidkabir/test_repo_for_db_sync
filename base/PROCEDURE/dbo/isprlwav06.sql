SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLWAV06                                          */  
/* Creation Date: 28-Jul-2016                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: SOS#372518 - HK Pearson - Wave Release Replenishmnt Task     */  
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver  Purposes                                    */ 
/* 01-04-2020  Wan01    2.1   Sync Exceed & SCE                          */ 
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV06]      
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
            ,@n_TakeQty INT
            ,@n_CaseCnt INT
            ,@c_Priority NVARCHAR(10)
            ,@c_Areakey NVARCHAR(10)
            ,@c_PickMethod NVARCHAR(10)
            ,@c_Toloc NVARCHAR(10)
            ,@c_Taskdetailkey NVARCHAR(10)  
            ,@c_UOM NVARCHAR(10)
            ,@c_DestinationType NVARCHAR(30)
            ,@c_SourceType NVARCHAR(30)
            ,@c_Pickdetailkey NVARCHAR(18)
            ,@c_NewPickdetailKey NVARCHAR(18)
            ,@n_Pickqty INT
            ,@n_ReplenQty INT
            ,@n_SplitQty  INT
            ,@c_Orderkey NVARCHAR(10)
            ,@c_Pickslipno NVARCHAR(10)
            ,@c_Message03 NVARCHAR(20)
            ,@c_TaskType NVARCHAR(10)
            ,@c_FPVASLoc NVARCHAR(10)
            ,@c_PPSORTLoc NVARCHAR(10)
            ,@c_GroupKey NVARCHAR(10)

    -----Wave Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = 'ispRLWAV06'  AND TD.Tasktype = 'RPF'
                      WHERE WD.Wavekey = @c_Wavekey                   
                      AND PD.Status = '0'
                      AND (TD.Status = '9' OR TD.Taskdetailkey IS NULL)                                           
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81010  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV06)'       
       END
    END

    /*    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype = 'ispRLWAV06'
                   AND TD.Tasktype = 'RPF')
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81010  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV06)'       
        END                 
    END

    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 
                  FROM WAVEDETAIL WD(NOLOCK)
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                  WHERE O.Status > '2'
                  AND WD.Wavekey = @c_Wavekey)
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81020  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking (ispRLWAV06)'         
        END                 
    END
    */
    
    -----Get Storerkey
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey = O.Storerkey
        FROM WAVEDETAIL WD(NOLOCK)
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        AND WD.Wavekey = @c_Wavekey 
    END

    --Remove taskdetailkey and add wavekey from pickdetail of the wave    
    /*
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
         UPDATE PICKDETAIL WITH (ROWLOCK) 
          SET PICKDETAIL.TaskdetailKey = '',
              PICKDETAIL.Wavekey = @c_Wavekey, 
             TrafficCop = NULL
         FROM WAVEDETAIL (NOLOCK)  
         JOIN PICKDETAIL ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey 
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END 
    END
    */
        
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN      
       --Tasktype PickMethod  UOM       From Area  To area  Description
       --RPF       FP           1         Bulk      VAS      Full pallet pick for single order(Pickdetail.Pickmethod='P')
       --RPF       FP           1(1,7) Bulk      Sort   Full pallet pick for (multi orders(1)/residual(7))              
       --RPF       PP           2(2,7) Case      Sort   Full Carton pick (single or multi orders(2) /residual(7))                            
       --RPF       PP           6         Pick      Sort   Loose pick from PP location
       
       SELECT @c_FPVASLoc = Long
       FROM CODELKUP(NOLOCK)
       WHERE Storerkey = @c_Storerkey
       AND Listname = 'PSTOLOC'
       AND Code = 'FPToLoc'
       
       IF ISNULL(@c_FPVASLoc,'') = ''
          SET @c_FPVASLoc = 'VAS01'
          
       SELECT @c_PPSORTLoc = Long
       FROM CODELKUP(NOLOCK)
       WHERE Storerkey = @c_Storerkey
       AND Listname = 'PSTOLOC'
       AND Code = 'PPToLoc'
       
       IF ISNULL(@c_PPSORTLoc,'') = ''
          SET @c_PPSORTLoc = 'SORT01'

       SET @c_SourceType = 'ispRLWAV06'    
       SET @c_TaskType = 'RPF'

       SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM,
              CASE WHEN PD.UOM = '1' OR (LOC.LocationType IN('BULK','OTHER') AND PD.UOM IN('7','6')) THEN --if partail allocate from bulk loc take full pallet
                        'FP'                          
                   ELSE 'PP' END AS PickMethod,
              CASE WHEN PD.UOM = '1' AND PD.Pickmethod = 'P' THEN 'VAS' ELSE 'SORTATION' END AS DestinationType, --if full order pallet direct to VAS
              CASE WHEN LOC.LocationType = 'CASE' AND PD.UOM IN('7','6') THEN
                      CEILING(SUM(PD.Qty) / (PACK.Casecnt * 1.00)) * PACK.Casecnt   -- convert to take full case
                   WHEN LOC.LocationType IN('BULK','OTHER') AND PD.UOM IN('7','6') THEN
                      (SELECT SUM(LLI.Qty) FROM LOTXLOCXID LLI (NOLOCK) 
                       WHERE LLI.Lot = PD.Lot AND LLI.Loc = PD.Loc AND LLI.ID = PD.ID) --convert to take full pallet
                   ELSE SUM(PD.Qty)  --UOM 2 or 6
              END AS TakeQty,
              CASE WHEN PD.UOM = '1' AND PD.Pickmethod = 'P' THEN --full order pallet
                      MIN(PD.Orderkey) 
                   ELSE @c_Wavekey
              END AS Message03,
              LOC.LocationType,
              PACK.CaseCnt,
              (SELECT SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) FROM LOTXLOCXID LLI (NOLOCK) 
               WHERE LLI.Lot = PD.Lot AND LLI.Loc = PD.Loc AND LLI.Id = PD.Id) AS QtyAvailable
       INTO #TMP_PICK              
       FROM WAVEDETAIL WD (NOLOCK)
       JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
       JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
       JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
       JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
       LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = 'ispRLWAV06'  AND TD.Tasktype = 'RPF'
       WHERE WD.Wavekey = @c_Wavekey
       AND PD.Status = '0'
       AND (TD.Status = '9' OR TD.Taskdetailkey IS NULL)                                           
       GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, LOC.LocationType, PACK.CaseCnt, PD.Pickmethod, 
                CASE WHEN PD.UOM = '1' OR (LOC.LocationType IN('BULK','OTHER') AND PD.UOM IN('7','6')) THEN 
                                 'FP'                          
                            ELSE 'PP' END,
                CASE WHEN PD.UOM = '1' AND PD.Pickmethod = 'P' THEN 'VAS' ELSE 'SORTATION' END
       ORDER BY PD.Storerkey, PD.UOM, PD.Sku, PD.Lot       

       DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT Storerkey, Sku, Lot, Loc, ID, SUM(Qty) AS Qty,             
                   CASE WHEN LocationType IN('BULK','OTHER') AND UOM IN('7','6') THEN  
                        '1'
                        WHEN LocationType = 'CASE' AND UOM IN('7','6') THEN  --conveted to full case
                        '2'
                        WHEN LocationType = 'PICK' AND UOM = '7' THEN  --converted to full pallet
                        '6'
                        ELSE UOM 
                   END AS UOM,
                   PickMethod, DestinationType, 
                   SUM(CASE WHEN (TakeQty - Qty) > QtyAvailable THEN Qty ELSE TakeQty END) AS TakeQty, --if partial allocate(uom 7) convert to full case but not enough qty then take allocate qty
                   --SUM(TakeQty) AS TakeQty, 
                   Casecnt, Message03
            FROM #TMP_PICK
            GROUP BY Storerkey, Sku, Lot, Loc, ID,
                     CASE WHEN LocationType IN('BULK','OTHER') AND UOM IN('7','6') THEN
                          '1'
                          WHEN LocationType = 'CASE' AND UOM IN('7','6') THEN 
                          '2'
                          WHEN LocationType = 'PICK' AND UOM = '7' THEN 
                          '6'
                          ELSE UOM 
                     END,
                     PickMethod, DestinationType, CaseCnt, Message03, QtyAvailable
            ORDER BY DestinationType, 6, Sku, Loc
       
       OPEN cur_pick  
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, 
                                     @c_PickMethod, @c_DestinationType, @n_TakeQty, @n_CaseCnt, @c_Message03
       
       WHILE @@FETCH_STATUS = 0  
       BEGIN   
           IF @c_DestinationType = 'VAS' 
           BEGIN
              SET @c_ToLoc = @c_FPVASLoc
              SET @c_Priority = '4'
             SET @c_Areakey = 'VAS'
             SET @c_Groupkey = ''
           END
           
           IF @c_DestinationType = 'SORTATION'
           BEGIN
              SET @c_ToLoc = @c_PPSortLoc
              SET @c_Priority = '5'
             SET @c_Areakey = 'SORTATION'
             SET @c_GroupKey = @c_Lot
           END
           
          GOTO INSERT_TASKS
          RTN_INSERT_TASKS:
               
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, 
                                        @c_PickMethod, @c_DestinationType, @n_TakeQty, @n_CaseCnt, @c_Message03
       END 
       CLOSE cur_pick  
       DEALLOCATE cur_pick                                                
    END  
          
    -----Generate Pickslip No-------
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN
       DECLARE CUR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT OrderKey   
          FROM   WAVEDETAIL (NOLOCK)  
          WHERE  Wavekey = @c_wavekey   
  
       OPEN CUR_ORDER  
  
       FETCH NEXT FROM CUR_ORDER INTO @c_Orderkey   
  
       WHILE @@FETCH_STATUS <> -1  
       BEGIN  
          SET @c_PickSlipno = ''      
          SELECT @c_PickSlipno = PickheaderKey  
          FROM   PICKHEADER (NOLOCK)  
          WHERE  OrderKey = @c_OrderKey
          --AND    Wavekey = @c_Wavekey
          --AND    Zone = '8'
                             
          -- Create Pickheader      
          IF ISNULL(@c_PickSlipno, '') = ''  
          BEGIN  
             EXECUTE nspg_GetKey   
             'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_err OUTPUT,   @c_errmsg OUTPUT      
                
             SELECT @c_Pickslipno = 'P' + @c_Pickslipno      
                        
             INSERT INTO PICKHEADER  
               (PickHeaderKey, Wavekey, Orderkey, PickType, Zone, TrafficCop)  
             VALUES  
               (@c_Pickslipno, @c_Wavekey, @c_OrderKey, '0' ,'3','')      
               
             SELECT @n_err = @@ERROR  
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (ispRLWAV06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             END  
          END 
       
          UPDATE PICKDETAIL WITH (ROWLOCK)  
          SET    PickSlipNo = @c_PickSlipNo  
                ,TrafficCop = NULL  
          WHERE  OrderKey = @c_OrderKey     
            
          SELECT @n_err = @@ERROR  
          IF @n_err <> 0  
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKDETAIL Failed (ispRLWAV06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END  
          
          /*
          IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookUp WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
          BEGIN
             INSERT INTO dbo.RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
             SELECT PickdetailKey, PickSlipNo, OrderKey, OrderLineNumber 
             FROM PICKDETAIL (NOLOCK)  
             WHERE PickSlipNo = @c_PickSlipNo  
             SELECT @n_err = @@ERROR  
             IF @n_err <> 0   
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060     
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookUp Table Failed. (ispRLWAV06)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
             END   
          END
          */        
            
          FETCH NEXT FROM CUR_ORDER INTO @c_OrderKey      
       END   
       CLOSE CUR_ORDER  
       DEALLOCATE CUR_ORDER 
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV06"  
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

 INSERT_TASKS:
 --function to insert taskdetail
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
     --,Message02  
     ,Message03
     ,Areakey
     ,Groupkey
    )  
    VALUES  
    (  
      @c_taskdetailkey  
     ,@c_TaskType --Tasktype  
     ,@c_Storerkey  
     ,@c_Sku  
     ,@c_UOM -- UOM,  
     ,@n_CaseCnt  -- UOMQty,  
     ,@n_TakeQty --replenishment qty
     ,@n_Qty  --systemqty allocated qty
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
     --,@c_DestinationType
     ,@c_Message03
     ,@c_Areakey
     ,@c_GroupKey
    )
    
    SELECT @n_err = @@ERROR  
    IF @n_err <> 0  
    BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
        GOTO RETURN_SP
    END   
 END
 
 --Update qty replen to lotxlocxid
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
     IF @n_Qty < @n_TakeQty 
     BEGIN
       UPDATE LOTXLOCXID WITH (ROWLOCK)
       SET QtyReplen = QtyReplen + (@n_TakeQty - @n_Qty)
       WHERE Lot = @c_Lot
       AND Loc = @c_FromLoc
       AND Id = @c_ID

       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
           GOTO RETURN_SP
       END   
     END
 END 
 
 --Update taskdetailkey/wavekey to pickdetail
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
     SELECT @c_Pickdetailkey = '', @n_ReplenQty = @n_Qty
     WHILE @n_ReplenQty > 0 
    BEGIN                        
       SET ROWCOUNT 1   
       
       SELECT @c_PickdetailKey = PICKDETAIL.Pickdetailkey, @n_PickQty = Qty
       FROM WAVEDETAIL (NOLOCK) 
       JOIN PICKDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
       WHERE WAVEDETAIL.Wavekey = @c_Wavekey
       AND ISNULL(PICKDETAIL.Taskdetailkey,'') = ''
       AND PICKDETAIL.Storerkey = @c_Storerkey
       AND PICKDETAIL.Sku = @c_sku
       AND PICKDETAIL.Lot = @c_Lot
       AND PICKDETAIL.Loc = @c_FromLoc
       AND PICKDETAIL.ID = @c_ID
       --AND PICKDETAIL.UOM = @c_UOM
       AND PICKDETAIL.Pickdetailkey > @c_pickdetailkey
       ORDER BY PICKDETAIL.Pickdetailkey
       
       SELECT @n_cnt = @@ROWCOUNT
       SET ROWCOUNT 0
       
       IF @n_cnt = 0
           BREAK
       
       IF @n_PickQty <= @n_ReplenQty
       BEGIN
          UPDATE PICKDETAIL WITH (ROWLOCK)
          SET Taskdetailkey = @c_TaskdetailKey,
              TrafficCop = NULL
          WHERE Pickdetailkey = @c_PickdetailKey
          SELECT @n_err = @@ERROR
          IF @n_err <> 0 
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81100   
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV06)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
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
                
          INSERT PICKDETAIL      
                 (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                  Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                  DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                  WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
          SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                 Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                 '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                 ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                 WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo
          FROM PICKDETAIL (NOLOCK)
          WHERE PickdetailKey = @c_PickdetailKey
                             
          SELECT @n_err = @@ERROR
          IF @n_err <> 0     
          BEGIN     
             SELECT @n_continue = 3      
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81110   
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV06)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             BREAK    
          END
          
          UPDATE PICKDETAIL WITH (ROWLOCK)
          SET Taskdetailkey = @c_TaskdetailKey,
             Qty = @n_ReplenQty,
             UOMQTY = CASE UOM WHEN '6' THEN @n_ReplenQty ELSE UOMQty END,            
             TrafficCop = NULL
          WHERE Pickdetailkey = @c_PickdetailKey
          SELECT @n_err = @@ERROR
          IF @n_err <> 0 
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81120   
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV06)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             BREAK
          END
          SELECT @n_ReplenQty = 0
       END     
     END -- While Qty > 0
 END        

 --return back to calling point
 GOTO RTN_INSERT_TASKS
      
 END --sp end

GO