SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: isp_KioskASRSTRFNewRevTaskCfm                               */
/* Creation Date: 21-Dec-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Confirm TRF Task - Confirm Pick;                            */
/*        : SOS#358912 - Project Merlion - GTM Kiosk Enhancement        */ 
/*                                                                      */
/* Called By: cb_confirmpick                                            */
/*          : u_kiosk_asrstrf_new_rev_c.cb_confirmpick.click event      */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 11-JAN-2016  Wan01   1.1   SOS#360964 Create Move Instead Transfer   */  
/*                            detail.                                   */  
/************************************************************************/  
CREATE PROC [dbo].[isp_KioskASRSTRFNewRevTaskCfm]   
            @c_Jobkey               NVARCHAR(10)  
         ,  @c_TaskDetailkey        NVARCHAR(10)   
         ,  @c_TransferKey          NVARCHAR(10)  
         ,  @c_TransferLineNumber   NVARCHAR(10)  
         ,  @c_ID                   NVARCHAR(18)  
         ,  @c_PickToID             NVARCHAR(10)   
         ,  @n_PickToQty            INT  
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
         --(Wan01) - START  
         , @c_Storerkey             NVARCHAR(15)  
         , @c_Sku                   NVARCHAR(15)           
         , @c_Packkey               NVARCHAR(10)  
         , @c_UOM                   NVARCHAR(10)  
         , @c_SourceKey             NVARCHAR(15)  
         , @c_MoveRefKey            NVARCHAR(10)  
         , @dt_today                DATETIME  
         --(Wan01) - END  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @b_Success  = 0  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
   SET @dt_today   = GETDATE()            --(Wan01)  
  
   SET @c_Lot = ''  
   SELECT @c_Lot = FromLot  
   FROM TRANSFERDETAIL WITH (NOLOCK)  
   WHERE Transferkey = @c_TransferKey  
   AND   TransferLineNumber = @c_TransferLineNumber  
     
   SET @c_Storerkey = ''                  --(Wan01)  
   SET @c_Sku = ''                        --(Wan01)  
   SET @c_Loc = ''  
   SELECT @c_Storerkey = Storerkey        --(Wan01)  
         ,@c_Sku = @c_Sku                 --(Wan01)  
         ,@c_Loc = LOC  
   FROM LOTxLOCxID WITH (NOLOCK)  
   WHERE Lot = @c_Lot  
   AND   Id  = @c_ID  
   AND   Qty > 0  
  
   IF @c_Loc = ''  
   BEGIN  
      SET @n_continue = 3      
      SET @n_err = 61005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
      SET @c_errmsg='ID''s Loc not found. (isp_KioskASRSTRFNewRevTaskCfm)'   
      GOTO QUIT_SP  
   END  
   
   BEGIN TRAN    
  
   IF @n_QtyToPut > 0  --if @n_PickToQty = 0, mean release pallet without picked  
   BEGIN  
      --(Wan01) - START  
      SET @c_MoveRefKey = ''  
      SET @b_success = 1      
      EXECUTE   nspg_getkey      
               'MoveRefKey'      
              , 10      
              , @c_MoveRefKey       OUTPUT      
              , @b_success          OUTPUT      
              , @n_err              OUTPUT      
              , @c_errmsg           OUTPUT   
  
      IF NOT @b_success = 1      
      BEGIN      
         SET @n_continue = 3      
         SET @n_err = 61010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get MoveRefKey Failed. (isp_KioskASRSTRFNewRevTaskCfm)'   
         GOTO QUIT_SP    
      END   
  
      UPDATE PICKDETAIL WITH (ROWLOCK)  
      SET MoveRefKey = @c_MoveRefKey  
         ,EditWho    = SUSER_NAME()  
         ,EditDate   = GETDATE()  
         ,Trafficcop = NULL  
      WHERE Lot = @c_Lot  
      AND   Loc = @c_Loc  
      AND   ID  = @c_ID  
      AND   Qty < '9'  
      AND   ShipFlag <> 'Y'  
  
      SET @n_err = @@ERROR   
  
      IF @n_err <> 0      
      BEGIN    
         SET @n_continue = 3      
         SET @n_err = 61015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table PICKDETIAL. (isp_KioskASRSTRFNewRevTaskCfm)'   
         GOTO QUIT_SP  
      END   
        
      SET @c_Packkey = ''  
      SET @c_UOM = ''     
      SELECT @c_Packkey = Packkey  
            ,@c_UOM = @c_UOM  
      FROM SKU WITH (NOLOCK)  
      WHERE Storerkey = @c_Storerkey  
      AND   Sku = @c_Sku  
  
      SET @c_SourceKey = RTRIM(@c_TransferKey) + RTRIM(@c_TransferLineNumber)  
      SET @b_Success = 1  
      EXEC dbo.nspItrnAddMove  
            @n_ItrnSysId      = NULL  
         ,  @c_StorerKey      = @c_Storerkey  
         ,  @c_Sku            = @c_Sku  
         ,  @c_Lot            = @c_Lot  
         ,  @c_FromLoc        = @c_Loc  
         ,  @c_FromID         = @c_ID  
         ,  @c_ToLoc          = @c_Loc  
         ,  @c_ToID           = @c_PickToID  
         ,  @c_Status         = 'OK'  
         ,  @c_lottable01     = ''   
         ,  @c_lottable02     = ''   
         ,  @c_lottable03     = ''   
         ,  @d_lottable04     = ''   
         ,  @d_lottable05     = ''   
         ,  @n_casecnt        = 0.00   
         ,  @n_innerpack      = 0.00   
         ,  @n_qty            = @n_QtyToPut  
         ,  @n_pallet         = 0.00   
         ,  @f_cube           = 0.00  
         ,  @f_grosswgt       = 0.00    
         ,  @f_netwgt         = 0.00    
         ,  @f_otherunit1     = 0.00    
         ,  @f_otherunit2     = 0.00    
         ,  @c_SourceKey      = @c_Sourcekey  
         ,  @c_SourceType     = 'isp_KioskASRSTRFNewRevTaskCfm'  
         ,  @c_PackKey        = @c_Packkey  
         ,  @c_UOM            = @c_UOM  
         ,  @b_UOMCalc        = 0  
         ,  @d_EffectiveDate  = @dt_today  
         ,  @c_itrnkey        = ''  
         ,  @b_Success        = @b_Success      OUTPUT  
         ,  @n_err            = @n_err          OUTPUT  
         ,  @c_errmsg         = @c_errmsg       OUTPUT    
         ,  @c_MoveRefKey     = @c_MoveRefKey    
  
      IF NOT @b_Success = 1  
      BEGIN  
         SET @n_Continue = 3   
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)       
         SET @n_Err = 61020      
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing Move To ToID - nspItrnAddMove (isp_KioskASRSTRFNewRevTaskCfm)'  
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         GOTO QUIT_SP     
      END  
  
      /*  
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
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TRANSFERDETAIL Failed. (isp_KioskASRSTRFNewRevTaskCfm)'   
         GOTO QUIT_SP  
      END*/  
   END  
  
   DECLARE CUR_TFD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT TransferLineNumber  
   FROM TRANSFERDETAIL WITH (NOLOCK)   
   WHERE TransferKey = @c_TransferKey  
   AND   TransferLineNumber = @c_TransferLineNumber          --(Wan01) IN (@c_TransferLineNumber, @c_NewTransferLineNumber)  
   AND FROMID = @c_ID  
  
   OPEN CUR_TFD  
  
   FETCH NEXT FROM CUR_TFD INTO  @c_TransferLineNumber          
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @c_ToID = @c_ID  
      --(Wan01) - START  
      -- Change Transferdetail.fromloc & Toloc & FromID & ToID before confirm instead when insert (START)  
      --IF @c_TransferLineNumber = @c_NewTransferLineNumber  
      --BEGIN  
      --   SET @c_ToID = @c_PickToID  
      --END  
      --(Wan01) - END  
  
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
         SET @n_err = 61025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TRANSFERDETAIL Failed. (isp_KioskASRSTRFNewRevTaskCfm)'   
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
         SET @n_err = 61030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute ispFinalizeTransfer Failed. (isp_KioskASRSTRFNewRevTaskCfm)'   
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
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSTRFNewRevTaskCfm)'   
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
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSTRFNewRevTaskCfm)'   
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_KioskASRSTRFNewRevTaskCfm'
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