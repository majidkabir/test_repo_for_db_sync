SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTTMEvaluatePATTasks                             */
/* Purpose:                                                             */
/*                                                                      */
/* Modification log:                                                    */
/* Date         Ver.  Author     Purposes                               */
/* 04-Dec-2012  1.0   Ung        SOS224379. Created                     */
/************************************************************************/

CREATE PROC [dbo].[nspTTMEvaluatePATTasks]
    @c_sendDelimiter    NVARCHAR(1)
   ,@c_userid           NVARCHAR(18)
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
   ,@b_Success          INT        OUTPUT
   ,@n_err              INT        OUTPUT
   ,@c_errmsg           NVARCHAR(250)  OUTPUT
   ,@c_ptcid            NVARCHAR(5)
   ,@c_FromLoc          NVARCHAR(10)   OUTPUT
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
      ,@c_sku       NVARCHAR(20)
      ,@c_fromid    NVARCHAR(18)
      ,@c_ToLoc     NVARCHAR(10)
      ,@c_lot       NVARCHAR(10)
      ,@n_qty       INT
      ,@cTransitLOC NVARCHAR( 10)

   SELECT 
       @n_TranCount = @@TRANCOUNT
      ,@n_Continue = 1
      ,@b_success = 0
      ,@n_err = 0
      ,@c_errmsg = ''
      ,@b_debug = 0

DeclareCursor_PATTaskCandidates:
   SET @c_executestmt = 'EXECUTE '+ RTRIM( @c_TTMPickCode)
      +" "
      +"'"+RTRIM(@c_userid)+"'"+","
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
       CLOSE Cursor_PATTaskCandidates
       DEALLOCATE Cursor_PATTaskCandidates
       GOTO DeclareCursor_PATTaskCandidates
   END
   
   -- Check other error
   IF @n_err <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 83651
      SET @c_errmsg = '83651 PAT Code Fail'
      GOTO Fail
   END

   OPEN Cursor_PATTaskCandidates
   SELECT @n_err = @@ERROR

   -- Check cursor is already open
   IF @n_err = 16905
   BEGIN
      CLOSE Cursor_PATTaskCandidates
      DEALLOCATE Cursor_PATTaskCandidates
      GOTO DeclareCursor_PATTaskCandidates
   END

   -- Check other error
   IF @n_err <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 83652
      SET @c_errmsg = '83652 OpenCursorFail'
      GOTO Fail
   END

   -- Get a task
   SET @c_TaskDetailKey = ''
   FETCH NEXT FROM Cursor_PATTaskCandidates INTO @c_TaskDetailKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get task info
      SELECT
         @c_StorerKey = StorerKey, 
         @c_sku       = SKU,
         @c_lot       = LOT,
         @c_FromLoc   = FromLOC,
         @c_FromId    = FromID,
         @n_Qty       = QTY, 
         @c_ToLoc     = ToLOC
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @c_TaskDetailKey

      -- Check skip task
      SET @b_success = 0
      SET @b_SkipTheTask = 0
      EXECUTE nspCheckSkipTasks
           @c_userid
         , @c_TaskDetailKey
         , 'PAT'
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
         FETCH NEXT FROM Cursor_PATTaskCandidates INTO @c_TaskDetailKey
         CONTINUE
      END

      -- Check equipment
      SET @b_success = 0
      EXECUTE nspCheckEquipmentProfile
           @c_Userid=@c_Userid
         , @c_TaskDetailKey= @c_TaskDetailKey
         , @c_StorerKey    = @c_StorerKey
         , @c_sku          = @c_sku
         , @c_lot          = @c_lot
         , @c_FromLoc      = @c_FromLoc
         , @c_fromID       = @c_fromid
         , @c_toLoc        = @c_toloc
         , @c_toID         = ''--@c_toid
         , @n_qty          = @n_qty
         , @b_Success      = @b_success OUTPUT
         , @n_err          = @n_err     OUTPUT
         , @c_errmsg       = @c_errmsg  OUTPUT
      IF @b_success = 0
      BEGIN
         FETCH NEXT FROM Cursor_PATTaskCandidates INTO @c_TaskDetailKey
         CONTINUE
      END

      -- Update task as in-progress
      UPDATE TaskDetail WITH (ROWLOCK) SET
          Status = '3'
         ,UserKey = @c_userid
         ,Reasonkey = ''
         ,ListKey = @c_TaskDetailKey
         ,StartTime = CURRENT_TIMESTAMP
         ,EditDate = CURRENT_TIMESTAMP
         ,EditWho = @c_userid
      WHERE FromLOC = @c_FromLoc
         AND FromID = @c_FromID
         AND Status = '0'
         AND TaskType = 'PAT'
         AND NOT EXISTS (SELECT 1 FROM TaskManagerSkipTasks S WITH (NOLOCK) WHERE S.TaskDetailKey = TaskDetail.TaskDetailKey)
      IF @@ERROR <> 0
      BEGIN
         SET @n_Err = 83653
         SET @c_ErrMsg = '83653^UpdTaskdetFail'
         GOTO Fail
      END
      
      SET @cFoundTask = 'Y'
      BREAK -- Task assiged sucessfully, Quit Now
   END

   IF @cFoundTask <> 'Y' 
      SET @c_TaskDetailKey = ''  --@c_TaskDetailKey still contain last record value if @@FETCH_STATUS <> 0 exit while loop

   GOTO Quit

Fail:
   SET @n_Continue = 3

Quit:
   -- Close cursor
   IF CURSOR_STATUS( 'global', 'Cursor_PATTaskCandidates') IN (0, 1) -- 0=empty, 1=record
   BEGIN
      CLOSE Cursor_PATTaskCandidates
      DEALLOCATE Cursor_PATTaskCandidates
   END

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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspTTMEvaluatePATTasks'
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