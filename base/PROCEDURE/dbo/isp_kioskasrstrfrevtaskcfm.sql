SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: isp_KioskASRSTRFRevTaskCfm                                  */
/* Creation Date: 30-Jan-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Confirm TRF Task - Confirm Pick;                            */
/*        : SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */
/* Called By: cb_confirmpick                                            */
/*          : u_kiosk_asrstrf_b_rev.cb_confirmpick.click event          */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_KioskASRSTRFRevTaskCfm] 
            @c_Jobkey               NVARCHAR(10)
         ,  @c_TaskDetailkey        NVARCHAR(10) 
         ,  @c_TransferKey          NVARCHAR(10)
         ,  @c_TransferLineNumber   NVARCHAR(10)
         ,  @c_ID                   NVARCHAR(18)
         ,  @c_PickToID             NVARCHAR(10) 
         ,  @n_QtyToPut             INT
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

   DECLARE @n_StartTCnt             INT
         , @n_Continue              INT 

         , @n_IDQty                 INT
         , @n_FromQty               INT
         , @c_Lot                   NVARCHAR(10)
         , @c_Loc                   NVARCHAR(10)
         , @c_ToID                  NVARCHAR(18)
         , @c_NewTransferLineNumber NVARCHAR(5)

         , @c_InvHoldStatus         NVARCHAR(10)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 0
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_Lot = ''
   SELECT @c_Lot = FromLot
   FROM TRANSFERDETAIL WITH (NOLOCK)
   WHERE Transferkey = @c_TransferKey
   AND   TransferLineNumber = @c_TransferLineNumber
   
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
      SET @c_errmsg='ID''s Loc not found. (isp_KioskASRSTRFRevTaskCfm)' 
      GOTO QUIT_SP
   END
   
   BEGIN TRAN  

   IF @n_QtyToPut > 0  --if @n_PickToQty = 0, mean release pallet without picked
   BEGIN
      SELECT @c_NewTransferLineNumber = RIGHT('00000' + CONVERT(NVARCHAR(5), MAX(TransferLineNumber) + 1),5)
      FROM TRANSFERDETAIL WITH (NOLOCK)
      WHERE TransferKey = @c_TransferKey

      -- Create PickToID ( Transfer Original Pallet to New Pallet)
      INSERT INTO TRANSFERDETAIL
            (
               TransferKey
            ,  TransferLineNumber
            ,  FromStorerkey
            ,  FromSku
            ,  FromPackkey
            ,  FromUOM
            ,  FromQty
            ,  FromLot
            ,  FromLoc
            ,  FromID
            ,  Lottable01
            ,  Lottable02
            ,  Lottable03
            ,  Lottable04
            ,  Lottable05
            ,  Lottable06
            ,  Lottable07
            ,  Lottable08
            ,  Lottable09
            ,  Lottable10
            ,  Lottable11
            ,  Lottable12
            ,  Lottable13
            ,  Lottable14
            ,  Lottable15
            ,  ToStorerkey
            ,  ToSku
            ,  ToPackkey
            ,  ToUOM
            ,  ToQty
            ,  ToLoc
            ,  ToID
            ,  ToLottable01
            ,  ToLottable02
            ,  ToLottable03
            ,  ToLottable04
            ,  ToLottable05
            ,  ToLottable06
            ,  ToLottable07
            ,  ToLottable08
            ,  ToLottable09
            ,  ToLottable10
            ,  ToLottable11
            ,  ToLottable12
            ,  ToLottable13
            ,  ToLottable14
            ,  ToLottable15
            ,  Status
            )
      SELECT TransferKey
            ,@c_NewTransferLineNumber
            ,FromStorerkey
            ,FromSku
            ,FromPackkey
            ,FromUOM
            ,@n_QtyToPut
            ,FromLot
            ,FromLoc       -- @c_Loc
            ,FromID
            ,Lottable01
            ,Lottable02
            ,Lottable03
            ,Lottable04
            ,Lottable05
            ,Lottable06
            ,Lottable07
            ,Lottable08
            ,Lottable09
            ,Lottable10
            ,Lottable11
            ,Lottable12
            ,Lottable13
            ,Lottable14
            ,Lottable15
            ,ToStorerkey
            ,ToSku
            ,ToPackkey
            ,ToUOM
            ,@n_QtyToPut
            ,ToLoc         --@c_Loc
            ,ToID          --@c_PickToID
            ,Lottable01
            ,Lottable02
            ,Lottable03
            ,Lottable04
            ,Lottable05
            ,Lottable06
            ,Lottable07
            ,Lottable08
            ,Lottable09
            ,Lottable10
            ,Lottable11
            ,Lottable12
            ,Lottable13
            ,Lottable14
            ,Lottable15
            ,'4'
      FROM TRANSFERDETAIL WITH (NOLOCK) 
      WHERE TransferKey = @c_TransferKey
      AND TransferLineNumber = @c_TransferLineNumber

      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TRANSFERDETAIL Failed. (isp_KioskASRSTRFRevTaskCfm)' 
         GOTO QUIT_SP
      END
   END

   -- Transfer Original Pallet's Lottables
--   UPDATE TRANSFERDETAIL WITH (ROWLOCK)
--   SET FromLoc      = @c_Loc              -- Change Transferdetail.fromloc & Toloc before confirm instead of change at release task
--      ,ToLoc        = @c_Loc              -- Change Transferdetail.fromloc & Toloc before confirm instead of change at release task
--      ,ToID         = FromID
----      ,UserDefine01 = 'RVPCK' 
----      ,FromQty      = FromQty - @n_QtytoPut
----      ,ToQty        = FromQty - @n_QtytoPut
--      ,EditWho      = SUSER_NAME()
--      ,EditDate     = GETDATE()
--      ,Trafficcop   = NULL
--   WHERE TransferKey = @c_TransferKey
--   AND TransferLineNumber = @c_TransferLineNumber
--
--   SET @n_err = @@ERROR   
--
--   IF @n_err <> 0    
--   BEGIN  
--      SET @n_continue = 3    
--      SET @n_err = 61015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
--      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TRANSFERDETAIL Failed. (isp_KioskASRSTRFRevTaskCfm)' 
--      GOTO QUIT_SP
--   END 

   DECLARE CUR_TFD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TransferLineNumber
   FROM TRANSFERDETAIL WITH (NOLOCK) 
   WHERE TransferKey = @c_TransferKey
   AND   TransferLineNumber IN (@c_TransferLineNumber, @c_NewTransferLineNumber)
   AND FROMID = @c_ID

   OPEN CUR_TFD

   FETCH NEXT FROM CUR_TFD INTO  @c_TransferLineNumber        
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_ToID = @c_ID
      -- Change Transferdetail.fromloc & Toloc & FromID & ToID before confirm instead when insert (START)
      IF @c_TransferLineNumber = @c_NewTransferLineNumber
      BEGIN
         SET @c_ToID = @c_PickToID
      END

      UPDATE TRANSFERDETAIL WITH (ROWLOCK)
      SET FromLoc      = @c_Loc              
         ,ToLoc        = @c_Loc              
         ,ToID         = @c_ToID
         ,EditWho      = SUSER_NAME()
         ,EditDate     = GETDATE()
         ,Trafficcop   = NULL
      WHERE TransferKey = @c_TransferKey
      AND TransferLineNumber = @c_TransferLineNumber

      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TRANSFERDETAIL Failed. (isp_KioskASRSTRFRevTaskCfm)' 
         GOTO QUIT_SP
      END 


      -- Change Transferdetail.fromloc & Toloc & FromID & ToID before confirm instead when insert (END)
      EXEC ispFinalizeTransfer
            @c_Transferkey = @c_Transferkey
         ,  @b_Success     = @b_Success   OUTPUT 
         ,  @n_err         = @n_err       OUTPUT 
         ,  @c_errmsg      = @c_errmsg    OUTPUT
         ,  @c_TransferLineNumber = @c_TransferLineNumber

      IF @b_Success <> 1 
      BEGIN
         SET @n_continue = 3    
         SET @n_err = 61020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute ispFinalizeTransfer Failed. (isp_KioskASRSTRFRevTaskCfm)' 
                      + @c_errmsg
         GOTO QUIT_SP
      END
      FETCH NEXT FROM CUR_TFD INTO  @c_TransferLineNumber 
   END
   CLOSE CUR_TFD
   DEALLOCATE CUR_TFD

   WHILE @@TRANCOUNT <= @n_StartTCnt
   BEGIN
      BEGIN TRAN
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
         SET @n_err = 61025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSTRFRevTaskCfm)' 
         GOTO QUIT_SP
      END 

      UPDATE TASKDETAIL WITH (ROWLOCK)
      SET Status = '4'
         ,EditWho= SUSER_NAME()
         ,EditDate=GETDATE()
         ,Trafficcop = NULL
      WHERE TaskDetailkey = @c_Jobkey
      AND   TaskType = 'GTMJOB'

      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSTRFRevTaskCfm)' 
         GOTO QUIT_SP
      END 
   END
QUIT_SP:
   IF CURSOR_STATUS('LOCAL' , 'CUR_TFD') in (0 , 1)
   BEGIN
      CLOSE CUR_TFD
      DEALLOCATE CUR_TFD
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_KioskASRSTRFRevTaskCfm'
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