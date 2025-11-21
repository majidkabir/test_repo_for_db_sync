SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRLWAV59                                          */  
/* Creation Date: 28-APR-2023                                            */  
/* Copyright: MAERSK                                                     */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-22425 VN Nike AirMi Release wave                         */
/*                                                                       */  
/* Called By: Wave                                                       */  
/*                                                                       */  
/* GitLab Version: 1.1                                                   */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver.  Purposes                                  */  
/* 28-APR-2023  NJOW     1.0   DevOps Combine Script                     */
/* 07-JUL-2023  NJOW01   1.1   WMS-23043 Cater for multi-lot full pallet */
/*************************************************************************/   

CREATE   PROCEDURE [dbo].[ispRLWAV59]      
       @c_wavekey      NVARCHAR(10)  
      ,@b_Success      INT            OUTPUT  
      ,@n_err          INT            OUTPUT  
      ,@c_errmsg       NVARCHAR(250)  OUTPUT  
 AS  
 BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue  INT,    
           @n_starttcnt INT,         -- Holds the current transaction count  
           @n_debug     INT,
           @n_cnt       INT
   
   IF @n_err > 0
      SET @n_debug = @n_err

   SELECT  @n_starttcnt = @@TRANCOUNT , @n_continue = 1, @b_success = 0,@n_err = 0,@c_errmsg = '',@n_cnt = 0
   
   DECLARE  @c_Storerkey               NVARCHAR(15)
           ,@c_Facility                NVARCHAR(5)
           ,@c_Sku                     NVARCHAR(20)
           ,@c_Lot                     NVARCHAR(10)
           ,@c_FromLoc                 NVARCHAR(10)
           ,@c_ID                      NVARCHAR(18)
           ,@n_Qty                     INT
           ,@c_SourceType              NVARCHAR(30)
           ,@c_DispatchCasePickMethod  NVARCHAR(10)
           ,@c_TaskType                NVARCHAR(10)
           ,@c_UOM                     NVARCHAR(10)
           ,@n_UOMQty                  INT
           ,@c_PickMethod              NVARCHAR(10)            
           ,@c_Priority                NVARCHAR(10)
           ,@c_Toloc                   NVARCHAR(10)
           ,@c_LinkTaskToPick_SQL      NVARCHAR(4000)
           ,@c_Loadkey                 NVARCHAR(10)
                       
   SET @c_SourceType = 'ispRLWAV59'    
   SET @c_Priority = '9'
   
   -----Wave Validation-----            
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      SELECT @c_Storerkey = OH.Storerkey
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      WHERE WD.WaveKey = @c_wavekey

      IF EXISTS (SELECT 1 
                 FROM WAVEDETAIL WD (NOLOCK)
                 JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                 JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType 
                                                AND TD.Tasktype IN ('FCP','FPK')
                 WHERE WD.Wavekey = @c_Wavekey                   
                 )
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83000  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The Wave has been released. (ispRLWAV59)'       
         GOTO RETURN_SP
      END      
      
      IF EXISTS (SELECT 1 
                 FROM WAVEDETAIL WD (NOLOCK)
                 LEFT JOIN LOADPLANDETAIL LPD (NOLOCK) ON WD.Orderkey = LPD.Orderkey
                 WHERE WD.Wavekey = @c_Wavekey
                 AND LPD.Orderkey IS NULL)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83010  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Loadkey not found for the Wave. Not allow to release. (ispRLWAV59)'       
         GOTO RETURN_SP
      END           
   END

   --Create pickdetail Work in progress temporary table    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      CREATE TABLE #PickDetail_WIP(
         [PickDetailKey] [NVARCHAR](18) NOT NULL PRIMARY KEY,
         [CaseID] [NVARCHAR](20) NOT NULL DEFAULT (' '),
         [PickHeaderKey] [NVARCHAR](18) NOT NULL,
         [OrderKey] [NVARCHAR](10) NOT NULL,
         [OrderLineNumber] [NVARCHAR](5) NOT NULL,
         [Lot] [NVARCHAR](10) NOT NULL,
         [Storerkey] [NVARCHAR](15) NOT NULL,
         [Sku] [NVARCHAR](20) NOT NULL,
         [AltSku] [NVARCHAR](20) NOT NULL DEFAULT (' '),
         [UOM] [NVARCHAR](10) NOT NULL DEFAULT (' '),
         [UOMQty] [INT] NOT NULL DEFAULT ((0)),
         [Qty] [INT] NOT NULL DEFAULT ((0)),
         [QtyMoved] [INT] NOT NULL DEFAULT ((0)),
         [Status] [NVARCHAR](10) NOT NULL DEFAULT ('0'),
         [DropID] [NVARCHAR](20) NOT NULL DEFAULT (''),
         [Loc] [NVARCHAR](10) NOT NULL DEFAULT ('UNKNOWN'),
         [ID] [NVARCHAR](18) NOT NULL DEFAULT (' '),
         [PackKey] [NVARCHAR](10) NULL DEFAULT (' '),
         [UpdateSource] [NVARCHAR](10) NULL DEFAULT ('0'),
         [CartonGroup] [NVARCHAR](10) NULL,
         [CartonType] [NVARCHAR](10) NULL,
         [ToLoc] [NVARCHAR](10) NULL  DEFAULT (' '),
         [DoReplenish] [NVARCHAR](1) NULL DEFAULT ('N'),
         [ReplenishZone] [NVARCHAR](10) NULL DEFAULT (' '),
         [DoCartonize] [NVARCHAR](1) NULL DEFAULT ('N'),
         [PickMethod] [NVARCHAR](1) NOT NULL DEFAULT (' '),
         [WaveKey] [NVARCHAR](10) NOT NULL DEFAULT (' '),
         [EffectiveDate] [datetime] NOT NULL DEFAULT (GETDATE()),
         [AddDate] [datetime] NOT NULL DEFAULT (GETDATE()),
         [AddWho] [NVARCHAR](128) NOT NULL DEFAULT (SUSER_SNAME()),
         [EditDate] [datetime] NOT NULL DEFAULT (GETDATE()),
         [EditWho] [NVARCHAR](128) NOT NULL DEFAULT (SUSER_SNAME()),
         [TrafficCop] [NVARCHAR](1) NULL,
         [ArchiveCop] [NVARCHAR](1) NULL,
         [OptimizeCop] [NVARCHAR](1) NULL,
         [ShipFlag] [NVARCHAR](1) NULL DEFAULT ('0'),
         [PickSlipNo] [NVARCHAR](10) NULL,
         [TaskDetailKey] [NVARCHAR](10) NULL,
         [TaskManagerReasonKey] [NVARCHAR](10) NULL,
         [Notes] [NVARCHAR](4000) NULL,
         [MoveRefKey] [NVARCHAR](10) NULL DEFAULT (''),
         [WIP_Refno] [NVARCHAR](30) NULL DEFAULT (''),
         [Channel_ID] [BIGINT] NULL DEFAULT ((0)))                   
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
   END
     
   -----Prepare common data
   IF  (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                   @c_Facility = O.Facility,
                   @c_DispatchCasePickMethod = W.DispatchCasePickMethod
      FROM WAVE W (NOLOCK)
      JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      AND W.Wavekey = @c_Wavekey         
      
      IF NOT EXISTS(SELECT 1
                    FROM LOC (NOLOCK)
                    WHERE LOC = @c_DispatchCasePickMethod)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83020  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Loc ' + RTRIM(ISNULL(@c_DispatchCasePickMethod,'')) + ' (DispatchCasePickMethod). (ispRLWAV59)'                
      END                     
   END  
      
   --Remove taskdetailkey 
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE #PICKDETAIL_WIP WITH (ROWLOCK) 
      SET #PICKDETAIL_WIP.TaskdetailKey = ''
   END
   
   --Find single order full pallet with multiple lots and update from uom 2 to uom 1
   IF @n_continue = 1 OR @n_continue = 2  --NJOW01
   BEGIN
   	  DECLARE CUR_FULLPLT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   	     SELECT PD.Loc, PD.ID
   	     FROM #PickDetail_WIP PD
   	     JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
   	     JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
   	     WHERE PD.UOM <> '1'
   	     AND PD.ID <> ''
   	     GROUP BY PD.Loc, PD.ID
   	     HAVING COUNT(DISTINCT PD.Sku) = 1 AND COUNT(DISTINCT PD.Orderkey) = 1 
   	            AND MAX(PACK.Pallet) = SUM(PD.Qty)	  

      OPEN CUR_FULLPLT  
      
      FETCH NEXT FROM CUR_FULLPLT INTO @c_FromLoc, @c_ID
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN      
      	 UPDATE #PickDetail_WIP 
      	 SET UOM = '1',
      	     CartonType = 'MULTILOT' 
      	 WHERE Loc = @c_FromLoc
      	 AND ID = @c_ID
      	
         FETCH NEXT FROM CUR_FULLPLT INTO @c_FromLoc, @c_ID      	
      END
      CLOSE CUR_FULLPLT
      DEALLOCATE CUR_FULLPLT                  	       	          
   END

   --Generate FPK and CPK tasks
   IF @n_continue = 1 OR @n_continue = 2   
   BEGIN             
      DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PD.Storerkey, PD.Sku, 
                CASE WHEN PD.UOM = '1' AND PD.CartonType = 'MULTILOT' THEN '' ELSE PD.Lot END AS Lot, --NJOW01
                PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,  
                PD.UOM, SUM(PD.UOMQty) AS UOMQty, MAX(O.Loadkey)
         FROM #PickDetail_WIP PD (NOLOCK) 
         JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
         GROUP BY PD.Storerkey, PD.Sku, 
                  CASE WHEN PD.UOM = '1' AND PD.CartonType = 'MULTILOT' THEN '' ELSE PD.Lot END, --NJOW01
                  PD.Loc, PD.ID, PD.UOM
         ORDER BY PD.UOM, PD.Loc, PD.Sku, CASE WHEN PD.UOM = '1' AND PD.CartonType = 'MULTILOT' THEN '' ELSE PD.Lot END  --NJOW01
      
      OPEN cur_pick  
      
      FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Loadkey
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN                     
         SET @c_LinkTaskToPick_SQL = '' 

         IF @c_UOM = '1'
         BEGIN
            SET @c_TaskType = 'FPK'
            SET @c_PickMethod = 'FP'
         END
         ELSE
         BEGIN   
            SET @c_TaskType = 'FCP'
            SET @c_PickMethod = 'PP'
         END
                                      
         SET @c_ToLoc = @c_DispatchCasePickMethod             
   
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
           ,@c_WaveKey               = @c_Wavekey      
           ,@c_Loadkey               = @c_Loadkey
           ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
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

    -----Update Wave Status-----
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
      UPDATE WAVE 
      SET TMReleaseFlag = 'Y'     
       ,  TrafficCop = NULL       
       ,  EditWho = SUSER_SNAME() 
       ,  EditDate= GETDATE()     
      WHERE WAVEKEY = @c_wavekey  

      SELECT @n_err = @@ERROR  

      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83130   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV59)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END  
   
RETURN_SP:

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
   
   IF OBJECT_ID('tempdb..#PickDetail_WIP') IS NOT NULL
      DROP TABLE #PickDetail_WIP
      
   IF CURSOR_STATUS('LOCAL', 'cur_pick') IN (0 , 1)
   BEGIN
      CLOSE cur_pick
      DEALLOCATE cur_pick   
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV59'  
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