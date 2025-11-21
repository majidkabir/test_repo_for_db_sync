SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************/
/* Trigger: ntrStrategyUpdate                                                        	*/
/* Creation Date:                                                                    	*/
/* Copyright: IDS                                                                    	*/
/* Written by:                                                                       	*/
/*                                                                                   	*/
/* Purpose:  Strategy Update Transaction                                             	*/
/*                                                                                   	*/
/* Input Parameters:                                                                 	*/
/*                                                                                   	*/
/* Output Parameters:                                                                	*/
/*                                                                                   	*/
/* Return Status:                                                                    	*/
/*                                                                                   	*/
/* Usage:                                                                            	*/
/*                                                                                   	*/
/* Local Variables:                                                                  	*/
/*                                                                                   	*/
/* Called By: When update records                                                    	*/
/*                                                                                   	*/
/* PVCS Version: 1.0                                                                 	*/
/*                                                                                   	*/
/* Version: 6.0                                                                      	*/
/*                                                                                   	*/
/* Data Modifications:                                                               	*/
/*                                                                                   	*/
/* Updates:                                                                          	*/
/* Date         Author    		Ver	Purposes                                          	*/
/* 25 May 2012  TLTING01         	DM integrity - add update editdate B4 TrafficCop   */
/* 28-Oct-2013  TLTING           	Review Editdate column update                      */ 
/* 2022-04-12   kelvinongcy	1.3	WMS-19428 prevent bulk update or delete (kocy01)	*/
/***************************************************************************************/

CREATE   TRIGGER [dbo].[ntrStrategyUpdate]
ON  [dbo].[Strategy] FOR UPDATE
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

	DECLARE @b_Success    int       -- Populated by calls to stored procedures - was the proc successful?
			, @n_err        int       -- Error number returned by stored procedure or this trigger
			, @n_err2       int       -- For Additional Error Detection
			, @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger
			, @n_continue   int                 
			, @n_starttcnt  int       -- Holds the current transaction count
			, @c_preprocess NVARCHAR(250) -- preprocess
			, @c_pstprocess NVARCHAR(250) -- post process
			, @n_cnt        int                  

	SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

	IF UPDATE(ArchiveCop)
	BEGIN
		SELECT @n_continue = 4 
	END
	
   --tlting01
	IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
	BEGIN
		UPDATE Strategy WITH (ROWLOCK)
		SET EditDate = GETDATE(),
		    EditWho  = SUSER_SNAME(),
		    TrafficCop = NULL
		FROM Strategy , INSERTED
      WHERE Strategy.StrategyKey = INSERTED.StrategyKey

		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
		IF @n_err <> 0
		BEGIN
			SELECT @n_continue = 3
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69701   -- Should Be Set To The SQL Err message but I don't know how to do so.
			SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table Strategy. (ntrStrategyUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
		END
	END
	
	IF UPDATE(TrafficCop)
	BEGIN
		SELECT @n_continue = 4 
	END
	
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69702   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update Failed On Table Strategy. Batch Update not allow! (ntrStrategyUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END


	   /* #INCLUDE <TRTHU1.SQL> */     
      /* #INCLUDE <TRTHU2.SQL> */
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
		execute nsp_logerror @n_err, @c_errmsg, 'ntrStrategyUpdate'
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