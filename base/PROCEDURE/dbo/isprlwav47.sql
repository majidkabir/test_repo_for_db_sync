SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLWAV47                                          */  
/* Creation Date: 24-Aug-2021                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-17687 - NIKESGEC Release Wave                            */
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/* 14-DEC-2021 NJOW     1.0   DEVOPS combine script                      */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV47]      
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
            ,@n_MaxOrderPerWave     INT
            ,@c_NewWavekey          NVARCHAR(10)             
            ,@n_WaveOrdCnt          INT
            ,@c_Orderkey            NVARCHAR(10)           
            ,@c_CurrWaveKey         NVARCHAR(10)
            ,@c_SourcePriority      NVARCHAR(10)
            ,@c_PickMethod          NVARCHAR(10)
            ,@c_Sku                 NVARCHAR(20)            
            ,@c_LinkTaskToPick_SQL  NVARCHAR(4000)
            ,@c_FromLoc             NVARCHAR(10)
            ,@n_Qty                 INT
            ,@c_UOM                 NVARCHAR(10)
            ,@n_UOMQty              INT
            ,@c_ID                  NVARCHAR(18) 
            ,@c_Loadkey             NVARCHAR(10)
            ,@c_Wavedetailkey       NVARCHAR(10)
            ,@n_MasterWaveOrdCnt    INT
                      
    SET @c_SourceType = 'ispRLWAV47'    
    SET @c_Priority = '9'
    SET @c_TaskType = 'CPK'
    SET @c_PickMethod = 'PP'
    SET @c_SourcePriority = '9'
    
    CREATE TABLE #TEMP_LOADKEY(
    Orderkey      NVARCHAR(20) NULL,
    Loadkey       NVARCHAR(20) NULL )

    CREATE TABLE #TEMP_WAVEKEY(
    Wavekey       NVARCHAR(10) NULL)

    -----Wave Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype = @c_TaskType
                      WHERE WD.Wavekey = @c_Wavekey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV47)'       
       END             
    END

    IF @n_continue = 1 OR @n_continue = 2
    BEGIN    
       IF EXISTS(SELECT 1 
                 FROM WAVEDETAIL WD (NOLOCK)
                 JOIN PICKHEADER PH (NOLOCK) ON WD.Orderkey = PH.Orderkey
                 AND WD.Wavekey = @c_Wavekey)
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83010  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some orders already have pickslip created, not allow to release. (ispRLWAV47)'              	
       END
    END             
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype = @c_SourceType
                   AND TD.Tasktype = @c_TaskType)
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83020    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV47)'       
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
          SELECT @n_err = 83030   
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some orderkey in the wave do not have loadkey. (ispRLWAV47)'   
       END
    END
          
    IF @@TRANCOUNT = 0
       BEGIN TRAN
                    
    -----Get Storerkey, facility
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
    END   
    
    --Split wave
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
    	--Current master wave
    	INSERT INTO #TEMP_WAVEKEY (Wavekey)
    	VALUES (@c_Wavekey)
    	
      SELECT @n_MaxOrderPerWave = CASE WHEN ISNUMERIC(Susr5) = 1 THEN CAST(Susr5 AS INT) ELSE 9999 END
    	FROM STORER (NOLOCK)
    	WHERE Storerkey = @c_Storerkey    	
    	
    	 --Need splitting
       IF (SELECT COUNT(DISTINCT Orderkey) 
           FROM WAVEDETAIL (NOLOCK)
           WHERE Wavekey = @c_Wavekey) > @n_MaxOrderPerWave
       BEGIN
          DECLARE CUR_WAVEDET CURSOR FAST_FORWARD READ_ONLY FOR  
            SELECT WD.Orderkey
            FROM WAVEDETAIL WD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
            WHERE WD.Wavekey = @c_Wavekey
            ORDER BY O.Loadkey, O.Orderkey
            
          OPEN CUR_WAVEDET  
       
          FETCH NEXT FROM CUR_WAVEDET INTO @c_Orderkey
          
          SET @n_WaveOrdCnt = 0
          SET @n_MasterWaveOrdCnt = @n_MaxOrderPerWave
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
          BEGIN               
          	 --Skip order for master wave
          	 IF @n_MasterWaveOrdCnt > 0
          	 BEGIN
          	    SET @n_MasterWaveOrdCnt = @n_MasterWaveOrdCnt - 1
          	    GOTO NEXT_ORDER
          	 END          	    
          	         	   	 
          	 --open new wave
          	 IF @n_WaveOrdCnt >= @n_MaxOrderPerWave OR @n_WaveOrdCnt = 0
          	 BEGIN	 	  
          	 	  SET @c_NewWavekey = ''
          	 	  SET @b_success = 1
          	    EXECUTE nspg_GetKey
                   'WAVEKEY',
                   10,
                   @c_NewWavekey   OUTPUT,
                   @b_success   	 OUTPUT,
                   @n_err       	 OUTPUT,
                   @c_errmsg    	 OUTPUT
                   
                IF NOT @b_success = 1
                BEGIN
                   SELECT @n_continue = 3
                END  
 
               	INSERT INTO #TEMP_WAVEKEY (Wavekey)
              	VALUES (@c_NewWavekey)
              	
              	INSERT INTO WAVE (WaveKey, WaveType, Descr, DispatchPalletPickMethod, DispatchCasePickMethod, DispatchPiecePickMethod,
                                  Status, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine06,
                                  UserDefine07, UserDefine08, UserDefine09, UserDefine10, LoadplanGroup, MBOLGroupMethod, BatchNo,
                                  TMSStatus, DoorBookStatus, ReplenishStatus, TMReleaseFlag, GenDynamicPickSlipCode, Strategykey)
                SELECT @c_NewWavekey, WaveType, Descr, DispatchPalletPickMethod, DispatchCasePickMethod, DispatchPiecePickMethod,
                       Status, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine06,
                       UserDefine07, UserDefine08, UserDefine09, @c_Wavekey, LoadplanGroup, MBOLGroupMethod, BatchNo,
                       TMSStatus, DoorBookStatus, ReplenishStatus, TMReleaseFlag, GenDynamicPickSlipCode, Strategykey
                FROM WAVE (NOLOCK)
                WHERE Wavekey = @c_Wavekey       
           
                SELECT @n_err = @@ERROR
    	          IF @n_err <> 0
	   	          BEGIN
	   		          SELECT @n_continue = 3
				          SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36040   
				          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert WAVE Table. (ispRLWAV47)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			          END			                                   	          	 
                 	 	 	  
          	    SET @n_WaveOrdCnt = 0
          	 END

          	 SET @n_WaveOrdCnt = @n_WaveOrdCnt + 1
          	                
          	 DELETE FROM WAVEDETAIL 
          	 WHERE Wavekey = @c_Wavekey
          	 AND Orderkey = @c_Orderkey
          	 
          	 SET @c_Wavedetailkey = ''
	           SET @b_success = 1
          	 EXECUTE nspg_GetKey
                'WAVEDETAILKEY',
                10,
                @c_Wavedetailkey   OUTPUT,
                @b_success   	 OUTPUT,
                @n_err       	 OUTPUT,
                @c_errmsg    	 OUTPUT
                
             IF NOT @b_success = 1
             BEGIN
                SELECT @n_continue = 3
             END  
             
             INSERT INTO WAVEDETAIL (WaveKey, WaveDetailKey, OrderKey)
             VALUES (@c_NewWavekey, @c_Wavedetailkey, @c_Orderkey)          	          	       
             
             SELECT @n_err = @@ERROR
    	       IF @n_err <> 0
	   	       BEGIN
	   		       SELECT @n_continue = 3
				       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 36050   
				       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert WAVEDETAIL Table. (ispRLWAV47)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			       END			                         
			       
			       NEXT_ORDER:          	          	 
          	           	  
             FETCH NEXT FROM CUR_WAVEDET INTO @c_Orderkey  
          END                                
          CLOSE CUR_WAVEDET
          DEALLOCATE CUR_WAVEDET         	
       END
    END
        
    --Release wave
    IF @n_continue = 1 OR @n_continue = 2 
    BEGIN    	
       DECLARE CUR_WAVES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
          SELECT Wavekey
          FROM #TEMP_WAVEKEY                    
          ORDER BY Wavekey          
   
       OPEN CUR_WAVES  
       
       FETCH NEXT FROM CUR_WAVES INTO @c_CurrWavekey
       
       --Loop by wave
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN                        	   	
       	  DELETE FROM #PickDetail_WIP  --clear staging table   
       	                                                 
          --Initialize Pickdetail work in progress staging table         	        
          IF @n_continue = 1 or @n_continue = 2
          BEGIN                                            
       	     EXEC isp_CreatePickdetail_WIP
                 @c_Loadkey               = ''
                ,@c_Wavekey               = @c_CurrWavekey  
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
          
          --Create pick task
          IF @n_continue IN(1,2) 
          BEGIN
             DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                SELECT PD.Storerkey, PD.Sku, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,  
                       MAX(PD.UOM), SUM(PD.UOMQty) AS UOMQty, O.Loadkey
                FROM WAVEDETAIL WD (NOLOCK)
                JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey
                JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey
                JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc   
                WHERE WD.Wavekey = @c_CurrWavekey
                AND PD.Status = '0'
                AND PD.WIP_RefNo = @c_SourceType
                GROUP BY PD.Storerkey, PD.Sku, PD.Loc, PD.ID, LOC.LogicalLocation, O.Loadkey
                ORDER BY Loc.LogicalLocation, PD.Loc        
          
             OPEN cur_pick  
             
             FETCH NEXT FROM CUR_PICK INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Loadkey
             
             WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
             BEGIN                                           
                SET @c_LinkTaskToPick_SQL = 'AND ORDERS.Loadkey = @c_Loadkey '
                
                EXEC isp_InsertTaskDetail   
                    @c_TaskType              = @c_TaskType             
                   ,@c_Storerkey             = @c_Storerkey
                   ,@c_Sku                   = @c_Sku
                   ,@c_Lot                   = ''
                   ,@c_UOM                   = ''
                   ,@n_UOMQty                = @n_Qty     
                   ,@n_Qty                   = @n_Qty     
                   ,@c_FromLoc               = @c_Fromloc      
                   ,@c_LogicalFromLoc        = @c_FromLoc 
                   ,@c_FromID                = @c_ID     
                   ,@c_ToLoc                 = ''      
                   ,@c_LogicalToLoc          = ''
                   ,@c_ToID                  = ''   
                   ,@c_Caseid                = '' 
                   ,@c_PickMethod            = @c_PickMethod
                   ,@c_Priority              = @c_Priority     
                   ,@c_SourcePriority        = @c_SourcePriority      
                   ,@c_SourceType            = @c_SourceType      
                   ,@c_SourceKey             = @c_Wavekey      
                   ,@c_OrderKey              = ''      
                   ,@c_CallSource            ='WAVE'
                   ,@c_WaveKey               = @c_CurrWavekey      
                   ,@c_Loadkey               = @c_Loadkey
                   ,@c_DropID                = @c_CurrWavekey
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
                     
                FETCH NEXT FROM CUR_PICK INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Loadkey
             END
             CLOSE CUR_PICK
             DEALLOCATE CUR_PICK       
          END
          
          -----Update pickdetail_WIP work in progress staging table back to pickdetail                                                                                                                                     
          IF @n_continue = 1 or @n_continue = 2                                                                                                                                                                            
          BEGIN                                                                                                                                                                                                            
             EXEC isp_CreatePickdetail_WIP                                                                                                                                                                                 
                   @c_Loadkey               = ''                                                                                                                                                                           
                  ,@c_Wavekey               = @c_CurrWavekey                                                                                                                                                                   
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

          -----Generate Discrete Pickslip
          IF @n_continue = 1 or @n_continue = 2
          BEGIN
             EXEC isp_CreatePickSlip
                     @c_Wavekey = @c_CurrWavekey
                    ,@c_LinkPickSlipToPick = 'N'  --Y=Update pickslipno to pickdetail.pickslipno 
                    ,@c_ConsolidateByLoad = 'N'
                    ,@c_AutoScanIn = 'N'
                    ,@c_Refkeylookup = 'N'
                    ,@b_Success = @b_Success OUTPUT
                    ,@n_Err = @n_err OUTPUT 
                    ,@c_ErrMsg = @c_errmsg OUTPUT       	
                
             IF @b_Success = 0
                SELECT @n_continue = 3   
          END  
                                     
          -----Update wave status                            
          IF @n_continue = 1 or @n_continue = 2  
          BEGIN  
             UPDATE WAVE WITH (ROWLOCK)
                SET TMReleaseFlag = 'Y'               
                 ,  TrafficCop = NULL                 
                 ,  EditWho = SUSER_SNAME()           
                 ,  EditDate= GETDATE()               
             WHERE WAVEKEY = @c_CurrWavekey  
             
             SELECT @n_err = @@ERROR  
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV47)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             END  
          END  
                                                                                                                                                                     	       	
          FETCH NEXT FROM CUR_WAVES INTO @c_CurrWavekey
       END
       CLOSE CUR_WAVES
       DEALLOCATE CUR_WAVES
    END
                                  
RETURN_SP:
          
    IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
       DROP TABLE #PICKDETAIL_WIP
       
    IF OBJECT_ID('tempdb..#TEMP_LOADKEY') IS NOT NULL
       DROP TABLE #TEMP_LOADKEY

    IF OBJECT_ID('tempdb..#TEMP_WAVEKEY') IS NOT NULL
       DROP TABLE #TEMP_WAVEKEY

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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV47"  
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