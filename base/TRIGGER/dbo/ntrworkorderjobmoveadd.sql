SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrWorkOrderJobMoveAdd                                         */
/* Creation Date: 12-Jan-2016                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: WorkorderJobMove Insert Trigger                                */
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
/* Date         Author  Ver   Purposes                                     */
/* 04-FEB-2016  Wan01   1.1   SOS#361353 - Project Merlion -SKU Reservation*/
/*                            Pallet Selection                             */
/***************************************************************************/
CREATE TRIGGER ntrWorkOrderJobMoveAdd ON WORKORDERJOBMOVE
FOR INSERT
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
         , @n_WOMovekey       INT         -- (Wan01)
         , @n_ReservedIDCnt   INT         -- (Wan01)

   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT   

   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SET @n_continue = 4
      GOTO QUIT
   END

   IF @n_Continue=1 or @n_Continue=2          
   BEGIN
      IF EXISTS (SELECT 1 FROM INSERTED i  
                 JOIN storerconfig s WITH (NOLOCK) ON  i.storerkey = s.storerkey    
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
                   'INSERT'  --@c_Action
                 , @b_Success  OUTPUT  
                 , @n_Err      OUTPUT   
                 , @c_ErrMsg   OUTPUT  

         IF @b_success <> 1  
         BEGIN  
            SET @n_continue = 3  
            SET @c_errmsg = 'ntrWorkOrderJobMoveAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
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
               FROM INSERTED 
               WHERE FromLoc = ToLoc
               AND PickMethod <> '1'
             )
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63705  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='Not Allow to reserve stock in VAS reserved Location. (ntrWorkOrderJobMoveAdd)'
      GOTO QUIT
   END

   IF EXISTS ( SELECT 1
               FROM INSERTED 
               WHERE (RTRIM(ID) = '' OR ID IS NULL)
               AND PickMethod = '1'
             )
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63710  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='Not Allow to reserve blank ID when pull by pallet. (ntrWorkOrderJobMoveAdd)'
      GOTO QUIT
   END

   --(Wan01) - START
   -- To Exclude VAP loc from Manual Reserve must setup in COdelkup = 'MRSVXCLLOC' AND Code = {Loc}
   IF EXISTS ( SELECT 1
               FROM INSERTED 
               JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.ListName = 'MRSVXCLLOC')
                                           AND(INSERTED.FromLoc = CODELKUP.Code)
             )
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63705  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='Not Allow to reserve stock in VAS Restricted Location. (ntrWorkOrderJobMoveAdd)'
      GOTO QUIT
   END
   --(Wan01) - END

   IF EXISTS ( SELECT 1 
               FROM WORKORDERJOBOPERATION WOJO WITH (NOLOCK)
               WHERE EXISTS ( SELECT 1
                              FROM INSERTED 
                              WHERE INSERTED.JobKey = WOJO.JobKey  
                              AND   INSERTED.JobLine= WOJO.JobLine  
                              GROUP BY INSERTED.JobKey
                                     , INSERTED.JobLine
                              HAVING WOJO.StepQty - WOJO.QtyReserved < SUM(INSERTED.Qty)
                             )
             )
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63715  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='Qty Reserved > Qty Required. (ntrWorkOrderJobMoveAdd)'
      GOTO QUIT
   END   

   DECLARE CUR_RSV CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT INSERTED.WOMovekey                          --(Wan01)
         ,INSERTED.JobKey
         ,INSERTED.JobLine
         ,INSERTED.Storerkey
         ,INSERTED.Sku
         ,INSERTED.Lot
         ,INSERTED.FromLoc
         ,INSERTED.ToLoc
         ,INSERTED.ID
         ,INSERTED.PickMethod
         ,INSERTED.Qty
   FROM INSERTED 

   OPEN CUR_RSV
   FETCH NEXT FROM CUR_RSV INTO @n_WOMovekey          --(Wan01)
                              , @c_JobKey
                              , @c_JobLineNo
                              , @c_Storerkey
                              , @c_Sku
                              , @c_Lot
                              , @c_FromLoc
                              , @c_ToLoc
                              , @c_ID
                              , @c_PickMethod
                              , @n_Qty


   WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
   BEGIN
      SET @c_SourceKey = @c_JobKey + @c_JobLineNo

      --(Wan01) - START
      SET @c_OriginalLoc = @c_FromLoc   

      IF @n_Qty <= 0 
      BEGIN   
         GOTO NEXT_REC  
      END 
      --(Wan01) - END         

      IF @c_PickMethod = '1'
      BEGIN
         --(Wan02) - START
         SET @n_ReservedIDCnt = 0
         SELECT TOP 1 @c_OriginalLoc = OriginalLoc
               ,      @n_ReservedIDCnt = 1
         FROM WORKORDERJOBMOVE WITH (NOLOCK)
         WHERE JobKey = @c_JobKey
         AND   ID = @c_ID
         AND   Qty > 0
         AND   Status < '9'
         AND   OriginalLoc <> '' 

         IF @n_ReservedIDCnt = 1 
         BEGIN
            GOTO NEXT_REC  
         END 
         --(Wan02) - END

         DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Storerkey
               ,Sku
               ,Lot
               ,Qty
         FROM LOTxLOCxID WITH (NOLOCK)
         WHERE Loc = @c_FromLoc
         AND   ID  = @c_ID
         AND   Qty > 0
         AND   @c_OriginalLoc <> @c_ToLoc             --(Wan01)
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
         AND   Loc = @c_FromLoc
         AND   ID  = @c_ID
         AND   Qty > 0
         AND   @c_OriginalLoc <> @c_ToLoc             --(Wan01)
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
           IF NOT EXISTS ( SELECT 1
                           FROM ID WITH (NOLOCK)
                           WHERE Id = @c_ID
                           AND Status = 'HOLD'
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
                  '1',              -- hold
                  @b_success OUTPUT,
                  @n_err OUTPUT,
                  @c_errmsg OUTPUT,
                  'VAS ASRS ID'     -- remark

               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 63720
                  SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Hold ID Fail. (ntrWorkOrderJobMoveAdd)' 
                                      + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '
               END
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               IF EXISTS ( SELECT 1
                           FROM PICKDETAIL WITH (NOLOCK)
                           WHERE Lot = @c_Lot
                           AND   Loc = @c_FromLoc
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
                     SET @n_err = 63725  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get MoveRefKey Failed. (ntrWorkOrderJobMoveAdd)' 
                  END 
            

                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN
                     UPDATE PICKDETAIL WITH (ROWLOCK)
                     SET MoveRefKey = @c_MoveRefKey
                        ,EditWho    = SUSER_NAME()
                        ,EditDate   = GETDATE()
                        ,Trafficcop = NULL
                     WHERE LOT = @c_Lot
                     AND   Loc = @c_FromLoc
                     AND   ID  = @c_ID
                     AND   Status < '9'
                     AND   ShipFlag <> 'Y'

                     SET @n_err = @@ERROR 
                     IF @n_err <> 0    
                     BEGIN  
                        SET @n_continue = 3    
                        SET @n_err = 63730   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                        SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table PICKDETIAL. (ntrWorkOrderJobMoveAdd)' 
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
               ,   @c_FromLoc
               ,   @c_ID
               ,   @c_ToLoc
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
               ,   'ntrWorkOrderJobMoveAdd'
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
               SET @n_err     = 63735  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error Moving Stock to Virtual Location. (ntrWorkOrderJobMoveAdd)' 
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

      --(Wan01) - START
      NEXT_REC:
      IF @n_Continue = 1 OR @n_Continue = 2
      BEGIN
         UPDATE WORKORDERJOBMOVE WITH (ROWLOCK)
         SET  OriginalLoc= @c_OriginalLoc
            , EditWho    = SUser_Name()
            , EditDate   = GetDate()
            , Trafficcop = NULL
         WHERE WOMoveKey = @n_WOMovekey

         SET @n_Err = @@ERROR
         IF @n_Err <> 0  
         BEGIN
            SET @n_Continue= 3
            SET @n_Err     = 63740 
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update fail on to Table WORKORDERJOBMOVE. (ntrWorkOrderJobMoveAdd)' 
         END
      END
      --(Wan01) - END

      IF @n_Continue = 1 OR @n_Continue = 2
      BEGIN
         UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
         SET QtyReserved = QtyReserved + @n_Qty
            ,EditWho     = SUSER_NAME()
            ,EditDate    = GETDATE()
         WHERE JobKey = @c_JobKey
         AND   JobLine= @c_JobLineNo

         SET @n_Err = @@ERROR
         IF @n_Err <> 0  
         BEGIN
            SET @n_Continue= 3
            SET @n_Err     = 63745 
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update fail on to Table WORKORDERJOBOPERATION. (ntrWorkOrderJobMoveAdd)' 
         END
      END

      FETCH NEXT FROM CUR_RSV INTO @n_WOMovekey
                                 , @c_JobKey
                                 , @c_JobLineNo
                                 , @c_Storerkey
                                 , @c_Sku
                                 , @c_Lot
                                 , @c_FromLoc
                                 , @c_ToLoc
                                 , @c_ID
                                 , @c_PickMethod
                                 , @n_Qty

   END 
   CLOSE CUR_RSV
   DEALLOCATE CUR_RSV
QUIT:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_RSV') in (0 , 1)  
   BEGIN
      CLOSE CUR_RSV
      DEALLOCATE CUR_RSV
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderJobMoveAdd'    
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