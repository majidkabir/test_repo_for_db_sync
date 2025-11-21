SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspRFSH01                                          */
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
/************************************************************************/

CREATE PROC    [dbo].[nspRFSH01]
@c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(18)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(30)
,              @c_appflag          NVARCHAR(5)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_ttm              NVARCHAR(5)
,              @c_fromid           NVARCHAR(18)
,              @c_fromloc          NVARCHAR(18)
,              @c_toid             NVARCHAR(18)
,              @c_toloc            NVARCHAR(18)
,              @c_action           NVARCHAR(10)
,              @c_outstring        NVARCHAR(255)  OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 1
   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @n_err2 int               -- For Additional Error Detection
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
   DECLARE @n_cqty int, @n_returnrecs int
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   SELECT @n_returnrecs=1
   DECLARE @c_caseid NVARCHAR(10)
   SELECT @c_caseid = @c_fromid -- So that we only take the first 10 characters of the ID comming in.
   /* #INCLUDE <SPTSH01_1.SQL> */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
   END
   IF (@n_continue = 1 or @n_continue = 2) AND (@c_action = "1" or @c_action = "PICK" or @c_action = "PICKED")
   BEGIN
      IF EXISTS(SELECT caseid FROM TASKDETAIL WHERE caseid = @c_caseid and STATUS = "0") -- and tasktype = "PK" and userkey = "")
      BEGIN
         BEGIN TRANSACTION
            UPDATE TASKDETAIL
            SET STATUS = "9" ,
            ToLoc = @c_toloc,
            Toid = @c_toid,
            Userkey = @c_userid,
            UserPosition = "1", -- This task is being performed at the FROMLOC
            EndTime = getdate()
            WHERE caseid = @c_caseid
            and status = "0"
            and tasktype = "PK"
            -- and userkey = ""
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=84701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table TaskDetail. (nspRFTRP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF @c_toid <> @c_fromid
               BEGIN
                  EXECUTE nspCheckDropID
                  @c_dropid       = @c_toid
                  ,              @c_childid      = @c_caseid
                  ,              @c_droploc      = @c_toloc
                  ,              @b_Success      = @b_success OUTPUT
                  ,              @n_err          = @n_err OUTPUT
                  ,              @c_errmsg       = @c_errmsg OUTPUT
                  IF @b_success = 0
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END
            ELSE
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 84703, @c_errmsg = "NSQL84702:" + "FromID cannot Equal the TOID"
               END
            END
            IF @n_continue = 3
            BEGIN
               ROLLBACK TRAN
            END
         ELSE
            BEGIN
               COMMIT TRAN
            END
         END
      ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 84702, @c_errmsg = "NSQL84703:" + "Caseid is not valid"
         END
      END
      IF (@n_continue = 1 or @n_continue = 2) AND (@c_action = "2" or @c_action = "LOAD" or @c_action = "PACK")
      BEGIN
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromid)) IS NOT NULL
         AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toid)) IS NOT NULL
         BEGIN
            IF @c_fromid <> @c_toid
            BEGIN
               IF EXISTS (SELECT caseid FROM PICKDETAIL WHERE caseid = @c_caseid)
               OR EXISTS (SELECT dropid FROM dropid where dropid = @c_fromid)
               BEGIN
                  BEGIN TRANSACTION
                     EXECUTE nspCheckDropID
                     @c_dropid       = @c_toid
                     ,              @c_childid      = @c_fromid
                     ,              @c_droploc      = @c_toloc
                     ,              @b_Success      = @b_success OUTPUT
                     ,              @n_err          = @n_err OUTPUT
                     ,              @c_errmsg       = @c_errmsg OUTPUT
                     IF @b_success = 0
                     BEGIN
                        SELECT @n_continue = 3
                     END
                     IF @n_continue = 3
                     BEGIN
                        ROLLBACK TRAN
                     END
                  ELSE
                     BEGIN
                        COMMIT TRAN
                     END
                  END
               ELSE
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 84703, @c_errmsg = "NSQL84704:" + "FromID Is Invalid"
                  END
               END
            ELSE
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 84703, @c_errmsg = "NSQL84705:" + "FromID cannot Equal the TOID"
               END
            END
         ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 84704, @c_errmsg = "NSQL84706:" + "FromID or TOID Was Not Supplied"
            END
         END
         IF (@n_continue = 1 or @n_continue = 2) AND (@c_action = "3" or @c_action = "SHIP")
         BEGIN
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromid)) IS NOT NULL
            BEGIN
               IF EXISTS (SELECT dropid FROM dropid where dropid = @c_fromid and STATUS = "0")
               BEGIN
                  BEGIN TRANSACTION
                     UPDATE dropid SET status = "9"
                     WHERE dropid = @c_fromid and STATUS = "0"
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=84707   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table DropID. (nspRFTRP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                     END
                     IF @n_continue = 3
                     BEGIN
                        ROLLBACK TRAN
                     END
                  ELSE
                     BEGIN
                        COMMIT TRAN
                     END
                  END
               ELSE
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 84703, @c_errmsg = "NSQL84708:" + "FromID Is Invalid or is already shipped"
                  END
               END
            ELSE
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 84704, @c_errmsg = "NSQL84709:" + "FromID or TOID Was Not Supplied"
               END
            END
            IF (@n_continue = 1 or @n_continue = 2) AND (@c_action = "4" or @c_action = "MOVE")
            BEGIN
               IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromid)) IS NOT NULL and dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toloc)) IS NOT NULL
               BEGIN
                  IF EXISTS (SELECT dropid FROM dropid where dropid = @c_fromid and STATUS = "0")
                  BEGIN
                     BEGIN TRANSACTION
                        UPDATE dropid SET droploc = @c_toloc
                        WHERE dropid = @c_fromid and STATUS = "0"
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=84710   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table DropID. (nspRFTRP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                        END
                        IF @n_continue = 3
                        BEGIN
                           ROLLBACK TRAN
                        END
                     ELSE
                        BEGIN
                           COMMIT TRAN
                        END
                     END
                  ELSE
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 84703, @c_errmsg = "NSQL84711:" + "FromID Is Invalid or is already shipped"
                     END
                  END
               ELSE
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 84704, @c_errmsg = "NSQL84712:" + "FromID or TOLOC Was Not Supplied"
                  END
               END
               IF (@n_continue = 1 or @n_continue = 2) AND (SUBSTRING(@c_action,1,5) = "PRINT")
               BEGIN
                  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromid)) IS NOT NULL
                  BEGIN
                     IF EXISTS (SELECT dropid FROM dropid where dropid = @c_fromid)
                     BEGIN
                        BEGIN TRANSACTION
                           INSERT poll_print (dropid,printtype) values (@c_fromid,@c_action)
                           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                           IF @n_err <> 0
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=84712   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                              SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Table poll_print. (nspRFTRP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                           END
                           IF @n_continue = 3
                           BEGIN
                              ROLLBACK TRAN
                           END
                        ELSE
                           BEGIN
                              COMMIT TRAN
                           END
                        END
                     ELSE
                        BEGIN
                           IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_caseid)) IS NOT NULL
                           AND EXISTS (SELECT caseid FROM pickdetail where caseid = @c_caseid)
                           BEGIN
                              BEGIN TRANSACTION
                                 INSERT poll_print (caseid,printtype) values (@c_caseid,@c_action)
                                 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                                 IF @n_err <> 0
                                 BEGIN
                                    SELECT @n_continue = 3
                                    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=84712   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                    SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Table poll_print. (nspRFTRP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                                 END
                                 IF @n_continue = 3
                                 BEGIN
                                    ROLLBACK TRAN
                                 END
                              ELSE
                                 BEGIN
                                    COMMIT TRAN
                                 END
                              END
                           ELSE
                              BEGIN
                                 SELECT @n_continue = 3
                                 SELECT @n_err = 84704, @c_errmsg = "NSQL84713:" + "FromID Is Invalid"
                              END
                           END
                        END
                     ELSE
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @n_err = 84704, @c_errmsg = "NSQL84712:" + "FromID Was Not Supplied"
                        END
                     END
                     IF @n_continue=3
                     BEGIN
                        IF @c_retrec="01"
                        BEGIN
                           SELECT @c_retrec="09", @c_appflag = "SH"
                        END
                     END
                  ELSE
                     BEGIN
                        SELECT @c_retrec="01"
                     END
                     SELECT @c_outstring =   @c_ptcid        + @c_senddelimiter
                     + dbo.fnc_RTrim(@c_userid)           + @c_senddelimiter
                     + dbo.fnc_RTrim(@c_taskid)           + @c_senddelimiter
                     + dbo.fnc_RTrim(@c_databasename)     + @c_senddelimiter
                     + dbo.fnc_RTrim(@c_appflag)          + @c_senddelimiter
                     + dbo.fnc_RTrim(@c_retrec)           + @c_senddelimiter
                     + dbo.fnc_RTrim(@c_server)           + @c_senddelimiter
                     + dbo.fnc_RTrim(@c_errmsg)
                     SELECT dbo.fnc_RTrim(@c_outstring)
                     /* #INCLUDE <SPTSP01_2.SQL> */
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
                        execute nsp_logerror @n_err, @c_errmsg, "nspRFSH01"
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