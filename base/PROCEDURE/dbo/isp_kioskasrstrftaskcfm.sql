SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_KioskASRSTRFTaskCfm                            */
/* Creation Date: 30-Jan-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Confirm TRF Task - Confirm Pick;                            */
/*        : SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */
/* Called By: cb_confirmpick                                            */
/*          : u_kiosk_asrstrf_b.cb_confirmpick.click event              */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_KioskASRSTRFTaskCfm] 
            @c_Jobkey               NVARCHAR(10) 
         ,  @c_TaskDetailkey        NVARCHAR(10) 
         ,  @c_TransferKey          NVARCHAR(10)
         ,  @c_TransferLineNumber   NVARCHAR(10)
         ,  @c_ID                   NVARCHAR(18)
         ,  @c_PickToID             NVARCHAR(10)
         ,  @n_PickToQty            INT
         ,  @c_TaskStatus           NVARCHAR(10)   = '0' OUTPUT
         ,  @b_Success              INT = 0  OUTPUT 
         ,  @n_err                  INT = 0  OUTPUT 
         ,  @c_errmsg               NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_StartTCnt          INT
         , @n_Continue           INT 

         , @c_Lot                NVARCHAR(10)
         , @c_Loc                NVARCHAR(10)

         , @c_InvHoldStatus      NVARCHAR(10)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 0
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_Lot = ''
   SELECT @c_Lot = FromLot
   FROM TRANSFERDETAIL WITH (NOLOCK) 
   WHERE TransferKey = @c_TransferKey
   AND TransferLineNumber = @c_TransferLineNumber

   SET @c_Loc = ''
   SELECT @c_Loc = LOC
   FROM LOTxLOCxID WITH (NOLOCK)
   WHERE Lot = @c_Lot
   AND   Id  = @c_ID
   AND   Qty > 0

   IF @c_Loc = ''
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 61005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='ID''s Loc not found. (isp_KioskASRSTRFTaskCfm)' 
      GOTO QUIT_SP
   END

   BEGIN TRAN  

   UPDATE TRANSFERDETAIL WITH (ROWLOCK)
   SET FromLoc      = @c_Loc              -- Change Transferdetail.fromloc & Toloc before confirm instead of change at release task
      ,ToLoc        = @c_Loc              -- Change Transferdetail.fromloc & Toloc before confirm instead of change at release task
      ,ToID         = @c_PickToID
      ,UserDefine03 = CASE WHEN FromQty > @n_PickToQty THEN CONVERT(NVARCHAR(10), FromQty) ELSE UserDefine03 END
      ,FromQty      = @n_PickToQty
      ,ToQty        = @n_PickToQty
      ,EditWho      = SUSER_NAME()
      ,EditDate     = GETDATE()
      ,Trafficcop   = NULL
   WHERE TransferKey = @c_TransferKey
   AND TransferLineNumber = @c_TransferLineNumber

   SET @n_err = @@ERROR   

   IF @n_err <> 0    
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 61010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TRANSFERDETAIL Failed. (isp_KioskASRSTRFTaskCfm)' 
      GOTO QUIT_SP
   END 

   EXEC ispFinalizeTransfer
         @c_Transferkey = @c_Transferkey
      ,  @b_Success     = @b_Success   OUTPUT 
      ,  @n_err         = @n_err       OUTPUT 
      ,  @c_errmsg      = @c_errmsg    OUTPUT
      ,  @c_TransferLineNumber = @c_TransferLineNumber

   IF @b_Success <> 1 
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 61015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute ispFinalizeTransfer Failed. (isp_KioskASRSTRFTaskCfm)' 
                   + @c_errmsg
      GOTO QUIT_SP
   END

   IF NOT EXISTS( SELECT 1
                  FROM TRANSFERDETAIL WITH (NOLOCK)
                  WHERE TransferKey = @c_TransferKey
                  AND   FromID = @c_ID
                  AND   Status < '5' AND Status <> 'CANC'
                  ) AND
      EXISTS ( SELECT 1 
               FROM TASKDETAIL WITH (NOLOCK)
               WHERE TaskdetailKey = @c_Taskdetailkey
               AND   Status < '9'
             )
   BEGIN
      SET @c_TaskStatus = '9'

      UPDATE TASKDETAIL WITH (ROWLOCK)
      SET Status = @c_TaskStatus
         ,EditWho= SUSER_NAME()
         ,EditDate=GETDATE()
         ,Trafficcop = NULL
      WHERE TaskdetailKey = @c_Taskdetailkey

      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSTRFTaskCfm)' 
         GOTO QUIT_SP
      END 

      UPDATE TASKDETAIL WITH (ROWLOCK)
      SET Status = '4'
         ,EditWho= SUSER_NAME()
         ,EditDate=GETDATE()
         ,Trafficcop = NULL
      WHERE TaskdetailKey = @c_Jobkey
      AND   TaskType = 'GTMJOB'

      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSTRFTaskCfm)' 
         GOTO QUIT_SP
      END 
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_KioskASRSTRFTaskCfm'
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