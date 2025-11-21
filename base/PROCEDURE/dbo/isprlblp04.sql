SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLBLP04                                          */  
/* Creation Date: 22-Aug-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-10285 - TW Build Load Release Picking Task               */
/*                                                                       */
/* Config Key = 'BuildLoadReleaseTask_SP'                                */  
/*                                                                       */  
/* Called By: isp_BuildLoadReleaseTask_Wrapper                           */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 2020-02-18   WLChooi  1.1  WMS-11926 - Store Sorting Sequence in      */
/*                            Codelkup (WL01)                            */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLBLP04]      
  @c_Loadkey      NVARCHAR(10)  
 ,@b_Success      INT        OUTPUT  
 ,@n_err          INT        OUTPUT  
 ,@c_errmsg       NVARCHAR(250)  OUTPUT
 ,@c_Storerkey    NVARCHAR(15) = '' 
   
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

    DECLARE  @c_Facility            NVARCHAR(5)
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
            ,@c_SQL                 NVARCHAR(MAX)
            ,@c_Route               NVARCHAR(10)
            ,@c_Taskdetailkey       NVARCHAR(10)
            ,@c_DefaultLoc          NVARCHAR(10)
            ,@n_PKZoneCnt           INT = 0
            ,@n_AisleZoneCnt        INT = 0
            ,@c_Option1             NVARCHAR(50)
            ,@c_SortingSeq          NVARCHAR(4000)   --WL01

    CREATE TABLE #Orderkey(
    Orderkey      NVARCHAR(10),
    PKZoneCnt     INT,
    AisleZoneCnt  INT )

    INSERT INTO #Orderkey (Orderkey, PKZoneCnt, AisleZoneCnt)
    SELECT PD.Orderkey,
           COUNT(DISTINCT(Loc.Pickzone)),
           COUNT(DISTINCT(Loc.LocAisle)) 
    FROM PICKDETAIL PD (NOLOCK)
    JOIN Loc (NOLOCK) ON PD.Loc = Loc.Loc
    JOIN LoadPlanDetail LPD (NOLOCK) ON PD.OrderKey = LPD.OrderKey
    JOIN LoadPlan LP (NOLOCK) ON LP.Loadkey = LPD.Loadkey
    WHERE LP.Loadkey = @c_Loadkey   
    GROUP BY PD.Orderkey 
                            
    SET @c_SourceType = 'ispRLBLP04'    
    SET @c_Priority = '9'
    SET @c_TaskType = 'FCP'
    SET @c_PickMethod = 'PP'

    -----Load Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM LOADPLANDETAIL LD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType 
                                                      AND TD.Tasktype IN ('FPK','FCP','FPP')
                      WHERE LD.Loadkey = @c_Loadkey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Load# ' + RTRIM(@c_Loadkey) +' has nothing to release. (ispRLBLP04)'      
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
                    @c_Facility = O.Facility
       FROM LOADPLAN L (NOLOCK)
       JOIN LOADPLANDETAIL LD(NOLOCK) ON L.Loadkey = LD.Loadkey
       JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
       WHERE L.Loadkey = @c_Loadkey      
    END    
    
    --WL01 - Get sorting sequence - START
    SELECT @c_SortingSeq = ISNULL(Option5,'')
    FROM Storerconfig (NOLOCK)
    WHERE Storerkey = @c_Storerkey AND Configkey = 'BuildLoadReleaseTask_SP' 	
    AND SValue = @c_SourceType

    IF ISNULL(@c_SortingSeq,'') = ''
    BEGIN
       SET @c_SortingSeq = N' Taskdetail.Priority, @pkzonecnt, @aislezonecnt, Loc.Pickzone, Orders.Consigneekey, Orders.Orderkey, 
                              Loc.LogicalLocation, Pickdetail.Loc, Pickdetail.Sku '
    END

    SET @c_SortingSeq = REPLACE(@c_SortingSeq,'@pkzonecnt','OK.PKZoneCnt')
    SET @c_SortingSeq = REPLACE(@c_SortingSeq,'@aislezonecnt','OK.AisleZoneCnt')
    SET @c_SortingSeq = REPLACE(@c_SortingSeq,'Taskdetail.Priority','Priority')
    SET @c_SortingSeq = REPLACE(@c_SortingSeq,'ORDERS.','O.')
    SET @c_SortingSeq = REPLACE(@c_SortingSeq,'PICKDETAIL.','PD.')
    SET @c_SortingSeq = REPLACE(@c_SortingSeq,'LOADPLANDETAIL.','LPD.')
    SET @c_SortingSeq = REPLACE(@c_SortingSeq,'LOADPLAN.','LP.')
    SET @c_SortingSeq = REPLACE(@c_SortingSeq,'TASKDETAIL.','TD.')
    SET @c_SortingSeq = REPLACE(@c_SortingSeq,'STORERSODEFAULT.','SSO.')
    --WL01 - Get sorting sequence - END

    --Initialize Pickdetail work in progress staging table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = @c_Loadkey
           ,@c_Wavekey               = ''  
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
        LEFT JOIN TASKDETAIL TD (NOLOCK) ON TD.Taskdetailkey = #PICKDETAIL_WIP.Taskdetailkey AND TD.Sourcetype = @c_SourceType 
                                        AND TD.Tasktype IN ('FPK','FCP','FPP') AND TD.Status <> 'X' 
        WHERE TD.Taskdetailkey IS NULL
    END

    IF @n_continue IN(1,2) 
    BEGIN
     	 --SELECT @c_DefaultLoc = CL.Long
       --FROM CODELKUP CL (NOLOCK)
       --JOIN LOC (NOLOCK) ON CL.Long = LOC.Loc
       --WHERE CL.Listname = 'TM_TOLOC'
       --AND CL.Storerkey = @c_Storerkey
       --AND CL.Code = 'DEFAULT'

    	 SET @c_SQL = '
       DECLARE cur_pick CURSOR FAST_FORWARD READ_ONLY FOR  
    	    SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,  
    	           PD.UOM, SUM(PD.UOMQty) AS UOMQty,
    	           O.Route,
    	           O.Orderkey,
    	           TOLOC.Loc AS ToLoc,
                 OK.PKZoneCnt,
                 OK.AisleZoneCnt,
                 CASE WHEN ISNULL(SC.Option1,'''') = ''Shipperkey'' THEN ISNULL(CL1.Code,'''') ELSE ''9'' END AS Priority   --WL01
          FROM LOADPLANDETAIL LPD (NOLOCK)
          JOIN LOADPLAN LP (NOLOCK) ON LP.Loadkey = LPD.Loadkey
          JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
          JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          JOIN #ORDERKEY OK (NOLOCK) ON OK.Orderkey = O.Orderkey
          LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype IN (''FPK'',''FCP'',''FPP'') AND TD.Status <> ''X'' --NJOW01          
          LEFT JOIN STORERSODEFAULT SSO (NOLOCK) ON SSO.Storerkey = O.Consigneekey                 
          OUTER APPLY (SELECT TOP 1 TL.Loc FROM LOC TL (NOLOCK) WHERE TL.Putawayzone = SSO.Route) AS TOLOC
          JOIN STORERCONFIG SC (NOLOCK) ON SC.STORERKEY = O.Storerkey AND SC.Configkey = ''BuildLoadReleaseTask_SP'' AND SC.SValue = @c_SourceType  --WL01
          OUTER APPLY (SELECT TOP 1 ISNULL(CL.Code,'''') AS Code FROM CODELKUP CL (NOLOCK) WHERE CL.LISTNAME = ''TMPRIORITY'' AND CL.Short = O.Shipperkey 
                                                                                             AND CL.Storerkey = O.Storerkey
                                                                                             AND (CL.Storerkey = O.Storerkey OR CL.Storerkey = '''')
                                                                                             ORDER BY O.STORERKEY DESC ) AS CL1   --WL01
          WHERE PD.Status = ''0''
          AND PD.WIP_RefNo = @c_SourceType
          AND TD.Taskdetailkey IS NULL  --NJOW01          
          GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, O.Route, LOC.LogicalLocation, O.Orderkey, O.Consigneekey, TOLOC.Loc, OK.PKZoneCnt, OK.AisleZoneCnt, Loc.Pickzone,
                   ISNULL(SC.Option1,''''), ISNULL(CL1.Code,'''')
          ORDER BY ' + @c_SortingSeq  --WL01

     --ORDER BY OK.PKZoneCnt, OK.AisleZoneCnt, Loc.Pickzone, O.Consigneekey, O.Orderkey, Loc.LogicalLocation, PD.Loc, PD.Sku
       EXEC sp_executesql @c_SQL,
          N'@c_Loadkey NVARCHAR(10), @c_SourceType NVARCHAR(30) ',
          @c_Loadkey,
          @c_SourceType
             
       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Route, @c_Orderkey, @c_ToLoc,
                                     @n_PKZoneCnt, @n_AisleZoneCnt, @c_Priority --WL01     
                                                                                                                         
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN
          SET @c_LinkTaskToPick_SQL = '' 
          SET @c_Groupkey = @c_Orderkey

          SELECT @c_DefaultLoc = CL.Long
          FROM CODELKUP CL (NOLOCK)
          JOIN LOC (NOLOCK) ON LOC.LOC = CL.LONG
          JOIN ORDERS (NOLOCK) ON CL.CODE = ORDERS.[TYPE]
          WHERE ORDERS.ORDERKEY = @c_Orderkey
          AND CL.Listname = 'TM_TOLOC'
          AND CL.Storerkey = @c_Storerkey 

          IF ISNULL(@c_DefaultLoc,'') = ''
          BEGIN
             SELECT @c_DefaultLoc = CL.Long
             FROM CODELKUP CL (NOLOCK)
             JOIN LOC (NOLOCK) ON CL.Long = LOC.Loc
             WHERE CL.Listname = 'TM_TOLOC'
             AND CL.Storerkey = @c_Storerkey
             AND CL.Code = 'DEFAULT'
          END       	         	 
        	 
        	 IF ISNULL(@c_DefaultLoc,'') <> ''
        	    SET @c_ToLoc = @c_DefaultLoc
            	         	    
    	     IF ISNULL(@c_Toloc,'') = ''
    	     BEGIN    	 	 
              SELECT @n_continue = 3  
              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Loc setup. (ispRLBLP04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
           END       
           
           --WL01 Start
           /*SELECT @c_Option1 = ISNULL(Option1,'')
           FROM Storerconfig (NOLOCK)
           WHERE Storerkey = @c_Storerkey AND Configkey = 'BuildLoadReleaseTask_SP' 	
           AND SValue = @c_SourceType */
           
           /*IF LTRIM(RTRIM(ISNULL(@c_Option1,''))) = 'Shipperkey'
           BEGIN
              SELECT TOP 1 @c_Priority = LTRIM(RTRIM(ISNULL(CL.CODE,'')))
              FROM CODELKUP CL (NOLOCK)
              JOIN ORDERS OH (NOLOCK) ON CL.Storerkey = OH.Storerkey AND CL.Listname = 'TMPRIORITY'
                                     AND CL.Short = OH.Shipperkey
              WHERE OH.Orderkey = @c_Orderkey
              AND (OH.Storerkey = @c_Storerkey OR OH.STORERKEY = '')
              ORDER BY OH.STORERKEY DESC

              IF ISNULL(@c_Priority,'') = ''
              BEGIN
                 SET @c_Priority = '9'
              END
           END 
           ELSE
           BEGIN
              SET @c_Priority = '9'
           END*/ --WL01 End

           IF @c_UOM = '1'
           BEGIN 
           	  SET @c_Taskdetailkey = ''
           	  SET @c_TaskType = 'FPK'
           	  SET @c_PickMethod = 'FP'
           	  SET @c_GroupKey = @c_Orderkey        
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
                 ,@c_SourceKey             = @c_Loadkey      
                 ,@c_OrderKey              = @c_Orderkey      
                 ,@c_Groupkey              = @c_Groupkey
                 ,@c_LoadKey               = @c_Loadkey    
                 ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                 ,@c_Message03             = ''
                 ,@c_CallSource            = 'LOADPLAN'
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
           ELSE IF @c_UOM = '2'
           BEGIN
           	  SET @c_TaskType = 'FCP'
           	  SET @c_PickMethod = '?'
           	  
           	  SET @c_Groupkey = @c_Orderkey  
           	            
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
                 ,@c_SourceKey             = @c_Loadkey      
                 ,@c_OrderKey              = @c_Orderkey      
                 ,@c_Groupkey              = @c_Groupkey
                 ,@c_LoadKey               = @c_Loadkey      
                 ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                 ,@c_Message03             = ''
                 ,@c_CallSource            = 'LOADPLAN'
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
                 ,@c_SourceKey             = @c_Loadkey      
                 ,@c_OrderKey              = @c_Orderkey      
                 ,@c_Groupkey              = @c_Groupkey
                 ,@c_LoadKey               = @c_Loadkey      
                 ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                 ,@c_Message03             = ''
                 ,@c_CallSource            = 'LOADPLAN'
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
               
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Route, @c_Orderkey, @c_ToLoc,
                                        @n_PKZoneCnt, @n_AisleZoneCnt, @c_Priority --WL01 
       END
       CLOSE cur_pick
       DEALLOCATE cur_pick    	
    END
                     
    -----Update pickdetail_WIP work in progress staging table back to pickdetail 
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
       EXEC isp_CreatePickdetail_WIP
             @c_Loadkey               = @c_Loadkey
            ,@c_Wavekey               = ''  
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
               @c_Loadkey = @c_Loadkey
              ,@c_LinkPickSlipToPick = 'N'  --Y=Update pickslipno to pickdetail.pickslipno 
              ,@c_ConsolidateByLoad = 'N'
              ,@c_AutoScanIn = 'Y'   --Y=Auto scan in the pickslip N=Not auto scan in   
              --,@c_PickslipType = '8'
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_err OUTPUT 
              ,@c_ErrMsg = @c_errmsg OUTPUT       	
          
          IF @b_Success = 0
             SELECT @n_continue = 3

         --NJOW01
         --DECLARE cur_waveord CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         --   SELECT Orderkey
         --   FROM WAVEDETAIL (NOLOCK)
         --   WHERE Wavekey = @c_Wavekey             
         
         --OPEN cur_waveord  
       
         --FETCH NEXT FROM cur_waveord INTO @c_Orderkey
         
         --WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         --BEGIN          	        	
         --	  UPDATE PICKHEADER WITH (ROWLOCK)
         --	  SET PICKHEADER.Wavekey = @c_Wavekey,
         --	      PICKHEADER.Trafficcop = NULL
         --	  FROM PICKHEADER
         --	  JOIN ORDERS (NOLOCK) ON PICKHEADER.Orderkey = ORDERS.Orderkey
         --	  WHERE PICKHEADER.Orderkey = @c_Orderkey
                                      
         --   FETCH NEXT FROM cur_waveord INTO @c_Orderkey
         --END       
         --CLOSE cur_waveord
         --DEALLOCATE cur_waveord
       END
    END
               
    -----Update Load Status-----
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN
       UPDATE LOADPLAN WITH (ROWLOCK)
       SET Status = '3',
           TrafficCop = NULL
       WHERE Loadkey = @c_Loadkey
       AND Status IN('1','2')
       
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on LoadPlan Table Failed (ispRLBLP04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
   
RETURN_SP:

    -----Delete pickdetail_WIP work in progress staging table
    IF @n_continue IN (1,2)
    BEGIN
       EXEC isp_CreatePickdetail_WIP
             @c_Loadkey               = @c_Loadkey
            ,@c_Wavekey               = ''  
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

QUIT_SP:
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLBLP04"  
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