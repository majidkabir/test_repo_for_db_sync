SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: ispRLWAV63                                          */
/* Creation Date: 14-Jun-2023                                            */
/* Copyright: MAERSK                                                     */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-22786 - [TW]PUMA_WaveReleaseTask_CR                      */
/*                                                                       */
/* Called By: Wave                                                       */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 14-Jun-2023  WLChooi  1.0  DevOps Combine Script                      */
/* 21-Sep-2023  WLChooi  1.1  WMS-22786 - Fix missing taskdetailkey(WL01)*/
/*************************************************************************/
CREATE   PROCEDURE [dbo].[ispRLWAV63]
   @c_Wavekey NVARCHAR(10)
 , @b_Success INT           OUTPUT
 , @n_err     INT           OUTPUT
 , @c_errmsg  NVARCHAR(250) OUTPUT
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

   SELECT @n_starttcnt = @@TRANCOUNT
        , @n_continue = 1
        , @b_Success = 0
        , @n_err = 0
        , @c_errmsg = ''
        , @n_cnt = 0
        , @n_debug = 0

   DECLARE @c_Storerkey          NVARCHAR(15)
         , @c_Facility           NVARCHAR(5)
         , @c_TaskType           NVARCHAR(10)
         , @c_SourceType         NVARCHAR(30)
         , @c_WaveType           NVARCHAR(10)
         , @c_Sku                NVARCHAR(20)
         , @c_Lot                NVARCHAR(10)
         , @c_FromLoc            NVARCHAR(10)
         , @c_ID                 NVARCHAR(18)
         , @n_Qty                INT
         , @c_UOM                NVARCHAR(10)
         , @n_UOMQty             INT
         , @c_Orderkey           NVARCHAR(10)
         , @c_Groupkey           NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
         , @c_Priority           NVARCHAR(10)
         , @c_PickMethod         NVARCHAR(10)
         , @c_Message03          NVARCHAR(20)
         , @c_LinkTaskToPick_SQL NVARCHAR(4000)
         , @c_SortingSeq         NVARCHAR(4000)
         , @c_SortingSeq_FCP     NVARCHAR(4000)
         , @c_SortingSeq_FPP     NVARCHAR(4000)
         , @c_SQL                NVARCHAR(MAX)
         , @c_DefaultLoc         NVARCHAR(20)
         , @c_Route              NVARCHAR(20)
         , @n_PKZoneCnt          INT
         , @n_AisleZoneCnt       INT
         , @c_Loadkey            NVARCHAR(10)

   SET @c_SourceType = N'ispRLWAV63'
   SET @c_Priority = N'9'
   SET @c_TaskType = N''
   SET @c_PickMethod = N'PP'

   -----Wave Validation-----              
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF NOT EXISTS (  SELECT 1
                       FROM WAVEDETAIL WD (NOLOCK)
                       JOIN PICKDETAIL PD (NOLOCK) ON WD.OrderKey = PD.OrderKey
                       LEFT JOIN TaskDetail TD (NOLOCK) ON  PD.TaskDetailKey = TD.TaskDetailKey
                                                        AND TD.SourceType = @c_SourceType
                                                        AND TD.TaskType = @c_TaskType
                       WHERE WD.WaveKey = @c_Wavekey AND PD.Status = '0' AND TD.TaskDetailKey IS NULL)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 83010
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Nothing to release. (ispRLWAV63)'
      END
   END

   --Create pickdetail Work in progress temporary table  
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      CREATE TABLE #PickDetail_WIP
      (
         [PickDetailKey]        [NVARCHAR](18)   NOT NULL PRIMARY KEY
       , [CaseID]               [NVARCHAR](20)   NOT NULL DEFAULT (' ')
       , [PickHeaderKey]        [NVARCHAR](18)   NOT NULL
       , [OrderKey]             [NVARCHAR](10)   NOT NULL
       , [OrderLineNumber]      [NVARCHAR](5)    NOT NULL
       , [Lot]                  [NVARCHAR](10)   NOT NULL
       , [Storerkey]            [NVARCHAR](15)   NOT NULL
       , [Sku]                  [NVARCHAR](20)   NOT NULL
       , [AltSku]               [NVARCHAR](20)   NOT NULL DEFAULT (' ')
       , [UOM]                  [NVARCHAR](10)   NOT NULL DEFAULT (' ')
       , [UOMQty]               [INT]            NOT NULL DEFAULT ((0))
       , [Qty]                  [INT]            NOT NULL DEFAULT ((0))
       , [QtyMoved]             [INT]            NOT NULL DEFAULT ((0))
       , [Status]               [NVARCHAR](10)   NOT NULL DEFAULT ('0')
       , [DropID]               [NVARCHAR](20)   NOT NULL DEFAULT ('')
       , [Loc]                  [NVARCHAR](10)   NOT NULL DEFAULT ('UNKNOWN')
       , [ID]                   [NVARCHAR](18)   NOT NULL DEFAULT (' ')
       , [PackKey]              [NVARCHAR](10)   NULL DEFAULT (' ')
       , [UpdateSource]         [NVARCHAR](10)   NULL DEFAULT ('0')
       , [CartonGroup]          [NVARCHAR](10)   NULL
       , [CartonType]           [NVARCHAR](10)   NULL
       , [ToLoc]                [NVARCHAR](10)   NULL DEFAULT (' ')
       , [DoReplenish]          [NVARCHAR](1)    NULL DEFAULT ('N')
       , [ReplenishZone]        [NVARCHAR](10)   NULL DEFAULT (' ')
       , [DoCartonize]          [NVARCHAR](1)    NULL DEFAULT ('N')
       , [PickMethod]           [NVARCHAR](1)    NOT NULL DEFAULT (' ')
       , [WaveKey]              [NVARCHAR](10)   NOT NULL DEFAULT (' ')
       , [EffectiveDate]        [DATETIME]       NOT NULL DEFAULT (GETDATE())
       , [AddDate]              [DATETIME]       NOT NULL DEFAULT (GETDATE())
       , [AddWho]               [NVARCHAR](128)  NOT NULL DEFAULT (SUSER_SNAME())
       , [EditDate]             [DATETIME]       NOT NULL DEFAULT (GETDATE())
       , [EditWho]              [NVARCHAR](128)  NOT NULL DEFAULT (SUSER_SNAME())
       , [TrafficCop]           [NVARCHAR](1)    NULL
       , [ArchiveCop]           [NVARCHAR](1)    NULL
       , [OptimizeCop]          [NVARCHAR](1)    NULL
       , [ShipFlag]             [NVARCHAR](1)    NULL DEFAULT ('0')
       , [PickSlipNo]           [NVARCHAR](10)   NULL
       , [TaskDetailKey]        [NVARCHAR](10)   NULL
       , [TaskManagerReasonKey] [NVARCHAR](10)   NULL
       , [Notes]                [NVARCHAR](4000) NULL
       , [MoveRefKey]           [NVARCHAR](10)   NULL DEFAULT ('')
       , [WIP_Refno]            [NVARCHAR](30)   NULL DEFAULT ('')
       , [Channel_ID]           [BIGINT]         NULL DEFAULT ((0))
      )
   END

   IF @@TRANCOUNT = 0
      BEGIN TRAN

   -----Get Storerkey and facility  
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT TOP 1 @c_Storerkey = O.StorerKey
                 , @c_Facility = O.Facility
                 , @c_WaveType = W.WaveType
                 , @c_TaskType = CL.code2
      FROM WAVE W (NOLOCK)
      JOIN WAVEDETAIL WD (NOLOCK) ON W.WaveKey = WD.WaveKey
      JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
      JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'WAVETYPE' AND CL.Code = W.WaveType AND CL.Storerkey = O.StorerKey
      WHERE W.WaveKey = @c_Wavekey

      CREATE TABLE #TMP_Orderkey(
         Orderkey      NVARCHAR(10),
         PKZoneCnt     INT,
         AisleZoneCnt  INT 
      )
       
      INSERT INTO #TMP_Orderkey (Orderkey, PKZoneCnt, AisleZoneCnt)
      SELECT PD.Orderkey,
             COUNT(DISTINCT(Loc.Pickzone)),
             COUNT(DISTINCT(Loc.LocAisle)) 
      FROM PICKDETAIL PD (NOLOCK)
      JOIN Loc (NOLOCK) ON PD.Loc = Loc.Loc
      JOIN WAVEDETAIL WD (NOLOCK) ON PD.OrderKey = WD.OrderKey
      WHERE WD.WaveKey = @c_Wavekey   
      GROUP BY PD.Orderkey 
         
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT @c_SortingSeq = ISNULL(Option5,'')
      FROM Storerconfig (NOLOCK)
      WHERE Storerkey = @c_Storerkey AND Configkey = 'ReleaseWave_SP' 	
      AND SValue = @c_SourceType

      SET @c_SortingSeq_FCP = dbo.fnc_GetParamValueFromString('@c_SortingSeq_FCP', @c_SortingSeq, @c_SortingSeq_FCP)
      SET @c_SortingSeq_FPP = dbo.fnc_GetParamValueFromString('@c_SortingSeq_FPP', @c_SortingSeq, @c_SortingSeq_FPP)

      IF ISNULL(@c_SortingSeq_FCP,'') = ''
      BEGIN
         SET @c_SortingSeq_FCP = N' LOC.PickZone, LOC.LogicalLocation, PICKDETAIL.Loc, PICKDETAIL.SKU '
      END

      IF ISNULL(@c_SortingSeq_FPP,'') = ''
      BEGIN
         SET @c_SortingSeq_FPP = N' Taskdetail.Priority, @pkzonecnt, @aislezonecnt, Loc.Pickzone, Orders.Consigneekey, Orders.Orderkey, 
                                Loc.LogicalLocation, Pickdetail.Loc, Pickdetail.Sku '
      END

      SET @c_SortingSeq_FPP = REPLACE(@c_SortingSeq_FPP,'@pkzonecnt','OK.PKZoneCnt')
      SET @c_SortingSeq_FPP = REPLACE(@c_SortingSeq_FPP,'@aislezonecnt','OK.AisleZoneCnt')
      SET @c_SortingSeq_FPP = REPLACE(@c_SortingSeq_FPP,'Taskdetail.Priority','Priority')
      SET @c_SortingSeq_FPP = REPLACE(@c_SortingSeq_FPP,'ORDERS.','O.')
      SET @c_SortingSeq_FPP = REPLACE(@c_SortingSeq_FPP,'PICKDETAIL.','PD.')
      SET @c_SortingSeq_FPP = REPLACE(@c_SortingSeq_FPP,'LOADPLANDETAIL.','LPD.')
      SET @c_SortingSeq_FPP = REPLACE(@c_SortingSeq_FPP,'LOADPLAN.','LP.')
      SET @c_SortingSeq_FPP = REPLACE(@c_SortingSeq_FPP,'TASKDETAIL.','TD.')
      SET @c_SortingSeq_FPP = REPLACE(@c_SortingSeq_FPP,'STORERSODEFAULT.','SSO.')
   END

   --Initialize Pickdetail work in progress staging table for first time release 
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                  , @c_Wavekey = @c_Wavekey
                                  , @c_WIP_RefNo = @c_SourceType
                                  , @c_PickCondition_SQL = ''
                                  , @c_Action = 'I' --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records  
                                  , @c_RemoveTaskdetailkey = 'Y' --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization  
                                  , @b_Success = @b_Success OUTPUT
                                  , @n_Err = @n_err OUTPUT
                                  , @c_ErrMsg = @c_errmsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END
   END

   IF @c_TaskType = 'FCP'
   BEGIN
      SET @c_SQL = N' DECLARE CUR_PICK CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13)
                 + N' SELECT PICKDETAIL.Storerkey ' + CHAR(13)
                 + N'      , RIGHT(TRIM(ISNULL(LOC.Pickzone,'''')), 1) + RIGHT(TRIM(ORDERS.LoadKey), 9) ' + CHAR(13)
                 + N'      , PICKDETAIL.Sku ' + CHAR(13)
                 + N'      , PICKDETAIL.Loc ' + CHAR(13)
                 + N'      , PICKDETAIL.Lot ' + CHAR(13)
                 + N'      , SUM(PICKDETAIL.Qty) AS Qty ' + CHAR(13)
                 + N'      , MAX(PICKDETAIL.UOM) ' + CHAR(13)
                 + N'      , SUM(PICKDETAIL.UOMQty) AS UOMQty ' + CHAR(13)
                 + N'      , ORDERS.LoadKey ' + CHAR(13)
                 + N'      , PICKDETAIL.ID ' + CHAR(13)   --WL01
                 + N' FROM WAVEDETAIL (NOLOCK) ' + CHAR(13)
                 + N' JOIN WAVE (NOLOCK) ON WAVEDETAIL.WaveKey = WAVE.WaveKey ' + CHAR(13)
                 + N' JOIN ORDERS (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey ' + CHAR(13)
                 + N' JOIN #PickDetail_WIP PICKDETAIL (NOLOCK) ON ORDERS.OrderKey = PICKDETAIL.OrderKey ' + CHAR(13)
                 + N' JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc ' + CHAR(13)
                 + N' WHERE WAVEDETAIL.WaveKey = @c_Wavekey  ' + CHAR(13)
                 + N' AND PICKDETAIL.Status = ''0''  ' + CHAR(13)
                 + N' AND PICKDETAIL.WIP_Refno = @c_SourceType ' + CHAR(13)
                 + N' AND LOC.[Floor] NOT IN (''1'') ' + CHAR(13)
                 + N' GROUP BY PICKDETAIL.Storerkey ' + CHAR(13)
                 + N'        , RIGHT(TRIM(ISNULL(LOC.Pickzone,'''')), 1) + RIGHT(TRIM(ORDERS.LoadKey), 9) ' + CHAR(13)
                 + N'        , PICKDETAIL.Sku ' + CHAR(13)
                 + N'        , PICKDETAIL.Loc ' + CHAR(13)
                 + N'        , PICKDETAIL.Lot ' + CHAR(13)
                 + N'        , LOC.PickZone ' + CHAR(13)
                 + N'        , LOC.LogicalLocation ' + CHAR(13)
                 + N'        , ORDERS.LoadKey ' + CHAR(13)
                 + N'        , PICKDETAIL.ID ' + CHAR(13)   --WL01
                 + N' ORDER BY ' + @c_SortingSeq_FCP

      EXEC sp_executesql @c_SQL,
          N'@c_Wavekey NVARCHAR(10), @c_SourceType NVARCHAR(30) ',
          @c_Wavekey,
          @c_SourceType

      OPEN CUR_PICK

      FETCH NEXT FROM CUR_PICK
      INTO @c_Storerkey
         , @c_Groupkey
         , @c_Sku
         , @c_FromLoc
         , @c_Lot
         , @n_Qty
         , @c_UOM
         , @n_UOMQty
         , @c_Loadkey
         , @c_ID   --WL01

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN ( 1, 2 )
      BEGIN
         SET @c_ToLoc = N''
         --SET @c_ID = N''   --WL01

         SELECT TOP 1 @c_ToLoc = ISNULL(LP.TRFRoom, '')
         FROM LOADPLAN LP (NOLOCK)
         WHERE LP.Loadkey = @c_Loadkey

         IF NOT EXISTS (  SELECT 1
                          FROM LOC (NOLOCK)
                          WHERE Loc = @c_ToLoc)
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                 , @n_err = 83015 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': LOC ' + @c_ToLoc + ' Not Found. (ispRLWAV63)'
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END

         SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM'

         EXEC isp_InsertTaskDetail @c_TaskType = @c_TaskType
                                 , @c_Storerkey = @c_Storerkey
                                 , @c_Sku = @c_Sku
                                 , @c_Lot = @c_Lot
                                 , @c_UOM = @c_UOM
                                 , @n_UOMQty = @n_UOMQty
                                 , @n_Qty = @n_Qty
                                 , @c_FromLoc = @c_FromLoc
                                 , @c_LogicalFromLoc = @c_FromLoc
                                 , @c_FromID = @c_ID
                                 , @c_ToLoc = @c_ToLoc
                                 , @c_LogicalToLoc = @c_ToLoc
                                 , @c_ToID = ''
                                 , @c_PickMethod = @c_PickMethod
                                 , @c_Priority = @c_Priority
                                 , @c_SourcePriority = '9'
                                 , @c_SourceType = @c_SourceType
                                 , @c_SourceKey = @c_Wavekey
                                 , @c_Groupkey = @c_Groupkey
                                 , @c_WaveKey = @c_Wavekey
                                 , @c_AreaKey = '?F' -- ?F=Get from location areakey  
                                 , @c_CallSource = 'WAVE'
                                 , @c_LinkTaskToPick = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip  
                                 , @c_LinkTaskToPick_SQL = @c_LinkTaskToPick_SQL
                                 , @c_WIP_RefNo = @c_SourceType
                                 , @b_Success = @b_Success OUTPUT
                                 , @n_Err = @n_err OUTPUT
                                 , @c_ErrMsg = @c_errmsg OUTPUT

         IF @b_Success <> 1
         BEGIN
            SELECT @n_continue = 3
         END

         FETCH NEXT FROM CUR_PICK
         INTO @c_Storerkey
            , @c_Groupkey
            , @c_Sku
            , @c_FromLoc
            , @c_Lot
            , @n_Qty
            , @c_UOM
            , @n_UOMQty
            , @c_Loadkey
            , @c_ID   --WL01
      END
      CLOSE CUR_PICK
      DEALLOCATE CUR_PICK
   END
   ELSE IF @c_TaskType = 'FPP'
   BEGIN
       SET @c_SQL = N' DECLARE CUR_PICK CURSOR FAST_FORWARD READ_ONLY FOR  ' + CHAR(13)
    	            + N' SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,  ' + CHAR(13)
    	            + N'        PD.UOM, SUM(PD.UOMQty) AS UOMQty, ' + CHAR(13)
    	            + N'        O.Route, ' + CHAR(13)
    	            + N'        O.Orderkey, ' + CHAR(13)
    	            + N'        TOLOC.Loc AS ToLoc, ' + CHAR(13)
                  + N'        OK.PKZoneCnt, ' + CHAR(13)
                  + N'        OK.AisleZoneCnt, ' + CHAR(13)
                  + N'        CASE WHEN ISNULL(SC.Option1,'''') = ''Shipperkey'' THEN ISNULL(CL1.Code,'''') ELSE ''9'' END AS Priority ' + CHAR(13)
                  + N' FROM LOADPLANDETAIL LPD (NOLOCK) ' + CHAR(13)
                  + N' JOIN LOADPLAN LP (NOLOCK) ON LP.Loadkey = LPD.Loadkey ' + CHAR(13)
                  + N' JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey ' + CHAR(13)
                  + N' JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey ' + CHAR(13)
                  + N' JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc ' + CHAR(13)
                  + N' JOIN #TMP_Orderkey OK (NOLOCK) ON OK.Orderkey = O.Orderkey ' + CHAR(13)
                  + N' LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype IN (''FCP'') AND TD.Status <> ''X'' ' + CHAR(13)
                  + N' LEFT JOIN STORERSODEFAULT SSO (NOLOCK) ON SSO.Storerkey = O.Consigneekey ' + CHAR(13)
                  + N' OUTER APPLY (SELECT TOP 1 TL.Loc FROM LOC TL (NOLOCK) WHERE TL.Putawayzone = SSO.Route) AS TOLOC ' + CHAR(13)
                  + N' JOIN STORERCONFIG SC (NOLOCK) ON SC.STORERKEY = O.Storerkey AND SC.Configkey = ''ReleaseWave_SP'' AND SC.SValue = @c_SourceType ' + CHAR(13)
                  + N' OUTER APPLY (SELECT TOP 1 ISNULL(CL.Code,'''') AS Code FROM CODELKUP CL (NOLOCK) WHERE CL.LISTNAME = ''TMPRIORITY'' AND CL.Short = O.Shipperkey  ' + CHAR(13)
                  + N'                                                                                    AND CL.Storerkey = O.Storerkey ' + CHAR(13)
                  + N'                                                                                    AND (CL.Storerkey = O.Storerkey OR CL.Storerkey = '''') ' + CHAR(13)
                  + N'                                                                                    ORDER BY O.STORERKEY DESC ) AS CL1 ' + CHAR(13)
                  + N' WHERE PD.Status = ''0'' ' + CHAR(13)
                  + N' AND PD.WIP_RefNo = @c_SourceType ' + CHAR(13)
                  + N' AND TD.Taskdetailkey IS NULL ' + CHAR(13)         
                  + N' GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, O.Route, LOC.LogicalLocation, O.Orderkey, O.Consigneekey, TOLOC.Loc, OK.PKZoneCnt, OK.AisleZoneCnt, Loc.Pickzone, ' + CHAR(13)
                  + N'          ISNULL(SC.Option1,''''), ISNULL(CL1.Code,'''') ' + CHAR(13)
                  + N' ORDER BY ' + @c_SortingSeq_FPP

       EXEC sp_executesql @c_SQL,
          N'@c_SourceType NVARCHAR(30) ',
          @c_SourceType
             
       OPEN CUR_PICK  
       
       FETCH NEXT FROM CUR_PICK INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Route, @c_Orderkey, @c_ToLoc,
                                     @n_PKZoneCnt, @n_AisleZoneCnt, @c_Priority     
                                                                                                                         
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
         SET @c_LinkTaskToPick_SQL = '' 
         SET @c_Toloc = ''

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
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Loc setup. (ispRLWAV63)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         END   
         
         IF NOT EXISTS (  SELECT 1
                          FROM LOC (NOLOCK)
                          WHERE Loc = @c_ToLoc)
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                 , @n_err = 83025 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': LOC ' + @c_ToLoc + ' Not Found. (ispRLWAV63)'
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END
          	    
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
              ,@c_Wavekey               = @c_Wavekey
              ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
              ,@c_CallSource            = 'WAVE'
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
               
         FETCH NEXT FROM CUR_PICK INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Route, @c_Orderkey, @c_ToLoc,
                                       @n_PKZoneCnt, @n_AisleZoneCnt, @c_Priority 
      END
      CLOSE CUR_PICK
      DEALLOCATE CUR_PICK
   END
   ELSE
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
           , @n_err = 83025 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': This Wave Type ' + @c_TaskType + ' Cannot Release Task . (ispRLWAV63)'
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
      GOTO RETURN_SP
   END

   -----Update pickdetail_WIP work in progress staging table back to pickdetail   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                  , @c_Wavekey = @c_Wavekey
                                  , @c_WIP_RefNo = @c_SourceType
                                  , @c_PickCondition_SQL = ''
                                  , @c_Action = 'U' --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records  
                                  , @c_RemoveTaskdetailkey = 'N' --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization  
                                  , @b_Success = @b_Success OUTPUT
                                  , @n_Err = @n_err OUTPUT
                                  , @c_ErrMsg = @c_errmsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END
   END

   -----Update Wave Status-----  
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE WAVE
      SET TMReleaseFlag = 'Y'
        , TrafficCop = NULL
        , EditWho = SUSER_SNAME()
        , EditDate = GETDATE()
      WHERE WaveKey = @c_Wavekey

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
              , @n_err = 83030 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Update on wave Failed (ispRLWAV63)' + ' ( '
                            + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
      END
   END

   RETURN_SP:

   -----Delete pickdetail_WIP work in progress staging table  
   IF @n_continue IN ( 1, 2 )
   BEGIN
      EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                  , @c_Wavekey = @c_Wavekey
                                  , @c_WIP_RefNo = @c_SourceType
                                  , @c_PickCondition_SQL = ''
                                  , @c_Action = 'D' --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records  
                                  , @c_RemoveTaskdetailkey = 'N' --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization  
                                  , @b_Success = @b_Success OUTPUT
                                  , @n_Err = @n_err OUTPUT
                                  , @c_ErrMsg = @c_errmsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END
   END

   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
      DROP TABLE #PickDetail_WIP

   IF OBJECT_ID('tempdb..#TMP_Orderkey') IS NOT NULL
      DROP TABLE #TMP_Orderkey
      
   IF CURSOR_STATUS('GLOBAL', 'CUR_PICK') IN (0 , 1)
   BEGIN
      CLOSE CUR_PICK
      DEALLOCATE CUR_PICK   
   END

   IF @n_continue = 3 -- Error Occured - Process And Return    
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV63'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR -- SQL2012    
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END --sp end  

GO