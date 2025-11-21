SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************/
/* Trigger: ntrRouteMasterDelete                                           				*/
/* Creation Date: 8-Aug-2011                                               				*/
/* Copyright: IDS                                                          				*/
/* Written by:    KHLim                                                    				*/
/*                                                                         				*/
/* Purpose: Trigger point upon any Delete on the RouteMaster               				*/
/*                                                                         				*/
/* Return Status:                                                          				*/
/*                                                                         				*/
/* Usage:                                                                  				*/
/*                                                                         				*/
/* Called By: When records Updated                                         				*/
/*                                                                         				*/
/* PVCS Version: 1.0                                                       				*/
/*                                                                         				*/
/* Version: 5.4                                                            				*/
/*                                                                         				*/
/* Modifications:                                                          				*/
/* Date         Author     	Ver  	Purposes                                   			*/
/* 8-Aug-2011   KHLim01    	1.0   initial creation                           			*/
/* 2022-05-17   kelvinongcy	1.1	WMS-19673 prevent bulk update or delete (kocy01)	*/
/***************************************************************************************/

CREATE   TRIGGER [dbo].[ntrRouteMasterDelete]
ON [dbo].[RouteMaster]
FOR DELETE
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

   DECLARE  @b_Success     int,       -- Populated by calls to stored procedures - was the proc successful?
            @n_err         int,       -- Error number returned by stored procedure or this trigger
            @c_errmsg      NVARCHAR(250), -- Error message returned by stored procedure or this trigger
            @n_continue    int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
            @n_starttcnt   int,       -- Holds the current transaction count
            @n_cnt         int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
           ,@c_authority   NVARCHAR(1)
			  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

      /* #INCLUDE <TRCONHD1.SQL> */     
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrRouteMasterDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'
      BEGIN
         INSERT INTO dbo.RouteMaster_DELLOG ( Route )
         SELECT Route FROM DELETED WITH (NOLOCK)

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Err message but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table RouteMaster Failed. (ntrRouteMasterDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END

   IF ( (SELECT COUNT(1) FROM Deleted WITH (NOLOCK) ) > 100 )  --kocy01
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME()) 
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68102   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Failed On Table RouteMaster. Batch Delete not allow! (ntrRouteMasterDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END

      /* #INCLUDE <TRCOND2.SQL> */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrRouteMasterDelete'
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