SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: nspTTMPF03                                         */
/* Purpose: TM Putaway To Strategy                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 02-12-2022  1.0   yeekung   WMS-21279. Created                       */
/************************************************************************/
CREATE   PROC [dbo].[nspTTMPF03]
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
      ,@cTimeOut     INT
      ,@c_CursorSelect NVARCHAR(Max) 

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
                      'Update to TaskDetail table failed. (nspTTMPF03)' +
                      '(SQLSvr MESSAGE = ' + RTRIM( @c_errmsg) + ' )'
   END

   Declare @t_Aisle_InUsed table
   (LocAIsle NVARCHAR(10), UserKey NVARCHAR(18))

   DECLARE @t_TaskDetailKey TABLE (TaskDetailKey NVARCHAR(10))

   -- Close cursor
   IF CURSOR_STATUS( 'global', 'Cursor_PAFTaskCandidates') IN (0, 1) -- 0=empty, 1=record
      CLOSE Cursor_PAFTaskCandidates
   IF CURSOR_STATUS( 'global', 'Cursor_PAFTaskCandidates') IN (-1)   -- -1=cursor is closed
      DEALLOCATE Cursor_PAFTaskCandidates
    
   DECLARE @cStorerkey NVARCHAR(20)

   SELECT @cStorerkey =storerkey
   FROM rdt.rdtmobrec (nolock)
   where username=@c_UserID

   -- Get Last LOCAisle
   SELECT @c_LastLOCAisle = LOCAisle FROM LOC WITH (NOLOCK) WHERE LOC = @c_LastLOC

   SELECT @cTimeOut=short
   FROM codelkup (nolock)
   where listname='PATimeOut'
   and storerkey = @cStorerkey
   AND code='TimeOut'

   SET @cTimeOut = CASE WHEN ISNULL(@cTimeOut,'') = '' THEN 0 ELSE @cTimeOut END

   IF @n_continue=1 OR @n_continue=2
	BEGIN
   	INSERT INTO @t_Aisle_InUsed (LocAisle, UserKey)
   	SELECT L.LocAisle, TD.UserKey
   	FROM TaskDetail TD WITH (NOLOCK)
   	JOIN LOC L WITH (NOLOCK) ON (TD.FromLOC = L.Loc)
   	JOIN TaskManagerUser TMU WITH (NOLOCK) ON (TD.UserKey = TMU.UserKey)
   	JOIN EquipmentProfile EP WITH (NOLOCK) ON (TMU.EquipmentProfileKey = EP.EquipmentProfileKey)
   	WHERE  TD.UserKey <>  @c_userid
         AND   TD.status <= '9'
         AND TD.TaskType IN ('PAF', 'PA1')
         AND  TD.storerkey= @cStorerkey
         AND (DATEDIFF(MINUTE, TD.editdate,getdate()) between 0 and 5)
   END


   IF @c_AreaKey01 <> ''
   BEGIN
   
      INSERT INTO @t_TaskDetailKey
      SELECT TaskDetailkey
      FROM dbo.TaskDetail WITH (NOLOCK)
         JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)
         JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
      WHERE AreaDetail.AreaKey = @c_AreaKey01
         AND TaskDetail.TaskType IN ('PAF', 'PA1')
         AND TaskDetail.Status = '0'
         AND EXISTS( SELECT 1
            FROM TaskManagerUserDetail tmu WITH (NOLOCK)
            WHERE PermissionType = TaskDetail.TASKTYPE
               AND tmu.UserKey = @c_UserID
               AND tmu.AreaKey = @c_AreaKey01
               AND tmu.Permission = '1')
         AND  NOT EXISTS (SELECT 1 FROM @t_Aisle_InUsed AIU       -- (ChewKP01)
                         WHERE AIU.LocAisle = LOC.LocAisle  )
      ORDER BY
            TaskDetail.Priority
         ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END
         ,CASE WHEN LOC.LOCAisle = @c_LastLOCAisle THEN '0' ELSE '1' END
         ,LOC.LogicalLocation
         ,LOC.LOC
   END
   ELSE
   BEGIN
      INSERT INTO @t_TaskDetailKey
      SELECT TaskDetailkey
      FROM dbo.TaskDetail WITH (NOLOCK)
         JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)
         JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
      WHERE AreaDetail.AreaKey = @c_AreaKey01
         AND TaskDetail.TaskType IN ('PAF', 'PA1')
         AND TaskDetail.Status = '0'
         AND EXISTS( SELECT 1
            FROM TaskManagerUserDetail tmu WITH (NOLOCK)
            WHERE PermissionType = TaskDetail.TASKTYPE
               AND tmu.UserKey = @c_UserID
               AND tmu.Permission = '1')
         AND  NOT EXISTS (SELECT 1 FROM @t_Aisle_InUsed AIU       -- (ChewKP01)
                         WHERE AIU.LocAisle = LOC.LocAisle  )
      ORDER BY
            TaskDetail.Priority
         ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END
         ,CASE WHEN LOC.LOCAisle = @c_LastLOCAisle THEN '0' ELSE '1' END
         ,LOC.LogicalLocation
         ,LOC.LOC
   END


   IF NOT EXISTS(SELECT 1 FROM  @t_TaskDetailKey)
   BEGIN
      DECLARE Cursor_PAFTaskCandidates
      CURSOR FAST_FORWARD READ_ONLY FOR     -- (ChewKP01)
      SELECT ''

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 67808--79201   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute Of Putaway Tasks Pick Code Failed. (nspTTMPA02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
      END

   END
   ELSE
   BEGIN
      SET @c_CursorSelect =''

      SET @c_TaskDetailKey = ''
      WHILE 1=1
      BEGIN
         SELECT TOP 1
                  @c_TaskDetailKey = TaskDetailKey
         FROM   @t_TaskDetailKey
         WHERE  TaskDetailKey > @c_TaskDetailKey
         ORDER BY TaskDetailKey

         IF @@ROWCOUNT = 0
            BREAK

         IF ISNULL(RTRIM(@c_TaskDetailKey),'') <> ''
         BEGIN
            IF LEN(@c_CursorSelect) = 0
            BEGIN
               SET @c_CursorSelect ='DECLARE Cursor_PAFTaskCandidates' +
                                    ' CURSOR FAST_FORWARD READ_ONLY FOR' + CHAR(13) +
                                    ' SELECT ''' + @c_TaskDetailKey + '''' + CHAR(13)
            END
            ELSE
               SET @c_CursorSelect = @c_CursorSelect + ' UNION SELECT ''' + @c_TaskDetailKey + '''' + CHAR(13)
         END
      END
      EXEC(@c_CursorSelect)
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 67808--79201   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute Of Putaway Tasks Pick Code Failed. (nspTTMPA02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
      END
   END

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
        execute nsp_logerror @n_err, @c_errmsg, 'nspTTMPF03'
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