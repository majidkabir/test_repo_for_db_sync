SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: ispRLWAV69                                          */
/* Creation Date: 21-Mar-2024                                            */
/* Copyright: MAERSK                                                     */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: UWP-16612 - Wave Release - create VNAOUT tasks during wave   */
/*                      release for Picking                              */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* GitHub Version: 1.0                                                   */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver.  Purposes                                   */
/* 21-Mar-2024  WLChooi 1.0   DevOps Combine Script                      */
/* 23-Oct-2024  Wan01   1.1   UWP-24998 - MLP Outbound Staging Loc       */
/* 13-NOV-2024  VPA235  1.2   UWP-26879 - Change task group key to Load ID */
/* 22-NOV-2024  Wan02   1.3   FCR-1430 - Gap for Overallocation at FrontLoc*/
/* 18-Dec-2024  SSA01   1.4   UWP-28305 -update Status = 0 for FCP tasks */
/*************************************************************************/
CREATE   PROCEDURE  [dbo].[ispRLWAV69]        
    @c_Wavekey      NVARCHAR(10)    
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
     
   DECLARE @n_continue  INT
         , @n_starttcnt INT -- Holds the current transaction count    
         , @n_debug     INT
         , @n_cnt       INT
                    
   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_success = 0, @n_err = 0, @c_errmsg = '', @n_cnt = 0   
   SELECT @n_debug = @b_debug 
 
   DECLARE @c_SourceType              NVARCHAR(20)
         , @c_DocType                 NVARCHAR(10)
         , @c_Storerkey               NVARCHAR(15)
         , @c_PickMethod              NVARCHAR(10)
         , @c_ToLoc                   NVARCHAR(10)
         , @c_SourcePriority          NVARCHAR(10)
         , @c_Priority                NVARCHAR(10)
         , @c_Facility                NVARCHAR(5)
         , @c_UOM                     NVARCHAR(10)
         , @c_Message03               NVARCHAR(20)
         , @c_TaskType                NVARCHAR(10)
         , @c_curPickdetailkey        NVARCHAR(10)
         , @c_PickCondition_SQL       NVARCHAR(4000)
         , @c_LinkTaskToPick_SQL      NVARCHAR(4000)
         , @c_SKU                     NVARCHAR(20)
         , @c_Lot                     NVARCHAR(10)
         , @c_FromLoc                 NVARCHAR(10)
         , @c_ID                      NVARCHAR(20)
         , @n_UOMQty                  INT
         , @n_Qty                     INT
         , @c_Loadkey                 NVARCHAR(10)
         , @c_Taskdetailkey           NVARCHAR(10) = ''
         , @c_FinalLoc                NVARCHAR(10)
         , @c_Orderkey                NVARCHAR(10)

         , @c_RLWav_Opt5               NVARCHAR(1000) = ''                          --(Wan01) 
         , @c_LoadAssignLane           NVARCHAR(10) = 'N'                           --(Wan01)

         , @n_Qty_Pick                 INT         = 0                              --(Wan02)
         , @n_Qty_Avail                INT         = 0                              --(Wan02)
         , @n_Qty_Task                 INT         = 0                              --(Wan02)
         , @n_Qty_Alloc                INT         = 0                              --(Wan02) 
         , @c_PickDetailKey            NVARCHAR(10) = ''                            --(Wan02)            
         , @c_NewPickDetailKey         NVARCHAR(10) = ''                            --(Wan02)   
         , @CUR_UPDPICK                CURSOR                                       --(Wan02)        

   SET @c_SourceType = 'ispRLWAV69'
             
   -----Get some basic info---------------
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN        
      SELECT TOP 1 @c_Facility  = ORDERS.Facility
                 , @c_Storerkey = ORDERS.Storerkey
                 , @c_DocType   = ORDERS.DocType
      FROM WAVE (NOLOCK)  
      JOIN WAVEDETAIL (NOLOCK) ON WAVE.Wavekey = WAVEDETAIL.WaveKey  
      JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey          
      WHERE WAVE.Wavekey = @c_Wavekey  
                          
      IF @n_debug=1  
         SELECT '@c_Wavekey', @c_Wavekey, '@c_Facility', @c_Facility, '@c_DocType', @c_DocType    
   END  
   -----Wave Validation-----  
   IF @n_continue=1 OR @n_continue=2    
   BEGIN    
      IF ISNULL(@c_Wavekey,'') = ''    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @n_err = 67800    
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)+': Invalid Parameters Passed (ispRLWAV69)'    
      END    
   END      
                        
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
                 WHERE TD.Wavekey = @c_Wavekey  
                 AND TD.Sourcetype = @c_SourceType
                 AND TD.Tasktype IN ( 'VNAOUT', 'FCP' ))   
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 67805    
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)+': This Wave has been released. (ispRLWAV69)'         
      END                   
   END  

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK)
                 WHERE UserDefine09 = @c_Wavekey
                 AND (Loadkey IS NULL OR Loadkey = '') )
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 67810  
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)+': One or more orders are missing Loadkey. (ispRLWAV69)'         
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
         SELECT @n_err = 67815    
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking (ispRLWAV69)'           
      END                   
   END   

   IF @@TRANCOUNT = 0
      BEGIN TRAN

   --(Wan01) - START
   SELECT @c_RLWav_Opt5 = gr.Option5 
   FROM fnc_GetRight2 (@c_Facility, @c_Storerkey, '', 'ReleaseWave_SP') gr

   SELECT @c_LoadAssignLane = 
   dbo.fnc_GetParamValueFromString('@c_LoadAssignLane', @c_RLWav_Opt5, @c_LoadAssignLane)
   --(Wan01) - END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      IF OBJECT_ID('#PickDetail_WIP') IS NOT NULL
      BEGIN 
         DROP TABLE #PickDetail_WIP
      END

      CREATE TABLE #PickDetail_WIP
      (  
         [PickDetailKey]         [NVARCHAR](18)    NOT NULL PRIMARY KEY  
      ,  [CaseID]                [NVARCHAR](20)    NOT NULL DEFAULT (' ')  
      ,  [PickHeaderKey]         [NVARCHAR](18)    NOT NULL  
      ,  [OrderKey]              [NVARCHAR](10)    NOT NULL  
      ,  [OrderLineNumber]       [NVARCHAR](5)     NOT NULL  
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
      JOIN #PickDetail_WIP PICKDETAIL WITH (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey   
  
      OPEN Orders_Pickdet_cur   
      FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey

      WHILE @@FETCH_STATUS = 0   
      BEGIN   
         UPDATE #PickDetail_WIP WITH (ROWLOCK)   
         SET #PickDetail_WIP.TaskdetailKey = '', 
             #PickDetail_WIP.Notes = '',   
             #PickDetail_WIP.Wavekey = @c_Wavekey,   
             EditWho    = SUSER_SNAME(),  
             EditDate   = GETDATE(),     
             TrafficCop = NULL  
         WHERE #PickDetail_WIP.Pickdetailkey = @c_curPickdetailkey
          
         SELECT @n_err = @@ERROR  

         IF @n_err <> 0   
         BEGIN  
            CLOSE Orders_Pickdet_cur   
            DEALLOCATE Orders_Pickdet_cur
            
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 678   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV69)' + ' ( ' + ' SQLSvr MESSAGE=' + TRIM(@c_errmsg) + ' ) '    
         END    

         FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey  
      END  
      CLOSE Orders_Pickdet_cur   
      DEALLOCATE Orders_Pickdet_cur  
   END 

   --VNAOUT for UOM 1 (Pallet Pick)
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE CUR_PICK_VNAOUT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
       SELECT PICKDETAIL.Storerkey 
            , PICKDETAIL.Sku 
            , PICKDETAIL.Lot
            , PICKDETAIL.Loc 
            , PICKDETAIL.ID 
            , MAX(PICKDETAIL.UOM) 
            , SUM(PICKDETAIL.UOMQty) AS UOMQty 
            , SUM(PICKDETAIL.Qty) AS Qty 
            , ORDERS.LoadKey
            , ORDERS.OrderKey
       FROM WAVEDETAIL (NOLOCK) 
       JOIN WAVE (NOLOCK) ON WAVEDETAIL.WaveKey = WAVE.WaveKey 
       JOIN ORDERS (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey 
       JOIN #PickDetail_WIP PICKDETAIL (NOLOCK) ON ORDERS.OrderKey = PICKDETAIL.OrderKey 
       JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.LOC
       WHERE WAVEDETAIL.WaveKey = @c_Wavekey  
       AND PICKDETAIL.[Status] = '0'  
       AND PICKDETAIL.WIP_Refno = @c_SourceType 
     --AND PICKDETAIL.UOM = '1'                  VPA235
       AND PICKDETAIL.UOM IN ( '1','6')
       AND LOC.LocationType = 'VNA'
       GROUP BY PICKDETAIL.Storerkey 
            , PICKDETAIL.Sku 
            , PICKDETAIL.Lot
            , PICKDETAIL.Loc 
            , PICKDETAIL.ID 
            , ORDERS.LoadKey
            , ORDERS.OrderKey

      OPEN CUR_PICK_VNAOUT

      FETCH NEXT FROM CUR_PICK_VNAOUT INTO @c_Storerkey, @c_SKU, @c_Lot, @c_FromLoc, @c_ID, @c_UOM, @n_UOMQty, @n_Qty, @c_Loadkey, @c_Orderkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_ToLoc = N''
         SET @c_FinalLoc = N''
         SET @c_PickMethod = N'FP'
         SET @c_TaskType = N'VNAOUT'
         SET @c_Message03 = N'FPK'
         SET @c_SourcePriority = '9'
         SET @c_Priority = '4'

         SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND LOC.LocationType = ''VNA'' '

         --(Wan01) - START
         IF @c_LoadAssignLane = 'Y'
         BEGIN
            IF @c_Loadkey <> '' OR @c_Loadkey IS NULL
            BEGIN 
               SELECT TOP 1 @c_FinalLoc = lpld.Loc
               FROM LoadPlanLaneDetail lpld(NOLOCK) 
               WHERE lpld.Loadkey = @c_Loadkey
               AND   lpld.LocationCategory = 'STAGING'
            END
         END
         ELSE
         BEGIN
            SELECT @c_FinalLoc = ISNULL(ORDERS.Door, '')
            FROM ORDERS WITH (NOLOCK)
            WHERE ORDERS.OrderKey = @c_Orderkey
         END
         --(Wan01) - END

         IF ISNULL(@c_FinalLoc,'') = ''
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 67820    
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)
                             +': Invalid Outbound Staging Loc from '
                             + CASE WHEN @c_LoadAssignLane = 'Y'                    --(Wan01)
                                    THEN 'Assign Lane'
                                    ELSE 'ORDERS.Door'
                                    END
                             +'. (ispRLWAV69)'                
         END
         ELSE IF NOT EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_FinalLoc)
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 67825    
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)+': Loc not found in Loc table. (ispRLWAV69)'         
         END 
         ELSE
         BEGIN
            SET @c_Taskdetailkey = ''
            EXEC isp_InsertTaskDetail @c_TaskType = @c_TaskType
                                    , @c_Storerkey = @c_Storerkey
                                    , @c_Sku = @c_Sku
                                    , @c_Lot = @c_Lot
                                    , @c_UOM = @c_UOM
                                    , @n_UOMQty = @n_UOMQty
                                    , @n_Qty = @n_Qty
                                    , @c_FromLoc = @c_FromLoc
                                    , @c_LogicalFromLoc = '?'
                                    , @c_FromID = @c_ID
                                    , @c_ToLoc = @c_FinalLoc
                                    , @c_LogicalToLoc = '?'
                                    , @c_ToID = @c_ID
                                    , @c_FinalID = @c_ID
                                    , @c_PickMethod = @c_PickMethod
                                    , @c_Priority = @c_Priority
                                    , @c_SourcePriority = @c_SourcePriority
                                    , @c_SourceType = @c_SourceType
                                    , @c_SourceKey = @c_Wavekey
                                    , @c_WaveKey = @c_Wavekey
                                    , @c_Loadkey = @c_Loadkey
                                    , @c_OrderKey = @c_Orderkey
                                    , @c_Message03 = @c_Message03
                                    , @n_SystemQty = @n_Qty
                                    , @c_FinalLoc = @c_FinalLoc
                                    , @c_Status = 'Q'
                                    , @c_AreaKey = '?F' -- ?F=Get from location areakey  
                                    , @c_UserPosition = '1'
                                    , @c_CallSource = 'WAVE'
                                    , @c_LinkTaskToPick = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip  
                                    , @c_LinkTaskToPick_SQL = @c_LinkTaskToPick_SQL
                                    , @c_WIP_RefNo = @c_SourceType
                                    , @b_Success = @b_Success OUTPUT
                                    , @n_Err = @n_err OUTPUT
                                    , @c_ErrMsg = @c_errmsg OUTPUT
                                    , @c_Taskdetailkey = @c_Taskdetailkey OUTPUT
            
            IF @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3
            END
            
            UPDATE TASKDETAIL
            SET Groupkey = @c_Taskdetailkey
            WHERE TaskDetailKey = @c_Taskdetailkey
            
            --Manual Lock Qty for FinalLoc
            --EXEC rdt.rdt_Putaway_PendingMoveIn 
            --             @cUserName = ''
            --            ,@cType = 'LOCK'
            --            ,@cFromLoc = @c_FromLoc
            --            ,@cFromID = @c_ID
            --            ,@cSuggestedLOC = @c_FinalLoc
            --            ,@cStorerKey = @c_Storerkey
            --            ,@nErrNo = @n_Err OUTPUT
            --            ,@cErrMsg = @c_Errmsg OUTPUT
            --            ,@cSKU = @c_Sku
            --            ,@nPutawayQTY    = @n_Qty
            --            ,@cFromLOT       = @c_Lot
            --            ,@cTaskDetailKey = @c_TaskdetailKey
            --            ,@nFunc = 0
            --            ,@nPABookingKey = 0
            --            ,@cMoveQTYAlloc = '1' 
         END

         FETCH NEXT FROM CUR_PICK_VNAOUT INTO @c_Storerkey, @c_SKU, @c_Lot, @c_FromLoc, @c_ID, @c_UOM, @n_UOMQty, @n_Qty, @c_Loadkey, @c_Orderkey
      END
      CLOSE CUR_PICK_VNAOUT
      DEALLOCATE CUR_PICK_VNAOUT
   END

   --FCP Task for UOM 2/3
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE CUR_PICK_FCP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
       SELECT PICKDETAIL.Storerkey 
            , PICKDETAIL.Sku 
            , PICKDETAIL.Lot
            , PICKDETAIL.Loc 
            , PICKDETAIL.ID 
            , MAX(PICKDETAIL.UOM) 
            , SUM(PICKDETAIL.UOMQty) AS UOMQty 
            , SUM(PICKDETAIL.Qty) AS Qty 
            , ORDERS.LoadKey
            , ORDERS.OrderKey
       FROM WAVEDETAIL (NOLOCK) 
       JOIN WAVE (NOLOCK) ON WAVEDETAIL.WaveKey = WAVE.WaveKey 
       JOIN ORDERS (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey 
       JOIN #PickDetail_WIP PICKDETAIL (NOLOCK) ON ORDERS.OrderKey = PICKDETAIL.OrderKey 
       JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.LOC
       WHERE WAVEDETAIL.WaveKey = @c_Wavekey  
       AND PICKDETAIL.[Status] = '0'  
       AND PICKDETAIL.WIP_Refno = @c_SourceType 
       AND PICKDETAIL.UOM IN ('2','3')
       AND LOC.LocationType = 'VNA'
       GROUP BY PICKDETAIL.Storerkey 
            , PICKDETAIL.Sku 
            , PICKDETAIL.Lot
            , PICKDETAIL.Loc 
            , PICKDETAIL.ID 
            , ORDERS.LoadKey
            , ORDERS.OrderKey

      OPEN CUR_PICK_FCP

      FETCH NEXT FROM CUR_PICK_FCP INTO @c_Storerkey, @c_SKU, @c_Lot, @c_FromLoc, @c_ID, @c_UOM, @n_UOMQty, @n_Qty, @c_Loadkey, @c_Orderkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_ToLoc = N''
         SET @c_FinalLoc = N''
         SET @c_PickMethod = N'PP'
         SET @c_TaskType = N'FCP'
         SET @c_Message03 = N'FPK'
         SET @c_SourcePriority = '9'
         SET @c_Priority = '9'
         SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND LOC.LocationType = ''VNA'' '

         --(Wan01) - START
         IF @c_LoadAssignLane = 'Y'
         BEGIN
            IF @c_Loadkey <> '' OR @c_Loadkey IS NULL
            BEGIN 
               SELECT TOP 1 @c_ToLoc = lpld.Loc
               FROM LoadPlanLaneDetail lpld(NOLOCK) 
               WHERE lpld.Loadkey = @c_Loadkey
               AND   lpld.LocationCategory = 'STAGING'
            END
         END
         ELSE
         BEGIN
            SELECT @c_ToLoc = ISNULL(ORDERS.Door, '')
            FROM ORDERS WITH (NOLOCK)
            WHERE ORDERS.OrderKey = @c_Orderkey
         END
         --(Wan01) - END

         IF ISNULL(@c_ToLoc,'') = ''
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 67830    
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)
                             +': Invalid Outbound Staging Loc from '
                             + CASE WHEN @c_LoadAssignLane = 'Y'                    --(Wan01)
                                    THEN 'Assign Lane'
                                    ELSE 'ORDERS.Door'
                                    END
                             +'. (ispRLWAV69)'                
                   
         END
         ELSE IF NOT EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_ToLoc)
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 67835    
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)+': Loc not found in Loc table. (ispRLWAV69)'         
         END 
         ELSE
         BEGIN
            --(Wan02) - START
            SET @n_Qty_Pick = @n_Qty
            SET @n_Qty_Avail = 0
            SET @n_Qty_Task  = 0

            SELECT @n_Qty_Avail = lli.Qty - lli.Qtypicked
            FROM LOTxLOCxID lli (NOLOCK)
            WHERE lli.Lot = @c_Lot
            AND   lli.Loc = @c_FromLoc
            AND   lli.ID  = @c_ID

            IF @n_Qty_Avail > 0
            BEGIN
               SELECT @n_Qty_Task = ISNULL(SUM(qty),0)
               FROM TaskDetail td(NOLOCK)
               WHERE td.Storerkey= @c_Storerkey
               AND   td.Sku      = @c_Sku
               AND   td.Tasktype = 'FCP'
               AND   td.Lot      = @c_Lot
               AND   td.FromLoc  = @c_FromLoc
               AND   td.FromID   = @c_ID
               AND   td.[Status] NOT IN ('X', '9')
               AND   td.CaseID   = ''

               SET @n_Qty_Avail = @n_Qty_Avail - @n_Qty_Task
            END

            WHILE @n_Qty_Pick > 0 AND @n_continue = 1
            BEGIN
               
               IF @n_Qty_Pick > @n_Qty_Avail AND @n_Qty_Avail > 0
               BEGIN
                  SET @n_Qty = @n_Qty_Avail
               END
               ELSE
               BEGIN
                  SET @n_Qty = @n_Qty_Pick
               END

               SET @n_Qty_Pick = @n_Qty_Pick - @n_Qty                 

               SET @c_Taskdetailkey = ''
               EXEC isp_InsertTaskDetail @c_TaskType = @c_TaskType
                                       , @c_Storerkey = @c_Storerkey
                                       , @c_Sku = @c_Sku
                                       , @c_Lot = @c_Lot
                                       , @c_UOM = @c_UOM
                                       , @n_UOMQty = @n_UOMQty
                                       , @n_Qty = @n_Qty
                                       , @c_FromLoc = @c_FromLoc
                                       , @c_LogicalFromLoc = '?'
                                       , @c_FromID = @c_ID
                                       , @c_ToLoc = @c_ToLoc
                                       , @c_LogicalToLoc = '?'
                                       , @c_ToID = @c_ID
                                       , @c_FinalID = @c_ID
                                       , @c_PickMethod = @c_PickMethod
                                       , @c_Priority = @c_Priority
                                       , @c_SourcePriority = @c_SourcePriority
                                       , @c_SourceType = @c_SourceType
                                       , @c_SourceKey = @c_Wavekey
                                       , @c_WaveKey = @c_Wavekey
                                       , @c_Loadkey = @c_Loadkey
                                       , @c_OrderKey = @c_Orderkey
                                       , @c_Message03 = @c_Message03
                                       , @n_SystemQty = @n_Qty
                                       , @c_Status = '0'        --(SSA01)
                                       , @c_AreaKey = '?F' -- ?F=Get from location areakey  
                                       , @c_UserPosition = '1'
                                       , @c_CallSource = 'WAVE'
                                       , @c_ReservePendingMoveIn = 'Y'
                                       , @c_LinkTaskToPick = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip  
                                       , @c_LinkTaskToPick_SQL = @c_LinkTaskToPick_SQL
                                       , @c_WIP_RefNo = @c_SourceType
                                       , @b_Success = @b_Success OUTPUT
                                       , @n_Err = @n_err OUTPUT
                                       , @c_ErrMsg = @c_errmsg OUTPUT
                                       , @c_Taskdetailkey = @c_Taskdetailkey OUTPUT
            
               IF @b_Success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            
               IF @n_continue = 1
               BEGIN
                  UPDATE TASKDETAIL
              --  SET Groupkey = @c_Taskdetailkey                       VPA235
                  SET Groupkey = @c_Loadkey
                  WHERE TaskDetailKey = @c_Taskdetailkey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_continue = 3
                  END
               END
            END                                                      --(Wan02) - END
         END

         FETCH NEXT FROM CUR_PICK_FCP INTO @c_Storerkey, @c_SKU, @c_Lot, @c_FromLoc, @c_ID, @c_UOM, @n_UOMQty, @n_Qty, @c_Loadkey, @c_Orderkey
      END
      CLOSE CUR_PICK_FCP
      DEALLOCATE CUR_PICK_FCP
   END

   --NONVNA
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE CUR_PICK_NONVNA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
       SELECT PICKDETAIL.Storerkey 
            , PICKDETAIL.Sku 
            , PICKDETAIL.Lot
            , PICKDETAIL.Loc 
            , PICKDETAIL.ID 
            , MAX(PICKDETAIL.UOM) 
            , SUM(PICKDETAIL.UOMQty) AS UOMQty 
            , SUM(PICKDETAIL.Qty) AS Qty 
            , ORDERS.LoadKey
            , ORDERS.OrderKey
       FROM WAVEDETAIL (NOLOCK) 
       JOIN WAVE (NOLOCK) ON WAVEDETAIL.WaveKey = WAVE.WaveKey 
       JOIN ORDERS (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey 
       JOIN #PickDetail_WIP PICKDETAIL (NOLOCK) ON ORDERS.OrderKey = PICKDETAIL.OrderKey 
       JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.LOC
       WHERE WAVEDETAIL.WaveKey = @c_Wavekey  
       AND PICKDETAIL.[Status] = '0'  
       AND PICKDETAIL.WIP_Refno = @c_SourceType 
       AND LOC.LocationType <> 'VNA'
       GROUP BY PICKDETAIL.Storerkey 
              , PICKDETAIL.Sku 
              , PICKDETAIL.Lot
              , PICKDETAIL.Loc 
              , PICKDETAIL.ID 
              , ORDERS.LoadKey
              , ORDERS.OrderKey
              , PICKDETAIL.UOM
       ORDER BY PICKDETAIL.UOM, PICKDETAIL.Sku, PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.ID

      OPEN CUR_PICK_NONVNA

      FETCH NEXT FROM CUR_PICK_NONVNA INTO @c_Storerkey, @c_SKU, @c_Lot, @c_FromLoc, @c_ID, @c_UOM, @n_UOMQty, @n_Qty, @c_Loadkey, @c_Orderkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_ToLoc = N''
         SET @c_FinalLoc = N''
         SET @c_PickMethod = IIF(@c_UOM = '1', N'FP', N'PP')
         SET @c_TaskType = IIF(@c_UOM = '1', N'FPK', N'FCP')
         SET @c_Message03 = N'FPK'
         SET @c_SourcePriority = '9'
         SET @c_Priority = '9'

         SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND LOC.LocationType <> ''VNA'' '

         --(Wan01) - START
         IF @c_LoadAssignLane = 'Y'  
         BEGIN
            IF @c_Loadkey <> '' OR @c_Loadkey IS NULL
            BEGIN 
               SELECT TOP 1 @c_ToLoc = lpld.Loc
               FROM LoadPlanLaneDetail lpld(NOLOCK) 
               WHERE lpld.Loadkey = @c_Loadkey
               AND   lpld.LocationCategory = 'STAGING'
            END
         END
         ELSE
         BEGIN
            SELECT @c_ToLoc = ISNULL(ORDERS.Door, '')
            FROM ORDERS WITH (NOLOCK)
            WHERE ORDERS.OrderKey = @c_Orderkey
         END
         --(Wan01) - END

         IF ISNULL(@c_ToLoc,'') = ''
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 67845    
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)
                             +': Invalid Outbound Staging Loc from '
                             + CASE WHEN @c_LoadAssignLane = 'Y'                    --(Wan01)
                                    THEN 'Assign Lane'
                                    ELSE 'ORDERS.Door'
                                    END
                             +'. (ispRLWAV69)'                
              END
         ELSE IF NOT EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_ToLoc)
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 67850    
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)+': Loc not found in Loc table. (ispRLWAV69)'         
         END 
         ELSE
         BEGIN
            --(Wan02) - START
            SET @n_Qty_Pick  = @n_Qty
            SET @n_Qty_Avail = 0
            SET @n_Qty_Task  = 0

            IF @c_UOM IN ('2','3') 
            BEGIN
               SELECT @n_Qty_Avail = lli.Qty - lli.Qtypicked
               FROM LOTxLOCxID lli (NOLOCK)
               WHERE lli.Lot = @c_Lot
               AND   lli.Loc = @c_FromLoc
               AND   lli.ID  = @c_ID

               IF @n_Qty_Avail > 0
               BEGIN
                  SELECT @n_Qty_Task = ISNULL(SUM(qty),0)
                  FROM TaskDetail td(NOLOCK)
                  WHERE td.Storerkey= @c_Storerkey
                  AND   td.Sku      = @c_Sku
                  AND   td.Tasktype = 'FCP'
                  AND   td.Lot      = @c_Lot
                  AND   td.FromLoc  = @c_FromLoc
                  AND   td.FromID   = @c_ID
                  AND   td.[Status] NOT IN ('X', '9')
                  AND   td.CaseID   = ''

                  SET @n_Qty_Avail = @n_Qty_Avail - @n_Qty_Task
               END
            END

            WHILE @n_Qty_Pick > 0 AND @n_Continue = 1
            BEGIN
               IF @n_Qty_Pick > @n_Qty_Avail AND @n_Qty_Avail > 0
               BEGIN
                  SET @n_Qty = @n_Qty_Avail
               END               
               ELSE
               BEGIN
                  SET @n_Qty = @n_Qty_Pick
               END
               SET @n_Qty_Pick = @n_Qty_Pick - @n_Qty     

               SET @c_Taskdetailkey = ''
               EXEC isp_InsertTaskDetail @c_TaskType = @c_TaskType
                                       , @c_Storerkey = @c_Storerkey
                                       , @c_Sku = @c_Sku
                                       , @c_Lot = @c_Lot
                                       , @c_UOM = @c_UOM
                                       , @n_UOMQty = @n_UOMQty
                                       , @n_Qty = @n_Qty
                                       , @c_FromLoc = @c_FromLoc
                                       , @c_LogicalFromLoc = '?'
                                       , @c_FromID = @c_ID
                                       , @c_ToLoc = @c_ToLoc
                                       , @c_LogicalToLoc = '?'
                                       , @c_ToID = @c_ID
                                       , @c_FinalID = @c_ID
                                       , @c_PickMethod = @c_PickMethod
                                       , @c_Priority = @c_Priority
                                       , @c_SourcePriority = @c_SourcePriority
                                       , @c_SourceType = @c_SourceType
                                       , @c_SourceKey = @c_Wavekey
                                       , @c_WaveKey = @c_Wavekey
                                       , @c_Loadkey = @c_Loadkey
                                       , @c_OrderKey = @c_Orderkey
                                       , @c_Message03 = @c_Message03
                                       , @n_SystemQty = @n_Qty
                                       , @c_Status = '0'
                                       , @c_AreaKey = '?F' -- ?F=Get from location areakey  
                                       , @c_UserPosition = '1'
                                       , @c_CallSource = 'WAVE'
                                       , @c_LinkTaskToPick = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip  
                                       , @c_LinkTaskToPick_SQL = @c_LinkTaskToPick_SQL
                                       , @c_WIP_RefNo = @c_SourceType
                                       , @b_Success = @b_Success OUTPUT
                                       , @n_Err = @n_err OUTPUT
                                       , @c_ErrMsg = @c_errmsg OUTPUT
                                       , @c_Taskdetailkey = @c_Taskdetailkey OUTPUT
            
               IF @b_Success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            
               IF @n_continue = 1
               BEGIN
                  UPDATE TASKDETAIL
            --    SET Groupkey = @c_Taskdetailkey              VPA235
                  SET Groupkey = @c_Loadkey
                  WHERE TaskDetailKey = @c_Taskdetailkey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_continue = 3
                  END
               END
            END                                                      --(Wan02) - END
         END

         FETCH NEXT FROM CUR_PICK_NONVNA INTO @c_Storerkey, @c_SKU, @c_Lot, @c_FromLoc, @c_ID, @c_UOM, @n_UOMQty, @n_Qty, @c_Loadkey, @c_Orderkey
      END
      CLOSE CUR_PICK_NONVNA
      DEALLOCATE CUR_PICK_NONVNA
   END

   -----Update pickdetail_WIP work in progress staging table back to pickdetail 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP
          @c_Loadkey               = ''
         ,@c_Wavekey               = @c_Wavekey  
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
   --IF (@n_continue = 1 or @n_continue = 2) AND @c_DocType = 'N'
   --BEGIN
   --   EXEC isp_CreatePickSlip
   --           @c_Wavekey = @c_Wavekey
   --          ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
   --          ,@c_ConsolidateByLoad = 'N'
   --          ,@c_AutoScanIn = 'Y'
   --          ,@c_Refkeylookup = 'N'
   --          ,@b_Success = @b_Success OUTPUT
   --          ,@n_Err = @n_err OUTPUT 
   --          ,@c_ErrMsg = @c_errmsg OUTPUT          
         
   --   IF @b_Success = 0
   --      SELECT @n_continue = 3   
   --END  

   -----Update Wave Status-----
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      UPDATE WAVE     
      SET TMReleaseFlag = 'Y'             
       ,  TrafficCop = NULL               
       ,  EditWho = SUSER_SNAME()         
       ,  EditDate= GETDATE()             
      WHERE WAVEKEY = @c_Wavekey      
   
      SELECT @n_err = @@ERROR
        
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67840   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV69)' + ' ( ' + ' SQLSvr MESSAGE=' + TRIM(@c_errmsg) + ' ) '  
      END  
   END  

   RETURN_SP:
   -----Delete pickdetail_WIP work in progress staging table
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN
      EXEC isp_CreatePickdetail_WIP
          @c_Loadkey               = ''
         ,@c_Wavekey               = @c_Wavekey  
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

   IF CURSOR_STATUS('LOCAL', 'Orders_Pickdet_cur') IN (0 , 1)
   BEGIN
      CLOSE Orders_Pickdet_cur
      DEALLOCATE Orders_Pickdet_cur   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_PICK_VNAOUT') IN (0 , 1)
   BEGIN
      CLOSE CUR_PICK_VNAOUT
      DEALLOCATE CUR_PICK_VNAOUT   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_PICK_FCP') IN (0 , 1)
   BEGIN
      CLOSE CUR_PICK_FCP
      DEALLOCATE CUR_PICK_FCP   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_PICK_NONVNA') IN (0 , 1)
   BEGIN
      CLOSE CUR_PICK_NONVNA
      DEALLOCATE CUR_PICK_NONVNA   
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV69'    
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