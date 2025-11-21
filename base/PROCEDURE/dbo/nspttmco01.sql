SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTTMCO01                                         */
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

CREATE PROC    [dbo].[nspTTMCO01]
@c_userid           NVARCHAR(18)
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
   SELECT @b_debug = 0
   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @n_err2 int             , -- For Additional Error Detection
   @b_Success int          ,
   @n_err int              ,
   @c_errmsg NVARCHAR(250)
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   DECLARE @c_executestmt NVARCHAR(255)
   /* #INCLUDE <SPTMCO01_1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) IS NULL
      BEGIN
         DECLARE cursor_COTASKCANDIDATES
         CURSOR FOR
         SELECT TaskDetailKey
         FROM TaskDetail,TaskManagerUserDetail,AreaDetail,Loc
         WHERE TaskDetail.Status = "0"
         AND TaskDetail.TaskType = "CO"
         AND TaskDetail.UserKey = ""
         AND TaskManagerUserDetail.UserKey = @c_userid
         AND TaskManagerUserDetail.PermissionType = "CO"
         AND TaskManagerUserDetail.Permission = "1"
         AND TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
         AND AreaDetail.Putawayzone = Loc.PutAwayZone
         AND TaskDetail.FromLoc = Loc.Loc
         ORDER BY SourcePriority,TaskDetailKey
      END
   ELSE
      BEGIN
         DECLARE cursor_COTASKCANDIDATES
         CURSOR FOR
         SELECT TaskDetailKey
         FROM TaskDetail,AreaDetail,Loc
         WHERE TaskDetail.Status = "0"
         AND TaskDetail.TaskType = "CO"
         AND TaskDetail.UserKey = ""
         AND AreaDetail.AreaKey = @c_areakey01
         AND AreaDetail.Putawayzone = Loc.PutAwayZone
         AND TaskDetail.FromLoc = Loc.Loc
         ORDER BY SourcePriority,TaskDetailKey
      END
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=79401   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Execute Of CrossDock Tasks Pick Code Failed. (nspTTMCO01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   /* #INCLUDE <SPTMCO01_2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, "nspTTMCO01"
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