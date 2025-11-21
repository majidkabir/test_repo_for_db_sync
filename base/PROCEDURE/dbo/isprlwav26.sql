SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLWAV26                                          */  
/* Creation Date: 09-May-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-8760 - BBGCN Release Wave                                */
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.2                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/* 2020-04-03  WLChooi  1.1   Add LLI.Qty > 0, tally with CNWMS Prod ver.*/
/*                            (WL01)                                     */
/* 01-04-2020  Wan01    1.2   Sync Exceed & SCE                          */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV26]      
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
            ,@c_DropID              NVARCHAR(20)
            ,@n_QtyShort            INT
            ,@n_QtyAvailable        INT
            ,@n_QtyReplen           INT
            ,@c_Sku                 NVARCHAR(20)
            ,@c_Lot                 NVARCHAR(10)
            ,@c_FromLoc             NVARCHAR(10)
            ,@c_ID                  NVARCHAR(18)
            ,@c_ToID                NVARCHAR(18)
            ,@n_Qty                 INT
            ,@c_Orderkey            NVARCHAR(10)
            ,@n_CaseCnt             INT
            ,@c_UOM                 NVARCHAR(10)
            ,@n_UOMQty              INT
            ,@c_SourcePriority      NVARCHAR(10)
            ,@n_TotCtn              INT
            ,@n_InsertQty           INT
            ,@c_UCCNo               NVARCHAR(20)
            ,@d_Lottable05          DATETIME
                      
    SET @c_SourceType = 'ispRLWAV26'    
    SET @c_Priority = '9'
    SET @c_TaskType = 'RPF'
    SET @c_PickMethod = 'PP'
    
    CREATE TABLE #TEMP_LOADKEY(
    Orderkey      NVARCHAR(20) NULL,
    Loadkey       NVARCHAR(20) NULL )

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
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV26)'       
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
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV26)'       
        END                 
    END
    
    --Check if all the orderkey in the wave have loadkey
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       INSERT INTO #TEMP_LOADKEY
       SELECT O.Orderkey, ISNULL(O.Loadkey,'')
       FROM WAVE W (NOLOCK)
       JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
       JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
       AND W.Wavekey = @c_Wavekey 
       
       IF EXISTS (SELECT 1 FROM #TEMP_LOADKEY WHERE LOADKEY = '')
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83020   
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some orderkey in the wave do not have loadkey. (ispRLWAV26)'   
       END
    END
          
    IF @@TRANCOUNT = 0
       BEGIN TRAN
                    
    -----Get Storerkey, facility, ToLoc
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                     @c_Facility = O.Facility   
        FROM WAVE W (NOLOCK)
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        AND W.Wavekey = @c_Wavekey 

        SELECT TOP 1 @c_ToLoc = LTRIM(RTRIM(ISNULL(CL.SHORT,'')))
        FROM CODELKUP CL (NOLOCK)
        WHERE CL.LISTNAME = 'BRLOC' AND CL.STORERKEY = @c_Storerkey AND CL.CODE = 'PACK'
        AND CL.Code2 = @c_Facility

        IF (@c_ToLoc = '' OR @c_ToLoc = NULL)
        BEGIN 
           SELECT @n_continue = 3  
           SELECT @n_err = 83030  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ToLoc is not set-up in Codelkup. (ispRLWAV26)' 
        END
        
        IF NOT EXISTS(SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_ToLoc)
        BEGIN 
           SELECT @n_continue = 3  
           SELECT @n_err = 83040  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ToLoc is not found in Loc table. (ispRLWAV26)' 
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
  
    --Create full case pick to Packstation (UOM = 2)
    IF @n_continue IN(1,2) 
    BEGIN
       DECLARE cur_pick CURSOR FAST_FORWARD READ_ONLY FOR  
          SELECT PD.Storerkey, PD.Sku, MAX(PD.Lot) AS Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,  
                 PD.UOM, SUM(PD.UOMQty) AS UOMQty, PD.DropID
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
          JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey
          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc   
          WHERE WD.Wavekey = @c_Wavekey
          AND PD.Status = '0'
          AND PD.WIP_RefNo = @c_SourceType
          AND PD.UOM = '2'         
          GROUP BY PD.Storerkey, PD.Sku, PD.Loc, PD.ID, PD.UOM, PD.DropID, LOC.LogicalLocation
          ORDER BY Qty, Loc.LogicalLocation, PD.Loc        

       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_DropID
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN                                           
           IF @c_UOM = '2'
           BEGIN
              SET @c_TaskType = 'RPF'
              SET @c_PickMethod = 'PP'
              SET @c_Message03 = 'PACKSTATION'
              SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM '
              SET @c_Priority = '8'
              SET @c_SourcePriority = '9'
              
              EXEC isp_InsertTaskDetail   
                  @c_TaskType              = @c_TaskType             
                 ,@c_Storerkey             = @c_Storerkey
                 ,@c_Sku                   = @c_Sku
                 ,@c_Lot                   = @c_Lot
                 ,@c_UOM                   = @c_UOM      
                 ,@n_UOMQty                = @n_Qty     
                 ,@n_Qty                   = @n_Qty     
                 ,@c_FromLoc               = @c_Fromloc      
                 ,@c_LogicalFromLoc        = @c_FromLoc 
                 ,@c_FromID                = @c_ID     
                 ,@c_ToLoc                 = @c_ToLoc       
                 ,@c_LogicalToLoc          = @c_ToLoc 
                 ,@c_ToID                  = ''   
                 ,@c_Caseid                = @c_DropID    
                 ,@c_PickMethod            = @c_PickMethod
                 ,@c_Priority              = @c_Priority     
                 ,@c_SourcePriority        = @c_SourcePriority      
                 ,@c_SourceType            = @c_SourceType      
                 ,@c_SourceKey             = @c_Wavekey      
                 ,@c_OrderKey              = ''      
                 ,@c_WaveKey               = @c_Wavekey      
                 ,@c_Loadkey               = ''
                 ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                 ,@c_Message03             = @c_Message03
                 ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
                 ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
                 ,@c_SplitTaskByCase       ='N'   -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0.
                 ,@c_WIP_RefNo             = @c_SourceType
                 ,@b_Success               = @b_Success OUTPUT
                 ,@n_Err                   = @n_err OUTPUT 
                 ,@c_ErrMsg                = @c_errmsg OUTPUT        
              
              IF @b_Success <> 1 
              BEGIN
                 SELECT @n_continue = 3  
              END                      
           END
               
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_DropID
       END
       CLOSE cur_pick
       DEALLOCATE cur_pick       
    END
    
    -----Create replenishment task (UOM = 7)
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF @n_debug = 1
       BEGIN
           PRINT 'Create replenishment task'
       END

       SET @c_UOM = '7'
       SET @c_Priority = '8'
       SET @c_SourcePriority = '9'
       SET @c_Message03 = 'PICKLOC'        
       
       --Retrieve all lot of the wave from pick loc
       SELECT DISTINCT LLI.Lot             
       INTO #TMP_WAVEPICKLOT
       FROM PICKDETAIL PD (NOLOCK)
       JOIN SKUXLOC SXL (NOLOCK) ON PD.Storerkey = SXL.Storerkey AND PD.Sku = SXL.Sku AND PD.Loc = SXL.Loc
       JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.ID = LLI.ID
       JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
       JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey
       WHERE WD.Wavekey = @c_Wavekey
       AND SXL.LocationType IN('PICK','CASE')       
       AND LLI.QtyExpected > 0

       --Retreive pick loc with overallocated
       DECLARE cur_PickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) AS Qty
          FROM LOTXLOCXID LLI (NOLOCK)          
          JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
          JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
          JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
          JOIN #TMP_WAVEPICKLOT ON LLI.Lot = #TMP_WAVEPICKLOT.Lot 
          WHERE SL.LocationType IN ('PICK','CASE')
          AND LLI.Storerkey = @c_Storerkey
          AND LOC.Facility = @c_Facility       
          GROUP BY LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, PACK.CaseCnt 
          HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) < 0  --overallocate

       OPEN cur_PickLoc
       
       FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN               
           
           IF @n_QtyShort < 0
              SET @n_QtyShort = @n_QtyShort * -1
              
           SET @n_QtyReplen = @n_QtyShort   
           
           --retrieve stock from bulk 
          DECLARE cur_Bulk CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
             SELECT LLI.Lot, LLI.Loc, LLI.Id, UCC.Qty AS QtyAvailable, UCC.UCCNo
             FROM LOTXLOCXID LLI (NOLOCK)          
             JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
             JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
             JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT  
             JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
             JOIN ID (NOLOCK) ON LLI.Id = ID.Id
             JOIN UCC (NOLOCK) ON (UCC.StorerKey = LLI.StorerKey AND UCC.SKU = LLI.SKU AND 
                                  UCC.LOT = LLI.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID AND UCC.Status < '3')
             WHERE SL.LocationType NOT IN('PICK','CASE')
             AND LOT.STATUS = 'OK' 
             AND LOC.STATUS = 'OK' 
             AND ID.STATUS = 'OK'  
             AND LOC.LocationFlag = 'NONE' 
             AND LOC.LocationType = 'OTHER' 
             AND ID.Status = 'OK' 
             AND LOT.Status = 'OK'
             AND UCC.Qty > 0
             AND LLI.Qty > 0   --WL01
             AND LLI.Storerkey = @c_Storerkey
             AND LLI.Sku = @c_Sku
             AND LLI.Lot = @c_Lot
             ORDER BY LA.Lottable05, QTYAVAILABLE, LOC.LogicalLocation, LOC.Loc
             
          OPEN cur_Bulk
         
          FETCH FROM cur_Bulk INTO @c_Lot, @c_FromLoc, @c_ID, @n_QtyAvailable, @c_UCCNo
          
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_QtyReplen > 0            
          BEGIN          
             EXEC isp_InsertTaskDetail   
                @c_TaskType              = @c_TaskType             
               ,@c_Storerkey             = @c_Storerkey
               ,@c_Sku                   = @c_Sku
               ,@c_Lot                   = @c_Lot 
               ,@c_UOM                   = @c_UOM     
               ,@n_UOMQty                = @n_QtyAvailable     
               ,@n_Qty                   = @n_QtyAvailable      
               ,@c_FromLoc               = @c_Fromloc      
               ,@c_LogicalFromLoc        = @c_FromLoc 
               ,@c_FromID                = @c_ID     
               ,@c_ToLoc                 = @c_ToLoc       
               ,@c_LogicalToLoc          = @c_ToLoc 
               ,@c_ToID                  = @c_ToID       
               ,@c_Caseid                = @c_UCCNo 
               ,@c_PickMethod            = @c_PickMethod
               ,@c_Priority              = @c_Priority     
               ,@c_SourcePriority        = @c_SourcePriority    
               ,@c_SourceType            = @c_SourceType      
               ,@c_SourceKey             = @c_Wavekey      
               ,@c_WaveKey               = @c_Wavekey      
               ,@c_AreaKey               = '?F'      -- ?F=Get from location areakey 
               ,@c_Message03             = @c_Message03
               ,@c_ZeroSystemQty         = 'Y'        --  N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.  
               ,@c_ReserveQtyReplen      = 'TASKQTY' -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid 
               ,@c_ReservePendingMoveIn  =  'Y'      -- Y=Update @n_qty to @n_PendingMoveIn
               ,@b_Success               = @b_Success OUTPUT
               ,@n_Err                   = @n_err OUTPUT 
               ,@c_ErrMsg                = @c_errmsg OUTPUT          
 
             IF @b_Success <> 1 
             BEGIN
                SELECT @n_continue = 3   
             END

             --Update UCC Status to 3
             UPDATE UCC WITH (ROWLOCK)
             SET Status = '3'
             WHERE UCCNo = @c_UCCNo
             
             SELECT @n_err = @@ERROR  
             
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on UCC Failed (ispRLWAV26)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             END 

             --Check if still need replenish from other UCC
             IF( @n_QtyReplen >= @n_QtyAvailable )
                SET @n_QtyReplen = @n_QtyReplen - @n_QtyAvailable   
             ELSE
                SET @n_QtyReplen = 0           
             
             FETCH FROM cur_Bulk INTO @c_Lot, @c_FromLoc, @c_ID, @n_QtyAvailable, @c_UCCNo
          END
          CLOSE cur_Bulk
          DEALLOCATE cur_Bulk
          
          FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort
       END
       CLOSE cur_PickLoc
       DEALLOCATE cur_PickLoc          
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
           ,@c_ConsolidateByLoad = 'N'
           ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
           ,@c_AutoScanIn = 'N'  --Y=Auto scan in the pickslip N=Not auto scan in     
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV26)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  

RETURN_SP:
    IF @n_continue = 1 or @n_continue = 2 
    BEGIN
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
    END             

    IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
       DROP TABLE #PICKDETAIL_WIP
       
    IF OBJECT_ID('tempdb..#TEMP_LOADKEY') IS NOT NULL
       DROP TABLE #TEMP_LOADKEY

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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV26"  
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