SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_TaskManagerMove                                */
/* Creation Date: 15-Apr-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#158753 - Task Manager Release Move Tasks                */
/*                                                                      */
/* Called By: TM Inventory Move                                         */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 15-Sep-2011  YTWan    1.1  SOS#224300: Partial Pallet Move.(Wan01)   */
/* 18-DEC-2012  YTWan    1.1  SOS#260275: VAS - Create Jobs (Wan02)     */
/* 02-JUL-2013  YTWan    1.1  SOS#271282: ABC - ABC Move task (Wan03)   */
/* 07-MAY-2015  NJOW01   1.2  340170 - change tasktype MV to MVF and    */
/*                            add areakey.                              */
/* 26-JAN-2016  YTWan    1.1  SOS#315603 - Project Merlion - VAP SKU    */
/*                            Reservation Strategy - MixSku in 1 Pallet */
/*                            enhancement                               */	
/************************************************************************/
CREATE PROC    [dbo].[isp_TaskManagerMove]
               @c_StorerKey    NVARCHAR(15)
,              @c_Sku          NVARCHAR(20)
,              @c_FromLoc      NVARCHAR(10)
,              @c_FromID       NVARCHAR(18)
,              @c_ToLoc        NVARCHAR(10)
,              @c_ToID         NVARCHAR(18)
,              @n_qty          int
,              @c_SourceKey    NVARCHAR(30) = ''                                                   --(Wan02)
,              @c_SourceType   NVARCHAR(30) = 'isp_TaskManagerMove'                                --(Wan02)
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
,              @c_Lot          NVARCHAR(10)  = ''                                                  --(Wan01)
,              @c_MoveMethod   NVARCHAR(2)   = ''                                                  --(Wan01)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,  
           @n_starttcnt int,
           @n_cnt int 
   
   DECLARE @c_taskdetailkey   NVARCHAR(10),
           @c_logicalfromloc  NVARCHAR(10),
           @c_logicaltoloc    NVARCHAR(10)

   DECLARE @c_PickMethod      NVARCHAR(10)                                                         --(Wan01)
         , @n_QtyAvailable    INT                                                                  --(Wan01)                                                              
         , @n_QtyPendingMove  INT                                                                  --(Wan01)
      
   DECLARE @c_Jobkey          NVARCHAR(10)                                                         --(Wan04)
         , @c_JobLineNo       NVARCHAR(5)                                                          --(Wan04)
         , @c_TmpLoc          NVARCHAR(10)                                                         --(Wan04)
         , @c_PullUOM         NVARCHAR(10)                                                         --(Wan04)
         , @c_PackKey         NVARCHAR(10)                                                         --(Wan04)
         , @c_PackUOM3        NVARCHAR(10)                                                         --(Wan04)
         , @c_PackUOM4        NVARCHAR(10)                                                         --(Wan04)
         , @c_MoveRefKey      NVARCHAR(10)                                                         --(Wna04)

   --(Wan02) - START
   DECLARE @c_TaskType        NVARCHAR(10) 
         , @c_Priority        NVARCHAR(10)                                                           
         , @c_SourcePriority  NVARCHAR(10) 
         , @c_RefTaskkey      NVARCHAR(10)
         , @c_Areakey         NVARCHAR(10)
   SET @c_TaskType      = 'MVF' 
   SET @c_Priority      = '5'
   SET @c_SourcePriority= '9'
   SET @c_RefTaskkey    = ''
   --(Wan02) - END
   
   SET @c_logicaltoloc  = ''

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg=""
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --(Wan03) - START
      IF @c_SourceType = 'ABC'
      BEGIN
         SET @c_TaskType = 'ABCMOVE'
         SET @c_Priority = '9'            --(Lowest priority)
      END
      --(Wan03) - END

      --(Wan01) - START
--      SELECT @n_cnt = COUNT(*)
--      FROM LOTXLOCXID (NOLOCK) 
--      LEFT JOIN TASKDETAIL TD1 (NOLOCK) ON (LOTXLOCXID.Storerkey = TD1.Storerkey
--                                        AND LOTXLOCXID.Loc = TD1.FromLoc
--                                        AND LOTXLOCXID.Id = TD1.FromID
--                                        AND TD1.TaskType = 'MV' 
--                                        AND TD1.Status NOT IN ('S','9')) 
--      LEFT JOIN TASKDETAIL TD2 (NOLOCK) ON (LOTXLOCXID.Storerkey = TD2.Storerkey
--                                        AND LOTXLOCXID.Sku = TD2.Sku
--                                        AND LOTXLOCXID.Loc = TD2.FromLoc
--                                        AND LOTXLOCXID.Id = TD2.FromID
--                                        AND TD2.TaskType = 'MV' 
--                                        AND TD2.Status NOT IN ('S','9')) 
--      WHERE LOTXLOCXID.Storerkey = @c_storerkey
--      AND (LOTXLOCXID.Sku = @c_sku OR @c_sku = 'MIXED_SKU')
--      AND LOTXLOCXID.Loc = @c_fromloc
--      AND LOTXLOCXID.Id = @c_fromid
--      AND (TD1.TaskDetailKey IS NOT NULL 
--      OR TD2.TaskDetailKey IS NOT NULL)
--      IF @n_cnt > 0
--      BEGIN
--         SELECT @n_continue = 3         
--         SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err),@n_err = 62079     
--         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
--                ': The From Loc and Id are pending move in Task Manager queue. Duplicate move is not allowed. (isp_TaskManagerMove)'                   
--      END

      SET @c_PickMethod = ''
      SELECT @c_PickMethod = ISNULL(MIN(TD1.PickMethod),0)
      FROM LOTXLOCXID WITH (NOLOCK) 
      LEFT JOIN TASKDETAIL TD1 WITH (NOLOCK) ON (LOTXLOCXID.Storerkey = TD1.Storerkey
                                             AND LOTXLOCXID.Loc = TD1.FromLoc
                                             AND LOTXLOCXID.Id = TD1.FromID
                                             AND TD1.TaskType = 'MVF' 
                                             AND TD1.Status NOT IN ('S','9','X'))                    
              
      WHERE LOTXLOCXID.Storerkey = @c_storerkey
      AND LOTXLOCXID.Loc = @c_fromloc
      AND LOTXLOCXID.Id = @c_fromid
      AND TD1.TaskDetailKey IS NOT NULL

      IF @c_PickMethod = 'FP' 
      BEGIN
         IF @c_MoveMethod = 'FP'
         BEGIN
            SET @n_continue = 3         
            SET @n_err = 62079 
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                   ': The From Loc and Id are pending move in Task Manager queue. Duplicate Full Pallet move is not allowed. (isp_TaskManagerMove)'
         END
         ELSE IF @c_MoveMethod = 'PP'
         BEGIN
            SET @n_continue = 3         
            SET @n_err = 62080
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                   ': Full Pallet are pending move in Task Manager queue. Partial Pallet is not allowed. (isp_TaskManagerMove)'

         END
      END
      ELSE IF @c_PickMethod = 'PP'
      BEGIN
         IF @c_MoveMethod = 'FP'
         BEGIN             
            SET @n_continue = 3         
            SET @n_err = 62081     
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                   ': There is/are partial pallet pending move in Task Manager queue. Full Pallet Move is not allowed. (isp_TaskManagerMove)'
         END 
         ELSE IF @c_MoveMethod = 'PP'
         BEGIN
            SET @n_cnt = 0
            SELECT @n_QtyAvailable = ISNULL(LOTXLOCXID.Qty-LOTXLOCXID.QtyAllocated-LOTXLOCXID.QtyPicked,0)
                  ,@n_QtyPendingMove = ISNULL(TD3.Qty,0)
            FROM LOTXLOCXID WITH (NOLOCK) 
            LEFT JOIN V_PP_MoveTask TD3 ON (LOTXLOCXID.Storerkey = TD3.Storerkey
                                        AND LOTXLOCXID.Sku = TD3.Sku
                                        AND LOTXLOCXID.Lot = TD3.Lot
                                        AND LOTXLOCXID.Loc = TD3.FromLoc
                                        AND LOTXLOCXID.Id = TD3.FromID)
            WHERE LOTXLOCXID.Storerkey = @c_storerkey
            AND LOTXLOCXID.Lot = @c_lot
            AND LOTXLOCXID.Loc = @c_fromloc
            AND LOTXLOCXID.Id = @c_fromid
            --AND LOTXLOCXID.Qty-LOTXLOCXID.QtyAllocated-LOTXLOCXID.QtyPicked = ISNULL(TD3.Qty,0)

            IF @n_QtyPendingMove > 0 
            BEGIN 
               IF  @n_QtyAvailable = @n_QtyPendingMove 
               BEGIN
                  SET @n_continue = 3         
                  SET @n_err = 62082 
                  SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                      ': Full Inverntory qty are pending move in Task Manager queue. Partial Move is not allowed. (isp_TaskManagerMove)'
               END

               IF @n_QtyAvailable < @n_QtyPendingMove + @n_Qty
               BEGIN
                  SET @n_continue = 3         
                  SET @n_err = 62082 
                  SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+ 
                                + ': Qty to Move for Lot: N''' + ISNULL(RTRIM(@c_lot),'')  + ''', Loc: N''' + ISNULL(RTRIM(@c_fromloc),'') 
                                + ''', ID: ' + ISNULL(RTRIM(@c_fromid),'')
                                + ' is greater than availabe Qty. QtyAvailable: ' + CONVERT(VARCHAR(10),@n_QtyAvailable) 
                                + ', Total pending move in Task Manager queue: ' + CONVERT(VARCHAR(10),@n_QtyPendingMove) 
                                + '. (isp_TaskManagerMove)'
               END
            END
         END                  
      END
      --(Wan01) - END
   END

   --(Wan04) - START
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @c_SourceType = 'VAS'
      BEGIN
         SET @c_Jobkey   = SUBSTRING(@c_SourceKey,1,10)
         SET @c_JobLineNo= SUBSTRING(@c_SourceKey,11,5)

         SET @c_RefTaskkey = @c_TaskDetailKey
         SELECT @c_Tasktype = CASE WOOperation WHEN 'ASRS Pull' THEN 'VA'
                                               WHEN 'VAS Pick'  THEN 'VP'
                                               WHEN 'VAS Move'  THEN 'VM'
                                               WHEN 'VAS Move To Line' THEN 'VL' 
                                               WHEN 'Begin FG'  THEN 'FG'
                              END
               ,@c_TmpLoc   = ISNULL(RTRIM(FromLoc),'')
               ,@c_PullUOM  = @c_PickMethod   
         FROM WORKORDERJOBOPERATION WITH (NOLOCK)
         WHERE Jobkey = SUBSTRING(@c_SourceKey,1,10)
         AND   JobLine= SUBSTRING(@c_SourceKey,11,5)
 
         IF @c_Lot = ''
         BEGIN
            SELECT TOP 1 @c_Lot = Lot
            FROM LOTxLOCxID WITH (NOLOCK)
            WHERE Storerkey = @c_Storerkey
            AND   Sku       = @c_Sku
            AND   Loc       = @c_FromLoc
            AND   ID        = @c_FromID
         END

         SET @c_Packkey = ''
         SET @c_PackUOM3= ''
         SELECT @c_Packkey = PACK.Packkey
               ,@c_PackUOM3= PACK.PackUOM3
               ,@c_PullUOM = CASE WHEN @c_PullUOM = PACK.PackUOM4 THEN '1'
                                  WHEN @c_PullUOM = PACK.PackUOM1 THEN '2'
                                  WHEN @c_PullUOM = PACK.PackUOM2 THEN '3'
                                  ELSE '6'
                                  END
         FROM SKU WITH (NOLOCK)
         JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         WHERE Storerkey = @c_Storerkey
         AND   Sku       = @c_Sku

         IF (@c_PullUOM = '1' AND @c_MoveMethod <> 'FP') OR
            (@c_PullUOM <>'1' AND @c_MoveMethod =  'FP')
         BEGIN
            SET @n_continue = 3         
            SET @n_err = 62085 
            SET @c_ErrMsg = 'UnMatched MoveMehtod and PullUOM. (isp_TaskManagerMove)'
            GOTO QUIT_SP
         END
         /*
         IF @c_PullUOM = '1'
         BEGIN
            DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Storerkey
                  ,Sku
                  ,Lot
                  ,Qty
            FROM LOTxLOCxID WITH (NOLOCK)
            WHERE Loc = @c_FromLoc
            AND   ID  = @c_FromID
            AND   Qty > 0
         END
         ELSE
         BEGIN
            DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Storerkey
                  ,Sku
                  ,Lot
                  ,@n_Qty 
            FROM LOTxLOCxID WITH (NOLOCK)
            WHERE Lot = @c_Lot
            AND   Loc = @c_FromLoc
            AND   ID  = @c_FromID
            AND   Qty > 0
         END

         OPEN CUR_ID
         FETCH NEXT FROM CUR_ID INTO @c_Storerkey
                                    ,@c_Sku
                                    ,@c_Lot
                                    ,@n_Qty

         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)
         BEGIN
            SELECT @c_Packkey = Packkey
            FROM SKU WITH (NOLOCK) 
            WHERE Storerkey = @c_Storerkey
            AND   Sku = @c_Sku

            SELECT @c_PackUOM3 = PACKUOM3
            FROM PACK WITH (NOLOCK)
            WHERE Packkey = @c_Packkey

            SET @c_MoveRefKey = ''

            IF @c_PullUOM = '1'
            BEGIN
               SET @b_success = 1    
               EXECUTE nspg_getkey    
                     'MoveRefKey'    
                    , 10    
                    , @c_MoveRefKey       OUTPUT    
                    , @b_success          OUTPUT    
                    , @n_err              OUTPUT    
                    , @c_errmsg           OUTPUT 

               IF NOT @b_success = 1    
               BEGIN    
                  SET @n_continue = 3    
                  SET @n_err = 62090  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get MoveRefKey Failed. (isp_TaskManagerMove)' 
               END 

               IF @n_continue = 1 OR @n_continue = 2
               BEGIN
                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET MoveRefKey = @c_MoveRefKey
                     ,EditWho    = SUSER_NAME()
                     ,EditDate   = GETDATE()
                     ,Trafficcop = NULL
                  WHERE LOT = @c_Lot
                  AND   Loc = @c_FromLoc
                  AND   ID  = @c_FromID
                  AND   Status < '9'
                  AND   ShipFlag <> 'Y'

                  SET @n_err = @@ERROR 
                  IF @n_err <> 0    
                  BEGIN  
                     SET @n_continue = 3    
                     SET @n_err = 62095   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table PICKDETIAL. (isp_TaskManagerMove)' 
                  END 
               END
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               EXEC nspItrnAddMove
                      NULL
                  ,   @c_StorerKey
                  ,   @c_Sku
                  ,   @c_Lot
                  ,   @c_FromLoc
                  ,   @c_FromID
                  ,   @c_TmpLoc
                  ,   @c_FromID
                  ,   ''         --Status
                  ,   ''         --lottable01
                  ,   ''         --lottable02
                  ,   ''         --lottable03
                  ,   NULL       --lottable04
                  ,   NULL       --lottable05
                  ,   ''         --lottable06
                  ,   ''         --lottable07
                  ,   ''         --lottable08
                  ,   ''         --lottable09
                  ,   ''         --lottable10
                  ,   ''         --lottable11
                  ,   ''         --lottable12
                  ,   NULL       --lottable13
                  ,   NULL       --lottable14
                  ,   NULL       --lottable15
                  ,   0
                  ,   0
                  ,   @n_Qty
                  ,   0
                  ,   0.00
                  ,   0.00
                  ,   0.00
                  ,   0.00
                  ,   0.00
                  ,   @c_SourceKey
                  ,   'isp_WOJobInvReserve'
                  ,   @c_PackKey
                  ,   @c_PackUOM3
                  ,   1
                  ,   NULL
                  ,   ''
                  ,   @b_Success        OUTPUT
                  ,   @n_err            OUTPUT
                  ,   @c_errmsg         OUTPUT
                  ,   @c_MoveRefKey     = @c_MoveRefKey 

               IF @n_err <> 0
               BEGIN
                  SET @n_continue= 3
                  SET @n_err     = 62100  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error Moving Stock to Virtual Location. (isp_TaskManagerMove)' 
               END
            END

            FETCH NEXT FROM CUR_ID INTO @c_Storerkey
                                       ,@c_Sku
                                       ,@c_Lot
                                       ,@n_Qty
         END 
         CLOSE CUR_ID
         DEALLOCATE CUR_ID
         */
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            INSERT INTO WorkOrderJobMove
                        (  JobKey
                        ,  JobLine
                        ,  Storerkey
                        ,  Sku
                        ,  Packkey
                        ,  UOM
                        ,  Lot
                        ,  FromLoc
                        ,  ToLoc
                        ,  ID
                        ,  Qty
                        ,  Status
                        ,  PickMethod
                        )
                  VALUES(  @c_JobKey
                        ,  @c_JobLineNo
                        ,  @c_Storerkey
                        ,  @c_Sku
                        ,  @c_PackKey
                        ,  @c_PackUOM3
                        ,  @c_Lot
                        ,  @c_FromLoc  
                        ,  @c_TmpLoc
                        ,  @c_FromID
                        ,  @n_Qty
                        , '0'
                        ,  @c_PullUOM
                        )

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 62105  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error Creating WorkOrderJobMove. (isp_TaskManagerMove)' 
            END
         END
         /*
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
            SET QtyReserved = QtyReserved + @n_Qty
               ,EditWho     = SUSER_NAME()
               ,EditDate    = GETDATE()
            WHERE JobKey = @c_JobKey
            AND   JobLine = @c_JobLineNo

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 62110  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Fail On WORKORDERJOBOPERATION. (isp_TaskManagerMove)' 
            END
         END
         */
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            EXECUTE isp_VASJobGenTasks_Wrapper
                     @c_JobKey    = @c_JobKey
                  ,  @c_JobLineNo = @c_JobLineNo
                  ,  @b_Success   = @b_Success  OUTPUT
                  ,  @n_Err       = @n_Err      OUTPUT
                  ,  @c_errmsg    = @c_errmsg   OUTPUT

            IF @b_Success <> 1
            BEGIN
               SET @n_Continue= 3  
               SET @n_err     = 62115
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error Executing isp_VASJobGenTasks_Wrapper. (isp_TaskManagerMove)'
            END
         END
         GOTO QUIT_SP
      END
   END
   --(Wan04) - END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      EXECUTE nspg_getkey
      'TaskDetailKey'
      , 10
      , @c_taskdetailkey OUTPUT
      , @b_success OUTPUT
      , @n_err OUTPUT
      , @c_errmsg OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3         
         SELECT @n_err = 62080
         SELECT @c_errmsg = 'isp_TaskManagerMove: ' + dbo.fnc_RTrim(@c_errmsg)
      END
   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @c_sku = 'MIXED_SKU'
         SET @c_sku = ''

      SELECT @c_logicalfromloc = ISNULL(RTRIM(LOC.LogicalLocation),'')
      FROM LOC (NOLOCK)
      WHERE LOC.Loc = @c_fromloc

      SELECT @c_logicaltoloc = ISNULL(RTRIM(LOC.LogicalLocation),'')
      FROM LOC (NOLOCK)
      WHERE LOC.Loc = @c_toloc   	  
      
      SELECT TOP 1 @c_Areakey = AREADETAIL.Areakey
      FROM LOC (NOLOCK)
      JOIN AREADETAIL ON (LOC.PutawayZone = AREADETAIL.PutawayZone)
      WHERE LOC.Loc = @c_fromloc
   END 
   
   IF @n_continue=1 OR @n_continue=2
   BEGIN
--(Wan04) - START
      --(Wan02) - START
--      IF @c_SourceType = 'VAS'
--      BEGIN
--         SET @c_RefTaskkey = @c_TaskDetailKey
--         SELECT @c_Tasktype = CASE WOOperation WHEN 'ASRS Pull' THEN 'VA'
--                                               WHEN 'VAS Pick'  THEN 'VP'
--                                               WHEN 'VAS Move'  THEN 'VM'
--                                               WHEN 'VAS Move To Line' THEN 'VL' 
--                                               WHEN 'Begin FG'  THEN 'FG'
--                              END
--               ,@c_ToLoc       = ISNULL(RTRIM(ToLoc),'')
--
--         FROM WORKORDERJOBOPERATION WITH (NOLOCK)
--         WHERE Jobkey = SUBSTRING(@c_SourceKey,1,10)
--         AND   JobLine= SUBSTRING(@c_SourceKey,11,5)
-- 
--         SET @c_Lot = ''
--         SELECT TOP 1 @c_Lot = Lot
--         FROM LOTxLOCxID WITH (NOLOCK)
--         WHERE Storerkey = @c_Storerkey
--         AND   Sku       = @c_Sku
--         AND   Loc       = @c_FromLoc
--         AND   ID        = @c_FromID
--
--         SELECT @c_Priority = Priority
--         FROM WORKORDERJOBDETAIL WITH (NOLOCK)
--         WHERE JobKey = SUBSTRING(@c_SourceKey,1,10)
--      END
      --(Wan02) - END
--(Wan04) - END
      BEGIN TRANSACTION
      
      INSERT TASKDETAIL
      (
        TaskDetailKey
       ,TaskType
       ,Storerkey
       ,Sku
       ,Lot                                                                                        --(Wan01)
       ,UOM
       ,UOMQty
       ,Qty
       ,FromLoc
       ,FromID
       ,ToLoc
       ,ToId
       ,PickMethod                                                                                 --(Wan01)
       ,SourceType
       ,SourceKey
       ,Priority
       ,SourcePriority
       ,Status
       ,LogicalFromLoc
       ,LogicalToLoc
       ,RefTaskKey                                                                                 --(Wan01)
       ,Areakey
       ,SystemQty
      )
      VALUES
      (
        @c_taskdetailkey
       --,'MV' --Tasktype                                                                          --(Wan02)
       ,@c_TaskType                                                                                --(Wan02)
       ,@c_Storerkey
       ,@c_sku
       ,@c_Lot                                                                                     --(Wan01)
       ,''	-- UOM,
       ,0	-- UOMQty,
       ,@n_qty
       ,@c_fromloc
       ,@c_fromid
       ,@c_toloc
       ,@c_toid
       ,@c_MoveMethod                                                                              --(Wan01)
       --,'isp_TaskManagerMove' --Sourcetype                                                       --(Wan02)                                             
       --,'' --Sourcekey                                                                           --(Wan02)
       --,'5' -- Priority                                                                          --(Wan02)
       --,'9' -- Sourcepriority                                                                    --(Wan02)
       ,@c_SourceType                                                                              --(Wan02)
       ,@c_SourceKey                                                                               --(Wan02)
       ,@c_Priority                                                                                --(Wan02)
       ,@c_SourcePriority                                                                          --(Wan02)
       ,'0' -- Status
       ,@c_logicalfromloc
       ,@c_logicaltoloc
       ,@c_RefTaskkey                                                                              --(Wan01)
       ,@c_Areakey
       ,@n_Qty
      )  
      
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err),@n_err = 62081     
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                ': Insert Into TaskDetail Failed (isp_TaskManagerMove)' 
               +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg+' ) '
      END
   END 
      
QUIT_SP:    --(Wan04)
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0   
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_TaskManagerMove'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END   

GO