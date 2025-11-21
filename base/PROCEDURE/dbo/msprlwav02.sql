SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: mspRLWAV02                                          */    
/* Creation Date: 2024-05-15                                             */
/* Copyright: Maersk                                                     */    
/* Written by: Supriya Sangeetham                                        */    
/*                                                                       */    
/* Purpose: UWP-18823 - Trigger replenishment with wave release          */  
/*                                                                       */  
/*                                                                       */    
/* Called By: Wave Release                                               */    
/*                                                                       */    
/* PVCS Version: 1.0                                                     */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date        Author   Ver   Purposes                                   */
/* 2024-06-04  SSA01    1.1   Updated to update the taskdetailkey        */
/*                            in the pickDetail table                    */
/* 2024-10-04  SSA02    1.2   UWP-25919-JCB-Release & Reverse Wave       */
/*                            for Kitting and Decanting                  */
/* 2024-11-04  SSA03    1.3   Updating size for the LOC and ID variables */
/*                            while fetching qty from inventory ,updated */
/*                            lot mapping while fetching orderkey        */
/* 2024-11-06  SSA04    1.4   Updating to fetch @n_qty, @c_FromID for the*/
/*                            UOM= 1 and updated to fetch the sortlane   */
/* 2024-11-07  SSA05    1.5   Updating to fetch @n_qty for the K4 Kitting*/
/* 2024-11-07  SSA06    1.6   Updating to remove the creating task for   */
/*                            type 2 with UOM1                           */
/* 2024-11-12  SSA07    1.7   Updating to add two step replenishment for */
/*                            type 1 with UOM7                           */
/*************************************************************************/
CREATE   PROCEDURE [dbo].[mspRLWAV02]
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

   DECLARE @n_continue    int = 1
         , @n_starttcnt   int = @@TRANCOUNT         -- Holds the current transaction count
         , @n_debug       int = 0
         , @n_cnt         int = 0

   SET @b_success = 0
   SET @n_err = 0
   SET @c_errmsg = ''

   DECLARE @c_Storerkey                NVARCHAR(15)   = ''
         , @c_Facility                 NVARCHAR(5)    = ''
         , @c_TaskType                 NVARCHAR(10)   = ''
         , @c_SourceType               NVARCHAR(30)   = ''
         , @c_Sku                      NVARCHAR(20)   = ''
         , @c_Lot                      NVARCHAR(10)   = ''
         , @c_FromLoc                  NVARCHAR(10)   = ''
         , @c_FromID                   NVARCHAR(18)   = ''
         , @c_Toloc                    NVARCHAR(10)   = ''
         , @c_ToID                     NVARCHAR(18)   = ''
         , @n_Qty                      INT            = 0
         , @n_UOMQty                   INT            = 0
         , @c_UOM                      NVARCHAR(10)   = ''
         , @c_Orderkey                 NVARCHAR(10)   = ''
         , @c_LoadKey                  NVARCHAR(10)   = ''
         , @c_Groupkey                 NVARCHAR(10)   = ''
         , @c_Priority                 NVARCHAR(10)   = ''
         , @c_PickMethod               NVARCHAR(10)   = ''
         , @c_LinkTaskToPick_SQL       NVARCHAR(4000) = ''
         , @c_Taskdetailkey            NVARCHAR(10)   = ''
         , @c_ID                       NVARCHAR(18)   = ''
         , @n_TaskQty                  INT                       --(SSA01)
         , @n_PickQty                  INT                       --(SSA01)
         , @c_SQL                      NVARCHAR(MAX)             --(SSA01)
         , @c_CurrPickDetailKey        NVARCHAR(10)              --(SSA01)
         , @c_CurrTaskDetailKey        NVARCHAR(10)              --(SSA01)
         , @c_Type                     NVARCHAR(10)              --(SSA02)
         , @c_LocationGroup            NVARCHAR(10)              --(SSA02)
         , @c_SortLane                 NVARCHAR(10)              --(SSA02)
         , @c_Finalloc                 NVARCHAR(10)   = ''       --(SSA02)
         , @n_SortLaneQty              INT            = 0        --(SSA02)
         , @c_userDefine01             NVARCHAR(10)   = ''       --(SSA02)
         , @c_PickDetailLoc            NVARCHAR(10)   = ''       --(SSA02)
         , @c_PickDetailToLoc          NVARCHAR(10)   = ''       --(SSA02)
         , @c_SQLParams                 NVARCHAR(MAX)


   SET @c_SourceType = 'mspRLWAV02'
   SET @c_Priority   = '9'
   SET @c_TaskType   = 'RPF'
   SET @c_PickMethod = 'FP'

   -----Get Storerkey and facility

   SELECT TOP 1 @c_StorerKey = O.Storerkey,
               @c_Facility = O.Facility
   FROM WAVE W (NOLOCK)
   JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
   JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
   WHERE WD.Wavekey = @c_Wavekey

   ------Loadplan Validation

   IF  (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT TOP 1 @c_Loadkey  = ISNULL(lpd.Loadkey,''),@c_Type  = ISNULL(O.Type,'')
      FROM WAVE W (NOLOCK)
      JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      LEFT OUTER JOIN LOADPLANDETAIL lpd (NOLOCK) ON lpd.Orderkey = O.Orderkey
      WHERE W.Wavekey = @c_Wavekey
      ORDER BY ISNULL(lpd.Loadkey,'')

      IF @c_Loadkey = ''
      BEGIN
         SET @n_continue = 3
         SET @n_err = 83010
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Loadplan has not generated yet. (mspRLWAV02)'
      END
   END

   ------(SSA02) Start----------
   -- (SSA06) Removed UOM = 1 for Type 2 ------
   -----Wave Validation
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
     SET @c_SQL = ' IF NOT EXISTS (SELECT 1 '
          + ' FROM WAVEDETAIL WD (NOLOCK)'
          + ' JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey'
          + ' LEFT JOIN TASKDETAIL TD (NOLOCK) ON  PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype = @c_TaskType'
          + ' WHERE WD.Wavekey = @c_Wavekey'
          + ' AND PD.Status = ''0'''
          + CASE WHEN @c_Type = '1' THEN ' AND PD.UOM = ''7'''
                 WHEN @c_Type = '6' THEN ' AND PD.UOM = ''1'''
                 WHEN @c_Type = '2' THEN ' AND PD.UOM = ''7'''
                 ELSE ' AND PD.UOM = ''7'''
                 END
          + ' AND TD.Taskdetailkey IS NULL )'
          + ' BEGIN '
          + ' SET @n_continue = 3 '
          + ' SET @n_err = 83020'
          + ' SET @c_errmsg=''NSQL''+CONVERT(NVARCHAR(5),@n_err)+'': Nothing to release. (mspRLWAV02)'''
          + ' END'
        SET @c_SQLParams= N'@c_Wavekey   NVARCHAR(10)'
                                    + ',@c_SourceType NVARCHAR(30)'
                                    + ',@c_TaskType   NVARCHAR(10)'
                                    + ',@n_continue            INT OUTPUT'
                                    + ',@n_Err                INT OUTPUT'
                                    + ',@c_ErrMsg             NVARCHAR(250) OUTPUT'
        EXEC sp_executesql @c_SQL
                          ,@c_SQLParams
                          ,@c_Wavekey
                          ,@c_SourceType
                          ,@c_TaskType
                          ,@n_continue OUTPUT
                          ,@n_err OUTPUT
                          ,@c_errmsg OUTPUT

		 END

    ------(SSA02) end----------
   --Create pickdetail Work in progress temporary table
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
         DROP TABLE #PICKDETAIL_WIP

      CREATE TABLE #PickDetail_WIP(
         [PickDetailKey]   [nvarchar](18) NOT NULL PRIMARY KEY
      ,  [CaseID]          [nvarchar](20) NOT NULL DEFAULT (' ')
      ,  [PickHeaderKey]   [nvarchar](18) NOT NULL
      ,  [OrderKey]        [nvarchar](10) NOT NULL
      ,  [OrderLineNumber] [nvarchar](5)  NOT NULL
      ,  [Lot]             [nvarchar](10) NOT NULL
      ,  [Storerkey]       [nvarchar](15) NOT NULL
      ,  [Sku]             [nvarchar](20) NOT NULL
      ,  [AltSku]          [nvarchar](20) NOT NULL DEFAULT (' ')
      ,  [UOM]             [nvarchar](10) NOT NULL DEFAULT (' ')
      ,  [UOMQty]          [int]          NOT NULL DEFAULT ((0))
      ,  [Qty]             [int]          NOT NULL DEFAULT ((0))
      ,  [QtyMoved]        [int]          NOT NULL DEFAULT ((0))
      ,  [Status]          [nvarchar](10) NOT NULL DEFAULT ('0')
      ,  [DropID]          [nvarchar](20) NOT NULL DEFAULT ('')
      ,  [Loc]             [nvarchar](10) NOT NULL DEFAULT ('UNKNOWN')
      ,  [ID]              [nvarchar](18) NOT NULL DEFAULT (' ')
      ,  [PackKey]         [nvarchar](10) NULL     DEFAULT (' ')
      ,  [UpdateSource]    [nvarchar](10) NULL     DEFAULT ('0')
      ,  [CartonGroup]     [nvarchar](10) NULL
      ,  [CartonType]      [nvarchar](10) NULL
      ,  [ToLoc]           [nvarchar](10) NULL     DEFAULT (' ')
      ,  [DoReplenish]     [nvarchar](1)  NULL     DEFAULT ('N')
      ,  [ReplenishZone]   [nvarchar](10) NULL     DEFAULT (' ')
      ,  [DoCartonize]     [nvarchar](1)  NULL     DEFAULT ('N')
      ,  [PickMethod]      [nvarchar](1)  NOT NULL DEFAULT (' ')
      ,  [WaveKey]         [nvarchar](10) NOT NULL DEFAULT (' ')
      ,  [EffectiveDate]   [datetime]     NOT NULL DEFAULT (getdate())
      ,  [AddDate]         [datetime]     NOT NULL DEFAULT (getdate())
      ,  [AddWho]          [nvarchar](128)NOT NULL DEFAULT (suser_sname())
      ,  [EditDate]        [datetime]     NOT NULL DEFAULT (getdate())
      ,  [EditWho]         [nvarchar](128)NOT NULL DEFAULT (suser_sname())
      ,  [TrafficCop]      [nvarchar](1)  NULL
      ,  [ArchiveCop]      [nvarchar](1)  NULL
      ,  [OptimizeCop]     [nvarchar](1)  NULL
      ,  [ShipFlag]        [nvarchar](1)  NULL     DEFAULT ('0')
      ,  [PickSlipNo]      [nvarchar](10) NULL
      ,  [TaskDetailKey]   [nvarchar](10) NULL
      ,  [TaskManagerReasonKey] [nvarchar](10) NULL
      ,  [Notes]           [nvarchar](4000)NULL
      ,  [MoveRefKey]      [nvarchar](10) NULL DEFAULT ('')
      ,  [WIP_Refno]       [nvarchar](30) NULL DEFAULT ('')
      ,  [Channel_ID]      [bigint]       NULL DEFAULT ((0)))
   END

   IF @@TRANCOUNT = 0
      BEGIN TRAN

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
      ELSE
      BEGIN
         UPDATE #PICKDETAIL_WIP
         SET #PICKDETAIL_WIP.Taskdetailkey = ''
         FROM #PICKDETAIL_WIP
         LEFT JOIN TASKDETAIL TD (NOLOCK) ON  TD.Taskdetailkey = #PICKDETAIL_WIP.Taskdetailkey
                                          AND TD.Sourcetype = @c_SourceType
                                          AND TD.Tasktype = @c_TaskType
                                          AND TD.Status <> 'X'
         WHERE TD.Taskdetailkey IS NULL
      END
   END

   IF @n_continue IN(1,2)
   BEGIN
   ------(SSA02) ,(SSA04)start----------
   ----- (SSA06) Removed UOM = 1 for Type 2
   SET @c_SQL =N'DECLARE cur_WaveReplto CURSOR FAST_FORWARD READ_ONLY FOR '
      +' SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.ToLoc, PD.CaseId, PD.Loc, PD.ID,PD.UOM,SUM(PD.QTY)'
      +' FROM WAVEDETAIL WD (NOLOCK)'
      +' JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey'
      +' JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey'
      +' JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey'
      +' LEFT JOIN TASKDETAIL TD (NOLOCK) ON  TD.Taskdetailkey = PD.Taskdetailkey'
      +' AND TD.Sourcetype = @c_SourceType'
      +' AND TD.Tasktype = @c_TaskType'
      +' AND TD.Status <> ''X'''
      +' WHERE WD.Wavekey = @c_Wavekey'
      +' AND PD.Status = ''0'''
      + CASE WHEN @c_Type = '1' THEN ' AND PD.UOM = ''7'''
                 WHEN @c_Type = '6' THEN ' AND PD.UOM = ''1'''
                 WHEN @c_Type = '2' THEN ' AND PD.UOM = ''7'''
                 ELSE ' AND PD.UOM = ''7'''
                 END
      +' AND PD.WIP_RefNo = @c_SourceType'
      +' AND TD.Taskdetailkey IS NULL'
      +' GROUP BY WD.Wavekey,PD.Storerkey, PD.Sku, PD.Lot, PD.ToLoc, PD.CaseId, PD.Loc, PD.ID'
      +', PD.UOM'
      +' ORDER BY PD.Storerkey,  PD.Sku,  PD.Lot,  PD.Loc,  PD.CaseId,  PD.ToLoc'
      SET @c_SQLParams= N'@c_Wavekey   NVARCHAR(10)'
                                    + ',@c_SourceType NVARCHAR(30)'
                                    + ',@c_TaskType   NVARCHAR(10)'


      EXEC sp_executesql @c_SQL
                          ,@c_SQLParams
                          ,@c_Wavekey
                          ,@c_SourceType
                          ,@c_TaskType

      ------(SSA02) end----------
      OPEN cur_WaveReplto

      FETCH NEXT FROM cur_WaveReplto INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_FromID, @c_ToLoc, @c_ToID
                                          ,@c_UOM,@n_Qty
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2)
      BEGIN
        ------(SSA02) ,(SSA07)start----------
         IF @c_UOM = '7'  --(SSA04)
         BEGIN
            SELECT @n_Qty = lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen from LOTxLOCxID lli (NOLOCK)
                WHERE lli.Lot = @c_Lot
                AND lli.Loc = @c_FromLoc AND lli.ID  = @c_FromID
                AND lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen > 0

           IF NOT EXISTS (SELECT 1
            FROM SKUxLOC SL (NOLOCK)
            JOIN #PICKDETAIL_WIP PD (NOLOCK) ON PD.Storerkey = SL.Storerkey
            WHERE SL.Storerkey = PD.Storerkey
            AND SL.Sku = PD.Sku
            AND SL.loc = @c_ToLoc
            AND SL.LocationType IN ('CASE','PICK')
            GROUP BY SL.StorerKey
            ,  SL.Sku
            ,  SL.Loc
            ,  SL.QtyLocationLimit)
            BEGIN
               SET @n_continue = 3
               SET @n_err = 83030
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Replenishment ToLoc is not a pickface/case. (mspRLWAV02)'
            END

            SELECT @c_Orderkey = orderkey from #PICKDETAIL_WIP PD (NOLOCK)  --(SSA01)
                  WHERE PD.Storerkey = @c_Storerkey
                  AND PD.Sku = @c_Sku
                  AND PD.Lot = @c_Lot             --(SSA03)
                  AND PD.CaseId = @c_FromID
                  AND PD.ToLoc = @c_FromLoc
                  AND PD.ID = @c_ToID
                  AND PD.Loc = @c_ToLoc
         END

         IF @c_UOM = '1' AND @c_Type = '6' --(SSA05)
         SELECT @n_Qty = lli.Qty from LOTxLOCxID lli (NOLOCK)
                WHERE lli.Lot = @c_Lot
                AND lli.Loc = @c_ToLoc AND lli.ID  = @c_ToID

         IF @n_continue IN(1,2)
         BEGIN
             SET @c_PickDetailLoc = @c_ToLoc
             SET @c_PickDetailToLoc = @c_FromLoc

             IF (@c_Type = '1' AND @c_UOM = '7') OR (@c_Type = '2' AND @c_UOM = '7')
             BEGIN
                  SELECT @c_LocationGroup = loc.locationgroup
                        FROM Loc loc (NOLOCK)
                        WHERE loc.loc = @c_FromLoc

                  IF @c_LocationGroup <> ''
                     BEGIN
                        SET @c_Finalloc  = @c_ToLoc
                        SET @c_ToLoc = @c_LocationGroup
                     END
             END
             ELSE IF (@c_Type = '6' AND @c_UOM = '1')     --(SSA06)
                BEGIN
                   SET @c_FromLoc = @c_ToLoc
                   SET @c_FromID = @c_ToID       --(SSA04)
                   SET @c_Orderkey = ''

                   SELECT @c_LocationGroup = loc.locationgroup
                      FROM Loc loc (NOLOCK)
                      WHERE loc.loc = @c_FromLoc

                   SELECT TOP 1 @c_SortLane  = ISNULL(cdlkup.code,'') ,@n_SortLaneQty = Sum(ISNULL(lli.Qty,0)), @c_userDefine01 = ISNULL(cdlkup.UDF01, '')
                   FROM codelkup cdlkup  (NOLOCK)
                   LEFT JOIN Lotxlocxid lli (NOLOCK) on cdlkup.code = lli.loc
                   WHERE cdlkup.Listname ='JCB_SORTL'  AND cdlkup.Storerkey = @c_Storerkey
                   GROUP by cdlkup.code ,cdlkup.UDF01 order by Sum(lli.Qty),cdlkup.code ASC

                   IF @c_userDefine01 <> '' AND @c_userDefine01 = '1'
                   BEGIN
                      IF @n_SortLaneQty > 0
                      BEGIN
                         SET @n_continue = 3
                         SET @n_err = 83040
                         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': SortLane Loc is not empty . (mspRLWAV02)'
                      END
                   END
                   IF @c_LocationGroup <> ''
                   BEGIN
                      SET @c_ToLoc = @c_LocationGroup
                      SET @c_Finalloc  = @c_SortLane
                   END
                   ELSE
                      SET @c_ToLoc = @c_SortLane
                END
         END
         ------(SSA02) ,(SSA07)end----------
         IF @n_continue IN(1,2)
         BEGIN
           SET @c_Taskdetailkey = ''
           SET @c_PickMethod = 'FP'
           SET @c_GroupKey = @c_WaveKey
           SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND ORDERS.USERDEFINE09 = @c_WaveKey'  --(SSA01)

           EXEC isp_InsertTaskDetail
               @c_Taskdetailkey         = @c_Taskdetailkey OUTPUT
              ,@c_TaskType              = @c_TaskType
              ,@c_Storerkey             = @c_Storerkey
              ,@c_Sku                   = @c_Sku
              ,@c_Lot                   = @c_Lot
              ,@c_UOM                   = @c_UOM
              ,@n_UOMQty                = @n_Qty
              ,@n_Qty                   = @n_Qty
              ,@c_FromLoc               = @c_FromLoc
              ,@c_LogicalFromLoc        = @c_FromLoc
              ,@c_FromID                = @c_FromID
              ,@c_ToLoc                 = @c_ToLoc
              ,@c_LogicalToLoc          = @c_ToLoc
              ,@c_ToID                  = @c_FromID                                  --(SSA01)
              ,@c_PickMethod            = @c_PickMethod
              ,@c_Priority              = @c_Priority
              ,@c_SourcePriority        = '9'
              ,@c_SourceType            = @c_SourceType
              ,@c_SourceKey             = @c_Wavekey
              ,@c_OrderKey              = @c_Orderkey
              ,@c_Groupkey              = @c_Groupkey
              ,@c_WaveKey               = @c_Wavekey
              ,@c_FinalLOC              = @c_Finalloc
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
              SET @n_continue = 3
           END
           ELSE
           --Update taskdetailkey in the pickdetail Work in progress staging table (SSA01)
           BEGIN
		          SELECT  @n_TaskQty = @n_Qty
              IF LEFT(LTRIM(@c_LinkTaskToPick_SQL), 4) <> 'AND ' AND (CHARINDEX('ORDER BY', LTRIM(@c_LinkTaskToPick_SQL)) = 0 OR CHARINDEX('ORDER BY', LTRIM(@c_LinkTaskToPick_SQL)) > 1)
                 SET @c_LinkTaskToPick_SQL  = 'AND ' + RTRIM(LTRIM(@c_LinkTaskToPick_SQL))

          	  IF CHARINDEX('ORDER BY', @c_LinkTaskToPick_SQL) = 0
          	     SET @c_LinkTaskToPick_SQL = @c_LinkTaskToPick_SQL + CHAR(13) + ' ORDER BY ORDERS.Loadkey, ORDERS.Orderkey, PICKDETAIL.Pickdetailkey '

              SET @c_LinkTaskToPick_SQL  = ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' + CHAR(13) +  @c_LinkTaskToPick_SQL
              SET @c_LinkTaskToPick_SQL  = ' AND PICKDETAIL.WIP_RefNo = @c_WIP_RefNo ' + CHAR(13) +  @c_LinkTaskToPick_SQL
              --(SSA04)
              IF OBJECT_ID('tempdb..#TMP_PICK') IS NOT NULL
              DROP TABLE #TMP_PICK

              CREATE TABLE #TMP_PICK (Pickdetailkey NVARCHAR(10) primary key,
	 	                          Qty           INT NULL,
	 	                          Taskdetailkey NVARCHAR(10),
	 	                          rowid         INT IDENTITY(1,1))
              TRUNCATE TABLE #TMP_PICK

              SET @c_SQL = ' INSERT INTO #TMP_PICK (Pickdetailkey, Qty, Taskdetailkey)
                         SELECT PICKDETAIL.Pickdetailkey,
                                PICKDETAIL.Qty, PICKDETAIL.Taskdetailkey
                         FROM #PICKDETAIL_WIP PICKDETAIL (NOLOCK)
                         JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey
                         JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc
                         JOIN SKUXLOC (NOLOCK) ON PICKDETAIL.Storerkey = SKUXLOC.Storerkey AND PICKDETAIL.Sku = SKUXLOC.Sku AND PICKDETAIL.Loc = SKUXLOC.Loc
                         JOIN WAVEDETAIL (NOLOCK) ON ORDERS.Orderkey = WAVEDETAIL.Orderkey
                         WHERE ISNULL(PICKDETAIL.Taskdetailkey,'''') = ''''
                         AND PICKDETAIL.Storerkey = @c_Storerkey
                         AND (PICKDETAIL.Sku = @c_Sku OR ISNULL(@c_Sku,'''') = '''')
                         AND (PICKDETAIL.Lot = @c_Lot OR ISNULL(@c_Lot,'''') = '''')
                         AND PICKDETAIL.Loc = @c_PickDetailLoc
                         AND PICKDETAIL.ID = @c_ToID
                         AND PICKDETAIL.ToLoc = @c_PickDetailToLoc
                         AND PICKDETAIL.CaseId = @c_FromID '+ @c_LinkTaskToPick_SQL

              EXEC sp_executesql @c_SQL,
                 N'@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Lot NVARCHAR(10), @c_PickDetailToLoc NVARCHAR(10), @c_PickDetailLoc NVARCHAR(10),@c_ToID NVARCHAR(18),
                 @c_FromID NVARCHAR(18), @c_UOM NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_Loadkey NVARCHAR(10), @c_Orderkey NVARCHAR(10), @c_WIP_RefNo NVARCHAR(30)',
               @c_Storerkey,
               @c_Sku,
               @c_Lot,
               @c_PickDetailToLoc,
               @c_PickDetailLoc,
               @c_ToID,
               @c_FromID,
               @c_UOM,
               @c_Wavekey,
               @c_Loadkey,
               @c_Orderkey,
               @c_SourceType

              DECLARE CUR_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
              SELECT Pickdetailkey, Qty ,Taskdetailkey
              FROM #TMP_PICK
              ORDER BY rowid

              OPEN CUR_Pick

              FETCH NEXT FROM CUR_Pick INTO @c_CurrPickdetailkey, @n_PickQty, @c_CurrTaskDetailKey
              WHILE @@FETCH_STATUS = 0 AND @c_CurrTaskDetailKey = ''
              BEGIN
                 IF @n_PickQty <= @n_TaskQty
                 BEGIN
             	       SET @c_SQL = 'UPDATE #PICKDETAIL_WIP WITH (ROWLOCK) ' +
                                ' SET Taskdetailkey =  @c_TaskdetailKey,' +
                                ' editdate =  getdate(), ' +
                                ' TrafficCop = NULL ' +
                                ' WHERE Pickdetailkey = @c_CurrPickdetailKey ' +
                                ' AND WIP_Refno = @c_WIP_RefNo '
                    EXEC sp_executesql @c_SQL,
                    N'@c_CurrPickdetailKey NVARCHAR(10), @c_TaskdetailKey NVARCHAR(10), @c_WIP_RefNo NVARCHAR(30)',
                    @c_CurrPickdetailKey,
                    @c_TaskdetailKey,
                    @c_SourceType
                    SELECT @n_err = @@ERROR
                    IF @n_err <> 0
                       BEGIN
                          SELECT @n_continue = 3
                          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83050
                          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (mspRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                          BREAK
                       END
                   SET @c_CurrTaskDetailKey = @c_TaskdetailKey
                 END
                 FETCH NEXT FROM CUR_Pick INTO @c_CurrPickdetailkey, @n_PickQty, @c_CurrTaskDetailKey
              END
              CLOSE CUR_Pick
              DEALLOCATE CUR_Pick
           END
         END
           FETCH NEXT FROM cur_WaveReplto INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_FromID, @c_ToLoc, @c_ToID
                                               ,@c_UOM,@n_Qty
      END
         CLOSE cur_WaveReplto
         DEALLOCATE cur_WaveReplto
  END

   -----Update pickdetail_WIP work in progress staging table back to pickdetail
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
         ,  @c_Wavekey               = @c_wavekey
         ,  @c_WIP_RefNo             = @c_SourceType
         ,  @c_PickCondition_SQL     = ''
         ,  @c_Action                = 'U'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
         ,  @c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
         ,  @b_Success               = @b_Success OUTPUT
         ,  @n_Err                   = @n_Err     OUTPUT
         ,  @c_ErrMsg                = @c_ErrMsg  OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END
   END

RETURN_SP:

   -----Delete pickdetail_WIP work in progress staging table
   IF @n_continue IN (1,2)
   BEGIN
      EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
         ,  @c_Wavekey               = @c_wavekey
         ,  @c_WIP_RefNo             = @c_SourceType
         ,  @c_PickCondition_SQL     = ''
         ,  @c_Action                = 'D'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
         ,  @c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
         ,  @b_Success               = @b_Success OUTPUT
         ,  @n_Err                   = @n_Err     OUTPUT
         ,  @c_ErrMsg                = @c_ErrMsg  OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END
   END

   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
      DROP TABLE #PICKDETAIL_WIP

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
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
      execute nsp_logerror @n_err, @c_errmsg, "mspRLWAV02"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   END
END

GO