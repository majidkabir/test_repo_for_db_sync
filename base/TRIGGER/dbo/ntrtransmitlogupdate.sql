SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/* 17-Mar-2009  TLTING     Change user_name() to SUSER_SNAME()          */
/* 28-Oct-2013  TLTING     Review Editdate column update                */

CREATE TRIGGER ntrTransmitlogUpdate
 ON  TRANSMITLOG
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

   DECLARE @b_debug int
   SELECT @b_debug = 0
   DECLARE   
   @b_Success            int       
   ,         @n_err                int       
   ,         @n_err2               int       
   ,         @c_errmsg             NVARCHAR(250) 
   ,         @n_continue int
   ,         @n_starttcnt          int
   ,         @c_preprocess         NVARCHAR(250) 
   ,         @c_pstprocess         NVARCHAR(250) 
   ,         @n_cnt                int      

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   IF UPDATE(ArchiveCop)
   BEGIN
   	SELECT @n_continue = 4 
   END
 	
   IF ( @n_continue = 1 or @n_continue = 2 ) AND NOT UPDATE(EditDate)
	BEGIN 	
	 	UPDATE TRANSMITLOG 
	    	   SET EditDate = GETDATE(),
	       	       EditWho = SUSER_SNAME(),
	        	       Trafficcop = NULL
	           FROM TRANSMITLOG, INSERTED
	          WHERE TRANSMITLOG.TRANSMITLOGKey = INSERTED.TRANSMITLOGKey
	         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
	 	IF @n_err <> 0
	    	BEGIN
	       		SELECT @n_continue = 3
	       		SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72804   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	       		SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table TRANSMITLOG. (ntrTRANSMITLOGUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
	    	END
	END
 END


GO