SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispBookingOutLoadDelete                                     */
/* Creation Date: 28-Sep-2014                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Booking Out Loadkey delete                                  */
/*        : SOS#322304 - PH - CPPI WMS Door Booking Enhancement         */
/* Called By: nep_n_cst_bookingoutload.of_deleteinstance                */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    Ver  Purposes                                  */
/* 19-MAY-2015 YTWan     1.1  SOS#341308 - PH CPPI Allow Deletion for   */
/*                            Finalized Booking (Wan01)                 */ 
/************************************************************************/
CREATE PROC [dbo].[ispBookingOutLoadDelete] 
            @c_Loadkey        NVARCHAR(10) 
         ,  @b_Success        INT = 0  OUTPUT 
         ,  @n_err            INT = 0  OUTPUT 
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @n_BookingNo             INT            --(Wan01)   
         , @c_Facility              NVARCHAR(5)    --(Wan01)
         , @c_StorerKey             NVARCHAR(15)   --(Wan01)
         , @c_AllowDelFinalizedBKO  NVARCHAR(10)   --(Wan01)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
     
   --(Wan01) - START
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SET @n_BookingNo=0
      SET @c_Facility = ''
      SET @c_Storerkey= ''
      SELECT TOP 1 @c_Facility  = LOADPLAN.Facility
            ,      @c_Storerkey = ORDERS.Storerkey
            ,      @n_BookingNo = LOADPLAN.BookingNo
      FROM LOADPLAN WITH (NOLOCK)
      JOIN ORDERS   WITH (NOLOCK) ON (LOADPLAN.Loadkey = ORDERS.Loadkey) 
      WHERE LOADPLAN.Loadkey = @c_Loadkey

      IF EXISTS ( SELECT 1 
                  FROM BOOKING_OUT WITH (NOLOCK)
                  WHERE BOOKING_OUT.BookingNo = @n_BookingNo
                  AND BOOKING_OUT.finalizeflag = 'Y'
                )
      BEGIN
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
            SET @n_continue = 3
            SET @n_err = 75005
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error getting Storerconfig AllowDelFinalizedBKO:' 
                          + RTRIM(@c_errmsg) + '. (ispBookingOutLoadDelete)'
            GOTO QUIT
         END
         IF @c_AllowDelFinalizedBKO = '1'
         BEGIN
 
            IF EXISTS (SELECT 1
                       FROM TASKDETAIL WITH (NOLOCK)
                       WHERE Loadkey = @c_Loadkey
                       AND Status <> 'X'
                      )
            BEGIN
               SET @n_continue = 3
               SET @n_err=75010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Loadkey Released. Not allow to delete booking.'
                            +' (ispBookingOutLoadDelete)'
               GOTO QUIT 
            END
         END
         ELSE
         BEGIN
            SET @n_continue = 3
            SET @n_err=75015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Not allow to delete finalized booking.'
                         +' (ispBookingOutLoadDelete)'
            GOTO QUIT   
         END
      END
   END
   --(Wan01) - END

   BEGIN TRAN
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN

      UPDATE LOADPLAN WITH (ROWLOCK)
      SET BookingNo = ''
         ,TrafficCop = NULL
         ,EditDate   = GETDATE()
         ,EditWho    = SUSER_NAME()
      WHERE LoadKey = @c_Loadkey

      SET @n_err = @@ERROR
      IF @n_err <> 0     
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 75020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete LOADPLAN Failed. (ispBookingOutLoadDelete)' 
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT
      END
   END 
QUIT:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispBookingOutLoadDelete'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END   
END -- procedure

GO