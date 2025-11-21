SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPoll                                            */
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

CREATE PROC    [dbo].[nspPoll]
@b_Success     int        = 0  OUTPUT
,              @n_err         int        = 0  OUTPUT
,              @c_errmsg      NVARCHAR(250)  = "" OUTPUT
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @b_debug int             -- Debug On Or Off
   /* #INCLUDE <SPPOLL1.SQL> */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
   @b_debug = 0
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_ucurrentmessage NVARCHAR(254)
      SELECT * INTO #od_poll_update FROM poll_update
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation Of Temp Table Failed (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         DECLARE @n_pollupdatekey int, @c_updatestmt NVARCHAR(255), @c_updatemsg NVARCHAR(255),
         @n_pollupdateretry int, @n_ok_update int
         SELECT @n_pollupdatekey = 0
         WHILE (1=1)
         BEGIN
            SET ROWCOUNT 1
            SELECT @n_pollupdatekey = pollupdatekey,
            @n_pollupdateretry = retrycount,
            @c_updatestmt = UpdateString
            FROM #od_poll_update
            WHERE pollupdatekey > @n_pollupdatekey
            ORDER BY pollupdatekey
            IF @@ROWCOUNT = 0
            BEGIN
               SET ROWCOUNT 0
               BREAK
            END
            SET ROWCOUNT 0
            SELECT @n_ok_update = 1
            BEGIN TRANSACTION
               UPDATE poll_update
               set retrycount = retrycount + 1
               where pollupdatekey = @n_pollupdatekey
               select @n_err = @@ERROR
               IF (@n_err = 0)
               BEGIN
                  Commit tran
               END
            ELSE
               BEGIN
                  rollback tran
               END
               IF @n_pollupdateretry >= 5
               BEGIN
                  SELECT @c_updatemsg = "Update task " + convert(char(5),@n_pollupdatekey)  + " Failed to execute "+@c_errmsg
                  EXECUTE nspLogAlert
                  @c_ModuleName   = "nspPoll",
                  @c_AlertMessage = @c_updatemsg,
                  @n_Severity     = 0,
                  @b_success       = @b_success OUTPUT,
                  @n_err          = @n_err OUTPUT,
                  @c_errmsg       = @c_errmsg OUTPUT
                  DELETE FROM POLL_UPDATE WHERE pollupdatekey = @n_pollupdatekey
                  SELECT @n_ok_update = 0
               END
               IF (@n_ok_update = 1)
               BEGIN
                  BEGIN TRANSACTION
                     EXECUTE (@c_updatestmt)
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        ROLLBACK TRANSACTION
                     END
                  ELSE
                     BEGIN
                        DELETE FROM POLL_UPDATE WHERE pollupdatekey = @n_pollupdatekey
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           ROLLBACK TRANSACTION
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to execute dynamic statement (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                        END
                     ELSE
                        BEGIN
                           COMMIT TRANSACTION
                        END
                     END
                  END
               END
               SET ROWCOUNT 0
            END
         END
         IF @n_continue = 3
         BEGIN
            SELECT @n_continue = 1 -- This is a differnt section of code, can't fail because above failed!
         END
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            SELECT *,pdkey=space(10) INTO #od_poll_pick FROM POLL_PICK
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation Of Temp Table Failed (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               UPDATE #od_poll_pick SET pdkey = pickdetail.pickdetailkey
               FROM pickdetail
               WHERE #od_poll_pick.caseid = pickdetail.caseid
               and pickdetail.status < "5"
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to update temp table (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT #od_poll_pick.* INTO #od_poll_pick_err
               FROM #od_poll_pick
               WHERE dbo.fnc_LTrim(dbo.fnc_RTrim(#od_poll_pick.pdkey)) is NULL
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation Of Temp Table Failed (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               DECLARE @c_caseid NVARCHAR(20), @c_currentmessage NVARCHAR(254)
               SELECT @c_caseid = ""
               WHILE (1=1)
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_caseid = caseid FROM #od_poll_pick_err
                  WHERE caseid > @c_caseid
                  ORDER BY caseid
                  IF @@ROWCOUNT = 0
                  BEGIN
                     SET ROWCOUNT 0
                     BREAK
                  END
                  SET ROWCOUNT 0
                  IF @n_continue = 1 or @n_continue = 2
                  BEGIN
                     SELECT @b_success = 1
                     SELECT @c_currentmessage = "Caseid " + @c_caseid + " - cannot flip Pick Status!"
                     EXECUTE nspLogAlert
                     @c_ModuleName   = "nspPoll",
                     @c_AlertMessage = @c_currentmessage,
                     @n_Severity     = 0,
                     @b_success       = @b_success OUTPUT,
                     @n_err          = @n_err OUTPUT,
                     @c_errmsg       = @c_errmsg OUTPUT
                  END
               END
               SET ROWCOUNT 0
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               DELETE FROM #od_poll_pick
               FROM #od_poll_pick_err
               WHERE #od_poll_pick.caseid = #od_poll_pick_err.caseid
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete From Temp Table Failed (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT @c_caseid = ""
               DECLARE @n_pollpickretrycount int, @n_ok_pick int
               SELECT @n_pollpickretrycount = 0
               SELECT @n_ok_pick = 0
               WHILE (1=1)
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_caseid = caseid, @n_pollpickretrycount = retrycount
                  FROM #od_poll_pick
                  WHERE caseid > @c_caseid
                  ORDER BY caseid
                  IF @@ROWCOUNT = 0
                  BEGIN
                     SET ROWCOUNT 0
                     BREAK
                  END
                  SET ROWCOUNT 0
                  SELECT @n_ok_pick = 0
                  BEGIN TRANSACTION
                     UPDATE POLL_PICK
                     set retrycount = retrycount + 1
                     where caseid = @c_caseid
                     select @n_err = @@error
                     if (@n_err = 0)
                     BEGIN
                        COMMIT TRANSACTION
                     END
                  ELSE
                     BEGIN
                        ROLLBACK TRANSACTION
                     END
                     IF @n_pollpickretrycount >= 5
                     BEGIN
                        SELECT @c_currentmessage = "Caseid " + @c_caseid + " Could Not Be Flipped To Pick Status after 5 trys!"
                        EXECUTE nspLogAlert
                        @c_ModuleName   = "nspPoll",
                        @c_AlertMessage = @c_currentmessage,
                        @n_Severity     = 0,
                        @b_success       = @b_success OUTPUT,
                        @n_err          = @n_err OUTPUT,
                        @c_errmsg       = @c_errmsg OUTPUT
                        DELETE from POLL_PICK where caseid = @c_caseid
                        SELECT @n_ok_pick = 1
                     END
                     IF (@n_ok_pick = 0)
                     BEGIN
                        BEGIN TRANSACTION
                           UPDATE PICKDETAIL SET STATUS = "5"
                           WHERE pickdetail.caseid = @c_caseid
                           and pickdetail.status < "5"
                           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                           IF @n_err <> 0
                           BEGIN
                              ROLLBACK TRANSACTION
                           END
                        ELSE
                           BEGIN
                              DELETE from POLL_PICK where caseid = @c_caseid
                              SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                              IF @n_err <> 0
                              BEGIN
                                 ROLLBACK TRANSACTION
                                 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to flip pickdetail status to 5 (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                              END
                           ELSE
                              BEGIN
                                 COMMIT TRANSACTION
                              END
                           END
                        END
                     END
                  END
                  IF @n_continue = 1 or @n_continue = 2
                  BEGIN
                     DELETE FROM poll_pick
                     FROM #od_poll_pick_err
                     WHERE #od_poll_pick_err.caseid = poll_pick.caseid
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74702  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation Of Temp Table Failed (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                     END
                  END
               END
               IF @n_continue = 3
               BEGIN
                  SELECT @n_continue = 1 -- This is a differnt section of code, can't fail because above failed!
               END
               IF @n_continue = 1 or @n_continue = 2
               BEGIN
                  SELECT *,pdkey=space(10) INTO #od_poll_ship FROM poll_ship
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation Of Temp Table Failed (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  END
                  IF @n_continue = 1 or @n_continue = 2
                  BEGIN
                     UPDATE #od_poll_ship SET pdkey = pickdetail.pickdetailkey
                     FROM pickdetail, #od_poll_ship
                     WHERE #od_poll_ship.caseid = pickdetail.caseid
                     and pickdetail.status < "9"
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to update temp table (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                     END
                  END
                  IF @n_continue = 1 or @n_continue = 2
                  BEGIN
                     SELECT #od_poll_ship.* INTO #od_poll_ship_err
                     FROM #od_poll_ship
                     WHERE dbo.fnc_LTrim(dbo.fnc_RTrim(#od_poll_ship.pdkey)) is NULL
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation Of Temp Table Failed (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                     END
                  END
                  IF @n_continue = 1 or @n_continue = 2
                  BEGIN
                     DECLARE @c_scaseid NVARCHAR(20), @c_scurrentmessage NVARCHAR(254)
                     SELECT @c_scaseid = ""
                     WHILE (1=1)
                     BEGIN
                        SET ROWCOUNT 1
                        SELECT @c_scaseid = caseid FROM #od_poll_ship_err
                        WHERE caseid > @c_scaseid
                        ORDER BY caseid
                        IF @@ROWCOUNT = 0
                        BEGIN
                           SET ROWCOUNT 0
                           BREAK
                        END
                        SET ROWCOUNT 0
                        IF @n_continue = 1 or @n_continue = 2
                        BEGIN
                           SELECT @b_success = 1
                           SELECT @c_scurrentmessage = "Caseid " + @c_scaseid + " : cannot flip to Ship Status!"
                           EXECUTE nspLogAlert
                           @c_ModuleName   = "nspPoll",
                           @c_AlertMessage = @c_scurrentmessage,
                           @n_Severity     = 0,
                           @b_success       = @b_success OUTPUT,
                           @n_err          = @n_err OUTPUT,
                           @c_errmsg       = @c_errmsg OUTPUT
                        END
                     END
                     SET ROWCOUNT 0
                  END
                  IF @n_continue = 1 or @n_continue = 2
                  BEGIN
                     DELETE FROM #od_poll_ship
                     FROM #od_poll_ship_err, #od_poll_ship
                     WHERE #od_poll_ship.caseid = #od_poll_ship_err.caseid
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete From Temp Table Failed (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                     END
                  END
                  IF @n_continue = 1 or @n_continue = 2
                  BEGIN
                     DECLARE @n_pollshipretrycount int, @n_ok_ship int
                     SELECT @c_caseid = ""
                     SELECT @n_pollshipretrycount = 0
                     SELECT @n_ok_ship = 0
                     WHILE (1=1)
                     BEGIN
                        SET ROWCOUNT 1
                        SELECT @c_caseid = caseid, @n_pollshipretrycount = retrycount
                        FROM #od_poll_ship
                        WHERE caseid > @c_caseid
                        ORDER BY caseid
                        IF @@ROWCOUNT = 0
                        BEGIN
                           SET ROWCOUNT 0
                           BREAK
                        END
                        SET ROWCOUNT 0
                        SELECT @n_ok_ship = 0
                        BEGIN TRANSACTION
                           UPDATE POLL_SHIP
                           set retrycount = retrycount + 1
                           where caseid = @c_caseid
                           select @n_err = @@error
                           if (@n_err = 0)
                           BEGIN
                              COMMIT TRANSACTION
                           END
                        ELSE
                           BEGIN
                              ROLLBACK TRANSACTION
                           END
                           IF @n_pollshipretrycount >= 5
                           BEGIN
                              SELECT @c_currentmessage = "Caseid " + @c_caseid + " Could Not Be Flipped To Ship Status after 5 trys!"
                              EXECUTE nspLogAlert
                              @c_ModuleName   = "nspPoll",
                              @c_AlertMessage = @c_currentmessage,
                              @n_Severity     = 0,
                              @b_success       = @b_success OUTPUT,
                              @n_err          = @n_err OUTPUT,
                              @c_errmsg       = @c_errmsg OUTPUT
                              DELETE from POLL_SHIP where caseid = @c_caseid
                              SELECT @n_ok_SHIP = 1
                           END
                           IF (@b_debug = 1)
                           BEGIN
                              select 'before going to update to 9 loop for shipping '
                              select * from #od_poll_ship
                              order by caseid
                              select '@c_caseid = ', @c_caseid,  '@n_ok_ship should be 0', @n_ok_ship
                           END
                           IF (@n_ok_ship = 0)
                           BEGIN
                              BEGIN TRANSACTION
                                 UPDATE PICKDETAIL SET STATUS = "9"
                                 FROM PICKDETAIL
                                 WHERE pickdetail.caseid = @c_caseid
                                 and pickdetail.status < "9"
                                 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                                 IF @n_err <> 0
                                 BEGIN
                                    ROLLBACK TRANSACTION
                                 END
                              ELSE
                                 BEGIN
                                    DELETE from POLL_SHIP where caseid = @c_caseid
                                    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                                    IF @n_err <> 0
                                    BEGIN
                                       ROLLBACK TRANSACTION
                                       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to flip pickdetail status to 9 (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                                    END
                                 ELSE
                                    BEGIN
                                       COMMIT TRANSACTION
                                    END
                                 END
                              END
                           END
                           set rowcount 0
                        END
                        IF @n_continue = 1 or @n_continue = 2
                        BEGIN
                           DELETE FROM poll_ship
                           FROM #od_poll_ship_err
                           WHERE #od_poll_ship_err.caseid = poll_ship.caseid
                           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                           IF @n_err <> 0
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74702  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                              SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation Of Temp Table Failed (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                           END
                        END
                     END
                     IF @n_continue = 3
                     BEGIN
                        SELECT @n_continue = 1 -- This is a differnt section of code, can't fail because above failed!
                     END
                     IF (@b_debug = 1)
                     BEGIN
                        SELECT @n_continue , 'value of @n_continue before alloc '
                        select * from poll_allocate
                     END
                     IF @n_continue = 1 or @n_continue = 2
                     BEGIN
                        SELECT * INTO #od_poll_allocate FROM poll_allocate
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation Of Temp Table Failed (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                        END
                        IF @n_continue = 1 or @n_continue = 2
                        BEGIN
                           DECLARE @c_orderkey NVARCHAR(10), @c_allocmessage NVARCHAR(254), @n_retrycount int,
                           @n_ok_print int , @n_ok_allocate int
                           SELECT @c_orderkey = ""
                           SELECT @n_ok_print = 0
                           WHILE (1=1)
                           BEGIN
                              SET ROWCOUNT 1
                              SELECT @c_orderkey = orderkey, @n_retrycount = retrycount
                              FROM #od_poll_allocate
                              WHERE orderkey > @c_orderkey
                              ORDER BY orderkey
                              select @n_err = @@error, @n_cnt = @@rowcount
                              IF @n_cnt = 0
                              BEGIN
                                 SET ROWCOUNT 0
                                 BREAK
                              END
                              IF (@n_err <> 0)
                              BEGIN
                                 SELECT @n_continue = 3
                                 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": @c_order key selection Failed (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                              END
                              SELECT @n_ok_print = 0
                              SELECT @n_ok_allocate = 0
                              IF @n_retrycount >= 5
                              BEGIN
                                 SELECT @c_allocmessage = "Order Key " + @c_orderkey + " Failed to Allocate. "+@c_errmsg
                                 EXECUTE nspLogAlert
                                 @c_ModuleName   = "nspPoll",
                                 @c_AlertMessage = @c_allocmessage,
                                 @n_Severity     = 0,
                                 @b_success       = @b_success OUTPUT,
                                 @n_err          = @n_err OUTPUT,
                                 @c_errmsg       = @c_errmsg OUTPUT
                                 DELETE FROM poll_allocate WHERE ORDERKEY = @c_orderkey
                                 SELECT @n_ok_allocate = 0
                                 SELECT @n_ok_print = 0
                              END
                           ELSE
                              BEGIN
                                 SELECT @n_ok_allocate = 1
                              END
                              SET ROWCOUNT 0
                              BEGIN TRAN
                                 UPDATE poll_allocate
                                 set retrycount = retrycount + 1
                                 WHERE ORDERKEY = @c_orderkey
                                 select @n_err = @@error, @n_cnt = @@rowcount
                                 IF (@b_debug = 1)
                                 BEGIN
                                    select 'orderkey = ', @c_orderkey, 'try = ',@n_retrycount, 'in poll_allocate'
                                    select * from poll_allocate
                                 END
                                 IF (@n_err = 0)
                                 BEGIN
                                    COMMIT TRAN
                                 END
                              ELSE
                                 BEGIN
                                    SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                    SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Retry update of poll_allocate failed (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                                 END
                                 IF (@n_retrycount > 5 AND @n_err = 0)
                                 BEGIN
                                    DELETE PICKDETAIL where ORDERKEY = @c_orderkey
                                    AND SUBSTRING(caseid,1,1) = "C"
                                    select @n_err = @@error, @n_cnt = @@rowcount
                                    IF (@n_err <> 0)
                                    BEGIN
                                       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Retry > 1 PD delete failed (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                                    END
                                 END
                                 IF (@b_debug = 1)
                                 BEGIN
                                    select 'I am here before allocation, n_cont = ', @n_continue, @c_orderkey
                                 END
                                 IF (@n_ok_allocate = 1)
                                 BEGIN
                                    SELECT @b_success = 1
                                    EXECUTE nspOrderProcessing
                                    @c_orderkey,
                                    "",
                                    "Y",
                                    "N",
                                    "",
                                    @b_success       = @b_success OUTPUT,
                                    @n_err          = @n_err OUTPUT,
                                    @c_errmsg       = @c_errmsg OUTPUT
                                    IF @b_success = 1
                                    BEGIN
                                       SELECT @n_ok_print = 1
                                    END
                                    IF NOT @b_success = 1
                                    BEGIN
                                       SELECT @n_ok_print = 0
                                    END
                                 END
                                 if (@b_debug = 1)
                                 BEGIN
                                    select @c_orderkey, '@b_success = ', @b_success
                                    select @c_errmsg
                                    select '@n_ok_print = ', @n_ok_print
                                 END
                                 IF @n_ok_print = 1
                                 BEGIN
                                    BEGIN TRAN
                                       DELETE FROM poll_allocate where orderkey = @c_orderkey
                                       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                                       IF @n_err <> 0
                                       BEGIN
                                          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to delete from poll_allocate (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                                       END
                                       IF @n_continue = 1 or @n_continue = 2
                                       BEGIN
                                          INSERT POLL_PRINT (printtype,orderkey)
                                          VALUES("ORDER",@c_orderkey)
                                          SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                                          IF @n_err <> 0
                                          BEGIN
                                             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to insert into poll_print (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                                          END
                                       END
                                       IF @n_continue = 1 or @n_continue = 2
                                       BEGIN
                                          COMMIT TRAN
                                       END
                                    ELSE
                                       BEGIN
                                          ROLLBACK TRAN
                                       END
                                    END
                                 END
                                 SET ROWCOUNT 0
                              END
                           END
                           IF @n_continue = 3
                           BEGIN
                              SELECT @n_continue = 1 -- This is a differnt section of code, can't fail because above failed!
                           END
                           IF @n_continue = 1 or @n_continue = 2
                           BEGIN
                              UPDATE PICKDETAIL SET PICKDETAIL.STATUS = "1", trafficcop = NULL
                              FROM POLL_PRINT
                              WHERE POLL_PRINT.orderkey = pickdetail.orderkey
                              and POLL_PRINT.status = "9"
                              and PICKDETAIL.status = "0"
                              and POLL_PRINT.printtype = "ORDER"
                              SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                              IF @n_err <> 0
                              BEGIN
                                 SELECT @n_continue = 3
                                 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to update the pickdetail table (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                              END
                              IF @n_continue = 1 or @n_continue = 2
                              BEGIN
                                 DELETE FROM POLL_PRINT WHERE STATUS = "9"
                                 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                                 IF @n_err <> 0
                                 BEGIN
                                    SELECT @n_continue = 3
                                    SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 74701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                    SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to delete from the poll_print table (nspPoll)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                                 END
                              END
                           END
                           /* #INCLUDE <SPPOLL2.SQL> */
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
                              EXECUTE nsp_logerror @n_err, @c_errmsg, "nspPoll"
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