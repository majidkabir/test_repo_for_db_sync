SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrOrderSelectionUpdate                                     */
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
/* Date        Author  Ver.  Purposes                                   */
/* 30-SEP-2013 TLTING  1.0   Initial Version                            */ 
/************************************************************************/

CREATE TRIGGER [dbo].[ntrOrderSelectionUpdate]
ON  [dbo].[OrderSelection]
FOR UPDATE
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END -- @@ROWCOUNT = 0

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
   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN
      UPDATE OrderSelection
      SET EditWho = sUser_sName(),
          EditDate = GetDate(),
          TrafficCop = NULL
      FROM OrderSelection 
      JOIN INSERTED ON OrderSelection.OrderSelectionKey = INSERTED.OrderSelectionKey
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update On Table OrderSelection Failed. (ntrOrderSelectionUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
      END      
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
   
	   EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrOrderSelectionUpdate"
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