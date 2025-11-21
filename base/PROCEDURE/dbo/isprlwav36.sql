SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Stored Procedure: ispRLWAV36                                             */
/* Creation Date: 20-JAN-2021                                               */
/* Copyright: LFL                                                           */
/* Written by:                                                              */
/*                                                                          */
/* Purpose: WMS-16019_iicombined_Exceed_ReleaseWaveSP                       */
/*                                                                          */
/* Called By: wave                                                          */
/*                                                                          */
/* PVCS Version: 1.2                                                        */
/*                                                                          */
/* Version: 7.0                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date        Author   Ver  Purposes                                       */
/* 17-FEB-2021 CSCHONG  1.0  WMS-16019 revised field logic (CS01)           */
/* 18-JUL-2022 CSCHONG  1.1  Devops Scripts Combine & WMS-20186 (CS02)      */
/* 06-Oct-2022 WLChooi  1.2  WMS-20942 - 1 ID 1 Replen Record (WL01)        */
/****************************************************************************/

CREATE PROCEDURE [dbo].[ispRLWAV36]
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

   DECLARE @c_Storerkey        NVARCHAR(15)
         , @c_Sku              NVARCHAR(20)
         , @c_Facility         NVARCHAR(5)
         , @c_SourceType       NVARCHAR(30)
         , @c_WaveType         NVARCHAR(10)
         , @c_Lot              NVARCHAR(10)
         , @c_FromLoc          NVARCHAR(10)
         , @c_ToLoc            NVARCHAR(10)
         , @c_ID               NVARCHAR(18)
         , @c_ToID             NVARCHAR(18)
         , @c_Packkey          NVARCHAR(10)
         , @c_PackUOM          NVARCHAR(10)
         , @c_UOM              NVARCHAR(10)
         , @n_Qty              INT
         , @c_ReplenishmentKey NVARCHAR(10)
         , @n_RowID            INT
         , @n_UCCQty           INT
         , @c_UCCNo            NVARCHAR(20)
         , @n_OrderCnt         INT
         , @c_ReplenType       NVARCHAR(10)
         , @c_DeviceID         NVARCHAR(20)
         , @c_IPAddress        NVARCHAR(40)
         , @c_DevicePosition   NVARCHAR(10)
         , @c_DevLoc           NVARCHAR(10)
         , @c_LabelNo          NVARCHAR(20)
         , @c_Orderkey         NVARCHAR(10)
         , @c_Pickslipno       NVARCHAR(10)
         , @c_Loadkey          NVARCHAR(10)
         , @c_DocType          NVARCHAR(1)
         , @c_OrderType        NVARCHAR(10)
         , @c_Consigneekey     NVARCHAR(15)
         , @c_PrevConsigneekey NVARCHAR(15)
         , @c_Userdefine03     NVARCHAR(20)
         , @n_Position         INT
         , @c_dropid           NVARCHAR(20)
         , @n_noofline         INT
         , @n_innerqty         FLOAT
         , @n_inner            INT
         , @n_loose            INT
         , @n_looseinner       INT
         , @c_LOTT07           NVARCHAR(30) --CS01
         , @c_trmlogkey        NVARCHAR(10) --CS01
         , @c_tablename        NVARCHAR(30) --CS01
         , @c_key01            NVARCHAR(10) --CS01
         , @c_key02            NVARCHAR(30) --CS01
         , @c_key03            NVARCHAR(20) --CS01
         , @n_lliqty           INT          --CS02
         , @n_Oriqty           INT          --CS02

   SET @c_SourceType = N'ispRLWAV36'

   -----Get Storerkey, facility
   IF (  @n_continue = 1
    OR   @n_continue = 2)
   BEGIN
      SELECT TOP 1 @c_Storerkey = O.StorerKey
                 , @c_Facility = O.Facility
                 , @c_WaveType = W.WaveType
      FROM WAVE W (NOLOCK)
      JOIN WAVEDETAIL WD (NOLOCK) ON W.WaveKey = WD.WaveKey
      JOIN ORDERS O (NOLOCK) ON  WD.OrderKey = O.OrderKey
                             AND W.WaveKey = @c_wavekey
   END

   -----Wave Validation-----
   IF @n_continue = 1
   OR @n_continue = 2
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM REPLENISHMENT RP (NOLOCK)
                   WHERE RP.Wavekey = @c_wavekey)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 83010
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': This Wave has been released. (ispRLWAV36)'
      END
   END

   --Create pickdetail Work in progress temporary table
   IF @n_continue = 1
   OR @n_continue = 2
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

      CREATE TABLE #DEVICEPOS
      (
         RowId          INT          IDENTITY(1, 1)
       , DevicePosition NVARCHAR(10) NULL
       , IPAddress      NVARCHAR(40) NULL
       , Loc            NVARCHAR(10) NULL
      )
   END

   BEGIN TRAN

   --Initialize Pickdetail work in progress staging table
   IF @n_continue = 1
   OR @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                  , @c_Wavekey = @c_wavekey
                                  , @c_WIP_RefNo = @c_SourceType
                                  , @c_PickCondition_SQL = ''
                                  , @c_Action = 'I'              --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
                                  , @c_RemoveTaskdetailkey = 'N' --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
                                  , @b_Success = @b_Success OUTPUT
                                  , @n_Err = @n_err OUTPUT
                                  , @c_ErrMsg = @c_errmsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END

      UPDATE #PickDetail_WIP
      SET ToLoc = ''
   END

   --select '1' ,* from #PickDetail_WIP  PD
   --where UOM IN('7')
   --where  PD.DropID <> ''
   --          AND PD.DropID IS NOT NULL
   --          AND PD.UOM IN('7')

   -- SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.Id, SUM(PD.Qty),  PACK.Packkey, PACK.PackUOM3, PD.dropid, COUNT(DISTINCT PD.Orderkey) AS ordercnt,
   --                 PD.Uom, MAX(O.DocType),LOTT.Lottable07
   --          FROM WAVEDETAIL WD (NOLOCK)
   --          JOIN #PickDetail_WIP PD ON WD.Orderkey = PD.Orderkey
   --          JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
   --          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
   --          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
   --          Join lotattribute LOTT with(nolock)  ON LOTT.lot = PD.lot
   --          --JOIN UCC (NOLOCK) ON PD.Storerkey = UCC.Storerkey AND PD.Sku = UCC.Sku AND PD.LOT = UCC.LOT AND PD.LOC = UCC.LOC AND PD.ID = UCC.ID
   --          WHERE WD.Wavekey = @c_Wavekey
   --          --AND PD.DropID <> ''
   --          --AND PD.DropID IS NOT NULL
   --          AND PD.UOM IN('7')
   --          GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.Id,  PACK.Packkey, PACK.PackUOM3, PD.dropid, PD.UOM,LOTT.Lottable07
   --          ORDER BY PD.UOM, PD.Sku, PD.Loc
   --GOTO RETURN_SP

   -----Create replenishment task for pick face picking
   IF (  @n_continue = 1
    OR   @n_continue = 2)
   BEGIN
      --Retreive UCC pick
      DECLARE cur_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.Storerkey
           , PD.Sku
           , PD.Lot
           , PD.Loc
           , PD.ID   --WL01
           , SUM(PD.Qty)   --WL01
           , PACK.InnerPack
           , PACK.PackKey
           , PACK.PackUOM3
           , PD.DropID
           , COUNT(DISTINCT PD.OrderKey) AS ordercnt
           , PD.UOM
           , MAX(O.DocType)
           , LOTT.Lottable07
           , LLI.Qty --CS02   --WL01
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN #PickDetail_WIP PD ON WD.OrderKey = PD.OrderKey
      JOIN ORDERS O (NOLOCK) ON PD.OrderKey = O.OrderKey
      JOIN SKU (NOLOCK) ON  PD.Storerkey = SKU.StorerKey
                        AND PD.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
      JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.Lot = PD.Lot
      --JOIN LOTxLOCxID lli WITH (NOLOCK) ON lli.Id = PD.ID --CS02   --WL01
      CROSS APPLY (SELECT SUM(Qty) AS Qty
                   FROM LOTXLOCXID WITH (NOLOCK)
                   WHERE ID = PD.ID) AS LLI   --WL01
      WHERE WD.WaveKey = @c_wavekey
      --AND PD.DropID <> ''
      --AND PD.DropID IS NOT NULL
      AND   PD.UOM IN ( '6' ) --CS02
      GROUP BY PD.Storerkey
             , PD.Sku
             , PD.Lot
             , PD.Loc
             , PD.ID   --WL01
             , PACK.InnerPack
             , PACK.PackKey
             , PACK.PackUOM3
             , PD.DropID
             , PD.UOM
             , LOTT.Lottable07
             , LLI.Qty --CS02   --WL01
      ORDER BY PD.UOM
             , PD.Sku
             , PD.Loc

      OPEN cur_Pick

      FETCH FROM cur_Pick
      INTO @c_Storerkey
         , @c_Sku
         , @c_Lot
         , @c_FromLoc
         , @c_ID
         , @n_Qty
         , @n_innerqty
         , @c_Packkey
         , @c_PackUOM
         , @c_dropid
         , @n_OrderCnt
         , @c_UOM
         , @c_DocType
         , @c_LOTT07
         , @n_lliqty --CS02

      WHILE @@FETCH_STATUS = 0
      AND   @n_continue IN ( 1, 2 )
      BEGIN
         SET @c_ToID = @c_ID
         SET @c_PackUOM = N'EA'
         SET @c_ToLoc = N''
         SET @n_noofline = 1
         --SET @n_innerqty  =1
         SET @n_inner = 1
         SET @n_loose = 0
         SET @n_looseinner = 0
         SET @n_Oriqty = 0

         -- select @c_UCCNo '@c_UCCNo', @c_FromLoc '@c_FromLoc',@c_Sku '@c_Sku', @c_Lot '@c_Lot', @c_Id '@c_Id'
         --  SELECT * FROM #PickDetail_WIP WHERE uom= 6
         IF @c_UOM = '6' --CS02
         BEGIN
            IF EXISTS (  SELECT 1
                         FROM REPLENISHMENT REP (NOLOCK)
                         WHERE RefNo = @c_dropid
                         AND   Storerkey = @c_Storerkey
                         AND   Sku = @c_Sku
                         AND   FromLoc = @c_FromLoc
                         AND   Lot = @c_Lot
                         AND   Id = @c_ID
                         AND   Wavekey = @c_wavekey)
            BEGIN
               GOTO NEXT_PICK
            END
         END

         SET @n_inner = @n_Qty / NULLIF(CAST(@n_innerqty AS INT), 0)
         SET @n_loose = @n_Qty % NULLIF(CAST(@n_innerqty AS INT), 0)


         IF @n_loose > 0
         BEGIN
            SET @n_looseinner = 1
            SET @n_noofline = @n_inner + @n_looseinner
         END
         ELSE
         BEGIN
            SET @n_noofline = @n_inner
         END
         --CS02 S

         SELECT @n_Oriqty = SUM(PD.Qty)
         FROM #PickDetail_WIP PD
         WHERE PD.UOM = '6'
         AND   PD.Lot = @c_Lot
         AND   PD.Sku = @c_Sku
         AND   PD.ID = @c_ID
         AND   PD.Loc = @c_FromLoc

         --CS02 E

         --IF @c_UOM = '2' AND @n_OrderCnt = 1
         --BEGIN
         --   SET @c_ReplenType = 'FCP'

         --   SELECT TOP 1 @c_Toloc = Short
         --   FROM CODELKUP (NOLOCK)
         --   WHERE Storerkey = @c_Storerkey
         --   AND Listname = 'RDTREPLEN'
         --   AND UDF01 = 'FCP'
         --   AND UDF02 = @c_DocType
         --END
         --ELSE IF @c_UOM = '2' AND @n_OrderCnt > 1
         --BEGIN
         --   SET @c_ReplenType = 'FCS'

         --   SELECT TOP 1 @c_Toloc = Short
         --   FROM CODELKUP (NOLOCK)
         --   WHERE Storerkey = @c_Storerkey
         --   AND Listname = 'RDTREPLEN'
         --   AND UDF01 = 'FCS'
         --END
         --ELSE
         --BEGIN
         SET @c_ReplenType = N'RPL'
         --CS01 START
         --SELECT TOP 1 @c_ToLoc = L.Loc
         --FROM SKUXLOC SL (NOLOCK)
         --JOIN LOC L (NOLOCK) ON SL.Loc = L.Loc
         --WHERE L.Facility = @c_Facility
         --AND L.LocationType = 'DYNPPICK'
         --AND L.LocationFlag = 'NONE'
         --AND SL.Storerkey = @c_Storerkey
         --AND SL.Sku = @c_Sku
         --AND (SL.Qty-SL.QtyPicked) + SL.QtyExpected > 0
         --ORDER BY (SL.Qty-SL.QtyPicked) + SL.QtyExpected, L.LogicalLocation, L.Loc

         SELECT TOP 1 @c_ToLoc = L.Loc
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LLI.Lot = LOTT.Lot
         JOIN LOC L (NOLOCK) ON LLI.Loc = L.Loc
         WHERE L.Facility = @c_Facility
         AND   L.LocationType = 'DYNPPICK'
         AND   L.LocationFlag = 'NONE'
         AND   LLI.StorerKey = @c_Storerkey
         AND   LLI.Sku = @c_Sku
         AND   LOTT.Lottable07 = @c_LOTT07
         AND   (LLI.Qty - LLI.QtyPicked) + LLI.QtyExpected > 0
         ORDER BY (LLI.Qty - LLI.QtyPicked) + LLI.QtyExpected
                , L.LogicalLocation
                , L.Loc


         --CS01 END
         --Find loc with zero stock with putawayzone priority in skuconfig
         IF ISNULL(@c_ToLoc, '') = ''
         BEGIN
            SELECT TOP 1 @c_ToLoc = L.Loc
            FROM LOC L (NOLOCK)
            LEFT JOIN SKUxLOC SL (NOLOCK) ON  L.Loc = SL.Loc
                                          AND SL.StorerKey = @c_Storerkey
                                          AND SL.Sku = @c_Sku
            LEFT JOIN SKUConfig SC (NOLOCK) ON  L.PutawayZone = SC.Data
                                            AND SC.StorerKey = @c_Storerkey
                                            AND SC.SKU = @c_Sku
            WHERE L.Facility = @c_Facility
            AND   L.LocationType = 'DYNPPICK'
            AND   L.LocationFlag = 'NONE'
            AND   ISNULL(SL.Qty, 0) = 0
            ORDER BY CASE WHEN SC.Data IS NOT NULL THEN 1
                          ELSE 2 END
                   , L.LogicalLocation
                   , L.Loc
         END

         --Find loc by putawayzone in codelkup
         IF ISNULL(@c_ToLoc, '') = ''
         BEGIN
            SELECT TOP 1 @c_ToLoc = L.Loc
            FROM LOC L (NOLOCK)
            LEFT JOIN SKUxLOC SL (NOLOCK) ON  L.Loc = SL.Loc
                                          AND SL.StorerKey = @c_Storerkey
                                          AND SL.Sku = @c_Sku
            WHERE L.Facility = @c_Facility
            AND   L.LocationType <> 'OTHER'
            AND   L.LocationFlag = 'NONE'
            AND   L.PutawayZone IN (  SELECT CL.Short
                                      FROM CODELKUP CL (NOLOCK)
                                      WHERE CL.LISTNAME = 'LSMIXLOC'
                                      AND   CL.Storerkey = @c_Storerkey )
            AND   ISNULL(SL.Qty, 0) = 0
            ORDER BY L.LogicalLocation
                   , L.Loc
         END
         --END

         IF @c_ToLoc = ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 83020
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Unable find destination loc for '
                               + RTRIM(@c_ReplenType) + ' for Sku ' + RTRIM(@c_Sku) + '. (ispRLWAV36)'
            BREAK
         END
         --WHILE @n_noofline > 0
         --BEGIN
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


         -- select @c_ReplenishmentKey '@c_ReplenishmentKey'

         INSERT INTO REPLENISHMENT (ReplenishmentGroup, ReplenishmentKey, Storerkey, Sku, FromLoc, ToLoc, Lot, Id, Qty
                                  , UOM, PackKey, Confirmed, MoveRefKey, ToID, PendingMoveIn, QtyReplen, QtyInPickLoc
                                  , RefNo, Wavekey, Remark, ReplenNo, OriginalQty, OriginalFromLoc, DropID)
         VALUES ('DYNAMIC', @c_ReplenishmentKey, @c_Storerkey, @c_Sku, @c_FromLoc, @c_ToLoc, @c_Lot, @c_ID
               , @n_lliqty --(@n_noofline*@n_innerqty),     --CS02
               , @c_PackUOM, @c_Packkey, 'N', '', @c_ToID, 0, 0, 0, @c_UCCNo, @c_wavekey, '', @c_ReplenType, @n_Oriqty
               , @c_SourceType, @c_UCCNo)

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                 , @n_err = 83030 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                               + ': Error Insert Replenishment Table. (ispRLWAV36)' + ' ( ' + ' SQLSvr MESSAGE='
                               + RTRIM(@c_errmsg) + ' ) '
         END
         --    SET @n_noofline = @n_noofline - 1
         --END
         IF @c_ReplenType = 'RPL'
         BEGIN
            UPDATE #PickDetail_WIP
            SET ToLoc = @c_ToLoc
            WHERE DropID = @c_UCCNo
            AND   Storerkey = @c_Storerkey
            AND   Sku = @c_Sku
         END

         NEXT_PICK:

         FETCH FROM cur_Pick
         INTO @c_Storerkey
            , @c_Sku
            , @c_Lot
            , @c_FromLoc
            , @c_ID
            , @n_Qty
            , @n_innerqty
            , @c_Packkey
            , @c_PackUOM
            , @c_dropid
            , @n_OrderCnt
            , @c_UOM
            , @c_DocType
            , @c_LOTT07
            , @n_lliqty --CS02
      END
      CLOSE cur_Pick
      DEALLOCATE cur_Pick
   END

   -----Generate Pickslip No------
   IF @n_continue = 1
   OR @n_continue = 2
   BEGIN
      EXEC isp_CreatePickSlip @c_Wavekey = @c_wavekey
                            , @c_LinkPickSlipToPick = 'Y' --Y=Update pickslipno to pickdetail.pickslipno
                            , @c_ConsolidateByLoad = 'N'
                            , @b_Success = @b_Success OUTPUT
                            , @n_Err = @n_err OUTPUT
                            , @c_ErrMsg = @c_errmsg OUTPUT

      IF @b_Success = 0
         SELECT @n_continue = 3
   END

   --Update load plan
   IF  (  @n_continue = 1
     OR   @n_continue = 2)
   AND @c_WaveType = 'DAS'
   BEGIN
      DECLARE cur_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT LPD.LoadKey
      FROM #PickDetail_WIP PD
      JOIN LoadPlanDetail LPD (NOLOCK) ON PD.OrderKey = LPD.OrderKey

      OPEN cur_LOAD

      FETCH FROM cur_LOAD
      INTO @c_Loadkey

      WHILE @@FETCH_STATUS = 0
      AND   @n_continue IN ( 1, 2 )
      BEGIN
         UPDATE LoadPlan WITH (ROWLOCK)
         SET LoadPickMethod = 'C'
         WHERE LoadKey = @c_Loadkey

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                 , @n_err = 83090 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Error Update LOADPLAN Table. (ispRLWAV36)'
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         END

         FETCH FROM cur_LOAD
         INTO @c_Loadkey
      END
      CLOSE cur_LOAD
      DEALLOCATE cur_LOAD
   END

   /*CS01 START*/
   -- insert TransmitLog3 table
   IF @c_WaveType = 'DAS'
   BEGIN

      SET @c_tablename = N''
      SET @c_key01 = N''
      SET @c_key02 = N''
      SET @c_key03 = N''

      SELECT DISTINCT @c_tablename = N'WVERCMLOG'
                    , @c_key01 = WV.WaveKey
                    , @c_key02 = N''
                    , @c_key03 = ORDERS.StorerKey
      FROM WAVE WV WITH (NOLOCK)
      JOIN WAVEDETAIL WITH (NOLOCK) ON WAVEDETAIL.WaveKey = WV.WaveKey
      JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.OrderKey = ORDERS.OrderKey)
      WHERE WAVEDETAIL.WaveKey = @c_wavekey


      SELECT @n_continue = 1
           , @b_Success = 1

      --EXEC dbo.ispGenTransmitLog3 @c_tablename, @c_key01, @c_key02, @c_key03, ''
      --   , @b_success OUTPUT
      --   , @n_err OUTPUT
      --   , @c_errmsg OUTPUT
      IF NOT EXISTS (  SELECT 1
                       FROM TRANSMITLOG3 (NOLOCK)
                       WHERE tablename = @c_tablename
                       AND   key1 = @c_key01
                       AND   key2 = @c_key02
                       AND   key3 = @c_key03
                       AND   tablename = @c_tablename)
      BEGIN

         BEGIN TRAN
         SELECT @b_Success = 0
         EXECUTE nspg_GetKey
            -- Change by June 15.Jun.2004
            -- To standardize name use in generating transmitlog3..transmitlogkey
            -- 'Transmitlog3Key'
            'TransmitlogKey3'
          , 10
          , @c_trmlogkey OUTPUT
          , @b_Success OUTPUT
          , @n_err OUTPUT
          , @c_errmsg OUTPUT

         IF @b_Success = 1
         BEGIN
            --SELECT @c_trmlogkey = 'P' + RTRIM(@c_PickSlipNo)
            COMMIT TRAN
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                 , @n_err = 81033
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Get transmitlogkey Failed. (ispRLWAV36)'
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         --BREAK
         END

         --  SET @n_seqno = 1

         BEGIN TRAN

         INSERT INTO TRANSMITLOG3 (transmitlogkey, tablename, key1, key2, key3, transmitflag, transmitbatch)
         VALUES (@c_trmlogkey, @c_tablename, @c_key01, ISNULL(@c_key02, ''), @c_key03, '0', '')

         SELECT @n_err = @@ERROR
         --print '@n_err : ' + cast(@n_err as nvarchar(5))

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                 , @n_err = 81053
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Insert Transmitlog3 Failed. (ispRLWAV36)'
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            --  ROLLBACK TRAN

            GOTO RETURN_SP
         END
         ELSE
            COMMIT TRAN
      END
   END
   /*CS01 END*/

   --Create packtask record
   IF (  @n_continue = 1
    OR   @n_continue = 2)
   BEGIN
      DECLARE cur_PackTaskOrd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.OrderKey
           , O.ConsigneeKey
           , O.UserDefine03
      FROM #PickDetail_WIP PD
      JOIN ORDERS O (NOLOCK) ON PD.OrderKey = O.OrderKey
      WHERE O.DocType = 'N'
      GROUP BY O.UserDefine03
             , O.ConsigneeKey
             , O.OrderKey
      ORDER BY CASE WHEN O.UserDefine03 = 'NC' THEN 1
                    WHEN O.UserDefine03 = 'SC' THEN 2
                    ELSE 3 END
             , O.ConsigneeKey
             , O.OrderKey

      OPEN cur_PackTaskOrd

      FETCH FROM cur_PackTaskOrd
      INTO @c_Orderkey
         , @c_Consigneekey
         , @c_Userdefine03

      SET @n_Position = 0
      SET @c_PrevConsigneekey = N'*'
      --SET @c_FirstSC = 'Y'
      WHILE @@FETCH_STATUS = 0
      AND   @n_continue IN ( 1, 2 )
      BEGIN
         IF @c_Userdefine03 = 'NC'
            SET @n_Position = 1
         ELSE IF @c_Userdefine03 = 'SC'
            SET @n_Position = 2
         /*ELSE IF @c_Userdefine03 = 'SC' AND @n_Position = 0 AND @c_FirstSC = 'Y'
           BEGIN
              SET @n_Position = 1
              SET @c_FirstSC = 'N'
           END
           ELSE IF @c_Userdefine03 = 'SC' AND @n_Position = 1 AND @c_FirstSC = 'Y'
           BEGIN
              SET @n_Position = 2
              SET @c_FirstSC = 'N'
           END*/
         ELSE
         BEGIN
            IF @n_Position < 2
               SET @n_Position = 2

            IF @c_PrevConsigneekey <> @c_Consigneekey
               SET @n_Position = @n_Position + 1
         END

         INSERT INTO PackTask (TaskBatchNo, Orderkey, DevicePosition)
         VALUES (@c_wavekey, @c_Orderkey, CAST(@n_Position AS NVARCHAR))

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                 , @n_err = 83100 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Error Insert PACKTASK Table. (ispRLWAV36)'
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         END

         SET @c_PrevConsigneekey = @c_Consigneekey

         FETCH FROM cur_PackTaskOrd
         INTO @c_Orderkey
            , @c_Consigneekey
            , @c_Userdefine03
      END
      CLOSE cur_PackTaskOrd
      DEALLOCATE cur_PackTaskOrd
   END

   -----Update pickdetail_WIP work in progress staging table back to pickdetail
   IF @n_continue = 1
   OR @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                  , @c_Wavekey = @c_wavekey
                                  , @c_WIP_RefNo = @c_SourceType
                                  , @c_PickCondition_SQL = ''
                                  , @c_Action = 'U'              --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
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
   IF @n_continue = 1
   OR @n_continue = 2
   BEGIN
      UPDATE WAVE
      SET TMReleaseFlag = 'Y'
        , TrafficCop = NULL
        , EditWho = SUSER_SNAME()
        , EditDate = GETDATE()
      WHERE WaveKey = @c_wavekey

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
              , @n_err = 83110 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Update on wave Failed (ispRLWAV36)' + ' ( '
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
                                  , @c_Action = 'D'              --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
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
      IF  @@TRANCOUNT = 1
      AND @@TRANCOUNT > @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ispRLWAV36"
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