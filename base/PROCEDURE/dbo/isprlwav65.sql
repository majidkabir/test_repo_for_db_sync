SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Stored Procedure: ispRLWAV65                                             */
/* Creation Date: 15-Sep-2023                                               */
/* Copyright: Maersk                                                        */
/* Written by: WLChooi                                                      */
/*                                                                          */
/* Purpose: WMS-23615 - [AU] LEVIS RELEASE WAVE (REPLENISHMENT) CR          */
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
/* 15-Sep-2023 WLChooi  1.0  DevOps Combine Script                          */
/* 19-Sep-2023 WLChooi  1.1  WMS-23615 - Add Validation (WL01)              */
/* 12-Oct-2023 WLChooi  1.2  WMS-23615 - SUM Qty by Loc (WL03)              */
/****************************************************************************/

CREATE   PROCEDURE [dbo].[ispRLWAV65]
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
         , @c_Putawayzone      NVARCHAR(50) = ''   
         , @c_FromLocPZ        NVARCHAR(50) = ''    

   SET @c_SourceType = N'ispRLWAV65'

   -----Get Storerkey, facility    
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT TOP 1 @c_Storerkey = O.StorerKey
                 , @c_Facility = O.Facility
                 , @c_WaveType = W.WaveType
      FROM WAVE W (NOLOCK)
      JOIN WAVEDETAIL WD (NOLOCK) ON W.WaveKey = WD.WaveKey
      JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey AND W.WaveKey = @c_wavekey
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
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': This Wave has beed released. (ispRLWAV65)'
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

      UPDATE #PickDetail_WIP
      SET ToLoc = ''
   END

   -----Create replenishment task for pick face picking    
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      --Retreive UCC pick     
      DECLARE cur_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.Storerkey
           , PD.Sku
           , PD.Lot
           , PD.Loc
           , PD.ID
           , SUM(PD.Qty)
           , UCC.qty
           , PACK.PackKey
           , PACK.PackUOM3
           , UCC.UCCNo
           , COUNT(DISTINCT PD.OrderKey) AS ordercnt
           , PD.UOM
           , MAX(O.Doctype)
           , SKU.PutawayZone
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN #PickDetail_WIP PD ON WD.OrderKey = PD.OrderKey
      JOIN ORDERS O (NOLOCK) ON PD.OrderKey = O.OrderKey
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.StorerKey AND PD.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
      JOIN UCC (NOLOCK) ON  PD.Storerkey = UCC.Storerkey
                        AND PD.Sku = UCC.SKU
                        AND PD.DropID = UCC.UCCNo
                        AND PD.Lot = UCC.Lot
                        AND PD.Loc = UCC.Loc
                        AND PD.ID = UCC.Id
      WHERE WD.WaveKey = @c_wavekey AND PD.DropID <> '' 
      AND PD.DropID IS NOT NULL AND PD.UOM IN ( '2', '6', '7' )
      GROUP BY PD.Storerkey
             , PD.Sku
             , PD.Lot
             , PD.Loc
             , PD.ID
             , UCC.qty
             , PACK.PackKey
             , PACK.PackUOM3
             , UCC.UCCNo
             , PD.UOM
             , SKU.PutawayZone
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
         , @n_UCCQty
         , @c_Packkey
         , @c_PackUOM
         , @c_UCCNo
         , @n_OrderCnt
         , @c_UOM
         , @c_DocType
         , @c_Putawayzone

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN ( 1, 2 )
      BEGIN
         SET @c_ToID = @c_ID
         SET @c_PackUOM = N'CA'
         SET @c_ToLoc = N''
         SET @c_FromLocPZ = N''

         IF @c_UOM = '7'
         BEGIN
            IF EXISTS (  SELECT 1
                         FROM REPLENISHMENT REP (NOLOCK)
                         WHERE RefNo = @c_UCCNo
                         AND   Storerkey = @c_Storerkey
                         AND   Sku = @c_Sku
                         AND   FromLoc = @c_FromLoc
                         AND   Lot = @c_Lot
                         AND   Id = @c_ID)
            BEGIN
               GOTO NEXT_PICK
            END
         END

         IF @c_UOM = '2' AND @n_OrderCnt = 1
         BEGIN
            SET @c_ReplenType = N'FCP'

            SELECT TOP 1 @c_ToLoc = Short
            FROM CODELKUP (NOLOCK)
            WHERE Storerkey = @c_Storerkey AND LISTNAME = 'RDTREPLEN' AND UDF01 = 'FCP' AND UDF02 = @c_DocType
         END
         ELSE IF @c_UOM = '2' AND @n_OrderCnt > 1
         BEGIN
            SET @c_ReplenType = N'FCS'

            SELECT TOP 1 @c_ToLoc = Short
            FROM CODELKUP (NOLOCK)
            WHERE Storerkey = @c_Storerkey AND LISTNAME = 'RDTREPLEN' AND UDF01 = 'FCS'
         END
         ELSE IF @c_UOM IN ('6','7') AND ISNULL(@c_UCCNo,'') <> ''
         BEGIN
            SET @c_ReplenType = N'RPL'

            SELECT TOP 1 @c_ToLoc = L.Loc
            FROM SKUxLOC SL (NOLOCK)
            JOIN LOC L (NOLOCK) ON SL.Loc = L.Loc
            WHERE L.Facility = @c_Facility
            AND   SL.StorerKey = @c_Storerkey
            AND   SL.Sku = @c_Sku
            AND   SL.LocationType IN ('PICK')
            ORDER BY L.Loc
 
            IF ISNULL(@c_ToLoc, '') = ''
            BEGIN
               SELECT TOP 1 @c_ToLoc = L.Loc
               FROM SKUxLOC SL (NOLOCK)
               JOIN LOC L (NOLOCK) ON SL.Loc = L.Loc
               WHERE L.Facility = @c_Facility
               AND   SL.StorerKey = @c_Storerkey
               AND   SL.Sku = @c_Sku
               AND   L.PutawayZone = @c_Putawayzone
               AND   SL.Qty > 0
               ORDER BY L.Loc
            END

            IF ISNULL(@c_ToLoc, '') = ''
            BEGIN
               SELECT TOP 1 @c_ToLoc = L.Loc
               FROM LOC L (NOLOCK)
               LEFT JOIN LOTXLOCXID LLI (NOLOCK) ON LLI.Loc = L.Loc
               WHERE NOT EXISTS ( SELECT 1
                                  FROM SKUXLOC SL (NOLOCK)
                                  WHERE SL.Loc = L.Loc
                                  AND SL.LocationType = 'PICK' )
               AND L.Facility = @c_Facility
               AND L.PutawayZone = @c_Putawayzone
               --AND ISNULL(LLI.Qty,0) + ISNULL(LLI.PendingMoveIn,0) = 0   --WL03
               AND NOT EXISTS ( SELECT 1                            --WL01
                                FROM REPLENISHMENT RP (NOLOCK)      --WL01
                                WHERE RP.Storerkey = @c_Storerkey   --WL01
                                AND RP.SKU <> @c_SKU                --WL01
                                AND RP.Confirmed = 'N'              --WL01
                                AND RP.ToLoc = L.Loc )              --WL01
               GROUP BY L.Loc, L.LogicalLocation   --WL03
               HAVING SUM(ISNULL(LLI.Qty,0) + ISNULL(LLI.PendingMoveIn,0)) = 0   --WL03
               ORDER BY L.LogicalLocation
            END
         END
         ELSE
         BEGIN
            GOTO NEXT_PICK
         END

         IF @c_ToLoc = ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 83020
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Unable find destination loc for '
                               + RTRIM(@c_ReplenType) + ' for Sku ' + RTRIM(@c_Sku) + '. (ispRLWAV65)'
            BREAK
         END

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

         SELECT @c_FromLocPZ = ISNULL(LOC.PutawayZone,'')
         FROM LOC (NOLOCK)
         WHERE LOC.LOC = @c_FromLoc

         INSERT INTO REPLENISHMENT (ReplenishmentGroup, ReplenishmentKey, Storerkey, Sku, FromLoc, ToLoc, Lot, Id, Qty
                                  , UOM, PackKey, Confirmed, MoveRefKey, ToID, PendingMoveIn, QtyReplen, QtyInPickLoc
                                  , RefNo, Wavekey, Remark, ReplenNo, OriginalQty, OriginalFromLoc, DropID)
         VALUES (IIF(@c_ReplenType = 'RPL', @c_FromLocPZ, 'DYNAMIC'), @c_ReplenishmentKey, @c_Storerkey, @c_Sku, @c_FromLoc, @c_ToLoc, @c_Lot, @c_ID, @n_UCCQty
               , @c_PackUOM, @c_Packkey, 'N', '', @c_ToID, 0, 0, 0, @c_UCCNo, @c_wavekey, '', @c_ReplenType, @n_Qty
               , @c_SourceType, @c_UCCNo)

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                 , @n_err = 83030 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                               + ': Error Insert Replenishment Table. (ispRLWAV65)' + ' ( ' + ' SQLSvr MESSAGE='
                               + RTRIM(@c_errmsg) + ' ) '
         END

         IF @c_ReplenType = 'RPL'
         BEGIN
            UPDATE #PickDetail_WIP
            SET ToLoc = @c_ToLoc
            WHERE DropID = @c_UCCNo AND Storerkey = @c_Storerkey AND Sku = @c_Sku
         END

         NEXT_PICK:

         FETCH FROM cur_Pick
         INTO @c_Storerkey
            , @c_Sku
            , @c_Lot
            , @c_FromLoc
            , @c_ID
            , @n_Qty
            , @n_UCCQty
            , @c_Packkey
            , @c_PackUOM
            , @c_UCCNo
            , @n_OrderCnt
            , @c_UOM
            , @c_DocType
            , @c_Putawayzone
      END
      CLOSE cur_Pick
      DEALLOCATE cur_Pick
   END

   -----Generate Pickslip No------        
   IF @n_continue = 1 OR @n_continue = 2
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

   --Create packtask record               
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      DECLARE cur_PackTaskOrd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.OrderKey
           , O.ConsigneeKey
           , O.UserDefine03
      FROM #PickDetail_WIP PD
      JOIN ORDERS O (NOLOCK) ON PD.OrderKey = O.OrderKey
      WHERE O.Doctype = 'N'
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

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN ( 1, 2 )
      BEGIN
         IF @c_Userdefine03 = 'NC'
            SET @n_Position = 1
         ELSE IF @c_Userdefine03 = 'SC'
            SET @n_Position = 2
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
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Error Insert PACKTASK Table. (ispRLWAV65)'
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

   -----Update Wave Status-----    
   IF @n_continue = 1 OR @n_continue = 2
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
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Update on wave Failed (ispRLWAV65)' + ' ( '
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV65'
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