SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE TRIGGER ntridsStkTrfDocdelete
ON  idsStkTrfDoc
FOR DELETE
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
	SET CONCAT_NULL_YIELDS_NULL OFF
	
	DECLARE
	@b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
	,         @n_err                int       -- Error number returned by stored procedure or this trigger
	,         @n_err2 int              -- For Additional Error Detection
	,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
	,         @n_continue int                 
	,         @n_starttcnt int                -- Holds the current transaction count
	,         @c_preprocess NVARCHAR(250)         -- preprocess
	,         @c_pstprocess NVARCHAR(250)         -- post process
	,         @n_cnt int                  
	SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
	     /* #INCLUDE <TRAHA1.SQL> */  
	
	IF @n_continue=1 or @n_continue=2
	BEGIN
		DELETE idsStkTrfDocDetail
		FROM   idsStkTrfDocDetail, Deleted 
		WHERE  idsStkTrfDocDetail.stdno = Deleted.stdno
		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
		IF @n_err <> 0
		BEGIN
			SELECT @n_continue = 3
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=66700   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
			SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Failed On Table idsStkTrfDocDetail. (nspidsStkTrfDocDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
		END
	END
	
	     /* #INCLUDE <TRAHA2.SQL> */
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
		execute nsp_logerror @n_err, @c_errmsg, "ntridsStkTrfDocDelete"
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