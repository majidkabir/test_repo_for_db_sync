SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTTMPK01                                         */
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

CREATE PROC    [dbo].[nspTTMPK01]
@c_userid      NVARCHAR(18)
,              @c_areakey01        NVARCHAR(10)
,              @c_areakey02        NVARCHAR(10)
,              @c_areakey03        NVARCHAR(10)
,              @c_areakey04        NVARCHAR(10)
,              @c_areakey05        NVARCHAR(10)
,              @c_lastloc          NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT  @b_debug = 0
   DECLARE @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @n_err2 int             , -- For Additional Error Detection
   @b_Success int          ,
   @n_err int              ,
   @c_errmsg NVARCHAR(250)
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_err2=0
   DECLARE @c_executestmt NVARCHAR(255)
   DECLARE @c_lastcaseid NVARCHAR(10), @c_lastwavekey NVARCHAR(10), @c_lastorderkey NVARCHAR(10), @c_lastroute NVARCHAR(10),
   @c_laststop NVARCHAR(10)
   DECLARE @b_gotarow int, @b_rowcheckpass int, @b_evaluationtype int,
   @b_doeval01_only int
   SELECT @b_gotarow = 0, @b_rowcheckpass = 0, @b_doeval01_only = 0
   DECLARE @c_taskdetailkey NVARCHAR(10), @c_caseid NVARCHAR(10), @c_orderkey NVARCHAR(10), @c_orderlinenumber NVARCHAR(5),
   @c_wavekey NVARCHAR(10), @c_storerkey NVARCHAR(15), @c_sku NVARCHAR(20), @c_loc NVARCHAR(10), @c_id NVARCHAR(18),
   @c_lot NVARCHAR(10), @c_uom NVARCHAR(10), @c_userkeyoverride NVARCHAR(18), @c_packkey NVARCHAR(15), @c_logicalloc NVARCHAR(18),
   @c_route NVARCHAR(10), @c_stop NVARCHAR(10), @c_door NVARCHAR(10),
   @c_message01 NVARCHAR(20), @c_message02 NVARCHAR(20), @c_message03 NVARCHAR(20)
   DECLARE @c_palletpickdispatchmethod NVARCHAR(10), @c_casepickdispatchmethod NVARCHAR(10), @c_piecepickdispatchmethod NVARCHAR(10)
   DECLARE @n_temptable_recordcount int, @n_temptable_qty int, @c_loctype NVARCHAR(10), @c_uomtext NVARCHAR(10),
   @c_temptaskdetailkey NVARCHAR(10), @c_caseidtodelete NVARCHAR(10), @n_countcaseidtodelete int,
   @b_skipthetask int
   DECLARE @b_cursor_EVAL01_open int, @b_cursor_EVAL02_open int,  @b_cursor_EVAL03_open int, @b_cursor_EVAL04_open int,
   @b_cursor_EVAL05_open int, @b_cursor_EVAL06_open int, @b_cursor_EVAL07_open int,  @b_cursor_evalbatchpick_open int,
   @b_temptablecreated int
   DECLARE  @c_lastloadkey NVARCHAR(10), @c_loadkey NVARCHAR(10)  , @c_sourcetype NVARCHAR(15)
   SELECT @b_cursor_EVAL01_open = 0,
   @b_cursor_EVAL02_open = 0,
   @b_cursor_EVAL03_open = 0,
   @b_cursor_EVAL04_open = 0,
   @b_cursor_EVAL05_open = 0,
   @b_cursor_EVAL06_open = 0,
   @b_cursor_EVAL07_open = 0,
   @b_cursor_evalbatchpick_open = 0,
   @b_temptablecreated   = 0
   /* #INCLUDE <SPTMPK01_1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      CREATE TABLE #temp_dispatchcaseid
      (
      taskdetailkey NVARCHAR(10),
      caseid NVARCHAR(10),
      qty int
      )
      SELECT @b_temptablecreated = 1
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey02)) IS NOT NULL
      BEGIN
         SELECT @c_lastcaseid = @c_areakey02
         SET ROWCOUNT 1
         SELECT @c_lastwavekey = wavekey
         FROM TASKDETAIL
         WHERE caseid = @c_lastcaseid
         AND tasktype = 'PK'
         AND STATUS = '0'
         SET ROWCOUNT 0
         IF @c_lastwavekey IS NULL
         BEGIN
            SELECT @c_lastwavekey = ''
         END
         SELECT @b_doeval01_only = 1 -- Only search this caseid for the next task - do not search for anything else.
      END
   ELSE
      BEGIN
         SELECT @c_lastcaseid = lastcaseidpicked,
         @c_lastwavekey = lastwavekey
         FROM TaskManagerUser
         WHERE userkey = @c_userid
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lastcaseid)) IS NOT NULL
      BEGIN
         SET ROWCOUNT 1
         SELECT @c_lastorderkey = orderkey
         FROM  PICKDETAIL (NOLOCK)
         WHERE CASEID = @c_lastcaseid
         SET ROWCOUNT 0
         SELECT @c_lastroute = route, @c_laststop = stop
         FROM ORDERS (NOLOCK)
         WHERE ORDERKEY = @c_lastorderkey
      END
   ELSE
      BEGIN
         SELECT @c_lastcaseid = '', @c_lastwavekey = '', @c_lastorderkey = '', @c_lastroute = '', @c_laststop = ''
      END
   END
   DECLARE @c_priority NVARCHAR(10)
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET ROWCOUNT 1
      SELECT DISTINCT
      @c_lastloadkey = TA.SOURCEKEY,
      @c_priority = TA.Priority
      FROM TASKDETAIL TA (NOLOCK)
      WHERE TA.Sourcetype = 'BATCHPICK'
      AND TA.Tasktype = 'PK'
      AND TA.Status = '0'
      AND NOT EXISTS( SELECT 1 FROM TaskManagerSkipTasks (NOLOCK)
      WHERE TaskManagerSkipTasks.Taskdetailkey = TA.TaskDetailkey)
      ORDER BY TA.PRIORITY
      SET ROWCOUNT 0
      IF @b_debug = 1
      BEGIN
         SELECT 'Loadkey' = @c_lastloadkey
      END
   END
   STARTPROCESSING:
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT 'start processing'
      END
      UPDATE TASKDETAIL
      SET STATUS = '0',
      USERKEY = '',
      REASONKEY = ''
      WHERE USERKEY = @c_userid
      AND STATUS < '9'
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=81201   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update to taskdetail table failed. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
      IF @b_debug = 1
      BEGIN
         SELECT 'Records where the userkey is equal to ',@c_userid, ' status is in process '
         SELECT * FROM TASKDETAIL where USERKEY = @c_userid and STATUS < '9'
      END
   END
   WHILE (1=1) AND ( @n_continue = 1 or @n_continue = 2 )
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT 'Start Evaluating'
      END
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lastcaseid)) IS NOT NULL
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT 'DECLARECURSOR_EVAL01'
         END
         DECLARECURSOR_EVAL01:
         SELECT @b_cursor_EVAL01_open = 0
         DECLARE cursor_EVAL01
         CURSOR FOR
         SELECT taskdetailkey
         FROM TASKDETAIL
         WHERE ORDERKEY = @c_lastorderkey
         AND TASKTYPE = 'PK'
         AND USERKEY = ''
         AND STATUS = '0'
         AND PICKMETHOD = '1'
         AND CASEID = @c_lastcaseid
         ORDER BY Priority, LOGICALFROMLOC
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err = 16915
         BEGIN
            CLOSE cursor_EVAL01
            DEALLOCATE cursor_EVAL01
            GOTO DECLARECURSOR_EVAL01
         END
         OPEN cursor_EVAL01
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err = 16905
         BEGIN
            CLOSE cursor_EVAL01
            DEALLOCATE cursor_EVAL01
            GOTO DECLARECURSOR_EVAL01
         END
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81202   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Could not Open cursor_EVAL01. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      ELSE
         BEGIN
            SELECT @b_cursor_EVAL01_open = 1
         END
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            WHILE (1=1)
            BEGIN
               FETCH NEXT FROM cursor_EVAL01 INTO @c_taskdetailkey
               IF @@FETCH_STATUS <> 0
               BEGIN
                  BREAK
               END
               SELECT @c_taskdetailkey = taskdetailkey,
               @c_caseid = caseid,
               @c_orderkey = orderkey,
               @c_orderlinenumber = orderlinenumber,
               @c_wavekey = wavekey,
               @c_storerkey = storerkey,
               @c_sku = sku,
               @c_loc = fromloc,
               @c_logicalloc = logicalfromloc,
               @c_id = fromid,
               @c_lot = lot,
               @c_uom = uom,
               @c_userkeyoverride = userkeyoverride
               FROM TASKDETAIL
               WHERE TASKDETAILKEY = @c_taskdetailkey
               SELECT @b_evaluationtype = 1
               SELECT @b_rowcheckpass = 0
               GOTO CHECKROW
               EVALUATIONTYPERETURN_01:
               IF @b_rowcheckpass = 1
               BEGIN
                  SELECT @b_gotarow = 1
                  GOTO DISPATCH
               END
            END -- WHILE (1=1)
         END
      END
      IF (@n_continue = 1 or @n_continue = 2) AND @b_doeval01_only = 0
      BEGIN
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lastorderkey)) IS NOT NULL
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT 'DECLARECURSOR_EVAL02'
            END
            DECLARECURSOR_EVAL02:
            SELECT @b_cursor_EVAL02_open = 0
            DECLARE cursor_EVAL02
            CURSOR FOR
            SELECT taskdetailkey FROM TASKDETAIL
            WHERE ORDERKEY = @c_lastorderkey
            AND TASKTYPE = 'PK'
            AND USERKEY = ''
            AND STATUS = '0'
            AND PICKMETHOD = '1'
            AND WAVEKEY = @c_lastwavekey
            ORDER BY Priority, LOGICALFROMLOC
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err = 16915
            BEGIN
               CLOSE cursor_EVAL02
               DEALLOCATE cursor_EVAL02
               GOTO DECLARECURSOR_EVAL02
            END
            OPEN cursor_EVAL02
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err = 16905
            BEGIN
               CLOSE cursor_EVAL02
               DEALLOCATE cursor_EVAL02
               GOTO DECLARECURSOR_EVAL02
            END
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81203   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Could not Open cursor_EVAL02. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         ELSE
            BEGIN
               SELECT @b_cursor_EVAL02_open = 1
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               WHILE (1=1)
               BEGIN
                  FETCH NEXT FROM cursor_EVAL02 INTO @c_taskdetailkey
                  IF @@FETCH_STATUS <> 0
                  BEGIN
                     BREAK
                  END
                  SELECT @c_taskdetailkey = taskdetailkey,
                  @c_caseid = caseid,
                  @c_orderkey = orderkey,
                  @c_orderlinenumber = orderlinenumber,
                  @c_wavekey = wavekey,
                  @c_storerkey = storerkey,
                  @c_sku = sku,
                  @c_loc = fromloc,
                  @c_logicalloc = logicalfromloc,
                  @c_id = fromid,
                  @c_lot = lot,
                  @c_uom = uom,
                  @c_userkeyoverride = userkeyoverride
                  FROM TASKDETAIL
                  WHERE TASKDETAILKEY = @c_taskdetailkey
                  SELECT @b_evaluationtype = 2
                  SELECT @b_rowcheckpass = 0
                  GOTO CHECKROW
                  EVALUATIONTYPERETURN_02:
                  IF @b_rowcheckpass = 1
                  BEGIN
                     SELECT @b_gotarow = 1
                     GOTO DISPATCH
                  END
               END -- WHILE (1=1)
            END
         END
      END
      IF (@n_continue = 1 or @n_continue = 2) AND @b_doeval01_only = 0
      BEGIN
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lastroute)) IS NOT NULL and dbo.fnc_LTrim(dbo.fnc_RTrim(@c_laststop)) IS NOT NULL
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT 'DECLARECURSOR_EVAL03'
            END
            DECLARECURSOR_EVAL03:
            SELECT @b_cursor_EVAL03_open = 0
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) IS NOT NULL
            BEGIN
               DECLARE cursor_EVAL03
               CURSOR FOR
               SELECT taskdetailkey FROM TASKDETAIL,ORDERS,LOC,AREADETAIL
               WHERE TASKDETAIL.ORDERKEY = ORDERS.ORDERKEY
               AND AreaDetail.AreaKey = @c_areakey01
               AND AreaDetail.Putawayzone = Loc.PutAwayZone
               AND TaskDetail.FromLoc = Loc.Loc
               AND Orders.ROUTE = @c_lastroute
               AND Orders.STOP = @c_laststop
               AND TaskDetail.TASKTYPE = 'PK'
               AND TaskDetail.USERKEY = ''
               AND TaskDetail.STATUS = '0'
               AND TaskDetail.PICKMETHOD = '1'
               AND TaskDetail.WAVEKEY = @c_lastwavekey
               ORDER BY TASKDETAIL.PRIORITY,
               TASKDETAIL.LOGICALFROMLOC
            END
         ELSE
            BEGIN
               DECLARE cursor_EVAL03
               CURSOR FOR
               SELECT taskdetailkey FROM TASKDETAIL,ORDERS,LOC,AREADETAIL,TaskManagerUserDetail
               WHERE TASKDETAIL.ORDERKEY = ORDERS.ORDERKEY
               AND AreaDetail.Putawayzone = Loc.PutAwayZone
               AND TaskManagerUserDetail.UserKey = @c_userid
               AND TaskManagerUserDetail.PermissionType = 'PK'
               AND TaskManagerUserDetail.Permission = '1'
               AND TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
               AND TaskDetail.FromLoc = Loc.Loc
               AND Orders.Route = @c_lastroute
               AND Orders.Stop = @c_laststop
               AND TaskDetail.TASKTYPE = 'PK'
               AND TaskDetail.USERKEY = ''
               AND TaskDetail.STATUS = '0'
               AND TaskDetail.PICKMETHOD = '1'
               AND TaskDetail.WAVEKEY = @c_lastwavekey
               ORDER BY TASKDETAIL.PRIORITY,
               TASKDETAIL.LOGICALFROMLOC
            END
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err = 16915
            BEGIN
               CLOSE cursor_EVAL03
               DEALLOCATE cursor_EVAL03
               GOTO DECLARECURSOR_EVAL03
            END
            OPEN cursor_EVAL03
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err = 16905
            BEGIN
               CLOSE cursor_EVAL03
               DEALLOCATE cursor_EVAL03
               GOTO DECLARECURSOR_EVAL03
            END
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81204   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Could not Open cursor_EVAL02. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         ELSE
            BEGIN
               SELECT @b_cursor_EVAL03_open = 1
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               WHILE (1=1)
               BEGIN
                  FETCH NEXT FROM cursor_EVAL03 INTO @c_taskdetailkey
                  IF @@FETCH_STATUS <> 0
                  BEGIN
                     BREAK
                  END
                  SELECT @c_taskdetailkey = taskdetailkey,
                  @c_caseid = caseid,
                  @c_orderkey = orderkey,
                  @c_orderlinenumber = orderlinenumber,
                  @c_wavekey = wavekey,
                  @c_storerkey = storerkey,
                  @c_sku = sku,
                  @c_loc = fromloc,
                  @c_logicalloc = logicalfromloc,
                  @c_id = fromid,
                  @c_lot = lot,
                  @c_uom = uom,
                  @c_userkeyoverride = userkeyoverride
                  FROM TASKDETAIL
                  WHERE TASKDETAILKEY = @c_taskdetailkey
                  SELECT @b_evaluationtype = 3
                  SELECT @b_rowcheckpass = 0
                  GOTO CHECKROW
                  EVALUATIONTYPERETURN_03:
                  IF @b_rowcheckpass = 1
                  BEGIN
                     SELECT @b_gotarow = 1
                     GOTO DISPATCH
                  END
               END -- WHILE (1=1)
            END
         END
      END
      -- Batch Picking
      IF (@n_continue = 1 or @n_continue = 2) AND @b_doeval01_only = 0
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT 'EValuating batch pick tasks'
            SELECT '@c_lastloadkey' = @c_lastloadkey
         END
         -- IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lastroute)) IS NOT NULL and dbo.fnc_LTrim(dbo.fnc_RTrim(@c_laststop)) IS NOT NULL
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lastloadkey)) IS NOT NULL
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT 'DECLARE CURSOR_EVALBATCHPICK'
            END
            DECLARECURSOR_EVALBATCHPICK:
            SELECT @b_cursor_evalbatchpick_open = 0
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) IS NOT NULL
            BEGIN
               DECLARE CURSOR_EVALBATCHPICK
               CURSOR FOR
               SELECT taskdetailkey
               FROM TASKDETAIL (nolock) ,LOC (nolock) ,AREADETAIL (nolock), TaskManagerUserDetail  (nolock)
               WHERE AreaDetail.AreaKey = @c_areakey01
               AND AreaDetail.Putawayzone = Loc.PutAwayZone
               AND TaskManagerUserDetail.UserKey = @c_userid
               AND TaskManagerUserDetail.PermissionType = 'PK'
               AND TaskManagerUserDetail.Permission = '1'
               AND TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
               AND TaskDetail.FromLoc = Loc.Loc
               -- AND Orders.ROUTE = @c_lastroute
               -- AND Orders.STOP = @c_laststop
               AND TaskDetail.TASKTYPE = 'PK'
               AND TaskDetail.USERKEY = ''
               AND TaskDetail.STATUS = '0'
               AND TaskDetail.PICKMETHOD = '1'
               -- AND TaskDetail.WAVEKEY = @c_lastwavekey
               -- AND TASKDETAIL.Sourcekey = @c_lastloadkey
               --  AND TASKDETAIL.Sourcetype = 'BATCHPICK'
               ORDER BY TASKDETAIL.PRIORITY,
               TASKDETAIL.LOGICALFROMLOC
            END
         ELSE
            BEGIN
               DECLARE CURSOR_EVALBATCHPICK
               CURSOR FOR
               SELECT taskdetailkey
               FROM TASKDETAIL (nolock) ,LOC (nolock),AREADETAIL (nolock),TaskManagerUserDetail  (nolock)
               WHERE AreaDetail.Putawayzone = Loc.PutAwayZone
               AND TaskManagerUserDetail.UserKey = @c_userid
               AND TaskManagerUserDetail.PermissionType = 'PK'
               AND TaskManagerUserDetail.Permission = '1'
               AND TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
               AND TaskDetail.FromLoc = Loc.Loc
               AND TaskDetail.TASKTYPE = 'PK'
               AND TaskDetail.USERKEY = ''
               AND TaskDetail.STATUS = '0'
               AND TaskDetail.PICKMETHOD = '1'
               --AND TaskDetail.SOURCEKEY = @c_lastloadkey
               ORDER BY TASKDETAIL.PRIORITY,
               TASKDETAIL.LOGICALFROMLOC
            END
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err = 16915
            BEGIN
               CLOSE CURSOR_EVALBATCHPICK
               DEALLOCATE CURSOR_EVALBATCHPICK
               GOTO DECLARECURSOR_EVALBATCHPICK
            END
            OPEN CURSOR_EVALBATCHPICK
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err = 16905
            BEGIN
               CLOSE CURSOR_EVALBATCHPICK
               DEALLOCATE CURSOR_EVALBATCHPICK
               GOTO DECLARECURSOR_EVALBATCHPICK
            END
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81204   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Could not Open CURSOR_EVALBATCHPICK. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         ELSE
            BEGIN
               SELECT @b_cursor_evalbatchpick_open = 1
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               WHILE (1=1)
               BEGIN
                  FETCH NEXT FROM CURSOR_EVALBATCHPICK INTO @c_taskdetailkey
                  IF @@FETCH_STATUS <> 0
                  BEGIN
                     BREAK
                  END
                  SELECT @c_taskdetailkey = taskdetailkey,
                  @c_caseid = caseid,
                  @c_orderkey = orderkey,
                  @c_loadkey = SOURCEKEY,
                  @c_sourcetype = SOURCETYPE ,
                  @c_orderlinenumber = orderlinenumber,
                  @c_wavekey = wavekey,
                  @c_storerkey = storerkey,
                  @c_sku = sku,
                  @c_loc = fromloc,
                  @c_logicalloc = logicalfromloc,
                  @c_id = fromid,
                  @c_lot = lot,
                  @c_uom = uom,
                  @c_userkeyoverride = userkeyoverride
                  FROM TASKDETAIL (NOLOCK)
                  WHERE TASKDETAILKEY = @c_taskdetailkey
                  --     AND SOURCETYPE = 'BATCHPICK'
                  SELECT @b_evaluationtype = 9
                  SELECT @b_rowcheckpass = 0
                  GOTO CHECKROW
                  EVALUATIONTYPERETURN_BATCHPICK:
                  IF @b_rowcheckpass = 1
                  BEGIN
                     SELECT @b_gotarow = 1
                     GOTO DISPATCH
                  END
               END -- WHILE (1=1)
            END
         END
      END
      -- Batch Picking
      IF (@n_continue = 1 or @n_continue = 2) AND @b_doeval01_only = 0
      BEGIN
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lastorderkey)) IS NOT NULL and dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lastwavekey)) IS NOT NULL
         BEGIN
            DECLARECURSOR_EVAL04:
            SELECT @b_cursor_EVAL04_open = 0
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) IS NOT NULL
            BEGIN
               DECLARE cursor_EVAL04
               CURSOR FOR
               SELECT taskdetailkey FROM TASKDETAIL,LOC,AREADETAIL,ORDERS
               WHERE AreaDetail.AreaKey = @c_areakey01
               AND AreaDetail.Putawayzone = Loc.PutAwayZone
               AND TaskDetail.FromLoc = Loc.Loc
               AND TaskDetail.TASKTYPE = 'PK'
               AND TaskDetail.USERKEY = ''
               AND TaskDetail.STATUS = '0'
               AND TaskDetail.PICKMETHOD = '1'
               AND TaskDetail.WAVEKEY = @c_lastwavekey
               AND TaskDetail.ORDERKEY = ORDERS.Orderkey
               ORDER BY TASKDETAIL.PRIORITY,
               ORDERS.ROUTE,
               ORDERS.STOP DESC,
               TASKDETAIL.LOGICALFROMLOC
            END
         ELSE
            BEGIN
               DECLARE cursor_EVAL04
               CURSOR FOR
               SELECT taskdetailkey FROM TASKDETAIL,LOC,AREADETAIL,TaskManagerUserDetail,ORDERS
               WHERE AreaDetail.Putawayzone = Loc.PutAwayZone
               AND TaskManagerUserDetail.UserKey = @c_userid
               AND TaskManagerUserDetail.PermissionType = 'PK'
               AND TaskManagerUserDetail.Permission = '1'
               AND TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
               AND TaskDetail.FromLoc = Loc.Loc
               AND TaskDetail.TASKTYPE = 'PK'
               AND TaskDetail.USERKEY = ''
               AND TaskDetail.STATUS = '0'
               AND TaskDetail.PICKMETHOD = '1'
               AND TaskDetail.WAVEKEY = @c_lastwavekey
               AND TaskDetail.ORDERKEY = ORDERS.Orderkey
               ORDER BY TASKDETAIL.PRIORITY,
               ORDERS.ROUTE,
               ORDERS.STOP DESC,
               TASKDETAIL.LOGICALFROMLOC
            END
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err = 16915
            BEGIN
               CLOSE cursor_EVAL04
               DEALLOCATE cursor_EVAL04
               GOTO DECLARECURSOR_EVAL04
            END
            OPEN cursor_EVAL04
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err = 16905
            BEGIN
               CLOSE cursor_EVAL04
               DEALLOCATE cursor_EVAL04
               GOTO DECLARECURSOR_EVAL04
            END
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81205   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Could not Open cursor_EVAL02. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         ELSE
            BEGIN
               SELECT @b_cursor_EVAL04_open = 1
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               WHILE (1=1)
               BEGIN
                  FETCH NEXT FROM cursor_EVAL04 INTO @c_taskdetailkey
                  IF @@FETCH_STATUS <> 0
                  BEGIN
                     BREAK
                  END
                  SELECT @c_taskdetailkey = taskdetailkey,
                  @c_caseid = caseid,
                  @c_orderkey = orderkey,
                  @c_orderlinenumber = orderlinenumber,
                  @c_wavekey = wavekey,
                  @c_storerkey = storerkey,
                  @c_sku = sku,
                  @c_loc = fromloc,
                  @c_logicalloc = logicalfromloc,
                  @c_id = fromid,
                  @c_lot = lot,
                  @c_uom = uom,
                  @c_userkeyoverride = userkeyoverride
                  FROM TASKDETAIL
                  WHERE TASKDETAILKEY = @c_taskdetailkey
                  SELECT @b_evaluationtype = 4
                  SELECT @b_rowcheckpass = 0
                  GOTO CHECKROW
                  EVALUATIONTYPERETURN_04:
                  IF @b_rowcheckpass = 1
                  BEGIN
                     SELECT @b_gotarow = 1
                     GOTO DISPATCH
                  END
               END -- WHILE (1=1)
            END
         END
      END
      IF (@n_continue = 1 or @n_continue = 2) AND @b_doeval01_only = 0
      BEGIN
         IF (1=1)
         BEGIN
            DECLARECURSOR_EVAL05:
            SELECT @b_cursor_EVAL05_open = 0
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) IS NOT NULL
            BEGIN
               DECLARE CURSOR_EVAL05
               CURSOR FOR
               SELECT taskdetailkey
               FROM TASKDETAIL (NOLOCK),LOC (NOLOCK),AREADETAIL (NOLOCK),ORDERS (NOLOCK)
               WHERE AreaDetail.AreaKey = @c_areakey01
               AND AreaDetail.Putawayzone = Loc.PutAwayZone
               AND TaskDetail.FromLoc = Loc.Loc
               AND TaskDetail.TASKTYPE = 'PK'
               AND TaskDetail.USERKEY = ''
               AND TaskDetail.STATUS = '0'
               AND TaskDetail.PICKMETHOD = '1'
               AND TaskDetail.Orderkey = ORDERS.Orderkey
               ORDER BY TASKDETAIL.PRIORITY,
               TASKDETAIL.Wavekey,
               ORDERS.ROUTE,
               ORDERS.STOP DESC,
               TASKDETAIL.LOGICALFROMLOC
            END
         ELSE
            BEGIN
               DECLARE CURSOR_EVAL05
               CURSOR FOR
               SELECT taskdetailkey
               FROM TASKDETAIL (NOLOCK),LOC (NOLOCK),AREADETAIL (NOLOCK),TaskManagerUserDetail (NOLOCK),
               ORDERS  (NOLOCK)
               WHERE AreaDetail.Putawayzone = Loc.PutAwayZone
               AND TaskManagerUserDetail.UserKey = @c_userid
               AND TaskManagerUserDetail.PermissionType = 'PK'
               AND TaskManagerUserDetail.Permission = '1'
               AND TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
               AND TaskDetail.FromLoc = Loc.Loc
               AND TaskDetail.TASKTYPE = 'PK'
               AND TaskDetail.USERKEY = ''
               AND TaskDetail.STATUS = '0'
               AND TaskDetail.PICKMETHOD = '1'
               AND TaskDetail.Orderkey = ORDERS.Orderkey
               ORDER BY TASKDETAIL.PRIORITY,
               TASKDETAIL.Wavekey,
               ORDERS.ROUTE,
               ORDERS.STOP DESC,
               TASKDETAIL.LOGICALFROMLOC
            END
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err = 16915
            BEGIN
               CLOSE CURSOR_EVAL05
               DEALLOCATE CURSOR_EVAL05
               GOTO DECLARECURSOR_EVAL05
            END
            OPEN CURSOR_EVAL05
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err = 16905
            BEGIN
               CLOSE CURSOR_EVAL05
               DEALLOCATE CURSOR_EVAL05
               GOTO DECLARECURSOR_EVAL05
            END
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81206   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Could not Open cursor_EVAL02. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         ELSE
            BEGIN
               SELECT @b_cursor_EVAL05_open = 1
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               WHILE (1=1)
               BEGIN
                  FETCH NEXT FROM CURSOR_EVAL05 INTO @c_taskdetailkey
                  IF @@FETCH_STATUS <> 0
                  BEGIN
                     BREAK
                  END
                  SELECT @c_taskdetailkey = taskdetailkey,
                  @c_caseid = caseid,
                  @c_orderkey = orderkey,
                  -- @c_loadkey = sourcekey,
                  @c_orderlinenumber = orderlinenumber,
                  @c_wavekey = wavekey,
                  @c_storerkey = storerkey,
                  @c_sku = sku,
                  @c_loc = fromloc,
                  @c_logicalloc = logicalfromloc,
                  @c_id = fromid,
                  @c_lot = lot,
                  @c_uom = uom,
                  @c_userkeyoverride = userkeyoverride
                  FROM TASKDETAIL
                  WHERE TASKDETAILKEY = @c_taskdetailkey
                  SELECT @b_evaluationtype = 5
                  SELECT @b_rowcheckpass = 0
                  GOTO CHECKROW
                  EVALUATIONTYPERETURN_05:
                  IF @b_rowcheckpass = 1
                  BEGIN
                     SELECT @b_gotarow = 1
                     GOTO DISPATCH
                  END
               END -- WHILE (1=1)
            END
         END
      END
      BREAK
      CHECKROW:
      SET ROWCOUNT 0
      IF @b_debug = 1
      BEGIN
         SELECT 'evaluationtype',@b_evaluationtype,
         'taskdetailkey=',@c_taskdetailkey,
         'caseid=',@c_caseid,
         'orderkey=',@c_orderkey,
         'orderlinenumber=',@c_orderlinenumber,
         'wavekey=',@c_wavekey,
         'storer=',@c_storerkey,
         'sku=',@c_sku,
         'loc=',@c_loc,
         'logicalloc=',@c_logicalloc,
         'id=',@c_id,
         'lot=',@c_lot,
         'uom=',@c_uom,
         'userkeyoverride=',@c_userkeyoverride
      END
      IF @b_rowcheckpass = 0
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT 'Row candidate check #1 - area authorization...'
         END
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) IS NULL
         BEGIN
            IF NOT EXISTS(SELECT TaskManagerUserDetail.*
            FROM TaskManagerUserDetail,AreaDetail,Loc
            WHERE TaskManagerUserDetail.UserKey = @c_userid
            AND TaskManagerUserDetail.PermissionType = 'PK'
            AND TaskManagerUserDetail.Permission = '1'
            AND TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
            AND AreaDetail.Putawayzone = Loc.PutAwayZone
            AND Loc.Loc = @c_loc
            )
            BEGIN
               GOTO EVALUATIONDONE
            END
         END
      ELSE
         BEGIN
            IF NOT EXISTS(SELECT Areadetail.*
            FROM AreaDetail,Loc
            WHERE AreaDetail.AreaKey = @c_areakey01
            AND AreaDetail.Putawayzone = Loc.PutAwayZone
            AND Loc.Loc = @c_loc
            )
            BEGIN
               GOTO EVALUATIONDONE
            END
         END
      END
      IF @b_rowcheckpass = 0
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT 'Row candidate check #2 - Make sure record is not assigned to another user'
            SELECT @c_userkeyoverride, @c_userkeyoverride, @c_userid
         END
         IF NOT ( @c_userkeyoverride = '' or @c_userkeyoverride = @c_userid )
         BEGIN
            GOTO EVALUATIONDONE
         END
      END
      IF @b_rowcheckpass = 0
      BEGIN
         SELECT @b_success = 0, @b_skipthetask = 0
         EXECUTE nspCheckSkipTasks
         @c_userid
         , @c_taskdetailkey
         , 'PK'
         , @c_taskdetailkey -- 'BATCHPICK' --@c_caseid
         , ''
         , ''
         , ''
         , ''
         , ''
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
            GOTO EVALUATIONDONE
         END
      END
      IF @b_rowcheckpass = 0
      BEGIN
         SELECT @b_success = 0
         execute    nspCheckEquipmentProfile
         @c_userid       =@c_userid
         ,              @c_taskdetailkey=''
         ,              @c_storerkey    =@c_storerkey
         ,              @c_sku          =@c_sku
         ,              @c_lot          =@c_lot
         ,              @c_fromLoc      =@c_loc
         ,              @c_fromID       =@c_id
         ,              @c_toLoc        =@c_loc
         ,              @c_toID         =@c_id
         ,              @n_qty          =0
         ,              @b_Success      =@b_success    OUTPUT
         ,              @n_err          =@n_err        OUTPUT
         ,              @c_errmsg       =@c_errmsg     OUTPUT
         IF @b_success = 0
         BEGIN
            GOTO EVALUATIONDONE
         END
      END
      SELECT @b_rowcheckpass = 1
      IF @b_debug = 1
      BEGIN
         SELECT 'Row check passed'
      END
      EVALUATIONDONE:
      IF @b_evaluationtype = 1
      BEGIN
         GOTO EVALUATIONTYPERETURN_01
      END
      IF @b_evaluationtype = 2
      BEGIN
         GOTO EVALUATIONTYPERETURN_02
      END
      IF @b_evaluationtype = 3
      BEGIN
         GOTO EVALUATIONTYPERETURN_03
      END
      IF @b_evaluationtype = 4
      BEGIN
         GOTO EVALUATIONTYPERETURN_04
      END
      IF @b_evaluationtype = 5
      BEGIN
         GOTO EVALUATIONTYPERETURN_05
      END
      IF @b_evaluationtype = 9
      BEGIN
         GOTO EVALUATIONTYPERETURN_BATCHPICK
      END
      DISPATCH:
      IF @b_debug = 1
      BEGIN
         SELECT 'Entering dispatch'
         SELECT '@c_uom' = @c_uom
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_wavekey)) IS NOT NULL
         BEGIN
            SELECT @c_palletpickdispatchmethod = dispatchpalletpickmethod,
            @c_casepickdispatchmethod = dispatchcasepickmethod,
            @c_piecepickdispatchmethod = dispatchpiecepickmethod
            FROM WAVE
            WHERE WAVEKEY = @c_wavekey
         END
      ELSE
         BEGIN
            SELECT @c_palletpickdispatchmethod = '1',
            @c_casepickdispatchmethod = '1',
            @c_piecepickdispatchmethod = '1'
         END
         SELECT @c_loctype = Locationtype FROM LOC WHERE LOC = @c_loc
         DELETE FROM #temp_dispatchcaseid
         IF @c_uom = '1' -- Full pallet pick
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT 'Dispatch - Full pallet pick'
            END
            INSERT #temp_dispatchcaseid
            (taskdetailkey,caseid,qty)
            SELECT taskdetailkey, caseid, qty
            FROM taskdetail
            WHERE taskdetailkey = @c_taskdetailkey
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=81207   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into temp table failed. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
            IF @b_debug = 1
            BEGIN
               SELECT * FROM #temp_dispatchcaseid
            END
            GOTO DISPATCHCHECK
         END -- IF @c_uom = '1'
         IF (@c_uom = '2' AND @c_casepickdispatchmethod = '1')
         OR ( @c_piecepickdispatchmethod = '3'
         AND NOT (@c_loctype = 'PICK' or @c_loctype = 'CASE')
         AND (@c_uom = '6' or @c_uom = '7' or @c_uom = '3' or @c_uom = '4' or @c_uom = '5')
         AND @c_casepickdispatchmethod = '1')
         BEGIN
            INSERT #temp_dispatchcaseid
            (taskdetailkey,caseid,qty)
            SELECT taskdetailkey,caseid,qty
            FROM taskdetail
            WHERE taskdetailkey = @c_taskdetailkey
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=81208   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into temp table failed. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
            GOTO DISPATCHCHECK
         END
         IF (@c_uom = '2' AND @c_casepickdispatchmethod = '2')
         OR ( @c_piecepickdispatchmethod = '3'
         AND NOT (@c_loctype = 'PICK' or @c_loctype = 'CASE')
         AND (@c_uom = '6' or @c_uom = '7' or @c_uom = '3' or @c_uom = '4' or @c_uom = '5')
         AND @c_casepickdispatchmethod = '2'
         )
         BEGIN
            INSERT #temp_dispatchcaseid
            (taskdetailkey,caseid,qty)
            SELECT taskdetailkey,caseid,qty
            FROM taskdetail
            WHERE wavekey = @c_wavekey
            AND orderkey = @c_orderkey
            AND storerkey = @c_storerkey
            AND sku = @c_sku
            AND fromloc = @c_loc
            AND fromid = @c_id
            AND pickmethod = '1'
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=81209   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into temp table failed. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
            GOTO DISPATCHCHECK
         END
         IF (@c_uom = '2' AND @c_casepickdispatchmethod = '3')
         OR (@c_piecepickdispatchmethod = '3'
         AND NOT (@c_loctype = 'PICK' or @c_loctype = 'CASE')
         AND (@c_uom = '6' or @c_uom = '7' or @c_uom = '3' or @c_uom = '4' or @c_uom = '5')
         AND @c_casepickdispatchmethod = '3' )
         BEGIN
            INSERT #temp_dispatchcaseid
            (taskdetailkey,caseid,qty)
            SELECT taskdetailkey,caseid,qty
            FROM taskdetail
            WHERE wavekey = @c_wavekey
            AND orderkey = @c_orderkey
            AND lot = @c_lot
            AND fromloc = @c_loc
            AND fromid = @c_id
            AND pickmethod = '1'
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=81210   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into temp table failed. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
            GOTO DISPATCHCHECK
         END
         IF (@c_uom = '6' or @c_uom = '7' or @c_uom = '3' or @c_uom = '4' or @c_uom = '5')
         AND @c_piecepickdispatchmethod = '1'
         BEGIN
            INSERT #temp_dispatchcaseid
            (taskdetailkey,caseid,qty)
            SELECT taskdetailkey,caseid,qty
            FROM taskdetail
            WHERE taskdetailkey = @c_taskdetailkey
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=81211   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into temp table failed. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
            GOTO DISPATCHCHECK
         END
         IF (@c_uom = '6' or @c_uom = '7' or @c_uom = '3' or @c_uom = '4' or @c_uom = '5')
         AND @c_piecepickdispatchmethod = '2'
         BEGIN
            INSERT #temp_dispatchcaseid
            (taskdetailkey,caseid,qty)
            SELECT taskdetailkey,caseid,qty
            FROM taskdetail
            WHERE wavekey = @c_wavekey
            AND orderkey = @c_orderkey
            AND storerkey = @c_storerkey
            AND sku = @c_sku
            AND fromloc = @c_loc
            AND fromid = @c_id
            AND pickmethod = '1'
            AND caseid = @c_caseid
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=81212   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into temp table failed. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
            GOTO DISPATCHCHECK
         END
         IF (@c_uom = '6' or @c_uom = '7' or @c_uom = '3' or @c_uom = '4' or @c_uom = '5')
         AND @c_piecepickdispatchmethod = '3'
         AND (@c_loctype = 'PICK' or @c_loctype = 'CASE')
         BEGIN
            INSERT #temp_dispatchcaseid
            (taskdetailkey,caseid,qty)
            SELECT taskdetailkey,caseid,qty
            FROM taskdetail
            WHERE wavekey = @c_wavekey
            AND orderkey = @c_orderkey
            AND storerkey = @c_storerkey
            AND sku = @c_sku
            AND fromloc = @c_loc
            AND fromid = @c_id
            AND pickmethod = '1'
            AND caseid = @c_caseid
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=81213   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into temp table failed. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
            GOTO DISPATCHCHECK
         END
      END
      DISPATCHCHECK:
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT 'Contents of #temp_dispatchcaseid table BEFORE dispatchcheck#1...'
            SELECT * FROM #temp_dispatchcaseid
         END
         SELECT @c_caseidtodelete = SPACE(10)
         WHILE (1=1) and (@n_continue =1 or @n_continue = 2)
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_caseidtodelete = caseid
            FROM #temp_dispatchcaseid
            WHERE CASEID > @c_caseidtodelete
            ORDER BY CASEID
            IF @@ROWCOUNT = 0
            BEGIN
               SET ROWCOUNT 0
               BREAK
            END
            SET ROWCOUNT 0
            SELECT @n_countcaseidtodelete = COUNT(*)
            FROM TASKDETAIL
            WHERE caseid = @c_caseidtodelete
            and status < '9'
            AND (userkey <> ''
            or (userkeyoverride <> @c_userid
            and userkeyoverride <> ''
            )
            )
            IF @n_countcaseidtodelete > 0
            BEGIN
               DELETE FROM #temp_dispatchcaseid
               WHERE caseid = @c_caseidtodelete
               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=81214   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete from temp table failed. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END
            IF (@n_continue = 1 or @n_continue = 2) and @n_countcaseidtodelete = 0
            BEGIN
               SELECT @b_success = 0, @b_skipthetask = 0
               EXECUTE nspCheckSkipTasks
               @c_userid
               , ''
               , 'PK'
               , @c_caseidtodelete
               , ''
               , ''
               , ''
               , ''
               , ''
               , @b_skipthetask OUTPUT
               , @b_Success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue=3
               END
               IF @b_success = 1
               BEGIN
                  IF @b_skipthetask = 1
                  BEGIN
                     DELETE FROM #temp_dispatchcaseid
                     WHERE caseid = @c_caseidtodelete
                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=81215   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete from temp table failed. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END
                  END
               END
            END
         END
         SET ROWCOUNT 0
         IF @b_debug = 1
         BEGIN
            SELECT 'Contents of #temp_dispatchcaseid table AFTER dispatchcheck#1...'
            SELECT * FROM #temp_dispatchcaseid
         END
      END
      DISPATCHEXECUTE:
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT 'Dispatch Execute...'
         END
         SELECT  @n_temptable_recordcount = COUNT(*) FROM #temp_dispatchcaseid
         IF @b_debug = 1
         BEGIN
            select 'record count in dispatchexeccute', @n_temptable_recordcount
            select * from #temp_dispatchcaseid
         END
         IF @n_temptable_recordcount > 0
         BEGIN
            SET ROWCOUNT 0
            BEGIN TRANSACTION
               UPDATE TASKDETAIL
               SET TASKDETAIL.status = '3',
               TASKDETAIL.userkey = @c_userid,
               TASKDETAIL.reasonkey = ''
               FROM #temp_dispatchcaseid
               WHERE TASKDETAIL.TASKDETAILKEY = #temp_dispatchcaseid.taskdetailkey
               AND TASKDETAIL.userkey = ''
               AND TASKDETAIL.status = '0'
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=81216   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update to taskdetail table failed. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
               IF @n_continue = 1 or @n_continue = 2
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     SELECT 'Commiting transactions'
                  END
                  COMMIT TRANSACTION
               END
            ELSE
               BEGIN
                  ROLLBACK TRANSACTION
               END
               SET ROWCOUNT 0
               IF @n_continue = 1 or @n_continue = 2
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     select 'second sets'
                  END
                  SELECT @n_cnt = COUNT(*)
                  FROM TASKDETAIL
                  WHERE TASKDETAIL.status = '3'
                  AND TASKDETAIL.tasktype = 'PK'
                  AND TASKDETAIL.userkey = @c_userid
                  IF @n_cnt <> @n_temptable_recordcount
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT 'Going back to start because counts did not match..','Before Count =',@n_temptable_recordcount,'After Record Count =',@n_cnt
                        SELECT 'in process records for this user...'
                        SELECT * FROM TASKDETAIL WHERE TASKDETAIL.STATUS = '3' and TASKDETAIL.userkey = @c_userid
                     END
                     GOTO STARTPROCESSING -- Loop around and start over
                  END
                  SET ROWCOUNT 1
                  SELECT @c_taskdetailkey = taskdetailkey
                  FROM #temp_dispatchcaseid
                  ORDER BY caseid
                  SET ROWCOUNT 0
                  SELECT @n_temptable_qty = SUM(QTY)
                  FROM #temp_dispatchcaseid
                  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lastloadkey)) IS NULL
                  BEGIN
                     SELECT @c_caseid = caseid,
                     @c_orderkey = orderkey,
                     @c_orderlinenumber = orderlinenumber,
                     @c_wavekey = wavekey,
                     @c_storerkey = TASKDETAIL.storerkey,
                     @c_sku = TASKDETAIL.sku,
                     @c_loc = fromloc,
                     @c_id = fromid,
                     -- @c_lot = lot,
                     @c_lot = CONVERT(char(10), LOTTABLE04, 103), -- use lot as expiry date
                     @c_uom = uom,
                     @c_userkeyoverride = userkeyoverride,
                     @c_message01 = message01,
                     @c_message02 = message02,
                     @c_message03 = SKU.DESCR -- SHONG
                     FROM TASKDETAIL
                     JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = TASKDETAIL.StorerKey AND SKU.SKU = TASKDETAIL.SKU)
                     JOIN LOTATTRIBUTE WITH (NOLOCK) ON (TASKDETAIL.LOT = LOTATTRIBUTE.LOT)
                     WHERE TASKDETAILKEY = @c_taskdetailkey
                  END
               ELSE
                  BEGIN
                     SELECT @c_caseid = caseid,
                     @c_orderkey = orderkey,    -- comment this line if there is problem.
                     @c_loadkey = Sourcekey,
                     @c_orderlinenumber = 'BATCH',
                     @c_wavekey = wavekey,
                     @c_storerkey = TASKDETAIL.storerkey,
                     @c_sku = TASKDETAIL.sku,
                     @c_loc = fromloc,
                     @c_id = fromid,
                     -- @c_lot = lot,
                     @c_lot = CONVERT(char(10), LOTTABLE04, 103), -- use lot as expiry date
                     @c_uom = uom,
                     @c_userkeyoverride = userkeyoverride,
                     @c_message01 = message01,
                     @c_message02 = message02,
                     @c_message03 = SKU.DESCR -- SHONG
                     FROM TASKDETAIL
                     JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = TASKDETAIL.StorerKey AND SKU.SKU = TASKDETAIL.SKU)
                     JOIN LOTATTRIBUTE WITH (NOLOCK) ON (TASKDETAIL.LOT = LOTATTRIBUTE.LOT)
                     WHERE TASKDETAILKEY = @c_taskdetailkey
                  END -- @loadkey = ''
                  -- IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_loadkey)) IS NULL
                  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sourcetype)) <> 'BATCHPICK'
                  BEGIN
                     SELECT @c_route = route,
                     @c_door = door,
                     @c_stop = stop
                     FROM ORDERS (NOLOCK)
                     WHERE ORDERKEY = @c_orderkey
                  END
               ELSE
                  BEGIN
                     SELECT @c_door = TRFROOM
                     FROM LOADPLAN  (NOLOCK)
                     WHERE LOADKEY = @c_loadkey -- @c_lastloadkey
                  END
                  --            IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_loadkey)) IS NULL
                  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sourcetype)) = 'BATCHPICK'
                  BEGIN
                     SELECT @c_message01 = 'Load# ' + @c_loadkey, -- @c_lastloadkey,
                     @c_message02 = 'Door# ' + @c_door
                  END
               ELSE
                  BEGIN
                     SELECT @c_message01 = 'Ord#: ' + @c_orderkey,
                     @c_message02 = 'Door# ' + @c_door
                  END
                  IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_id)) IS NULL
                  BEGIN
                     SELECT @c_packkey = PACKKEY
                     FROM ID (NOLOCK) WHERE ID = @c_id
                  END
               ELSE
                  BEGIN
                     SELECT @c_packkey = PACKKEY
                     FROM SKU (NOLOCK)
                     WHERE STORERKEY = @c_storerkey and SKU = @c_sku
                  END
                  SELECT @c_uomtext = ''
                  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_packkey)) IS NOT NULL
                  BEGIN
                     SELECT @c_uomtext = packuom3
                     FROM  PACK (NOLOCK) WHERE PACKKEY = @c_packkey
                  END
                  -- XXXX
                  SELECT @c_packkey = dbo.fnc_RTrim( CAST( FLOOR(@n_temptable_qty/PACK.CaseCnt) as NVARCHAR(10) ) )
                  + ' ' + dbo.fnc_RTrim(PACK.PackUOM1) + ' '
                  + dbo.fnc_RTrim(CAST(dbo.fnc_RTrim(@n_temptable_qty - FLOOR(@n_temptable_qty/PACK.CaseCnt) * PACK.CaseCnt) as NVARCHAR(5)))
                  + ' ' + dbo.fnc_RTrim(PACK.PACKUOM3)
                  FROM SKU (NOLOCK)
                  JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
                  WHERE STORERKEY = @c_storerkey and SKU = @c_sku
                  -- XXXX
                  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_loadkey)) IS NULL
                  BEGIN
                     DECLARE CURSOR_PKTASKCANDIDATES
                     CURSOR FOR
                     SELECT @c_taskdetailkey,
                     @c_caseid,@c_orderkey,
                     @c_orderlinenumber,
                     @c_wavekey,@c_storerkey,@c_sku,@c_lot,@c_loc,@c_id,@c_packkey,
                     @c_uomtext, @n_temptable_qty, @c_message01, @c_message02, @c_message03
                  END
               ELSE
                  BEGIN
                     DECLARE CURSOR_PKTASKCANDIDATES
                     CURSOR FOR
                     SELECT @c_taskdetailkey,@c_caseid,@c_loadkey,@c_orderlinenumber,
                     @c_wavekey,@c_storerkey,@c_sku,@c_lot,@c_loc,@c_id,@c_packkey,
                     @c_uomtext, @n_temptable_qty, @c_message01, @c_message02, @c_message03
                  END
                  IF @b_debug = 1
                  BEGIN
                     SELECT 'Updating taskmanageruser'
                  END
                  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_loadkey)) IS NULL
                  BEGIN
                     UPDATE TASKMANAGERUSER
                     SET LastCaseIdPicked = @c_caseid,
                     Lastwavekey = @c_wavekey
                     WHERE USERKEY = @c_userid
                  END
                  GOTO DONE
               END
            ELSE
               BEGIN
                  GOTO STARTPROCESSING -- Loop around and start over
               END
            END
         ELSE
            BEGIN
               GOTO NOTHINGTOSEND
            END
         END
      END  -- WHILE 1=1
      SET ROWCOUNT 0
      NOTHINGTOSEND:
      IF @b_debug = 1
      BEGIN
         SELECT 'Nothing to send...'
      END
      DECLARE CURSOR_PKTASKCANDIDATES
      CURSOR FOR
      SELECT '','','','','','','','','','','','',0,'','',''
      DONE:
      IF @b_debug = 1
      BEGIN
         SELECT 'DONE'
      END
      IF @b_cursor_EVAL01_open = 1
      BEGIN
         CLOSE cursor_EVAL01
         DEALLOCATE cursor_EVAL01
      END
      IF @b_cursor_EVAL02_open = 1
      BEGIN
         CLOSE cursor_EVAL02
         DEALLOCATE cursor_EVAL02
      END
      IF @b_cursor_EVAL03_open = 1
      BEGIN
         CLOSE cursor_EVAL03
         DEALLOCATE cursor_EVAL03
      END
      IF @b_cursor_EVAL04_open = 1
      BEGIN
         CLOSE cursor_EVAL04
         DEALLOCATE cursor_EVAL04
      END
      IF @b_cursor_EVAL05_open = 1
      BEGIN
         CLOSE CURSOR_EVAL05
         DEALLOCATE CURSOR_EVAL05
      END
      IF @b_cursor_EVAL06_open = 1
      BEGIN
         CLOSE cursor_EVAL06
         DEALLOCATE cursor_EVAL06
      END
      IF @b_cursor_EVAL07_open = 1
      BEGIN
         CLOSE cursor_EVAL07
         DEALLOCATE cursor_EVAL07
      END
      -- batch picking
      IF @b_cursor_evalbatchpick_open = 1
      BEGIN
         IF @b_debug = 1 SELECT 'CLOSING CURSOR BATCHPICK'
         CLOSE CURSOR_EVALBATCHPICK
         DEALLOCATE CURSOR_EVALBATCHPICK
      END
      -- batch picking
      IF @b_temptablecreated = 1
      BEGIN
         DROP TABLE #TEMP_DISPATCHCASEID
      END
      /* #INCLUDE <SPTMPK01_2.SQL> */
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
         execute nsp_logerror @n_err, @c_errmsg, 'nspTTMPK01'
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