SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrBooking_InUpdate                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* Called By: When records Updated                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.    Purposes                              */
/* 25-SEP-2013 NJOW01  1.0   288370-Create booking audit record         */   
/* 28-Oct-2013  TLTING    1.1     Review Editdate column update         */
/************************************************************************/

CREATE TRIGGER ntrBooking_InUpdate
ON  Booking_In
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END   
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @b_Success              int       -- Populated by calls to stored procedures - was the proc successful?
   ,         @n_err        int       -- Error number returned by stored procedure or this trigger
   ,         @n_err2       int       -- For Additional Error Detection
   ,         @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,         @n_continue   int
   ,         @n_starttcnt  int       -- Holds the current transaction count
   ,         @c_preprocess NVARCHAR(250) -- preprocess
   ,         @c_pstprocess NVARCHAR(250) -- post process
   ,         @n_cnt int
   ,         @c_receiptkey NVARCHAR(10)
   ,         @c_containerno NVARCHAR(30)
   ,         @c_Storerkey  NVARCHAR(15)
   ,         @c_Configkey  NVARCHAR(30)
   ,         @c_SValue     NVARCHAR(10)
   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   SET @c_Storerkey = ''
   SET @c_Configkey = 'BookSyncContnrTOASN'
   SET @c_SValue    = ''

   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END
   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END
   
   IF (@n_continue=1 OR @n_continue=2) AND UPDATE(Receiptkey) 
   BEGIN
      SELECT @c_receiptkey = ISNULL(DELETED.Receiptkey,''), 
             @c_containerno = ISNULL(DELETED.ContainerNo,'')
      FROM DELETED
   
      IF @c_receiptkey <> '' AND @c_containerno <> ''
      BEGIN
         SELECT @c_Storerkey = ISNULL(Receipt.Storerkey,'')
         FROM RECEIPT WITH (NOLOCK)
         WHERE Receiptkey = @c_receiptkey

         EXECUTE dbo.nspGetRight NULL                 -- facility
                              ,  @c_Storerkey         -- Storerkey
                              ,  NULL                 -- Sku
                              ,  @c_Configkey         -- Configkey
                              ,  @b_success      OUTPUT
                              ,  @c_SValue       OUTPUT
                              ,  @n_err          OUTPUT
                              ,  @c_errmsg       OUTPUT

         IF @b_success = 0
         BEGIN  
            SET @n_continue = 3 
            SET @n_Err = 74901
            SEt @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(255), @n_Err) 
                          + ': Error Getting StorerCongfig for Storer: ' + @c_Storerkey
                          + '. (ntrBooking_InUpdate)' 
            GOTO QUIT_TR
         END  

         IF @c_SValue = '1'
         BEGIN
            UPDATE RECEIPT WITH (ROWLOCK)
            SET Containerkey = '',
                TrafficCop = NULL,
                EditDate = GETDATE(),
                EditWho = SUSER_SNAME()
            WHERE Receiptkey = @c_receiptkey      
            IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=74902   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Error on Booking_In. (ntrBooking_InUpdate)" + " ( " + " SQLSvr MESSAGE=" + RTrim(ISNULL(@c_errmsg,'')) + " ) "
            END
         END
      END 
   END

   IF (@n_continue=1 OR @n_continue=2) AND (UPDATE(Containerno) OR UPDATE(Receiptkey))
   BEGIN
      SELECT @c_receiptkey = ISNULL(INSERTED.Receiptkey,''), 
             @c_containerno = ISNULL(INSERTED.ContainerNo,'')
      FROM INSERTED
   
      IF @c_receiptkey <> '' AND @c_containerno <> ''
      BEGIN
         SELECT @c_Storerkey = ISNULL(Receipt.Storerkey,'')
         FROM RECEIPT WITH (NOLOCK)
         WHERE Receiptkey = @c_receiptkey

         EXECUTE dbo.nspGetRight NULL                 -- facility
                              ,  @c_Storerkey         -- Storerkey
                              ,  NULL                 -- Sku
                              ,  @c_Configkey         -- Configkey
                              ,  @b_success      OUTPUT
                              ,  @c_SValue       OUTPUT
                              ,  @n_err          OUTPUT
                              ,  @c_errmsg       OUTPUT

         IF @b_success = 0
         BEGIN  
            SET @n_continue = 3 
            SET @n_Err = 74903
            SEt @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(255), @n_Err) 
                          + ': Error Getting StorerCongfig for Storer: ' + @c_Storerkey
                          + '. (ntrBooking_InUpdate)' 
            GOTO QUIT_TR
         END  

         IF @c_SValue = '1'
         BEGIN
            UPDATE RECEIPT WITH (ROWLOCK)
            SET Containerkey = @c_containerno,
                TrafficCop = NULL,
                EditDate = GETDATE(),
                EditWho = SUSER_SNAME()
            WHERE Receiptkey = @c_receiptkey      
            IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=74904   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Error on Booking_In. Update Containerno (ntrBooking_InUpdate)" + " ( " + " SQLSvr MESSAGE=" + RTrim(ISNULL(@c_errmsg,'')) + " ) "
            END
         END
      END 
   END

   IF @n_continue = 1 OR @n_continue = 2   
   BEGIN        
      --NJOW01  
      INSERT INTO Booking_Audit (BookingNo, BookingType, Facility, BookingDate,EndTime, Duration, Loc, Type,                               
                                ALTReference, SCAC, ReferenceNo, POKey, ReceiptKey, Status, ContainerNo, ArrivedTime,                     
                                SignInTime, UnloadTime, DepartTime, DriverName, UserDefine01, UserDefine02, UserDefine03,                 
                                UserDefine04, UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09,                       
                                UserDefine10,UOMQty, Qty, NumberOfSKU, Remark, SpecialHandling)                                           
      SELECT BookingNo, 'IN', Facility, BookingDate,EndTime, Duration, Loc, Type,                                                         
             ALTReference, SCAC, ReferenceNo, POKey, ReceiptKey, Status, ContainerNo, ArrivedTime,                                        
             SignInTime, UnloadTime, DepartTime, DriverName, UserDefine01, UserDefine02, UserDefine03,                                    
             UserDefine04, UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09,                                          
             UserDefine10,UOMQty, Qty, NumberOfSKU, Remark, SpecialHandling                                                               
      FROM INSERTED                                                                                                                             
   END  
   IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE BOOKING_IN with (ROWLOCK)
      SET EditWho = sUser_sName(),
          EditDate = GetDate()
      FROM BOOKING_IN 
      JOIN INSERTED ON BOOKING_IN.BookingNo = INSERTED.BookingNo
   END

   QUIT_TR:
   IF @n_continue=3  -- Error Occured - Process And Return
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
   
	   EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrBooking_InUpdate"
	   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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