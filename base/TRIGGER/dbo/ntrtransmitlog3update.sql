SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/* 17-Mar-2009  TLTING     Change user_name() to SUSER_SNAME()          */
/* 28-Oct-2013  TLTING     Review Editdate column update                */
/* 02-Oct-2018  TLTING     log and block bulk update                    */
/* 22-Sep-2020  TLTING     new service account                          */

CREATE  TRIGGER [dbo].[ntrTransmitlog3Update]
ON  [dbo].[TRANSMITLOG3]
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

   DECLARE @b_debug int
   SELECT @b_debug = 0
   DECLARE
   @b_Success              int
   , @n_err                int
   , @n_err2               int
   , @c_errmsg             NVARCHAR(250)
   , @n_continue           int
   , @n_starttcnt          int
   , @c_preprocess         NVARCHAR(250)
   , @c_pstprocess         NVARCHAR(250)
   , @n_cnt                int

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END


   IF ( @n_continue = 1 or @n_continue = 2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE TRANSMITLOG3
         SET EditDate = GETDATE(),
             EditWho = SUSER_SNAME(),
             Trafficcop = NULL
        FROM TRANSMITLOG3, INSERTED
       WHERE TRANSMITLOG3.TRANSMITLOGKey = INSERTED.TRANSMITLOGKey
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72804   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table TRANSMITLOG3. (ntrTransmitlog3Update)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END


   IF ( (Select count(1) FROM  TRANSMITLOG3 (NOLOCK), INSERTED
       WHERE TRANSMITLOG3.TRANSMITLOGKey = INSERTED.TRANSMITLOGKey ) > 50 )
         AND Suser_sname() not in ('iml','dts','itadmin', 'QCmdUser', 'alpha\wmsadmingt', 'mctang', 'kwhchan', 'JovineNg', 'wfleong', 'ALPHA\SRVwmsadminlfl', 'ALPHA\SRVwmsadmincn')
   BEGIN
         --Declare @c_Progname nvarchar(20)
         --Declare @c_Username nvarchar(20)

         --select @c_Progname= program_name , @c_Username = loginame from master.sys.sysprocesses where spid = @@SPID


         --INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 )
         --Select  'ntrTransmitlog3Update', GETDATE(), Suser_sname(), INSERTED.tablename,cast(count(5) as nvarchar),@c_Progname,''
         --FROM   TRANSMITLOG3, INSERTED
         --WHERE TRANSMITLOG3.TRANSMITLOGKey = INSERTED.TRANSMITLOGKey
         --group by  INSERTED.tablename


         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72814   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table TRANSMITLOG3. Batch Update not allow! (ntrTransmitlog3Update)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "

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
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrTransmitlog3Update'
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