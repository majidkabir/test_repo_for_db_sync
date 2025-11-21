SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: ispRLWAV29                                          */    
/* Creation Date: 24-Jun-2019                                            */    
/* Copyright: LFL                                                        */    
/* Written by: Chooi                                                     */    
/*                                                                       */    
/* Purpose: WMS-9378 - TW EAT Wave release pick task                     */  
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
/* 01-04-2020  Wan01    1.1   Sync Exceed & SCE                          */
/*************************************************************************/     
  
CREATE PROCEDURE [dbo].[ispRLWAV29]        
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
            ,@n_LocCnt              INT  
            ,@n_LocGroupMin         INT  
            ,@c_Groupkey            NVARCHAR(10)  
            ,@c_Toloc               NVARCHAR(10)                                      
            ,@c_Priority            NVARCHAR(10)              
            ,@c_PickMethod          NVARCHAR(10)              
            ,@c_Message03           NVARCHAR(20)  
            ,@C_Zip                 NVARCHAR(18)              
            ,@c_LinkTaskToPick_SQL  NVARCHAR(4000)   
            ,@c_SQL                 NVARCHAR(MAX)  
            ,@c_ExtraCondition      NVARCHAR(MAX) = ''
            ,@b_Released            INT = 0
            ,@c_TDKey               NVARCHAR(10)
            ,@c_Consigneekey        NVARCHAR(20)
    
    CREATE TABLE #TEMP_TDKEY(
    Orderkey        NVARCHAR(10),
    Taskdetailkey   NVARCHAR(10) )

    INSERT INTO #TEMP_TDKEY
    SELECT PD.Orderkey, PD.Taskdetailkey FROM WAVEDETAIL WD (NOLOCK)  
    JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey  
    JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
    JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey    
    JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc   
    WHERE WD.Wavekey = @c_Wavekey  
    AND PD.Status = '0'  
    AND PD.TASKDETAILKEY <> NULL
    AND PD.TASKDETAILKEY NOT IN (SELECT TASKDETAILKEY FROM TASKDETAIL TD (NOLOCK) WHERE TD.WAVEKEY = @c_Wavekey 
                                                                                    AND TD.Sourcetype = @c_SourceType  
                                                                                    AND TD.Tasktype = @c_Tasktype)      
                              
    SET @c_SourceType = 'ispRLWAV29'      
    SET @c_Priority = '9'  
    SET @c_TaskType = 'FCP'  
    SET @c_PickMethod = 'PP'  

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
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV29)'         
       END        
    END  
         
    IF @n_continue = 1 OR @n_continue = 2  
    BEGIN  
       IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
                  WHERE TD.Wavekey = @c_Wavekey  
                  AND TD.Sourcetype = @c_SourceType  
                  AND TD.Tasktype = @c_Tasktype)
       BEGIN 
          IF EXISTS ( SELECT 1 FROM #TEMP_TDKEY)-- WHERE Taskdetailkey <> NULL) --If temp table is empty, first time release
          BEGIN
             SET @b_Released = 1
          END    
          ELSE
          BEGIN 
             SELECT @n_continue = 3    
             SELECT @n_err = 83010    
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV29)'
          END
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
    IF  (@n_continue = 1 OR @n_continue = 2)  
    BEGIN  
        SELECT TOP 1 @c_Storerkey = O.Storerkey,   
                     @c_Facility = O.Facility,  
                     @c_WaveType = W.WaveType  
        FROM WAVE W (NOLOCK)  
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey  
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
        AND W.Wavekey = @c_Wavekey       
    END      

    --Initialize Pickdetail work in progress staging table for first time release 
    IF (@n_continue = 1 OR @n_continue = 2 ) AND @b_Released = 0
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

    --Initialize Pickdetail work in progress staging table for re-release, do not remove the taskdetailkey
    IF (@n_continue = 1 OR @n_continue = 2 ) AND @b_Released = 1
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
    END   

    IF (@n_continue = 1 OR @n_continue = 2 ) AND @b_Released = 1
    BEGIN  
       --Update PD.Taskdetailkey to blank when Taskdetail.Taskdetailkey is deleted
       DECLARE cur_DeleteTDKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT PD.TASKDETAILKEY
       FROM #PickDetail_WIP PD
       WHERE PD.TASKDETAILKEY NOT IN (SELECT TASKDETAILKEY FROM TASKDETAIL (NOLOCK) WHERE WAVEKEY = @c_WaveKey)

       OPEN cur_DeleteTDKey

       FETCH NEXT FROM cur_DeleteTDKey INTO @c_TDKey

       WHILE @@FETCH_STATUS <> -1
       BEGIN
          UPDATE #PickDetail_WIP
          SET TaskDetailKey = ''
          WHERE TaskDetailKey = @c_TDKey
          
          FETCH NEXT FROM cur_DeleteTDKey INTO @c_TDKey
       END
       CLOSE cur_DeleteTDKey
       DEALLOCATE cur_DeleteTDKey
    END

    IF @n_continue IN(1,2)  
    BEGIN
       SET @c_SQL = '  
          DECLARE cur_pick CURSOR FAST_FORWARD READ_ONLY FOR    
          SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,    
                 MAX(PD.UOM), SUM(PD.UOMQty) AS UOMQty, O.Orderkey, CASE WHEN ISNULL(O.c_Zip,'''') = '''' THEN ISNULL(CON.Zip,'''') ELSE O.c_Zip END AS Zip,  
                 O.Consigneekey 
           FROM WAVEDETAIL WD (NOLOCK)  
           JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey  
           JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
           JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey
           JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
           LEFT JOIN STORER CON (NOLOCK) ON O.Consigneekey = CON.Storerkey  
           LEFT JOIN STORERSODEFAULT SSO (NOLOCK) ON SSO.Storerkey = O.Consigneekey                
           OUTER APPLY (SELECT TOP 1 TL.Loc FROM LOC TL (NOLOCK) WHERE TL.Putawayzone = SSO.Route) AS TOLOC 
           WHERE WD.Wavekey = @c_Wavekey  
           AND PD.Status = ''0''  
           AND PD.WIP_RefNo = @c_SourceType 
           AND PD.TASKDETAILKEY NOT IN (SELECT TASKDETAILKEY FROM TASKDETAIL (NOLOCK) WHERE WAVEKEY = @c_WaveKey)
           GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, O.Orderkey, SSO.Route, O.Consigneekey, Loc.LogicalLocation,  
                    CASE WHEN ISNULL(O.c_Zip,'''') = '''' THEN ISNULL(CON.Zip,'''') ELSE O.c_Zip END, TOLOC.Loc                        
           ORDER BY PD.Storerkey, SSO.Route, O.Consigneekey, Loc.LogicalLocation, PD.Loc '  

       EXEC sp_executesql @c_SQL,  
          N'@c_Wavekey NVARCHAR(10), @c_SourceType NVARCHAR(30)',   
          @c_Wavekey,  
          @c_SourceType     
               
       OPEN cur_pick    
         
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Orderkey, @c_Zip, @c_Consigneekey  
         
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
       BEGIN                      
          SET @c_LinkTaskToPick_SQL = ''   
          SET @c_UOM = ''  
          SET @n_UOMQty = 0  
          SET @c_Groupkey = @c_Orderkey       
          SET @c_ToLoc = ''

          SELECT TOP 1 @c_ToLoc = ISNULL(CL.Long,'')
          FROM CODELKUP CL (NOLOCK) 
          WHERE CL.Listname = 'TM_TOLOC'
          AND CL.CODE IN (SELECT TOP 1 SUSR3 FROM STORER (NOLOCK) WHERE STORERKEY = @c_Consigneekey)
          AND CL.Storerkey = @c_Storerkey
          ORDER BY CASE WHEN ISNULL(CL.Long,'') = '' THEN 2 ELSE 1 END

          IF NOT EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_ToLoc)
          BEGIN
             SELECT @n_continue = 3    
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': LOC ' + @c_ToLoc + 'Not Found. (ispRLWAV29)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
             GOTO RETURN_SP
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
                
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Orderkey, @c_Zip, @c_Consigneekey  
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
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV29)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV29"    
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