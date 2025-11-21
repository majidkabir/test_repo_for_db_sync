SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspTTMRP10                                         */
/* Copyright: Maersk                                                    */
/*                                                                      */
/* Purpose: TM Replenishment Strategy                                   */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Author    Ver  Purposes                                  */
/* 16-10-2018  ChewKP    1.0  WMS-6505. Created                         */
/* 23-08-2023  Ung       1.1  WMS-23369 Add UserKeyOverRide             */
/************************************************************************/
CREATE   PROC [dbo].[nspTTMRP10]
    @c_UserID    NVARCHAR(18)
   ,@c_AreaKey01 NVARCHAR(10)
   ,@c_AreaKey02 NVARCHAR(10)
   ,@c_AreaKey03 NVARCHAR(10)
   ,@c_AreaKey04 NVARCHAR(10)
   ,@c_AreaKey05 NVARCHAR(10)
   ,@c_LastLOC   NVARCHAR(10)
   ,@c_TaskDetailKey NVARCHAR(10) OUTPUT
   ,@n_Err       INT OUTPUT
   ,@c_ErrMsg    NVARCHAR(250) OUTPUT
   
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
      ,@c_LastLOCAisle  NVARCHAR(10)
      ,@c_LangCode      NVARCHAR(3)

   DECLARE 
       @n_TranCount   INT
      ,@b_SkipTheTask INT
      ,@cFoundTask    NVARCHAR( 1)      

   DECLARE 
       @c_StorerKey NVARCHAR(15)
      ,@c_SKU       NVARCHAR(20)
      ,@c_FromID    NVARCHAR(18)
      ,@c_ToLOC     NVARCHAR(10)
      ,@c_ToID      NVARCHAR(18)
      ,@c_LOT       NVARCHAR(10)
      ,@n_QTY       INT
      ,@c_TaskType  NVARCHAR( 10)
      ,@c_LOCCategory NVARCHAR( 10)
      ,@c_LOCAisle  NVARCHAR( 10)
      ,@c_Facility  NVARCHAR( 5)
      ,@cTransitLOC NVARCHAR( 10)
      ,@cWaveKey    NVARCHAR( 10)
      ,@cPickMethod NVARCHAR( 10)    
      ,@c_FromLOC   NVARCHAR( 10)   
      
    SELECT 
       @b_debug = 0
      ,@n_starttcnt = @@TRANCOUNT
      ,@n_continue = 1
      ,@b_success = 0
      ,@n_err = 0
      ,@c_errmsg = ''
      ,@c_TaskDetailkey = ''
      ,@c_LastLOCAisle = ''

     
    
   SELECT @c_LangCode = DefaultLangCode
   FROM rdt.rdtUser WITH (NOLOCK) 
   WHERE UserName = @c_UserID
      
   -- Reset in-progress task, to be refetch, if connection broken
   UPDATE TaskDetail SET
      Status = '0'
   WHERE UserKey = @c_UserID
      AND Status = '3'
   IF @@ERROR <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 128851
      SET @c_errmsg = rdt.rdtgetmessage( @n_err, @c_LangCode, 'DSP') --UpdTaskDetFail
      GOTO Quit 
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
            ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END
            ,CASE WHEN LOC.LOCAisle = @c_LastLOCAisle THEN '0' ELSE '1' END
            ,LOC.LogicalLocation
            ,LOC.LOC

   -- Start of Process EvaluateRPF Equivalent
   OPEN Cursor_RPFTaskCandidates
   
   -- Get a task
   SET @c_TaskDetailKey = ''
   FETCH NEXT FROM Cursor_RPFTaskCandidates INTO @c_TaskDetailKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get task info
      SELECT
         @c_TaskType  = TaskType, 
         @c_StorerKey = StorerKey, 
         @c_SKU       = SKU,
         @c_LOT       = LOT,
         @n_QTY       = QTY, 
         @c_FromLOC   = FromLOC,
         @c_FromID    = FromID,
         @c_ToLOC     = ToLOC,
         @c_ToID      = ToID, 
         @cTransitLOC = TransitLOC, 
         @cWaveKey    = WaveKey, 
         @cPickMethod = PickMethod
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @c_TaskDetailKey

      -- Check skip task
      SET @b_success = 0
      SET @b_SkipTheTask = 0
      EXECUTE nspCheckSkipTasks
           @c_UserID
         , @c_TaskDetailKey
         , @c_TaskType
         , ''
         , ''
         , ''
         , ''
         , ''
         , ''
         , @b_SkipTheTask  OUTPUT
         , @b_Success      OUTPUT
         , @n_err          OUTPUT
         , @c_errmsg       OUTPUT
         
      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         --SET @n_err = 128851
         SET @c_errmsg = rdt.rdtgetmessage( @n_err, @c_LangCode, 'DSP') --UpdTaskDetFail
         GOTO Quit 
         
      END   
      
      IF @b_SkipTheTask = 1
      BEGIN
         FETCH NEXT FROM Cursor_RPFTaskCandidates INTO @c_TaskDetailKey
         CONTINUE
      END

      -- Check equipment
      SET @b_success = 0
      EXECUTE nspCheckEquipmentProfile
           @c_UserID=@c_UserID
         , @c_TaskDetailKey= @c_TaskDetailKey
         , @c_StorerKey    = @c_StorerKey
         , @c_SKU          = @c_SKU
         , @c_LOT          = @c_LOT
         , @c_FromLOC      = @c_FromLOC
         , @c_FromID       = @c_FromID
         , @c_ToLOC        = @c_ToLOC
         , @c_toID         = ''--@c_toid
         , @n_QTY          = @n_QTY
         , @b_Success      = @b_success OUTPUT
         , @n_err          = @n_err     OUTPUT
         , @c_errmsg       = @c_errmsg  OUTPUT
      IF @b_success = 0
      BEGIN
         FETCH NEXT FROM Cursor_RPFTaskCandidates INTO @c_TaskDetailKey
         CONTINUE
      END

      -- Get from LOC info
      SELECT 
         @c_LOCCategory = LocationCategory, 
         @c_LOCAisle = LocAisle, 
         @c_Facility = Facility
      FROM dbo.LOC WITH (NOLOCK) 
      WHERE LOC = @c_FromLoc
      
      
      -- Check aisle in used
      IF @c_LOCCategory IN ('VNA')
      BEGIN
    

         IF EXISTS( SELECT 1 
            FROM dbo.TaskDetail TD WITH (NOLOCK) 
               JOIN dbo.LOC L1 WITH (NOLOCK) ON (TD.FromLOC = L1.LOC)
               LEFT JOIN dbo.LOC L2 WITH (NOLOCK) ON (TD.ToLOC = L2.LOC)
            WHERE TD.Status > '0' AND TD.Status < '9'
               AND @c_Facility IN (L1.Facility, L2.Facility)
               AND @c_LOCAisle IN (L1.LOCAisle, L2.LOCAisle)
               AND NOT L1.LocationCategory IN ('PND_OUT', 'PND') -- Exclude task going out from PND_OUT
               AND NOT L2.LocationCategory IN ('PND_IN', 'PND')  -- Exclude task coming in into PND_IN
               AND UserKey <> @c_userid)
         BEGIN
            FETCH NEXT FROM Cursor_RPFTaskCandidates INTO @c_TaskDetailKey
            CONTINUE
         END
      END
      
      -- Get transit LOC
      IF @cTransitLOC = ''
      BEGIN
         SET @n_err = 0
         EXECUTE rdt.rdt_GetTransitLoc
              @c_UserID
            , @c_StorerKey
            , @c_SKU
            , @n_QTY
            , @c_FromLOC
            , @c_FromID
            , @c_ToLOC
            , 0             -- Lock PND transit LOC. 1=Yes, 0=No
            , @cTransitLOC OUTPUT 
            , @n_err       OUTPUT
            , @c_errmsg    OUTPUT
            , @nFunc = 1764
         IF @n_err <> 0
         BEGIN
            FETCH NEXT FROM Cursor_RPFTaskCandidates INTO @c_TaskDetailKey
            CONTINUE
         END
      END

      -- Reach final LOC
      IF @cTransitLOC = @c_ToLOC 
      BEGIN
         -- Get To LOC info
         SELECT 
            @c_LOCCategory = LocationCategory, 
            @c_LOCAisle = LocAisle, 
            @c_Facility = Facility
         FROM dbo.LOC WITH (NOLOCK) 
         WHERE LOC = @c_ToLOC
         
         -- Check To aisle in used
         IF @c_LOCCategory IN ('VNA')
         BEGIN
            IF EXISTS( SELECT 1 
               FROM dbo.TaskDetail TD WITH (NOLOCK) 
                  JOIN dbo.LOC L1 WITH (NOLOCK) ON (TD.FromLOC = L1.LOC)
                  LEFT JOIN dbo.LOC L2 WITH (NOLOCK) ON (TD.ToLOC = L2.LOC)
               WHERE TD.Status > '0' AND TD.Status < '9'
                  AND @c_Facility IN (L1.Facility, L2.Facility)
                  AND @c_LOCAisle IN (L1.LOCAisle, L2.LOCAisle)
                  AND NOT L1.LocationCategory IN ('PND_OUT', 'PND') -- Exclude task going out from PND_OUT
                  AND NOT L2.LocationCategory IN ('PND_IN', 'PND')  -- Exclude task coming in into PND_IN
                  AND UserKey <> @c_userid)
            BEGIN
               FETCH NEXT FROM Cursor_RPFTaskCandidates INTO @c_TaskDetailKey
               CONTINUE
            END
         END
      END

      -- Update task as in-progress
      IF NOT EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @c_TaskDetailKey AND Status = '3' AND UserKey = @c_UserID)
      BEGIN
         IF @cTransitLOC = @c_ToLOC
            UPDATE TaskDetail WITH (ROWLOCK) SET
                Status     = '3'
               ,UserKey    = @c_UserID
               ,ReasonKey  = ''
               ,ListKey    = CASE WHEN ListKey = '' THEN @c_TaskDetailKey ELSE ListKey END
               ,StartTime  = CURRENT_TIMESTAMP
               ,EditDate   = CURRENT_TIMESTAMP
               ,EditWho    = @c_UserID
               ,TrafficCop = NULL
            WHERE TaskDetailKey = @c_TaskDetailKey
               AND Status IN ('0')
         ELSE
            UPDATE TaskDetail WITH (ROWLOCK) SET
                Status     = '3'
               ,UserKey    = @c_UserID
               ,ReasonKey  = ''
               ,TransitLOC = @cTransitLOC
               ,FinalLOC   = @c_ToLOC
               ,FinalID    = @c_ToID
               ,ToLOC      = @cTransitLOC
               ,ToID       = @c_FromID
               ,ListKey    = CASE WHEN ListKey = '' THEN @c_TaskDetailKey ELSE ListKey END
               ,StartTime  = CURRENT_TIMESTAMP
               ,EditDate   = CURRENT_TIMESTAMP
               ,EditWho    = @c_UserID
               ,TrafficCop = NULL
            WHERE TaskDetailKey = @c_TaskDetailKey
               AND Status IN ('0')
               
         IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
         BEGIN
            SET @n_continue = 3
            SET @n_err = 128852
            SET @c_errmsg = rdt.rdtgetmessage( @n_err, @c_LangCode, 'DSP') --UpdTaskDetFail
            GOTO Quit 
         END
         
         -- Fetch other tasks that can perform at once
         IF @c_TaskType = 'RPF' AND @cPickMethod = 'FP'
         BEGIN
            DECLARE @cOtherTaskDetailKey NVARCHAR(10)
            DECLARE @cOtherTaskToLOC NVARCHAR(10)
            DECLARE @cOtherTaskToID NVARCHAR(18)
            
            SET @cOtherTaskDetailKey = ''
            SET @cOtherTaskToLOC = ''
            SET @cOtherTaskToID = ''
            
            DECLARE @curTask CURSOR
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TaskDetailKey, ToLOC, ToID
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE WaveKey = @cWaveKey
                  AND FromLOC = @c_FromLOC
                  AND FromID = @c_FromID
                  AND TaskType = 'RPF'
                  AND Status = '0'
                  AND TaskDetailKey <> @c_TaskDetailKey
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cOtherTaskDetailKey, @cOtherTaskToLOC, @cOtherTaskToID
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF @cTransitLOC = @c_ToLOC
                  UPDATE TaskDetail WITH (ROWLOCK) SET
                      Status     = '3'
                     ,UserKey    = @c_UserID
                     ,ReasonKey  = ''
                     ,RefTaskKey = @c_TaskDetailKey
                     ,ListKey    = CASE WHEN ListKey = '' THEN @c_TaskDetailKey ELSE ListKey END
                     ,StartTime  = CURRENT_TIMESTAMP
                     ,EditDate   = CURRENT_TIMESTAMP
                     ,EditWho    = @c_UserID
                     ,TrafficCop = NULL
                  WHERE TaskDetailKey = @cOtherTaskDetailKey
               ELSE
                  UPDATE TaskDetail WITH (ROWLOCK) SET
                      Status     = '3'
                     ,UserKey    = @c_UserID
                     ,ReasonKey  = ''
                     ,RefTaskKey = @c_TaskDetailKey
                     ,TransitLOC = @cTransitLOC
                     ,FinalLOC   = @cOtherTaskToLOC
                     ,FinalID    = @cOtherTaskToID
                     ,ToLOC      = @cTransitLOC
                     ,ToID       = @c_FromID
                     ,ListKey    = CASE WHEN ListKey = '' THEN @c_TaskDetailKey ELSE ListKey END
                     ,StartTime  = CURRENT_TIMESTAMP
                     ,EditDate   = CURRENT_TIMESTAMP
                     ,EditWho    = @c_UserID
                     ,TrafficCop = NULL
                  WHERE TaskDetailKey = @cOtherTaskDetailKey
               
               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 128853
                  SET @c_errmsg = rdt.rdtgetmessage( @n_err, @c_LangCode, 'DSP') --UpdTaskDetFail
                  GOTO Quit 
               END
               
               FETCH NEXT FROM @curTask INTO @cOtherTaskDetailKey, @cOtherTaskToLOC, @cOtherTaskToID
            END
            
            -- Update own RefTaskKey
            IF @cOtherTaskDetailKey <> ''
            BEGIN
               UPDATE TaskDetail WITH (ROWLOCK) SET
                   RefTaskKey = @c_TaskDetailKey
                  ,TrafficCop = NULL
               WHERE TaskDetailKey = @c_TaskDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 128854
                  SET @c_errmsg = rdt.rdtgetmessage( @n_err, @c_LangCode, 'DSP') --UpdTaskDetFail
                  GOTO Quit 
               END
            END
         END
      END
      
      SET @cFoundTask = 'Y'
      BREAK -- Task assiged sucessfully, Quit Now
   END
   
   -- Exit if no task
   IF @cFoundTask <> 'Y' 
   BEGIN
      SET @c_TaskDetailKey = ''  --@c_TaskDetailKey still contain last record value if @@FETCH_STATUS <> 0 exit while loop
      --GOTO Quit
   END
   
Quit:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      
      CLOSE Cursor_RPFTaskCandidates
      DEALLOCATE Cursor_RPFTaskCandidates
      
       
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
        execute nsp_logerror @n_err, @c_errmsg, 'nspTTMRP10'
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