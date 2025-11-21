SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispWAVPK09                                         */
/* Creation Date: 07-MAR-2020                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-12724 SG PMI Precartonization                           */
/*                                                                      */
/* Called By: Wave                                                      */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 08-Jan-2020  NJOW01   1.0  WMS-15924 filter carton type by consignee.*/
/* 08-Feb-2023  WLChooi  1.1  WMS-21700 - Not allow process if partial  */
/*                            allocated unless approved (WL01)          */
/* 08-Feb-2023  WLChooi  1.1  DevOps Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[ispWAVPK09]
   @c_Wavekey NVARCHAR(10)
 , @b_Success INT           OUTPUT
 , @n_Err     INT           OUTPUT
 , @c_ErrMsg  NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Storerkey        NVARCHAR(15)
         , @c_Sku              NVARCHAR(20)
         , @c_Sku2             NVARCHAR(20)
         , @c_UOM              NVARCHAR(10)
         , @n_Casecnt          INT
         , @n_PackQty          INT
         , @n_SplitQty         INT
         , @c_Pickdetailkey    NVARCHAR(10)
         , @c_Pickdetailkey2   NVARCHAR(10)
         , @c_Pickdetailkey3   NVARCHAR(10)
         , @c_NewPickdetailKey NVARCHAR(10)
         , @c_DropID           NVARCHAR(20)
         , @c_Orderkey         NVARCHAR(10)
         , @n_Qty              INT
         , @n_Qty2             INT
         , @n_Qty3             INT
         , @n_CartonNo         INT
         , @c_CaseID           NVARCHAR(30)
         , @n_CartonQtyCanFit  INT
         , @n_NoofFullCase     INT
         , @c_SourceType       NVARCHAR(30)
         , @c_DropIDFound      NVARCHAR(20)
         , @c_CaseIDFound      NVARCHAR(20)
         , @c_CartonType       NVARCHAR(10)
         , @c_Size             NVARCHAR(10)
         , @c_Size2            NVARCHAR(10)
         , @n_CartonSize       INT
         , @n_MidCartonSize    INT
         , @c_Consigneekey     NVARCHAR(15)
         , @c_CartonTypeList   NVARCHAR(500)
         , @c_LargeCarton      NVARCHAR(60)
         , @c_MidiumCarton     NVARCHAR(60)
         , @c_SmallCarton      NVARCHAR(60)
         , @n_SmallCartonSize  INT
         , @n_LargeCartonSize  INT
         , @n_SkuCartonSize    INT --NJOW01
         , @c_allowpack        NVARCHAR(1) --NJOW01

   DECLARE @n_Continue  INT
         , @n_StartTCnt INT
         , @n_debug     INT
         , @n_Cnt       INT

   SET @c_SourceType = N'ispWAVPK09'
   IF @n_Err = 1
      SET @n_debug = 1
   ELSE
      SET @n_debug = 0

   SELECT @n_Continue = 1
        , @n_StartTCnt = @@TRANCOUNT
        , @n_Err = 0
        , @c_ErrMsg = ''
        , @b_Success = 1

   IF @@TRANCOUNT = 0
      BEGIN TRAN

   --Create temporary table
   IF @n_Continue IN ( 1, 2 )
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

      CREATE TABLE #ORDERLOOSEQTYSUM
      (
         Storerkey       NVARCHAR(15)
       , Sku             NVARCHAR(15)
       , Qty             INT
       , LogicalLocation NVARCHAR(18)
       , Loc             NVARCHAR(10)
       , Size            NVARCHAR(10)
      )

      CREATE TABLE #DROPID_SIZE
      (
         DropID     NVARCHAR(20)
       , MaxQty     INT
       , CartonType NVARCHAR(10)
      ) --NJOW01                
   END

   --Validation            
   IF @n_Continue IN ( 1, 2 )
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM WAVEDETAIL WD (NOLOCK)
                   JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
                   JOIN PICKDETAIL PD (NOLOCK) ON O.OrderKey = PD.OrderKey
                   WHERE WD.WaveKey = @c_Wavekey AND (ISNULL(PD.DropID, '') <> '' OR PD.Status >= 3))
      BEGIN
         SELECT @n_Continue = 3
         SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
              , @n_Err = 38020
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                            + ': The wave has been pre-cartonized or Started Picking. Not allow to run again. (ispWAVPK09)'
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' ) '
         GOTO QUIT_SP
      END

      --WL01 S
      IF EXISTS (  SELECT 1
                   FROM WAVE W (NOLOCK)
                   WHERE W.WaveKey = @c_Wavekey AND W.[Status] = '1')
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM WAVEDETAIL WD (NOLOCK)
                     JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
                     WHERE WD.WaveKey = @c_Wavekey
                     AND OH.[Status] = '1' AND ISNULL(OH.ContainerType,'') <> 'APPROVED')
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                 , @n_Err = 38021
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                               + ': Found Partial Allocated Orders, not allow to proceed. (ispWAVPK09)'
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' ) '
            GOTO QUIT_SP
         END
      END
      --WL01 E
   END

   --Initialize Pickdetail work in progress staging table
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                  , @c_Wavekey = @c_Wavekey
                                  , @c_WIP_RefNo = @c_SourceType
                                  , @c_PickCondition_SQL = ''
                                  , @c_Action = 'I' --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
                                  , @c_RemoveTaskdetailkey = 'N' --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
                                  , @b_Success = @b_Success OUTPUT
                                  , @n_Err = @n_Err OUTPUT
                                  , @c_ErrMsg = @c_ErrMsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
      END
      BEGIN
         UPDATE #PickDetail_WIP
         SET DropID = ''
           , CaseID = ''
           , CartonType = ''
      END
   END

   --Cartonization
   IF @n_Continue IN ( 1, 2 )
   BEGIN
      --Caronization by order
      DECLARE CUR_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.OrderKey
           , O.ConsigneeKey --NJOW01
      FROM #PickDetail_WIP PD
      JOIN ORDERS O (NOLOCK) ON PD.OrderKey = O.OrderKey
      GROUP BY PD.OrderKey
             , O.ConsigneeKey --NJOW01
      ORDER BY PD.OrderKey

      OPEN CUR_ORDERS

      FETCH NEXT FROM CUR_ORDERS
      INTO @c_Orderkey
         , @c_Consigneekey

      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN ( 1, 2 )
      BEGIN
         --Sku Non-full carton order qty summary table
         DELETE FROM #ORDERLOOSEQTYSUM

         INSERT INTO #ORDERLOOSEQTYSUM (Storerkey, Sku, Qty, LogicalLocation, Loc, Size)
         SELECT PD.Storerkey
              , PD.Sku
              , SUM(PD.Qty)
              , MIN(LOC.LogicalLocation)
              , MIN(LOC.Loc)
              , SKU.Size
         FROM #PickDetail_WIP PD
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.StorerKey AND PD.Sku = SKU.Sku
         WHERE PD.OrderKey = @c_Orderkey AND PD.UOM <> '2'
         GROUP BY PD.Storerkey
                , PD.Sku
                , SKU.Size

         SET @n_CartonNo = 0

         --NJOW01
         SET @c_CartonTypeList = N''
         SELECT TOP 1 @c_CartonTypeList = CL.Notes
         FROM CODELKUP CL (NOLOCK)
         WHERE CL.LISTNAME = 'PMICUST' AND CL.Code = @c_Consigneekey

         WHILE 1 = 1 AND @n_Continue IN ( 1, 2 ) --Carton loop         
         BEGIN
            SELECT TOP 1 @c_Pickdetailkey = PD.PickDetailKey
                       , @c_Storerkey = PD.Storerkey
                       , @c_Sku = PD.Sku
                       , @n_Qty = PD.Qty
                       , @c_UOM = PD.UOM
                       , @n_Casecnt = PACK.CaseCnt
                       , @c_Size = SKU.Size
            FROM #PickDetail_WIP PD
            JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
            JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.StorerKey AND PD.Sku = SKU.Sku
            JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
            LEFT JOIN CODELKUP CL (NOLOCK) ON  SKU.Size = CL.Code
                                           AND CL.LISTNAME = 'PMISIZE'
                                           AND PD.Storerkey = CL.Storerkey --NJOW01
            WHERE PD.DropID = '' AND PD.CaseID = '' AND PD.OrderKey = @c_Orderkey
            ORDER BY CASE WHEN CL.Short IS NULL THEN 'ZZZZ'
                          ELSE CL.Short END
                   , LOC.LogicalLocation
                   , LOC.Loc
                   , PD.Sku
                   , PD.UOM
                   , PD.Qty DESC --NJOW01
            --ORDER BY CASE WHEN SKU.Size = 'XL' THEN 1 ELSE 2 END, LOC.LogicalLocation, LOC.Loc, PD.Sku, PD.UOM   --XL Sku assign carton first. 

            IF @@ROWCOUNT = 0
               BREAK

            --Open new carton if not full case
            IF NOT (@c_UOM = '2' AND @n_Qty % @n_Casecnt = 0)
            BEGIN
               --NJOW01 -S
               SELECT @c_LargeCarton = N''
                    , @c_MidiumCarton = N''
                    , @c_SmallCarton = N''

               SELECT TOP 1 @c_LargeCarton = CL.UDF03
                          , @c_MidiumCarton = CL.UDF02
                          , @c_SmallCarton = CL.UDF01
               FROM CODELKUP CL (NOLOCK)
               WHERE CL.LISTNAME = 'PMISIZE' AND CL.Storerkey = @c_Storerkey AND CL.Code = @c_Size --XL and other.

               IF CHARINDEX('PM003', @c_CartonTypeList) > 0
               BEGIN
                  SET @c_CartonType = N'PM003' --NJOW01
                  IF ISNUMERIC(@c_LargeCarton) = 1
                     SET @n_CartonSize = CAST(@c_LargeCarton AS INT)
                  ELSE IF @c_Size = 'XL'
                     SET @n_CartonSize = 460 --last XL sku carton can mix with normal sku
                  ELSE
                     SET @n_CartonSize = 500
               END
               ELSE IF CHARINDEX('PM002', @c_CartonTypeList) > 0
               BEGIN
                  SET @c_CartonType = N'PM002' --NJOW01
                  IF ISNUMERIC(@c_MidiumCarton) = 1
                     SET @n_CartonSize = CAST(@c_MidiumCarton AS INT)
                  ELSE IF @c_Size = 'XL'
                     SET @n_CartonSize = 240 --last XL sku carton can mix with normal sku
                  ELSE
                     SET @n_CartonSize = 250
               END
               ELSE IF CHARINDEX('PM001', @c_CartonTypeList) > 0
               BEGIN
                  SET @c_CartonType = N'PM001' --NJOW01
                  IF ISNUMERIC(@c_SmallCarton) = 1
                     SET @n_CartonSize = CAST(@c_SmallCarton AS INT)
                  ELSE
                     SET @n_CartonSize = 100
               END
               ELSE
               BEGIN
                  SET @c_CartonType = N'PM003' --NJOW01
                  IF ISNUMERIC(@c_LargeCarton) = 1
                     SET @n_CartonSize = CAST(@c_LargeCarton AS INT)
                  ELSE IF @c_Size = 'XL'
                     SET @n_CartonSize = 460 --last XL sku carton can mix with normal sku
                  ELSE
                     SET @n_CartonSize = 500
               END
               --NJOW01 E

               /*
               IF @c_Size = 'XL'            	   
            	    SET @n_CartonSize = 460   --last XL sku carton can mix with normal sku
            	 ELSE
            	    SET @n_CartonSize = 500
            	 */

               SET @n_CartonQtyCanFit = @n_CartonSize
               SET @n_CartonNo = @n_CartonNo + 1
               SET @c_CaseID = RIGHT('000' + RTRIM(CAST(@n_CartonNo AS NVARCHAR)), 3)

               EXECUTE nspg_GetKey 'PMIDROPID'
                                 , 6
                                 , @c_DropID OUTPUT
                                 , @b_Success OUTPUT
                                 , @n_Err OUTPUT
                                 , @c_ErrMsg OUTPUT

               SET @c_DropID = N'PM' + RTRIM(LTRIM(@c_DropID))

               INSERT INTO #DROPID_SIZE (DropID, MaxQty, CartonType) --NJOW01
               VALUES (@c_DropID, @n_CartonSize, @c_CartonType)
            END

            IF @c_UOM = '2' AND @n_Qty % @n_Casecnt = 0
            BEGIN --Full case
               SET @n_NoofFullCase = @n_Qty / @n_Casecnt

               --Split full case
               WHILE @n_NoofFullCase > 0
               BEGIN
                  --Open new carton for each full case
                  SET @n_CartonSize = 500
                  SET @n_CartonQtyCanFit = @n_CartonSize
                  SET @n_CartonNo = @n_CartonNo + 1
                  SET @c_CaseID = RIGHT('000' + RTRIM(CAST(@n_CartonNo AS NVARCHAR)), 3)
                  SET @c_CartonType = N'PM004' --NJOW01

                  EXECUTE nspg_GetKey 'PMIDROPID'
                                    , 6
                                    , @c_DropID OUTPUT
                                    , @b_Success OUTPUT
                                    , @n_Err OUTPUT
                                    , @c_ErrMsg OUTPUT

                  SET @c_DropID = N'PM' + RTRIM(LTRIM(@c_DropID))

                  INSERT INTO #DROPID_SIZE (DropID, MaxQty, CartonType) --NJOW01
                  VALUES (@c_DropID, @n_CartonSize, @c_CartonType)

                  IF @n_NoofFullCase = 1
                  BEGIN
                     UPDATE #PickDetail_WIP
                     SET DropID = @c_DropID
                       , CaseID = @c_CaseID
                       , Qty = @n_Casecnt
                       , UOMQty = 1
                     WHERE PickDetailKey = @c_Pickdetailkey
                  END
                  ELSE
                  BEGIN
                     EXECUTE nspg_GetKey 'PICKDETAILKEY'
                                       , 10
                                       , @c_NewPickdetailKey OUTPUT
                                       , @b_Success OUTPUT
                                       , @n_Err OUTPUT
                                       , @c_ErrMsg OUTPUT

                     INSERT INTO #PickDetail_WIP (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot
                                                , Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status], DropID
                                                , Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc
                                                , DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey
                                                , EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, TaskDetailKey
                                                , TaskManagerReasonKey, Notes, MoveRefKey, WIP_Refno, Channel_ID)
                     SELECT @c_NewPickdetailKey
                          , @c_CaseID
                          , PickHeaderKey
                          , OrderKey
                          , OrderLineNumber
                          , Lot
                          , Storerkey
                          , Sku
                          , AltSku
                          , UOM
                          , 1
                          , @n_Casecnt
                          , QtyMoved
                          , Status
                          , @c_DropID
                          , Loc
                          , ID
                          , PackKey
                          , UpdateSource
                          , CartonGroup
                          , CartonType
                          , ToLoc
                          , DoReplenish
                          , ReplenishZone
                          , DoCartonize
                          , PickMethod
                          , WaveKey
                          , EffectiveDate
                          , '9'
                          , ShipFlag
                          , PickSlipNo
                          , TaskDetailKey
                          , TaskManagerReasonKey
                          , Notes
                          , MoveRefKey
                          , WIP_Refno
                          , Channel_ID
                     FROM #PickDetail_WIP
                     WHERE PickDetailKey = @c_Pickdetailkey
                  END

                  SET @n_NoofFullCase = @n_NoofFullCase - 1
               END
            END
            ELSE
            BEGIN --Innner pack / package(EA)
               ------------pack current pick into carton
               IF @n_Continue IN ( 1, 2 )
               BEGIN
                  IF @n_Qty >= @n_CartonQtyCanFit
                  BEGIN
                     --can pack the pick into full carton and open new carton
                     SET @n_SplitQty = @n_Qty - @n_CartonQtyCanFit

                     UPDATE #PickDetail_WIP
                     SET DropID = @c_DropID
                       , CaseID = @c_CaseID
                       , Qty = @n_CartonQtyCanFit
                       , UOMQty = @n_CartonQtyCanFit
                     WHERE PickDetailKey = @c_Pickdetailkey

                     UPDATE #ORDERLOOSEQTYSUM
                     SET Qty = Qty - @n_CartonQtyCanFit
                     WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku

                     --split the pickdetail not in carton
                     IF @n_SplitQty > 0
                     BEGIN
                        --check if other carton has space can fit the split qty
                        SELECT @c_DropIDFound = N''
                             , @c_CaseIDFound = N''
                        SELECT TOP 1 @c_DropIDFound = PD.DropID
                                   , @c_CaseIDFound = PD.CaseID
                        FROM #PickDetail_WIP PD
                        JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
                        JOIN #DROPID_SIZE DS ON PD.DropID = DS.DropID --NJOW01
                        WHERE PD.DropID <> ''
                        AND   PD.CaseID <> ''
                        AND   PD.OrderKey = @c_Orderkey
                        AND   DS.MaxQty <= @n_CartonSize --NJOW01 not to consider other carton greater than current carton size limit.
                        GROUP BY PD.DropID
                               , PD.CaseID
                               , DS.MaxQty
                        HAVING DS.MaxQty - SUM(PD.Qty) >= @n_SplitQty --NJOW01
                        ORDER BY (DS.MaxQty - SUM(PD.Qty)) --NJOW01
                        --HAVING @n_CartonSize - SUM(PD.Qty) >= @n_SplitQty
                        --ORDER BY (@n_CartonSize - SUM(PD.Qty))    	     	                 	     	            

                        IF @c_DropIDFound <> ''
                        BEGIN
                           UPDATE #ORDERLOOSEQTYSUM
                           SET Qty = Qty - @n_SplitQty
                           WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku
                        END

                        EXECUTE nspg_GetKey 'PICKDETAILKEY'
                                          , 10
                                          , @c_NewPickdetailKey OUTPUT
                                          , @b_Success OUTPUT
                                          , @n_Err OUTPUT
                                          , @c_ErrMsg OUTPUT

                        INSERT INTO #PickDetail_WIP (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber
                                                   , Lot, Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status]
                                                   , DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType
                                                   , ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod
                                                   , WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo
                                                   , TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_Refno
                                                   , Channel_ID)
                        SELECT @c_NewPickdetailKey
                             , @c_CaseIDFound
                             , PickHeaderKey
                             , OrderKey
                             , OrderLineNumber
                             , Lot
                             , Storerkey
                             , Sku
                             , AltSku
                             , UOM
                             , @n_SplitQty
                             , @n_SplitQty
                             , QtyMoved
                             , Status
                             , @c_DropIDFound
                             , Loc
                             , ID
                             , PackKey
                             , UpdateSource
                             , CartonGroup
                             , CartonType
                             , ToLoc
                             , DoReplenish
                             , ReplenishZone
                             , DoCartonize
                             , PickMethod
                             , WaveKey
                             , EffectiveDate
                             , '9'
                             , ShipFlag
                             , PickSlipNo
                             , TaskDetailKey
                             , TaskManagerReasonKey
                             , Notes
                             , MoveRefKey
                             , WIP_Refno
                             , Channel_ID
                        FROM #PickDetail_WIP
                        WHERE PickDetailKey = @c_Pickdetailkey
                     END
                     GOTO NEW_CARTON
                  END
                  ELSE
                  BEGIN
                     --pack the pick into the carton and continue pack
                     UPDATE #PickDetail_WIP
                     SET DropID = @c_DropID
                       , CaseID = @c_CaseID
                     WHERE PickDetailKey = @c_Pickdetailkey

                     UPDATE #ORDERLOOSEQTYSUM
                     SET Qty = Qty - @n_Qty
                     WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku

                     SET @n_CartonQtyCanFit = @n_CartonQtyCanFit - @n_Qty
                  END
               END

               ----------pack other pick with same sku into the carton
               IF @n_Continue IN ( 1, 2 ) AND @n_CartonQtyCanFit > 0
               BEGIN
                  DECLARE CUR_PICKSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PD.PickDetailKey
                       , PD.Qty
                  FROM #PickDetail_WIP PD
                  JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
                  WHERE PD.Storerkey = @c_Storerkey
                  AND   PD.Sku = @c_Sku
                  AND   PD.DropID = ''
                  AND   PD.CaseID = ''
                  AND   PD.UOM <> '2'
                  AND   PD.OrderKey = @c_Orderkey
                  ORDER BY LOC.LogicalLocation
                         , LOC.Loc
                         , PD.UOM

                  OPEN CUR_PICKSKU

                  FETCH NEXT FROM CUR_PICKSKU
                  INTO @c_Pickdetailkey2
                     , @n_Qty2

                  WHILE @@FETCH_STATUS = 0 AND @n_Continue IN ( 1, 2 ) AND @n_CartonQtyCanFit > 0
                  BEGIN
                     IF @n_CartonQtyCanFit >= @n_Qty2
                     BEGIN
                        --pack all qty
                        UPDATE #PickDetail_WIP
                        SET DropID = @c_DropID
                          , CaseID = @c_CaseID
                        WHERE PickDetailKey = @c_Pickdetailkey2

                        UPDATE #ORDERLOOSEQTYSUM
                        SET Qty = Qty - @n_Qty2
                        WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku

                        SET @n_CartonQtyCanFit = @n_CartonQtyCanFit - @n_Qty2
                     END
                     ELSE
                     BEGIN
                        --pack qty can fit only
                        SET @n_PackQty = @n_CartonQtyCanFit
                        SET @n_SplitQty = @n_Qty2 - @n_CartonQtyCanFit

                        UPDATE #PickDetail_WIP
                        SET DropID = @c_DropID
                          , CaseID = @c_CaseID
                          , Qty = @n_PackQty
                          , UOMQty = @n_PackQty
                        WHERE PickDetailKey = @c_Pickdetailkey2

                        UPDATE #ORDERLOOSEQTYSUM
                        SET Qty = Qty - @n_PackQty
                        WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku

                        SET @n_CartonQtyCanFit = @n_CartonQtyCanFit - @n_PackQty

                        --check if other carton has space can fit the split qty
                        SELECT @c_DropIDFound = N''
                             , @c_CaseIDFound = N''
                        SELECT TOP 1 @c_DropIDFound = PD.DropID
                                   , @c_CaseIDFound = PD.CaseID
                        FROM #PickDetail_WIP PD
                        JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
                        JOIN #DROPID_SIZE DS ON PD.DropID = DS.DropID --NJOW01   	     	              
                        WHERE PD.DropID <> ''
                        AND   PD.CaseID <> ''
                        AND   PD.OrderKey = @c_Orderkey
                        AND   DS.MaxQty <= @n_CartonSize --NJOW01 not to consider other carton greater than current carton size limit.
                        GROUP BY PD.DropID
                               , PD.CaseID
                               , DS.MaxQty
                        HAVING DS.MaxQty - SUM(PD.Qty) >= @n_SplitQty --NJOW01
                        ORDER BY (DS.MaxQty - SUM(PD.Qty)) --NJOW01
                        --HAVING @n_CartonSize - SUM(PD.Qty) >= @n_SplitQty
                        --ORDER BY (@n_CartonSize - SUM(PD.Qty)) 

                        IF @c_DropIDFound <> ''
                        BEGIN
                           UPDATE #ORDERLOOSEQTYSUM
                           SET Qty = Qty - @n_SplitQty
                           WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku
                        END

                        --split the pickdetail not in carton               	      
                        EXECUTE nspg_GetKey 'PICKDETAILKEY'
                                          , 10
                                          , @c_NewPickdetailKey OUTPUT
                                          , @b_Success OUTPUT
                                          , @n_Err OUTPUT
                                          , @c_ErrMsg OUTPUT

                        INSERT INTO #PickDetail_WIP (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber
                                                   , Lot, Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status]
                                                   , DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType
                                                   , ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod
                                                   , WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo
                                                   , TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_Refno
                                                   , Channel_ID)
                        SELECT @c_NewPickdetailKey
                             , @c_CaseIDFound
                             , PickHeaderKey
                             , OrderKey
                             , OrderLineNumber
                             , Lot
                             , Storerkey
                             , Sku
                             , AltSku
                             , UOM
                             , @n_SplitQty
                             , @n_SplitQty
                             , QtyMoved
                             , Status
                             , @c_DropIDFound
                             , Loc
                             , ID
                             , PackKey
                             , UpdateSource
                             , CartonGroup
                             , CartonType
                             , ToLoc
                             , DoReplenish
                             , ReplenishZone
                             , DoCartonize
                             , PickMethod
                             , WaveKey
                             , EffectiveDate
                             , '9'
                             , ShipFlag
                             , PickSlipNo
                             , TaskDetailKey
                             , TaskManagerReasonKey
                             , Notes
                             , MoveRefKey
                             , WIP_Refno
                             , Channel_ID
                        FROM #PickDetail_WIP
                        WHERE PickDetailKey = @c_Pickdetailkey2
                     END

                     FETCH NEXT FROM CUR_PICKSKU
                     INTO @c_Pickdetailkey2
                        , @n_Qty2
                  END
                  CLOSE CUR_PICKSKU
                  DEALLOCATE CUR_PICKSKU
               END

               ----------pack other sku best fit in all qty or SKU with XL size
               IF @n_Continue IN ( 1, 2 ) AND @n_CartonQtyCanFit > 0
               BEGIN
                  --Get other Sku can fully fit or sku with XL size
                  DECLARE CUR_PICKFULLSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT Sku
                       , Qty
                       , Size
                  FROM #ORDERLOOSEQTYSUM
                  WHERE Storerkey = @c_Storerkey AND Qty > 0 AND Qty <= @n_CartonQtyCanFit
                  --AND QtY <= CASE WHEN Size = 'XL' THEN Qty ELSE @n_CartonQtyCanFit END
                  ORDER BY CASE WHEN Size = 'XL' THEN 1
                                ELSE 2 END
                         , LogicalLocation
                         , Loc
                         , Qty
                         , Sku --Sort by loc
                  --ORDER BY Qty DESC, Sku --Sort by best fit

                  OPEN CUR_PICKFULLSKU

                  FETCH NEXT FROM CUR_PICKFULLSKU
                  INTO @c_Sku2
                     , @n_Qty2
                     , @c_Size2

                  WHILE @@FETCH_STATUS = 0 AND @n_Continue IN ( 1, 2 ) AND @n_CartonQtyCanFit > 0
                  BEGIN
                     --NJOW01 S
                     --Not to consider carton size limit of the sku smaller than current carton size
                     SELECT @c_LargeCarton = N''
                          , @c_MidiumCarton = N''
                          , @c_SmallCarton = N''
                          , @n_SkuCartonSize = 0

                     SELECT TOP 1 @c_LargeCarton = CL.UDF03
                                , @c_MidiumCarton = CL.UDF02
                                , @c_SmallCarton = CL.UDF01
                     FROM CODELKUP CL (NOLOCK)
                     WHERE CL.LISTNAME = 'PMISIZE' AND CL.Storerkey = @c_Storerkey AND CL.Code = @c_Size2 --XL and other.

                     IF CHARINDEX('PM003', @c_CartonTypeList) > 0
                     BEGIN
                        SET @c_CartonType = N'PM003'
                        IF ISNUMERIC(@c_LargeCarton) = 1
                           SET @n_SkuCartonSize = CAST(@c_LargeCarton AS INT)
                        ELSE IF @c_Size2 = 'XL'
                           SET @n_SkuCartonSize = 460 --last XL sku carton can mix with normal sku
                        ELSE
                           SET @n_SkuCartonSize = 500
                     END
                     ELSE IF CHARINDEX('PM002', @c_CartonTypeList) > 0
                     BEGIN
                        SET @c_CartonType = N'PM002'
                        IF ISNUMERIC(@c_MidiumCarton) = 1
                           SET @n_SkuCartonSize = CAST(@c_MidiumCarton AS INT)
                        ELSE IF @c_Size2 = 'XL'
                           SET @n_SkuCartonSize = 240 --last XL sku carton can mix with normal sku
                        ELSE
                           SET @n_SkuCartonSize = 250
                     END
                     ELSE IF CHARINDEX('PM001', @c_CartonTypeList) > 0
                     BEGIN
                        SET @c_CartonType = N'PM001'
                        IF ISNUMERIC(@c_SmallCarton) = 1
                           SET @n_SkuCartonSize = CAST(@c_SmallCarton AS INT)
                        ELSE
                           SET @n_SkuCartonSize = 100
                     END
                     ELSE
                     BEGIN
                        SET @c_CartonType = N'PM003'
                        IF ISNUMERIC(@c_LargeCarton) = 1
                           SET @n_SkuCartonSize = CAST(@c_LargeCarton AS INT)
                        ELSE IF @c_Size2 = 'XL'
                           SET @n_SkuCartonSize = 460 --last XL sku carton can mix with normal sku
                        ELSE
                           SET @n_SkuCartonSize = 500
                     END

                     SET @c_allowpack = N'N'
                     IF  @n_Qty2 + (@n_CartonSize - @n_CartonQtyCanFit) <= @n_SkuCartonSize --if total pack qty not over the sku carton size limit
                     AND @n_SkuCartonSize < @n_CartonSize --Current carton size over the limit of the sku 
                     BEGIN
                        SET @c_allowpack = N'Y'

                        --reset the carton size to avoid over pack by other sku 
                        UPDATE #DROPID_SIZE
                        SET MaxQty = @n_SkuCartonSize
                          , CartonType = @c_CartonType
                        WHERE DropID = @c_DropID

                        SET @n_CartonQtyCanFit = @n_CartonQtyCanFit - (@n_CartonSize - @n_SkuCartonSize) --reduce space available after reset carton size
                     END
                     --NJOW01 E

                     IF  @n_Qty2 <= @n_CartonQtyCanFit --can fit
                     AND (@n_SkuCartonSize >= @n_CartonSize OR @c_allowpack = 'Y') --NJOW01 Not to consider carton size limit of the sku smaller than current carton size                  	 	       
                     BEGIN
                        --Pack all pick of the sku into carton
                        DECLARE CUR_PICKSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT PD.PickDetailKey
                             , PD.Qty
                        FROM #PickDetail_WIP PD
                        JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
                        WHERE PD.Storerkey = @c_Storerkey
                        AND   PD.Sku = @c_Sku2
                        AND   PD.DropID = ''
                        AND   PD.CaseID = ''
                        AND   PD.UOM <> '2'
                        AND   PD.OrderKey = @c_Orderkey
                        ORDER BY LOC.LogicalLocation
                               , LOC.Loc
                               , PD.UOM

                        OPEN CUR_PICKSKU

                        FETCH NEXT FROM CUR_PICKSKU
                        INTO @c_Pickdetailkey3
                           , @n_Qty3

                        WHILE @@FETCH_STATUS = 0 AND @n_Continue IN ( 1, 2 )
                        BEGIN
                           UPDATE #PickDetail_WIP
                           SET DropID = @c_DropID
                             , CaseID = @c_CaseID
                           WHERE PickDetailKey = @c_Pickdetailkey3

                           UPDATE #ORDERLOOSEQTYSUM
                           SET Qty = Qty - @n_Qty3
                           WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku2

                           SET @n_CartonQtyCanFit = @n_CartonQtyCanFit - @n_Qty3

                           FETCH NEXT FROM CUR_PICKSKU
                           INTO @c_Pickdetailkey3
                              , @n_Qty3
                        END
                        CLOSE CUR_PICKSKU
                        DEALLOCATE CUR_PICKSKU
                     END
                     /*ELSE IF @c_Size = 'XL' --Splip the XL Sku qty into the carton
                     BEGIN
                  	    DECLARE CUR_PICKXLSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	     	                 SELECT PD.Pickdetailkey, PD.Qty
   	     	                 FROM #PICKDETAIL_WIP PD
   	     	                 JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
   	     	                 WHERE PD.Storerkey = @c_Storerkey
   	     	                 AND PD.Sku = @c_Sku2
        	        	       AND PD.DropID = ''
   	     	                 AND PD.CaseID = ''
   	     	                 AND PD.UOM <> '2'
   	     	                 AND PD.Orderkey = @c_Orderkey
        	        	       ORDER BY LOC.LogicalLocation, LOC.Loc, PD.UOM
   	     	              
   	     	              OPEN CUR_PICKXLSKU  
                        
                        FETCH NEXT FROM CUR_PICKXLSKU INTO @c_Pickdetailkey3, @n_Qty3
                        
                        WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_CartonQtyCanFit > 0
                        BEGIN
     	                  	 IF @n_CartonQtyCanFit >= @n_Qty3
                         	 BEGIN
                              UPDATE #PICKDETAIL_WIP
                              SET DropID = @c_DropID,
                                  CaseID = @c_CaseID
                              WHERE Pickdetailkey = @c_PickdetailKey3   	     	  	 	
                              
                              UPDATE #ORDERLOOSEQTYSUM
                              SET Qty = Qty - @n_Qty3
                              WHERE Storerkey = @c_Storerkey
                              AND Sku = @c_Sku2 
                              
                              SET @n_CartonQtyCanFit = @n_CartonQtyCanFit - @n_Qty3
                           END   
                           ELSE
                           BEGIN
                              SET @n_PackQty = @n_CartonQtyCanFit
                  	 	        SET @n_SplitQty = @n_Qty3 - @n_CartonQtyCanFit
                  	 	        
  	  	                      UPDATE #PICKDETAIL_WIP
                              SET DropID = @c_DropID,
                                  CaseID = @c_CaseID,
                                  Qty = @n_PackQty,
                                  UOMQty = @n_PackQty
                              WHERE Pickdetailkey = @c_PickdetailKey3
                              
                              UPDATE #ORDERLOOSEQTYSUM
                              SET Qty = Qty - @n_PackQty
                              WHERE Storerkey = @c_Storerkey
                              AND Sku = @c_Sku2	 
                              
                              SET @n_CartonQtyCanFit = @n_CartonQtyCanFit - @n_PackQty
                              
                              --check if other carton has space can fit the split qty
                              SELECT @c_DropIDFound = '', @c_CaseIDFound = ''
                              SELECT TOP 1 @c_DropIDFound = PD.DropID,
                                           @c_CaseIDFound = PD.CaseID
   	     	                    FROM #PICKDETAIL_WIP PD
   	     	                    JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
   	     	                    WHERE PD.DropID <> ''
   	     	                    AND PD.CaseID <> ''
   	     	                    AND PD.Orderkey = @c_Orderkey
   	     	                    GROUP BY PD.DropID, PD.CaseID
   	     	                    HAVING @n_CartonSize - SUM(PD.Qty) >= @n_SplitQty
   	     	                    ORDER BY (@n_CartonSize - SUM(PD.Qty)) 
   	     	                    
   	     	                    IF @c_DropIDFound <> ''
   	     	                    BEGIN
                                 UPDATE #ORDERLOOSEQTYSUM
                                 SET Qty = Qty - @n_SplitQty
                                 WHERE Storerkey = @c_Storerkey
                                 AND Sku = @c_Sku	 	
   	     	                    END
   	     	                                
                              --split the pickdetail not in carton               	      
                  	           EXECUTE nspg_GetKey      
                              'PICKDETAILKEY',      
                              10,      
                              @c_NewPickdetailKey OUTPUT,         
                              @b_success OUTPUT,      
                              @n_err OUTPUT,      
                              @c_errmsg OUTPUT      
                              
                              INSERT INTO #PICKDETAIL_WIP      
                                     (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                                      Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],       
                                      DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                                      WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, 
                                      TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_Refno, Channel_ID)      
                              SELECT @c_NewpickDetailKey, @c_CaseIDFound, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                                     Storerkey, Sku, AltSku, UOM, @n_SplitQty , @n_SplitQty, QtyMoved, Status,       
                                     @c_DropIDFound, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                                     ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                                     WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,
                                     TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_Refno, Channel_ID             
                              FROM #PICKDETAIL_WIP 
                              WHERE PickdetailKey = @c_PickdetailKey3	                                           	
                           END                           
                              
                           FETCH NEXT FROM CUR_PICKXLSKU INTO @c_Pickdetailkey3, @n_Qty3
                        END
                        CLOSE CUR_PICKXLSKU
                        DEALLOCATE CUR_PICKXLSKU                     	
                     END*/

                     FETCH NEXT FROM CUR_PICKFULLSKU
                     INTO @c_Sku2
                        , @n_Qty2
                        , @c_Size2
                  END
                  CLOSE CUR_PICKFULLSKU
                  DEALLOCATE CUR_PICKFULLSKU
               END
            END

            NEW_CARTON:
         END --While 1=1

         FETCH NEXT FROM CUR_ORDERS
         INTO @c_Orderkey
            , @c_Consigneekey
      END
      CLOSE CUR_ORDERS
      DEALLOCATE CUR_ORDERS
   END

   --Assign cartontype
   /*
   IF @n_continue = 1 or @n_continue = 2 --NJOW01
   BEGIN   	
      DECLARE CUR_CARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.DropID, DS.CartonType
         FROM #PICKDETAIL_WIP PD
         JOIN #DROPID_SIZE DS ON PD.Dropid = DS.DropID
         GROUP BY PD.DropID, DS.CartonType
         ORDER BY PD.DropID, DS.CartonType
      
      OPEN CUR_CARTON  
      
      FETCH NEXT FROM CUR_CARTON INTO @c_DropID, @c_CartonType
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) 
      BEGIN         
         UPDATE #PICKDETAIL_WIP
         SET CartonType = @c_CartonType
         WHERE DropID = @c_DropID
      	 
         FETCH NEXT FROM CUR_CARTON INTO @c_DropID, @c_CartonType
      END
      CLOSE CUR_CARTON
      DEALLOCATE CUR_CARTON   	
   END
   */

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE CUR_CARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.DropID
           , SUM(PD.Qty)
           , MIN(PD.UOM)
           , PD.Storerkey
           , SUM(CASE WHEN ISNULL(SKU.Size, '') = 'XL' THEN 1
                      ELSE 0 END)
           , MAX(SKU.Size) --NJOW01
      FROM #PickDetail_WIP PD
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.StorerKey AND PD.Sku = SKU.Sku
      WHERE PD.DropID <> ''
      GROUP BY PD.DropID
             , PD.Storerkey

      OPEN CUR_CARTON

      FETCH NEXT FROM CUR_CARTON
      INTO @c_DropID
         , @n_Qty
         , @c_UOM
         , @c_Storerkey
         , @n_Cnt
         , @c_Size

      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN ( 1, 2 )
      BEGIN
         SET @c_CartonType = N''

         IF @c_UOM = '2'
         BEGIN
            SET @c_CartonType = 'PM004' --full carton

         --SELECT TOP 1 @c_CartonType = CZ.CartonType 
         --FROM STORER S (NOLOCK)
         --JOIN  CARTONIZATION CZ (NOLOCK) ON S.CartonGroup = CZ.CartonizationGroup 
         --WHERE S.Storerkey = @c_Storerkey
         --AND CZ.MaxCount = 0            
         END
         ELSE
         BEGIN
            --NJOW01 S
            SELECT @c_LargeCarton = N''
                 , @c_MidiumCarton = N''
                 , @c_SmallCarton = N''

            IF @n_Cnt > 0
            BEGIN
               SELECT TOP 1 @c_MidiumCarton = CL.UDF02
                          , @c_SmallCarton = CL.UDF01
               FROM CODELKUP CL (NOLOCK)
               WHERE CL.LISTNAME = 'PMISIZE' AND CL.Storerkey = @c_Storerkey AND CL.Code = 'XL' --XL and other.        

               SELECT TOP 1 @c_LargeCarton = CL.UDF03
               FROM CODELKUP CL (NOLOCK)
               WHERE CL.LISTNAME = 'PMISIZE' AND CL.Storerkey = @c_Storerkey AND CL.Code = @c_Size --XL and other.                                                                               
            END
            ELSE
            BEGIN
               SELECT TOP 1 @c_LargeCarton = CL.UDF03
                          , @c_MidiumCarton = CL.UDF02
                          , @c_SmallCarton = CL.UDF01
               FROM CODELKUP CL (NOLOCK)
               WHERE CL.LISTNAME = 'PMISIZE' AND CL.Storerkey = @c_Storerkey AND CL.Code = @c_Size --XL and other.                            
            END

            IF ISNUMERIC(@c_LargeCarton) = 1
               SET @n_LargeCartonSize = CAST(@c_LargeCarton AS INT)
            ELSE
               SET @n_LargeCartonSize = 500

            IF ISNUMERIC(@c_MidiumCarton) = 1
               SET @n_MidCartonSize = CAST(@c_MidiumCarton AS INT)
            ELSE IF @n_Cnt > 0 --drop id have XL pack sku
               SET @n_MidCartonSize = 240
            ELSE
               SET @n_MidCartonSize = 250

            IF ISNUMERIC(@c_SmallCarton) = 1
               SET @n_SmallCartonSize = CAST(@c_SmallCarton AS INT)
            ELSE
               SET @n_SmallCartonSize = 100

            IF @n_Qty > @n_MidCartonSize AND @n_Qty <= @n_LargeCartonSize --large
               SET @c_CartonType = N'PM003'
            ELSE IF @n_Qty > @n_SmallCartonSize AND @n_Qty <= @n_MidCartonSize --medium 
               SET @c_CartonType = 'PM002'
            ELSE IF @n_Qty <= @n_SmallCartonSize
               SET @c_CartonType = 'PM001' --small
            ELSE
               SET @c_CartonType = N'PM003' --large              
         --NJOW01 E


         --IF @n_cnt > 0 --drop id have XL pack sku
         --   SET @n_MidCartonSize = 240
         --ELSE
         --   SET @n_MidCartonSize = 250


         --IF @n_Qty > @n_MidCartonSize AND @n_Qty <= 500 --large
         --   SET @c_CartonType = 'PM003'
         --ELSE IF @n_Qty > 100 AND @n_Qty <= @n_MidCartonSize  --medium 
         --   SET @c_cartonType = 'PM002'
         --ELSE IF @n_Qty <= 100
         --   SET @c_cartonType = 'PM001' --small
         --ELSE
         --   SET @c_CartonType = 'PM003'  --large

         --SELECT TOP 1 @c_CartonType = CZ.CartonType 
         --FROM STORER S (NOLOCK)
         --JOIN  CARTONIZATION CZ (NOLOCK) ON S.CartonGroup = CZ.CartonizationGroup 
         --WHERE S.Storerkey = @c_Storerkey
         --AND CZ.MaxCount <= @n_Qty
         --ORDER BY CZ.MaxCount DESC            
         END

         IF @c_CartonType <> ''
         BEGIN
            UPDATE #PickDetail_WIP
            SET CartonType = @c_CartonType
            WHERE DropID = @c_DropID
         END

         FETCH NEXT FROM CUR_CARTON
         INTO @c_DropID
            , @n_Qty
            , @c_UOM
            , @c_Storerkey
            , @n_Cnt
            , @c_Size
      END
      CLOSE CUR_CARTON
      DEALLOCATE CUR_CARTON
   END

   -----Update pickdetail_WIP work in progress staging table back to pickdetail 
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP @c_Loadkey = ''
                                  , @c_Wavekey = @c_Wavekey
                                  , @c_WIP_RefNo = @c_SourceType
                                  , @c_PickCondition_SQL = ''
                                  , @c_Action = 'U' --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
                                  , @c_RemoveTaskdetailkey = 'N' --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
                                  , @b_Success = @b_Success OUTPUT
                                  , @n_Err = @n_Err OUTPUT
                                  , @c_ErrMsg = @c_ErrMsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
      END
   END

   QUIT_SP:

   IF OBJECT_ID('tempdb..#PickDetail_WIP', 'u') IS NOT NULL
      DROP TABLE #PickDetail_WIP

   IF @n_Continue = 3 -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE dbo.nsp_logerror @n_Err, @c_ErrMsg, 'ispWAVPK09'
      RAISERROR(@c_ErrMsg, 16, 1) WITH SETERROR -- SQL2012
      --RAISERROR @nErr @cErrmsg
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO