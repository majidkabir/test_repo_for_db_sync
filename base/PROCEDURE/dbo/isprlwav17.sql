SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLWAV17                                          */  
/* Creation Date: 20-Jul-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-5747 - CN Skechers Release Wave                          */
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
/* 13-Mar-2019 NJOW01   1.0   WMS-8274 sku not pick face skip generate   */
/*                            task                                       */
/* 01-04-2020  Wan01    1.1   Sync Exceed & SCE                          */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV17]      
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
            ,@c_Priority            NVARCHAR(10)
            ,@c_Toloc               NVARCHAR(10)
            ,@c_PickMethod          NVARCHAR(10)
            ,@c_Message03           NVARCHAR(20)
            ,@c_PickCondition_SQL   NVARCHAR(4000)
            ,@c_LinkTaskToPick_SQL  NVARCHAR(4000)
            ,@c_ToLoc_Strategy      NVARCHAR(30)
            ,@c_ToLoc_StrategyParam NVARCHAR(4000)
                            
    SET @c_SourceType = 'ispRLWAV17'    
    SET @c_Priority = '9'
    SET @c_TaskType = 'RPF'
    SET @c_PickMethod = 'PP'

    -----Wave Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype IN('RPF')
                      WHERE WD.Wavekey = @c_Wavekey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV17)'       
       END      
    END
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype = @c_SourceType
                   AND TD.Tasktype IN('RPF'))
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83010    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV17)'       
        END                 
    END
          
    IF @@TRANCOUNT = 0
       BEGIN TRAN
                    
    -----Get Storerkey, facility and order group
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                     @c_Facility = O.Facility
        FROM WAVE W (NOLOCK)
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        AND W.Wavekey = @c_Wavekey 
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

       CREATE INDEX PDWIP_Pickdetailkey ON #PickDetail_WIP (Pickdetailkey) 
       CREATE INDEX PDWIP_SKU ON #PickDetail_WIP (Storerkey, Sku)    
       CREATE INDEX PDWIP_UOM ON #PickDetail_WIP (UOM) 
       CREATE INDEX PDWIP_LLI ON #PickDetail_WIP (Lot, Loc, ID)           
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
  
    --Full carton to packstation
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       SET @c_ToLoc = ''
       SET @c_ToLoc_Strategy = '' 
       SET @c_Message03 = 'PACKSTATION'
       SET @c_PickCondition_SQL = 'AND PICKDETAIL.UOM = ''2'' AND LOC.LocationType NOT IN(''PICK'',''DYNPPICK'') AND SKUXLOC.LocationType <> ''PICK'' AND ISNULL(SKU.Busr7,'''') <> ''NOPICKLOC'' ' --NJOW01         
       SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM'
       
       SELECT TOP 1 @c_ToLoc = Short
       FROM CODELKUP (NOLOCK)
       WHERE Listname = 'SKEB2B'
       AND Code = @c_Facility
       
       IF ISNULL(@c_Toloc,'') = ''
          SET @c_ToLoc = 'SKEPKSTG'
       
       EXEC isp_CreateTaskByPick
            @c_TaskType              = @c_TaskType
           ,@c_Wavekey               = @c_Wavekey  
           ,@c_ToLoc                 = @c_ToLoc       
           ,@c_ToLoc_Strategy        = @c_ToLoc_Strategy
           ,@c_PickMethod            = @c_PickMethod   -- ?=Auto determine FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  ?ROUNDUP=Qty available - (qty - systemqty)
           ,@c_Priority              = @c_Priority      
           ,@c_Message03             = @c_Message03       
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
           ,@c_SplitTaskByCase       = 'Y'    -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
           ,@c_ZeroSystemQty         = 'N'    -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT        
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
       IF @b_Success <> 1
       BEGIN
          SET @n_continue = 3
       END                                
    END

    --piece from bulk to pick. pick as full carton.
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN       
       SET @c_ToLoc = ''
       SET @c_ToLoc_Strategy = 'PICK' -- PICK=Auto get the pick location of the sku.
       SET @c_Message03 = 'PICKLOC'
       SET @c_PickCondition_SQL = 'AND PICKDETAIL.UOM = ''7'' AND LOC.LocationType NOT IN(''PICK'',''DYNPPICK'') AND SKUXLOC.LocationType <> ''PICK'' AND ISNULL(SKU.Busr7,'''') <> ''NOPICKLOC'' '     --NJOW01
       SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM'
             
       EXEC isp_CreateTaskByPick
            @c_TaskType              = @c_TaskType
           ,@c_Wavekey               = @c_Wavekey  
           ,@c_ToLoc                 = @c_ToLoc 
           ,@c_ToLoc_Strategy        = @c_ToLoc_Strategy
           ,@c_PickMethod            = @c_PickMethod   -- ?=Auto determine FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  ?ROUNDUP=Qty available - (qty - systemqty)
           ,@c_Priority              = @c_Priority      
           ,@c_Message03             = @c_Message03   
           ,@c_SourceType            = @c_SourceType      
           ,@c_SourceKey             = @c_Wavekey         
           ,@c_CallSource            = 'WAVE' -- WAVE / LOADPLAN 
           ,@c_PickCondition_SQL     = @c_PickCondition_SQL  -- Additional condition to filter pickdetail. e.g. AND PICKDETAIL.UOM='2' AND LOC.LoctionType = 'OTHER'
           ,@c_LinkTaskToPick        = 'WIP'    -- N=No update taskdetailkey to pickdetail Y=Update taskdetailkey to pickdetail  WIP=Update taskdetailkey to pickdetail_wip
           ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL     -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY
           ,@c_ReserveQtyReplen      = 'ROUNDUP'    -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
           ,@c_ReservePendingMoveIn  = 'Y'    -- N=No update @n_qty to @n_PendingMoveIn Y=Update @n_qty to @n_PendingMoveIn           
           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
           ,@c_RoundUpQty            = 'FC'             -- FC=Round up qty to full carton by packkey/ucc FP=Round up qty to full pallet by packkey/ucc  FL=Round up to full location qty
           ,@c_SplitTaskByCase       = 'Y'              -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
           ,@c_ZeroSystemQty         = 'N'              -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT        
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
       IF @b_Success <> 1
       BEGIN
          SET @n_continue = 3
       END                                
    END
    
    --conso carton from bulk to DPP. 
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN       
       SET @c_ToLoc = ''
       SET @c_ToLoc_Strategy = 'ispToLoc_DynamicLoc' 
       SET @c_ToLoc_StrategyParam = '@c_MaxCasePerLoc=3' 
       SET @c_Message03 = 'DP'
       SET @c_PickCondition_SQL = 'AND PICKDETAIL.UOM = ''6'' AND LOC.LocationType NOT IN(''PICK'',''DYNPPICK'') AND SKUXLOC.LocationType <> ''PICK'' AND ISNULL(SKU.Busr7,'''') <> ''NOPICKLOC'' ' --NJOW01          
       SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM'
             
       EXEC isp_CreateTaskByPick
            @c_TaskType              = @c_TaskType
           ,@c_Wavekey               = @c_Wavekey  
           ,@c_ToLoc                 = @c_ToLoc
           ,@c_ToLoc_Strategy        = @c_ToLoc_Strategy
           ,@c_ToLoc_StrategyParam   = @c_ToLoc_StrategyParam
           ,@c_PickMethod            = @c_PickMethod  -- ?=Auto determine FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  ?ROUNDUP=Qty available - (qty - systemqty)
           ,@c_Priority              = @c_Priority      
           ,@c_Message03             = @c_Message03     
           ,@c_SourceType            = @c_SourceType      
           ,@c_SourceKey             = @c_Wavekey         
           ,@c_CallSource            = 'WAVE' -- WAVE / LOADPLAN 
           ,@c_PickCondition_SQL     = @c_PickCondition_SQL -- Additional condition to filter pickdetail. e.g. AND PICKDETAIL.UOM='2' AND LOC.LoctionType = 'OTHER'
           ,@c_LinkTaskToPick        = 'WIP'    -- N=No update taskdetailkey to pickdetail Y=Update taskdetailkey to pickdetail  WIP=Update taskdetailkey to pickdetail_wip
           ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL   -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY
           ,@c_ReserveQtyReplen      = 'N'    -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
           ,@c_ReservePendingMoveIn  = 'Y'    -- N=No update @n_qty to @n_PendingMoveIn Y=Update @n_qty to @n_PendingMoveIn           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
           ,@c_WIP_RefNo             = @c_SourceType  -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
           ,@c_RoundUpQty            = 'N'            -- FC=Round up qty to full carton by packkey/ucc FP=Round up qty to full pallet by packkey/ucc  FL=Round up to full location qty
           ,@c_SplitTaskByCase       = 'Y'            -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
           ,@c_ZeroSystemQty         = 'N'            -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT        
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
       IF @b_Success <> 1
       BEGIN
          SET @n_continue = 3
       END                                
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
       EXEC isp_CreatePickSlip
            @c_Wavekey = @c_Wavekey
           ,@c_ConsolidateByLoad = 'Y'
           ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
           ,@c_AutoScanIn = 'Y'  --Y=Auto scan in the pickslip N=Not auto scan in     
           ,@b_Success = @b_Success OUTPUT
           ,@n_Err = @n_err OUTPUT 
           ,@c_ErrMsg = @c_errmsg OUTPUT        
       
       IF @b_Success = 0
          SELECT @n_continue = 3    
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV17)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
   
RETURN_SP:
    -----Delete pickdetail_WIP work in progress staging table
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV17"  
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