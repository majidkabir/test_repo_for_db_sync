SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRLWAV60                                          */  
/* Creation Date: 19-MAY-2023                                            */  
/* Copyright: MAERSK                                                     */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-22603 MY Puma Release wave                               */
/*                                                                       */  
/* Called By: Wave                                                       */  
/*                                                                       */  
/* GitLab Version: 1.0                                                   */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver.  Purposes                                  */  
/* 19-MAY-2023  NJOW     1.0   DevOps Combine Script                     */
/* 22-AUG-2023  NJOW01   1.1   WMS-23496 Change pickmethod to PP         */
/*************************************************************************/   

CREATE   PROCEDURE [dbo].[ispRLWAV60]      
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
           ,@c_Loc                     NVARCHAR(10)
           ,@c_Toloc                   NVARCHAR(10)
           ,@c_LinkTaskToPick_SQL      NVARCHAR(4000)
           ,@c_PTSLoc                  NVARCHAR(10)           
           ,@n_FlowRackReqCnt          INT
           ,@n_FlowRackAvaiCnt         INT
           ,@c_Userdefine02            NVARCHAR(20)
           ,@c_Userdefine03            NVARCHAR(20)
           ,@c_ConsoDisc               NVARCHAR(5)
                       
   SET @c_SourceType = 'ispRLWAV60'    
   SET @c_Priority = '9'
   
   -----Wave Validation-----            
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      SELECT @c_Storerkey = OH.Storerkey
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      WHERE WD.WaveKey = @c_wavekey

      IF NOT EXISTS(SELECT 1
                    FROM WAVEDETAIL WD (NOLOCK)
                    JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                    JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
                    JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
                    AND WD.Wavekey = @c_Wavekey
                    AND O.DocType = 'N'      
                    AND LOC.LocationType = 'OTHER'
                    AND LOC.LocationCategory = 'RACK')  --Only release for B2B footwear at highbay
      BEGIN
         GOTO RETURN_SP  
      END          

      IF NOT EXISTS (SELECT 1
                     FROM WAVEDETAIL WD (NOLOCK)
                     JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                     LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype IN('FCP','RPF')
                     WHERE WD.Wavekey = @c_Wavekey
                     AND PD.Status = '0'
                     AND TD.Taskdetailkey IS NULL                        
                    )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 83000
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV60)'
         GOTO RETURN_SP
      END
    
      IF EXISTS (SELECT 1 
                 FROM WAVEDETAIL WD (NOLOCK)
                 JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                 JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType 
                                                AND TD.Tasktype IN ('RPF')
                 WHERE WD.Wavekey = @c_Wavekey                   
                 )
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83010  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The Wave has been released. (ispRLWAV60)'       
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
           ,@c_PickCondition_SQL     = 'LOC.LocationType = ''OTHER'' AND LOC.LocationCategory = ''RACK'' AND ORDERS.DocType = ''N'' '  --B2B Highbay (footwaer) only
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
     
   -----Prepare common data
   IF  (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT TOP 1 @c_Storerkey = O.Storerkey,
                   @c_Facility = O.Facility,
                   @c_Userdefine02 = W.UserDefine02,
                   @c_Userdefine03 = W.UserDefine03,
                   @c_DispatchCasePickMethod = W.DispatchCasePickMethod
      FROM WAVE W (NOLOCK)
      JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      AND W.Wavekey = @c_Wavekey
      
      IF (ISNULL(@c_Userdefine02,'') = '' OR ISNULL(@c_Userdefine03,'') = '') 
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 83020
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Must key-in flowrack location range at userdefine02&03. (ispRLWAV60)'
         GOTO RETURN_SP
      END

      /*IF NOT EXISTS(SELECT 1 
                    FROM LOC (NOLOCK)
                    WHERE LOC.Loc = @c_DispatchCasePickMethod
                    AND LOC.Facility = @c_Facility)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 83030
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Packstation. Must select packstation at DispatchCasePickMethod. (ispRLWAV60)'
         GOTO RETURN_SP
      END*/
      
      CREATE TABLE #PTS_LOCASSIGNED (RowId BIGINT Identity(1,1) PRIMARY KEY
                                    ,STORERKEY NVARCHAR(15) NULL
                                    ,SKU NVARCHAR(20) NULL
                                    ,TOLOC NVARCHAR(10) NULL)
      
      --Find and update conso carton
      DECLARE CUR_PICKCASE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT PD.Lot, PD.Loc, PD.ID
         FROM #PICKDETAIL_WIP PD
         WHERE PD.UOM = '2'
         GROUP BY PD.Lot, PD.Loc, PD.ID
         HAVING COUNT(DISTINCT PD.Orderkey) > 1
         
      OPEN CUR_PICKCASE  
      
      FETCH NEXT FROM CUR_PICKCASE INTO @c_Lot, @c_Loc, @c_ID
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN      
      	 UPDATE #PICKDETAIL_WIP
      	 SET PickMethod = 'C'
      	 WHERE Lot = @c_Lot
      	 AND Loc = @c_Loc
      	 AND ID = @c_ID
      	 AND UOM = '2'
      	 
         FETCH NEXT FROM CUR_PICKCASE INTO @c_Lot, @c_Loc, @c_ID
      END
      CLOSE CUR_PICKCASE
      DEALLOCATE CUR_PICKCASE                        
      
      /*EXEC isp_CreatePickdetail_WIP
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
      END*/
                                                                 
      SELECT @n_FlowRackAvaiCnt = COUNT(1)
      FROM LOC (NOLOCK)
      WHERE LOC.Loc BETWEEN @c_Userdefine02 AND @c_Userdefine03
      AND LOC.Facility = @c_Facility
      AND LOC.LocationType = 'PTL'
      AND LOC.LocationCategory = 'FLOWRACK'                            
      
      SELECT @n_FlowRackReqCnt = COUNT(DISTINCT PD.Sku)       
      FROM #PICKDETAIL_WIP PD
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      --WHERE (PD.UOM <> '2' 
      --       OR (PD.UOM = '2' AND PD.PickMethod = 'C')) --Loose and conso carton only
           
      IF @n_FlowRackReqCnt > @n_FlowRackAvaiCnt
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 83040
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insufficient Flow Rack. Available: ' + CAST(@n_FlowRackAvaiCnt AS NVARCHAR) + ' Require: ' + CAST(@n_FlowRackReqCnt AS NVARCHAR)  + '. (ispRLWAV12)'
         GOTO RETURN_SP
      END
   END  
         
   --Generate RPF and FCP tasks
   IF @n_continue = 1 OR @n_continue = 2   
   BEGIN             
      DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,  
                PD.UOM, SUM(PD.UOMQty) AS UOMQty, 
                CASE WHEN PD.PickMethod = 'C' THEN PD.PickMethod ELSE 'D' END AS ConsoDisc
         FROM #PICKDETAIL_WIP PD (NOLOCK) 
         JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
         GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, CASE WHEN PD.PickMethod = 'C' THEN PD.PickMethod ELSE 'D' END,
                  SKU.Style, SKU.Size, SKU.Color
         ORDER BY SKU.Style, SKU.Size, SKU.Color, PD.UOM, PD.Loc, PD.Sku, PD.Lot 
      
      OPEN cur_pick  
      
      FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_ConsoDisc
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN                     
         SET @c_PickMethod = 'PP'
         SET @c_PTSLoc = ''
         SET @c_ToLoc = ''
         SET @c_TaskType = 'RPF'
         --SET @c_PickMethod = '?' --NJOW01 Removed

         IF @c_UOM = '2' AND @c_ConsoDisc = 'D'
         BEGIN
            SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND PICKDETAIL.PickMethod <> ''C''  '      
            --SET @c_PickMethod = 'FP' --NJOW01 Removed
            --SET @c_ToLoc = @c_DispatchCasePickMethod
         END
         ELSE
         BEGIN   
            SET @c_LinkTaskToPick_SQL = '(PICKDETAIL.UOM <> ''2'' OR (PICKDETAIL.UOM = ''2'' AND PICKDETAIL.PickMethod = ''C''))  '
         END    
            
         IF ISNULL(@c_PTSLoc,'')=''
         BEGIN
             SELECT TOP 1 @c_PTSLoc = PTS.ToLoc
             FROM #PTS_LOCASSIGNED PTS
             JOIN LOC (NOLOCK) ON LOC.Loc = PTS.ToLoc
             WHERE PTS.Storerkey = @c_Storerkey
             AND PTS.Sku = @c_Sku
             ORDER BY LOC.LogicalLocation, PTS.ToLoc
         END
         
          -- Assign new PTS location
         IF ISNULL(@c_PTSLoc,'')=''
         BEGIN
            SELECT TOP 1 @c_PTSLoc = Loc
            FROM LOC(NOLOCK)
            WHERE Loc >= @c_Userdefine02
            AND Loc <= @c_Userdefine03
            AND LocationType  ='PTL'
            AND LocationCategory = 'FLOWRACK'
            AND Facility = @c_Facility
            AND Loc NOT IN(SELECT TOLOC FROM #PTS_LOCASSIGNED)
            ORDER BY LogicalLocation, Loc
         END
         
         -- Terminate. Can't find any PTS location
         IF ISNULL(@c_PTSLoc,'')=''
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PTS Location Not Setup / Not enough PTS Location. (ispRLWAispRLWAV60)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            BREAK
         END
         
         SELECT @c_ToLoc = @c_PTSLoc
         
         --Insert current location assigned
         IF NOT EXISTS (SELECT 1 FROM #PTS_LOCASSIGNED
                        WHERE Storerkey = @c_Storerkey
                        AND Sku = @c_Sku
                        AND ToLoc = @c_ToLoc)
         BEGIN
            INSERT INTO #PTS_LOCASSIGNED (Storerkey, Sku, ToLoc)
            VALUES (@c_Storerkey, @c_Sku, @c_Toloc )
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
           ,@c_WaveKey               = @c_Wavekey      
           ,@c_Loadkey               = ''
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
            
         FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_ConsoDisc
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
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV60)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV60'  
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