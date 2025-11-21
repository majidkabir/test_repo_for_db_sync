SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspTTMNM02                                         */
/*                                                                      */
/* Modifications:                                                       */
/* Date         Ver.  Author     Purposes                               */
/* 13-05-2013   1.0   Ung        SOS265332 Created                      */
/************************************************************************/

CREATE PROC [dbo].[nspTTMNM02]
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
      @b_debug     int, 
      @n_continue  int,
      @n_starttcnt int, -- Holds the current transaction count
      @b_Success   int,
      @n_err       int,
      @c_errmsg    NVARCHAR(250),
      @c_Aisle     NVARCHAR(10)

   SELECT 
      @b_debug = 0, 
      @n_starttcnt = @@TRANCOUNT, 
      @n_continue = 1, 
      @b_success = 0,
      @n_err = 0, 
      @c_errmsg = ''

   DECLARE @t_Aisle_InUsed TABLE 
   (
      LocAIsle NVARCHAR(10)
   )
	      
   -- Get aisle in use
	INSERT INTO @t_Aisle_InUsed (LOCAisle)
	SELECT LOC.LOCAisle
	FROM TaskDetail TD WITH (NOLOCK) 
   	JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)
   	JOIN TaskManagerUser TMU WITH (NOLOCK) ON (TD.UserKey = TMU.UserKey)
   	JOIN EquipmentProfile EP WITH (NOLOCK) ON (TMU.EquipmentProfileKey = EP.EquipmentProfileKey)
	WHERE TMU.EquipmentProfileKey = 'VNA' 
		AND TD.UserKey <>  @c_userid 
		AND TD.STatus = '3'

   -- Get user last LOC
   IF @c_LastLOC <> ''
      SELECT @c_Aisle = LOCAisle FROM LOC (NOLOCK) WHERE LOC = @c_LastLOC
   ELSE
      SET @c_Aisle = ''

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
                      'Update to TaskDetail table failed. (nspTTMNM02)' + 
                      '(SQLSvr MESSAGE = ' + RTRIM( @c_errmsg) + ' )'
   END

   -- Close cursor
   IF CURSOR_STATUS( 'global', 'cursor_NMVTaskCandidates') IN (0, 1) -- 0=empty, 1=record
      CLOSE cursor_NMVTaskCandidates
   IF CURSOR_STATUS( 'global', 'cursor_NMVTaskCandidates') IN (-1)   -- -1=cursor is closed
      DEALLOCATE cursor_NMVTaskCandidates

   IF ISNULL(RTRIM(@c_areakey01), '') = ''
      DECLARE cursor_NMVTaskCandidates CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT TOP 1 TaskDetailKey
      FROM TaskDetail WITH (NOLOCK) 
         JOIN LOC WITH (NOLOCK) ON (TaskDetail.FromLoc = LOC.LOC) 
         JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
         JOIN DropID WITH (NOLOCK) ON (TaskDetail.FromLOC = DropID.DropLOC AND TaskDetail.FromID = DropID.DropID AND DropID.Status <> '9')
      WHERE TaskDetail.TaskType = 'NMV'
         AND TaskDetail.Status = '0'
         AND TaskDetail.UserKey = ''
         AND NOT EXISTS (SELECT 1 
            FROM DropID WITH (NOLOCK)
               JOIN LOC WITH (NOLOCK) ON (DropID.DropLOC = LOC.LOC)
            WHERE DropLOC = TaskDetail.ToLOC 
               AND LOC.LocationCategory <> 'STAGING')
         AND EXISTS( SELECT 1 
            FROM TaskManagerUserDetail tmu WITH (NOLOCK)
            WHERE PermissionType = TaskDetail.TASKTYPE
              AND tmu.UserKey = @c_UserID
              AND tmu.AreaKey = @c_AreaKey01
              AND tmu.Permission = '1')
      ORDER BY 
          TaskDetail.Priority
         ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END
         ,CASE WHEN LOC.LOCAisle = @c_Aisle THEN '0' ELSE '1' END
         ,LOC.LogicalLocation
         ,LOC.LOC
   ELSE
      DECLARE cursor_NMVTaskCandidates CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT TOP 1 TaskDetailKey
      FROM TaskDetail WITH (NOLOCK) 
         JOIN LOC WITH (NOLOCK) ON (TaskDetail.FromLoc = LOC.LOC) 
         JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
         JOIN DropID WITH (NOLOCK) ON (TaskDetail.FromLOC = DropID.DropLOC AND TaskDetail.FromID = DropID.DropID AND DropID.Status <> '9')
      WHERE AreaDetail.AreaKey = @c_areakey01
         AND TaskDetail.TaskType = 'NMV'
         AND TaskDetail.Status = '0'
         AND TaskDetail.UserKey = ''
         AND NOT EXISTS (SELECT 1 
            FROM DropID WITH (NOLOCK)
               JOIN LOC WITH (NOLOCK) ON (DropID.DropLOC = LOC.LOC)
            WHERE DropLOC = TaskDetail.ToLOC 
               AND LOC.LocationCategory <> 'STAGING')
         AND EXISTS( SELECT 1 
            FROM TaskManagerUserDetail tmu WITH (NOLOCK)
            WHERE PermissionType = TaskDetail.TASKTYPE
              AND tmu.UserKey = @c_UserID
              AND tmu.AreaKey = @c_AreaKey01
              AND tmu.Permission = '1')
      ORDER BY 
          TaskDetail.Priority
         ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END
         ,CASE WHEN LOC.LOCAisle = @c_Aisle THEN '0' ELSE '1' END
         ,LOC.LogicalLocation
         ,LOC.LOC

   IF @n_continue=3  -- Error Occured - Process And Return
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
        execute nsp_logerror @n_err, @c_errmsg, 'nspTTMNM02'
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