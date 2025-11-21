SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Trigger: ntrVASDetailUpdate                                          */
/* Creation Date: 10-Oct-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  VAS Detail Update Transaction                              */
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
/* Called By: When update records                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 28-Oct-2013  TLTING     Review Editdate column update                */
/************************************************************************/

CREATE TRIGGER [ntrVASDetailUpdate]
ON  [dbo].[VASDetail] FOR UPDATE
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

	DECLARE @n_continue   int                 
			, @n_starttcnt  int       -- Holds the current transaction count@b_Success
			, @n_err        int       -- Error number returned by stored procedure or this trigger
			, @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger


	SET @n_continue = 1
   SET @n_starttcnt= @@TRANCOUNT

	IF UPDATE(ArchiveCop)
	BEGIN
		SET @n_continue = 4 
	END

	/* #INCLUDE <TRTHU1.SQL> */     

	IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
	BEGIN
		UPDATE VASDetail
		SET EditDate = GETDATE() 
		   ,EditWho = SUSER_SNAME()
		FROM VASDetail WITH (NOLOCK)
      JOIN INSERTED WITH (NOLOCK) ON (INSERTED.VasKey = VASDetail.VasKey)
                                  AND(INSERTED.VASLineNumber = VASDetail.VASLineNumber)
      JOIN DELETED WITH (NOLOCK)  ON (DELETED.VasKey = VASDetail.VasKey)
                                  AND(DELETED.VASLineNumber = VASDetail.VASLineNumber)

		SET @n_err = @@ERROR 

		IF @n_err <> 0
		BEGIN
			SET @n_continue = 3
			SET @c_errmsg = CONVERT(CHAR(250),@n_err)
         SET @n_err=69701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
			SET @c_errmsg ='NSQL'+CONVERT(char(5),@n_err)
                       +': Update Failed On Table VASDetail. (ntrVASDetailUpdate)' 
                       + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
		END
	END
	IF UPDATE(TrafficCop)
	BEGIN
		SET @n_continue = 4 
	END
	-- Begin

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
		execute nsp_logerror @n_err, @c_errmsg, 'ntrVASDetailUpdate'
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