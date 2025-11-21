SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/* 17-Mar-2009  TLTING     Change user_name() to SUSER_SNAME()          */
/* 28-Oct-2013  TLTING     1.4   Review Editdate column update          */

CREATE TRIGGER ntrInvRptlogUpdate
 ON  INVRPTLOG
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
	DECLARE @n_err int, @n_cnt int, @c_errmsg NVARCHAR(250)   
   DECLARE @n_continue int

   SELECT @n_continue=1 
 	IF UPDATE(TrafficCop)  
	BEGIN  
	    SELECT @n_continue = 4   
	END  
	
	IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate)
	BEGIN	
	 	
	 	UPDATE INVRPTLOG with (ROWLOCK)
	    	   SET EditDate = GETDATE(),
	       	       EditWho = SUSER_SNAME(),
	        	       Trafficcop = NULL
	           FROM INVRPTLOG, INSERTED
	          WHERE INVRPTLOG.INVRPTLOGKey = INSERTED.INVRPTLOGKey
	         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
	 	IF @n_err <> 0
	    	BEGIN
	       		SELECT @n_continue = 3
	       		SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72805   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	       		SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table INVRPTLOG. (ntrINVRPTLOGUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
	    	END
	END
 END


GO