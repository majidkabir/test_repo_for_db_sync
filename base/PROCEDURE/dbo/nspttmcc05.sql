SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspTTMCC05                                         */
/* Creation Date: 09-11-2011                                            */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose: Only allow 1 user to do cycle count in 1 aisle              */
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
/* 28-03-2018   James         WMS4083. Created                          */
/************************************************************************/

CREATE PROC [dbo].[nspTTMCC05]
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
   DECLARE @c_LastLocAisle          NVARCHAR( 10)
   DECLARE @c_TaskDetailKey         NVARCHAR( 10)
   DECLARE @c_TaskDetailKey2LOCK    NVARCHAR( 10)
   DECLARE @c_LocAisle           NVARCHAR( 10)

   /* #INCLUDE <SPTMCC01_1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SET @c_LastLocAisle = ''

      -- Get last locaisle user previously assigned task
      SELECT TOP 1 @c_LastLocAisle = LOC.LocAisle 
      FROM dbo.TASKDETAIL TA WITH (NOLOCK)  
      JOIN dbo.LOC LOC WITH (NOLOCK) ON TA.FROMLOC = LOC.LOC
      WHERE  TA.Tasktype = 'CC'  
            AND TA.Status = '9'  
            AND ta.UserKey = @c_UserID  
            AND NOT EXISTS(  
                     SELECT 1  
                     FROM   TaskManagerSkipTasks(NOLOCK)  
                     WHERE  TaskManagerSkipTasks.Taskdetailkey = TA.TaskDetailkey  
                  )  
      ORDER BY  
            TA.EditDate DESC   

      IF ISNULL( @c_LastLocAisle, '') <> ''
      BEGIN
         -- Check if locaisle is valid within the area
         IF NOT EXISTS ( SELECT 1 FROM dbo.AreaDetail AD WITH (NOLOCK)
                           JOIN dbo.LOC LOC WITH (NOLOCK) ON AD.PutAwayZone = LOC.PutAwayZone
                           WHERE AD.AreaKey = @c_areakey01
                           AND   LOC.LocAisle = @c_LastLocAisle)
         BEGIN
            SET @c_LastLocAisle = ''
         END

         -- Check if last locaisle retrieved still has task to assign
         IF NOT EXISTS (
            SELECT TaskDetailKey
            FROM dbo.TaskDetail TaskDetail WITH (NOLOCK)
            JOIN dbo.Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc)
            JOIN dbo.AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
            WHERE TaskDetail.Status = '0'
            AND TaskDetail.TaskType = 'CC'
            AND TaskDetail.UserKey = ''
            AND AreaDetail.AreaKey = @c_areakey01
            AND AreaDetail.Putawayzone = Loc.PutAwayZone
            AND TaskDetail.FromLoc = Loc.Loc
            AND NOT EXISTS ( SELECT 1 FROM dbo.TaskDetail TD2 WITH (NOLOCK) 
                              JOIN dbo.Loc Loc2 WITH (NOLOCK) ON (TD2.FromLoc = Loc2.Loc)
                              WHERE TD2.TaskType = 'CC'
                              AND   TD2.Status = '3'
                              AND   Loc.LocAisle = Loc2.LocAisle)
            AND Loc.LocAisle = ISNULL( @c_LastLocAisle, ''))
         BEGIN
            SET @c_LastLocAisle = ''
         END
      END

      SELECT TOP 1 @c_TaskDetailKey = TaskDetailKey
      FROM dbo.TaskDetail TaskDetail WITH (NOLOCK)
      JOIN dbo.Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) 
      JOIN dbo.AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone) 
      WHERE TaskDetail.Status = '0'
      AND TaskDetail.TaskType = 'CC'
      AND TaskDetail.UserKey = ''
      AND AreaDetail.AreaKey = @c_areakey01
      AND AreaDetail.Putawayzone = Loc.PutAwayZone
      AND TaskDetail.FromLoc = Loc.Loc
      AND NOT EXISTS ( SELECT 1 FROM dbo.TaskDetail TD2 WITH (NOLOCK) 
                        JOIN dbo.Loc Loc2 WITH (NOLOCK) ON (TD2.FromLoc = Loc2.Loc)
                        WHERE TD2.TaskType = 'CC'
                        AND   TD2.Status = '3'
                        AND   Loc.LocAisle = Loc2.LocAisle)
      AND (( ISNULL( @c_LastLocAisle, '') = '') OR ( Loc.LocAisle = @c_LastLocAisle))
      ORDER BY Priority,TaskDetailKey      

      IF ISNULL( @c_TaskDetailKey, '') <> ''
      BEGIN
         SELECT TOP 1 @c_LocAisle = LOC.LocAisle
         FROM dbo.TaskDetail TD WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)
         WHERE TD.TaskDetailKey = @c_TaskDetailKey
         ORDER BY 1

         DECLARE CUR_UPDLOCAISLE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT TD.TaskDetailKey
         FROM dbo.TaskDetail TD WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)
         WHERE LOC.LocAisle = @c_LocAisle
         AND   TD.Status = '0'
         AND   TD.UserKey = ''
         AND   TD.TaskDetailKey <> @c_TaskDetailKey
         ORDER BY 1
         OPEN CUR_UPDLOCAISLE
         FETCH NEXT FROM CUR_UPDLOCAISLE INTO @c_TaskDetailKey2LOCK
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
               [Status] = '3',
               UserKey = sUSER_sNAME(),
               EditDate = GETDATE(),
               EditWho  = sUSER_sNAME(),
               TrafficCop = NULL  
            WHERE TaskDetailKey = @c_TaskDetailKey2LOCK

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=79801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Lock CC Task Failed. (nspTTMCC05)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               BREAK
            END

            FETCH NEXT FROM CUR_UPDLOCAISLE INTO @c_TaskDetailKey2LOCK
         END
         CLOSE CUR_UPDLOCAISLE
         DEALLOCATE CUR_UPDLOCAISLE
      END

      DECLARE cursor_CCTASKCANDIDATES
      CURSOR FOR
      SELECT TaskDetailKey
      FROM TaskDetail WITH (NOLOCK) 
      WHERE TASKDETAILKEY = @c_TaskDetailKey

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=79801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Execute Of CrossDock Tasks Pick Code Failed. (nspTTMCC05)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
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
      execute nsp_logerror @n_err, @c_errmsg, 'nspTTMCC05'
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