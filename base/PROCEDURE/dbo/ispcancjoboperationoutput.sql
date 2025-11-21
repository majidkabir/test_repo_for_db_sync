SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure:ispCancJobOperationOutput                           */  
/* Creation Date: 23-JUN-2015                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#318089 - Project Merlion - VAP Add or Delete Work Order */
/*          Component                                                   */ 
/*                                                                      */  
/* Called By: isp_WOJobCanc                                             */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */
/* 26-JAN-2016  YTWan   1.1   SOS#315603 - Project Merlion - VAP SKU    */
/*                            Reservation Strategy - MixSku in 1 Pallet */
/*                            enhancement                               */	 
/************************************************************************/  
CREATE PROC [dbo].[ispCancJobOperationOutput]    
     @c_JobKey             NVARCHAR(10)  
   , @c_WorkOrderkey       NVARCHAR(10)
   , @c_WkOrdReqOutputsKey NVARCHAR(10) = ''      
   , @b_Success            INT           OUTPUT    
   , @n_Err                INT           OUTPUT    
   , @c_ErrMsg             NVARCHAR(250) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE  @n_Continue       INT     
         ,  @n_StartTCnt      INT  -- Holds the current transaction count  

         ,  @c_JobLineNo      NVARCHAR(5) 
         ,  @c_StepNumber     NVARCHAR(10)

         ,  @c_SourceType     NVARCHAR(10)
            
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue   =  1
   SET @b_Success    =  1 
   SET @n_Err        =  0  
   SET @c_ErrMsg     =  '' 
   SET @c_SourceType = 'VAS'

   BEGIN TRAN

   DECLARE CUR_JOB CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT JobKey
         ,JobLine
         ,StepNumber
         ,WkOrdReqOutputsKey
   FROM VASREFKEYLOOKUP WITH (NOLOCK)
   WHERE JobKey = @c_JobKey
   AND   WorkOrderkey = @c_WorkOrderkey
   AND   WkOrdReqOutputsKey <> '' 
   AND ((WkOrdReqOutputsKey = @c_WkOrdReqOutputsKey) OR @c_WkOrdReqOutputsKey = '')
       
   OPEN CUR_JOB
   
   FETCH NEXT FROM CUR_JOB INTO @c_JobKey
                              , @c_JobLineNo
                              , @c_StepNumber
                              , @c_WkOrdReqOutputsKey

   WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)
   BEGIN
--      IF NOT EXISTS (SELECT 1 FROM VASREFKEYLOOKUP WITH (NOLOCK)
--                     WHERE JobKey = @c_JobKey
--                     AND   WorkOrderkey <> @c_WorkOrderkey
--                    )
--      BEGIN
      IF EXISTS ( SELECT 1
                  FROM TASKDETAIL    TD    WITH (NOLOCK)
                  JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TD.Taskdetailkey)
                  WHERE TLKUP.Jobkey = @c_JobKey
                  AND   TLKUP.JobLine= @c_JobLineNo
                  AND   TLKUP.WorkOrderkey  = @c_WorkOrderkey 
                  AND   TD.SourceType = @c_SourceType
                  AND   TD.Status NOT IN ('S', '0', 'X', '9')
                )
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63505  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'FG Task are in Progress. Cancel/Delete Abort. (ispCancJobOperationOutput)' 
         GOTO QUIT_SP
      END 

      IF EXISTS ( SELECT 1
                  FROM TASKDETAIL    TD    WITH (NOLOCK)
                  JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TD.Taskdetailkey)
                  WHERE TLKUP.Jobkey = @c_JobKey
                  AND   TLKUP.JobLine= @c_JobLineNo
                  AND   TLKUP.WorkOrderkey  = @c_WorkOrderkey 
                  AND   TD.Status IN ('S', '0')
                )
      BEGIN
         EXEC isp_VASJobCancTasks_Wrapper
                 @c_JobKey       = @c_JobKey
               , @c_JobLineNo    = @c_JobLineNo    
               , @c_WorkOrderkey = @c_WorkOrderkey             
               , @b_Success      = @b_Success      OUTPUT            
               , @n_err          = @n_err          OUTPUT          
               , @c_errmsg       = @c_errmsg       OUTPUT

         IF @@ERROR <> 0 OR @b_Success <> 1  
         BEGIN  
            SET @n_Continue= 3    
            SET @n_Err     = 63510  
            SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC isp_VASJobCancTasks_Wrapper ' +    
                              CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispCancJobOperationOutput)'
            GOTO QUIT_SP                         
         END 
      END
--      END

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
            SET @n_err     = 63525 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Delete WORKORDERJOBOPERATION Fail. (ispCancJobOperationOutput)' 
            GOTO QUIT_SP
         END

         IF NOT EXISTS (SELECT 1
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
            DELETE FROM VASREFKEYLOOKUP WITH (ROWLOCK)
            WHERE JobKey = @c_JobKey
            AND   JobLine = @c_JobLineNo
            AND   WorkOrderkey = @c_WorkOrderkey 
            AND   StepNumber   = @c_StepNumber
            AND   WkOrdReqOutputsKey = @c_WkOrdReqOutputsKey 

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63530  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table VASREFKEYLOOKUP. (ispCancJobOperationOutput)' 
               GOTO QUIT_SP
            END  
         END
      END

      FETCH NEXT FROM CUR_JOB INTO @c_JobKey
                                 , @c_JobLineNo
                                 , @c_StepNumber
                                 , @c_WkOrdReqOutputsKey
   END
   CLOSE CUR_JOB
   DEALLOCATE CUR_JOB
QUIT_SP:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_JOB') in (0 , 1)  
   BEGIN
      CLOSE CUR_JOB
      DEALLOCATE CUR_JOB
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
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispCancJobOperationOutput'    
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