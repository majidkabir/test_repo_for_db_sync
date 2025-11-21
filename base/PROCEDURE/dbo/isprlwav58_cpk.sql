SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispRLWAV58_CPK                                          */
/* Creation Date: 19-Apr-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22210 - AESOP Release Wave (CPK)                        */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 19-Apr-2023 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[ispRLWAV58_CPK]
   @c_Wavekey NVARCHAR(10)
 , @b_Success INT           = 1 OUTPUT
 , @n_Err     INT           = 0 OUTPUT
 , @c_ErrMsg  NVARCHAR(255) = '' OUTPUT
 , @n_debug   INT           = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt     INT          = 0
         , @n_Continue      INT          = 1
         , @n_Batch         INT          = 0
         , @n_TaskDetailKey INT          = 0
         , @c_TaskDetailKey NVARCHAR(10) = N''
         , @c_GroupKey      NVARCHAR(10) = N''
         , @c_CaseID        NVARCHAR(20) = N''
         , @c_Facility      NVARCHAR(5)  = N''
         , @c_Storerkey     NVARCHAR(15) = N''
         , @n_CtnPerCart    INT          = 0

   DECLARE @t_ORDERS TABLE
   (
      Wavekey   NVARCHAR(10)  NOT NULL DEFAULT ('')
    , Loadkey   NVARCHAR(10)  NOT NULL DEFAULT ('')
    , Orderkey  NVARCHAR(10)  NOT NULL DEFAULT ('') PRIMARY KEY
    , Facility  NVARCHAR(5)   NOT NULL DEFAULT ('')
    , Storerkey NVARCHAR(15)  NOT NULL DEFAULT ('')
    , [Route]   NVARCHAR(20)  NOT NULL DEFAULT ('')
    , C_Zip     NVARCHAR(100) NOT NULL DEFAULT ('')
   )

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_Err = 0
   SET @c_ErrMsg = ''

   IF OBJECT_ID('tempdb..#CPK_WIP', 'U') IS NOT NULL
   BEGIN
      DROP TABLE #CPK_WIP
   END

   CREATE TABLE #CPK_WIP
   (
      RowID          INT          IDENTITY(1, 1) PRIMARY KEY
    , Orderkey       NVARCHAR(10) DEFAULT ('')
    , Pickdetailkey  NVARCHAR(10) DEFAULT ('')
    , Storerkey      NVARCHAR(15) DEFAULT ('')
    , Sku            NVARCHAR(20) DEFAULT ('')
    , UOM            NVARCHAR(10) DEFAULT ('')
    , UOMQty         INT          DEFAULT (0)
    , Qty            INT          DEFAULT (0)
    , Lot            NVARCHAR(10) DEFAULT ('')
    , Loc            NVARCHAR(10) DEFAULT ('')
    , CaseID         NVARCHAR(20) DEFAULT ('')
    , DropID         NVARCHAR(20) DEFAULT ('')
    , PickLoc        NVARCHAR(10) DEFAULT ('') --Pickdetail.Loc  
    , PickLogicalloc NVARCHAR(10) DEFAULT ('')
    , PickZone       NVARCHAR(10) DEFAULT ('')
    , PickAreakey    NVARCHAR(10) DEFAULT ('')
    , PackZone       NVARCHAR(10) DEFAULT ('')
   )

   IF OBJECT_ID('tempdb..#CPK', 'U') IS NOT NULL
   BEGIN
      DROP TABLE #CPK
   END

   CREATE TABLE #CPK
   (
      RowID             INT          IDENTITY(1, 1) PRIMARY KEY
    , TaskDetailKey     NVARCHAR(10) DEFAULT ('')
    , Wavekey           NVARCHAR(10) DEFAULT ('')
    , Orderkey          NVARCHAR(10) DEFAULT ('')
    , Storerkey         NVARCHAR(15) DEFAULT ('')
    , Sku               NVARCHAR(20) DEFAULT ('')
    , UOM               NVARCHAR(10) DEFAULT ('')
    , Qty               INT          DEFAULT (0)
    , CaseID            NVARCHAR(20) DEFAULT ('')
    , Lot               NVARCHAR(10) DEFAULT ('')
    , FromLoc           NVARCHAR(10) DEFAULT ('')
    , Logicallocation   NVARCHAR(10) DEFAULT ('')
    , ToLoc             NVARCHAR(10) DEFAULT ('')
    , ToLogicallocation NVARCHAR(10) DEFAULT ('')
    , PickZone          NVARCHAR(10) DEFAULT ('')
    , AreaKey           NVARCHAR(10) DEFAULT ('')
    , RowRef            INT          DEFAULT (0)
    , Groupkey          NVARCHAR(10) DEFAULT ('')
   )

   INSERT INTO @t_ORDERS (Wavekey, Loadkey, Orderkey, Facility, Storerkey, [Route], C_Zip)
   SELECT WD.WaveKey
        , OH.LoadKey
        , OH.OrderKey
        , OH.Facility
        , OH.StorerKey
        , ISNULL(OH.[Route], '')
        , ISNULL(OH.C_Zip, '')
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON WD.OrderKey = OH.OrderKey
   WHERE WD.WaveKey = @c_Wavekey

   SELECT TOP 1 @c_Facility = tor.Facility
              , @c_Storerkey = tor.Storerkey
   FROM @t_ORDERS AS tor

   --Number of Carton per cart
   SELECT @n_CtnPerCart = CASE WHEN ISNUMERIC(Short) = 1 THEN Short
                               ELSE 0 END
   FROM CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'CUSTPARAM' AND Storerkey = @c_Storerkey AND Code = 'B2BCart'

   IF ISNULL(@n_CtnPerCart, 0) = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 66010
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                      + ': Please set up Codelkup.Short (LISTNAME = CUSTPARAM). (ispRLWAV58_CPK)'
      GOTO QUIT_SP
   END

   INSERT INTO #CPK_WIP (Orderkey, Pickdetailkey, Storerkey, Sku, UOM, UOMQty, Qty, Lot, Loc, CaseID, DropID, PickLoc)
   SELECT p.OrderKey
        , p.PickDetailKey
        , p.Storerkey
        , p.Sku
        , p2.PackUOM3
        , p.UOMQty
        , p.Qty
        , p.Lot
        , p.Loc
        , p.CaseID
        , p.DropID
        , PickLoc = p.Loc
   FROM @t_ORDERS AS tor
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = tor.Orderkey
   JOIN dbo.SKU AS s2 WITH (NOLOCK) ON s2.StorerKey = p.Storerkey AND s2.Sku = p.Sku
   JOIN dbo.PACK AS p2 WITH (NOLOCK) ON p2.PackKey = s2.PACKKey
   JOIN dbo.LOC AS l WITH (NOLOCK) ON p.Loc = l.Loc
   CROSS APPLY (  SELECT PICKDETAIL.OrderKey
                       , COUNT(DISTINCT PICKDETAIL.CaseID) AS CountCaseID
                  FROM PICKDETAIL (NOLOCK)
                  WHERE PICKDETAIL.OrderKey = tor.Orderkey
                  GROUP BY PICKDETAIL.OrderKey) AS PD
   --LEFT OUTER JOIN dbo.TaskDetail AS td2 WITH (NOLOCK) ON  td2.TaskDetailKey = p.TaskDetailKey  
   --                                                    AND td2.Caseid = p.DropID   
   --                                                    AND td2.TaskType = 'RPF'     
   WHERE p.UOM IN ( '2', '6' ) 
   AND p.Qty > 0 
   AND p.[Status] < '5'
   ORDER BY tor.[Route] ASC
          , tor.C_Zip ASC
          , PD.CountCaseID DESC --Number of ship cartons DESC
          , p.OrderKey ASC
          , p.CaseID ASC

   UPDATE cw
   SET cw.PickLogicalloc = l.LogicalLocation
     , cw.PickZone = l.PickZone
     , cw.PickAreakey = ISNULL(ad.AreaKey, '')
   FROM @t_ORDERS AS tor
   JOIN #CPK_WIP AS cw ON cw.Orderkey = tor.Orderkey
   JOIN dbo.LOC AS l WITH (NOLOCK) ON cw.PickLoc = l.Loc
   LEFT OUTER JOIN dbo.AreaDetail AS ad WITH (NOLOCK) ON ad.PutawayZone = l.PickZone

   --UPDATE cw  
   --   SET cw.PackZone = ISNULL(c.Short,'')  
   --FROM @t_ORDERS AS tor          
   --JOIN #CPK_WIP AS cw ON cw.Orderkey = tor.Orderkey  
   --LEFT OUTER JOIN dbo.CODELKUP AS c WITH (NOLOCK) ON  c.LISTNAME  = 'ADPickZone'  
   --                                                AND c.Code      = cw.PickZone  
   --                                                AND c.Storerkey = cw.Storerkey  
   --                                                AND c.code2     = tor.DocType                                           

   IF EXISTS (  SELECT 1
                FROM #CPK_WIP AS cw
                WHERE cw.PickAreakey = '')
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 66020
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                      + ': AreaKey Not Found. Please make sure all pickzone loc has setup areakey. (ispRLWAV58_CPK)'
      GOTO QUIT_SP
   END

   INSERT INTO #CPK (Wavekey, Orderkey, Storerkey, Sku, UOM, Qty, CaseID, Lot, FromLoc, Logicallocation, ToLoc
                   , ToLogicallocation, PickZone, AreaKey, RowRef)
   SELECT Wavekey = @c_Wavekey
        , cw.Orderkey
        , cw.Storerkey
        , cw.Sku
        , cw.UOM
        , SUM(cw.Qty)
        , cw.CaseID
        , cw.Lot
        , cw.PickLoc
        , cw.PickLogicalloc
        , ''
        , ''
        , cw.PickZone
        , cw.PickAreakey
        , RowRef = MIN(cw.RowID)
   FROM #CPK_WIP AS cw
   JOIN dbo.LOC AS l WITH (NOLOCK) ON cw.PickLoc = l.Loc
   GROUP BY cw.Orderkey
          , cw.Storerkey
          , cw.Sku
          , cw.UOM
          , cw.CaseID
          , cw.Lot
          , cw.PickLoc
          , cw.PickLogicalloc
          , cw.PackZone
          , cw.PickZone
          , cw.PickAreakey
   ORDER BY cw.PickZone
          , cw.PickLogicalloc

   SET @n_Batch = 0
   SELECT TOP 1 @n_Batch = c.RowID
   FROM #CPK AS c
   ORDER BY c.RowID DESC

   SET @c_TaskDetailKey = N''
   SET @b_Success = 1
   EXECUTE nspg_GetKey @KeyName = 'TaskDetailKey'
                     , @fieldlength = 10
                     , @keystring = @c_TaskDetailKey OUTPUT
                     , @b_Success = @b_Success OUTPUT
                     , @n_err = @n_Err OUTPUT
                     , @c_errmsg = @c_ErrMsg OUTPUT
                     , @n_batch = @n_Batch

   IF NOT @b_Success = 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 66040
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Get Batch TaskDetailkey Fail. (ispRLWAV58_CPK)'
      GOTO QUIT_SP
   END

   SET @n_TaskDetailKey = CONVERT(INT, @c_TaskDetailKey) - 1;
   WITH TASK (RowID, Taskdetailkey) AS
   (
      SELECT c.RowID
           , Taskdetailkey = RIGHT('0000000000'
                                   + CONVERT(NVARCHAR(10), ROW_NUMBER() OVER (ORDER BY c.RowID) + @n_TaskDetailKey), 10)
      FROM #CPK AS c
   )
   UPDATE c
   SET c.TaskDetailKey = T.TaskDetailKey
   FROM #CPK AS c
   JOIN TASK AS t ON t.RowID = c.RowID

   SELECT @n_Batch = CEILING(@n_Batch / CAST(@n_CtnPerCart AS FLOAT))

   SET @c_GroupKey = N''
   SET @b_Success = 1
   EXECUTE nspg_GetKey @KeyName = 'TaskDetailKey'
                     , @fieldlength = 10
                     , @keystring = @c_GroupKey OUTPUT
                     , @b_Success = @b_Success OUTPUT
                     , @n_err = @n_Err OUTPUT
                     , @c_errmsg = @c_ErrMsg OUTPUT
                     , @n_batch = @n_Batch

   IF NOT @b_Success = 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 66050
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Get Batch Groupkey Fail. (ispRLWAV58_CPK)'
      GOTO QUIT_SP
   END

   SET @c_GroupKey = CONVERT(INT, @c_GroupKey) - 1;
   WITH Grp (Caseid, GroupKey) AS
   (
      SELECT DISTINCT 
             c.Caseid
           , Groupkey = RIGHT('0000000000'
                              + CONVERT(
                                   NVARCHAR(10), (DENSE_RANK() OVER (ORDER BY c.Caseid) - 1) / @n_CtnPerCart + 1 + @c_GroupKey), 10)
      FROM #CPK AS c
   )
   UPDATE c
   SET c.Groupkey = T.Groupkey
   FROM #CPK AS c
   JOIN Grp AS t ON t.Caseid = c.Caseid

   INSERT INTO TaskDetail (TaskDetailKey, TaskType, Storerkey, Sku, Lot, UOM, UOMQty, Qty, FromLoc, LogicalFromLoc
                         , FromID, ToLoc, LogicalToLoc, ToID, Caseid, PickMethod, [Status], [Priority], AreaKey
                         , SourceType, SourceKey, WaveKey, OrderKey, Groupkey)
   SELECT c.TaskDetailKey
        , TaskType = 'CPK'
        , c.Storerkey
        , c.Sku
        , c.Lot
        , c.UOM
        , c.Qty
        , c.Qty
        , c.FromLoc
        , c.Logicallocation
        , FromID = ''
        , c.ToLoc
        , c.ToLogicallocation
        , ToID = ''
        , c.CaseID
        , 'PP'
        , [Status] = '0'
        , [Priority] = '9'
        , c.AreaKey
        , SourceType = 'ispRLWAV58_CPK'
        , Sourcekey = c.Wavekey
        , c.Wavekey
        , c.Orderkey
        , c.Groupkey
   FROM #CPK AS c
   ORDER BY c.RowID

   SET @n_Err = @@ERROR

   IF @n_Err <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 66060
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Insert Taskdetail Failed. (ispRLWAV58_CPK)'
      GOTO QUIT_SP
   END;
   WITH UPD_PD (TaskDetailkey, PickDetailKey) AS
   (
      SELECT c.TaskDetailKey
           , cw.Pickdetailkey
      FROM #CPK AS c
      JOIN #CPK_WIP AS cw ON cw.CaseID = c.CaseID AND cw.Lot = c.Lot AND cw.PickLoc = c.FromLoc
   )
   UPDATE p WITH (ROWLOCK)
   SET p.TaskDetailKey = up.TaskDetailkey
     , p.TrafficCop = NULL
     , p.EditWho = SUSER_SNAME()
     , p.EditDate = GETDATE()
   FROM UPD_PD AS up
   JOIN dbo.PICKDETAIL AS p ON p.PickDetailKey = up.PickDetailKey
   WHERE (p.TaskDetailKey = '' OR p.TaskDetailKey IS NULL)

   SET @n_Err = @@ERROR
   IF @n_Err <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 66070
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Update PICKDETAIL Failed. (ispRLWAV58_CPK)'
      GOTO QUIT_SP
   END

   QUIT_SP:
   IF @n_Continue = 3 -- Error Occured - Process And Return  
   BEGIN
      SET @b_Success = 0
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

      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispRLWAV58_CPK'
      RAISERROR(@c_ErrMsg, 16, 1) WITH SETERROR -- SQL2012  
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure  

GO