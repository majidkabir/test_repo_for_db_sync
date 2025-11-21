SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLWAV23                                          */  
/* Creation Date: 27-Feb-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-8017 - CN Fabory release task                            */
/*                                                                       */
/*                                                                       */  
/* Called By: Wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.1                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver  Purposes                                    */  
/* 01-04-2020  Wan01    1.1   Sync Exceed & SCE                          */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV23]      
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

    DECLARE @c_Storerkey            NVARCHAR(15)
            ,@c_Facility            NVARCHAR(5)
            ,@c_TaskType            NVARCHAR(10)            
            ,@c_SourceType          NVARCHAR(30)
            ,@c_Sku                 NVARCHAR(20)
            ,@c_Lot                 NVARCHAR(10)
            ,@c_FromLoc             NVARCHAR(10)
            ,@c_ID                  NVARCHAR(18)
            ,@n_Qty                 INT
            ,@c_UOM                 NVARCHAR(10)
            ,@n_UOMQty              INT
            ,@c_Orderkey            NVARCHAR(10)
            ,@c_Toloc               NVARCHAR(10)                                    
            ,@c_Toloc_C             NVARCHAR(10)  --Case                                    
            ,@c_Toloc_P             NVARCHAR(10)  --pallet                                  
            ,@c_Toloc_E             NVARCHAR(10)  --Each                                
            ,@c_Priority            NVARCHAR(10)            
            ,@c_PickMethod          NVARCHAR(10)            
            ,@c_Message01           NVARCHAR(20)
            ,@c_LinkTaskToPick_SQL  NVARCHAR(4000)
            ,@c_PickCondition_SQL   NVARCHAR(4000) 
            ,@c_SQL                 NVARCHAR(MAX)
            ,@c_SourcePriority      NVARCHAR(10)
            ,@c_Lottable02          NVARCHAR(18)
            ,@n_UCCQty              INT
            ,@n_LastPartial_Ctn     INT
            ,@c_Loadkey             NVARCHAR(10)
                            
    SET @c_SourceType = 'ispRLWAV23'    
    
    -----Wave Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype = @c_Tasktype
                      WHERE WD.Wavekey = @c_Wavekey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV23)'       
       END      
    END
       
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                  WHERE TD.Wavekey = @c_Wavekey
                  AND TD.Sourcetype = @c_SourceType
                  AND TD.Tasktype IN ('FPK','FCP'))
       BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83010    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV23)'       
       END                 
    END   
    
    --Create pickdetail Work in progress temporary table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       CREATE TABLE #PickDetail_WIP(
          [PickDetailKey] [nvarchar](18) NOT NULL PRIMARY KEY,
          [CaseID] [nvarchar](20) NOT NULL DEFAULT (' '),
          [PickHeaderKey] [nvarchar](18) NOT NULL,
          [OrderKey] [nvarchar](10) NOT NULL,
          [OrderLineNumber] [nvarchar](5) NOT NULL,
          [Lot] [nvarchar](10) NOT NULL,
          [Storerkey] [nvarchar](15) NOT NULL,
          [Sku] [nvarchar](20) NOT NULL,
          [AltSku] [nvarchar](20) NOT NULL DEFAULT (' '),
          [UOM] [nvarchar](10) NOT NULL DEFAULT (' '),
          [UOMQty] [int] NOT NULL DEFAULT ((0)),
          [Qty] [int] NOT NULL DEFAULT ((0)),
          [QtyMoved] [int] NOT NULL DEFAULT ((0)),
          [Status] [nvarchar](10) NOT NULL DEFAULT ('0'),
          [DropID] [nvarchar](20) NOT NULL DEFAULT (''),
          [Loc] [nvarchar](10) NOT NULL DEFAULT ('UNKNOWN'),
          [ID] [nvarchar](18) NOT NULL DEFAULT (' '),
          [PackKey] [nvarchar](10) NULL DEFAULT (' '),
          [UpdateSource] [nvarchar](10) NULL DEFAULT ('0'),
          [CartonGroup] [nvarchar](10) NULL,
          [CartonType] [nvarchar](10) NULL,
          [ToLoc] [nvarchar](10) NULL  DEFAULT (' '),
          [DoReplenish] [nvarchar](1) NULL DEFAULT ('N'),
          [ReplenishZone] [nvarchar](10) NULL DEFAULT (' '),
          [DoCartonize] [nvarchar](1) NULL DEFAULT ('N'),
          [PickMethod] [nvarchar](1) NOT NULL DEFAULT (' '),
          [WaveKey] [nvarchar](10) NOT NULL DEFAULT (' '),
          [EffectiveDate] [datetime] NOT NULL DEFAULT (getdate()),
          [AddDate] [datetime] NOT NULL DEFAULT (getdate()),
          [AddWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
          [EditDate] [datetime] NOT NULL DEFAULT (getdate()),
          [EditWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
          [TrafficCop] [nvarchar](1) NULL,
          [ArchiveCop] [nvarchar](1) NULL,
          [OptimizeCop] [nvarchar](1) NULL,
          [ShipFlag] [nvarchar](1) NULL DEFAULT ('0'),
          [PickSlipNo] [nvarchar](10) NULL,
          [TaskDetailKey] [nvarchar](10) NULL,
          [TaskManagerReasonKey] [nvarchar](10) NULL,
          [Notes] [nvarchar](4000) NULL,
          [MoveRefKey] [nvarchar](10) NULL DEFAULT (''),
          [WIP_Refno] [nvarchar](30) NULL DEFAULT (''),
          [Channel_ID] [bigint] NULL DEFAULT ((0)))      
    END
          
    IF @@TRANCOUNT = 0
       BEGIN TRAN
                    
    -----Get Storerkey and facility
    IF (@n_continue = 1 OR @n_continue = 2)
    BEGIN
       SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                    @c_Facility = O.Facility,
                    @c_ToLoc_P = ISNULL(LOCP.Loc,''),
                    @c_ToLoc_C = ISNULL(LOCC.Loc,''),
                    @c_ToLoc_E = ISNULL(LOCE.Loc,'')                                        
       FROM WAVE W (NOLOCK)
       JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
       JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
       LEFT JOIN CODELKUP CLP (NOLOCK) ON W.DispatchPalletPickMethod = CLP.Code AND CLP.Listname = 'DICSEPKMTD'
       LEFT JOIN CODELKUP CLC (NOLOCK) ON W.DispatchCasePickMethod = CLC.Code AND CLC.Listname = 'DICSEPKMTD'
       LEFT JOIN CODELKUP CLE (NOLOCK) ON W.DispatchPiecePickMethod = CLE.Code AND CLE.Listname = 'DIPCEPKMTD'
       LEFT JOIN LOC LOCP (NOLOCK) ON CLP.Short = LOCP.Loc
       LEFT JOIN LOC LOCC (NOLOCK) ON CLC.Short = LOCC.Loc
       LEFT JOIN LOC LOCE (NOLOCK) ON CLE.Short = LOCE.Loc
       WHERE W.Wavekey = @c_Wavekey      

       IF ISNULL(@c_ToLoc_P,'') = ''            
       BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83010    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Location Setup for pallet picking. (ispRLWAV23)'       
       END
       ELSE IF ISNULL(@c_ToLoc_C,'') = ''            
       BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83010    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Location Setup for case picking. (ispRLWAV23)'       
       END                                      
    END    
        
    --Initialize Pickdetail work in progress staging table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
           ,@c_Wavekey               = @c_wavekey  
           ,@c_WIP_RefNo             = @c_SourceType 
           ,@c_PickCondition_SQL     = ''
           ,@c_Action                = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
           ,@c_RemoveTaskdetailkey   = 'Y'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT 
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
        IF @b_Success <> 1
        BEGIN
           SET @n_continue = 3
        END          
    END
    
    --Create full pallet pick task for modulized & none modulized sku
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       SET @c_Message01 = ''
       SET @c_PickCondition_SQL = 'AND PICKDETAIL.UOM = ''1'' AND LOC.LocationType = ''OTHER'' AND SKUXLOC.LocationType NOT IN (''PICK'',''CASE'')'         
       SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM AND ORDERS.Loadkey = @c_Loadkey '
       SET @c_PickMethod = 'FP'
       SET @c_Priority = '8'
       SET @c_SourcePriority = '8'
       SET @c_TaskType = 'FPK'
       SET @c_ToLoc = @c_Toloc_P
             
       EXEC isp_CreateTaskByPick
            @c_TaskType              = @c_TaskType
           ,@c_Wavekey               = @c_Wavekey  
           ,@c_ToLoc                 = @c_ToLoc       
           ,@c_ToLoc_Strategy        = ''
           ,@c_PickMethod            = @c_PickMethod   -- ?=Auto determine FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  ?ROUNDUP=Qty available - (qty - systemqty)
           ,@c_Priority              = @c_Priority      
           ,@c_SourcePriority        = @c_SourcePriority           
           ,@c_Message01             = @c_Message01       
           ,@c_SourceType            = @c_SourceType      
           ,@c_SourceKey             = @c_Wavekey         
           ,@c_CallSource            = 'WAVE' -- WAVE / LOADPLAN 
           ,@c_PickCondition_SQL     = @c_PickCondition_SQL   -- Additional condition to filter pickdetail. e.g. AND PICKDETAIL.UOM='2' AND LOC.LoctionType = 'OTHER'
           ,@c_LinkTaskToPick        = 'WIP'    -- N=No update taskdetailkey to pickdetail Y=Update taskdetailkey to pickdetail  WIP=Update taskdetailkey to pickdetail_wip
           ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL   -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY
           ,@c_ReserveQtyReplen      = 'N'    -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
           ,@c_ReservePendingMoveIn  = 'N'    -- N=No update @n_qty to @n_PendingMoveIn Y=Update @n_qty to @n_PendingMoveIn           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
           ,@c_RoundUpQty            = 'N'    -- FC=Round up qty to full carton by packkey/ucc FP=Round up qty to full pallet by packkey/ucc  FL=Round up to full location qty
           ,@c_SplitTaskByCase       = 'N'    -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
           ,@c_ZeroSystemQty         = 'N'    -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.
           ,@c_SplitTaskByOrder      = 'N'    -- N=No slip by order Y=Split TASK by Order.            
           ,@c_SplitTaskByLoad       = 'Y'    -- N=No slip by load Y=Split TASK by load. Usually applicaple when create task by wave.
           ,@c_TaskIgnoreLot         = 'Y'    -- N=Task with lot  Y=Task ignore lot  
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT        
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
       IF @b_Success <> 1
       BEGIN
          SET @n_continue = 3
       END                                
    END
    
    --Create full case pick for modulized sku (non-modulize sku will not have case allocation)
    IF @n_continue IN(1,2) 
    BEGIN
       SET @c_SQL = '
       DECLARE cur_pick CURSOR FAST_FORWARD READ_ONLY FOR  
          SELECT PD.Storerkey, PD.Sku, MAX(PD.Lot), PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,  
                 PD.UOM, SUM(PD.UOMQty) AS UOMQty, ISNULL(UCC.Qty,0), LA.Lottable02, ISNULL(O.Loadkey,'''')
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
          JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey
          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
          OUTER APPLY (SELECT MAX(UCC.Qty) AS Qty FROM UCC (NOLOCK)
                       JOIN LOTATTRIBUTE (NOLOCK) ON UCC.Lot = LOTATTRIBUTE.Lot 
                       WHERE UCC.Storerkey = PD.Storerkey AND UCC.Sku = PD.Sku AND LOTATTRIBUTE.Lottable02 = LA.Lottable02 AND LOTATTRIBUTE.Lottable02 <> '''') AS UCC           
          WHERE WD.Wavekey = @c_Wavekey
          AND PD.Status = ''0''
          AND PD.WIP_RefNo = @c_SourceType
          AND SKU.Busr1 = ''Y''
          AND PD.UOM = ''2''          
          GROUP BY PD.Storerkey, PD.Sku, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation, ISNULL(UCC.Qty,0), LA.Lottable02, ISNULL(O.Loadkey,'''')
          ORDER BY Loc.LogicalLocation, PD.Loc '       

       EXEC sp_executesql @c_SQL,
          N'@c_Wavekey NVARCHAR(10), @c_SourceType NVARCHAR(30)', 
          @c_Wavekey,
          @c_SourceType   
             
       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @n_UCCQty, @c_Lottable02, @c_Loadkey
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN                                           
           IF @c_UOM = '2'
           BEGIN
              IF ISNULL(@n_UCCQty,0) = 0
              BEGIN          
                 SELECT @n_continue = 3  
                 SELECT @n_err = 83010    
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UCC Qty not found for Sku: ' + RTRIM(@c_Sku) + ' Loc: ' + RTRIM(@c_FromLoc) + ' Lottable02: ' + RTRIM(@c_Lottable02) + '. (ispRLWAV23)'
                 GOTO NEXT_REC
              END       

              SET @c_TaskType = 'FCP'
              SET @c_PickMethod = 'PP'
               SET @c_Message01 = ''
              SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM AND ISNULL(ORDERS.Loadkey,'''') = @c_Loadkey '
              SET @c_Priority = '9'
              SET @c_SourcePriority = '9'
              SET @n_UOMQty = @n_UCCQty              
              SET @c_ToLoc = @c_Toloc_C
              
              SET @n_LastPartial_Ctn = @n_Qty % @n_UCCQty
              
              IF @n_LastPartial_Ctn > 0
                 SET @n_Qty = @n_Qty - @n_LastPartial_Ctn 
                             
               EXEC isp_InsertTaskDetail   
                  @c_TaskType              = @c_TaskType             
                 ,@c_Storerkey             = @c_Storerkey
                 ,@c_Sku                   = @c_Sku
                 ,@c_Lot                   = '' 
                 ,@c_UOM                   = @c_UOM      
                 ,@n_UOMQty                = @n_UOMQty     
                 ,@n_Qty                   = @n_Qty      
                 ,@c_FromLoc               = @c_Fromloc      
                 ,@c_LogicalFromLoc        = @c_FromLoc 
                 ,@c_FromID                = @c_ID     
                 ,@c_ToLoc                 = @c_ToLoc       
                 ,@c_LogicalToLoc          = @c_ToLoc 
                 ,@c_ToID                  = @c_ID       
                 ,@c_PickMethod            = @c_PickMethod
                 ,@c_Priority              = @c_Priority     
                 ,@c_SourcePriority        = @c_SourcePriority      
                 ,@c_SourceType            = @c_SourceType      
                 ,@c_SourceKey             = @c_Wavekey      
                 ,@c_OrderKey              = ''      
                 ,@c_WaveKey               = @c_Wavekey      
                 ,@c_Loadkey               = @c_Loadkey
                 ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                 ,@c_Message01             = ''
                 ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
                 ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
                 ,@c_SplitTaskByCase       ='N'   -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
                 ,@c_WIP_RefNo             = @c_SourceType
                 ,@b_Success               = @b_Success OUTPUT
                 ,@n_Err                   = @n_err OUTPUT 
                 ,@c_ErrMsg                = @c_errmsg OUTPUT        
              
              IF @b_Success <> 1 
              BEGIN
                 SELECT @n_continue = 3  
              END
              ELSE IF @n_LastPartial_Ctn > 0                                                
              BEGIN                   
                --last partial carton split to different task. every lottable02 could have last carton with partial qty. 
                  --1 pallet will not mix lottable02 but might have more than 1 lot due to diffrent receive date. only last pallet of the batch have last partial carton.
                  --every batch should have same UCC qty except last carton.                                                                    
                  EXEC isp_InsertTaskDetail   
                     @c_TaskType              = @c_TaskType             
                    ,@c_Storerkey             = @c_Storerkey
                    ,@c_Sku                   = @c_Sku
                    ,@c_Lot                   = '' 
                    ,@c_UOM                   = @c_UOM      
                    ,@n_UOMQty                = @n_LastPartial_Ctn     
                    ,@n_Qty                   = @n_LastPartial_Ctn      
                    ,@c_FromLoc               = @c_Fromloc      
                    ,@c_LogicalFromLoc        = @c_FromLoc 
                    ,@c_FromID                = @c_ID     
                    ,@c_ToLoc                 = @c_ToLoc       
                    ,@c_LogicalToLoc          = @c_ToLoc 
                    ,@c_ToID                  = @c_ID       
                    ,@c_PickMethod            = @c_PickMethod
                    ,@c_Priority              = @c_Priority     
                    ,@c_SourcePriority        = @c_SourcePriority      
                    ,@c_SourceType            = @c_SourceType      
                    ,@c_SourceKey             = @c_Wavekey      
                    ,@c_OrderKey              = ''      
                    ,@c_WaveKey               = @c_Wavekey      
                    ,@c_Loadkey               = @c_Loadkey                   
                    ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                    ,@c_Message01             = 'Last Partial Carton'
                    ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
                    ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
                    ,@c_SplitTaskByCase       ='N'   -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
                    ,@c_WIP_RefNo             = @c_SourceType
                    ,@b_Success               = @b_Success OUTPUT
                    ,@n_Err                   = @n_err OUTPUT 
                    ,@c_ErrMsg                = @c_errmsg OUTPUT        
                 
                 IF @b_Success <> 1 
                 BEGIN
                    SELECT @n_continue = 3  
                 END                 
              END                         
           END
          
          NEXT_REC: 
               
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @n_UCCQty, @c_Lottable02, @c_Loadkey
       END
       CLOSE cur_pick
       DEALLOCATE cur_pick       
    END

    --Create loose pick for none-modulized sku (modulized sku will not have loose allocation)
    IF @n_continue IN(1,2) 
    BEGIN
       SET @c_SQL = '
       DECLARE cur_pick CURSOR FAST_FORWARD READ_ONLY FOR  
          SELECT PD.Storerkey, PD.Sku, MAX(PD.Lot), PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,  
                 PD.UOM, CASE WHEN PD.UOM = ''3'' THEN MAX(PACK.InnerPack) ELSE SUM(PD.UOMQty) END AS UOMQty, ISNULL(O.Loadkey,'''')
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
          JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey
          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey  
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
          WHERE WD.Wavekey = @c_Wavekey
          AND PD.Status = ''0''
          AND PD.WIP_RefNo = @c_SourceType
          AND SKU.Busr1 <> ''Y''
          AND PD.UOM IN(''3'',''6'')          
          GROUP BY PD.Storerkey, PD.Sku, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation, ISNULL(O.Loadkey,'''')
          ORDER BY Loc.LogicalLocation, PD.Loc '       

       EXEC sp_executesql @c_SQL,
          N'@c_Wavekey NVARCHAR(10), @c_SourceType NVARCHAR(30)', 
          @c_Wavekey,
          @c_SourceType   
             
       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Loadkey
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN                                           
           IF @c_UOM = '6'
           BEGIN
              SET @c_TaskType = 'FCP'
              SET @c_PickMethod = 'PP'
               SET @c_Message01 = ''
              SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM AND ISNULL(ORDERS.Loadkey,'''') = @c_Loadkey '
              SET @c_Priority = '9'
              SET @c_SourcePriority = '9'
              SET @n_UOMQty = 0             
              SET @c_ToLoc = @c_Toloc_E              
                                            
               EXEC isp_InsertTaskDetail   
                  @c_TaskType              = @c_TaskType             
                 ,@c_Storerkey             = @c_Storerkey
                 ,@c_Sku                   = @c_Sku
                 ,@c_Lot                   = '' --@c_Lot
                 ,@c_UOM                   = @c_UOM      
                 ,@n_UOMQty                = @n_UOMQty     
                 ,@n_Qty                   = @n_Qty      
                 ,@c_FromLoc               = @c_Fromloc      
                 ,@c_LogicalFromLoc        = @c_FromLoc 
                 ,@c_FromID                = @c_ID     
                 ,@c_ToLoc                 = @c_ToLoc       
                 ,@c_LogicalToLoc          = @c_ToLoc 
                 ,@c_ToID                  = @c_ID       
                 ,@c_PickMethod            = @c_PickMethod
                 ,@c_Priority              = @c_Priority     
                 ,@c_SourcePriority        = @c_SourcePriority      
                 ,@c_SourceType            = @c_SourceType      
                 ,@c_SourceKey             = @c_Wavekey      
                 ,@c_OrderKey              = ''      
                 ,@c_WaveKey               = @c_Wavekey      
                 ,@c_Loadkey               = @c_Loadkey
                 ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                 ,@c_Message01             = ''
                 ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
                 ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
                 ,@c_SplitTaskByCase       ='N'   -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
                 ,@c_WIP_RefNo             = @c_SourceType
                 ,@b_Success               = @b_Success OUTPUT
                 ,@n_Err                   = @n_err OUTPUT 
                 ,@c_ErrMsg                = @c_errmsg OUTPUT        
              
              IF @b_Success <> 1 
              BEGIN
                 SELECT @n_continue = 3  
              END             
           END
                         
           FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Loadkey
       END
       CLOSE cur_pick
       DEALLOCATE cur_pick       
    END
    
                     
    -----Update pickdetail_WIP work in progress staging table back to pickdetail 
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
       EXEC isp_CreatePickdetail_WIP
             @c_Loadkey               = ''
            ,@c_Wavekey               = @c_wavekey  
            ,@c_WIP_RefNo             = @c_SourceType 
            ,@c_PickCondition_SQL     = ''
            ,@c_Action                = 'U'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
            ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
            ,@b_Success               = @b_Success OUTPUT
            ,@n_Err                   = @n_Err     OUTPUT 
            ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
       IF @b_Success <> 1
       BEGIN
          SET @n_continue = 3
       END             
    END
      
    -----Generate Pickslip No------    
    /*IF @n_continue = 1 or @n_continue = 2 
    BEGIN
       IF dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AutoScanIn') = '1' 
       BEGIN    
          EXEC isp_CreatePickSlip
               @c_Wavekey = @c_Wavekey
              ,@c_LinkPickSlipToPick = 'N'  --Y=Update pickslipno to pickdetail.pickslipno 
              ,@c_ConsolidateByLoad = 'N'
              ,@c_AutoScanIn = 'Y'   --Y=Auto scan in the pickslip N=Not auto scan in   
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_err OUTPUT 
              ,@c_ErrMsg = @c_errmsg OUTPUT        
          
          IF @b_Success = 0
             SELECT @n_continue = 3
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV23)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
   
RETURN_SP:

    -----Delete pickdetail_WIP work in progress staging table
    IF @n_continue IN (1,2)
    BEGIN
       EXEC isp_CreatePickdetail_WIP
             @c_Loadkey               = ''
            ,@c_Wavekey               = @c_wavekey  
            ,@c_WIP_RefNo             = @c_SourceType 
            ,@c_PickCondition_SQL     = ''
            ,@c_Action                = 'D'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
            ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
            ,@b_Success               = @b_Success OUTPUT
            ,@n_Err                   = @n_Err     OUTPUT 
            ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
       IF @b_Success <> 1
       BEGIN
          SET @n_continue = 3
       END             
    END
    
    IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
       DROP TABLE #PICKDETAIL_WIP

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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV23"  
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