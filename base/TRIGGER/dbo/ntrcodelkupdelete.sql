SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/* 14-Jul-2011  KHLim02    1.0   GetRight for Delete log                      */
/* 19-Dec-2011  KHLim03    1.1   Additional PK: Storerkey                     */
/* 13-Apr-2015  KHLim04    1.2   Additional PK: code2                         */
/* 24-Sept-2021 kocy       1.3   WMS-17868 Add additional columns for trace   */
/* 22-Feb-2022  TLTING     1.4   prevent bulk update                          */ 
/******************************************************************************/

CREATE     TRIGGER [dbo].[ntrCODELKUPDelete]
ON [dbo].[CODELKUP]
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
            @n_continue    INT,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
            @n_starttcnt   INT,       -- Holds the current transaction count
            @n_cnt         INT        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
           ,@c_authority   NVARCHAR(1)  -- KHLim02
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
-- if (select count(*) from DELETED) =
-- (select count(*) from DELETED where DELETED.ArchiveCop = '9')
-- BEGIN
--    SELECT @n_continue = 4
-- END
      /* #INCLUDE <TRCONHD1.SQL> */     

   IF ( ( SELECT COUNT(1) FROM   DELETED ) > 100 ) 
       AND SUSER_SNAME() NOT IN ( 'itadmin', 'alpha\wmsadmingt', 'ALPHA\SRVwmsadminlfl', 'ALPHA\SRVwmsadmincn'    )
   BEGIN
      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68108   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Delete Failed On Table CodeLKUP. Batch delete not allow! (ntrCODELKUPDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
          
   END


   IF @n_continue = 1 OR @n_continue = 2
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
               ,@c_errmsg = 'ntrCODELKUPDelete' + RTRIM(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.CODELKUP_DELLOG ( LISTNAME, Code, Storerkey, code2, [Description], Short, Long,  Notes, Notes2, UDF01, UDF02, UDF03, UDF04, UDF05 )  -- KHLim03 --kocy
         SELECT LISTNAME, Code, Storerkey, code2, [Description], Short, Long,  Notes, Notes2, UDF01, UDF02, UDF03, UDF04, UDF05 -- KHLim04   -- kocy
         FROM DELETED                  

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table CODELKUP Failed. (ntrCODELKUPDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrCODELKUPDelete'
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