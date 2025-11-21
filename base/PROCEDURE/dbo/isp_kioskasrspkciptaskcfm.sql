SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_KioskASRSPKCIPTaskCfm                          */
/* Creation Date: 28-Feb-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Confirm PK Task - Confirm Pick;                             */
/*        : SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */
/* Called By: cb_confirmpick                                            */
/*          : u_kiosk_asrspk_cip_b.cb_confirmpick.click event           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver Purposes                                    */
/* 24-Nov-2015  YTWan   1.1   Fix to Insert CartonGroup, CartonType,    */
/*                            DoCartonize when split pickdetail.(Wan01) */
/* 27-APR-2018  Wan02   1.2   WMS-4672 - MHAP - Load Planning (GTM Update)*/
/* 20-DEC-2018  Wan03   1.3   WMS-7286 - PRHK-GTM Picking For COPACK Sku*/
/************************************************************************/
CREATE PROC [dbo].[isp_KioskASRSPKCIPTaskCfm] 
            @c_JobKey         NVARCHAR(10)
         ,  @c_TaskDetailKey  NVARCHAR(10)
         ,  @c_Lot            NVARCHAR(10)
         ,  @c_ID             NVARCHAR(18)
         ,  @c_PickToID       NVARCHAR(10)
         ,  @n_PickToQty      INT
         ,  @c_OrderStatus    NVARCHAR(10)   OUTPUT
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
         , @n_QtyPicked          INT
         , @n_QtyRemaining       INT

         , @c_RefTaskkey         NVARCHAR(10)  -- ASRSPK TASKDETAIL.RefTaskkey 
         , @c_Orderkey           NVARCHAR(10) 

         , @c_PickDetailKey      NVARCHAR(10)
         , @c_NewPickDetailKey   NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)        
         , @c_Loc                NVARCHAR(10)
         , @c_Packkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)

         , @c_MoveRefKey         NVARCHAR(10)
         , @dt_today             DATETIME
         , @c_InvHoldStatus      NVARCHAR(10)

         , @c_Notes              NVARCHAR(MAX)
         , @c_Status             NVARCHAR(10)
         , @c_TaskManagerReasonKey  NVARCHAR(10)

         , @c_Containerkey       NVARCHAR(10)   --(Wan02)
         , @c_LineNo             NVARCHAR(5)    --(Wan02)
         , @c_Consigneekey       NVARCHAR(30)   --(Wan02)   
         , @c_NoOfPalletQty      NVARCHAR(30)   --(Wan02)
         , @c_PalletWeight       NVARCHAR(30)   --(Wan02)

   --(Wan03) - START
         , @c_COPACKSku          NVARCHAR(20) = '' 
         , @n_PickToQty_Orig     INT          = ''
   DECLARE @tLot TABLE
      (  Lot               NVARCHAR(10)   NOT NULL PRIMARY KEY
      )
   --(Wan03) - SKU

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @dt_today   = GETDATE()
   SET @c_OrderStatus = '0'

   SELECT @c_Orderkey = Orderkey
         ,@c_RefTaskkey = RefTaskKey
         ,@c_COPACKSku= ISNULL(RTRIM(Message02),'')               --(Wan03)
   FROM  TASKDETAIL (NOLOCK) 
   WHERE Taskdetailkey = @c_TaskDetailkey

   --(Wan03) - START
   INSERT INTO @tLot (Lot)
   VALUES (@c_Lot)

   SET @n_PickToQty_Orig = @n_PickToQty
   --(Wan03) - END

   BEGIN TRAN

   CONFIRM_PICK:                                                  --(Wan03)
   DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PICKDETAIL.Pickdetailkey
         ,PICKDETAIL.Storerkey
         ,PICKDETAIL.Sku
         ,PICKDETAIL.Lot                                          --(Wan03)
         ,PICKDETAIL.Loc
         ,PICKDETAIL.Packkey
         ,PACK.PackUOM3
         ,PICKDETAIL.Qty
   FROM PICKDETAIL WITH (NOLOCK)
   JOIN PACK       WITH (NOLOCK) ON (PICKDETAIL.Packkey = PACK.Packkey)
   WHERE PICKDETAIL.Orderkey = @c_Orderkey   
   --AND   PICKDETAIL.Lot      = @c_Lot                           --(Wan03)
   AND   EXISTS (SELECT 1 FROM @tLot WHERE Lot = PICKDETAIL.Lot)  --(Wan03)
   AND   PICKDETAIL.ID       = @c_ID
   AND   PICKDETAIL.Taskdetailkey = @c_RefTaskKey
   AND   PICKDETAIL.Status < '4'
   AND   PICKDETAIL.Qty > 0

   OPEN CUR_PD

   FETCH NEXT FROM CUR_PD INTO  @c_Pickdetailkey
                              , @c_Storerkey
                              , @c_Sku
                              , @c_Lot                            --(Wan03)
                              , @c_Loc
                              , @c_Packkey
                              , @c_UOM
                              , @n_QtyAllocated       
          
   WHILE @@FETCH_STATUS <> -1 AND @n_PickToQty > 0                --(Wan03)
   BEGIN
      SET @c_NewPickDetailKey = ''  --(Wan02)
      SET @c_Status= '5'

      SET @n_QtyPicked = CASE WHEN @n_PickToQty > @n_QtyAllocated THEN @n_QtyAllocated ELSE @n_PickToQty END
      
      -- Picking Short when
      -- 1) Short Pick
      IF  @n_QtyPicked < @n_QtyAllocated  
      BEGIN
         SET @n_QtyRemaining = @n_QtyAllocated - @n_QtyPicked  
         SET @c_Status = '4'

         UPDATE PICKDETAIL WITH (ROWLOCK)
         SET Qty = @n_QtyRemaining
            ,Status = @c_Status 
         WHERE Pickdetailkey = @c_PickDetailKey

         SET @n_err = @@ERROR 

         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 61005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table PICKDETIAL. (isp_KioskASRSPKCIPTaskCfm)' 
            GOTO QUIT_SP
         END 

         IF @n_QtyAllocated = @n_QtyRemaining
         BEGIN
            GOTO NEXT_PD
         END 

         SET @b_success = 1    
         EXECUTE   nspg_getkey    
                  'PickDetailKey'    
                 , 10    
                 , @c_NewPickDetailKey OUTPUT    
                 , @b_success          OUTPUT    
                 , @n_err              OUTPUT    
                 , @c_errmsg           OUTPUT 

         IF NOT @b_success = 1    
         BEGIN    
            SET @n_continue = 3    
            SET @n_err = 61010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PickDetailKey Failed. (isp_KioskASRSPKCIPTaskCfm)' 
            GOTO QUIT_SP  
         END  

         INSERT INTO PICKDETAIL 
            (  PickdetailKey
            ,  PickHeaderKey
            ,  Orderkey
            ,  OrderLineNumber
            ,  Storerkey
            ,  Sku
            ,  Lot
            ,  Loc
            ,  ID
            ,  Packkey
            ,  UOM
            ,  UOMQty
            ,  CartonGroup --(Wan01)
            ,  CartonType  --(Wan01)
            ,  DoCartonize --(Wan01)
            ,  PickMethod
            ,  Qty
            ,  TaskdetailKey 
            ,  Status
            ,  Notes
            ,  TaskManagerReasonKey
            )
         SELECT @c_NewPickdetailKey
            , ''
            , Orderkey
            , OrderlineNumber
            , Storerkey
            , Sku
            , Lot
            , Loc
            , ID
            , Packkey
            , UOM
            , UOMQty
            , CartonGroup --(Wan01)
            , CartonType  --(Wan01)
            , DoCartonize --(Wan01)
            , PickMethod
            , @n_QtyPicked
            , TaskdetailKey
            , '0'
            , 'Split from PickdetailKey: ' + @c_PickDetailKey 
            + ', Original QtyAllocated: ' + CONVERT(NVARCHAR(5), @n_QtyAllocated)
            , 'SHORT' 
         FROM PICKDETAIL WITH (NOLOCK)
         WHERE PickDetailkey = @c_PickDetailKey

         SET @n_err = @@ERROR 

         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 61015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Failed into Table PCIKDETAIL. (isp_KioskASRSPKCIPTaskCfm)' 
            GOTO QUIT_SP
         END 
       
         SET @c_Status = '5' 
         SET @c_PickDetailKey = @c_NewPickdetailKey
      END

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
         SET @n_err = 61020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get MoveRefKey Failed. (isp_KioskASRSPKCIPTaskCfm)' 
         GOTO QUIT_SP  
      END 

      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET MoveRefKey = @c_MoveRefKey
         ,EditWho    = SUSER_NAME()
         ,EditDate   = GETDATE()
         ,Trafficcop = NULL
      WHERE Pickdetailkey = @c_PickDetailKey

      SET @n_err = @@ERROR 

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table PICKDETIAL. (isp_KioskASRSPKCIPTaskCfm)' 
         GOTO QUIT_SP
      END 

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
         ,  @n_qty            = @n_QtyPicked
         ,  @n_pallet         = 0.00 
         ,  @f_cube           = 0.00
         ,  @f_grosswgt       = 0.00  
         ,  @f_netwgt         = 0.00  
         ,  @f_otherunit1     = 0.00  
         ,  @f_otherunit2     = 0.00  
         ,  @c_SourceKey      = ''
         ,  @c_SourceType     = 'isp_KioskASRSPKCIPTaskCfm'
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
         SET @n_Err = 61030    
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing Move To ToID - nspItrnAddMove (isp_KioskASRSPKCIPTaskCfm)'
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT_SP   
      END

      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET Status     = @c_Status
      WHERE Pickdetailkey = @c_PickDetailKey

      SET @n_err = @@ERROR 

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61035   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table PICKDETIAL. (isp_KioskASRSPKCIPTaskCfm)' 
         GOTO QUIT_SP
      END 

      --(Wan02) - START
      SET @c_Containerkey = ''
      SET @c_LineNo = ''
      SET @c_Consigneekey = ''
      SET @c_NoOfPalletQty= ''
      SET @c_PalletWeight = ''

      SELECT TOP 1 @c_Containerkey = CTNRD.ContainerKey
            ,@c_LineNo = CTNRD.ContainerLineNumber
            ,@c_Consigneekey = CTNRD.Userdefine01
            ,@c_NoOfPalletQty= CTNRD.Userdefine03
            ,@c_PalletWeight = CTNRD.Userdefine04
      FROM ORDERS OH WITH (NOLOCK)
      JOIN CONTAINER CTNR WITH (NOLOCK) ON (OH.Loadkey = CTNR.Loadkey)
      JOIN CONTAINERDETAIL CTNRD WITH (NOLOCK) ON (CTNR.Containerkey = CTNRD.Containerkey)
      WHERE OH.Orderkey = @c_Orderkey 
      AND   CTNRD.Palletkey = @c_ID
      AND   CTNRD.Userdefine02 = @c_Sku
      AND   CTNR.Status < '9'
      ORDER BY CTNR.ContainerKey

      IF @c_Containerkey <> '' AND @c_LineNo <> ''
      BEGIN
         IF @c_NewPickDetailKey <> ''  -- Split Pickdetail
         BEGIN
            SET @c_LineNo = ''
            SELECT @c_LineNo = ISNULL(MAX(ContainerLineNumber),'00000')
            FROM CONTAINERDETAIL CTNRD WITH (NOLOCK) 
            WHERE CTNRD.Containerkey = @c_Containerkey

            SET @c_LineNo = RIGHT('00000' + CONVERT(NVARCHAR(5),(CONVERT(INT, @c_LineNo) + 1)),5)

            INSERT INTO CONTAINERDETAIL (Containerkey
                                       , ContainerLineNumber
                                       , Palletkey
                                       , Userdefine01
                                       , Userdefine02
                                       , Userdefine03
                                       , Userdefine04)
            VALUES(  @c_Containerkey
                  ,  @c_LineNo
                  ,  @c_PickToId
                  ,  @c_Consigneekey
                  ,  @c_Sku
                  ,  @c_NoOfPalletQty
                  ,  @c_PalletWeight
                  ) 
              
            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(CHAR(250),@n_err)
               SET @n_err = 61040
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert Containerdetail Table'
                              +'. (isp_KioskASRSPKCIPTaskCfm)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
               GOTO QUIT_SP
            END
         END 
         ELSE 
         BEGIN
            UPDATE CONTAINERDETAIL WITH (ROWLOCK)
            SET  PalletKey = @c_PickToID
               , EditWho   = SUSER_NAME()
               , EditDate  = GETDATE()
            WHERE ContainerKey = @c_Containerkey
            AND   ContainerLineNumber = @c_LineNo
            AND   Palletkey = @c_ID 

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(CHAR(250),@n_err)
               SET @n_err = 61045
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update Containerdetail Table'
                              +'. (isp_KioskASRSPKCIPTaskCfm)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
               GOTO QUIT_SP
            END
         END
      END
      --(Wan02) - END

      SET @n_PickToQty = @n_PickToQty - @n_QtyPicked

      NEXT_PD:
      FETCH NEXT FROM CUR_PD INTO  @c_Pickdetailkey
                                 , @c_Storerkey
                                 , @c_Sku
                                 , @c_Lot                         --(Wan03)
                                 , @c_Loc
                                 , @c_Packkey
                                 , @c_UOM
                                 , @n_QtyAllocated     
   END

   CLOSE CUR_PD
   DEALLOCATE CUR_PD

   --(Wan03) - START
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
   --(Wan03) - END

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
      WHERE ID = @c_PickToID

      SET @n_err = @@ERROR 

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table ID. (isp_KioskASRSPKCIPTaskCfm)' 
         GOTO QUIT_SP
      END 
   END

   -- a->b picking (normal CIP) Multiple ASRSPK's task records
   -- 1) @c_ReftaskKey is GTMJob's taskdetail.reftaskkey
   -- 2) @c_ReftaskKey is ASRSPK's taskdetail.reftaskkey
   -- 3) @c_ReftaskKey is ASRSPK's pickdetail.taskdetailkey
   -- 4) @c_Taskdetailkey is ASRSPK's taskdetail.taskdetailkey


   IF NOT EXISTS ( SELECT 1
                   FROM PICKDETAIL WITH (NOLOCK)
                   WHERE Orderkey = @c_Orderkey
                   AND   TaskdetailKey = @c_RefTaskKey
                   AND   Status < '4' AND Qty > 0
                 )
   BEGIN
      SET @c_OrderStatus = '5' -- Picked

      UPDATE TASKDETAIL WITH (ROWLOCK)
      SET Status = '9'
         ,EditWho= SUSER_NAME()
         ,EditDate=GETDATE()
         ,Trafficcop = NULL
      WHERE Orderkey = @c_Orderkey
      AND   TaskdetailKey = @c_ReftaskKey
      AND   TaskType = 'ASRSPK'

      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61065   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSPKCIPTaskCfm)' 
         GOTO QUIT_SP
      END 
   END

   IF NOT EXISTS( SELECT 1
                  FROM PICKDETAIL WITH (NOLOCK)
                  WHERE ID = @c_ID
                  AND   TaskdetailKey = @c_RefTaskKey
                  AND   Status < '4' -- Don't why there is Pickdetail.status = '2' during UAT
                  )  
   BEGIN
      SET @c_TaskStatus = '9'

      UPDATE TASKDETAIL WITH (ROWLOCK)
      SET Status = @c_TaskStatus
         ,EditWho= SUSER_NAME()
         ,EditDate=GETDATE()
         ,Trafficcop = NULL
      WHERE FromID = @c_ID
      AND   RefTaskKey = @c_RefTaskKey
      AND   TaskType = 'ASRSPK'
      AND   Status < '9'
     
      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSPKCIPTaskCfm)' 
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
         SET @n_err = 61075   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSPKCIPTaskCfm)' 
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_KioskASRSPKCIPTaskCfm'
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