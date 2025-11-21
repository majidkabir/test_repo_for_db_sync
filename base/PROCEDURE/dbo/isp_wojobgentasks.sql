SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store Procedure: isp_WOJobGenTasks                                      */
/* Creation Date: 11-AUG-2015                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#315701 - Project Merlion - VAP Release Task generates      */
/*        : WCS Message                                                    */
/*                                                                         */
/* Called By:  isp_VASJobGenTasks_Wrapper                                  */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver.  Purposes                                     */
/* 11-JAN-2016 Wan01    1.1   SOS#315603 - Project Merlion - VAP SKU       */
/*                            Reservation Strategy - MixSku in 1 Pallet    */
/*                            enhancement                                  */	     
/***************************************************************************/
CREATE PROC [dbo].[isp_WOJobGenTasks]
           @c_JobKey          NVARCHAR(10) 
         , @c_JobLineNo       NVARCHAR(5)  = ''
         , @b_Success         INT            OUTPUT            
         , @n_err             INT            OUTPUT          
         , @c_errmsg          NVARCHAR(255)  OUTPUT  
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue           INT                     
         , @n_StartTCnt          INT            -- Holds the current transaction count    

   DECLARE @c_TaskdetailKey      NVARCHAR(10) 
         , @c_GroupKey           NVARCHAR(10) 
         , @c_TaskType           NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_Lot                NVARCHAR(10)
         , @c_FromLoc            NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
         , @c_FinalLoc           NVARCHAR(10)
         , @c_ID                 NVARCHAR(18)
         , @c_LogicalFromLoc     NVARCHAR(10)
         , @c_LogicalToLoc       NVARCHAR(10)
         , @c_Priority           NVARCHAR(10)
         , @c_SourcePriority     NVARCHAR(10)
         , @c_SourceKey          NVARCHAR(20)
         , @c_SourceType         NVARCHAR(30)
         , @c_PickDetailKey      NVARCHAR(10)
         , @c_Orderkey           NVARCHAR(10)
         , @c_OrderLineNumber    NVARCHAR(5)
         , @c_Status             NVARCHAR(10)
         , @c_StatusMsg          NVARCHAR(4000)
         , @c_RefJobLineNo       NVARCHAR(5) 
         , @n_StepQty            INT
         , @n_MoveQty            INT
         , @n_Qty                INT
         , @n_QtyToProcess       INT
         , @n_PendingTasks       INT

   DECLARE @c_TempStaging        NVARCHAR(10)
         , @c_Facility           NVARCHAR(5)
         , @c_WorkOrderkey       NVARCHAR(10)
         , @c_MasterWorkOrder    NVARCHAR(50)
         , @c_WorkOrderName      NVARCHAR(50)
         , @c_WorkStation        NVARCHAR(10)
         , @c_Sequence           NVARCHAR(10)
         , @n_QtyJob             INT
 
   DECLARE @c_GenJobLineNo       NVARCHAR(10)
         , @c_MinStep            NVARCHAR(5)
         , @c_WOOperation        NVARCHAR(30)
         , @c_LocationCategory   NVARCHAR(10)
         , @c_CopyInputFromStep  NVARCHAR(5)
         , @c_PullUOM            NVARCHAR(10)
         , @c_TmpLoc             NVARCHAR(10)
         , @n_WOMoveKey          INT


   SET @n_Continue         = 1
   SET @n_StartTCnt        = @@TRANCOUNT  
   SET @b_Success          = 1
   SET @n_Err              = 0
   SET @c_errmsg           = ''  

   SET @c_TaskdetailKey    = ''
   SET @c_TaskType         = ''
   SET @c_Storerkey        = ''
   SET @c_Sku              = ''
   SET @c_Lot              = ''
   SET @c_FromLoc          = ''
   SET @c_ToLoc            = ''
   SET @c_FinalLoc         = ''
   SET @c_ID               = ''
   SET @c_LogicalFromLoc   = ''
   SET @c_LogicalToLoc     = ''
   SET @c_Priority         = ''
   SET @c_SourcePriority   = ''
   SET @c_SourceKey        = ''
   SET @c_SourceType       = 'VAS'
   SET @c_PickDetailKey    = ''
   SET @c_Orderkey         = ''
   SET @c_OrderLineNumber  = ''
   SET @c_Status           = 'S'
   SET @c_StatusMsg        = ''

   SET @c_MinStep          = ''
   SET @c_WOOperation      = ''  
   SET @c_CopyInputFromStep= '' 

   SET @c_MasterWorkOrder  = ''
   SET @c_WorkOrderName    = ''
   
   SELECT @c_Priority = Priority
         ,@c_TempStaging = ISNULL(RTRIM(TempStaging),'')
   FROM WORKORDERJOBDETAIL WITH (NOLOCK)
   WHERE JobKey = @c_JobKey

   SET @c_GenJobLineNo = @c_JobLineNo

   BEGIN TRAN
   DECLARE CUR_WOJO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(JobLine),'')
         ,ISNULL(RTRIM(MinStep),'')
         ,ISNULL(RTRIM(WOOperation),'')
         ,ISNULL(RTRIM(CopyInputFromStep),'')
         ,ISNULL(RTRIM(FromLoc),'')
         ,ISNULL(RTRIM(ToLoc),'')
         ,ISNULL(RTRIM(Instructions),'')
   FROM WORKORDERJOBOPERATION  WOJO WITH (NOLOCK)
   WHERE Jobkey = @c_jobKey
   ORDER BY CASE WOOperation  WHEN 'VAS Move To Line' THEN 8
                              WHEN 'VAS Move'  THEN 7
                              WHEN 'VAS Pick'  THEN 2
                              WHEN 'ASRS Pull' THEN 1
                              ELSE 9
                              END
          , ISNULL(RTRIM(JobLine),'')

   OPEN CUR_WOJO
   FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
                              ,  @c_MinStep
                              ,  @c_WOOperation
                              ,  @c_CopyInputFromStep
                              ,  @c_FromLoc
                              ,  @c_ToLoc
                              ,  @c_StatusMsg

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      SET @c_Sourcekey = CONVERT(NCHAR(10), @c_JobKey) + CONVERT(NCHAR(5), @c_JobLineNo)

      SET @c_TaskType = CASE @c_WOOperation WHEN 'ASRS Pull' THEN 'VA'
                                            WHEN 'VAS Pick'  THEN 'VP'
                                            WHEN 'VAS Move'  THEN 'VM'
                                            WHEN 'VAS Move To Line' THEN 'VL' 
                                            WHEN 'Begin FG'  THEN 'FG'
                        END

      IF @c_TaskType IN ('VA','VP')
      BEGIN
         DECLARE CUR_WOJM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT WOJM.WOMoveKey
               ,WOJM.Storerkey
               ,WOJM.Sku
               ,WOJM.Lot
               ,WOJM.FromLoc
               ,WOJM.ToLoc
               ,WOJM.ID
               ,WOJM.Qty
               ,WOJM.PickMethod
         FROM WORKORDERJOBMOVE WOJM  WITH (NOLOCK)
         WHERE WOJM.JobKey = @c_JobKey
         AND   WOJM.JobLine= @c_JobLineNo
         AND   WOJM.Qty > 0
         ORDER BY WOJM.WOMoveKey

         OPEN CUR_WOJM

         FETCH NEXT FROM CUR_WOJM INTO @n_WOMoveKey
                                    ,  @c_Storerkey
                                    ,  @c_Sku
                                    ,  @c_Lot
                                    ,  @c_FromLoc
                                    ,  @c_TmpLoc
                                    ,  @c_ID
                                    ,  @n_Qty
                                    ,  @c_PullUOM
       
         WHILE @@FETCH_STATUS <> -1  
         BEGIN

            IF @c_PullUOM = '1' 
            BEGIN
               SET @c_Sku = ''
               SET @c_Lot = ''

               SELECT @n_Qty = ISNULL(SUM(Qty),0)
                     ,@c_Sku = CASE WHEN COUNT (DISTINCT Sku) > 1 THEN 'MIXED_SKU' ELSE ISNULL(MAX(Sku),'') END  --(Wan01) 
               FROM WORKORDERJOBMOVE WITH (NOLOCK)
               WHERE JobKey = @c_JobKey
               AND   ID     = @c_ID
               
               IF @c_TaskType = 'VA'
               BEGIN 
                  SET @c_LocationCategory = 'ASRSOUTST'

                  --SELECT @c_LocationCategory = LocationCategory
                  --FROM LOC WITH (NOLOCK) 
                  --WHERE Loc = @c_TmpLoc

                  SET @c_FinalLoc = @c_ToLoc
                  SET @c_ToLoc = ''
                  SET @c_LogicalToLoc = ''

                  SELECT @c_ToLoc = OUTLOC.Loc 
                        ,@c_LogicalToLoc = OUTLOC.Logicallocation  
                  FROM LOC STGLOC WITH (NOLOCK) 
                  JOIN LOC OUTLOC WITH (NOLOCK) ON (STGLOC.PutawayZone = OUTLOC.PutawayZone) 
                                                AND(OUTLOC.LocationCategory = @c_LocationCategory)
                  WHERE STGLOC.Loc = @c_FinalLoc 

                  SET @c_TaskType = 'ASRSMV'
               END
            END

            IF EXISTS ( SELECT 1 
                        FROM  JOBTASKLOOKUP WITH (NOLOCK)
                        WHERE JobKey  = @c_JobKey
                        AND   JobLine = @c_JobLineNo
                        AND   WOMoveKey = @n_WOMoveKey
                      )
            BEGIN
               GOTO NEXT_INV
            END

            SET @c_TaskDetailkey = ''
            SET @b_success = 0
            EXECUTE nspg_getkey
                   'TASKDETAILKEY'
                  , 10
                  , @c_TaskDetailKey   OUTPUT
                  , @b_success         OUTPUT
                  , @n_err             OUTPUT
                  , @c_ErrMsg          OUTPUT

            IF @b_success = 0 
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63705  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error Getting TaskDetailKey. (isp_WOJobGenTasks)' 

               GOTO QUIT_SP
            END

            SET @c_LogicalFromLoc = ''
            SELECT @c_LogicalFromLoc = Logicallocation
            FROM LOC WITH (NOLOCK)  
            WHERE Loc = @c_FromLoc

            SET @c_LogicalToLoc = ''
            SELECT @c_LogicalToLoc = Logicallocation
            FROM LOC WITH (NOLOCK)  
            WHERE Loc = @c_ToLoc

            INSERT INTO TASKDETAIL
               (TaskDetailkey
               ,TaskType
               ,Storerkey
               ,Sku
               ,Lot
               ,FromLoc
               ,LogicalFromLoc
               ,ToLoc
               ,LogicalToLoc
               ,FromID
               ,Qty
               ,Priority
               ,SourcePriority
               ,Sourcekey
               ,SourceType
               ,PickDetailKey
               ,Orderkey
               ,OrderLineNumber
               ,Status
               ,StatusMsg
               ,FinalLoc
               ,RefTaskKey
               ,GroupKey
               )
            VALUES 
               (@c_TaskDetailkey
               ,@c_TaskType
               ,@c_Storerkey
               ,@c_Sku
               ,@c_Lot
               ,@c_FromLoc
               ,@c_LogicalFromLoc
               ,@c_ToLoc
               ,@c_LogicalToLoc
               ,@c_ID
               ,@n_Qty
               ,@c_Priority
               ,''
               ,@c_Sourcekey
               ,@c_SourceType
               ,CONVERT(NVARCHAR(10),@n_WOMoveKey)
               ,@c_Orderkey
               ,@c_OrderLineNumber
               ,@c_Status
               ,@c_StatusMsg
               ,@c_FinalLoc 
               ,@c_TaskDetailkey
               ,@c_TaskDetailkey
               )

               SET @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SET @n_continue= 3
                  SET @n_err     = 63710   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': INSERT Failed On Table TASKDETAIL. (isp_WOJobGenTasks)' 
                  GOTO QUIT_SP
               END 

            --(Wan01) - START
            IF @c_PullUOM = 1  
            BEGIN
               INSERT INTO JOBTASKLOOKUP ( JobKey, JobLine, WOMoveKey, Taskdetailkey )
               SELECT @c_JobKey, JobLine, WOMoveKey, @c_Taskdetailkey
               FROM WORKORDERJOBMOVE WITH (NOLOCK)
               WHERE JobKey = @c_JobKey
               AND   ID = @c_ID

            END
            ELSE
            BEGIN 
               INSERT INTO JOBTASKLOOKUP ( JobKey, JobLine, WOMoveKey, Taskdetailkey )
               VALUES (@c_JobKey, @c_JobLineNo, @n_WOMoveKey, @c_Taskdetailkey)
            END

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63715   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': INSERT Failed Into Table JOBTASKLOOKUP. (isp_WOJobGenTasks)' 
               GOTO QUIT_SP
            END 
            --(Wan01) - END

            NEXT_INV:
            
            FETCH NEXT FROM CUR_WOJM INTO @n_WOMoveKey
                                       ,  @c_Storerkey
                                       ,  @c_Sku
                                       ,  @c_Lot
                                       ,  @c_FromLoc
                                       ,  @c_TmpLoc
                                       ,  @c_ID
                                       ,  @n_Qty
                                       ,  @c_PullUOM
         END
         CLOSE CUR_WOJM
         DEALLOCATE CUR_WOJM
      END
      ELSE IF @c_TaskType IN ('VM','VL') 
      BEGIN
         SET @c_MasterWorkOrder = ''
         SET @c_WorkOrderName   = ''

         DECLARE CUR_MWO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT DISTINCT 
                MasterWorkOrder = MasterWorkOrder
            ,   WorkOrderName   = WorkOrderName
         FROM VASREFKEYLOOKUP WITH (NOLOCK)
         WHERE JobKey = @c_JobKey
         AND   JobLine= @c_JobLineNo

         OPEN CUR_MWO

         FETCH NEXT FROM CUR_MWO INTO @c_MasterWorkOrder
                                   ,  @c_WorkOrderName

         WHILE @@FETCH_STATUS <> -1  
         BEGIN
            DECLARE CUR_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TLKUP.Taskdetailkey
                  ,WOJM.WOMoveKey
                  ,WOJM.JobLine
                  ,WOJM.Storerkey
                  ,WOJM.Sku
                  ,WOJM.Lot
                  ,WOJM.ID
                  ,WOJM.Qty
                  ,WOJM.PickMethod
            FROM WORKORDERJOBMOVE WOJM WITH (NOLOCK)
            JOIN VASREFKEYLOOKUP  LKUP WITH (NOLOCK) ON (WOJM.JobKey = LKUP.JobKey)
                                                     AND(WOJM.JobLine= LKUP.JobLine) 
            JOIN JOBTASKLOOKUP   TLKUP WITH (NOLOCK) ON (WOJM.JobKey = TLKUP.JobKey)
                                                     AND(WOJM.JobLine= TLKUP.JobLine)
                                                     AND(WOJM.WOMoveKey= TLKUP.WOMoveKey) 
            WHERE LKUP.JobKey = @c_JobKey
            AND   LKUP.MasterWorkOrder = @c_MasterWorkOrder
            AND   LKUP.WorkOrderName   = @c_WorkOrderName
            AND   LKUP.StepNumber      = @c_CopyInputFromStep
            AND   WOJM.Qty > 0
            ORDER BY WOJM.WOMoveKey

            OPEN CUR_TASK
   
            FETCH NEXT FROM CUR_TASK INTO @c_GroupKey
                                       ,  @c_PickDetailKey
                                       ,  @c_RefJobLineNo
                                       ,  @c_Storerkey
                                       ,  @c_Sku
                                       ,  @c_Lot
                                       ,  @c_ID
                                       ,  @n_Qty
                                       ,  @c_PullUOM
          
            WHILE @@FETCH_STATUS <> -1  
            BEGIN
               IF EXISTS ( SELECT 1
                           FROM  JOBTASKLOOKUP WITH (NOLOCK)
                           WHERE JobKey  = @c_JobKey
                           AND   JobLine = @c_JobLineNo
                           AND   WOMoveKey = @c_PickDetailKey)
               BEGIN
                  GOTO NEXT_TASK
               END

               IF @c_PullUOM = '1'
               BEGIN
                  IF EXISTS ( SELECT 1
                              FROM JOBTASKLOOKUP TKLUP WITH (NOLOCK)
                              JOIN TASKDETAIL    TD    WITH (NOLOCK) ON (TKLUP.Taskdetailkey = TD.Taskdetailkey)
                              WHERE TKLUP.JobKey = @c_JobKey
                              AND   TKLUP.JobLine= @c_JobLineNo
                              AND   TD.fromID = @c_ID
                            )
                  BEGIN
                     GOTO NEXT_TASK
                  END

                  SELECT @n_Qty = ISNULL(SUM(Qty),0)
                  FROM WORKORDERJOBMOVE WITH (NOLOCK)
                  WHERE JobKey = @c_JobKey
                  AND   JobLine= @c_RefJobLineNo
                  AND   ID     = @c_ID

                  SET @c_Lot = ''
               END

               SET @b_success = 0
               EXECUTE nspg_getkey
                      'TASKDETAILKEY'
                     , 10
                     , @c_TaskDetailKey   OUTPUT
                     , @b_success         OUTPUT
                     , @n_err             OUTPUT
                     , @c_ErrMsg          OUTPUT

               IF @b_success = 0 
               BEGIN
                  SET @n_continue= 3
                  SET @n_err     = 63720  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error Getting TaskDetailKey. (isp_WOJobGenTasks)' 

                  GOTO QUIT_SP
               END
               
               INSERT INTO TASKDETAIL
                  (TaskDetailkey
                  ,TaskType
                  ,Storerkey
                  ,Sku
                  ,Lot
                  ,FromLoc
                  ,ToLoc
                  ,FromID
                  ,Qty
                  ,Priority
                  ,SourcePriority
                  ,Sourcekey
                  ,SourceType
                  ,PickDetailKey
                  ,Orderkey
                  ,OrderLineNumber
                  ,Status
                  ,StatusMsg
                  ,RefTaskKey
                  ,GroupKey
                  )
               VALUES 
                  (@c_TaskDetailkey
                  ,@c_TaskType
                  ,@c_Storerkey
                  ,@c_Sku
                  ,@c_Lot
                  ,@c_FromLoc
                  ,@c_ToLoc
                  ,@c_ID
                  ,@n_Qty
                  ,@c_Priority
                  ,''
                  ,@c_Sourcekey
                  ,@c_SourceType
                  ,@c_PickDetailkey
                  ,@c_Orderkey
                  ,@c_OrderLineNumber
                  ,@c_Status
                  ,@c_StatusMsg 
                  ,@c_GroupKey 
                  ,@c_GroupKey             --Should use GroupKey
                  )

               SET @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SET @n_continue= 3
                  SET @n_err     = 637125   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': INSERT Failed On Table TASKDETAIL. (isp_WOJobGenTasks)' 
                  GOTO QUIT_SP
               END 
        
               NEXT_TASK:

               INSERT INTO JOBTASKLOOKUP ( JobKey, JobLine, WOMoveKey, Taskdetailkey )
               VALUES (@c_JobKey, @c_JobLineNo, @c_PickDetailKey, @c_Taskdetailkey)
            
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SET @n_continue= 3
                  SET @n_err     = 63730   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': INSERT Failed Into Table JOBTASKLOOKUP. (isp_WOJobGenTasks)' 
                  GOTO QUIT_SP
               END 

               FETCH NEXT FROM CUR_TASK INTO @c_GroupKey
                                          ,  @c_PickDetailKey
                                          ,  @c_RefJobLineNo
                                          ,  @c_Storerkey
                                          ,  @c_Sku
                                          ,  @c_Lot
                                          ,  @c_ID
                                          ,  @n_Qty
                                          ,  @c_PullUOM
            END
            CLOSE CUR_TASK
            DEALLOCATE CUR_TASK

            FETCH NEXT FROM CUR_MWO INTO @c_MasterWorkOrder
                                      ,  @c_WorkOrderName

         END
         CLOSE CUR_MWO
         DEALLOCATE CUR_MWO
      END
      ELSE IF @c_TaskType = 'FG' AND @c_GenJobLineNo = ''
      BEGIN
         DECLARE CUR_WOJ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT Facility  = ISNULL(RTRIM(WOJ.Facility),'')
               ,WorkOrderkey = ISNULL(RTRIM(WOJ.WorkOrderkey),'')
               ,WorkOrderName= ISNULL(RTRIM(WOJ.WorkOrderName),'')
               ,Sequence     = ISNULL(RTRIM(WOJ.Sequence),'')
               ,WorkStation  = ISNULL(RTRIM(WOJ.WorkStation),'')
               ,QtyJob       = ISNULL(RTRIM(WOJ.QtyJob),'')
         FROM WORKORDERJOB WOJ  WITH (NOLOCK)
         WHERE WOJ.JobKey = @c_JobKey
         AND   WOJ.QtyJob > 0
         ORDER BY ISNULL(RTRIM(WOJ.WorkOrderkey),'')

         OPEN CUR_WOJ

         FETCH NEXT FROM CUR_WOJ INTO @c_Facility
                                    , @c_WorkOrderkey
                                    , @c_WorkOrderName
                                    , @c_Sequence
                                    , @c_WorkStation
                                    , @n_QtyJob
         WHILE @@FETCH_STATUS <> -1  
         BEGIN
            IF EXISTS ( SELECT 1 
                        FROM  JOBTASKLOOKUP WITH (NOLOCK)
                        WHERE JobKey  = @c_JobKey
                        AND   JobLine = @c_JobLineNo
                        AND   WorkOrderKey = @c_WorkOrderkey
                        )                    
            BEGIN
               GOTO NEXT_WO
            END

            SET @c_FromLoc = ''
            SELECT TOP 1 @c_FromLoc = ISNULL(Location,'')
            FROM WORKSTATIONLOC WITH (NOLOCK)
            WHERE Facility = @c_Facility
            AND   WorkStation = @c_WorkStation
            AND   LocType = 'INLOC' 

            SET @c_LogicalFromLoc = ''
            SELECT @c_LogicalFromLoc = Logicallocation
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_FromLoc

            SET @c_LogicalToLoc = ''
            SELECT @c_LogicalToLoc = Logicallocation
            FROM LOC WITH (NOLOCK)
            WHERE Loc = @c_TempStaging

            SET @b_success = 0
            EXECUTE nspg_getkey
                   'TASKDETAILKEY'
                  , 10
                  , @c_TaskDetailKey   OUTPUT
                  , @b_success         OUTPUT
                  , @n_err             OUTPUT
                  , @c_ErrMsg          OUTPUT

            IF @b_success = 0 
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63735  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error Getting TaskDetailKey. (isp_WOJobGenTasks)' 

               GOTO QUIT_SP
            END

            INSERT INTO TASKDETAIL
               (TaskDetailkey
               ,TaskType
               ,Storerkey
               ,Sku
               ,Lot
               ,FromLoc
               ,LogicalFromLoc
               ,ToLoc
               ,LogicalToLoc
               ,FromID
               ,Qty
               ,Priority
               ,SourcePriority
               ,Sourcekey
               ,SourceType
               ,PickDetailKey
               ,Orderkey
               ,OrderLineNumber
               ,Status
               ,StatusMsg
               ,GroupKey
               )
            VALUES(
                @c_TaskDetailkey
               ,@c_TaskType
               ,''
               ,@c_WorkOrderName
               ,''
               ,@c_FromLoc
               ,@c_LogicalFromLoc
               ,@c_TempStaging
               ,@c_LogicalToLoc 
               ,''
               ,@n_QtyJob
               ,@c_Priority
               ,@c_Sequence
               ,@c_SourceKey
               ,@c_SourceType
               ,''
               ,@c_WorkOrderkey
               ,@c_MinStep
               ,@c_Status
               ,@c_StatusMsg
               ,@c_TaskDetailKey
               )
   
            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63740   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': INSERT Failed On Table TASKDETAIL. (isp_WOJobGenTasks)' 
               GOTO QUIT_SP
            END 

            INSERT INTO JOBTASKLOOKUP ( JobKey, JobLine, Taskdetailkey, WorkOrderkey )
            VALUES (@c_JobKey, @c_JobLineNo, @c_Taskdetailkey, @c_WorkOrderkey)
         
            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63745   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': INSERT Failed Into Table JOBTASKLOOKUP. (isp_WOJobGenTasks)' 
               GOTO QUIT_SP
            END 

            NEXT_WO:
            FETCH NEXT FROM CUR_WOJ INTO @c_Facility
                                       , @c_WorkOrderkey
                                       , @c_WorkOrderName
                                       , @c_Sequence
                                       , @c_WorkStation
                                       , @n_QtyJob
         END
         CLOSE CUR_WOJ
         DEALLOCATE CUR_WOJ
      END
  
      SET @n_QtyToProcess = 0
      SET @n_PendingTasks = 0
      SELECT @n_QtyToProcess = ISNULL(SUM(TD.Qty),0)
            ,@n_PendingTasks = ISNULL(COUNT(1),0)
      FROM TASKDETAIL       TD   WITH (NOLOCK)  
      WHERE TD.SourceType = @c_SourceType
      AND   TD.Status = 'S'
      AND   EXISTS( SELECT 1 FROM JOBTASKLOOKUP   TLKUP WITH (NOLOCK)
                    WHERE TLKUP.TaskDetailkey = TD.TaskDetailKey
                    AND   TLKUP.JobKey = @c_JobKey
                    AND   TLKUP.JobLine= @c_JobLineNo
                  )

      UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
      SET   QtyToProcess = @n_QtyToProcess
         ,  PendingTasks = @n_PendingTasks
         ,  EditWho     = SUSER_NAME()
         ,  EditDate    = GETDATE()
      WHERE JobKey = @c_Jobkey
      AND   JobLine= @c_JobLineNo

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63750   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (isp_WOJobGenTasks)' 
         GOTO QUIT_SP
      END 
    
      FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
                                 ,  @c_MinStep
                                 ,  @c_WOOperation
                                 ,  @c_CopyInputFromStep
                                 ,  @c_FromLoc
                                 ,  @c_ToLoc
                                 ,  @c_StatusMsg
   END 
   CLOSE CUR_WOJO
   DEALLOCATE CUR_WOJO

   QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_WOJO') in (0 , 1)  
   BEGIN
      CLOSE CUR_WOJO
      DEALLOCATE CUR_WOJO
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_WOJ') in (0 , 1)  
   BEGIN
      CLOSE CUR_WOJ 
      DEALLOCATE CUR_WOJ 
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_WOJM') in (0 , 1)  
   BEGIN
      CLOSE CUR_WOJM
      DEALLOCATE CUR_WOJM
   END


   IF CURSOR_STATUS( 'LOCAL', 'CUR_MWO') in (0 , 1)  
   BEGIN
      CLOSE CUR_MWO 
      DEALLOCATE CUR_MWO 
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_TASK') in (0 , 1)  
   BEGIN
      CLOSE CUR_TASK 
      DEALLOCATE CUR_TASK 
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_WOJobGenTasks'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END

GO