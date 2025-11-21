SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrBooking_OutDelete                                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  SOS#322304 - PH - CPPI WMS Door Booking Enhancement        */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records Deleted                                      */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 19MAY2015   YTWan    1.1   SOS#341308 - PH CPPI Allow Deletion for   */
/*                            Finalized Booking (Wan01)                 */ 
/* 2022-03-03  Wan02    1.2   LFWM-3336 - Door Booking SPsDB queries    */
/*                            clarification                             */
/* 2022-03-03  Wan02    1.2   LFWM-3336 - Door Booking SPsDB queries    */
/*                            clarification                             */
/* 2022-07-15  Wan03    1.3   As Per LFWM-3336 Technical Spec, Should not*/
/*                            allow to delete closed Booking            */
/*                            To be same as Exceed to check Allowdelete */
/*                            if FinalizeFlag = 'Y'                     */
/************************************************************************/

CREATE   TRIGGER [dbo].[ntrBooking_OutDelete]
ON  [dbo].[Booking_Out]
FOR DELETE
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
            @b_Success        int       -- Populated by calls to stored procedures - was the proc successful?
   ,        @n_err            int       -- Error number returned by stored procedure or this trigger
   ,        @c_errmsg         NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,        @n_Continue       int
   ,        @n_StartTCnt      int       -- Holds the current transaction count

   ,        @n_BookingNo            INT
   ,        @c_Loadkey              NVARCHAR(10)   --(Wan01)
   ,        @c_finalizeflag         NVARCHAR(10)   --(Wan01)

   ,        @c_Facility             NVARCHAR(5)    --(Wan01)
   ,        @c_StorerKey            NVARCHAR(15)   --(Wan01)
   ,        @c_AllowDelFinalizedBKO NVARCHAR(10)   --(Wan01)
   
   ,        @n_RowRef_SHPM          INT            --(Wan02)
   ,        @c_ShipmentGID          NVARCHAR(50)   --(Wan02)
   ,        @c_Loadkey_BO           NVARCHAR(10)   --(Wan03)
   ,        @c_MBOLkey_BO           NVARCHAR(10)   --(Wan03)
   ,        @c_Status_BO            NVARCHAR(10)   --(Wan03)
   
   DECLARE @CUR_BKO                 CURSOR         --(Wan02) 
         , @CUR_LOAD                CURSOR         --(Wan02)
         , @CUR_SHPM                CURSOR         --(Wan02)
 
   SET @n_Continue=1
   SET @n_StartTCnt=@@TRANCOUNT

   IF (SELECT COUNT(1) FROM DELETED) =
      (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9')
   BEGIN
      SET @n_Continue = 4
   END
   --(Wan02) - START 
  
   IF (@n_Continue=1 OR @n_Continue=2) 
   BEGIN 
      SET @CUR_BKO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Deleted.Facility
            ,Deleted.BookingNo
            ,Deleted.FinalizeFlag
            ,Loadkey = ISNULL(Deleted.Loadkey,'')              --(Wan03)
            ,MBOLkey = ISNULL(Deleted.MBOLKey,'')              --(Wan03)
            ,Deleted.[Status]                                  --(Wan03)
      FROM DELETED
      ORDER BY Deleted.BookingNo
      
      OPEN @CUR_BKO
      
      FETCH NEXT FROM @CUR_BKO INTO @c_Facility
                                 ,  @n_BookingNo
                                 ,  @c_finalizeflag
                                 ,  @c_Loadkey_BO              --(Wan03)
                                 ,  @c_MBOLkey_BO              --(Wan03) 
                                 ,  @c_Status_BO               --(Wan03)                                  
      
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
      BEGIN
         --(Wan03) - START
         IF @c_Status_BO = '9'
         BEGIN
            SET @n_Continue = 3
            SET @n_err=74906   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Not allow to delete closed booking. (ntrBooking_OutDelete)'
            GOTO QUIT_TR
         END
         
         IF @c_finalizeflag = 'Y' AND (@c_Loadkey_BO <> '' OR @c_MBOLkey_BO <> '')
         BEGIN
            IF NOT EXISTS  (  SELECT 1       
                              FROM LOADPLAN WITH (NOLOCK)
                              WHERE LOADPLAN.BookingNo = @n_BookingNo
                           )
            BEGIN
               SET @n_Continue = 3
               SET @n_err=74905   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Not allow to delete finalized booking. (ntrBooking_OutDelete)'
               GOTO QUIT_TR
            END
         END
         --(Wan03) - END
      
         SET @CUR_LOAD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT lp.LoadKey
         FROM dbo.LoadPlan AS lp WITH (NOLOCK)
         WHERE lp.BookingNo = @n_BookingNo
         ORDER BY lp.LoadKey
      
         OPEN @CUR_LOAD
      
         FETCH NEXT FROM @CUR_LOAD INTO @c_Loadkey
      
         WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
         BEGIN
            IF @c_finalizeflag = 'Y'                  -- (Wan03)
            BEGIN
               SET @c_Storerkey= ''
               SELECT TOP 1 @c_Storerkey = o.Storerkey
               FROM dbo.LoadPlanDetail AS lpd WITH (NOLOCK)
               JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey
               WHERE lpd.LoadKey = @c_Loadkey
               ORDER BY lpd.LoadLineNumber
               
               SET @c_AllowDelFinalizedBKO = ''
               SELECT @c_AllowDelFinalizedBKO = dbo.fnc_GetRight(@c_Facility, @c_StorerKey, '', 'AllowDelFinalizedBKO')
            
               IF @c_AllowDelFinalizedBKO IN ('1')
               BEGIN
                  IF EXISTS (SELECT 1
                             FROM dbo.TaskDetail AS td WITH (NOLOCK)
                             WHERE td.Loadkey = @c_Loadkey
                             AND Status <> 'X'
                            )
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_err=74915  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Loadkey Released. Not allow to delete booking.'
                                  +' (ntrBooking_OutDelete)'
                     GOTO QUIT_TR 
                  END
               END
               ELSE IF @c_AllowDelFinalizedBKO IN ('', '0')
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err=74920  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Not allow to delete finalized booking.'
                               +' (ntrBooking_OutDelete)'
                  GOTO QUIT_TR  
               END            
            END                                    -- (Wan03)
            FETCH NEXT FROM @CUR_LOAD INTO @c_Loadkey
         END
         CLOSE @CUR_LOAD
         DEALLOCATE @CUR_LOAD 
         
         SET @CUR_SHPM = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ts.RowRef
               ,ts.ShipmentGID
         FROM dbo.TMS_Shipment AS ts WITH (NOLOCK)
         WHERE ts.BookingNo = @n_BookingNo
         ORDER BY ts.ShipmentGID
      
         OPEN @CUR_SHPM
      
         FETCH NEXT FROM @CUR_SHPM INTO @n_RowRef_SHPM
                                       ,@c_ShipmentGID
      
         WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
         BEGIN
            IF @c_finalizeflag = 'Y'               -- (Wan03) 
            BEGIN
               SELECT TOP 1 @c_StorerKey = o.StorerKey
               FROM dbo.TMS_ShipmentTransOrderLink AS tstol WITH (NOLOCK)
               JOIN dbo.TMS_TransportOrder AS tto WITH (NOLOCK) ON tto.ProvShipmentID = tstol.ProvShipmentID
               JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = tto.OrderSourceID
               WHERE tstol.ShipmentGID = @c_ShipmentGID
               ORDER BY tto.Rowref
               
               SET @c_AllowDelFinalizedBKO = ''
               SELECT @c_AllowDelFinalizedBKO = dbo.fnc_GetRight(@c_Facility, @c_StorerKey, '', 'AllowDelFinalizedBKO')
            
               IF @c_AllowDelFinalizedBKO IN ('', '0')
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err=74920  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Not allow to delete finalized booking.'
                               +' (ntrBooking_OutDelete)'
                  GOTO QUIT_TR               
               END
            END                                    -- (Wan03)
            
            UPDATE dbo.TMS_Shipment WITH (ROWLOCK)
            SET BookingNo = 0                      -- (Wan03)
               ,Editwho = SUSER_NAME()
               ,EditDate= GETDATE()
            WHERE Rowref = @n_RowRef_SHPM
            
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_errmsg = CONVERT(CHAR(250),@n_err)
               SET @n_err=74910   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update TMS_Shipment Fail. (ntrBooking_OutDelete)'
               GOTO QUIT_TR 
            END
            
            FETCH NEXT FROM @CUR_SHPM INTO @n_RowRef_SHPM
                                          ,@c_ShipmentGID
         END
         CLOSE @CUR_SHPM
         DEALLOCATE @CUR_SHPM 
         
         FETCH NEXT FROM @CUR_BKO INTO @c_Facility
                                    ,  @n_BookingNo
                                    ,  @c_finalizeflag 
                                    ,  @c_Loadkey_BO           --(Wan03)
                                    ,  @c_MBOLkey_BO           --(Wan03) 
                                    ,  @c_Status_BO            --(Wan03) 
            
      END
      CLOSE @CUR_BKO
      DEALLOCATE @CUR_BKO
   END
   
   /*
   IF (@n_Continue=1 OR @n_Continue=2) 
   BEGIN
      --(Wan01) - START  
      SET @n_BookingNo=0
      SET @c_Facility = ''
      SET @c_finalizeflag = ''
      SELECT @n_BookingNo    = ISNULL(DELETED.BookingNo,0)
            ,@c_Facility     = ISNULL(Facility,'')
            ,@c_finalizeflag = ISNULL(DELETED.finalizeflag,'N')
      FROM DELETED

      IF @c_finalizeflag = 'Y'
      BEGIN
         IF NOT EXISTS  (  SELECT 1       
                           FROM LOADPLAN WITH (NOLOCK)
                           WHERE LOADPLAN.BookingNo = @n_BookingNo
                        )
         BEGIN
            SET @n_Continue = 3
            SET @n_err=74905   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Not allow to delete finalized booking. (ntrBooking_OutDelete)'
            GOTO QUIT_TR
         END
      END
   END

   IF (@n_Continue=1 OR @n_Continue=2) 
   BEGIN
--   
--      UPDATE LOADPLAN WITH (ROWLOCK)
--      SET BookingNo  = 0 
--        , TrafficCop = NULL
--        , EditDate   = GETDATE()
--        , EditWho    = SUSER_NAME()      
--      WHERE BookingNo = @n_BookingNo 
--     
--      IF @@ERROR <> 0
--      BEGIN
--         SET @n_Continue = 3
--         SET @c_errmsg = CONVERT(CHAR(250),@n_err)
--         SET @n_err=74910   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Error on Booking_Out. (ntrBooking_OutDelete)'
--                      + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(ISNULL(@c_errmsg,'')) + ' ) '
--         GOTO QUIT_TR
--      END

      DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Loadkey
      FROM LOADPLAN WITH (NOLOCK)  
      WHERE BookingNo = @n_BookingNo 

      OPEN CUR_LOAD

      FETCH NEXT FROM CUR_LOAD INTO @c_Loadkey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_finalizeflag = 'Y'
         BEGIN
            SET @c_Storerkey= ''
            SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
            FROM ORDERS WITH (NOLOCK)  
            WHERE ORDERS.Loadkey = @c_Loadkey

            SET @b_success = 0
            Execute nspGetRight 
                    @c_facility 
                  , @c_StorerKey               -- Storer
                  , ''                         -- Sku
                  , 'AllowDelFinalizedBKO'     -- ConfigKey
                  , @b_success                  OUTPUT 
                  , @c_AllowDelFinalizedBKO     OUTPUT 
                  , @n_err                      OUTPUT 
                  , @c_errmsg                   OUTPUT
            
            IF @b_success <> 1
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 74910
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error getting Storerconfig AllowDelFinalizedBKO:' 
                             + RTRIM(@c_errmsg) + '. (ntrBooking_OutDelete)'
               GOTO QUIT_TR
            END
        
            IF @c_AllowDelFinalizedBKO = '1'
            BEGIN
               IF EXISTS (SELECT 1
                          FROM TASKDETAIL WITH (NOLOCK)
                          WHERE Loadkey = @c_Loadkey
                          AND Status <> 'X'
                         )
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err=74915  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Loadkey Released. Not allow to delete booking.'
                               +' (ntrBooking_OutDelete)'
                  GOTO QUIT_TR 
               END
            END
            ELSE
            BEGIN
               SET @n_Continue = 3
               SET @n_err=74920  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Not allow to delete finalized booking.'
                            +' (ntrBooking_OutDelete)'
               GOTO QUIT_TR   
            END
         END

         SET @b_Success = 0  
         EXEC dbo.ispBookingOutLoadDelete 
                 @c_Loadkey = @c_Loadkey
               , @b_Success = @b_Success     OUTPUT  
               , @n_Err     = @n_err         OUTPUT   
               , @c_ErrMsg  = @c_errmsg      OUTPUT  

         IF @n_err <> 0 OR @b_Success <> 1 
         BEGIN 
            SET @n_Continue= 3 
            SET @b_Success = 0
            SET @n_err  = 74925
            SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Fail to Exec ispBookingOutLoadDelete.'
                          + '(' + @c_errmsg + ') (ntrBooking_OutDelete)'

            GOTO QUIT_TR
         END   

         FETCH NEXT FROM CUR_LOAD INTO @c_Loadkey
      END
      CLOSE CUR_LOAD
      DEALLOCATE CUR_LOAD 
      ----(Wan01) - END               
   END
   */
   --(Wan02) - END
   QUIT_TR:

   --(Wan02) - START
   --IF CURSOR_STATUS('LOCAL' , 'CUR_LOAD') in (0 , 1)
   --BEGIN
   --   CLOSE CUR_LOAD
   --   DEALLOCATE CUR_LOAD
   --END
   --(Wan04) - END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrBooking_OutDelete'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
       COMMIT TRAN
      END
      RETURN
   END
END

GO