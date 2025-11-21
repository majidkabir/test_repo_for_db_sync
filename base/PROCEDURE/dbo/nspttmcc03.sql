SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTTMCC03                                         */
/* Creation Date: 26-06-2012                                            */
/* Copyright: IDS                                                       */
/* Written by: Chew KP                                                  */
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
/* 27-07-2012   ChewKP        Rewrite SQL JOIN (ChewKP01)               */
/************************************************************************/

CREATE PROC    [dbo].[nspTTMCC03]
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
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_err2=0
   DECLARE @c_executestmt NVARCHAR(255)
   /* #INCLUDE <SPTMCC01_1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) IS NULL
      BEGIN
         DECLARE cursor_CCTASKCANDIDATES
         CURSOR FOR
         SELECT TaskDetailKey
         --FROM TaskDetail,TaskManagerUserDetail,AreaDetail,Loc
         FROM TaskDetail TaskDetail WITH (NOLOCK)                 -- (ChewKP01)  
         JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) -- (ChewKP01)
         JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone) -- (ChewKP01)
         JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey) -- (ChewKP01)
         WHERE TaskDetail.Status = '0'
         AND TaskDetail.TaskType = 'CCSV'
         AND TaskDetail.UserKey = ''
         AND TaskManagerUserDetail.UserKey = @c_userid
         AND TaskManagerUserDetail.PermissionType = 'CCSV'
         AND TaskManagerUserDetail.Permission = '1'
         AND TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
         AND AreaDetail.Putawayzone = Loc.PutAwayZone
         AND TaskDetail.FromLoc = Loc.Loc
         ORDER BY Priority,TaskDetailKey
      END
   ELSE
      BEGIN
         DECLARE cursor_CCTASKCANDIDATES
         CURSOR FOR
         SELECT TaskDetailKey
         --FROM TaskDetail,AreaDetail,Loc
         FROM TaskDetail TaskDetail WITH (NOLOCK)                 -- (ChewKP01)  
         JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) -- (ChewKP01)
         JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone) -- (ChewKP01)
         WHERE TaskDetail.Status = '0'
         AND TaskDetail.TaskType = 'CCSV'
         AND TaskDetail.UserKey = ''
         AND AreaDetail.AreaKey = @c_areakey01
         AND AreaDetail.Putawayzone = Loc.PutAwayZone
         AND TaskDetail.FromLoc = Loc.Loc
         ORDER BY Priority,TaskDetailKey
      END
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=79801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Execute Of CrossDock Tasks Pick Code Failed. (nspTTMCC03)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END
   /* #INCLUDE <SPTMCC01_2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, 'nspTTMCC03'
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