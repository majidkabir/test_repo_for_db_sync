SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspTTMEvaluateRPFTasks                             */
/* Purpose:                                                             */
/*                                                                      */
/* Modification log:                                                    */
/* Date        Ver.  Author      Purposes                               */
/* 14-03-2013  1.0   Ung         SOS259759. Created                     */
/* 11-03-2014  1.1   Ung         SOS296465. Update ListKey              */
/* 22-07-2016  1.2   Ung         SOS359988. Fix transit of other FP task*/
/* 20-12-2017  1.3   Ung         WMS-2050 Add LoadKey                   */
/* 05-09-2018  1.4   ChewKP      WMS-6178. Param to Move all Validation */
/*                               to be done in Pickcode (ChewKP01)      */
/************************************************************************/

CREATE PROC [dbo].[nspTTMEvaluateRPFTasks]
    @c_sendDelimiter    NVARCHAR(1)
   ,@c_UserID           NVARCHAR(18)
   ,@c_StrategyKey      NVARCHAR(10)
   ,@c_TTMStrategyKey   NVARCHAR(10)
   ,@c_TTMPickCode      NVARCHAR(10)
   ,@c_TTMOverride      NVARCHAR(10)
   ,@c_AreaKey01        NVARCHAR(10)
   ,@c_AreaKey02        NVARCHAR(10)
   ,@c_AreaKey03        NVARCHAR(10)
   ,@c_AreaKey04        NVARCHAR(10)
   ,@c_AreaKey05        NVARCHAR(10)
   ,@c_LastLoc          NVARCHAR(10)
   ,@c_OutString        NVARCHAR(255)  OUTPUT
   ,@b_Success          INT            OUTPUT
   ,@n_err              INT            OUTPUT
   ,@c_errmsg           NVARCHAR(250)  OUTPUT
   ,@c_ptcid            NVARCHAR(5)
   ,@c_FromLOC          NVARCHAR(10)   OUTPUT
   ,@c_TaskDetailKey    NVARCHAR(10)   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
       @b_debug       INT
      ,@n_Continue    INT
      ,@n_TranCount   INT
      ,@c_executestmt NVARCHAR(255)
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
      ,@cLoadKey    NVARCHAR( 10)
      ,@cPickMethod NVARCHAR( 10)
      ,@cSQL        NVARCHAR( MAX)
      ,@cSQLParam   NVARCHAR( MAX)

   SELECT 
       @n_TranCount = @@TRANCOUNT
      ,@n_Continue = 1
      ,@b_success = 0
      ,@n_err = 0
      ,@c_errmsg = ''
      ,@b_debug = 0

DeclareCursor_RPFTaskCandidates:
   
   -- (ChewKP01) 
   -- Get PickCode Parameter . If Param = @c_TaskDetailKey then Execute all Validation in Pickcode, By Pass EvaluateSP
   
   IF EXISTS ( SELECT 1 FROM sys.parameters 
               WHERE  object_id = object_id('dbo.'+ @c_TTMPickCode )
               AND Name = '@c_TaskDetailKey' ) 
   BEGIN
       IF @c_TTMPickCode <> ''
       BEGIN
         IF EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @c_TTMPickCode AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC dbo.' + RTRIM( @c_TTMPickCode) +
               ' @c_UserID, @c_AreaKey01, @c_AreaKey02, @c_AreaKey03, @c_AreaKey04, @c_AreaKey05, @c_LastLOC, @c_TaskDetailKey OUTPUT, @n_Err OUTPUT , @c_ErrMsg OUTPUT' 
            SET @cSQLParam =
               '  @c_UserID    NVARCHAR(18)              '+
               ' ,@c_AreaKey01 NVARCHAR(10)              '+
               ' ,@c_AreaKey02 NVARCHAR(10)              '+
               ' ,@c_AreaKey03 NVARCHAR(10)              '+
               ' ,@c_AreaKey04 NVARCHAR(10)              '+
               ' ,@c_AreaKey05 NVARCHAR(10)              '+
               ' ,@c_LastLOC   NVARCHAR(10)              '+
               ' ,@c_TaskDetailKey NVARCHAR(10) OUTPUT   '+
               ' ,@n_Err       INT OUTPUT                '+
               ' ,@c_ErrMsg    NVARCHAR(250) OUTPUT      '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @c_UserID, @c_AreaKey01, @c_AreaKey02, @c_AreaKey03, @c_AreaKey04, @c_AreaKey05, @c_LastLOC, @c_TaskDetailKey OUTPUT, @n_Err OUTPUT , @c_ErrMsg OUTPUT
   
            
            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               GOTO Fail
            END
               GOTO QUIT
         END
       END 

       --SET @c_executestmt = 'EXECUTE '+ RTRIM( @c_TTMPickCode)
       --  +" "
       --  +"'"+RTRIM(@c_UserID)+"'"+","
       --  +"'"+RTRIM(@c_AreaKey01)+"'"+","
       --  +"'"+RTRIM(@c_AreaKey02)+"'"+","
       --  +"'"+RTRIM(@c_AreaKey03)+"'"+","
       --  +"'"+RTRIM(@c_AreaKey04)+"'"+","
       --  +"'"+RTRIM(@c_AreaKey05)+"'"+","
       --  +"'"+RTRIM(@c_LastLoc)+"'"+","
       --  +"'"+RTRIM(@c_TaskDetailKey)+"'"+" OUTPUT,"
       --  +"'"+RTRIM(@n_Err)+"'"+" OUTPUT,"
       --  +"'"+RTRIM(@c_ErrMsg)+"' OUTPUT"

         
         
       --  EXECUTE (@c_executestmt)
       --  SET @n_err = @@ERROR
         
         --IF @n_err <> 0 
         --BEGIN 
         --   SET @n_Continue = 3
         --   --SET @n_err = 83601
         --   --SET @c_errmsg = '83601^RPF Code Fail'
         --   GOTO Fail
         --END
      --ELSE
      --BEGIN
      --   GOTO QUIT
      --END
      
      
   END
   
   SET @c_executestmt = 'EXECUTE '+ RTRIM( @c_TTMPickCode)
      +" "
      +"'"+RTRIM(@c_UserID)+"'"+","
      +"'"+RTRIM(@c_AreaKey01)+"'"+","
      +"'"+RTRIM(@c_AreaKey02)+"'"+","
      +"'"+RTRIM(@c_AreaKey03)+"'"+","
      +"'"+RTRIM(@c_AreaKey04)+"'"+","
      +"'"+RTRIM(@c_AreaKey05)+"'"+","
      +"'"+RTRIM(@c_LastLoc)+"'"
   EXECUTE (@c_executestmt)
   SET @n_err = @@ERROR

   -- Check cursor already exists
   IF @n_err = 16915
   BEGIN
       CLOSE Cursor_RPFTaskCandidates
       DEALLOCATE Cursor_RPFTaskCandidates
       GOTO DeclareCursor_RPFTaskCandidates
   END
   
   -- Check other error
   IF @n_err <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 83601
      SET @c_errmsg = '83601^RPF Code Fail'
      GOTO Fail
   END

   OPEN Cursor_RPFTaskCandidates
   SELECT @n_err = @@ERROR

   -- Check cursor is already open
   IF @n_err = 16905
   BEGIN
      CLOSE Cursor_RPFTaskCandidates
      DEALLOCATE Cursor_RPFTaskCandidates
      GOTO DeclareCursor_RPFTaskCandidates
   END

   IF @n_err <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 83602
      SET @c_errmsg = '83602^OpenCursorFail'
      GOTO Fail
   END

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
         @cLoadKey    = LoadKey, 
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
         GOTO Fail
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
         EXECUTE rdt.rdt_GetTransitLOC 
              @c_UserID
            , @c_StorerKey
            , @c_SKU
            , @n_QTY
            , @c_FromLOC
            , @c_FromID
            , @c_ToLOC
            , 1             -- Lock PND transit LOC. 1=Yes, 0=No
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
            SET @n_Err = 83603
            SET @c_ErrMsg = '83603 UPDTaskDtlFail'
            GOTO Fail
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
               WHERE FromLOC = @c_FromLOC
                  AND FromID = @c_FromID
                  AND TaskType = 'RPF'
                  AND Status = '0'
                  AND TaskDetailKey <> @c_TaskDetailKey
                  AND (@cWaveKey = '' OR (@cWaveKey <> '' AND WaveKey = @cWaveKey))
                  AND (@cLoadKey = '' OR (@cLoadKey <> '' AND LoadKey = @cLoadKey))
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
                  SET @n_Err = 83604
                  SET @c_ErrMsg = '83604 UPDTaskDtlFail'
                  GOTO Fail
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
                  SET @n_Err = 83605
                  SET @c_ErrMsg = '83605 UPDTaskDtlFail'
                  GOTO Fail
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
      GOTO Quit
   END

/*
   -- Update wave status to replenish in-progress
   IF EXISTS( SELECT 1 FROM dbo.Wave WITH (NOLOCK) WHERE WaveKey = @cWaveKey AND Status = '1')
   BEGIN
      UPDATE dbo.Wave SET 
         Status = '2' -- Replenish in-progress
      WHERE WaveKey = @cWaveKey 
         AND Status = '1' -- Wave released
      IF @@ERROR <> 0
      BEGIN
         SET @n_Err = 1
         SET @c_ErrMsg = ''
         GOTO Fail
         -- SET @nErrNo = 
         -- SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd Wave Fail
         -- GOTO Quit
      END
   END
*/

   GOTO Quit

Fail:
   SET @n_Continue = 3

Quit:
   -- Close cursor
   IF CURSOR_STATUS( 'global', 'Cursor_RPFTaskCandidates') IN (0, 1) -- 0=empty, 1=record
      CLOSE Cursor_RPFTaskCandidates
   IF CURSOR_STATUS( 'global', 'Cursor_RPFTaskCandidates') IN (-1)   -- -1=cursor is closed
      DEALLOCATE Cursor_RPFTaskCandidates

   IF @n_Continue=3 -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT=1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         WHILE @@TRANCOUNT>@n_TranCount
               COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err ,10 ,1) WITH SETERROR

         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT=1
            AND @@TRANCOUNT>@n_TranCount
         BEGIN
             ROLLBACK TRAN
         END
         ELSE
         BEGIN
             WHILE @@TRANCOUNT>@n_TranCount
             BEGIN
                 COMMIT TRAN
             END
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspTTMEvaluateRPFTasks'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT>@n_TranCount
         COMMIT TRAN
      RETURN
   END
END

GO