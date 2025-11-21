SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispRLWAV55                                         */  
/* Creation Date: 25-Aug-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20606 - ID-PUMA-Replenishment Strategy                  */ 
/*                                                                      */
/* Called By: Wave                                                      */ 
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 25-Aug-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 20-Feb-2023  WLChooi  1.1  WMS-20606 Modify B2B gen pickslip (WL01)  */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispRLWAV55]      
       @c_Wavekey      NVARCHAR(10)  
     , @b_Success      INT            OUTPUT  
     , @n_err          INT            OUTPUT  
     , @c_errmsg       NVARCHAR(250)  OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue              INT
         , @b_Debug                 INT
         , @n_StartTranCnt          INT
         , @c_Storerkey             NVARCHAR(15)
         , @c_Facility              NVARCHAR(5)
         , @c_ToPickLoc             NVARCHAR(20)

   DECLARE @c_SourceType            NVARCHAR(50) = 'ispRLWAV55'
         , @c_ReplenishmentKey      NVARCHAR(10)
         , @c_SKU                   NVARCHAR(20)
         , @c_FromLoc               NVARCHAR(20)
         , @c_ToLoc                 NVARCHAR(20)
         , @c_Lot                   NVARCHAR(10)
         , @c_ID                    NVARCHAR(30)
         , @c_ToID                  NVARCHAR(30)
         , @n_Qty                   INT
         , @c_Packkey               NVARCHAR(30)
         , @c_UOM                   NVARCHAR(10)
         , @c_ReplenishmentGroup    NVARCHAR(10)
         , @n_QtyAvailable          INT
         , @n_ReplenQty             INT
         , @n_ReplenQtyFinal        INT
         , @n_QtyShort              INT

   DECLARE @c_Loadkey               NVARCHAR(10)
         , @c_Orderkey              NVARCHAR(10)
         , @c_PAZone                NVARCHAR(30)
         , @c_PrevPAzone            NVARCHAR(30)
         , @c_GetPickDetailKey      NVARCHAR(10)
         , @c_PickDetailKey         NVARCHAR(10)
         , @c_RPickSlipNo           NVARCHAR(10)
         , @c_OrdLineNo             NVARCHAR(5)
         , @c_GetWavekey            NVARCHAR(10)
         , @c_GetLoadkey            NVARCHAR(10)
         , @c_GetPHOrdKey           NVARCHAR(10)
         , @c_GetWDOrdKey           NVARCHAR(10)
         , @c_Pickslipno            NVARCHAR(10)

   SET @b_Debug = @n_err

   IF ISNULL(@b_Debug,0) = 0 SET @b_Debug = 0
      
   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_Continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''

   -----Get Wave Info-----
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN      
      SELECT @c_Storerkey     = MAX(OH.Storerkey)
           , @c_Facility      = MAX(OH.Facility)
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      WHERE WD.WaveKey = @c_Wavekey      
   END

   -----Wave Validation-----
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 
                 FROM REPLENISHMENT RP (NOLOCK)
                 WHERE RP.Wavekey = @c_Wavekey    
                 ) 
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 67700    
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has been released. (ispRLWAV55)'     
         GOTO QUIT_SP 
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

   --Initialize Pickdetail work in progress staging table  
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN    	 	    	 	    	 
      EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
           ,@c_Wavekey               = @c_Wavekey  
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
   END

   --Main Process
   IF @b_Debug = 0
   BEGIN
      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END

      IF @@TRANCOUNT = 0
         BEGIN TRAN
   END

   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN 
      --Retrieve all lot of the wave from pick loc
      DECLARE CUR_PICKLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      WITH LOT_CTE AS
      (
         SELECT DISTINCT LLI.Lot
         FROM #PickDetail_WIP PD (NOLOCK)
         JOIN SKUxLOC SXL (NOLOCK) ON  PD.Storerkey = SXL.StorerKey
                                   AND PD.Sku = SXL.Sku
                                   AND PD.Loc = SXL.Loc
         JOIN LOTxLOCxID LLI (NOLOCK) ON  PD.Storerkey = LLI.StorerKey
                                      AND PD.Sku = LLI.Sku
                                      AND PD.Lot = LLI.Lot
                                      AND PD.Loc = LLI.Loc
                                      AND PD.ID = LLI.Id
         JOIN ORDERS O (NOLOCK) ON PD.OrderKey = O.OrderKey
         JOIN WAVEDETAIL WD (NOLOCK) ON O.OrderKey = WD.OrderKey
         WHERE WD.WaveKey = @c_Wavekey
         AND   SXL.LocationType IN ( 'PICK', 'CASE' )
         AND   LLI.QtyExpected > 0
      )
      SELECT LLI.StorerKey
           , LLI.Sku
           , LLI.Lot
           , LLI.Loc
           , LLI.Id
           , SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIN) AS Qty
           , PACK.PackKey
           , PACK.PackUOM3
      FROM LOTxLOCxID LLI (NOLOCK)
      JOIN SKUxLOC SL (NOLOCK) ON  LLI.StorerKey = SL.StorerKey
                               AND LLI.Sku = SL.Sku
                               AND LLI.Loc = SL.Loc
      JOIN SKU (NOLOCK) ON  LLI.StorerKey = SKU.StorerKey
                        AND LLI.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
      JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
      JOIN LOT_CTE ON LLI.Lot = LOT_CTE.Lot
      WHERE SL.LocationType IN ( 'PICK', 'CASE' )
      AND   LLI.StorerKey = @c_Storerkey
      AND   LOC.Facility = @c_Facility
      GROUP BY LLI.StorerKey
             , LLI.Sku
             , LLI.Lot
             , LLI.Loc
             , LLI.Id
             , PACK.PackKey
             , PACK.PackUOM3
      HAVING SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIN) < 0 --overallocate
      
      OPEN CUR_PICKLOC
      
      FETCH NEXT FROM CUR_PICKLOC
      INTO @c_Storerkey
         , @c_SKU
         , @c_Lot
         , @c_ToLoc
         , @c_ToID
         , @n_QtyShort
         , @c_Packkey
         , @c_UOM
      
      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN ( 1, 2 )
      BEGIN
         IF @n_QtyShort < 0
            SET @n_QtyShort = @n_QtyShort * -1

         SET @n_ReplenQty = @n_QtyShort

         --Retrieve stock from bulk
         DECLARE CUR_BULK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.Lot
              , LLI.Loc
              , LLI.Id
              , (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) AS QtyAvailable
         FROM LOTxLOCxID LLI (NOLOCK)
         JOIN SKUxLOC SL (NOLOCK) ON  LLI.StorerKey = SL.StorerKey
                                  AND LLI.Sku = SL.Sku
                                  AND LLI.Loc = SL.Loc
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
         AND   LLI.Sku = @c_SKU
         AND   LLI.Lot = @c_Lot
         AND   LOC.Facility = @c_Facility
         ORDER BY LOC.LogicalLocation
                , LOC.Loc

         OPEN CUR_BULK
      
         FETCH FROM CUR_BULK
         INTO @c_Lot
            , @c_FromLoc
            , @c_ID
            , @n_QtyAvailable

         WHILE @@FETCH_STATUS = 0 AND @n_Continue IN ( 1, 2 ) AND @n_ReplenQty > 0
         BEGIN
            SELECT @c_ReplenishmentKey = ''
                 , @c_ReplenishmentGroup = ''
      
            --IF @n_QtyAvailable >= @n_ReplenQty
            --BEGIN
            --   SET @n_ReplenQtyFinal = CEILING(@n_ReplenQty / (@n_CaseCnt * 1.00)) * @n_CaseCnt --Try to replenish full case
      
            --   IF @n_ReplenQtyFinal > @n_QtyAvailable --take all of available if less than full case
            --      SET @n_ReplenQtyFinal = @n_QtyAvailable
            --END
            --ELSE
            --   SET @n_ReplenQtyFinal = @n_QtyAvailable

            SET @n_ReplenQtyFinal = @n_QtyAvailable   --Replenish full ID

            SET @n_ReplenQty = @n_ReplenQty - @n_ReplenQtyFinal
      
            EXECUTE nspg_GetKey 'REPLENISHKEY'
                              , 10
                              , @c_ReplenishmentKey OUTPUT
                              , @b_Success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT
      
            IF NOT @b_Success = 1
            BEGIN
               SELECT @n_Continue = 3
            END
      
            INSERT INTO REPLENISHMENT (ReplenishmentGroup, ReplenishmentKey, Storerkey, Sku, FromLoc, ToLoc, Lot, Id, Qty
                                     , UOM, PackKey, Confirmed, MoveRefKey, ToID, PendingMoveIn, QtyReplen, QtyInPickLoc
                                     , RefNo, Wavekey, Remark, ReplenNo, OriginalQty, OriginalFromLoc)
            VALUES (@c_ReplenishmentGroup, @c_ReplenishmentKey, @c_Storerkey, @c_SKU, @c_FromLoc, @c_ToLoc, @c_Lot, @c_ID
                  , @n_ReplenQtyFinal, @c_UOM, @c_Packkey, 'N', '', @c_ToID, @n_ReplenQtyFinal, @n_ReplenQtyFinal, 0, ''
                  , @c_Wavekey, '', '', 0, @c_SourceType)
      
            IF @@ERROR <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 81007 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Error Insert Replenishment Table. (ispRLWAV55)'
                                  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END
      
            FETCH FROM CUR_BULK
            INTO @c_Lot
               , @c_FromLoc
               , @c_ID
               , @n_QtyAvailable
         END
         CLOSE CUR_BULK
         DEALLOCATE CUR_BULK
      
         FETCH FROM CUR_PICKLOC
         INTO @c_Storerkey
            , @c_SKU
            , @c_Lot
            , @c_ToLoc
            , @c_ToID
            , @n_QtyShort
            , @c_Packkey
            , @c_UOM
      END
      CLOSE CUR_PICKLOC
      DEALLOCATE CUR_PICKLOC
   END

   IF @b_Debug = 0
   BEGIN
      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
   END

   --Create Pickslip
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      IF @@TRANCOUNT = 0
         BEGIN TRAN

      SET @c_OrderKey = ''
      SET @c_PrevPAzone = ''
      SET @c_PickDetailKey = ''

      DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OH.Loadkey
                    , PDW.Orderkey
                    , L.PickZone
                    , PDW.PickDetailKey
      FROM #PickDetail_WIP PDW WITH (NOLOCK)
      LEFT OUTER JOIN RefKeyLookup WITH (NOLOCK) ON (RefKeyLookup.PickDetailKey = PDW.PickDetailKey)   
      JOIN LOC L WITH (NOLOCK) ON PDW.Loc = L.Loc 
      JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = PDW.OrderKey
      WHERE ISNULL(RefKeyLookup.PickSlipNo, '') = ''
      AND OH.DocType = 'E'   --WL01
      ORDER BY L.PickZone
             , PDW.PickDetailKey

      OPEN CUR_LOAD

      FETCH NEXT FROM CUR_LOAD
      INTO @c_Loadkey
         , @c_Orderkey
         , @c_PAZone
         , @c_GetPickDetailKey

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         IF ISNULL(@c_Orderkey, '0') = '0'
            BREAK

         IF @c_PrevPAZone <> @c_PAZone          
         BEGIN              
            SET @c_RPickSlipNo = ''

            EXECUTE nspg_GetKey 'PICKSLIP'
                              , 9
                              , @c_RPickSlipNo OUTPUT
                              , @b_Success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

            IF @b_Success = 1
            BEGIN
               SET @c_RPickSlipNo = 'P' + @c_RPickSlipNo

               INSERT INTO PICKHEADER (PickHeaderKey, WaveKey, OrderKey, ExternOrderKey, LoadKey, PickType, Zone
                                     , ConsoOrderKey, TrafficCop)
               VALUES (@c_RPickSlipNo, @c_Wavekey, '', @c_Loadkey, @c_Loadkey, '0', 'LP', @c_PAZone, '')

               SET @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                  SET @n_err = 81008 -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                  SET @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                  + ': Insert PICKHEADER Failed (ispRLWAV55)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_errmsg) + ' ) '
                  GOTO QUIT_SP
               END
            END
            ELSE
            BEGIN
               SELECT @n_Continue = 3
               SELECT @n_err = 81009
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Get PSNO Failed. (ispRLWAV55)'
               BREAK
            END       
         END

         IF @n_Continue = 1
         BEGIN
            DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR
            SELECT PICKDETAIL.PickDetailKey
                 , PICKDETAIL.OrderLineNumber
            FROM #PickDetail_WIP PICKDETAIL WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
            JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = PICKDETAIL.OrderKey)
            JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
            WHERE PICKDETAIL.PickDetailKey = @c_GetPickDetailKey
            AND   LOADPLANDETAIL.LoadKey = @c_LoadKey
            AND   LOC.PickZone = TRIM(@c_PAZone)
            ORDER BY PICKDETAIL.PickDetailKey

            OPEN C_PickDetailKey
            FETCH NEXT FROM C_PickDetailKey
            INTO @c_PickDetailKey
               , @c_OrdLineNo

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF NOT EXISTS (  SELECT 1
                                FROM RefKeyLookup WITH (NOLOCK)
                                WHERE PickDetailkey = @c_PickDetailKey)
               BEGIN
                  INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                  VALUES (@c_PickDetailKey, @c_RPickSlipNo, @c_OrderKey, @c_OrdLineNo, @c_Loadkey)

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @n_err = 81010
                     SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                        + ': Insert RefKeyLookup Failed. (ispRLWAV55)'
                     GOTO QUIT_SP
                  END
               END

               FETCH NEXT FROM C_PickDetailKey
               INTO @c_PickDetailKey
                  , @c_OrdLineNo
            END
            CLOSE C_PickDetailKey
            DEALLOCATE C_PickDetailKey
         END

         UPDATE #PickDetail_WIP
         SET PickSlipNo = @c_RPickSlipNo
         WHERE Pickdetailkey = @c_GetPickDetailKey

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_err = 81011
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                               + ': Update #TMP_PICK Failed. (ispRLWAV55)'
            GOTO QUIT_SP
         END

         IF @b_Debug = 0
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END
 
         SET @c_PrevPAzone = @c_PAZone

         FETCH NEXT FROM CUR_LOAD
         INTO @c_loadkey
            , @c_Orderkey
            , @c_PAZone
            , @c_GetPickDetailKey
      END
      CLOSE CUR_LOAD
      DEALLOCATE CUR_LOAD

      DECLARE CUR_WaveOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT WD.WaveKey
                    , LPD.LoadKey
                    , ''
                    , WD.OrderKey
      FROM WAVEDETAIL WD WITH (NOLOCK)
      JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (WD.OrderKey = LPD.OrderKey)
      JOIN #PickDetail_WIP PDET WITH (NOLOCK) ON PDET.OrderKey = WD.OrderKey
      JOIN LOC L WITH (NOLOCK) ON L.Loc = PDET.Loc
      WHERE WD.WaveKey = @c_Wavekey

      OPEN CUR_WaveOrder

      FETCH NEXT FROM CUR_WaveOrder
      INTO @c_GetWavekey
         , @c_GetLoadkey
         , @c_GetPHOrdKey
         , @c_GetWDOrdKey

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN

         IF NOT EXISTS (  SELECT 1
                          FROM PICKHEADER (NOLOCK)
                          WHERE WaveKey = @c_Wavekey
                          AND   OrderKey = @c_GetWDOrdKey)
         BEGIN
            IF @b_Debug = 0
               BEGIN TRAN

            EXECUTE nspg_GetKey 'PICKSLIP'
                              , 9
                              , @c_Pickslipno OUTPUT
                              , @b_Success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

            SET @c_Pickslipno = 'P' + @c_Pickslipno

            INSERT INTO PICKHEADER (PickHeaderKey, WaveKey, OrderKey, ExternOrderKey, LoadKey, PickType, Zone, ConsoOrderKey
                                  , TrafficCop)
            VALUES (@c_Pickslipno, @c_Wavekey, @c_GetWDOrdKey, @c_GetLoadkey, @c_GetLoadkey, '0', '3', '', '')

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
               SET @n_err = 81012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
               SET @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                               + ': Insert PICKHEADER Failed (ispRLWAV55)' + ' ( ' + ' SQLSvr MESSAGE='
                               + RTRIM(@c_errmsg) + ' ) '
               GOTO QUIT_SP
            END
         END

         --WL01 S
         IF EXISTS (SELECT 1
                    FROM ORDERS (NOLOCK)
                    WHERE Orderkey = @c_GetWDOrdKey
                    AND DocType = 'N')
         BEGIN
            UPDATE #PickDetail_WIP
            SET PickSlipNo = @c_Pickslipno
            WHERE OrderKey = @c_GetWDOrdKey

            SELECT @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @n_err = 81013
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                 + ': Update #TMP_PICK Failed. (ispRLWAV55)'
               GOTO QUIT_SP
            END
         END
         --WL01 E

         IF @b_Debug = 0
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END

         FETCH NEXT FROM CUR_WaveOrder
         INTO @c_GetWavekey
            , @c_GetLoadkey
            , @c_GetPHOrdKey
            , @c_GetWDOrdKey
      END
      CLOSE CUR_WaveOrder
      DEALLOCATE CUR_WaveOrder     
   END

   --Stamp Pickdetail.ID to Pickdetail.DropID
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      UPDATE #PickDetail_WIP
      SET DropID = ID
      WHERE WaveKey = @c_Wavekey
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
      UPDATE WAVE WITH (ROWLOCK)
      SET TMReleaseFlag = 'Y'        
       ,  TrafficCop = NULL      
       ,  EditWho = SUSER_SNAME()
       ,  EditDate= GETDATE()    
      WHERE WaveKey = @c_wavekey  

      SELECT @n_err = @@ERROR  

      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67710   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on WAVE Failed (ispRLWAV55)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END

   IF @b_Debug = 0
   BEGIN
      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
   END

   QUIT_SP:

   --Delete pickdetail_WIP work in progress staging table
   IF @n_continue = 1 OR @n_continue = 2
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

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_LOOP')) >=0 
   BEGIN
      CLOSE CUR_LOOP           
      DEALLOCATE CUR_LOOP      
   END  

   IF @n_Continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV55'
      --RAISERROR @n_err @c_errmsg
      --RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      --RETURN
   END

   IF @b_Debug = 0
   BEGIN
      WHILE @@TRANCOUNT < @n_StartTranCnt
         BEGIN TRAN
   END
END

GO