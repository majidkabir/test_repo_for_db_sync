SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: nspLPRTSK13                                         */
/* Creation Date: 20-Aug-2024                                            */
/* Copyright: MAERSK                                                     */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-26098 - [AU] HPAU XDock Pick Tasks Wave Release          */
/*          Enhancements                                                 */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* Github Version: 1.1                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 20-Aug-2024  WLChooi  1.0  DevOps Combine Script                      */
/* 28-Oct-2024  WLChooi  1.1  WMS-26098 - UCCNo stamp to CaseID (WL01)   */
/*************************************************************************/
CREATE   PROC [dbo].[nspLPRTSK13]
   @c_LoadKey   NVARCHAR(10)
 , @n_err       INT           OUTPUT
 , @c_ErrMsg    NVARCHAR(250) OUTPUT
 , @c_Storerkey NVARCHAR(15) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Sku                NVARCHAR(20)
         , @c_Lot                NVARCHAR(10)
         , @c_FromLoc            NVARCHAR(10)
         , @c_Prev_Loc           NVARCHAR(10) = ''
         , @c_ToLoc              NVARCHAR(10)
         , @c_ID                 NVARCHAR(18)
         , @n_Qty                INT
         , @c_PickMethod         NVARCHAR(10)
         , @c_Taskdetailkey      NVARCHAR(10)
         , @c_TaskType           NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @c_AreaKey            NVARCHAR(10)
         , @c_Prev_Areakey       NVARCHAR(10)
         , @c_PickDetailKey      NVARCHAR(10)
         , @c_TMGroupKey         NVARCHAR(10)
         , @c_TMGroupKey_Insert  NVARCHAR(10)
         , @c_Facility           NVARCHAR(5)
         , @c_Option5            NVARCHAR(MAX)
         , @c_GenTaskByConsignee NVARCHAR(10) = ''
         , @c_DropID             NVARCHAR(20)
         , @c_Wavekey            NVARCHAR(10) = ''

   DECLARE @n_continue     INT
         , @b_success      INT
         , @n_StartTranCnt INT

   SELECT @n_continue = 1
        , @n_err = 0
        , @c_ErrMsg = ''
        , @b_success = 1

   SET @n_StartTranCnt = @@TRANCOUNT

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_Facility = LP.facility
      FROM dbo.LoadPlan LP (NOLOCK)
      WHERE LP.LoadKey = @c_LoadKey

      SELECT @c_Option5 = fgr.Option5 
      FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '','ReleasePickTaskCode') AS fgr
   
      SELECT @c_GenTaskByConsignee = dbo.fnc_GetParamValueFromString('@c_GenTaskByConsignee', @c_Option5, @c_GenTaskByConsignee) 

      SELECT @c_Wavekey = ISNULL(OH.UserDefine09, '')
      FROM LoadPlanDetail LPD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON LPD.OrderKey = OH.OrderKey
      WHERE LPD.LoadKey = @c_LoadKey
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --Clear invalid taskdetailkey at pickdetail
      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET TaskDetailKey = ''
        , TrafficCop = NULL
      FROM LOADPLANDETAIL LPD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON LPD.OrderKey = O.OrderKey
      JOIN PICKDETAIL ON O.OrderKey = PICKDETAIL.OrderKey
      LEFT JOIN TaskDetail TD (NOLOCK) ON PICKDETAIL.TaskDetailKey = TD.TaskDetailKey
      WHERE ISNULL(TD.TaskDetailKey, '') = '' 
      AND LPD.LoadKey = @c_LoadKey 
      AND O.StorerKey = @c_Storerkey

      IF NOT EXISTS (  SELECT 1
                       FROM PICKDETAIL P WITH (NOLOCK)
                       JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = P.OrderKey
                       JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = P.OrderKey
                       JOIN LoadPlan LP WITH (NOLOCK) ON LP.LoadKey = LPD.LoadKey
                       WHERE LPD.LoadKey = @c_LoadKey 
                       AND P.[Status] = '0' 
                       AND ISNULL(P.TaskDetailKey, '') = '')
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err)
              , @n_err = 81002
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': No task to release' + ' ( ' + ' SQLSvr MESSAGE= '
                            + @c_ErrMsg + ' ) '
         GOTO QUIT_SP
      END
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT LLI.StorerKey
           , LLI.Loc
           , LLI.Id
           , SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS QtyAvailable
      INTO #TMP_LOCXID
      FROM LOTxLOCxID LLI (NOLOCK)
      --JOIN SKUxLOC SL (NOLOCK) ON LLI.StorerKey = SL.StorerKey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
      JOIN LOC (NOLOCK) ON  LLI.Loc = LOC.Loc
                        AND LLI.StorerKey = @c_Storerkey AND LLI.Qty > 0
                        AND LOC.LocationType NOT IN ( 'PICK', 'CASE' )
      GROUP BY LLI.StorerKey
             , LLI.Loc
             , LLI.Id

      SELECT PD.Storerkey
           , PD.Loc
           , PD.ID
           , LI.QtyAvailable AS LOCXID_QTYAVAILABLE
           , COUNT(DISTINCT PD.Sku) AS SkuCount
           , COUNT(DISTINCT PD.Lot) AS LotCount
      INTO #LOCXID_QTYAVAILABLE
      FROM LoadPlanDetail LD (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON LD.OrderKey = PD.OrderKey
      JOIN #TMP_LOCXID LI (NOLOCK) ON PD.Storerkey = LI.StorerKey AND PD.Loc = LI.Loc AND PD.ID = LI.Id
      --JOIN SKUxLOC SL (NOLOCK) ON PD.Storerkey = SL.StorerKey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      WHERE LD.LoadKey = @c_LoadKey 
      AND   PD.Storerkey = @c_Storerkey
      AND   LOC.LocationType NOT IN ( 'PICK', 'CASE' )
      GROUP BY PD.Storerkey
             , PD.Loc
             , PD.ID
             , LI.QtyAvailable

      DECLARE cur_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.Storerkey
           , Sku = CASE WHEN (@c_GenTaskByConsignee = 'Y' AND PICK.TaskType = 'FPK') THEN ''
                        WHEN (@c_GenTaskByConsignee = 'Y' AND PICK.TaskType = 'FCP') THEN MAX(PD.Sku)
                        ELSE IIF(LOC.LocationType NOT IN ( 'PICK', 'CASE' ), '', MAX(PD.Sku))
                        END
           , Lot = CASE WHEN (@c_GenTaskByConsignee = 'Y' AND PICK.TaskType = 'FPK') THEN ''
                        WHEN (@c_GenTaskByConsignee = 'Y' AND PICK.TaskType = 'FCP') THEN MAX(PD.Lot)
                        ELSE IIF(LOC.LocationType NOT IN ( 'PICK', 'CASE' ), '', MAX(PD.Lot))
                        END
           , PD.Loc
           , PD.ID
           , SUM(PD.Qty) AS Qty
           , PD.UOM
           , PickMethod = CASE WHEN (@c_GenTaskByConsignee = 'Y' AND PICK.TaskType = 'FPK') THEN 'FP'
                               WHEN (@c_GenTaskByConsignee = 'Y' AND PICK.TaskType = 'FCP') THEN 'PP'
                               ELSE IIF(LOC.LocationType NOT IN ( 'PICK', 'CASE' ) AND ISNULL(LI.LOCXID_QTYAVAILABLE, 0) <= 0, 'FP', 'PP')
                               END
           , TaskType = IIF(@c_GenTaskByConsignee = 'Y', PICK.TaskType, IIF(LOC.LocationType NOT IN ( 'PICK', 'CASE' ), 'FPK' , 'FCP'))
           , MAX(O.Door) AS ToLoc
           , AD.AreaKey
           , DropID = CASE WHEN PICK.TaskType = 'FPK' THEN '' ELSE PD.DropID END
      FROM LoadPlan L (NOLOCK)
      JOIN LoadPlanDetail LD (NOLOCK) ON L.LoadKey = LD.LoadKey
      JOIN ORDERS O (NOLOCK) ON LD.OrderKey = O.OrderKey
      JOIN PICKDETAIL PD (NOLOCK) ON O.OrderKey = PD.OrderKey
      --JOIN SKUxLOC SL (NOLOCK) ON PD.Storerkey = SL.StorerKey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      OUTER APPLY (  SELECT TOP 1 AreaKey
                     FROM AreaDetail (NOLOCK)
                     WHERE AreaDetail.PutawayZone = LOC.PutawayZone
                     ORDER BY AreaDetail.AreaKey) AD
      CROSS APPLY ( SELECT DropIDCnt = COUNT(DISTINCT PICK.DropID) 
                    FROM PICKDETAIL PICK (NOLOCK) 
                    WHERE PICK.ID = PD.ID
                    AND PICK.Storerkey = PD.Storerkey ) AS PIDET
      OUTER APPLY ( SELECT COUNT(1) AS Valid
                    FROM CODELKUP CL (NOLOCK)
                    WHERE CL.LISTNAME = 'GENFPKBYST'
                    AND CL.Storerkey = O.StorerKey
                    AND CL.Code = O.ConsigneeKey ) C1
      CROSS APPLY (  SELECT IIF(COUNT(DISTINCT LOTATTRIBUTE.Lottable03) = 1
                              , IIF(SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0, 
                                    'FCP', 
                                    IIF(PIDET.DropIDCnt < 10, 
                                        'FCP', 
                                        IIF(C1.Valid > 0, 'FPK', 'FCP')))
                              , 'FCP') AS TaskType
                     FROM LOTxLOCxID (NOLOCK)
                     JOIN LOTATTRIBUTE (NOLOCK) ON LOTATTRIBUTE.Lot = LOTxLOCxID.Lot
                     WHERE LOTxLOCxID.ID = PD.ID 
                     AND LOTxLOCxID.Qty > 0
                     AND LOTxLOCxID.Storerkey = PD.Storerkey ) AS PICK
      LEFT JOIN #LOCXID_QTYAVAILABLE LI (NOLOCK) ON PD.Storerkey = LI.Storerkey AND PD.Loc = LI.Loc AND PD.ID = LI.ID
      WHERE L.LoadKey = @c_LoadKey 
      AND O.StorerKey = @c_Storerkey 
      AND ISNULL(PD.TaskDetailKey, '') = '' 
      AND PD.[Status] = '0'
      GROUP BY PD.Storerkey
             , PD.Loc
             , PD.ID
             , PD.UOM
             , CASE WHEN (@c_GenTaskByConsignee = 'Y' AND PICK.TaskType = 'FPK') THEN 'FP'
                    WHEN (@c_GenTaskByConsignee = 'Y' AND PICK.TaskType = 'FCP') THEN 'PP'
                    ELSE IIF(LOC.LocationType NOT IN ( 'PICK', 'CASE' ) AND ISNULL(LI.LOCXID_QTYAVAILABLE, 0) <= 0, 'FP', 'PP')
                    END
             , LOC.LogicalLocation
             , AD.AreaKey
             , IIF(@c_GenTaskByConsignee = 'Y', PICK.TaskType, IIF(LOC.LocationType NOT IN ( 'PICK', 'CASE' ), 'FPK' , 'FCP'))
             , CASE WHEN PICK.TaskType = 'FPK' THEN '' ELSE PD.DropID END
             , PICK.TaskType
             , LOC.LocationType
      ORDER BY PD.Storerkey
             --, MAX(AD.AreaKey)
             --, LOC.LogicalLocation
             , PD.Loc

      OPEN cur_PickDetail

      FETCH NEXT FROM cur_PickDetail
      INTO @c_Storerkey
         , @c_Sku
         , @c_Lot
         , @c_FromLoc
         , @c_ID
         , @n_Qty
         , @c_UOM
         , @c_PickMethod
         , @c_TaskType
         , @c_ToLoc
         , @c_AreaKey
         , @c_DropID

      SET @c_Prev_Areakey = '*START*'

      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @c_TaskType = 'FCP'
         BEGIN
            IF (@c_FromLoc <> @c_Prev_Loc)
            BEGIN
               EXECUTE nspg_getkey
               'TMGroupKey',
               10,
               @c_TMGroupKey    OUTPUT,
               @b_success       OUTPUT,
               @n_err           OUTPUT,
               @c_ErrMsg        OUTPUT
         
               IF NOT @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81004
                  SELECT @c_ErrMsg = 'NSQL'+ CONVERT(CHAR(5), @n_err) + ': Unable to Get TMGroupKey (nspLPRTSK13)' +
                                     ' ( ' + ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '
                  GOTO Quit_SP
               END
            END
         
            SELECT @c_Prev_Loc = @c_FromLoc
            SELECT @c_TMGroupKey_Insert = @c_TMGroupKey
         END
         ELSE
            SELECT @c_TMGroupKey_Insert = N''

         EXECUTE nspg_GetKey 'TaskDetailKey'
                           , 10
                           , @c_Taskdetailkey OUTPUT
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_ErrMsg OUTPUT

         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err)
                 , @n_err = 81005
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Unable to Get TaskDetailKey (nspLPRTSK13)'
                               + ' ( ' + ' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '
            GOTO QUIT_SP
         END
         ELSE
         BEGIN
            INSERT TASKDETAIL
                 ( TaskDetailKey
                 , TaskType
                 , Storerkey
                 , Sku
                 , Lot
                 , UOM
                 , UOMQty
                 , Qty
                 , FromLoc
                 , FromID
                 , ToLoc
                 , ToId
                 , SourceType
                 , SourceKey
                 , Caseid
                 , [Priority]
                 , SourcePriority
                 , OrderKey
                 , OrderLineNumber
                 , PickDetailKey
                 , PickMethod
                 , [Status]
                 , LoadKey
                 , Areakey
                 , Message01
                 , SystemQty
                 , GroupKey
                 , DropID
                 , WaveKey)
            VALUES (
                   @c_TaskDetailKey
                 , @c_TaskType
                 , @c_Storerkey
                 , @c_Sku
                 , @c_Lot
                 , @c_UOM
                 , 0
                 , @n_Qty
                 , @c_fromloc
                 , @c_ID
                 , @c_ToLoc
                 , @c_ID
                 , 'nspLPRTSK13'
                 , @c_LoadKey
                 , IIF(@c_TaskType = 'FCP', @c_DropID, '')   --WL01
                 , '5'
                 , '9'
                 , ''
                 , ''
                 , ''
                 , @c_PickMethod
                 , '0'
                 , @c_LoadKey
                 , @c_AreaKey
                 , ''
                 , @n_Qty
                 , @c_TMGroupKey_Insert
                 , ''   --IIF(@c_TaskType = 'FCP', @c_DropID, '')   --WL01
                 , @c_Wavekey)

            SELECT @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err)
                    , @n_err = 81006
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Insert Into TaskDetail Failed (nspLPRTSK13)'
                                  + ' ( ' + ' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '
               GOTO QUIT_SP
            END

            -- Update the Pickdetail TaskDetailKey
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               IF @c_TaskType = 'FPK'
               BEGIN
                  DECLARE CUR_PICKDETAILKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT P.PickDetailKey
                  FROM PICKDETAIL P WITH (NOLOCK)
                  JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = P.OrderKey
                  JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = P.OrderKey
                  WHERE LPD.LoadKey = @c_LoadKey
                  AND   P.[Status] = '0'
                  AND   ISNULL(P.TaskDetailKey, '') = ''
                  AND   P.Loc = @c_FromLoc
                  AND   P.ID = @c_ID
                  AND   O.StorerKey = @c_Storerkey
                  AND   P.UOM = @c_UOM
               END
               ELSE
               BEGIN
                  DECLARE CUR_PICKDETAILKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT P.PickDetailKey
                  FROM PICKDETAIL P WITH (NOLOCK)
                  JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = P.OrderKey
                  JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = P.OrderKey
                  WHERE LPD.LoadKey = @c_LoadKey
                  AND   P.[Status] = '0'
                  AND   ISNULL(P.TaskDetailKey, '') = ''
                  AND   P.Loc = @c_FromLoc
                  AND   P.ID = @c_ID
                  --AND   P.Sku = @c_Sku
                  --AND   P.Lot = @c_Lot
                  AND   O.StorerKey = @c_Storerkey
                  AND   P.UOM = @c_UOM
                  AND   P.DropID = @c_DropID
               END

               OPEN CUR_PICKDETAILKEY
               FETCH NEXT FROM CUR_PICKDETAILKEY
               INTO @c_PickDetailKey

               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET TaskDetailKey = @c_Taskdetailkey
                    , TrafficCop = NULL
                  WHERE PickDetailKey = @c_PickDetailKey

                  FETCH NEXT FROM CUR_PICKDETAILKEY
                  INTO @c_PickDetailKey
               END
               CLOSE CUR_PICKDETAILKEY
               DEALLOCATE CUR_PICKDETAILKEY
            END
         END

         FETCH NEXT FROM cur_PickDetail
         INTO @c_Storerkey
            , @c_Sku
            , @c_Lot
            , @c_FromLoc
            , @c_ID
            , @n_Qty
            , @c_UOM
            , @c_PickMethod
            , @c_TaskType
            , @c_ToLoc
            , @c_AreaKey
            , @c_DropID
      END
      CLOSE cur_PickDetail
      DEALLOCATE cur_PickDetail
   END

   QUIT_SP:

   IF OBJECT_ID('tempdb..#LOCXID_QTYAVAILABLE') IS NOT NULL
      DROP TABLE #LOCXID_QTYAVAILABLE

   IF OBJECT_ID('tempdb..#TMP_LOCXID') IS NOT NULL
      DROP TABLE #TMP_LOCXID

   IF CURSOR_STATUS('LOCAL', 'cur_PickDetail') IN (0 , 1)
   BEGIN
      CLOSE cur_PickDetail
      DEALLOCATE cur_PickDetail   
   END
      
   IF @n_continue <> 3
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTranCnt
      COMMIT TRAN
   END
END

GO