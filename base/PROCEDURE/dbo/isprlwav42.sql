SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: ispRLWAV42                                          */    
/* Creation Date: 27-May-2021                                            */    
/* Copyright: LFL                                                        */    
/* Written by: WLChooi                                                   */    
/*                                                                       */    
/* Purpose: WMS-17089 - [CN] Coach - Release Wave for Replenishment      */    
/*                                                                       */    
/* Called By: Wave                                                       */    
/*                                                                       */    
/* GitLab Version: 1.2                                                   */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */ 
/* 2021-08-17   WLChooi  1.1  Bug Fix (WL01)                             */   
/* 2021-09-08   WLChooi  1.2  DevOps Combine Script                      */   
/* 2021-09-08   WLChooi  1.2  WMS-17879 - Update Pickdetail.Notes (WL02) */
/*************************************************************************/     

CREATE PROCEDURE [dbo].[ispRLWAV42]        
    @c_wavekey      NVARCHAR(10)    
   ,@b_Success      INT            OUTPUT    
   ,@n_err          INT            OUTPUT    
   ,@c_errmsg       NVARCHAR(250)  OUTPUT    
   ,@b_debug        INT = 0
 AS    
 BEGIN    
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE  @n_continue int,      
            @n_starttcnt int,         -- Holds the current transaction count    
            @n_debug int,  
            @n_cnt int  
                    
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0  
   SELECT @n_debug = @b_debug 
 
   DECLARE @c_PTS                     NVARCHAR(10)
         , @c_Option5                 NVARCHAR(4000)
         , @c_SourceType              NVARCHAR(20)
         , @c_DispatchPiecePickMethod NVARCHAR(20)
         , @c_DocType                 NVARCHAR(10)
         , @c_DeviceId                NVARCHAR(20)
         , @c_IPAddress               NVARCHAR(40)
         , @c_PortNo                  NVARCHAR(5)
         , @c_DevicePosition          NVARCHAR(10)
         , @c_PTSLOC                  NVARCHAR(10)
         , @c_PTSStatus               NVARCHAR(10)
         , @c_InLoc                   NVARCHAR(10)
         , @c_DropId                  NVARCHAR(20)
         , @c_Storerkey               NVARCHAR(15)
         , @c_Sku                     NVARCHAR(20)
         , @c_Lot                     NVARCHAR(10)
         , @c_FromLoc                 NVARCHAR(10)
         , @c_ID                      NVARCHAR(18)
         , @c_ToID                    NVARCHAR(18)
         , @n_Qty                     INT
         , @n_QtyShort                INT
         , @n_QtyReplen               INT
         , @n_CaseCntFinal            INT
         , @n_OnHandQty               INT
         , @n_QtyTake                 INT
         , @n_RemainingQty            INT
         , @n_InsertQty               INT
         , @n_TotCtn                  INT
         , @c_SourcePriority          NVARCHAR(10)
         , @c_PickMethod              NVARCHAR(10)
         , @c_Toloc                   NVARCHAR(10)
         , @c_ToLoc_Strategy          NVARCHAR(30)
         , @c_ToLoc_StrategyParam     NVARCHAR(4000)
         , @c_Priority                NVARCHAR(10)
         , @c_Taskdetailkey           NVARCHAR(10)
         , @n_UCCQty                  INT
         , @c_Style                   NVARCHAR(20)
         , @c_Facility                NVARCHAR(5)
         , @c_UOM                     NVARCHAR(10)
         , @c_DestinationType         NVARCHAR(30)
         , @c_Pickdetailkey           NVARCHAR(18)
         , @c_NewPickdetailKey        NVARCHAR(18)
         , @n_Pickqty                 INT
         , @n_ReplenQty               INT
         , @n_SplitQty                INT
         , @c_Message03               NVARCHAR(20)
         , @c_TaskType                NVARCHAR(10)
         , @c_Orderkey                NVARCHAR(10)
         , @c_Pickslipno              NVARCHAR(10)
         , @c_Loadkey                 NVARCHAR(10)
         , @c_InductionLoc            NVARCHAR(20)
         , @c_PTLWavekey              NVARCHAR(10)
         , @c_PTLLoadkey              NVARCHAR(10)
         , @c_LoadlineNumber          NVARCHAR(5)
         , @c_Loctype                 NVARCHAR(10)
         , @c_curPickdetailkey        NVARCHAR(10)
         , @c_Lottable01              NVARCHAR(18)
         , @dt_Lottable05             DATETIME
         , @c_UserDefine02            NVARCHAR(18)
         , @c_GetUserDefine02         NVARCHAR(18)
         , @c_Sourcekey               NVARCHAR(10)
         , @c_trmlogkey               NVARCHAR(10)
         , @n_TLogGenerated           INT = 0
         , @c_Userdefine04            NVARCHAR(10)
         , @c_PrevSourcekey           NVARCHAR(10) = N''
         , @c_DPCount                 NVARCHAR(10) = N''
         , @c_FirstDP                 NVARCHAR(20) = N''
         , @c_PrevDP                  NVARCHAR(20) = N''
         , @c_SourcekeyCNT            INT          = 0
         , @c_TableName               NVARCHAR(20) = N''
         , @c_UserDefine08            NVARCHAR(50) = N''
         , @c_Userdefine03            NVARCHAR(50) = N''
         , @c_PickCondition_SQL       NVARCHAR(4000)
         , @c_LinkTaskToPick_SQL      NVARCHAR(4000)
         , @c_CLCode                  NVARCHAR(50)   --WL02
         , @c_CLShort                 NVARCHAR(50)   --WL02
 
   DECLARE @cur_PICKSKU CURSOR,   
           @c_SortMode NVARCHAR(10)  

   SET @c_SourceType = 'ispRLWAV42'
   SET @c_Priority = '9'
             
   -----Get some basic info---------------
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN        
      SELECT TOP 1 @c_Userdefine02            = WAVE.UserDefine02,   
                   @c_Userdefine03            = WAVE.UserDefine03,   
                   @c_Facility                = ORDERS.Facility,  
                   @c_DispatchPiecePickMethod = WAVE.DispatchPiecePickMethod,  
                   @c_Storerkey               = ORDERS.Storerkey,
                   @c_Userdefine04            = WAVE.UserDefine04,
                   @c_UserDefine08            = WAVE.UserDefine08,
                   @c_DocType                 = ORDERS.DocType
      FROM WAVE (NOLOCK)  
      JOIN WAVEDETAIL (NOLOCK) ON WAVE.Wavekey = WAVEDETAIL.WaveKey  
      JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey          
      WHERE WAVE.Wavekey = @c_Wavekey  
                          
      IF @n_debug=1  
         SELECT '@c_Wavekey', @c_Wavekey, '@c_Facility', @c_Facility, '@c_DocType', @c_DocType    
         
      SELECT @c_Option5 = SC.Option5
      FROM StorerConfig SC (NOLOCK)
      WHERE SC.StorerKey = @c_Storerkey AND SC.ConfigKey = 'ReleaseWave_SP'
      AND SC.SValue = @c_SourceType      
      
      IF ISNULL(@c_PTS,'') = ''
         SELECT @c_PTS = dbo.fnc_GetParamValueFromString('@c_PTS', @c_Option5, @c_PTS)    

      SET @c_PTS = REPLACE(@c_PTS,'''','')
   END  
   -----Wave Validation-----  
   IF @n_continue=1 or @n_continue=2    
   BEGIN    
      IF ISNULL(@c_wavekey,'') = ''    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @n_err = 81010    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Parameters Passed (ispRLWAV42)'    
      END    
   END      
                        
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
                 WHERE TD.Wavekey = @c_Wavekey  
                 AND TD.Sourcetype = @c_SourceType
                 AND TD.Tasktype IN ('RPT','FCP'))   
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 81040    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has been released. (ispRLWAV42)'         
      END                   
   END  

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK)
                 WHERE UserDefine09 = @c_wavekey
                 AND (Loadkey IS NULL OR Loadkey = '') )
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 81045  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': One or more orders are missing Loadkey. (ispRLWAV42)'         
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
         SELECT @n_err = 81050    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking (ispRLWAV42)'           
      END                   
   END   

   IF @@TRANCOUNT = 0
      BEGIN TRAN
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN 
      IF OBJECT_ID('#PickDetail_WIP') IS NOT NULL
      BEGIN 
         DROP TABLE #PickDetail_WIP
      END

      CREATE TABLE #PickDetail_WIP
      (  
         [PickDetailKey]         [nvarchar](18)    NOT NULL PRIMARY KEY  
      ,  [CaseID]                [nvarchar](20)    NOT NULL DEFAULT (' ')  
      ,  [PickHeaderKey]         [nvarchar](18)    NOT NULL  
      ,  [OrderKey]              [nvarchar](10)    NOT NULL  
      ,  [OrderLineNumber]       [nvarchar](5)     NOT NULL  
      ,  [Lot]                   [nvarchar](10)    NOT NULL  
      ,  [Storerkey]             [nvarchar](15)    NOT NULL  
      ,  [Sku]                   [nvarchar](20)    NOT NULL  
      ,  [AltSku]                [nvarchar](20)    NOT NULL    DEFAULT (' ')  
      ,  [UOM]                   [nvarchar](10)    NOT NULL    DEFAULT (' ')  
      ,  [UOMQty]                [int]             NOT NULL    DEFAULT ((0))  
      ,  [Qty]                   [int]             NOT NULL    DEFAULT ((0))  
      ,  [QtyMoved]              [int]             NOT NULL    DEFAULT ((0))  
      ,  [Status]                [nvarchar](10)    NOT NULL    DEFAULT ('0')  
      ,  [DropID]                [nvarchar](20)    NOT NULL    DEFAULT ('')  
      ,  [Loc]                   [nvarchar](10)    NOT NULL    DEFAULT ('UNKNOWN')  
      ,  [ID]                    [nvarchar](18)    NOT NULL    DEFAULT (' ')  
      ,  [PackKey]               [nvarchar](10)    NULL        DEFAULT (' ')  
      ,  [UpdateSource]          [nvarchar](10)    NULL        DEFAULT ('0')  
      ,  [CartonGroup]           [nvarchar](10)    NULL  
      ,  [CartonType]            [nvarchar](10)    NULL  
      ,  [ToLoc]                 [nvarchar](10)    NULL        DEFAULT (' ')  
      ,  [DoReplenish]           [nvarchar](1)     NULL        DEFAULT ('N')  
      ,  [ReplenishZone]         [nvarchar](10)    NULL        DEFAULT (' ')  
      ,  [DoCartonize]           [nvarchar](1)     NULL        DEFAULT ('N')  
      ,  [PickMethod]            [nvarchar](1)     NOT NULL    DEFAULT (' ')  
      ,  [WaveKey]               [nvarchar](10)    NOT NULL    DEFAULT (' ')  
      ,  [EffectiveDate]         [datetime]        NOT NULL    DEFAULT (getdate())  
      ,  [AddDate]               [datetime]        NOT NULL    DEFAULT (getdate())  
      ,  [AddWho]                [nvarchar](128)   NOT NULL    DEFAULT (suser_sname())  
      ,  [EditDate]              [datetime]        NOT NULL    DEFAULT (getdate())  
      ,  [EditWho]               [nvarchar](128)   NOT NULL    DEFAULT (suser_sname())  
      ,  [TrafficCop]            [nvarchar](1)     NULL  
      ,  [ArchiveCop]            [nvarchar](1)     NULL  
      ,  [OptimizeCop]           [nvarchar](1)     NULL  
      ,  [ShipFlag]              [nvarchar](1)     NULL        DEFAULT ('0')  
      ,  [PickSlipNo]            [nvarchar](10)    NULL  
      ,  [TaskDetailKey]         [nvarchar](10)    NULL  
      ,  [TaskManagerReasonKey]  [nvarchar](10)    NULL  
      ,  [Notes]                 [nvarchar](4000)  NULL  
      ,  [MoveRefKey]            [nvarchar](10)    NULL        DEFAULT ('')  
      ,  [WIP_Refno]             [nvarchar](30)    NOT NULL    DEFAULT ('')  
      ,  [Channel_ID]            [bigint]          NULL        DEFAULT ((0))
      )      
            
      CREATE INDEX PDWIP_Wave ON #PickDetail_WIP (Wavekey, WIP_RefNo, UOM, [Status]) 
   END

   --Initialize Pickdetail work in progress staging table
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP
          @c_Loadkey               = ''
         ,@c_Wavekey               = @c_Wavekey  
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

   --Remove taskdetailkey and add wavekey from pickdetail of the wave      
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      SET @c_curPickdetailkey = ''  
      DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT Pickdetailkey  
      FROM WAVEDETAIL WITH (NOLOCK)    
      JOIN #PickDetail_WIP PICKDETAIL WITH (NOLOCK)  ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey   --WL02  
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey   
  
      OPEN Orders_Pickdet_cur   
      FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey   
      WHILE @@FETCH_STATUS = 0   
      BEGIN   
         --WL02 S
         UPDATE #PickDetail_WIP WITH (ROWLOCK)   
         SET #PickDetail_WIP.TaskdetailKey = '', 
             #PickDetail_WIP.Notes = '',   
             #PickDetail_WIP.Wavekey = @c_Wavekey,   
             EditWho    = SUSER_SNAME(),  
             EditDate   = GETDATE(),     
             TrafficCop = NULL  
         WHERE #PickDetail_WIP.Pickdetailkey = @c_curPickdetailkey
         --WL02 E
          
         SELECT @n_err = @@ERROR  

         IF @n_err <> 0   
         BEGIN  
            CLOSE Orders_Pickdet_cur   
            DEALLOCATE Orders_Pickdet_cur                    
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV42)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END    

         FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey  
      END  
      CLOSE Orders_Pickdet_cur   
      DEALLOCATE Orders_Pickdet_cur  
   END 

   --FCP Task for UOM 2 (Directly to Pack Station)
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_ToLoc = ''
      SET @c_ToLoc_Strategy = '' 
      SET @c_Message03 = 'PACKSTATION'
      SET @c_PickCondition_SQL = 'AND PICKDETAIL.UOM = ''2'' AND LOC.LocationType = ''OTHER'' AND SKUXLOC.LocationType <> ''PICK'''         
      SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM'
      SET @c_TaskType = 'FCP'
      SET @c_PickMethod = 'PP'
    
      SELECT TOP 1 @c_ToLoc = CL.Short
      FROM CODELKUP CL (NOLOCK)
      JOIN LOC (NOLOCK) ON CL.Short = LOC.Loc
      WHERE CL.Listname = 'COHLOC'
      AND CL.Storerkey = @c_Storerkey
      AND CL.Code = 'PACK'
      AND CL.Code2 = @c_DocType
    
      IF ISNULL(@c_Toloc,'') = ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83030    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid pack station setup at codelkup ''COHLOC''. (ispRLWAV42)'              
      END
      
      IF NOT EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_Toloc)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83035    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Loc not found in Loc table. (ispRLWAV42)'         
      END 

      IF @n_continue = 1 or @n_continue = 2
      BEGIN              
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
            ,@c_PickCondition_SQL     = @c_PickCondition_SQL   -- Additional condition to filter pickdetail. e.g. AND PICKDETAIL.UOM='2' AND LOC.LocationType = 'OTHER'
            ,@c_LinkTaskToPick        = 'WIP'    -- N=No update taskdetailkey to pickdetail Y=Update taskdetailkey to pickdetail  WIP=Update taskdetailkey to pickdetail_wip
            ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL   -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY
            ,@c_ReserveQtyReplen      = 'N'    -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
            ,@c_ReservePendingMoveIn  = 'N'    -- N=No update @n_qty to @n_PendingMoveIn Y=Update @n_qty to @n_PendingMoveIn           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
            ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
            ,@c_RoundUpQty            = 'N'    -- FC=Round up qty to full carton by packkey/ucc FP=Round up qty to full pallet by packkey/ucc  FL=Round up to full location qty
            ,@c_SplitTaskByCase       = 'Y'    -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
            ,@c_CasecntbyLocUCC       = 'Y'    -- N=Get casecnt by packkey Y=Get casecnt by UCC Qty of the lot,loc & ID. All UCC must have same qty.
            ,@c_ZeroSystemQty         = 'N'    -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.
            --,@c_SplitTaskByLoad       = 'Y'    -- N=No slip by load Y=Split TASK by load. Usually applicable when create task by wave.
            ,@b_Success               = @b_Success OUTPUT
            ,@n_Err                   = @n_Err     OUTPUT        
            ,@c_ErrMsg                = @c_ErrMsg  OUTPUT

         IF @b_Success <> 1
         BEGIN
            SET @n_continue = 3
         END   
         
         IF OBJECT_ID('tempdb..#TMP_PICK') IS NOT NULL
            DROP TABLE #TMP_PICK                   
      END          
   END

   --FCP Task for UOM 6 (Replenish to PTS)
   IF (@n_continue = 1 or @n_continue = 2) AND @c_PTS = '1'
   BEGIN        
      SET @c_ToLoc = ''
      SET @c_ToLoc_Strategy = ''
      SET @c_ToLoc_StrategyParam = ''
      SET @c_Message03 = 'PTS'
      SET @c_PickCondition_SQL = 'AND PICKDETAIL.UOM IN (''6'') AND LOC.LocationType = ''OTHER'' AND SKUXLOC.LocationType <> ''PICK'''         
      SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM'
      SET @c_TaskType = 'FCP'
      SET @c_PickMethod = 'PP'

      SELECT TOP 1 @c_ToLoc = CL.Short
      FROM CODELKUP CL (NOLOCK)
      JOIN LOC (NOLOCK) ON CL.Short = LOC.Loc
      WHERE CL.Listname = 'COHLOC'
      AND CL.Storerkey = @c_Storerkey
      AND CL.Code = 'PTS'
    
      IF ISNULL(@c_Toloc,'') = ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83040    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid PTS station setup at codelkup ''COHLOC''. (ispRLWAV42)'              
      END
      
      IF NOT EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_Toloc)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83045    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Loc not found in Loc table. (ispRLWAV42)'         
      END 

      IF (@n_continue = 1 OR @n_continue = 2)   --WL01
      BEGIN
         EXEC isp_CreateTaskByPick
             @c_TaskType              = @c_TaskType
            ,@c_Wavekey               = @c_Wavekey  
            ,@c_ToLoc                 = @c_ToLoc 
            ,@c_ToLoc_Strategy        = @c_ToLoc_Strategy
            ,@c_ToLoc_StrategyParam   = @c_ToLoc_StrategyParam
            ,@c_PickMethod            = @c_PickMethod   -- ?=Auto determine FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  ?ROUNDUP=Qty available - (qty - systemqty)
            ,@c_Priority              = @c_Priority      
            ,@c_Message03             = @c_Message03   
            ,@c_SourceType            = @c_SourceType      
            ,@c_SourceKey             = @c_Wavekey         
            ,@c_CallSource            = 'WAVE'  -- WAVE / LOADPLAN 
            ,@c_PickCondition_SQL     = @c_PickCondition_SQL   -- Additional condition to filter pickdetail. e.g. AND PICKDETAIL.UOM='2' AND LOC.LocationType = 'OTHER'
            ,@c_LinkTaskToPick        = 'WIP'   -- N=No update taskdetailkey to pickdetail Y=Update taskdetailkey to pickdetail  WIP=Update taskdetailkey to pickdetail_wip
            ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY
            ,@c_ReserveQtyReplen      = 'N'  -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
            ,@c_ReservePendingMoveIn  = 'Y'  -- N=No update @n_qty to @n_PendingMoveIn Y=Update @n_qty to @n_PendingMoveIn ,@c_WIP_RefNo = @c_SourceType   -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
            ,@c_WIP_RefNo             = @c_SourceType -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
            ,@c_RoundUpQty            = 'N'  -- FC=Round up qty to full carton by packkey/ucc FP=Round up qty to full pallet by packkey/ucc  FL=Round up to full location qty
            ,@c_SplitTaskByCase       = 'Y'  -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
            ,@c_CasecntbyLocUCC       = 'Y'  -- N=Get casecnt by packkey Y=Get casecnt by UCC Qty of the lot,loc & ID. All UCC must have same qty.
            ,@c_ZeroSystemQty         = 'N'  -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.
            ,@b_Success               = @b_Success OUTPUT
            ,@n_Err                   = @n_Err     OUTPUT        
            ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
         IF @b_Success <> 1
         BEGIN
            SET @n_continue = 3
         END 
      END   --WL01   
      
      IF OBJECT_ID('tempdb..#TMP_PICK') IS NOT NULL
         DROP TABLE #TMP_PICK                            
   END

   --RPF Task for UOM 7 (Replenish to Pick)
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_UOM = '7'
      
      EXEC isp_CreateReplenishTask01
          @c_Storerkey = @c_Storerkey
         ,@c_Facility = @c_Facility
         ,@c_PutawayZones = '' --putawayzone list to filter delimited by comma e.g. Zone1, Zone3, Bulkarea, Pickarea
         ,@c_SQLCondition = 'SKUXLOC.Locationtype = ''PICK'' ' --additional condition to filter the pick/dynamic loc. e.g. LOC.locationhandling = '1' AND SKUXLOC.Locationtype = 'PICK'
         ,@c_CaseLocRoundUpQty  = 'FC' --case pick loc round up qty replen from bulk. FC=Round up to full case  FP=Round up to full pallet  FL=Round up to full location qty
         ,@c_PickLocRoundUpQty  = 'FC' --pick/dynamic loc round up qty replen from bulk. FC=Round up to full case  FP=Round up to full pallet  FL=Round up to full location qty
         ,@c_CaseLocReplenPickCode  = '' --custom replen pickcode for case loc lot sorting. the sp name must start from 'nspRP'. Put 'NOPICKCODE' to use standard lot sorting. put empty to use pickcode from sku table.
         ,@c_PickLocReplenPickCode  = '' --custom replen pickcode for pick/dynamic loc lot sorting. the sp name must start from 'nspRP'. Put 'NOPICKCODE' to use standard lot sorting. put empty to use pickcode from sku table.
         ,@c_QtyReplenFormula       = 'QtyExpectedNoLocLimit' --custom formula to calculate the qty to replenish. e.g. (@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked)) - @n_PendingMoveIn 
                                          --the formula is a stadard sql statement and can apply below variables to calculate. the above example is the default.                                                    
                                          --@n_Qty, @n_QtyPicked, @n_QtyAllocated, @n_QtyLocationLimit, @n_CaseCnt, @n_Pallet, n_QtyExpected, @n_PendingMoveIn, @n_QtyExpectedFinal, @c_LocationType, @c_LocLocationType
                                          --it can pass in preset formula code. QtyExpectedFitLocLimit=try fit the overallocaton qty to location limit. usually apply when @c_BalanceExclQtyAllocated = 'Y' and do not want to replen overallocate qty exceed limit
                                          --QtyExpectedNoLocLimit=replenish overallocated qty without check location limit. 
         ,@c_Priority              = @c_Priority  --task priority default is 5 ?LOC=get the priority from skuxloc.ReplenishmentPriority  ?STOCK=calculate priority by on hand stock level against limit. if empty default is 5.
         ,@c_SplitTaskByCarton     = 'Y' --Y=Slplit the task by carton. Casecnt must set and not applicable if roundupqty is FP,FL. 
         ,@c_CasecntbyLocUCC       = 'Y' --N=Get casecnt by packkey Y=Get casecnt by UCC Qty of the lot,loc & ID. All UCC must have same qty.
         ,@c_OverAllocateOnly      = 'Y' --Y=Only replenish pick/dynamic loc with overallocated qty  N=replen loc with overallocated qty and below minimum qty.
                                          --Dynamic loc only replenish when overallocated.
         ,@c_BalanceExclQtyAllocated = 'N'  --Y=the qtyallocated is deducted when calculate loc balance. N=the qtyallocated is not deducated.
         ,@c_TaskType                = 'RPF'
         ,@c_Wavekey                 = @c_Wavekey   --set to replenish only pick/dynamic loc involved by the wave
         ,@c_Loadkey                 = ''  --set to replenish only pick/dynamic loc involved by the load
         ,@c_SourceType              = @c_SourceType
         ,@c_Message03               = 'PICKLOC'
         ,@c_PickMethod              = 'PP'
         ,@c_UOM                     = @c_UOM
         ,@n_UOMQty                  = 1
         ,@b_Success                 = @b_Success OUTPUT
         ,@n_Err                     = @n_Err     OUTPUT 
         ,@c_ErrMsg                  = @c_ErrMsg  OUTPUT    
            
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END            
   END

   --RPF Task for UOM 7 (Replenish to Pick)
   /*IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT DISTINCT LLI.Lot             
      INTO #TMP_WavePICKLOT
      FROM PICKDETAIL PD (NOLOCK)
      JOIN SKUXLOC SXL (NOLOCK) ON PD.Storerkey = SXL.Storerkey AND PD.Sku = SXL.Sku AND PD.Loc = SXL.Loc
      JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.ID = LLI.ID
      JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
      JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey
      WHERE WD.Wavekey = @c_Wavekey
      AND SXL.LocationType IN('PICK','CASE')    	 
      AND LLI.QtyExpected > 0

      DECLARE cur_PickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) AS Qty
      FROM LOTXLOCXID LLI (NOLOCK)          
      JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
      JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
      JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
      JOIN #TMP_WavePICKLOT ON LLI.Lot = #TMP_WavePICKLOT.Lot 
      JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.LOT = LLI.LOT
      WHERE SL.LocationType IN ('PICK','CASE')  
      AND LLI.Storerkey = @c_Storerkey
      AND LOC.Facility = @c_Facility  	 
      GROUP BY LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id
      HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) < 0  --overallocate
      ORDER BY MAX(LOTT.Lottable05)

      OPEN cur_PickLoc
       
      FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
         IF @n_QtyShort < 0
            SET @n_QtyShort = @n_QtyShort * -1
       	     
         SET @n_QtyReplen = @n_QtyShort
         SET @n_RemainingQty = @n_QtyReplen

         --retrieve carton from bulk 
         DECLARE cur_BulkPallet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT LLI.Lot, LLI.Loc, LLI.Id, LLI.Qty 
         FROM LOTXLOCXID LLI (NOLOCK)          
         JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
         JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
         JOIN SKU (NOLOCK) ON SKU.Storerkey = LLI.Storerkey AND SKU.SKU = LLI.SKU
         JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.LOT = LLI.LOT
         WHERE SL.LocationType NOT IN ('PICK','CASE')
         AND LOC.LocationType = 'OTHER' 
         AND (LLI.QTY - LLI.QTYPICKED - LLI.QTYALLOCATED - LLI.QtyReplen) > 0
         --AND (LLI.QtyAllocated + LLI.QtyPicked + LLI.QtyReplen) = 0
         AND LLI.Storerkey = @c_Storerkey
         AND LLI.Sku = @c_Sku
         ORDER BY LOTT.Lottable05, SL.Qty, LOC.Logicallocation, LOC.Loc, LLI.Lot

         OPEN cur_BulkPallet
         
         FETCH FROM cur_BulkPallet INTO @c_Lot, @c_FromLoc, @c_ID, @n_OnHandQty

         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_QtyReplen > 0 
         BEGIN
            SET @c_Priority = '9'  
            SET @c_SourcePriority = '9'
            SET @c_UOM = '7'
            SET @c_PickMethod = 'PP'
            SET @c_TaskType = 'RPF' 
            SET @c_Message03 = 'PICKLOC'
            SET @n_CaseCntFinal = 0

            SET @n_UCCQty = 0
            SELECT @n_UCCQty = MAX(UCC.Qty)
            FROM UCC (NOLOCK)
            WHERE UCC.Storerkey = @c_Storerkey
            AND UCC.Sku = @c_Sku
            AND UCC.Lot = @c_Lot
            AND UCC.Loc = @c_FromLoc
            AND UCC.ID = @c_ID
            AND UCC.Status <= '3'
                  
            IF ISNULL(@n_UCCQty,0) > 0
               SET @n_CaseCntFinal = @n_UCCQty

            IF @n_OnHandQty >= @n_RemainingQty                          
               SET @n_QtyTake = @n_RemainingQty
            ELSE
               SET @n_QtyTake = @n_OnHandQty   
            	
            IF @n_CaseCntFinal > 0
               SET @n_TotCtn = CEILING(@n_QtyTake / (@n_CaseCntFinal * 1.00))
            ELSE
               SET @n_TotCtn = 1
          	
            WHILE @n_TotCtn > 0 AND @n_QtyTake > 0 AND @n_continue IN(1,2)  
            BEGIN
               IF @n_QtyTake >= @n_CaseCntFinal
                  SET @n_InsertQty = @n_CaseCntFinal
               ELSE 
                  SET @n_InsertQty = @n_QtyTake
       	  	   	     
               SET @n_QtyTake = @n_QtyTake - @n_InsertQty
               SET @n_RemainingQty = @n_RemainingQty - @n_InsertQty

               EXEC isp_InsertTaskDetail   
                    @c_TaskType              = @c_TaskType        
                   ,@c_Storerkey             = @c_Storerkey
                   ,@c_Sku                   = @c_Sku
                   ,@c_Lot                   = @c_Lot 
                   ,@c_UOM                   = @c_UOM     
                   ,@n_UOMQty                = 0     
                   ,@n_Qty                   = @n_InsertQty      
                   ,@c_FromLoc               = @c_Fromloc      
                   ,@c_FromID                = @c_ID     
                   ,@c_ToLoc                 = @c_ToLoc       
                   ,@c_ToID                  = @c_ID       
                   ,@c_PickMethod            = @c_PickMethod
                   ,@c_Priority              = @c_Priority     
                   ,@c_SourcePriority        = @c_SourcePriority      
                   ,@c_SourceType            = @c_SourceType      
                   ,@c_SourceKey             = @c_wavekey      
                   ,@c_WaveKey               = @c_wavekey
                   ,@c_Message03             = @c_Message03
                   ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                   ,@c_ReservePendingMoveIn  = 'Y' --Y=Update @n_qty to @n_PendingMoveIn
                   ,@c_ReserveQtyReplen      = 'TASKQTY'  --TASKQTY=Reserve all task qty for replenish at Lotxlocxid
                   ,@c_CallSource            = 'WAVE'
                   ,@c_LinkTaskToPick        = 'WIP'  --WIP=Update taskdetailkey to pickdetail_wip
                   ,@c_LinkTaskToPick_SQL    = 'PICKDETAIL.UOM = @c_UOM '
                   ,@c_SplitTaskByCase       = 'Y'              -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
                   ,@c_CasecntbyLocUCC       = 'Y'    -- N=Get casecnt by packkey Y=Get casecnt by UCC Qty of the lot,loc & ID. All UCC must have same qty.
                   ,@c_RoundUpQty            = 'FC'  -- FC=Round up qty to full carton by packkey  FP=Round up qty to full pallet by packkey  FL=Full Location Qty
                   ,@b_Success               = @b_Success OUTPUT
                   ,@n_Err                   = @n_err OUTPUT 
                   ,@c_ErrMsg                = @c_errmsg OUTPUT       	
          	    
               IF @b_Success <> 1 
               BEGIN
                  SELECT @n_continue = 3  
               END

               IF OBJECT_ID('tempdb..#TMP_PICK') IS NOT NULL
                  DROP TABLE #TMP_PICK
               
               ----Check if still need replenish
               --IF( @n_QtyReplen >= @n_Qty )
               --   SET @n_QtyReplen = @n_QtyReplen - @n_Qty   
               --ELSE
               --   SET @n_QtyReplen = 0   
            END 
          	 
            FETCH FROM cur_BulkPallet INTO @c_Lot, @c_FromLoc, @c_ID, @n_OnHandQty
         END
         CLOSE cur_BulkPallet
         DEALLOCATE cur_BulkPallet

         FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort
      END
      CLOSE cur_PickLoc
      DEALLOCATE cur_PickLoc
   END*/

   --WL02 S
   --Assign PTS Loc to Pickdetail.Notes
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_DocType = 'N'
   BEGIN
      DECLARE CUR_PTS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT CL.Code, CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CL.Short ELSE 0 END
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'WSPTSCODE'
      AND CL.Storerkey = @c_Storerkey
      ORDER BY CL.Code ASC

      OPEN CUR_PTS

      FETCH NEXT FROM CUR_PTS INTO @c_CLCode, @c_CLShort

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE #PickDetail_WIP
         SET Notes = @c_CLCode
         WHERE OrderKey IN ( SELECT DISTINCT TOP (CAST(@c_CLShort AS INT)) PD.OrderKey
                             FROM #PickDetail_WIP PD
                             WHERE PD.WaveKey = @c_wavekey
                             AND PD.Notes = ''
                             ORDER BY PD.OrderKey)
         AND Storerkey = @c_Storerkey

         IF NOT EXISTS (SELECT 1 FROM #PickDetail_WIP PDW WHERE PDW.Notes = '')
            BREAK;

         FETCH NEXT FROM CUR_PTS INTO @c_CLCode, @c_CLShort
      END
      CLOSE CUR_PTS
      DEALLOCATE CUR_PTS
   END
   --WL02 E

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
 
   -----Generate Discrete Pickslip
   IF (@n_continue = 1 or @n_continue = 2) AND @c_DocType <> 'E'
   BEGIN
      EXEC isp_CreatePickSlip
              @c_Wavekey = @c_Wavekey
             ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
             ,@c_ConsolidateByLoad = 'N'
             ,@c_AutoScanIn = 'Y'
             ,@c_Refkeylookup = 'N'
             ,@b_Success = @b_Success OUTPUT
             ,@n_Err = @n_err OUTPUT 
             ,@c_ErrMsg = @c_errmsg OUTPUT       	
         
      IF @b_Success = 0
         SELECT @n_continue = 3   
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
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83160   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV33)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END  

RETURN_SP:
   -----Delete pickdetail_WIP work in progress staging table
   IF @n_continue = 1 or @n_continue = 2  
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
   
   IF OBJECT_ID('#PickDetail_WIP') IS NOT NULL
   BEGIN 
      DROP TABLE #PickDetail_WIP
   END

   IF OBJECT_ID('#TMP_WavePICKLOT') IS NOT NULL
   BEGIN 
      DROP TABLE #TMP_WavePICKLOT
   END

   --WL02 S
   IF CURSOR_STATUS('LOCAL', 'CUR_PTS') IN (0 , 1)
   BEGIN
      CLOSE CUR_PTS
      DEALLOCATE CUR_PTS   
   END
   --WL02 E

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
      execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV42"    
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