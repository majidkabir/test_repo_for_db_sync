SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispFinalizeBookingOut                                       */
/* Creation Date: 30-OCT-2014                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#322304 - PH - CPPI WMS Door Booking Enhancement         */ 
/*        : Finalize Booking Out                                        */
/* Called By: nep_n_cst_bookingout.Event ue_finalizeAll                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispFinalizeBookingOut] 
      @n_BookingNo      INT
   ,  @b_Success        INT   OUTPUT
   ,  @n_err            INT   OUTPUT
   ,  @c_errmsg         NVARCHAR(215)  OUTPUT
AS
BEGIN
   DECLARE @n_StartTranCnt       INT
         , @n_Continue           INT 

         , @c_SQL                NVARCHAR(4000)
         , @c_Facility           NVARCHAR(5)
         , @c_Storerkey          NVARCHAR(10)
         , @c_Bayoutloc          NVARCHAR(10)
         , @c_Status             NVARCHAR(10)
         , @c_FinalizeFlag       NVARCHAR(1)

         , @c_BKOValidationRules NVARCHAR(10)

   SET @n_StartTranCnt = @@TRANCOUNT
   SET @n_Continue = 1
   
   SET @c_SQL        = ''
   SET @c_Facility   = ''
   SET @c_Storerkey  = ''
   SET @c_Bayoutloc  = ''
   SET @c_Status       = ''
   SET @c_FinalizeFlag = 'N' 

   SELECT @c_Status = Status 
      , @c_FinalizeFlag = Finalizeflag
      , @c_Bayoutloc = Loc
   FROM BOOKING_OUT WITH (NOLOCK) 
   WHERE BookingNo = @n_BookingNo

   IF @c_Status = '9'
   BEGIN
      SET @n_continue=3
      SET @n_err=72800
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize rejected. BOOKING OUT had been completed. (ispFinalizeBookingOut)'
      GOTO QUIT
   END

   IF @c_FinalizeFlag = 'Y'
   BEGIN
      SET @n_continue=3
      SET @n_err=72805
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize rejected. BOOKING OUT had been finalized. (ispFinalizeBookingOut)'
      GOTO QUIT
   END

   SELECT TOP 1 @c_Storerkey = ISNULL(ISNULL(OHL.Storerkey, ISNULL(OHM.Storerkey, OHC.Storerkey)),'') 
         , @c_Facility = BKO.Facility
   FROM BOOKING_OUT BKO    WITH (NOLOCK)
   LEFT JOIN LOADPLAN LP   WITH (NOLOCK) ON (BKO.BookingNo = LP.BookingNo) 
                                         OR ((BKO.Loadkey = LP.Loadkey)
                                         AND (ISNULL(BKO.Loadkey,'') <> '')
                                         AND (ISNULL(BKO.Loadkey,'') <> 'MULTI'))
   LEFT JOIN ORDERS   OHL  WITH (NOLOCK) ON (LP.Loadkey = OHL.Loadkey)
   LEFT JOIN ORDERS   OHM  WITH (NOLOCK) ON (BKO.MBOLKey = OHM.MBOLKey)  
                                         AND(ISNULL(BKO.MBOLKey,'') <> '')
                                         AND(ISNULL(BKO.MBOLKey,'') <> 'MULTI')
   LEFT JOIN MBOL     MB   WITH (NOLOCK) ON (BKO.CBOLKey = MB.CBOLKey) 
                                         AND(ISNULL(BKO.CBOLKey,0) > 0)
   LEFT JOIN ORDERS   OHC  WITH (NOLOCK) ON (MB.MBOLKey = OHC.MBOLKey)
                                         AND(ISNULL(MB.MBOLKey,'') <> '')
   WHERE BKO.BookingNo = @n_BookingNo

   IF @c_Storerkey <> '' 
   BEGIN
      SELECT @c_BKOValidationRules = SC.sValue
      FROM STORERCONFIG SC (NOLOCK)
      JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname
      WHERE SC.StorerKey = @c_StorerKey
      AND (SC.Facility = @c_Facility OR SC.Facility = '' OR SC.Facility IS NULL)
      AND SC.Configkey = 'BKOExtendedValidation'


      IF ISNULL(@c_BKOValidationRules,'') <> ''
      BEGIN
         EXEC isp_BKO_ExtendedValidation @n_BookingNo = @n_BookingNo 
                                      ,  @c_BKOValidationRules = @c_BKOValidationRules
                                      ,  @b_Success = @b_Success  OUTPUT
                                      ,  @c_ErrMsg  = @c_ErrMsg   OUTPUT


         IF @b_Success <> 1
         BEGIN
            SET @n_Continue = 3
            SET @n_err=72805
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Booking Out Extended Validation Failed. (ispFinalizeBookingOut)  ( '    
                                + RTRIM(@c_errmsg) + ' ) '
            GOTO QUIT  
         END
      END
      ELSE   
      BEGIN 
  
         SELECT @c_BKOValidationRules = SC.sValue    
         FROM STORERCONFIG SC (NOLOCK) 
         WHERE SC.StorerKey = @c_StorerKey 
         AND (SC.Facility = @c_Facility OR SC.Facility = '' OR SC.Facility IS NULL)
         AND SC.Configkey = 'BKOExtendedValidation'    
         
         IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_BKOValidationRules) AND type = 'P')          
         BEGIN  

       
            SET @c_SQL = 'EXEC ' + @c_BKOValidationRules + ' @n_BookingNo, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '          

            EXEC sp_executesql @c_SQL          
                , N'@n_BookingNo NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'
                , @n_BookingNo           
                , @b_Success  OUTPUT           
                , @n_Err      OUTPUT          
                , @c_ErrMsg   OUTPUT 
             
            IF @b_Success <> 1     
            BEGIN    
               SET @n_Continue = 3    
               SET @n_err=72810 
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Booking Out Extended Validation Failed. (ispFinalizeBookingOut)  ( '    
                                   + RTRIM(@c_errmsg) + ' ) '  
               GOTO QUIT
            END         
         END  
      END            
   END

   UPDATE ORDERS WITH (ROWLOCK)
   SET ORDERS.Door = @c_Bayoutloc
      ,EditWho = SUSER_NAME()
      ,EditDate= GETDATE()
      ,Trafficcop = NULL
   FROM ORDERS OH
   JOIN LOADPLAN LP    WITH (NOLOCK) ON (OH.Loadkey = LP.Loadkey)
   WHERE LP.BookingNo = @n_BookingNo
   
   IF @@ERROR <> 0
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = CONVERT(CHAR(250),@n_err)
      SET @n_err=72815  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE ORDERS Failed. (ispFinalizeBookingOut)  ( '    
                          + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
      GOTO QUIT
   END  

   UPDATE BOOKING_OUT WITH (ROWLOCK)
   SET FinalizeFlag = 'Y'
      ,EditWho = SUSER_NAME()
      ,EditDate= GETDATE()
      ,Trafficcop = NULL
   WHERE BookingNo = @n_BookingNo
   
   IF @@ERROR <> 0
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = CONVERT(CHAR(250),@n_err)
      SET @n_err=72815  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE BOOKING_OUT Failed. (ispFinalizeBookingOut)  ( '    
                          + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
      GOTO QUIT
   END  
QUIT:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispFinalizeBookingOut'

      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END   
END -- procedure

GO