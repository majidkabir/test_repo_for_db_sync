SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************************/
/* Trigger: ntrFACILITYDelete                                              			*/
/* Creation Date:                                                          			*/
/* Copyright: LFL                                                          			*/
/* Written by:                                                             			*/
/*                                                                         			*/
/* Purpose:  Facility delete trigger                                       			*/
/*                                                                         			*/
/* Input Parameters:                                                       			*/
/*                                                                         			*/
/* Output Parameters:                                                      			*/
/*                                                                         			*/
/* Return Status:                                                          			*/
/*                                                                         			*/
/* Usage:                                                                  			*/
/*                                                                         			*/
/* Local Variables:                                                        			*/
/*                                                                         			*/
/* Called By: When update records                                          			*/
/*                                                                         			*/
/* PVCS Version: 1.0                                                       			*/
/*                                                                         			*/
/* Version: 6.0                                                            			*/
/*                                                                         			*/
/* Data Modifications:                                                     			*/
/*                                                                         			*/
/* Updates:                                                                			*/
/* Date         Author     	Ver.  Purposes                                  		*/
/* 14-Jul-2011  KHLim02    	1.0   GetRight for Delete log                   		*/
/* 02-May-2018  NJOW01     	1.1   WMS-4914 facility delete validation       		*/
/* 04-Mar-2022  TLTING     	1.2  	WMS-19029 prevent bulk update or delete    		*/
/* 2022-04-12   kelvinongcy	1.3   amend way for control user run batch (kocy01)	*/
/************************************************************************************/

CREATE   TRIGGER [dbo].[ntrFACILITYDelete]
ON [dbo].[FACILITY]
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

   DECLARE  @b_Success     INT,       -- Populated by calls to stored procedures - was the proc successful?
            @n_err         INT,       -- Error number returned by stored procedure or this trigger
            @c_errmsg      NVARCHAR(250), -- Error message returned by stored procedure or this trigger
            @n_continue    int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
            @n_starttcnt   int,       -- Holds the current transaction count
            @n_cnt         int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
           ,@c_authority   NVARCHAR(1)  -- KHLim02
   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

-- if (select count(*) from DELETED) =
-- (select count(*) from DELETED where DELETED.ArchiveCop = '9')
-- BEGIN
--    SELECT @n_continue = 4
-- END
      /* #INCLUDE <TRCONHD1.SQL> */     
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
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
               ,@c_errmsg = 'ntrFACILITYDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.FACILITY_DELLOG ( Facility )
         SELECT Facility FROM DELETED WITH (NOLOCK)

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Err message but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table FACILITY Failed. (ntrFACILITYDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
 
   --IF ( (Select count(1) FROM   Deleted  ) > 100 ) 
   --    AND Suser_sname() not in ( 'itadmin', 'alpha\wmsadmingt', 'ALPHA\SRVwmsadminlfl', 'ALPHA\SRVwmsadmincn', 'iml'    )
   IF ( (SELECT COUNT(1) FROM Deleted WITH (NOLOCK) ) > 100 )    --kocy01
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME()) 
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68108   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Failed On Table Facility. Batch Delete not allow! (ntrFacilityDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END

   --NJOW01
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
   	  IF EXISTS(SELECT 1 
   	            FROM DELETED  WITH (NOLOCK)
   	            JOIN LOC (NOLOCK) ON DELETED.Facility = LOC.Facility)
   	  BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68102   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Facility refer by location. Not allow to delete. (ntrFACILITYDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
   	  END          
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrFACILITYDelete'
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