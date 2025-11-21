SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLWAV22                                          */  
/* Creation Date: 12-Feb-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-7994 - TW SY2DC Wave release pick task                   */
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
/* Date        Author   Ver   Purposes                                   */  
/* 31-Jul-2019 NJOW01   1.0   WMS-10032 change task sequence and groupkey*/
/* 01-04-2020  Wan01    1.1   Sync Exceed & SCE                          */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV22]      
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
            ,@c_WaveType            NVARCHAR(10)
            ,@c_Sku                 NVARCHAR(20)
            ,@c_Lot                 NVARCHAR(10)
            ,@c_FromLoc             NVARCHAR(10)
            ,@c_ID                  NVARCHAR(18)
            ,@n_Qty                 INT
            ,@c_UOM                 NVARCHAR(10)
            ,@n_UOMQty              INT
            ,@c_Orderkey            NVARCHAR(10)
            --,@n_LocCnt              INT
            --,@n_LocGroupMin         INT
            ,@c_Groupkey            NVARCHAR(10)
            ,@c_Toloc               NVARCHAR(10)                                    
            ,@c_Priority            NVARCHAR(10)            
            ,@c_PickMethod          NVARCHAR(10)            
            ,@c_Message03           NVARCHAR(20)
            ,@C_Zip                 NVARCHAR(18)            
            ,@c_LinkTaskToPick_SQL  NVARCHAR(4000)
            --,@C_RELWAV19_SORT       NVARCHAR(10)
            ,@c_SQL                 NVARCHAR(MAX)
            ,@c_Route               NVARCHAR(10)
            ,@c_Taskdetailkey       NVARCHAR(10)
            ,@c_DefaultLoc          NVARCHAR(10)
            ,@dt_deliveryDate       DATETIME  --NJOW01
                            
    SET @c_SourceType = 'ispRLWAV22'    
    SET @c_Priority = '9'
    SET @c_TaskType = 'FCP'
    SET @c_PickMethod = 'PP'

    -----Wave Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype IN ('FPK','FCP','FPP')
                      WHERE WD.Wavekey = @c_Wavekey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV22)'       
       END      
    END
       
    /*IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                  WHERE TD.Wavekey = @c_Wavekey
                  AND TD.Sourcetype = @c_SourceType
                  AND TD.Tasktype IN ('FPK','FCP','FPP'))
       BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83010    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV22)'       
       END                 
    END*/   
    
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
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                     @c_Facility = O.Facility,
                     @c_WaveType = W.WaveType
        FROM WAVE W (NOLOCK)
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        AND W.Wavekey = @c_Wavekey 
        
        /*SELECT @n_LocGroupMin = CASE WHEN ISNUMERIC(Short) = 1 THEN CAST(Short AS INT) ELSE 0 END
        FROM CODELKUP (NOLOCK)
        WHERE Listname = 'TMPKGRPQTY'
        AND Storerkey = @c_Storerkey
        
        SELECT @C_RELWAV19_SORT = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'RELWAV19_SORT') 
        */
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
           ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT 
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
        IF @b_Success <> 1
        BEGIN
           SET @n_continue = 3
        END          
        
        UPDATE #PICKDETAIL_WIP
        SET #PICKDETAIL_WIP.Taskdetailkey = ''
        FROM #PICKDETAIL_WIP
        LEFT JOIN TASKDETAIL TD (NOLOCK) ON TD.Taskdetailkey = #PICKDETAIL_WIP.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype IN ('PK','FCP','FPP') AND TD.Status <> 'X' 
        WHERE TD.Taskdetailkey IS NULL
    END
    
    IF @n_continue IN(1,2) 
    BEGIN
       SELECT @c_DefaultLoc = CL.Long
       FROM CODELKUP CL (NOLOCK)
       JOIN LOC (NOLOCK) ON CL.Long = LOC.Loc
       WHERE CL.Listname = 'TM_TOLOC'
       AND CL.Storerkey = @c_Storerkey
       AND CL.Code = 'DEFAULT'
      
       SET @c_SQL = '
       DECLARE cur_pick CURSOR FAST_FORWARD READ_ONLY FOR  
          SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,  
                 PD.UOM, SUM(PD.UOMQty) AS UOMQty,
                 O.Route,
                 O.Orderkey,
                 --CASE WHEN PD.UOM NOT IN(''1'',''2'') THEN
                 --   O.Orderkey ELSE '''' END AS Orderkey, 
                 TOLOC.Loc AS ToLoc,
                 ISNULL(CL.Code,''9'') AS Priority,
                 O.DeliveryDate  --NJOW01
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
          JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype IN (''FPK'',''FCP'',''FPP'') AND TD.Status <> ''X'' --NJOW01          
          LEFT JOIN STORERSODEFAULT SSO (NOLOCK) ON SSO.Storerkey = O.Consigneekey         
          LEFT JOIN CODELKUP CL (NOLOCK) ON O.Storerkey = CL.Storerkey AND CL.Listname = ''TMPRIORITY'' AND LEFT(O.Route,1) = CL.Short          
          OUTER APPLY (SELECT TOP 1 TL.Loc FROM LOC TL (NOLOCK) WHERE TL.Putawayzone = SSO.Route) AS TOLOC
          WHERE WD.Wavekey = @c_Wavekey
          AND PD.Status = ''0''
          AND PD.WIP_RefNo = @c_SourceType
          AND TD.Taskdetailkey IS NULL  --NJOW01          
          --AND NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)
          --                WHERE TD.Wavekey = W.Wavekey
          --                AND TD.TaskType IN (''FPK'',''FCP'',''FPP'') 
          --                AND TD.Orderkey = O.Orderkey
          --                AND TD.Status <> ''X'') --NJOW01
          GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, O.Route, LOC.LogicalLocation, O.Orderkey, O.Consigneekey, TOLOC.Loc, ISNULL(CL.Code,''9''),
                   O.DeliveryDate  
                   --CASE WHEN PD.UOM NOT IN(''1'',''2'') THEN O.Orderkey ELSE '''' END,                    
                   --CASE WHEN PD.UOM NOT IN(''1'',''2'') THEN O.Consigneekey ELSE '''' END
          ORDER BY O.Route, PD.UOM, Loc.LogicalLocation, PD.Loc, PD.Sku, O.Orderkey '   --NJOW01 

          --ORDER BY ISNULL(CL.Short,''9''), O.Route, O.Consigneekey, O.Orderkey,
          --         --CASE WHEN PD.UOM NOT IN(''1'',''2'') THEN O.Consigneekey ELSE '''' END, CASE WHEN PD.UOM NOT IN(''1'',''2'') THEN O.Orderkey ELSE '''' END, 
          --         Loc.LogicalLocation, PD.Loc '       

       EXEC sp_executesql @c_SQL,
          N'@c_Wavekey NVARCHAR(10), @c_SourceType NVARCHAR(30)', 
          @c_Wavekey,
          @c_SourceType   
             
       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Route, @c_Orderkey, @c_ToLoc, @c_Priority, @dt_DeliveryDate
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN                     
          SET @c_LinkTaskToPick_SQL = '' 
            --SET @n_UOMQty = 0
          SET @c_Groupkey = ''                                  
          
          IF ISNULL(@c_DefaultLoc,'') <> ''
             SET @c_ToLoc = @c_DefaultLoc
                               
           IF ISNULL(@c_Toloc,'') = ''
           BEGIN         
              SELECT @n_continue = 3  
              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Loc setup at ROUTE. (ispRLWAV15)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
           END               

           IF @c_UOM = '1'
           BEGIN 
              SET @c_Taskdetailkey = ''
              SET @c_TaskType = 'FPK'
              SET @c_PickMethod = 'FP'
              SET @c_GroupKey = ''        
              SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND ORDERS.Orderkey = @c_Orderkey'
              
               EXEC isp_InsertTaskDetail   
                   @c_Taskdetailkey         = @c_Taskdetailkey OUTPUT
                 ,@c_TaskType              = @c_TaskType             
                 ,@c_Storerkey             = @c_Storerkey
                 ,@c_Sku                   = @c_Sku
                 ,@c_Lot                   = @c_Lot 
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
                 ,@c_SourcePriority        = '9'      
                 ,@c_SourceType            = @c_SourceType      
                 ,@c_SourceKey             = @c_Wavekey      
                 ,@c_OrderKey              = @c_Orderkey      
                 ,@c_Groupkey              = @c_Groupkey
                 ,@c_WaveKey               = @c_Wavekey      
                 ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                 ,@c_Message03             = ''
                 ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
                 ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
                 ,@c_WIP_RefNo             = @c_SourceType
                 ,@b_Success               = @b_Success OUTPUT
                 ,@n_Err                   = @n_err OUTPUT 
                 ,@c_ErrMsg                = @c_errmsg OUTPUT        
              
              IF @b_Success <> 1 
              BEGIN
                 SELECT @n_continue = 3  
              END             
              ELSE
              BEGIN
                 UPDATE TASKDETAIL WITH (ROWLOCK)
                 SET Groupkey = @c_Taskdetailkey
                 WHERE TaskDetailKey = @c_Taskdetailkey  
              END
           END
           ELSE IF @c_UOM = '2'
           BEGIN
              SET @c_TaskType = 'FCP'
              SET @c_PickMethod = '?'
              
              IF @dt_deliverydate IS NOT NULL
                SET @c_Groupkey = RTRIM(@c_Route) + SUBSTRING(CONVERT(NVARCHAR(8), @dt_deliverydate, 112),5,4)   --NJOW01
              ELSE
                SET @c_GroupKey = @c_Route
                        
              SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND ORDERS.Orderkey = @c_Orderkey'
              
               EXEC isp_InsertTaskDetail   
                  @c_TaskType              = @c_TaskType             
                 ,@c_Storerkey             = @c_Storerkey
                 ,@c_Sku                   = @c_Sku
                 ,@c_Lot                   = @c_Lot 
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
                 ,@c_SourcePriority        = '9'      
                 ,@c_SourceType            = @c_SourceType      
                 ,@c_SourceKey             = @c_Wavekey      
                 ,@c_OrderKey              = @c_Orderkey      
                 ,@c_Groupkey              = @c_Groupkey
                 ,@c_WaveKey               = @c_Wavekey      
                 ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                 ,@c_Message03             = ''
                 ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
                 ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
                 ,@c_SplitTaskByCase       ='Y'   -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
                 ,@c_WIP_RefNo             = @c_SourceType
                 ,@b_Success               = @b_Success OUTPUT
                 ,@n_Err                   = @n_err OUTPUT 
                 ,@c_ErrMsg                = @c_errmsg OUTPUT        
              
              IF @b_Success <> 1 
              BEGIN
                 SELECT @n_continue = 3  
              END                         
           END
           ELSE
           BEGIN  --UOM 6                     
              SET @c_TaskType = 'FPP'
              SET @c_PickMethod = 'PP'
              SET @c_GroupKey = @c_Orderkey        
              SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND ORDERS.Orderkey = @c_Orderkey'
              
               EXEC isp_InsertTaskDetail   
                  @c_TaskType              = @c_TaskType             
                 ,@c_Storerkey             = @c_Storerkey
                 ,@c_Sku                   = @c_Sku
                 ,@c_Lot                   = @c_Lot 
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
                 ,@c_SourcePriority        = '9'      
                 ,@c_SourceType            = @c_SourceType      
                 ,@c_SourceKey             = @c_Wavekey      
                 ,@c_OrderKey              = @c_Orderkey      
                 ,@c_Groupkey              = @c_Groupkey
                 ,@c_WaveKey               = @c_Wavekey      
                 ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                 ,@c_Message03             = ''
                 ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
                 ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
                 ,@c_WIP_RefNo             = @c_SourceType
                 ,@b_Success               = @b_Success OUTPUT
                 ,@n_Err                   = @n_err OUTPUT 
                 ,@c_ErrMsg                = @c_errmsg OUTPUT        
              
              IF @b_Success <> 1 
              BEGIN
                 SELECT @n_continue = 3  
              END                            
           END
               
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Route, @c_Orderkey, @c_ToLoc, @c_Priority, @dt_DeliveryDate
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
    IF @n_continue = 1 or @n_continue = 2 
    BEGIN
       IF dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AutoScanIn') = '1' 
       BEGIN            
          EXEC isp_CreatePickSlip
               @c_Wavekey = @c_Wavekey
              ,@c_LinkPickSlipToPick = 'N'  --Y=Update pickslipno to pickdetail.pickslipno 
              ,@c_ConsolidateByLoad = 'N'
              ,@c_AutoScanIn = 'Y'   --Y=Auto scan in the pickslip N=Not auto scan in   
              ,@c_PickslipType = '8'
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_err OUTPUT 
              ,@c_ErrMsg = @c_errmsg OUTPUT        
          
          IF @b_Success = 0
             SELECT @n_continue = 3

         --NJOW01
         DECLARE cur_waveord CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Orderkey
            FROM WAVEDETAIL (NOLOCK)
            WHERE Wavekey = @c_Wavekey             
         
         OPEN cur_waveord  
       
         FETCH NEXT FROM cur_waveord INTO @c_Orderkey
         
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN                      
              UPDATE PICKHEADER WITH (ROWLOCK)
              SET PICKHEADER.Wavekey = @c_Wavekey,
                  PICKHEADER.Trafficcop = NULL
              FROM PICKHEADER
              JOIN ORDERS (NOLOCK) ON PICKHEADER.Orderkey = ORDERS.Orderkey
              WHERE PICKHEADER.Orderkey = @c_Orderkey
                                      
            FETCH NEXT FROM cur_waveord INTO @c_Orderkey
         END       
         CLOSE cur_waveord
         DEALLOCATE cur_waveord
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV22)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV22"  
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