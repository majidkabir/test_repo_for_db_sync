SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_KioskASRSQCTaskCfm                             */
/* Creation Date: 22-Jan-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Confirm Task - Task Completed;                              */
/*        : SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */
/* Called By: cb_complete                                               */
/*          : u_kiosk_asrsqc_b.cb_complete.click event                  */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_KioskASRSQCTaskCfm] 
            @c_Jobkey         NVARCHAR(10) 
         ,  @c_TaskDetailkey  NVARCHAR(10) 
         ,  @c_ID             NVARCHAR(18) 
         ,  @b_Success        INT = 0  OUTPUT 
         ,  @n_err            INT = 0  OUTPUT 
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
  
   BEGIN TRAN
   UPDATE TASKDETAIL WITH (ROWLOCK)
   SET Status = '9' 
      ,EditWho= SUSER_NAME()
      ,EditDate=GETDATE()
      ,Trafficcop = NULL
   WHERE TaskdetailKey = @c_Taskdetailkey

   SET @n_err = @@ERROR   

   IF @n_err <> 0    
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 61005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSQCTaskCfm)' 
      GOTO QUIT_SP
   END 

   UPDATE TASKDETAIL WITH (ROWLOCK)
   SET Status = '4'
      ,EditWho= SUSER_NAME()
      ,EditDate=GETDATE()
      ,Trafficcop = NULL
   WHERE TaskDetailkey= @c_JobKey
   AND   TaskType = 'GTMJOB'


   SET @n_err = @@ERROR   

   IF @n_err <> 0    
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 61010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSQCTaskCfm)' 
      GOTO QUIT_SP
   END 


QUIT_SP:

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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_KioskASRSQCTaskCfm'
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
END -- procedure

GO