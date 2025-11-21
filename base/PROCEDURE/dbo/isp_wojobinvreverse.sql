SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store Procedure: isp_WOJobInvReverse                                    */
/* Creation Date: 07-Dec-2012                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Hold Work Order Job Tasks                                     */
/*                                                                         */
/* Called By: PB: Work ORder Job - RMC Reserve                             */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 25-JUN-2015  YTWan    1.1  SOS#318089 - VAP Add or Delete Order         */
/*                            Component (Wan01)                            */
/* 26-JAN-2016  YTWan    1.2  SOS#315603 - Project Merlion - VAP SKU       */
/*                            Reservation Strategy - MixSku in 1 Pallet    */
/*                            enhancement                                  */	
/***************************************************************************/
CREATE PROC [dbo].[isp_WOJobInvReverse]
           @c_JobKey          NVARCHAR(10) 
         , @b_Success         INT            OUTPUT            
         , @n_err             INT            OUTPUT          
         , @c_errmsg          NVARCHAR(255)  OUTPUT  
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue     INT                     
         , @n_StartTCnt    INT            -- Holds the current transaction count    

   DECLARE @c_WOMoveKey    NVARCHAR(10)
--         , @c_JobLineNo    NVARCHAR(5)
         , @c_Storerkey    NVARCHAR(15)
         , @c_Sku          NVARCHAR(20)
         , @c_PackKey      NVARCHAR(10)
         , @c_UOM          NVARCHAR(10)
         , @c_FromLoc      NVARCHAR(10)
         , @c_ToLoc        NVARCHAR(10)
         , @c_aLot         NVARCHAR(10)
         , @c_ID           NVARCHAR(18)
         , @c_Lot          NVARCHAR(10)
         , @n_Qty          INT
         , @n_MoveQty      INT
         , @c_PickMethod      NVARCHAR(10)
   
         , @c_SourceKey    NVARCHAR(20)
         , @c_SourceType   NVARCHAR(30)

         , @n_StepQty      INT
         , @n_QtyReserved  INT
         , @n_QtyToMove    INT
         , @n_QtyItemsOrd  INT
         , @n_QtyItemsRes  INT
         , @c_JobStatus    NVARCHAR(10)

         , @c_MoveRefKey   NVARCHAR(10)

   SET @n_Continue         = 1
   SET @n_StartTCnt        = @@TRANCOUNT  
   SET @b_Success          = 1
   SET @n_Err              = 0
   SET @c_errmsg           = ''  

   SET @c_WOMoveKey        = ''
--   SET @c_JobLineNo        = ''
   SET @c_Storerkey        = ''
   SET @c_Sku              = ''
   SET @c_PackKey          = ''
   SET @c_UOM              = ''
   SET @c_FromLoc          = ''
   SET @c_ToLoc            = ''
   SET @c_Lot              = ''
   SET @c_ID               = ''
   SET @n_MoveQty          = 0

   SET @c_SourceKey        = ''
   SET @c_SourceType       = 'VAS'

   SET @n_StepQty          = 0
   SET @n_QtyReserved      = 0
   SET @n_QtyToMove        = 0
   SET @n_QtyItemsOrd      = 0
   SET @n_QtyItemsRes      = 0


   BEGIN TRAN
   DELETE FROM WORKORDERJOBMOVE WITH (ROWLOCK)
   WHERE JobKey = @c_JobKey

/*
   IF EXISTS (SELECT 1
              FROM WORKORDERJOBMOVE WOJM WITH (NOLOCK)
              LEFT JOIN TASKDETAIL  TD   WITH (NOLOCK) ON (WOJM.WOMoveKey = CONVERT(Bigint, TD.PickDetailKey))
                                                       AND(SUBSTRING(TD.Sourcekey,1,10)= WOJM.JobKey)
                                                       AND(TD.Sourcetype = @c_SourceType)
              WHERE  WOJM.JobKey = @c_JobKey
              AND  (WOJM.JobLine = @c_JobLineNo OR @c_JobLineNo = '')
              AND  (WOJM.WOMoveKey = @n_WOMoveKey OR @n_WOMoveKey = 0)
              AND  TD.Status = '9'
              AND   TD.TaskDetailkey IS NOT NULL
              AND (WOJM.Status = '9'))
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63701  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': All Pull / Pick Tasks '
                     + 'had been executed. No reserved inventory to reverse. (isp_WOJobInvReverse)'

      GOTO QUIT
   END

   IF EXISTS (SELECT 1
              FROM WORKORDERJOBMOVE WOJM WITH (NOLOCK)
              LEFT JOIN TASKDETAIL  TD   WITH (NOLOCK) ON (WOJM.WOMoveKey = CONVERT(Bigint, TD.PickDetailKey))
                                                       AND(SUBSTRING(TD.Sourcekey,1,10)= WOJM.JobKey)
                                                       AND(TD.Sourcetype = @c_SourceType)
              WHERE WOJM.JobKey = @c_JobKey
              AND  @c_JobLineNo = ''                     -- Only check if Reverse by Jobkey
              AND (WOJM.WOMoveKey = @n_WOMoveKey OR @n_WOMoveKey = 0)
              AND  TD.Status IN ('S', '0', '3', 'H')
              AND (WOJM.Status = '9'))
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63702  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Tasks are generated/active for job. '
                     + 'Please cancel any tasks before reversing the inventory. (isp_WOJobInvReverse)' 
      GOTO QUIT
   END

   BEGIN TRAN
   DECLARE WOJO_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(JobLine),'')
         ,ISNULL(StepQty,0)
         ,ISNULL(QtyReserved ,0)
   FROM WORKORDERJOBOPERATION WOJO WITH (NOLOCK)
   JOIN SKU              SKU  WITH (NOLOCK) ON (WOJO.Storerkey = SKU.Storerkey)
                                            AND(WOJO.Sku = SKU.Sku)
   WHERE Jobkey = @c_jobKey
   AND (WOJO.JobLine = @c_JobLineNo OR @c_JobLineNo = '')

   OPEN WOJO_CUR
   FETCH NEXT FROM WOJO_CUR INTO @c_JobLineNo
                              ,  @n_StepQty
                              ,  @n_QtyReserved 

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN 
      SET @n_QtyToMove = 0

      DECLARE WOJM_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ISNULL(RTRIM(WOMoveKey),'')
            ,ISNULL(RTRIM(WOJM.JobLine),'')
--            ,ISNULL(RTRIM(WOJM.Storerkey),'')
--            ,ISNULL(RTRIM(WOJM.Sku),'')
--            ,ISNULL(RTRIM(WOJM.Packkey),'')
--            ,ISNULL(RTRIM(WOJM.UOM),'')
            ,ISNULL(RTRIM(WOJM.Lot),'')
            ,ISNULL(RTRIM(WOJM.FromLoc),'')
            ,ISNULL(RTRIM(WOJM.ToLoc),'')
            ,ISNULL(RTRIM(WOJM.ID),'')
            ,ISNULL(WOJM.Qty,0)
            ,ISNULL(RTRIM(WOJM.PickMethod),'')
      FROM WORKORDERJOBMOVE WOJM WITH (NOLOCK)
      WHERE WOJM.Jobkey = @c_jobKey
      AND   WOJM.JobLine= @c_JobLineNo
      AND  (WOJM.WOMoveKey = @n_WOMoveKey OR @n_WOMoveKey = 0)
      AND  (WOJM.Status= '9')

      OPEN WOJM_CUR
      FETCH NEXT FROM WOJM_CUR INTO @c_WOMoveKey
                                 ,  @c_JobLineNo
                                 ,  @c_aLot
                                 ,  @c_FromLoc
                                 ,  @c_ToLoc
                                 ,  @c_ID
                                 ,  @n_MoveQty
                                 ,  @c_PickMethod 
      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         SET @c_Sourcekey = CONVERT( NCHAR(10), @c_JobKey) + CONVERT( NCHAR(5), @c_JobLineNo)

         IF @n_QtyToReverse > 0 --AND @n_QtyToReverse < @n_MoveQty
         BEGIN
            SET @n_MoveQty = @n_QtyToReverse 
            SET @c_PickMethod = '3'
         END

         IF @c_PickMethod = '1' -- WORKORDERJOBOperation.PULLUOM = PACKUOM4 (Pallet) 
         BEGIN
            DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Storerkey
                  ,Sku
                  ,Lot
                  ,Qty
            FROM LOTxLOCxID WITH (NOLOCK)
            WHERE Loc = @c_ToLoc
            AND   ID  = @c_ID
            AND   Qty > 0
         END
         ELSE
         BEGIN
            DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Storerkey
                  ,Sku
                  ,Lot
                  ,@n_MoveQty
            FROM LOTxLOCxID WITH (NOLOCK)
            WHERE Lot = @c_aLot
            AND   Loc = @c_ToLoc
            AND   ID  = @c_ID
            AND   Qty > 0
         END

         OPEN CUR_ID
         FETCH NEXT FROM CUR_ID INTO @c_Storerkey
                                    ,@c_Sku
                                    ,@c_Lot
                                    ,@n_Qty

         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)
         BEGIN

            SELECT @c_Packkey = Packkey
            FROM SKU WITH (NOLOCK) 
            WHERE Storerkey = @c_Storerkey
            AND   Sku = @c_Sku

            SELECT @c_UOM = PACKUOM3
            FROM PACK WITH (NOLOCK)
            WHERE Packkey = @c_Packkey

            SET @c_MoveRefKey = ''

            IF @c_PickMethod = '1'
            BEGIN
              IF EXISTS ( SELECT 1
                          FROM INVENTORYHOLD (NOLOCK)
                          WHERE ID = @c_ID
                          AND Hold = '1'
                          AND Status = 'VASIDHOLD'
                        )
               BEGIN  
                  EXEC nspInventoryHoldWrapper
                     '',               -- lot
                     '',               -- loc
                     @c_ID,            -- id
                     '',               -- storerkey
                     '',               -- sku
                     '',               -- lottable01
                     '',               -- lottable02
                     '',               -- lottable03
                     NULL,             -- lottable04
                     NULL,             -- lottable05
                     '',               -- lottable06
                     '',               -- lottable07    
                     '',               -- lottable08
                     '',               -- lottable09
                     '',               -- lottable10
                     '',               -- lottable11
                     '',               -- lottable12
                     NULL,             -- lottable13
                     NULL,             -- lottable14
                     NULL,             -- lottable15
                     'VASIDHOLD',      -- status  
                     '0',              -- hold
                     @b_success OUTPUT,
                     @n_err OUTPUT,
                     @c_errmsg OUTPUT,
                     'VAS ASRS ID UN HOLD'     -- remark

                  IF @n_err <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @n_err = 63705
                     SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Hold ID Fail. (isp_WOJobInvReverse)' 
                                         + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '
                     GOTO QUIT
                  END
               END

               IF EXISTS ( SELECT 1
                           FROM PICKDETAIL WITH (NOLOCK)
                           WHERE Lot = @c_Lot
                           AND   Loc = @c_ToLoc
                           AND   ID  = @c_ID
                           AND   Status < '9'
                           AND   ShipFlag <> 'Y'
                         )
               BEGIN
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
                     SET @n_err = 63710  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get MoveRefKey Failed. (isp_WOJobInvReverse)' 
                     GOTO QUIT
                  END 

                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN
                     UPDATE PICKDETAIL WITH (ROWLOCK)
                     SET MoveRefKey = @c_MoveRefKey
                        ,EditWho    = SUSER_NAME()
                        ,EditDate   = GETDATE()
                        ,Trafficcop = NULL
                     WHERE Lot = @c_Lot
                     AND   Loc = @c_ToLoc
                     AND   ID  = @c_ID

                     SET @n_err = @@ERROR 
                     IF @n_err <> 0    
                     BEGIN  
                        SET @n_continue = 3    
                        SET @n_err = 63715   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                        SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table PICKDETIAL. (isp_WOJobInvReverse)' 
                        GOTO QUIT
                     END 
                  END
               END
            END

            EXEC nspItrnAddMove                   
                  NULL          
               ,  @c_StorerKey      
               ,  @c_Sku               
               ,  @c_Lot                 
               ,  @c_ToLoc               
               ,  @c_ID              
               ,  @c_FromLoc          
               ,  @c_ID  
               ,  ''           
               ,  ''         --lottable01
               ,  ''         --lottable02
               ,  ''         --lottable03
               ,  NULL       --lottable04
               ,  NULL       --lottable05
               ,  ''         --lottable06
               ,  ''         --lottable07
               ,  ''         --lottable08
               ,  ''         --lottable09
               ,  ''         --lottable10
               ,  ''         --lottable11
               ,  ''         --lottable12
               ,  NULL       --lottable13
               ,  NULL       --lottable14
               ,  NULL       --lottable15  
               ,  0         
               ,  0             
               ,  @n_Qty         
               ,  0             
               ,  0.00           
               ,  0.00           
               ,  0.00             
               ,  0.00             
               ,  0.00             
               ,  @c_SourceKey     
               ,  'isp_WOJobInvReverse'      
               ,  @c_PackKey         
               ,  @c_UOM                 
               ,  1             
               ,  NULL     
               ,  ''              
               ,  @b_Success        OUTPUT
               ,  @n_err            OUTPUT
               ,  @c_errmsg         OUTPUT
               ,  @c_MoveRefKey

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63720  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error Reversing Stock to Original Location. (isp_WOJobInvReverse)' 
               GOTO QUIT
            END

            FETCH NEXT FROM CUR_ID INTO @c_Storerkey
                                       ,@c_Sku
                                       ,@c_Lot
                                       ,@n_Qty
         END
         CLOSE CUR_ID
         DEALLOCATE CUR_ID
     
         UPDATE WORKORDERJOBMOVE WITH (ROWLOCK)
         SET Status      = CASE WHEN Qty - @n_MoveQty = 0 THEN 'R' ELSE Status END
            ,Qty         = Qty - @n_MoveQty
            ,EditWho     = SUSER_NAME()
            ,EditDate    = GETDATE()
            ,Trafficcop  = NULL  
         WHERE  WOMoveKey = @c_WOMoveKey

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63725  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBMOVE. (isp_WOJobInvReserve)' 
            GOTO QUIT
         END

         SET @n_QtyToMove = @n_QtyToMove + @n_MoveQty

         FETCH NEXT FROM WOJM_CUR INTO @c_WOMoveKey
                                    ,  @c_JobLineNo
                                    ,  @c_aLot
                                    ,  @c_FromLoc
                                    ,  @c_ToLoc
                                    ,  @c_ID
                                    ,  @n_MoveQty 
                                    ,  @c_PickMethod
      END 
      CLOSE WOJM_CUR
      DEALLOCATE WOJM_CUR


      SET @n_QtyReserved= @n_QtyReserved - @n_QtyToMove
      
      UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
      SET QtyReserved = @n_QtyReserved 
         ,EditWho     = SUSER_NAME()
         ,EditDate    = GETDATE()
      WHERE JobKey = @c_JobKey
      AND   JobLine= @c_JobLineNo

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63730  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (isp_WOJobInvReverse)' 
         GOTO QUIT
      END

      FETCH NEXT FROM WOJO_CUR INTO @c_JobLineNo
                                 ,  @n_StepQty
                                 ,  @n_QtyReserved


   END 
   CLOSE WOJO_CUR
   DEALLOCATE WOJO_CUR
*/
   QUIT:

   IF CURSOR_STATUS( 'LOCAL', 'WOJO_CUR') in (0 , 1)  
   BEGIN
      CLOSE WOJO_CUR
      DEALLOCATE WOJO_CUR
   END

   IF CURSOR_STATUS( 'LOCAL', 'WOJM_CUR') in (0 , 1)  
   BEGIN
      CLOSE WOJM_CUR
      DEALLOCATE WOJM_CUR
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_ID') in (0 , 1)  
   BEGIN
      CLOSE CUR_ID
      DEALLOCATE CUR_ID
   END
--(Wan01) - START
--   WHILE @@TRANCOUNT < @n_StartTCnt
--   BEGIN
--      BEGIN TRAN
--   END

--(Wan01) - END

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
      --execute nsp_logerror @n_err, @c_errmsg, 'isp_WOJobInvReverse'
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