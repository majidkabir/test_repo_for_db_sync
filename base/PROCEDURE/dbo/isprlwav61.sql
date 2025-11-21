SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Stored Procedure: ispRLWAV61                                             */
/* Creation Date: 30-MAY-2023                                               */
/* Copyright: MAERSK                                                        */
/* Written by:                                                              */
/*                                                                          */
/* Purpose: WMS-22724 - CN Anta Release wave for replenishment              */
/*                                                                          */
/* Called By: wave                                                          */
/*                                                                          */
/* PVCS Version: 1.0                                                        */
/*                                                                          */
/* Version: 7.0                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date        Author   Ver  Purposes                                       */
/* 30-MAY-2023 NJOW     1.0  DEVOPS Combine Script                          */
/****************************************************************************/

CREATE   PROCEDURE [dbo].[ispRLWAV61]
   @c_wavekey NVARCHAR(10)
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
   SELECT @n_debug = 0

   DECLARE @c_DocType            NVARCHAR(1)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_Facility           NVARCHAR(5)
         , @c_SourceType         NVARCHAR(30)
         , @c_Lot                NVARCHAR(10)
         , @c_FromLoc            NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
         , @c_ID                 NVARCHAR(18)
         , @c_ToID               NVARCHAR(18)
         , @c_LocationRoom       NVARCHAR(18)
         , @n_CaseCnt            INT
         , @c_Packkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @n_Qty                INT
         , @c_ReplenishmentKey   NVARCHAR(10)
         , @c_ReplenishmentGroup NVARCHAR(10)
         , @n_ReplenQty          INT
         , @n_ReplenQtyFinal     INT
         , @n_QtyAvailable       INT
         , @n_QtyShort           INT

   SET @c_SourceType = N'ispRLWAV61'

   -----Get Storerkey, facility
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT TOP 1 @c_Storerkey = O.StorerKey
                 , @c_Facility = O.Facility
                 , @c_DocType = O.DocType
      FROM WAVE W (NOLOCK)
      JOIN WAVEDETAIL WD (NOLOCK) ON W.WaveKey = WD.WaveKey
      JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
      WHERE W.Wavekey = @c_Wavekey
   END

   -----Wave Validation-----               
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM REPLENISHMENT RP (NOLOCK)
                   WHERE RP.Wavekey = @c_wavekey)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 83010
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': This Wave has beed released. (ispRLWAV61)'
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM WAVEDETAIL WD (NOLOCK)
                   JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
                   WHERE WD.WaveKey = @c_wavekey AND (O.LoadKey = '' OR O.LoadKey IS NULL))
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 83020
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                            + ': Not allow to release. Found some order without load planning yet. (ispRLWAV61)'
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM WAVEDETAIL WD (NOLOCK)
                   JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
                   WHERE WD.WaveKey = @c_wavekey AND O.Status = '0')
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 83030
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                            + ': Not allow to release. Found some order in the wave is not allocated yet. (ispRLWAV61)'
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_Sku = N''

      SELECT TOP 1 @c_Sku = OD.Sku
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
      JOIN ORDERDETAIL OD (NOLOCK) ON O.OrderKey = OD.OrderKey
      OUTER APPLY (  SELECT SXL.Loc, SXL.LocationType
                     FROM SKUxLOC SXL (NOLOCK)
                     JOIN LOC L (NOLOCK) ON SXL.Loc = L.Loc
                     WHERE OD.Storerkey = SXL.StorerKey AND OD.Sku = SXL.Sku AND SXL.LocationType IN ( 'PICK', 'CASE' )
                     AND L.Facility = @c_Facility) SL  
      WHERE WD.WaveKey = @c_wavekey
      GROUP BY OD.Sku
      HAVING COUNT(DISTINCT SL.Loc) > 1 OR MAX(SL.LocationType) IS NULL
      ORDER BY OD.Sku

      IF ISNULL(@c_Sku, '') <> ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 83040
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Found Sku: ' + RTRIM(@c_Sku)
                            + ' has none or multiple pick locations of the facility. Every Sku must has one pick location only. (ispRLWAV61)'  
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

   BEGIN TRAN

   --Initialize Pickdetail work in progress staging table
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                  , @c_Wavekey = @c_wavekey
                                  , @c_WIP_RefNo = @c_SourceType
                                  , @c_PickCondition_SQL = ''
                                  , @c_Action = 'I' --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
                                  , @c_RemoveTaskdetailkey = 'N' --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
                                  , @b_Success = @b_Success OUTPUT
                                  , @n_Err = @n_err OUTPUT
                                  , @c_ErrMsg = @c_errmsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END
   END
   
   -----Create replenishment task for pick face picking
   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN
      --Retrieve all lot of the wave from pick loc
      SELECT DISTINCT LLI.Lot
      INTO #TMP_WAVEPICKLOT
      FROM PICKDETAIL PD (NOLOCK)
      JOIN SKUxLOC SXL (NOLOCK) ON PD.Storerkey = SXL.StorerKey AND PD.Sku = SXL.Sku AND PD.Loc = SXL.Loc
      JOIN LOTxLOCxID LLI (NOLOCK) ON  PD.Storerkey = LLI.StorerKey
                                   AND PD.Sku = LLI.Sku
                                   AND PD.Lot = LLI.Lot
                                   AND PD.Loc = LLI.Loc
                                   AND PD.ID = LLI.Id
      JOIN ORDERS O (NOLOCK) ON PD.OrderKey = O.OrderKey
      JOIN WAVEDETAIL WD (NOLOCK) ON O.OrderKey = WD.OrderKey
      WHERE WD.WaveKey = @c_wavekey AND SXL.LocationType IN ( 'PICK', 'CASE' ) AND LLI.QtyExpected > 0

      --Retreive pick loc with overallocated
      DECLARE cur_PickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LLI.StorerKey
           , LLI.Sku
           , LLI.Lot
           , LLI.Loc
           , LLI.Id
           , SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIN) AS Qty
           , PACK.CaseCnt
           , PACK.PackKey
           , PACK.PackUOM3
           , LOC.LocationRoom
      FROM LOTxLOCxID LLI (NOLOCK)
      JOIN SKUxLOC SL (NOLOCK) ON LLI.StorerKey = SL.StorerKey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
      JOIN SKU (NOLOCK) ON LLI.StorerKey = SKU.StorerKey AND LLI.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
      JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
      JOIN #TMP_WAVEPICKLOT ON LLI.Lot = #TMP_WAVEPICKLOT.Lot
      WHERE SL.LocationType IN ( 'PICK', 'CASE' ) AND LLI.StorerKey = @c_Storerkey AND LOC.Facility = @c_Facility
      GROUP BY LLI.StorerKey
             , LLI.Sku
             , LLI.Lot
             , LLI.Loc
             , LLI.Id
             , PACK.CaseCnt
             , PACK.PackKey
             , PACK.PackUOM3
             , LOC.LocationRoom
      HAVING SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIN) < 0 --overallocate

      OPEN cur_PickLoc

      FETCH FROM cur_PickLoc
      INTO @c_Storerkey
         , @c_Sku
         , @c_Lot
         , @c_ToLoc
         , @c_ToID
         , @n_QtyShort
         , @n_CaseCnt
         , @c_Packkey
         , @c_UOM
         , @c_LocationRoom

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN ( 1, 2 )
      BEGIN
         IF @n_QtyShort < 0
            SET @n_QtyShort = @n_QtyShort * -1

         SET @n_ReplenQty = @n_QtyShort

         --retrieve stock from bulk 
         DECLARE cur_Bulk CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.Lot
              , LLI.Loc
              , LLI.Id
              , (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) AS QtyAvailable
         FROM LOTxLOCxID LLI (NOLOCK)
         JOIN SKUxLOC SL (NOLOCK) ON LLI.StorerKey = SL.StorerKey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
         JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
         JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
         JOIN ID (NOLOCK) ON LLI.Id = ID.Id
         WHERE SL.LocationType NOT IN ( 'PICK', 'CASE' )
         AND   LOT.Status = 'OK'
         AND   LOC.Status = 'OK'
         AND   ID.Status = 'OK'
         AND   LOC.LocationFlag = 'NONE'
         AND   LOC.LocationType = 'OTHER'
         AND   (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) > 0
         AND   LLI.StorerKey = @c_Storerkey
         AND   LLI.Sku = @c_Sku
         AND   LLI.Lot = @c_Lot
         AND   LOC.Facility = @c_Facility 
         ORDER BY LOC.LogicalLocation
                , (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) DESC       
                , LOC.Loc

         OPEN cur_Bulk

         FETCH FROM cur_Bulk
         INTO @c_Lot
            , @c_FromLoc
            , @c_ID
            , @n_QtyAvailable

         WHILE @@FETCH_STATUS = 0 AND @n_continue IN ( 1, 2 ) AND @n_ReplenQty > 0
         BEGIN
            SELECT @c_ReplenishmentKey = ''
                 , @c_ReplenishmentGroup = ''
               
            SET @n_ReplenQtyFinal = @n_QtyAvailable               

            SET @n_ReplenQty = @n_ReplenQty - @n_ReplenQtyFinal

            EXECUTE nspg_GetKey 'REPLENISHKEY'
                              , 10
                              , @c_ReplenishmentKey OUTPUT
                              , @b_Success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

            IF NOT @b_Success = 1
            BEGIN
               SELECT @n_continue = 3
            END

            INSERT INTO REPLENISHMENT (ReplenishmentGroup, ReplenishmentKey, Storerkey, Sku, FromLoc, ToLoc, Lot, Id
                                     , Qty, UOM, PackKey, Confirmed, MoveRefKey, ToID, PendingMoveIn, QtyReplen
                                     , QtyInPickLoc, RefNo, Wavekey, Remark, ReplenNo, OriginalQty, OriginalFromLoc)
            VALUES (@c_ReplenishmentGroup, @c_ReplenishmentKey, @c_Storerkey, @c_Sku, @c_FromLoc, @c_ToLoc, @c_Lot
                  , @c_ID, @n_ReplenQtyFinal, @c_UOM, @c_Packkey, 'N', '', @c_ToID, @n_ReplenQtyFinal
                  , @n_ReplenQtyFinal, 0, '', @c_wavekey, '', '', 0, @c_SourceType)

            IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 83050 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                  + ': Error Insert Replenishment Table. (ispRLWAV61)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_errmsg) + ' ) '
            END

            FETCH FROM cur_Bulk
            INTO @c_Lot
               , @c_FromLoc
               , @c_ID
               , @n_QtyAvailable
         END
         CLOSE cur_Bulk
         DEALLOCATE cur_Bulk

         FETCH FROM cur_PickLoc
         INTO @c_Storerkey
            , @c_Sku
            , @c_Lot
            , @c_ToLoc
            , @c_ToID
            , @n_QtyShort
            , @n_CaseCnt
            , @c_Packkey
            , @c_UOM
            , @c_LocationRoom
      END
      CLOSE cur_PickLoc
      DEALLOCATE cur_PickLoc
   END

   -----Update pickdetail_WIP work in progress staging table back to pickdetail 
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                  , @c_Wavekey = @c_wavekey
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

   -----Generate Pickslip No------    
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_DocType <> 'E'
   BEGIN
      EXEC isp_CreatePickSlip @c_Wavekey = @c_wavekey
                            , @c_LinkPickSlipToPick = 'Y' --Y=Update pickslipno to pickdetail.pickslipno 
                            , @c_ConsolidateByLoad = 'Y'
                            , @b_Success = @b_Success OUTPUT
                            , @n_Err = @n_err OUTPUT
                            , @c_ErrMsg = @c_errmsg OUTPUT

      IF @b_Success = 0
         SELECT @n_continue = 3
   END

   -----Update Wave Status-----
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE WAVE
      SET TMReleaseFlag = 'Y'
        , TrafficCop = NULL
        , EditWho = SUSER_SNAME()
        , EditDate = GETDATE()
      WHERE WaveKey = @c_wavekey
      -- (Wan01) - END       

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
              , @n_err = 83060 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Update on wave Failed (ispRLWAV61)' + ' ( '
                            + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
      END
   END

   RETURN_SP:

   -----Delete pickdetail_WIP work in progress staging table
   IF @n_continue IN ( 1, 2 )
   BEGIN
      EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                  , @c_Wavekey = @c_wavekey
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ispRLWAV61"
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