SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_KioskASRSPKCIPRevTaskCfm                       */
/* Creation Date: 27-Jan-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Confirm PK Task - Confirm Pick;                             */
/*        : SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */
/* Called By: cb_confirmpick                                            */
/*          : u_kiosk_asrspk_cip_rev_b.cb_confirmpick.click event       */
/* PVCS Version: 1.1                                                   */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 20-DEC-2018  Wan01   1.1   WMS-7286 - PRHK-GTM Picking For COPACK Sku*/
/************************************************************************/
CREATE PROC [dbo].[isp_KioskASRSPKCIPRevTaskCfm] 
            @c_JobKey         NVARCHAR(10)
         ,  @c_TaskDetailkey  NVARCHAR(10)  -- GTMJOB.RefTaskKey
         ,  @c_Lot            NVARCHAR(10)
         ,  @c_ID             NVARCHAR(18)
         ,  @c_PickToID       NVARCHAR(10)
         ,  @n_PickToQty      INT
         ,  @n_QtyToPut       INT
         ,  @c_TaskStatus     NVARCHAR(10)   OUTPUT
         ,  @b_Success        INT = 0        OUTPUT 
         ,  @n_err            INT = 0        OUTPUT 
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_StartTCnt          INT
         , @n_Continue           INT 

         , @n_QtyAllocated       INT
         , @n_QtyToMove          INT

         , @c_RefTaskkey         NVARCHAR(10)  -- ASRSPK.RefTaskKey
         , @c_Orderkey           NVARCHAR(10)
         , @c_PickDetailKey      NVARCHAR(10)

         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(15)         
         , @c_Loc                NVARCHAR(10)
         , @c_Packkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @dt_today             DATETIME

   --(Wan01) - START
         , @c_COPACKSku          NVARCHAR(20) = '' 
         , @n_PickToQty_Orig     INT          = ''
   DECLARE @tLot TABLE
      (  Lot               NVARCHAR(10)   NOT NULL PRIMARY KEY
      )
   --(Wan01) - SKU

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @dt_today   = GETDATE()
 
   SELECT @c_Orderkey = Orderkey
         ,@c_RefTaskkey = RefTaskKey
         ,@c_COPACKSku= ISNULL(RTRIM(Message02),'')               --(Wan01)
   FROM  TASKDETAIL (NOLOCK) 
   WHERE Taskdetailkey = @c_TaskDetailkey

   --(Wan03) - START
   INSERT INTO @tLot (Lot)
   VALUES (@c_Lot)

   SET @n_PickToQty_Orig = @n_PickToQty
   --(Wan03) - END

   BEGIN TRAN
 
   CONFIRM_PICK:                                                        --(Wan01)
   IF @n_QtyToPut > 0 
   BEGIN
      SELECT TOP 1                                                      --(Wan01)
             @c_Storerkey = LOTxLOCxID.Storerkey
            ,@c_Sku       = LOTxLOCxID.Sku
            ,@c_Lot       = LOTxLOCxID.Lot                              --(Wan01)
            ,@c_Loc       = LOTxLOCxID.Loc
            ,@c_PackKey   = SKU.Packkey
            ,@c_UOM       = PACK.PackUOM3
      FROM @tLot t                                                      --(Wan01)
      JOIN LOTxLOCxID WITH (NOLOCK) ON (t.lot =  LOTxLOCxID.Lot)        --(Wan01)
      JOIN SKU WITH (NOLOCK)  ON (LOTxLOCxID.Storerkey = SKU.Storerkey)
                              AND(LOTxLOCxID.Sku = SKU.Sku)
      JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      --WHERE LOTxLOCxID.Lot = @c_Lot                                   --(Wan01)
      WHERE  LOTxLOCxID.ID  = @c_ID
      AND   LOTxLOCxID.Qty > 0
      ORDER BY T.Lot                                                    --(Wan01)
      
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
         ,  @c_SourceKey      = ''
         ,  @c_SourceType     = 'isp_KioskASRSPKCIPRevTaskCfm'
         ,  @c_PackKey        = @c_Packkey
         ,  @c_UOM            = @c_UOM
         ,  @b_UOMCalc        = 0
         ,  @d_EffectiveDate  = @dt_today
         ,  @c_itrnkey        = ''
         ,  @b_Success        = @b_Success      OUTPUT
         ,  @n_err            = @n_err          OUTPUT
         ,  @c_errmsg         = @c_errmsg       OUTPUT  
 

      IF NOT @b_Success = 1
      BEGIN
         SET @n_Continue = 3 
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)     
         SET @n_Err = 81005    
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing Move To ToID - nspItrnAddMove (isp_KioskASRSPKCIPRevTaskCfm)'
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT_SP   
      END
   END

   DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PICKDETAIL.Pickdetailkey                                   --(Wan01)
        , PICKDETAIL.Lot                                             --(Wan01)
   FROM @tLot t                                                      --(Wan01)
   JOIN  PICKDETAIL WITH (NOLOCK) ON (T.Lot = PICKDETAIL.Lot)        --(Wan01)
   WHERE PICKDETAIL.Orderkey = @c_Orderkey                           
   --AND   PICKDETAIL.Lot      = @c_Lot                              --(Wan01)   
   AND   PICKDETAIL.ID       = @c_ID
   AND   PICKDETAIL.Taskdetailkey = @c_RefTaskKey
   AND   PICKDETAIL.Status < '4'
   AND   PICKDETAIL.Qty > 0
   ORDER BY PICKDETAIL.PickDetailKey                                 --(Wan01)

   OPEN CUR_PD

   FETCH NEXT FROM CUR_PD INTO  @c_Pickdetailkey
                              , @c_Lot                               --(Wan01)
         
   WHILE @@FETCH_STATUS <> -1 
   BEGIN
      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET Status = '5'
      WHERE Pickdetailkey = @c_PickDetailKey

      SET @n_err = @@ERROR 

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table PICKDETIAL. (isp_KioskASRSPKCIPRevTaskCfm)' 
         GOTO QUIT_SP
      END 

      FETCH NEXT FROM CUR_PD INTO  @c_Pickdetailkey
                                 , @c_Lot                            --(Wan01)
   END
 
   CLOSE CUR_PD
   DEALLOCATE CUR_PD

   --(Wan01) - START
   IF @c_COPACKSku <> ''
   BEGIN
      DELETE FROM @tLot

      INSERT INTO @tLot
         (  Lot
         )
      SELECT DISTINCT
             PICKDETAIL.Lot
      FROM PICKDETAIL WITH (NOLOCK)
      JOIN PACK       WITH (NOLOCK) ON (PICKDETAIL.Packkey = PACK.Packkey)
      WHERE PICKDETAIL.Orderkey = @c_Orderkey
      AND   PICKDETAIL.Sku = @c_COPACKSku
      AND   PICKDETAIL.ID  = @c_ID
      AND   PICKDETAIL.Taskdetailkey = @c_RefTaskKey
      AND   PICKDETAIL.Status < '4'
      AND   PICKDETAIL.Qty > 0

      SET @c_COPACKSku = ''
      SET @n_PickToQty = @n_PickToQty_Orig
      GOTO CONFIRM_PICK
   END
   --(Wan01) - END


   IF NOT EXISTS (SELECT  1    
                  FROM LOADPLANDETAIL WITH (NOLOCK)         
                  JOIN LOADPLANLANEDETAIL WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey = LOADPLANLANEDETAIL.Loadkey)
                  JOIN LOC WITH (NOLOCK) ON (LOADPLANLANEDETAIL.Loc = LOC.Loc)
                  WHERE LOADPLANDETAIL.Orderkey = @c_Orderkey
                  AND   LOADPLANLANEDETAIL.LocationCategory = 'STAGING' 
                 ) OR
      EXISTS ( SELECT 1 FROM ORDERS WITH (NOLOCK)
               WHERE Orderkey = @c_Orderkey
               AND SpecialHandling = 'H' )
   BEGIN
      UPDATE ID WITH (ROWLOCK)
      SET PalletFlag = 'PACKNHOLD'
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
         ,Trafficcop= NULL
      WHERE ID = @c_ID

      SET @n_err = @@ERROR 

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61015  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table ID. (isp_KioskASRSPKCIPRevTaskCfm)' 
         GOTO QUIT_SP
      END 
   END
 
   -- a->b picking (normal CIP) Multiple ASRSPK's task records
   -- 1) @c_ReftaskKey is GTMJob's taskdetail.reftaskkey
   -- 2) @c_ReftaskKey is ASRSPK's taskdetail.reftaskkey
   -- 3) @c_ReftaskKey is ASRSPK's pickdetail.taskdetailkey
   -- 4) @c_Taskdetailkey is ASRSPK's taskdetail.taskdetailkey
   IF NOT EXISTS( SELECT 1
                  FROM PICKDETAIL WITH (NOLOCK)
                  WHERE Orderkey = @c_Orderkey
                  AND   TaskdetailKey = @c_ReftaskKey
                  AND   ID = @c_ID
                  AND   Status < '4'
                  )  
   BEGIN
      SET @c_TaskStatus = '9'

      UPDATE TASKDETAIL WITH (ROWLOCK)
      SET Status = @c_TaskStatus
         ,EditWho= SUSER_NAME()
         ,EditDate=GETDATE()
         ,Trafficcop = NULL
      WHERE FromID = @c_ID
      AND   Orderkey = @c_Orderkey
      AND   RefTaskKey = @c_ReftaskKey
      AND   TaskType = 'ASRSPK'

      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSPKCIPRevTaskCfm)' 
         GOTO QUIT_SP
      END 

      UPDATE TASKDETAIL WITH (ROWLOCK)
      SET Status = '4'
         ,EditWho= SUSER_NAME()
         ,EditDate=GETDATE()
         ,Trafficcop = NULL
      WHERE TaskdetailKey = @c_JobKey
      AND   TaskType = 'GTMJOB'


      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSPKCIPRevTaskCfm)' 
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_KioskASRSPKCIPRevTaskCfm'
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