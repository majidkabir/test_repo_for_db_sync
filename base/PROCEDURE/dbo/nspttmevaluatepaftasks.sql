SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspTTMEvaluatePAFTasks                             */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Modification log:                                                    */    
/* Date         Ver.  Author     Purposes                               */    
/* 30-Jan-2013  1.0   Ung        SOS256104. Created                     */    
/************************************************************************/    
    
CREATE PROC [dbo].[nspTTMEvaluatePAFTasks]    
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
      ,@n_RowCount    INT    
      ,@cFoundTask    NVARCHAR( 1)    
    
   DECLARE    
       @c_StorerKey       NVARCHAR(15)    
      ,@c_sku             NVARCHAR(20)    
      ,@c_fromid          NVARCHAR(18)    
      ,@c_ToLoc           NVARCHAR(10)    
      ,@c_lot             NVARCHAR(10)    
      ,@n_qty             INT    
      ,@c_SuggestedLOC    NVARCHAR( 10)    
      ,@c_PickAndDropLOC  NVARCHAR( 10)    
      ,@c_FitCasesInAisle NVARCHAR( 1)    
      ,@c_TaskType        NVARCHAR( 10)    
      ,@c_LOCCategory     NVARCHAR( 10)    
      ,@c_LOCAisle        NVARCHAR( 10)    
      ,@c_Facility        NVARCHAR( 5)    
      ,@cSwapTask         NVARCHAR( 1)    
          
   SELECT    
       @n_TranCount = @@TRANCOUNT    
      ,@n_Continue = 1    
      ,@b_success = 0    
      ,@n_err = 0    
      ,@c_errmsg = ''    
      ,@b_debug = 0    
    
DeclareCursor_PAFTaskCandidates:    
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
       CLOSE Cursor_PAFTaskCandidates    
       DEALLOCATE Cursor_PAFTaskCandidates    
       GOTO DeclareCursor_PAFTaskCandidates    
   END    
    
   -- Check other error    
   IF @n_err <> 0    
   BEGIN    
      SET @n_Continue = 3    
      SET @n_err = 83552    
      SET @c_errmsg = 'PAFCodeError'    
      GOTO Quit    
   END    
    
   OPEN Cursor_PAFTaskCandidates    
   SELECT @n_err = @@ERROR    
    
   -- Check cursor is already open    
   IF @n_err = 16905    
   BEGIN    
      CLOSE Cursor_PAFTaskCandidates    
      DEALLOCATE Cursor_PAFTaskCandidates    
      GOTO DeclareCursor_PAFTaskCandidates    
   END    
    
   IF @n_err <> 0    
      GOTO Quit    
    
   -- Get a task    
   SET @c_TaskDetailKey = ''    
   FETCH NEXT FROM Cursor_PAFTaskCandidates INTO @c_TaskDetailKey    
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
        @c_ToLoc     = ToLOC,     
         @c_TaskType  = TaskType    
      FROM dbo.TaskDetail WITH (NOLOCK)    
      WHERE TaskDetailKey = @c_TaskDetailKey    
    
      -- Get storer config    
      SET @cSwapTask = rdt.rdtGetConfig( 1797, 'SwapTask', @c_StorerKey)    
    
      -- Check skip task    
      SET @b_success = 0    
      SET @b_SkipTheTask = 0    
      EXECUTE nspCheckSkipTasks    
           @c_userid    
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
         FETCH NEXT FROM Cursor_PAFTaskCandidates INTO @c_TaskDetailKey    
         CONTINUE    
      END    
    
      -- Check equipment    
      SET @b_success = 0    
      EXECUTE nspCheckEquipmentProfile    
           @c_Userid=@c_Userid    
         , @c_TaskDetailKey= @c_TaskDetailKey    
         , @c_StorerKey    = @c_StorerKey    
         , @c_sku          = @c_sku -- not used    
         , @c_lot          = @c_lot -- not used    
         , @c_FromLoc      = @c_FromLoc    
         , @c_fromID       = @c_fromid    
         , @c_toLoc        = @c_toloc -- Optional    
         , @c_toID         = ''--@c_toid    
         , @n_qty          = @n_qty  -- not used    
         , @b_Success      = @b_success OUTPUT    
         , @n_err          = @n_err     OUTPUT    
         , @c_errmsg       = @c_errmsg  OUTPUT    
      IF @b_success = 0    
      BEGIN    
         FETCH NEXT FROM Cursor_PAFTaskCandidates INTO @c_TaskDetailKey    
         CONTINUE    
      END    
    
      -- Get LOC info    
      SELECT     
         @c_LOCCategory = LocationCategory,     
         @c_LOCAisle = LocAisle,     
         @c_Facility = Facility    
      FROM dbo.LOC WITH (NOLOCK)     
      WHERE LOC = @c_FromLoc    
          
      -- Check aisle in used    
      IF @c_LOCCategory IN ('PnD', 'PnD_In')    
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
            FETCH NEXT FROM Cursor_PAFTaskCandidates INTO @c_TaskDetailKey    
            CONTINUE    
         END    
      END    
    
      -- Execute putaway strategy    
      IF @c_ToLOC = '' AND @cSwapTask <> '1'    
      BEGIN    
         -- Suggest LOC    
         EXEC @n_Err = [dbo].[nspRDTPASTD]    
              @c_userid          = 'RDT'    
            , @c_storerkey       = @c_StorerKey    
            , @c_lot             = @c_LOT    
            , @c_sku             = @c_SKU    
            , @c_id              = @c_FromID    
            , @c_fromloc         = @c_FromLOC    
            , @n_qty             = @n_QTY    
            , @c_uom             = '' -- not used    
            , @c_packkey         = '' -- optional, if pass-in SKU    
            , @n_putawaycapacity = 0    
            , @c_final_toloc     = @c_SuggestedLOC OUTPUT    
            , @c_PickAndDropLoc  = @c_PickAndDropLOC OUTPUT    
            , @c_FitCasesInAisle = @c_FitCasesInAisle  OUTPUT    
    
         -- Update Task ToLOC    
         IF @c_SuggestedLOC = ''     
         BEGIN    
            FETCH NEXT FROM Cursor_PAFTaskCandidates INTO @c_TaskDetailKey    
            CONTINUE    
         END    
         ELSE    
         BEGIN    
            IF @c_PickAndDropLOC = ''    
               UPDATE TaskDetail WITH (ROWLOCK) SET    
                  ToLOC = @c_SuggestedLOC 
                  ,EditDate = CURRENT_TIMESTAMP    
                  ,EditWho = @c_userid
                  ,TrafficCop = NULL        
               WHERE TaskDetailKey = @c_TaskDetailKey    
            ELSE    
               UPDATE TaskDetail WITH (ROWLOCK) SET    
                  FinalLOC   = @c_SuggestedLOC,    
                  FinalID    = @c_FromID,     
                  ToLOC      = @c_PickAndDropLOC,    
                  ToID       = @c_FromID,     
                  TransitLOC = @c_PickAndDropLOC,     
                  ListKey    = @c_TaskDetailKey
                  ,EditDate = CURRENT_TIMESTAMP    
                  ,EditWho = @c_userid
                  ,TrafficCop = NULL        
               WHERE TaskDetailKey = @c_TaskDetailKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @n_Err = 83553    
               SET @c_ErrMsg = 'UPDTaskDtlFail'    
               GOTO Fail    
            END    
    
            -- Lock suggested location    
            IF @c_FitCasesInAisle <> 'Y'    
               EXEC rdt.rdt_Putaway_PendingMoveIn @c_userid, 'LOCK'    
                  ,@c_FromLOC    
                  ,@c_FromID    
                  ,@c_SuggestedLOC    
                  ,@c_StorerKey    
                  ,@n_Err    OUTPUT    
                  ,@c_ErrMsg OUTPUT    
    
            -- Lock PND location    
            IF @c_PickAndDropLOC <> ''    
               EXEC rdt.rdt_Putaway_PendingMoveIn @c_userid, 'LOCK'    
                  ,@c_FromLOC    
                  ,@c_FromID    
                  ,@c_PickAndDropLOC    
                  ,@c_StorerKey    
                  ,@n_Err    OUTPUT    
                  ,@c_ErrMsg OUTPUT    
         END    
      END    
    
      -- Update task as in-progress    
      UPDATE TaskDetail WITH (ROWLOCK)   
         SET Status = '3'    
         ,UserKey = @c_userid    
         ,Reasonkey = ''    
         ,StartTime = CURRENT_TIMESTAMP    
         ,EditDate = CURRENT_TIMESTAMP    
         ,EditWho = @c_userid    
         ,TrafficCop = NULL    
      WHERE TaskDetailKey = @c_TaskDetailKey    
         AND Status = '0'    
      SELECT @n_err = @@ERROR, @n_RowCount = @@ROWCOUNT    
      IF @n_err <> 0 OR @n_RowCount <> 1    
      BEGIN    
         SET @n_Err = 83551    
         SET @c_ErrMsg = 'Try again!'    
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
   IF CURSOR_STATUS( 'global', 'Cursor_PAFTaskCandidates') IN (0, 1) -- 0=empty, 1=record    
      CLOSE Cursor_PAFTaskCandidates    
   IF CURSOR_STATUS( 'global', 'Cursor_PAFTaskCandidates') IN (-1)   -- -1=cursor is closed    
      DEALLOCATE Cursor_PAFTaskCandidates    
    
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspTTMEvaluatePAFTasks'    
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