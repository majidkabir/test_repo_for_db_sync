SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************************/  
/* Trigger:  ntrCODELISTUpdate                                                   	*/
/* Creation Date:                                                                	*/
/* Copyright: IDS                                                                	*/
/* Written by:                                                                   	*/
/*                                                                               	*/
/* Purpose:  Trigger point upon any Update on the CODELIST                       	*/
/*                                                                               	*/
/* Return Status:  None                                                          	*/
/*                                                                               	*/
/* Usage:                                                                        	*/
/*                                                                               	*/
/* Local Variables:                                                              	*/
/*                                                                               	*/
/* Called By: When records updated                                               	*/
/*                                                                               	*/
/* PVCS Version: 1.0                                                             	*/
/*                                                                               	*/
/* Version: 5.4                                                                  	*/
/*                                                                               	*/
/* Data Modifications:                                                           	*/
/*                                                                               	*/
/* Updates:                                                                      	*/
/* Date         Author    		Ver.  Purposes                                        */
/* 04-Mar-2022  TLTING    		1.1   WMS-19029 prevent bulk update or delete         */ 
/* 2022-04-12   kelvinongcy	1.2   amend way for control user run batch (kocy01)	*/
/************************************************************************************/  

CREATE   TRIGGER [dbo].[ntrCODELISTUpdate]
ON  [dbo].[CODELIST]
FOR UPDATE
AS
BEGIN -- main
   IF @@ROWCOUNT = 0  
   BEGIN  
      RETURN  
   END     
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
         , @n_err                int       -- Error number returned by stored procedure or this trigger
         , @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
         , @n_continue           int                 
         , @n_starttcnt          int       -- Holds the current transaction count
         , @c_TrafficCop         NCHAR(1)
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT      
   
   IF UPDATE(TrafficCop)  
   BEGIN
      SELECT @n_continue = 4 
   END

   IF (@n_continue = 1 or @n_continue = 2)  AND NOT UPDATE(EditDate)
   BEGIN
    	UPDATE CODELIST WITH (ROWLOCK)
   	SET CODELIST.EditWho = SUSER_SNAME(),
   	    CODELIST.EditDate = GETDATE(),
   	    CODELIST.TrafficCop = NULL
   	FROM CODELIST
      JOIN INSERTED ON CODELIST.LISTNAME = INSERTED.LISTNAME
      
		SELECT @n_err = @@ERROR 
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67404   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table CODELIST. (ntrCODELISTUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
    END

   --IF ( (SELECT COUNT(1) FROM   INSERTED  ) > 100 ) 
   --    AND SUSER_SNAME() NOT IN ( 'itadmin', 'alpha\wmsadmingt', 'ALPHA\SRVwmsadminlfl', 'ALPHA\SRVwmsadmincn', 'iml'    )
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01
		  AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67408   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update Failed On Table CODELIST. Batch Update not allow! (ntrCODELISTUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END


   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
    IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
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
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrCODELISTUpdate'
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

END -- main

GO