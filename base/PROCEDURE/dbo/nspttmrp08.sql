SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspTTMRP08                                         */
/* Copyright: Maersk                                                    */
/*                                                                      */
/* Purpose: TM Replenishment Strategy                                   */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Author    Ver  Purposes                                  */
/* 17-01-2019  James     1.0  WMS-7686 Created                          */
/* 23-08-2023  Ung       1.1  WMS-23369 Add UserKeyOverRide             */
/************************************************************************/
CREATE   PROC [dbo].[nspTTMRP08]
    @c_UserID    NVARCHAR(18)
   ,@c_AreaKey01 NVARCHAR(10)
   ,@c_AreaKey02 NVARCHAR(10)
   ,@c_AreaKey03 NVARCHAR(10)
   ,@c_AreaKey04 NVARCHAR(10)
   ,@c_AreaKey05 NVARCHAR(10)
   ,@c_LastLOC   NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
       @b_debug      INT
      ,@n_starttcnt  INT -- Holds the current transaction count
      ,@n_continue   INT
      ,@b_Success    INT
      ,@n_err        INT
      ,@c_errmsg     NVARCHAR(250)
      ,@c_TaskDetailkey NVARCHAR(10)
      ,@c_LastLOCAisle  NVARCHAR(10)
      
    SELECT 
       @b_debug = 0
      ,@n_starttcnt = @@TRANCOUNT
      ,@n_continue = 1
      ,@b_success = 0
      ,@n_err = 0
      ,@c_errmsg = ''
      ,@c_TaskDetailkey = ''
      ,@c_LastLOCAisle = ''
      
   -- Reset in-progress task, to be refetch, if connection broken
   UPDATE TaskDetail SET
      Status = '0'
   WHERE UserKey = @c_UserID
      AND Status = '3'
   IF @@ERROR <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 81201
      SET @c_errmsg = 'NSQL' + CONVERT( NVARCHAR(5), @n_err) + ': ' + 
                      'Update to TaskDetail table failed. (nspTTMRP08)' + 
                      '(SQLSvr MESSAGE = ' + RTRIM( @c_errmsg) + ' )'
   END

   -- Close cursor
   IF CURSOR_STATUS( 'global', 'Cursor_RPFTaskCandidates') IN (0, 1) -- 0=empty, 1=record
      CLOSE Cursor_RPFTaskCandidates
   IF CURSOR_STATUS( 'global', 'Cursor_RPFTaskCandidates') IN (-1)   -- -1=cursor is closed
      DEALLOCATE Cursor_RPFTaskCandidates

   -- Get Last LOCAisle
   SELECT @c_LastLOCAisle = LOCAisle FROM LOC WITH (NOLOCK) WHERE LOC = @c_LastLOC

   IF @c_AreaKey01 <> ''
      DECLARE Cursor_RPFTaskCandidates CURSOR FAST_FORWARD READ_ONLY FOR --Note: global cursor
         SELECT TaskDetailkey
         FROM dbo.TaskDetail WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)
            JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
         WHERE AreaDetail.AreaKey = @c_AreaKey01
            AND TaskDetail.TaskType IN ('RPF')
            AND TaskDetail.Status = '0'
            AND TaskDetail.UserKeyOverRide IN (@c_UserID, '')
            AND NOT EXISTS( SELECT 1
               FROM TaskDetail T1 WITH (NOLOCK)
               WHERE TaskDetail.GroupKey <> '' 
                  AND T1.GroupKey = TaskDetail.GroupKey 
                  AND T1.Status < '9'
                  AND T1.UserKey NOT IN (@c_userid, ''))
            AND EXISTS( SELECT 1 
               FROM TaskManagerUserDetail tmu WITH (NOLOCK)
               WHERE PermissionType = TaskDetail.TASKTYPE
                 AND tmu.UserKey = @c_UserID
                 AND tmu.AreaKey = @c_AreaKey01
                 AND tmu.Permission = '1')
         ORDER BY
             TaskDetail.Priority
            ,TaskDetail.Wavekey
            ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END
            ,CASE WHEN LOC.LOCAisle = @c_LastLOCAisle THEN '0' ELSE '1' END
            ,LOC.LogicalLocation
            ,LOC.LOC
   ELSE
      DECLARE Cursor_RPFTaskCandidates CURSOR FAST_FORWARD READ_ONLY FOR --Note: global cursor 
         SELECT TaskDetailkey
         FROM dbo.TaskDetail WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)
            JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
         WHERE dbo.TaskDetail.TaskType IN ('RPF')
            AND TaskDetail.Status = '0'
            AND TaskDetail.UserKeyOverRide IN (@c_UserID, '')
            AND NOT EXISTS( SELECT 1
               FROM TaskDetail T1 WITH (NOLOCK)
               WHERE TaskDetail.GroupKey <> '' 
                  AND T1.GroupKey = TaskDetail.GroupKey 
                  AND T1.Status < '9'
                  AND T1.UserKey NOT IN (@c_userid, ''))
            AND EXISTS( SELECT 1 
               FROM TaskManagerUserDetail tmu WITH (NOLOCK)
               WHERE PermissionType = TaskDetail.TASKTYPE
                 AND tmu.UserKey = @c_UserID
                 AND tmu.AreaKey = @c_AreaKey01
                 AND tmu.Permission = '1')
         ORDER BY
             TaskDetail.Priority
            ,TaskDetail.Wavekey
            ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END
            ,CASE WHEN LOC.LOCAisle = @c_LastLOCAisle THEN '0' ELSE '1' END
            ,LOC.LogicalLocation
            ,LOC.LOC

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16. 
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR 

         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
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
        execute nsp_logerror @n_err, @c_errmsg, 'nspTTMRP08'
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
        RETURN
     END
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