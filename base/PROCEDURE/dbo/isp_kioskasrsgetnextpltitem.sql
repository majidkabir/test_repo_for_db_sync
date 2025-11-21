SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_KioskASRSGetNextPLTItem                        */
/* Creation Date: 04-Feb-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Confirm Task - Task Completed;                              */
/*        : SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */
/* Called By:                                                           */
/*          : w_gtm_kiosk.ue_getnextpalletitem event                    */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_KioskASRSGetNextPLTItem] 
            @c_Jobkey         NVARCHAR(18) 
         ,  @b_Success        INT = 1  OUTPUT 
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
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   BEGIN TRAN
   UPDATE TASKDETAIL WITH (ROWLOCK)
   SET Status       = '2'
      ,Trafficcop   = NULL
      ,EditWho      = SUSER_NAME()
      ,EditDate     = GETDATE()
   WHERE TaskDetailKey = @c_JobKey

   IF @@ERROR <> 0   
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 61005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TASKDETAIL Fail. (isp_KioskASRSGetNextPLTItem)' 
                   + '( ' + @c_ErrMsg + ' )'
      GOTO QUIT_SP
   END 

QUIT_SP:
   IF CURSOR_STATUS('LOCAL' , 'CUR_MVID') in (0 , 1)
   BEGIN
      CLOSE CUR_MVID
      DEALLOCATE CUR_MVID
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_KioskASRSGetNextPLTItem'
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