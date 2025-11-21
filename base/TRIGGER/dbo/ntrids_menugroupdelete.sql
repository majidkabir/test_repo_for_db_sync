SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrIDS_MenuGroupDelete                                      */
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
/* Called By: When records Deleted                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date       Author    Ver.    Purposes                                */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrIDS_MenuGroupDelete]
ON  [dbo].[IDS_MenuGroup]
FOR DELETE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END	
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
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
   ,         @c_groupkey NVARCHAR(10)
   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
    
   IF (@n_continue=1 OR @n_continue=2) 
   BEGIN   
      SELECT @c_groupkey = ISNULL(DELETED.Groupkey,'') 
      FROM DELETED
      
      IF @c_groupkey <> ''
      BEGIN
      	 DELETE IDS_MENULINK 
      	 WHERE Groupkey = @c_groupkey
      	 
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=74909   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Error on IDS_MenuLink. (ntrIDS_MenuGroupDelete)" + " ( " + " SQLSvr MESSAGE=" + RTrim(ISNULL(@c_errmsg,'')) + " ) "
         END         
         
         UPDATE IDS_MENUUSER WITH (ROWLOCK)
         SET Groupkey = 'LFSTD'
         WHERE Groupkey = @c_groupkey         

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=74910   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Error on IDS_MenuUser. (ntrIDS_MenuGroupDelete)" + " ( " + " SQLSvr MESSAGE=" + RTrim(ISNULL(@c_errmsg,'')) + " ) "
         END         
      END 
   END
 
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
   
	   EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrIDS_MenuGroupDelete"
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