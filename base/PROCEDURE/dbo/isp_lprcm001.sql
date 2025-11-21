SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_LPRCM001                                       */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#336088 - Allow release of Replen Tasks before Pick Tasks*/
/*        : Move the DRP task from 'nspLPRTSK2'                         */
/*                                                                      */
/* Called By: Dynamic RCM Menu                                          */
/*                                                                      */
/* Version: 3.3                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_LPRCM001]
      @c_LoadKey     NVARCHAR(10) 
   ,  @b_Success     INT            OUTPUT
   ,  @n_err         INT            OUTPUT 
   ,  @c_ErrMsg      NVARCHAR(250)  OUTPUT 
   ,  @c_code        NVARCHAR(10) = '' 
AS
BEGIN
    SET NOCOUNT ON
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @n_continue       INT
           ,@n_StartTCnt      INT

    DECLARE @c_TaskDetailKey  NVARCHAR(10)
           ,@c_Storerkey      NVARCHAR(15)
           ,@c_Sku            NVARCHAR(20)
           ,@c_LOT            NVARCHAR(10)
           ,@c_ID             NVARCHAR(18)
           ,@c_FromLoc        NVARCHAR(10)
           ,@c_ToLoc          NVARCHAR(10)
           ,@c_Status         NVARCHAR(10)

           ,@c_Facility       NVARCHAR(10)
           ,@c_ReplenPriority NVARCHAR(10)
           ,@n_ReplenQty      INT
           ,@n_Qty            INT

   DECLARE  @d_StartTime    datetime,
            @d_EndTime      datetime,
            @d_Step1        datetime,
            @d_Step2        datetime,
            @d_Step3        datetime,
            @d_Step4        datetime,
            @d_Step5        datetime,
            @d_SubStartTime datetime,
            @d_SubEndTime   datetime,
            @d_SubStep1     datetime,
            @d_SubStep2     datetime,
            @d_SubStep3     datetime,
            @d_SubStep4     datetime,
            @d_SubStep5     datetime,
            @c_col1         NVARCHAR(20),
            @c_col2         NVARCHAR(20),
            @c_col3         NVARCHAR(20),
            @c_col4         NVARCHAR(20),
            @c_col5         NVARCHAR(20),
            @c_myTraceName  NVARCHAR(80),
            @b_mydebug        int

   SET @b_mydebug = 0
   SET @c_myTraceName= 'isp_LPRCM001'

   SET @n_StartTCnt = @@TRANCOUNT
   SET @d_StartTime = GETDATE()
   SET @c_Status    = '0'

--   IF EXISTS ( SELECT 1
--               FROM TASKDETAIL WITH (NOLOCK)
--               WHERE TaskType = 'DRP'
--               AND SourceType = 'isp_LPRCM001'
--               AND SourceKey = @c_LoadKey
--               AND Status < '9'
--             )
--   BEGIN
--      SET @n_continue = 3
--      SET @n_err = 81024 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--      SET @c_ErrMsg = 'DRP Task(s) had been released (isp_LPRCM001)'
--      GOTO QUIT_SP
--   END

   IF @b_mydebug = 1 
   BEGIN
      INSERT INTO [dbo].[Temp_ReplenTrace]
                  ( [LoadKey]
                  , [AddDate]
                  , [StorerKey]
                  , [SKU]
                  , [LOC]
                  , [Qty]
                  , [PATaskQty]
                  , [QtyAllocated]
                  , [QtyPicked]
                  , [QtyLocationLimit]
                  , [QtyLocationMinimum]
                  , [LocationType]
                  , [AddWho]
                  , [AlertStatus] )
      SELECT @c_LoadKey, GETDATE()
           , SL.StorerKey
           , SL.SKU
           , SL.LOC
           , SL.Qty
           , ISNULL(PA_TASK.Qty, 0)
           , SL.QtyAllocated
           , SL.QtyPicked
           , SL.QtyLocationLimit
           , SL.QtyLocationMinimum
           , SL.LocationType
           , SUSER_SNAME()
           , '5'
      FROM   SKUxLOC SL WITH (NOLOCK)
      JOIN   LOC WITH (NOLOCK) ON LOC.Loc = SL.Loc
      LEFT OUTER JOIN
             ( SELECT StorerKey, SKU, ToLoc AS LOC, SUM(Qty) AS Qty
               FROM   TaskDetail WITH (NOLOCK)
               WHERE  STATUS < '9'
               AND    TaskDetail.TaskType IN ('PA','DRP')
               GROUP BY StorerKey, SKU, ToLoc) AS PA_TASK
               ON PA_TASK.StorerKey = SL.StorerKey
               AND PA_TASK.Sku = SL.Sku
               AND PA_TASK.LOC = SL.LOC
      WHERE EXISTS ( SELECT 1
                     FROM LOADPLANDETAIL LPD WITH (NOLOCK)
                     JOIN ORDERS     OH  WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey) 
                     JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
                     JOIN LOC        LOC WITH (NOLOCK) ON (PD.Loc = LOC.loc)
                     WHERE LPD.Loadkey = @c_Loadkey
                     AND  PD.Storerkey = SL.Storerkey
                     AND  PD.Sku = SL.Sku
                     AND  PD.Loc = SL.Loc 
                     AND  PD.Status = '0'  
                     AND ( PD.TaskDetailKey IS NULL OR PD.TaskDetailKey = '' )   
                     AND LOC.LocationType IN ('DYNPICKP', 'DYNPICKR','PICK')
                 )
   END

   DECLARE CUR_REPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT sl.StorerKey
      , sl.SKU
      , sl.LOC
      , sl.QtyLocationLimit - ((sl.Qty  + ISNULL(PA_TASK.Qty, 0)) - (sl.QtyAllocated + sl.QtyPicked)) 
      , LOC.Facility
      , ReplenishmentPriority  
   FROM   SKUxLOC sl WITH (NOLOCK)
   JOIN   LOC WITH (NOLOCK) ON LOC.Loc = sl.Loc
   LEFT OUTER JOIN
        (SELECT StorerKey, SKU, ToLoc AS LOC, SUM(Qty) AS Qty
         FROM   TaskDetail WITH (NOLOCK)
         WHERE  STATUS < '9'
         AND    TaskDetail.TaskType IN ('PA','DRP')
         GROUP BY StorerKey, SKU, ToLoc) AS PA_TASK
         ON PA_TASK.StorerKey = sl.StorerKey
            AND PA_TASK.Sku = sl.Sku
            AND PA_TASK.LOC = sl.LOC
   WHERE (sl.Qty  + ISNULL(PA_TASK.Qty, 0)) - (sl.QtyAllocated + sl.QtyPicked) < sl.QtyLocationMinimum
   AND  sl.LocationType IN ('PICK', 'CASE')
   AND EXISTS ( SELECT 1
                FROM LOADPLANDETAIL LPD WITH (NOLOCK)
                JOIN ORDERS     OH  WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey) 
                JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
                JOIN LOC        LOC WITH (NOLOCK) ON (PD.Loc = LOC.loc)
                WHERE LPD.Loadkey = @c_Loadkey
                  AND  PD.Storerkey = SL.Storerkey
                  AND  PD.Sku = SL.Sku
                  AND  PD.Loc = SL.Loc 
                  AND  PD.Status = '0'  
                  AND ( PD.TaskDetailKey IS NULL OR PD.TaskDetailKey = '' )   
                  AND LOC.LocationType IN ('DYNPICKP', 'DYNPICKR','PICK')
                 )
   OPEN CUR_REPL

   FETCH NEXT FROM CUR_REPL INTO @c_StorerKey
                                          ,  @c_SKU
                                          ,  @c_ToLOC
                                          ,  @n_ReplenQty
                                          ,  @c_Facility
                                          ,  @c_ReplenPriority
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      -- Find Available Qty FROM Bulk
      DECLARE CUR_AVAILQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT lli.LOT, lli.LOC, lli.Id,
           (lli.Qty - lli.QtyAllocated - lli.QtyPicked - CASE WHEN lli.QtyReplen > 0 THEN lli.QtyReplen ELSE 0 END) 
      FROM   LOTxLOCxID lli WITH (NOLOCK)
      JOIN   SKUxLOC sl WITH (NOLOCK) ON sl.StorerKey = lli.StorerKey AND sl.Sku = lli.Sku AND sl.Loc = lli.Loc
      JOIN   LOC WITH (NOLOCK) ON LOC.Loc = lli.Loc
      JOIN   ID  WITH (NOLOCK) ON ID.ID = lli.Id AND ID.[Status] = 'OK'
      JOIN   LOT WITH (NOLOCK) ON LOT.Lot = lli.Lot AND lot.[Status] = 'OK'
      WHERE  lli.StorerKey = @c_StorerKey
      AND    lli.Sku = @c_SKU
      AND    sl.LocationType NOT IN ('PICK', 'CASE')
      AND    LOC.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','PICK') 
      AND    LOC.[Status] = 'OK'
      AND    LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
      AND    (lli.Qty - lli.QtyAllocated - lli.QtyPicked - CASE WHEN lli.QtyReplen > 0 
                                                                THEN lli.QtyReplen 
                                                                ELSE 0 END) > 0 
      OPEN CUR_AVAILQTY

      FETCH NEXT FROM CUR_AVAILQTY INTO @c_LOT, @c_FromLoc, @c_ID, @n_Qty
      WHILE @@FETCH_STATUS <> -1
      BEGIN

         IF @n_Qty > @n_ReplenQty
            SET @n_Qty = @n_ReplenQty

         -- Insert Replen Task here
         EXECUTE nspg_getkey
               'TaskDetailKey' 
            ,  10 
            ,  @c_TaskDetailKey  OUTPUT 
            ,  @b_Success        OUTPUT 
            ,  @n_err            OUTPUT 
            ,  @c_ErrMsg         OUTPUT

         IF NOT @b_Success=1
         BEGIN
            SET @n_continue = 3
            SET @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
            SET @n_err = 81024 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)
                 + ': Unable to Get TaskDetailKey (isp_LPRCM001)'
                 +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                 +' ) '
            GOTO QUIT_SP
         END
         ELSE
         BEGIN
            INSERT TASKDETAIL
             (
               TaskDetailKey, TaskType, Storerkey, Sku, Lot, UOM,
               UOMQty, Qty, FromLoc, FromID, ToLoc, ToId, SourceType,
               SourceKey, Caseid, Priority, SourcePriority, OrderKey,
               OrderLineNumber, PickDetailKey, PickMethod, STATUS,
               LoadKey, AreaKey, SystemQty
             )
            VALUES
             (
               @c_TaskDetailKey, 'DRP'
               , @c_Storerkey
               , @c_SKU
               , @c_LOT -- Lot,
               , ''     -- UOM,
               , 0      -- UOMQty,
               , @n_Qty
               , @c_FromLoc -- FromLoc
               , @c_ID      -- FromID
               , @c_ToLoc   -- ToLoc
               , ''         -- ToID
               , 'isp_LPRCM001'
               , @c_LoadKey
               , ''             -- Caseid
               , @c_ReplenPriority    -- Priority
               , '9'
               , '' -- Orderkey,
               , '' -- OrderLineNumber
               , '' -- PickDetailKey
               , 'CASE' -- PickMethod
               , @c_Status
               , @c_LoadKey
               , ''  
               , @n_Qty  
            )

           SET @n_err = @@ERROR
           IF @n_err<>0
           BEGIN
               SET @n_continue = 3
               SET @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
               SET @n_err = 81025 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err) 
                     +': Insert Into TaskDetail Failed (isp_LPRCM001)'
                     +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                     +' ) '
              GOTO QUIT_SP
            END
         END

         UPDATE LOTxLOCxID WITH (ROWLOCK)
         SET QtyReplen = QtyReplen + @n_Qty
         WHERE LOT = @c_Lot
         AND   LOC = @c_FromLoc
         AND   ID  = @c_ID

         SET @n_err = @@ERROR
         IF @n_err<>0
         BEGIN
            SET @n_continue = 3
            SET @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
            SET @n_err = 81026 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err) 
                  +': Insert Into TaskDetail Failed (isp_LPRCM001)'
                  +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                  +' ) '
            GOTO QUIT_SP
         END

         SET @n_ReplenQty = @n_ReplenQty - @n_Qty

         IF @n_ReplenQty <= 0  
            BREAK
           
         FETCH NEXT FROM CUR_AVAILQTY INTO @c_LOT, @c_FromLoc, @c_ID, @n_Qty
      END
      CLOSE CUR_AVAILQTY
      DEALLOCATE CUR_AVAILQTY

      FETCH NEXT FROM CUR_REPL INTO @c_StorerKey
                                             ,  @c_SKU
                                             ,  @c_ToLOC
                                             ,  @n_ReplenQty
                                             ,  @c_Facility
                                             ,  @c_ReplenPriority
   END
   CLOSE CUR_REPL
   DEALLOCATE CUR_REPL

   IF @b_mydebug = 1 
   BEGIN
      -- Added by SHong on 02-Aug-2011
      -- To track replen task not ganerated Issues
      INSERT INTO [dbo].[Temp_ReplenTrace]
        ([LoadKey]
        ,[AddDate]
        ,[StorerKey]
        ,[SKU]
        ,[LOC]
        ,[Qty]
        ,[PATaskQty]
        ,[QtyAllocated]
        ,[QtyPicked]
        ,[AddWho])
      SELECT  @c_LoadKey
            , GetDate()
            , sl.StorerKey
            , sl.SKU
            , sl.LOC
            , sl.Qty
            , ISNULL(PA_TASK.Qty, 0) AS PATaskQty
            , sl.QtyAllocated
            , sl.QtyPicked
            , sUser_sName()
      FROM   SKUxLOC sl WITH (NOLOCK)
      JOIN   LOC WITH (NOLOCK) ON LOC.Loc = sl.Loc
      LEFT OUTER JOIN
           (SELECT StorerKey, SKU, ToLoc AS LOC, SUM(Qty) AS Qty
            FROM   TaskDetail WITH (NOLOCK)
            WHERE  STATUS < '9'
            AND    TaskDetail.TaskType IN ('PA','DRP')
            GROUP BY StorerKey, SKU, ToLoc) AS PA_TASK
            ON PA_TASK.StorerKey = sl.StorerKey
               AND PA_TASK.Sku = sl.Sku
               AND PA_TASK.LOC = sl.LOC
      WHERE (sl.Qty  + ISNULL(PA_TASK.Qty, 0)) - (sl.QtyAllocated + sl.QtyPicked) < sl.QtyLocationMinimum
      AND  sl.LocationType IN ('PICK', 'CASE')
      AND EXISTS ( SELECT 1
                   FROM LOADPLANDETAIL LPD WITH (NOLOCK)
                   JOIN ORDERS     OH  WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey) 
                   JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
                   JOIN LOC        LOC WITH (NOLOCK) ON (PD.Loc = LOC.loc)
                   WHERE LPD.Loadkey = @c_Loadkey
                     AND  PD.Storerkey = SL.Storerkey
                     AND  PD.Sku = SL.Sku
                     AND  PD.Loc = SL.Loc 
                     AND  PD.Status = '0'  
                     AND ( PD.TaskDetailKey IS NULL OR PD.TaskDetailKey = '' )   
                     AND LOC.LocationType IN ('DYNPICKP', 'DYNPICKR','PICK')
                    )
   END

   Quit_SP:
   IF CURSOR_STATUS('LOCAL' , 'CUR_AVAILQTY') in (0 , 1)
   BEGIN
      CLOSE CUR_AVAILQTY
      DEALLOCATE CUR_AVAILQTY
   END

   IF CURSOR_STATUS('LOCAL' , 'CUR_REPL') in (0 , 1)
   BEGIN
      CLOSE CUR_REPL
      DEALLOCATE CUR_REPL
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_LPRCM001'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END

GO