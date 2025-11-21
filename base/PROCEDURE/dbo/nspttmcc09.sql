SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: nspTTMCC09                                            */
/* Copyright: Maersk                                                       */
/*                                                                         */
/* Purpose: Consider GroupKey when get task for PAGE                       */
/*                                                                         */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author  Ver   Purposes                                     */
/* 2025-02-11   JCH507  1.0   FCR-1917 Get task which group not assigned   */
/***************************************************************************/

CREATE   PROC nspTTMCC09
   @c_userid NVARCHAR(18),
   @c_areakey01 NVARCHAR(10),
   @c_areakey02 NVARCHAR(10),
   @c_areakey03 NVARCHAR(10),
   @c_areakey04 NVARCHAR(10),
   @c_areakey05 NVARCHAR(10),
   @c_lastloc NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_debug int
   SELECT @b_debug = 0
   DECLARE @n_continue int,
           @n_starttcnt int,
           @n_cnt int,
           @n_err2 int,
           @b_Success int,
           @n_err int,
           @c_errmsg NVARCHAR(250)
   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_success = 0, @n_err = 0, @c_errmsg = '', @n_err2 = 0

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_areakey01)) IS NULL
      BEGIN
         DECLARE cursor_CCTASKCANDIDATES CURSOR FOR
         SELECT TaskDetailKey
         FROM TaskDetail TaskDetail WITH (NOLOCK)
         JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc)
         JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
         JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey)
         WHERE TaskDetail.Status = '0'
         AND TaskDetail.TaskType = 'CC'
         AND TaskDetail.UserKey = ''
         AND TaskManagerUserDetail.UserKey = @c_userid
         AND TaskManagerUserDetail.PermissionType = 'CC'
         AND TaskManagerUserDetail.Permission = '1'
         AND TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
         AND AreaDetail.Putawayzone = Loc.PutAwayZone
         AND TaskDetail.FromLoc = Loc.Loc
         AND TaskDetail.UserKeyOverRide IN (@c_userid, '')
         AND NOT EXISTS (
            SELECT 1
            FROM TaskDetail TD WITH (NOLOCK)
            WHERE TD.GroupKey = TaskDetail.GroupKey
               AND TD.TaskType = 'CC'
               AND TD.Userkey <> ''
               AND TD.UserKey <> @c_userid 
               AND TD.Status <> '9'
         )
         ORDER BY
            CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END,
            Priority, TaskDetailKey
      END
      ELSE
      BEGIN
         DECLARE cursor_CCTASKCANDIDATES CURSOR FOR
         SELECT TaskDetailKey
         FROM TaskDetail TaskDetail WITH (NOLOCK)
         JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc)
         JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
         WHERE TaskDetail.Status = '0'
         AND TaskDetail.TaskType = 'CC'
         AND TaskDetail.UserKey = ''
         AND AreaDetail.AreaKey = @c_areakey01
         AND AreaDetail.Putawayzone = Loc.PutAwayZone
         AND TaskDetail.FromLoc = Loc.Loc
         AND TaskDetail.UserKeyOverRide IN (@c_userid, '')
         AND NOT EXISTS (
            SELECT 1
            FROM TaskDetail TD WITH (NOLOCK)
            WHERE TD.GroupKey = TaskDetail.GroupKey
               AND TD.TaskType = 'CC'
               AND TD.Userkey <> ''
               AND TD.UserKey <> @c_userid 
               AND TD.Status <> '9'
         )
         ORDER BY
            CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END,
            Priority, TaskDetailKey
      END
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 79801
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err) + ': Execute Of CrossDock Tasks Pick Code Failed. (nspTTMCC09)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF @n_continue = 3
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspTTMCC09'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR
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