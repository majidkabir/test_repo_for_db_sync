SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTMTM03                                          */
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

CREATE PROC    [dbo].[nspTMTM03]
@c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(18)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(30)
,              @c_appflag          NVARCHAR(5)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_ttm              NVARCHAR(5)
,              @c_taskdetailkey    NVARCHAR(10)
,              @c_reasoncode       NVARCHAR(10)
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
   DECLARE @c_tasktype NVARCHAR(10)
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   SELECT @n_returnrecs=1
   /* #INCLUDE <SPTMTM03_1.SQL> */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @c_reasoncode NOT IN (SELECT TaskManagerReasonKey FROM TaskManagerReason
      WHERE TaskManagerReasonKey = @c_reasoncode
      AND ValidInFromLoc = "1")
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 82901, @c_errmsg = "NSQL82901:Invalid Reason Code"
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF SUBSTRING(@c_taskdetailkey,1,1) = "R" -- Replenishment task.
      BEGIN
         SELECT @c_tasktype = "RP" -- Remember, replenishment tasks are not held in taskdetail - they are dynamic.
      END
   ELSE
      BEGIN
         SELECT @c_tasktype = tasktype
         FROM TASKDETAIL
         WHERE taskdetailkey = @c_taskdetailkey
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS(SELECT * FROM TaskDetail WHERE TaskDetailKey=@c_taskdetailkey and status = "9")
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 82902, @c_errmsg = "NSQL82902:Task Has Been Completed"
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      BEGIN TRAN
         IF @c_tasktype = "PK"
         BEGIN
            UPDATE TASKDETAIL
            SET Reasonkey = @c_reasoncode,
            UserKey = "",
            UserPosition = "1", -- This task is being performed at the FROMLOC
            Statusmsg = "Cancelled/Rejected By User " + @c_userid,
            EndTime = getdate()
            WHERE status = "3"
            AND userkey = @c_userid
            AND tasktype = "PK"
         END
      ELSE
         IF @c_tasktype = "RP"
         BEGIN
            IF EXISTS(SELECT TaskManagerReasonKey FROM TaskManagerReason
            WHERE TaskManagerReasonKey = @c_reasoncode
            AND ValidInFromLoc = "1"
            AND RemoveTaskFromUserQueue = "1"
            )
            BEGIN
               SELECT @b_success = 0
               EXECUTE nspAddSkipTasks
               @c_ptcid
               , @c_userid
               , @c_taskdetailkey
               , "RP"
               , ""
               , "" -- Lot, the function will figure this out
               , "" -- Fromloc, the function will figure this out
               , "" -- Fromid, the function will figure this out
               , "" -- Toloc, the function will figure this out
               , "" -- Toid, the function will figure this out
               , @b_Success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue=3
               END
            END
         END
      ELSE
         BEGIN
            UPDATE TASKDETAIL
            SET Reasonkey = @c_reasoncode,
            UserKey = "",
            UserPosition = "1", -- This task is being performed at the FROMLOC
            Statusmsg = "Cancelled/Rejected By User " + @c_userid,
            EndTime = getdate()
            WHERE taskdetailkey = @c_taskdetailkey
         END
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=82905   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table TaskDetail. (nspRFTRP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
         IF @n_continue = 3
         BEGIN
            ROLLBACK TRAN
         END
      ELSE
         BEGIN
            COMMIT TRAN
         END
      END -- @n_continue = 1 or @n_continue = 2
      IF @n_continue=3
      BEGIN
         IF @c_retrec="01"
         BEGIN
            SELECT @c_retrec="09", @c_appflag = "TM"
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
      /* #INCLUDE <SPTMTM03_2.SQL> */
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
         execute nsp_logerror @n_err, @c_errmsg, "nspTMTM03"
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