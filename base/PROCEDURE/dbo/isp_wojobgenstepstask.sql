SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: isp_WOJobGenStepsTask                                  */
/* Creation Date: 18-Dec-2012                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Generate Work Order Job Tasks for step                        */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/***************************************************************************/
CREATE PROC [dbo].[isp_WOJobGenStepsTask]
           @c_TaskdetailKey   NVARCHAR(10) 
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

   DECLARE @c_NewTaskDetailKey   NVARCHAR(10)
         , @c_TaskType           NVARCHAR(10)
         , @c_FromLoc            NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
         , @c_Priority           NVARCHAR(10)
         , @c_SourceKey          NVARCHAR(20)
         , @c_SourceType         NVARCHAR(30)
         , @c_Status             NVARCHAR(10)

   DECLARE @c_JobKey             NVARCHAR(10)
         , @c_JobLineNo          NVARCHAR(5)
         , @c_WOOperation        NVARCHAR(30)


   DECLARE @n_SeqNo              INT

   SET @n_Continue         = 1
   SET @n_StartTCnt        = @@TRANCOUNT  
   SET @b_Success          = 1
   SET @n_Err              = 0
   SET @c_errmsg           = ''  

   SET @c_NewTaskDetailKey = ''
   SET @c_TaskType         = ''
   SET @c_FromLoc          = ''
   SET @c_ToLoc            = ''
   SET @c_Priority         = ''
   SET @c_SourceKey        = ''
   SET @c_SourceType       = 'VAS'
   SET @c_Status           = 'S'

   SET @c_JobKey           = ''
   SET @c_JobLineNo        = ''
   SET @c_WOOperation      = ''  


   SELECT @c_JobKey    = SUBSTRING(Sourcekey,1,10)
         ,@c_JobLineNo = SUBSTRING(Sourcekey,11,5) 
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE TaskDetailKey = @c_TaskDetailkey

   SELECT @c_Priority = Priority
   FROM WORKORDERJOBDETAIL WITH (NOLOCK)
   WHERE JobKey = @c_JobKey

   DECLARE WOJM_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(JobLine),'')
         ,ISNULL(RTRIM(WOOperation),'')
         ,ISNULL(RTRIM(FromLoc),'')
         ,ISNULL(RTRIM(ToLoc),'')
   FROM WORKORDERJOBOPERATION  WOJO WITH (NOLOCK)
   WHERE Jobkey = @c_JobKey
   AND   JobLine> @c_JobLineNo
   ORDER BY ISNULL(RTRIM(JobLine),'')

   OPEN WOJM_CUR
   FETCH NEXT FROM WOJM_CUR INTO @c_JobLineNo
                              ,  @c_WOOperation
                              ,  @c_FromLoc
                              ,  @c_ToLoc
  

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN

      SET @c_Sourcekey = CONVERT(NCHAR(10), @c_JobKey) + CONVERT(NCHAR(5), @c_JobLineNo)

      SET @c_TaskType = CASE @c_WOOperation WHEN 'VAS Move'          THEN 'VM'
                                            WHEN 'VAS Move To Line'  THEN 'VL' 
                                            WHEN 'Begin FG'          THEN 'FG'
                                            ELSE ''
                        END

      IF @c_TaskType = 'FG' OR @c_TaskType = ''
      BEGIN
         GOTO NEXT_JOBLINE
      END

      SET @b_success = 0
      EXECUTE nspg_getkey
             'TASKDETAILKEY'
            , 10
            , @c_NewTaskDetailKey   OUTPUT
            , @b_success            OUTPUT
            , @n_err                OUTPUT
            , @c_ErrMsg             OUTPUT

      IF @b_success = 0 
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63701  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error Getting TaskDetailKey. (isp_WOJobGenStepsTask)' 

         GOTO QUIT
      END

      INSERT INTO TASKDETAIL
            (TaskDetailKey
            ,TaskType
            ,Storerkey
            ,Sku
            ,Lot
            ,FromLoc
            ,ToLoc
            ,FromID
            ,ToID
            ,Qty
            ,Priority
            ,Sourcekey
            ,SourceType
            ,PickDetailKey
            ,RefTaskKey
            ,Orderkey
            ,OrderLineNumber
            ,Status
            ,StatusMsg
            )
      SELECT @c_NewTaskDetailKey
            ,@c_TaskType
            ,Storerkey
            ,Sku
            ,Lot
            ,@c_FromLoc
            ,@c_ToLoc
            ,FromID
            ,ToID
            ,Qty
            ,@c_Priority
            ,@c_Sourcekey
            ,@c_SourceType
            ,''
            ,TaskDetailKey
            ,RefTaskKey
            ,''
            ,@c_Status
            ,StatusMsg
      FROM TASKDETAIL WITH (NOLOCK)
      WHERE TaskDetailKey = @c_TaskDetailKey

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63702  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error INSERT Record to TASKDETAIL. (isp_WOJobGenStepsTask)' 
         GOTO QUIT
      END

      NEXT_JOBLINE:
      FETCH NEXT FROM WOJM_CUR INTO @c_JobLineNo
                                 ,  @c_WOOperation
                                 ,  @c_FromLoc
                                 ,  @c_ToLoc
  
   END 
   CLOSE WOJM_CUR
   DEALLOCATE WOJM_CUR

--   SELECT JobKey
--         ,JobLine
--         ,PendingTasks  = SUM(PendingTasks)
--         ,InprocessTasks= SUM(InprocessTasks)
--         ,QtyToProcess  = SUM(QtyToProcess)
--         ,QtyInProcess  = SUM(QtyInProcess)
--   INTO #TMP_Qty
--   FROM (
--         SELECT JobKey = SUBSTRING(Sourcekey,1,10)
--               ,JobLine= SUBSTRING(Sourcekey,11,5)
--               ,PendingTasks = SUM(CASE WHEN Status = '0' THEN 1 ELSE 0 END) 
--               ,InprocessTasks=SUM(CASE WHEN Status = '3' THEN 1 ELSE 0 END) 
--               ,QtyToProcess = SUM(CASE WHEN Status = 'S' THEN Qty ELSE 0 END) 
--               ,QtyInProcess = SUM(CASE WHEN Status = '3' THEN Qty ELSE 0 END)
--         FROM TASKDETAIL WITH (NOLOCK)
--         WHERE SourceType = @c_SourceType
--         AND SUBSTRING(Sourcekey,1,10) = @c_JobKey
--         AND Status IN ('0', '3', 'S')
--         GROUP BY SUBSTRING(Sourcekey,1,10)
--               ,  SUBSTRING(Sourcekey,11,5)
--               ,  Status ) TMP
--   GROUP BY JobKey
--         ,  JobLine
--
--   UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
--   SET PendingTasks  = ISNULL(#TMP_Qty.PendingTasks,0)
--      ,InprocessTasks= ISNULL(#TMP_Qty.InprocessTasks,0)
--      ,QtyToProcess  = ISNULL(#TMP_Qty.QtyToProcess,0)
--      ,QtyInProcess  = ISNULL(#TMP_Qty.QtyInProcess,0)
--      ,EditWho       = SUSER_NAME()
--      ,EditDate      = GETDATE()
--      ,Trafficcop    = NULL 
--   FROM WORKORDERJOBOPERATION WOJO
--   LEFT JOIN #TMP_Qty ON (WOJO.JobKey = #TMP_Qty.Jobkey) AND (WOJO.JobLine = #TMP_Qty.JobLine)
--   WHERE WOJO.JobKey = @c_JobKey
--
--   SET @n_err = @@ERROR
--
--   IF @n_err <> 0
--   BEGIN
--      SET @n_continue= 3
--      SET @n_err     = 63703   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (isp_WOJobReleaseTasks)' 
--      GOTO QUIT
--   END

--   UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
--   SET JobStatus = '3'
--      ,EditWho      = SUSER_NAME()
--      ,EditDate     = GETDATE()
--      ,Trafficcop   = NULL 
--   WHERE JobKey = @c_Jobkey
--
--   SET @n_err = @@ERROR
--
--   IF @n_err <> 0
--   BEGIN
--      SET @n_continue= 3
--      SET @n_err     = 63704   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (isp_WOJobReleaseTasks)' 
--      GOTO QUIT
--   END 
   QUIT:

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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_WOJobGenStepsTask'
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