SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsprfOT08                                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 25-Apr-2007  Vicky			SQL2005 doesnt have SysXLogins table      */
/*                            anymore. It's replace by table            */
/*                            master.Sys.sql_logins                     */
/************************************************************************/

CREATE PROC    [dbo].[nsprfOT08]
@c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(10)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(5)
,              @c_appflag          NVARCHAR(2)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_outstring        NVARCHAR(255)  OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
   -- SET ANSI_DEFAULTS OFF
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   -- SET ANSI_NULLS OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int               -- For Additional Error Detection
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
   DECLARE @c_dbnamestring NVARCHAR(255)
   DECLARE @n_qty int, @n_cqty int, @n_returnrecs int
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   SELECT @n_returnrecs=1
   /* #INCLUDE <SPRFOT08_1.SQL> */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      DECLARE @c_dbname NVARCHAR(255), @n_dbcount int
      SELECT @c_dbname = SPACE(255), @n_dbcount = 0
      SET ROWCOUNT  1
      WHILE 1=1
      BEGIN
         SELECT @n_dbcount = @n_dbcount + 1
--          SELECT @c_dbname = master..SysDatabases.NAME
--          FROM   master..SysDatabases, master..SysXLogins
--          WHERE  master..SysDatabases.NAME > @c_dbname
--          AND    master..SysDatabases.name NOT IN ( 'pubs', 'master', 'tempdb', 'model', 'msdb', 'tsecure' )
--          AND    Master..SysDatabases.dbid = master..SysXLogins.dbid
--          AND    master..SysXLogins.name = @c_userid
--          order by master..SysDatabases.name
         -- For SQL 2005 Changes
         SELECT  @c_dbname = master.Sys.sql_logins.default_database_name
         FROM   master.Sys.sql_logins
         WHERE  master.Sys.sql_logins.default_database_name > @c_dbname
         AND    master.Sys.sql_logins.default_database_name NOT IN ( 'pubs', 'master', 'tempdb', 'model', 'msdb', 'tsecure' )
         AND    master.Sys.sql_logins.name = @c_userid
         order by master.Sys.sql_logins.default_database_name
         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END
      ELSE
         BEGIN
            SELECT @c_dbnamestring =  dbo.fnc_RTRIM(@c_dbnamestring) + @c_sendDelimiter + dbo.fnc_RTRIM(@c_dbname) + @c_sendDelimiter + dbo.fnc_RTRIM(@c_dbname)
         END
         SELECT @n_returnrecs = @n_dbcount
         IF @n_dbcount > 10
         BEGIN
            BREAK
         END
      END
      SET ROWCOUNT 0
   END -- @n_continue =1 or @n_continue = 2
   IF @n_continue=3
   BEGIN
      IF @c_retrec="01"
      BEGIN
         SELECT @c_retrec="09"
      END
   END
ELSE
   BEGIN
      SELECT @c_retrec="01"
   END
   IF @n_continue=1 OR @n_continue=4
   BEGIN
      SELECT @c_outstring =
      dbo.fnc_RTRIM(@c_ptcid)     + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_userid)    + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_taskid)    + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_databasename) + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_appflag)   + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_retrec)    + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_server)    + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_errmsg)    + @c_senddelimiter
      + dbo.fnc_RTRIM(CONVERT(Nchar(10),@n_returnrecs))
      + dbo.fnc_RTRIM(@c_dbnamestring
      )
      SELECT dbo.fnc_RTRIM(@c_outstring)
   END
ELSE
   BEGIN
      SELECT @c_outstring =
      dbo.fnc_RTRIM(@c_ptcid)     + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_userid)    + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_taskid)    + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_databasename) + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_appflag)   + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_retrec)    + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_server)    + @c_senddelimiter
      + dbo.fnc_RTRIM(@c_errmsg)    + @c_senddelimiter
      + dbo.fnc_RTRIM(CONVERT(Nchar(10),@n_returnrecs))
      + dbo.fnc_RTRIM(@c_dbnamestring)
      SELECT dbo.fnc_RTRIM(@c_outstring)
   END
   /* #INCLUDE <SPRFOT08_2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
      execute nsp_logerror @n_err, @c_errmsg, "nspRFOT08"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO