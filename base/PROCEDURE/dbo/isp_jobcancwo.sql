SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure:isp_JobCancWO                                       */  
/* Creation Date: 23-JUN-2015                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#318089 - Project Merlion VAP Add or Delete Work Order   */
/*          Component                                                   */ 
/*                                                                      */  
/* Called By: W/O Tab RCM Cancel WorkOrder                              */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev  Purposes                                   */ 
/* 26-JAN-2016  YTWan   1.1  SOS#315603 - Project Merlion - VAP SKU     */
/*                            Reservation Strategy - MixSku in 1 Pallet */
/*                            enhancement                               */	
/************************************************************************/  
CREATE PROC [dbo].[isp_JobCancWO]    
     @c_JobKey         NVARCHAR(10)
   , @c_WorkOrderkey   NVARCHAR(10)
   , @b_Success        INT           OUTPUT    
   , @n_Err            INT           OUTPUT    
   , @c_ErrMsg         NVARCHAR(250) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE  @n_Continue       INT     
         ,  @n_StartTCnt      INT  -- Holds the current transaction count  

         ,  @n_ConsoLineNo          INT
         ,  @c_JobLineNo            NVARCHAR(5)
         ,  @c_StepNumber           NVARCHAR(10)
         ,  @c_WkOrdReqInputsKey    NVARCHAR(10)
         ,  @c_WkOrdReqOutputsKey   NVARCHAR(10)
         ,  @c_TaskStatus           NVARCHAR(10)
         ,  @c_JobStatus            NVARCHAR(10)

         ,  @n_Qty                  INT
         ,  @n_Wastage              INT
         ,  @n_QtyRemaining         INT
         ,  @n_QtyCompleted         INT
         ,  @n_StepQty              INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue   =  1
   SET @b_Success    =  1 
   SET @n_Err        =  0  
   SET @c_ErrMsg     =  '' 

   BEGIN TRAN

   DECLARE CUR_JOBWO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT JobLine
         ,StepNumber
         ,WkOrdReqInputsKey  
         ,WkOrdReqOutputsKey
   FROM VASREFKEYLOOKUP WITH (NOLOCK)
   WHERE JobKey = @c_JobKey
   AND   WorkOrderkey = @c_WorkOrderkey
   ORDER BY WkOrdReqInputsKey DESC
          , WkOrdReqOutputsKey  

   OPEN CUR_JOBWO
   
   FETCH NEXT FROM CUR_JOBWO INTO @c_JobLineNo
                                 ,@c_StepNumber
                                 ,@c_WkOrdReqInputsKey  
                                 ,@c_WkOrdReqOutputsKey

   WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)
   BEGIN
      IF @c_WkOrdReqInputsKey <> ''
      BEGIN
         EXEC ispCancJobOperationInput 
                 @c_JobKey             = @c_JobKey
               , @c_WorkOrderkey       = @c_WorkOrderkey 
               , @c_WkOrdReqInputsKey  = @c_WkOrdReqInputsKey 
               , @b_Success            = @b_Success   OUTPUT            
               , @n_err                = @n_err       OUTPUT          
               , @c_errmsg             = @c_errmsg    OUTPUT

         IF @@ERROR <> 0 OR @b_Success <> 1  
         BEGIN  
            SET @n_Continue= 3    
            SET @n_Err     = 63505  
            SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ispCancJobOperationInput ' +    
                              CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (isp_JobCancWO)'
            GOTO QUIT_SP                          
         END
      END

      IF @c_WkOrdReqInputsKey = '' AND @c_WkOrdReqOutputsKey = ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
                        FROM  JOBTASKLOOKUP WITH (NOLOCK) 
                        WHERE JobKey = @c_JobKey
                        AND   JobLine = @c_JobLineNo
                        )
         BEGIN
            DELETE WORKORDERJOBOPERATION WITH (ROWLOCK)
            WHERE JobKey = @c_JobKey
            AND   JobLine = @c_JobLineNo

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63510 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Delete WORKORDERJOBOPERATION Fail. (isp_JobCancWO)' 
               GOTO QUIT_SP
            END

            IF NOT EXISTS (SELECT 1
                           FROM VASREFKEYLOOKUP WITH (NOLOCK)
                           WHERE JobKey = @c_JobKey
                           AND   WorkOrderkey = @c_WorkOrderkey 
                           AND   WkOrdReqInputsKey  <> '' AND WkOrdReqInputsKey IS NOT NULL
                          )
            BEGIN
               DELETE FROM VASREFKEYLOOKUP WITH (ROWLOCK)
               WHERE JobKey = @c_JobKey
               AND   JobLine = @c_JobLineNo
               AND   WorkOrderkey = @c_WorkOrderkey 
               AND   StepNumber   = @c_StepNumber
               AND   (WkOrdReqInputsKey  = '' OR  WkOrdReqInputsKey  IS NULL)
               AND   (WkOrdReqOutputsKey = '' OR  WkOrdReqOutputsKey IS NULL)

               IF @n_err <> 0
               BEGIN
                  SET @n_continue= 3
                  SET @n_err     = 63515  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table VASREFKEYLOOKUP. (isp_JobCancWO)' 
                  GOTO QUIT_SP
               END 
            END
         END 
      END

      IF @c_WkOrdReqOutputsKey <> ''
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM VASREFKEYLOOKUP JLKUP WITH (NOLOCK)
                     JOIN JOBTASKLOOKUP   TLKUP WITH (NOLOCK) ON (JLKUP.JobKey = TLKUP.JobKey)
                                                              AND(JLKUP.JobLine= TLKUP.JobLine)
                     JOIN TASKDETAIL      TD    WITH (NOLOCK) ON (TLKUP.TaskDetailkey = TD.TaskDetailkey)
                     WHERE JLKUP.JobKey = @c_JobKey
                     AND   JLKUP.WorkOrderkey = @c_WorkOrderkey
                     AND  (JLKUP.WkOrdReqOutputsKey = '' OR JLKUP.WkOrdReqOutputsKey IS NULL)
                     AND  TD.Status NOT IN ('X', '9')
                   )
         BEGIN
            GOTO QUIT_SP
         END

         EXEC ispCancJobOperationOutput 
                 @c_JobKey             = @c_JobKey
               , @c_WorkOrderkey       = @c_WorkOrderkey 
               , @c_WkOrdReqOutputsKey = @c_WkOrdReqOutputsKey 
               , @b_Success            = @b_Success   OUTPUT            
               , @n_err                = @n_err       OUTPUT          
               , @c_errmsg             = @c_errmsg    OUTPUT

         IF @@ERROR <> 0 OR @b_Success <> 1  
         BEGIN  
            SET @n_Continue= 3    
            SET @n_Err     = 63520
            SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ispCancJobOperationOutput' +    
                              CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (isp_JobCancWO)'
            GOTO QUIT_SP                          
         END 
      END
      FETCH NEXT FROM CUR_JOBWO INTO @c_JobLineNo
                                    ,@c_StepNumber
                                    ,@c_WkOrdReqInputsKey  
                                    ,@c_WkOrdReqOutputsKey
   END
   CLOSE CUR_JOBWO
   DEALLOCATE CUR_JOBWO

   UPDATE WORKORDERJOB WITH (ROWLOCK)
   SET  JobStatus = '8'
       ,UOMQtyJob = 0
      ,EditWho   = SUSER_NAME()
      ,EditDate  = GETDATE()
   WHERE Jobkey = @c_JobKey
   AND   WorkOrderkey = @c_Workorderkey

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63525  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Delete Failed On Table WORKORDERJOB. (isp_JobCancWO)' 
      GOTO QUIT_SP
   END

--   IF NOT EXISTS (SELECT 1 
--                  FROM WORKORDERJOB WITH (NOLOCK) 
--                  WHERE JobKey = @c_JobKey
--                  AND QtyRemaining > 0)
--   BEGIN
--      UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
--         SET JobStatus = '8'
--            ,EditWho   = SUSER_NAME()
--            ,EditDate  = GETDATE()
--            ,Trafficcop= NULL 
--      WHERE JobKey = @c_JobKey
--
--      SET @n_err = @@ERROR
--
--      IF @n_err <> 0
--      BEGIN
--         SET @n_continue= 3
--         SET @n_err     = 63530 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (isp_JobCancWO)' 
--         GOTO QUIT_SP
--      END
--   END
QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_JOBWO') in (0 , 1)  
   BEGIN
      CLOSE CUR_JOBWO
      DEALLOCATE CUR_JOBWO
   END

   IF @n_Continue=3  -- Error Occured - Process And Return    
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
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_JobCancWO'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN 
      SET @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   
      RETURN    
   END    
    
END -- Procedure  

GO