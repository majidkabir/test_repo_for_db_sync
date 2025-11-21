SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTTMEvaluateQCTasks                              */
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

CREATE PROC    [dbo].[nspTTMEvaluateQCTasks]
@c_sendDelimiter    NVARCHAR(1)
,              @c_userid           NVARCHAR(18)
,              @c_strategykey      NVARCHAR(10)
,              @c_ttmstrategykey   NVARCHAR(10)
,              @c_ttmpickcode      NVARCHAR(10)
,              @c_ttmoverride      NVARCHAR(10)
,              @c_areakey01        NVARCHAR(10)
,              @c_areakey02        NVARCHAR(10)
,              @c_areakey03        NVARCHAR(10)
,              @c_areakey04        NVARCHAR(10)
,              @c_areakey05        NVARCHAR(10)
,              @c_lastloc          NVARCHAR(10)
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
   SELECT @b_debug = 0
   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @n_err2 int               -- For Additional Error Detection
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
   DECLARE @n_cqty int, @n_returnrecs int
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   SELECT @n_returnrecs=1
   DECLARE @c_executestmt NVARCHAR(255), @c_AlertMessage NVARCHAR(255), @b_gotarow int
   DECLARE @b_cursor_open int, @c_taskdetailkey NVARCHAR(10)
   DECLARE @c_storerkey NVARCHAR(10), @c_sku NVARCHAR(20), @c_fromloc NVARCHAR(10), @c_fromid NVARCHAR(18),
   @c_toloc NVARCHAR(10), @c_toid NVARCHAR(18), @c_lot NVARCHAR(10), @n_qty int, @c_packkey NVARCHAR(10), @c_uom NVARCHAR(5)
   DECLARE @c_msg01 NVARCHAR(20), @c_msg02 NVARCHAR(20), @c_msg03 NVARCHAR(20), @c_userkeyoverride NVARCHAR(18),
   @b_skipthetask int
   SELECT @b_gotarow = 0
   /* #INCLUDE <SPEVQC_1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLAREcursor_QCTASKCANDIDATES:
      SELECT @b_cursor_open = 0
      SELECT @n_continue = 1 -- Reset just in case the GOTO statements below get executed
      SELECT @c_executestmt = "execute " + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ttmpickcode)) + " "
      + "N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_userid)) + "'" + ","
      + "N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) + "'" + ","
      + "N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey02)) + "'" + ","
      + "N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey03)) + "'" + ","
      + "N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey04)) + "'" + ","
      + "N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey05)) + "'" + ","
      + "N'" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lastloc)) + "'"
      EXECUTE (@c_executestmt)
      SELECT @n_err = @@ERROR
      IF @n_err <> 0 and @n_err <> 16915 and @n_err <> 16905 -- Error #s 16915 and 16905 handled separately below
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=79901   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Execute Of Move Tasks Pick Code Failed. (nspTTMEvaluateQCTasks)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @n_err = 16915
      BEGIN
         CLOSE cursor_QCTASKCANDIDATES
         DEALLOCATE cursor_QCTASKCANDIDATES
         GOTO DECLAREcursor_QCTASKCANDIDATES
      END
      OPEN CURSOR_QCTASKCANDIDATES
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err = 16905
      BEGIN
         CLOSE cursor_QCTASKCANDIDATES
         DEALLOCATE cursor_QCTASKCANDIDATES
         GOTO DECLAREcursor_QCTASKCANDIDATES
      END
      IF @n_err = 0
      BEGIN
         SELECT @b_cursor_open = 1
      END
   END
   IF (@n_continue = 1 or @n_continue = 2) and @b_cursor_open = 1
   BEGIN
      WHILE (1=1) and (@n_continue = 1 or @n_continue = 2)
      BEGIN
         FETCH NEXT FROM cursor_QCTASKCANDIDATES INTO @c_taskdetailkey
         IF @@FETCH_STATUS = -1
         BEGIN
            BREAK
         END
         IF @@FETCH_STATUS = 0
         BEGIN
            SELECT @c_fromloc = taskdetail.fromloc,
            @c_fromid = taskdetail.fromid ,
            @c_userkeyoverride = userkeyoverride,
            @c_msg01 = Message01 ,
            @c_msg02 = Message02 ,
            @c_msg03 = Message03
            FROM TaskDetail
            WHERE TaskDetail.TaskDetailKey = @c_taskdetailkey
            IF @c_userkeyoverride <> "" and @c_userkeyoverride <> @c_userid
            BEGIN
               CONTINUE
            END
            SELECT @b_success = 0, @b_skipthetask = 0
            EXECUTE nspCheckSkipTasks
            @c_userid
            , @c_taskdetailkey
            , "QC"
            , ""
            , ""
            , ""
            , ""
            , ""
            , ""
            , @b_skipthetask OUTPUT
            , @b_Success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue=3
            END
            IF @b_skipthetask = 1
            BEGIN
               CONTINUE
            END
            UPDATE TASKDETAIL
            SET status = "0" ,
            userKey = ""
            WHERE status = "3"
            AND userkey = @c_userid
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=79902   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Occurred While Attempting To Update TaskDetail. (nspTTMEvaluateQCTasks)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               UPDATE TASKDETAIL
               SET status = "3" ,
               userKey = @c_userid ,
               reasonkey = "" ,
               StartTime = CURRENT_TimeStamp
               WHERE TaskDetailKey = @c_taskDetailKey
               AND STATUS = "0"
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=79903   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Occurred While Attempting To Update TaskDetail. (nspTTMEvaluateQCTasks)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               END
               IF @n_cnt = 1
               BEGIN
                  SELECT @b_gotarow = 1
                  BREAK -- We're done.
               END
            END
         END
      END -- WHILE (1=1)
   END
   IF @b_cursor_open = 1
   BEGIN
      CLOSE cursor_QCTASKCANDIDATES
      DEALLOCATE cursor_QCTASKCANDIDATES
   END
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
   IF (@n_continue = 1 or @n_continue = 2) and @b_gotarow = 1
   BEGIN
      SELECT @c_outstring =
      @c_taskdetailkey          + @c_senddelimiter
      + dbo.fnc_RTrim(@c_fromloc)               + @c_senddelimiter
      + dbo.fnc_RTrim(@c_fromid)                + @c_senddelimiter
      + dbo.fnc_RTrim(@c_msg01)                 + @c_senddelimiter
      + dbo.fnc_RTrim(@c_msg02)                 + @c_senddelimiter
      + dbo.fnc_RTrim(@c_msg03)
   END
ELSE
   BEGIN
      SELECT @c_outstring = ""
   END
   /* #INCLUDE <SPEVQC_2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, "nspTTMEvaluateQCTasks"
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