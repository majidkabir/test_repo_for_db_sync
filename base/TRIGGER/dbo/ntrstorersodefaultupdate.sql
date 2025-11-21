SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************/
/* Trigger: ntrStorerSODefaultUpdate                                    					*/
/* Creation Date:                                                       					*/
/* Copyright: IDS                                                       					*/
/* Written by:  KHLIM                                                   					*/
/*                                                                      					*/
/* Purpose:  StorerSODefault Update                                     					*/
/*                                                                      					*/
/* Input Parameters:                                                    					*/
/*                                                                      					*/
/* Output Parameters:                                                   					*/
/*                                                                      					*/
/* Return Status:                                                       					*/
/*                                                                      					*/
/* Usage:                                                               					*/
/*                                                                      					*/
/* Local Variables:                                                     					*/
/*                                                                      					*/
/* Called By: When update records                                       					*/
/*                                                                      					*/
/* PVCS Version: 1.0                                                    					*/
/*                                                                      					*/
/* Version: 6.0                                                         					*/
/*                                                                      					*/
/* Data Modifications:                                                  					*/
/*                                                                      					*/
/* Updates:                                                             					*/
/* Date         Author   		Ver  	Purposes                                  			*/
/* 28-Oct-2013  TLTING   		1.1  	Review Editdate column update             			*/
/* 2022-05-17   kelvinongcy	1.2	WMS-19673 prevent bulk update or delete (kocy01)	*/
/***************************************************************************************/

CREATE   TRIGGER [dbo].[ntrStorerSODefaultUpdate]
ON  [dbo].[StorerSODefault] 
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

	   /* #INCLUDE <TRTHU1.SQL> */     
	IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
	BEGIN
		UPDATE StorerSODefault WITH (ROWLOCK)
		SET EditDate = GETDATE(),
		    EditWho = SUSER_SNAME()
		FROM StorerSODefault, INSERTED
		WHERE StorerSODefault.StorerKey = INSERTED.StorerKey

		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

		IF @n_err <> 0
		BEGIN
			SELECT @n_continue = 3
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69701   -- Should Be Set To The SQL Err message but I don't know how to do so.
			SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table StorerSODefault. (ntrStorerSODefaultUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
		END
	END

   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK)  ) > 100 )   --kocy01
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69702   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table StorerSODefault. Batch Update not allow! (ntrStorerSODefaultUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END

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
		execute nsp_logerror @n_err, @c_errmsg, 'ntrStorerSODefaultUpdate'
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