SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrWorkOrderJobMoveDelete                                      */
/* Creation Date: 12-Jan-2016                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: WorkorderJobMove Delete Trigger                                */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Inserted                                        */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author   Ver  Purposes                                     */
/* 04-FEB-2016  Wan01   1.1   SOS#361353 - Project Merlion -SKU Reservation*/
/*                            Pallet Selection                             */
/***************************************************************************/
CREATE TRIGGER ntrWorkOrderJobMoveDelete ON WORKORDERJOBMOVE
FOR DELETE
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT                     
         , @n_StartTCnt       INT            -- Holds the current transaction count    
         , @b_Success         INT            -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err             INT            -- Error number returned by stored procedure or this trigger    
         , @c_errmsg          NVARCHAR(255)  -- Error message returned by stored procedure or this trigger    

         , @b_debug           INT
         , @c_authority       NVARCHAR(10)

         , @c_SourceKey       NVARCHAR(15)
         , @c_MoveRefKey      NVARCHAR(10)
         , @c_JobKey          NVARCHAR(10)
         , @c_JobLineNo       NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @c_Packkey         NVARCHAR(10)
         , @c_UOM             NVARCHAR(10)
         , @c_Lot             NVARCHAR(10)
         , @c_FromLoc         NVARCHAR(10)
         , @c_ToLoc           NVARCHAR(10)
         , @c_OriginalLoc     NVARCHAR(10)
         , @c_ID              NVARCHAR(10)
         , @c_PickMethod      NVARCHAR(10)
         , @n_Qty             INT
         , @n_QtyToMove       INT 

   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT   

   IF EXISTS( SELECT 1 FROM DELETED WHERE ArchiveCop = '9')
   BEGIN
      SET @n_continue = 4
      GOTO QUIT
   END

   IF @n_continue=1 or @n_continue=2          
   BEGIN
      IF EXISTS (SELECT 1 FROM DELETED d  
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey    
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'JobMoveTrigger_SP')  
      BEGIN        	  
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
         BEGIN
            DROP TABLE #INSERTED
         END
   
         SELECT * 
         INTO #INSERTED
         FROM INSERTED
            
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
         BEGIN
            DROP TABLE #DELETED
         END
   
         SELECT * 
         INTO #DELETED
         FROM DELETED
   
         EXECUTE dbo.isp_JobMoveTrigger_Wrapper
                   'DELETE'  --@c_Action
                 , @b_Success  OUTPUT  
                 , @n_Err      OUTPUT   
                 , @c_ErrMsg   OUTPUT  
   
         IF @b_success <> 1  
         BEGIN  
            SET @n_continue = 3  
            SET @c_errmsg = 'ntrWorkOrderJobMoveDelete ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
         END  
         
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
         BEGIN
            DROP TABLE #INSERTED
         END
   
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
         BEGIN
            DROP TABLE #DELETED
         END
      END
   END     

   IF EXISTS ( SELECT 1
               FROM DELETED 
               JOIN JOBTASKLOOKUP TLKUP WITH (NOLOCK) ON (DELETED.JobKey = TLKUP.JobKey)
                                                      AND(DELETED.JobLine = TLKUP.JobLine)
                                                      AND(DELETED.WOMoveKey = TLKUP.WOMoveKey)
               JOIN TASKDETAIL WITH (NOLOCK) ON (TLKUP.Taskdetailkey = TASKDETAIL.GroupKey)
               WHERE TASKDETAIL.Status NOT IN ('X')
             ) 
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63710
      SET @c_ErrMsg='Task in Progress/Completed. Not Allow to reverse Inventory. (ntrWorkOrderJobMoveDelete)' 
      GOTO QUIT               
   END

   IF EXISTS ( SELECT 1
               FROM DELETED 
               JOIN LOTxLOCxID WITH (NOLOCK) ON  (DELETED.Lot   = LOTxLOCxID.Lot)
                                             AND (DELETED.ToLoc = LOTxLOCxID.Loc)
                                             AND (DELETED.ID    = LOTxLOCxID.ID)
               WHERE LOTxLOCxID.Qty = 0
               AND DELETED.Qty > 0
             )
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63715
      SET @c_ErrMsg='Inventory Not in reserved Location. Not Allow to reverse Inventory. (ntrWorkOrderJobMoveDelete)' 
      GOTO QUIT               
   END   
  
   DECLARE CUR_RVS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DELETED.JobKey
         ,DELETED.JobLine
         ,DELETED.Storerkey
         ,DELETED.Sku
         ,DELETED.Lot
         ,DELETED.FromLoc
         ,DELETED.ToLoc
         ,DELETED.OriginalLoc                         --(Wan01)
         ,DELETED.ID
         ,DELETED.PickMethod
         ,DELETED.Qty
   FROM DELETED 
   WHERE DELETED.Qty > 0
   AND   DELETED.Status < '9'

   OPEN CUR_RVS
   FETCH NEXT FROM CUR_RVS INTO @c_JobKey
                              , @c_JobLineNo
                              , @c_Storerkey
                              , @c_Sku
                              , @c_Lot
                              , @c_FromLoc
                              , @c_ToLoc
                              , @c_OriginalLoc        --(Wan01)
                              , @c_ID
                              , @c_PickMethod
                              , @n_Qty


   WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
   BEGIN
      SET @c_SourceKey = @c_JobKey + @c_JobLineNo

      IF @c_PickMethod = '1'
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM LOTxLOCxID WITH (NOLOCK) 
                     WHERE LOTxLOCxID.ID = @c_ID
                     AND   LOTxLOCxID.Qty > 0 
                     GROUP BY LOTxLOCxID.ID
                     HAVING COUNT( DISTINCT LOTxLOCxID.Loc ) > 1
                    )
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63720
            SET @c_ErrMsg='ID Found in Multiple Location. Not Allow to reverse Inventory. (ntrWorkOrderJobMoveDelete)' 
            GOTO QUIT               
         END   

         IF EXISTS ( SELECT 1  
                     FROM WORKORDERJOBMOVE WITH (NOLOCK)
                     WHERE JobKey = @c_JobKey
                     AND   ID = @c_ID  
                     AND   Qty > 0  
                     )
         BEGIN
            GOTO NEXT_REC
         END

         DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Storerkey
               ,Sku
               ,Lot
               ,Qty
         FROM LOTxLOCxID WITH (NOLOCK)
         WHERE Loc = @c_ToLoc
         AND   ID  = @c_ID
         AND   Qty > 0
         AND   @c_OriginalLoc <> @c_ToLoc                --(Wan01)
      END
      ELSE
      BEGIN
         DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Storerkey
               ,Sku
               ,Lot
               ,@n_Qty
         FROM LOTxLOCxID WITH (NOLOCK)
         WHERE Lot = @c_Lot
         AND   Loc = @c_ToLoc
         AND   ID  = @c_ID
         AND   Qty > 0
         AND   @c_OriginalLoc <> @c_ToLoc                --(Wan01)
      END

      OPEN CUR_ID
      FETCH NEXT FROM CUR_ID INTO @c_Storerkey
                                 ,@c_Sku
                                 ,@c_Lot
                                 ,@n_QtyToMove

      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
      BEGIN
         SET @c_Packkey = ''
         SELECT @c_Packkey = Packkey
         FROM SKU WITH (NOLOCK) 
         WHERE Storerkey = @c_Storerkey
         AND   Sku = @c_Sku

         SET @c_UOM = ''
         SELECT @c_UOM = PackUOM3
         FROM PACK WITH (NOLOCK)
         WHERE Packkey = @c_Packkey

         SET @c_MoveRefKey = ''

         IF @c_PickMethod = '1'
         BEGIN
           IF EXISTS (  SELECT 1
                        FROM INVENTORYHOLD WITH (NOLOCK)
                        WHERE Id = @c_ID
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
                  'VAS ASRS ID'     -- remark

               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 63725
                  SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Hold ID Fail. (ntrWorkOrderJobMoveDelete)' 
                                      + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '
               END
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
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
                  EXECUTE nspg_getkey    
                        'MoveRefKey'    
                       , 10    
                       , @c_MoveRefKey       OUTPUT    
                       , @b_success          OUTPUT    
                       , @n_err              OUTPUT    
                       , @c_errmsg           OUTPUT 

                  IF NOT @b_success = 1    
                  BEGIN    
                     SET @n_continue = 3    
                     SET @n_err = 63708  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get MoveRefKey Failed. (ntrWorkOrderJobMoveDelete)' 
                  END 
            

                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN
                     UPDATE PICKDETAIL WITH (ROWLOCK)
                     SET MoveRefKey = @c_MoveRefKey
                        ,EditWho    = SUSER_NAME()
                        ,EditDate   = GETDATE()
                        ,Trafficcop = NULL
                     WHERE LOT = @c_Lot
                     AND   Loc = @c_ToLoc
                     AND   ID  = @c_ID
                     AND   Status < '9'
                     AND   ShipFlag <> 'Y'

                     SET @n_err = @@ERROR 
                     IF @n_err <> 0    
                     BEGIN  
                        SET @n_continue = 3    
                        SET @n_err = 63709   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                        SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table PICKDETIAL. (ntrWorkOrderJobMoveDelete)' 
                     END 
                  END
               END
            END
         END

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            EXEC nspItrnAddMove
                   NULL
               ,   @c_StorerKey
               ,   @c_Sku
               ,   @c_Lot
               ,   @c_ToLoc
               ,   @c_ID
               ,   @c_OriginalLoc
               ,   @c_ID
               ,   ''         --Status
               ,   ''         --lottable01
               ,   ''         --lottable02
               ,   ''         --lottable03
               ,   NULL       --lottable04
               ,   NULL       --lottable05
               ,   ''         --lottable06
               ,   ''         --lottable07
               ,   ''         --lottable08
               ,   ''         --lottable09
               ,   ''         --lottable10
               ,   ''         --lottable11
               ,   ''         --lottable12
               ,   NULL       --lottable13
               ,   NULL       --lottable14
               ,   NULL       --lottable15
               ,   0
               ,   0
               ,   @n_QtyToMove
               ,   0
               ,   0.00
               ,   0.00
               ,   0.00
               ,   0.00
               ,   0.00
               ,   @c_SourceKey
               ,   'ntrWorkOrderJobMoveDelete'
               ,   @c_PackKey
               ,   @c_UOM
               ,   1
               ,   NULL
               ,   ''
               ,   @b_Success        OUTPUT
               ,   @n_err            OUTPUT
               ,   @c_errmsg         OUTPUT
               ,   @c_MoveRefKey     = @c_MoveRefKey 

            IF @n_err <> 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63710  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error Moving Stock to Virtual Location. (ntrWorkOrderJobMoveDelete)' 
            END
            IF @b_debug = 1
            BEGIN
               select 'itrnmove', @c_Lot, @c_ID, @c_FromLoc, @c_ToLoc,@n_QtyToMove 
            END
         END

         FETCH NEXT FROM CUR_ID INTO @c_Storerkey
                                    ,@c_Sku
                                    ,@c_Lot
                                    ,@n_QtyToMove
      END 
      CLOSE CUR_ID
      DEALLOCATE CUR_ID

      NEXT_REC:
      IF @n_Continue = 1 OR @n_Continue = 2
      BEGIN
         UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
         SET QtyReserved = QtyReserved - @n_Qty
            ,EditWho     = SUSER_NAME()
            ,EditDate    = GETDATE()
         WHERE JobKey = @c_JobKey
         AND   JobLine= @c_JobLineNo

         SET @n_Err = @@ERROR
         IF @n_Err <> 0  
         BEGIN
            SET @n_Continue= 3
            SET @n_Err     = 63715 
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update fail on to Table WORKORDERJOBOPERATION. (ntrWorkOrderJobMoveDelete)' 
         END
      END

      FETCH NEXT FROM CUR_RVS INTO @c_JobKey
                                 , @c_JobLineNo
                                 , @c_Storerkey
                                 , @c_Sku
                                 , @c_Lot
                                 , @c_FromLoc
                                 , @c_ToLoc
                                 , @c_OriginalLoc
                                 , @c_ID
                                 , @c_PickMethod
                                 , @n_Qty

   END 
   CLOSE CUR_RVS
   DEALLOCATE CUR_RVS

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS ( SELECT 1 FROM DELETED WHERE [STATUS] < '9')
      BEGIN
         SET @c_authority = 1
         SET @b_success = 0                     --    Start (KHLim02)
         EXECUTE nspGetRight  NULL             -- facility  
                           ,  NULL             -- Storerkey  
                           ,  NULL             -- Sku  
                           ,  'DataMartDELLOG' -- Configkey  
                           ,  @b_success     OUTPUT 
                           ,  @c_authority   OUTPUT 
                           ,  @n_err         OUTPUT 
                           ,  @c_errmsg      OUTPUT  

         IF @b_success <> 1
         BEGIN
            SET @n_continue = 3
            SET @n_err      = 63705
            SET @c_errmsg = 'ntrWorkOrderJobMoveDelete' + dbo.fnc_RTrim(@c_errmsg)
            GOTO QUIT
         END
         ELSE 
         IF @c_authority = '1'             
         BEGIN
            INSERT INTO dbo.WORKORDERJOBMOVE_DELLOG 
            ( WOMoveKey, JobKey, JobLine, Lot, FromLoc, ToLoc, ID, Qty, PickMethod, JobReservekey, OriginalLoc )
            SELECT WOMoveKey, JobKey, JobLine, Lot, FromLoc, ToLoc, ID, Qty, PickMethod, JobReservekey, OriginalLoc 
            FROM DELETED
            WHERE [STATUS] < '9'
   
            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(CHAR(250),@n_err)
               SET @n_err = 63710   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table PICKDETAIL Failed. (ntrWorkOrderJobMoveDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
               GOTO QUIT
            END
         END
      END
   END
QUIT:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_RVS') in (0 , 1)  
   BEGIN
      CLOSE CUR_RVS
      DEALLOCATE CUR_RVS
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_ID') in (0 , 1)  
   BEGIN
      CLOSE CUR_ID
      DEALLOCATE CUR_ID
   END

   /* #INCLUDE <TRRDA2.SQL> */    
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_starttcnt    
         BEGIN    
            COMMIT TRAN    
         END     
      END    

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderJobMoveDelete'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR  

      RETURN    
   END    
   ELSE    
   BEGIN    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    

      RETURN    
   END      
END

GO