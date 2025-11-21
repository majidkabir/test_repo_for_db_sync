SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: nspTTMRP16                                         */
/* Copyright: Maersk                                                    */
/*                                                                      */
/* Purpose: TM Replenishment Strategy                                   */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Author    Ver  Purposes                                  */
/* 17-07-2020  James     1.0  WMS-14152. Created                        */
/* 18-05-2021  James     1.1  Perf tune (james01)                       */
/* 23-08-2023  Ung       1.2  WMS-23369 Add UserKeyOverRide             */
/************************************************************************/
CREATE   PROC [dbo].[nspTTMRP16]
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
      ,@c_TransitLOC NVARCHAR( 10)
      ,@cWaveKey    NVARCHAR( 10)
      ,@cPickMethod NVARCHAR( 10)    
      ,@c_FromLOC   NVARCHAR( 10)   
      ,@c_ToLOCAisle NVARCHAR( 10)
      ,@n_MaxPallet  INT
      ,@n_PNDPalletCnt  INT
      ,@c_LastTaskDetailKey   NVARCHAR( 10)
      ,@c_LastFromLoc   NVARCHAR( 10)
      ,@c_LastPririoty  NVARCHAR( 10)
      ,@n_NoOfUserWorkingOnAisle   INT
      ,@cTempTaskDetailKey NVARCHAR( 10)
      
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
   -- (james01)
   DECLARE @cCurUpdTask CURSOR
   SET @cCurUpdTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT TaskDetailKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE UserKey = @c_UserID
   AND   [Status] = '3'
   OPEN @cCurUpdTask
   FETCH NEXT FROM @cCurUpdTask INTO @cTempTaskDetailKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE TaskDetail SET
         Status = '0',
         EditWho = @c_UserID,
         EditDate = GETDATE()
      WHERE TaskDetailKey = @cTempTaskDetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 128851
         SET @c_errmsg = rdt.rdtgetmessage( @n_err, @c_LangCode, 'DSP') --UpdTaskDetFail
         GOTO Quit 
      END
   
      FETCH NEXT FROM @cCurUpdTask INTO @cTempTaskDetailKey
   END
   --UPDATE TaskDetail SET
   --   Status = '0'
   --WHERE UserKey = @c_UserID
   --   AND Status = '3'


   

   -- Close cursor
   IF CURSOR_STATUS( 'global', 'Cursor_RPFTaskCandidates') IN (0, 1) -- 0=empty, 1=record
      CLOSE Cursor_RPFTaskCandidates
   IF CURSOR_STATUS( 'global', 'Cursor_RPFTaskCandidates') IN (-1)   -- -1=cursor is closed
      DEALLOCATE Cursor_RPFTaskCandidates

   -- Get Last LOCAisle
   IF ISNULL( @c_LastLOC, '') <> ''
   BEGIN
      -- Last loc could be suggested toloc or pnd loc
      -- To get the task within same aisle then need retrieve lastloc
      -- From taskdetail.fromloc
      SELECT @c_LastLOC = V_LOC, 
             @c_LastTaskDetailKey = V_TaskDetailKey
      FROM RDT.RDTMOBREC WITH (NOLOCK) 
      WHERE UserName = SUSER_SNAME()
      
      SELECT @c_LastFromLoc = FromLoc,
             @c_LastPririoty = Priority
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @c_LastTaskDetailKey
      
      SELECT @c_LastLOCAisle = LOCAisle FROM LOC WITH (NOLOCK) WHERE LOC = @c_LastFromLoc
      
      -- Same aisle has same priority again, continue with this aisle else re-evaluate the seq to dispatch task 
      IF NOT EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                      JOIN dbo.Loc LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)
                      WHERE TD.TaskType = 'RPF'
                      AND   td.[Status] = '0'
                      AND   TD.Priority = @c_LastPririoty
                      AND   LOC.LocAisle = @c_LastLOCAisle)
         SET @c_LastLOCAisle = ''
   END

   IF @c_AreaKey01 <> ''
   BEGIN
      IF ISNULL( @c_LastLOCAisle, '') = ''   -- 1st time getting task, check aisle with most available task
      BEGIN
         DECLARE Cursor_RPFTaskCandidates CURSOR FAST_FORWARD READ_ONLY FOR --Note: global cursor
         SELECT TaskDetailkey--, loc.locaisle,TaskDetail.Priority, A.Cnt 
         FROM dbo.TaskDetail WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)
            JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
            JOIN ( SELECT TOP 100
                     TaskDetail.Priority, COUNT( 1) AS Cnt
                     FROM dbo.TaskDetail TaskDetail WITH (NOLOCK)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)
                     JOIN dbo.AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
                     WHERE AreaDetail.AreaKey = @c_AreaKey01
                     AND TaskDetail.TaskType IN ('RPF')
                     AND TaskDetail.Status = '0'
                     AND TaskDetail.UserKeyOverRide IN (@c_UserID, '')
                     AND EXISTS( SELECT 1 
                                 FROM dbo.TaskManagerUserDetail tmu WITH (NOLOCK)
                                 WHERE PermissionType = TaskDetail.TASKTYPE
                                 AND tmu.UserKey = @c_userid
                                 AND tmu.AreaKey = @c_AreaKey01
                                 AND tmu.Permission = '1')
                                 GROUP BY TaskDetail.Priority
                                 ORDER BY cnt 
                              ) A ON TaskDetail.Priority = A.Priority
            JOIN ( SELECT TOP 100
                     LOC.LocAisle, taskdetail.Priority, COUNT( 1) AS Cnt
                     FROM dbo.TaskDetail TaskDetail WITH (NOLOCK)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)
                     JOIN dbo.AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
                     WHERE AreaDetail.AreaKey = @c_AreaKey01
                     AND TaskDetail.TaskType IN ('RPF')
                     AND TaskDetail.Status = '0'
                     AND TaskDetail.UserKeyOverRide IN (@c_UserID, '')
                     AND EXISTS( SELECT 1 
                                 FROM dbo.TaskManagerUserDetail tmu WITH (NOLOCK)
                                 WHERE PermissionType = TaskDetail.TASKTYPE
                                 AND tmu.UserKey = @c_userid
                                 AND tmu.AreaKey = @c_AreaKey01
                                 AND tmu.Permission = '1')
                                 GROUP BY LOC.LocAisle, taskdetail.Priority
                                 ORDER BY cnt DESC, taskdetail.Priority
                              ) B ON LOC.LocAisle = B.LocAisle AND a.Priority = b.Priority
            WHERE AreaDetail.AreaKey = @c_AreaKey01
            AND TaskDetail.TaskType IN ('RPF')
            AND TaskDetail.Status = '0'
            AND EXISTS( SELECT 1 
                        FROM dbo.TaskManagerUserDetail tmu WITH (NOLOCK)
                        WHERE PermissionType = TaskDetail.TASKTYPE
                        AND tmu.UserKey = @c_userid
                        AND tmu.AreaKey = @c_AreaKey01
                        AND tmu.Permission = '1') 
         ORDER BY
            -- TaskDetail.Priority, B.Cnt DESC
            --,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END
             CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END
            ,B.Cnt DESC
            ,TaskDetail.Priority
            ,LOC.LOCAisle
            ,LOC.LogicalLocation
            ,LOC.LOC
      END
      ELSE
      BEGIN
         DECLARE Cursor_RPFTaskCandidates CURSOR FAST_FORWARD READ_ONLY FOR --Note: global cursor  
         SELECT TaskDetailkey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
            JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)  
         WHERE AreaDetail.AreaKey = @c_AreaKey01  
            AND TaskDetail.TaskType IN ('RPF', 'RP1')  
            AND TaskDetail.Status = '0'  
            AND TaskDetail.UserKeyOverRide IN (@c_UserID, '')
            AND EXISTS( SELECT 1   
               FROM TaskManagerUserDetail tmu WITH (NOLOCK)  
               WHERE PermissionType = TaskDetail.TASKTYPE  
                 AND tmu.UserKey = @c_UserID  
                 AND tmu.AreaKey = @c_AreaKey01  
                 AND tmu.Permission = '1')  
         ORDER BY  
             CASE WHEN LOC.LOCAisle = @c_LastLOCAisle THEN '0' ELSE '1' END
            --,TaskDetail.Priority  
            --,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END  
            ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END
            ,TaskDetail.Priority  
            ,LOC.LogicalLocation  
            ,LOC.LOC  
      END
   END
   ELSE
   BEGIN
      IF ISNULL( @c_LastLOCAisle, '') = ''   -- 1st time getting task, check aisle with most available task
      BEGIN
         DECLARE Cursor_RPFTaskCandidates CURSOR FAST_FORWARD READ_ONLY FOR --Note: global cursor 
         SELECT TaskDetailkey
         FROM dbo.TaskDetail WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)
            JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
            JOIN ( SELECT TOP 100
                     LOC.LocAisle, COUNT( 1) AS Cnt
                     FROM dbo.TaskDetail TaskDetail WITH (NOLOCK)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)
                     JOIN dbo.AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
                     WHERE TaskDetail.TaskType IN ('RPF')
                     AND TaskDetail.Status = '0'
                     AND TaskDetail.UserKeyOverRide IN (@c_UserID, '')
                     AND EXISTS( SELECT 1 
                                 FROM dbo.TaskManagerUserDetail tmu WITH (NOLOCK)
                                 WHERE PermissionType = TaskDetail.TASKTYPE
                                 AND tmu.UserKey = @c_UserID
                                 AND tmu.AreaKey = @c_AreaKey01
                                 AND tmu.Permission = '1')
                                 GROUP BY LOC.LocAisle
                                 ORDER BY cnt DESC
                              ) A ON LOC.LocAisle = A.LocAisle
            WHERE TaskDetail.TaskType IN ('RPF')
            AND TaskDetail.Status = '0'
            AND EXISTS( SELECT 1 
                        FROM dbo.TaskManagerUserDetail tmu WITH (NOLOCK)
                        WHERE PermissionType = TaskDetail.TASKTYPE
                        AND tmu.UserKey = @c_UserID
                        AND tmu.AreaKey = @c_AreaKey01
                        AND tmu.Permission = '1') 
         ORDER BY
               A.Cnt DESC
            --,TaskDetail.Priority
            --,CASE WHEN TaskDetail.UserKeyOverRide = @c_UserID THEN '0' ELSE '1' END
            ,CASE WHEN TaskDetail.UserKeyOverRide = @c_UserID THEN '0' ELSE '1' END
            ,TaskDetail.Priority
            ,CASE WHEN LOC.LOCAisle = @c_LastLOCAisle THEN '0' ELSE '1' END
            --,LOC.LogicalLocation
            ,LOC.LOC
      END
      ELSE
      BEGIN
         DECLARE Cursor_RPFTaskCandidates CURSOR FAST_FORWARD READ_ONLY FOR --Note: global cursor   
         SELECT TaskDetailkey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
            JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)  
         WHERE TaskDetail.TaskType IN ('RPF', 'RP1')  
            AND TaskDetail.Status = '0'  
            AND TaskDetail.UserKeyOverRide IN (@c_UserID, '')
            AND EXISTS( SELECT 1   
               FROM TaskManagerUserDetail tmu WITH (NOLOCK)  
               WHERE PermissionType = TaskDetail.TASKTYPE  
                 AND tmu.UserKey = @c_UserID  
                 AND tmu.AreaKey = @c_AreaKey01  
                 AND tmu.Permission = '1')  
         ORDER BY  
             CASE WHEN LOC.LOCAisle = @c_LastLOCAisle THEN '0' ELSE '1' END
            --,TaskDetail.Priority  
            --,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END  
            ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END
            ,TaskDetail.Priority  
            ,LOC.LogicalLocation  
            ,LOC.LOC  
      END
   END
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
         @c_TransitLOC = TransitLOC, 
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

      SET @c_LOCCategory = ''
      SET @c_LOCAisle = ''
      SET @c_Facility = ''
      SET @c_ToLOCAisle = ''

      -- Get from LOC info
      SELECT 
         @c_LOCCategory = LocationCategory, 
         @c_LOCAisle = LocAisle, 
         @c_Facility = Facility
      FROM dbo.LOC WITH (NOLOCK) 
      WHERE LOC = @c_FromLoc

      -- Get equipment info  
      DECLARE @n_MaximumPallet INT  
      SELECT @n_MaximumPallet = E.MaximumPallet  
      FROM dbo.TaskManagerUser TMU WITH (NOLOCK)   
      JOIN dbo.EquipmentProfile E WITH (NOLOCK) ON (E.EquipmentProfileKey = TMU.EquipmentProfileKey)  
      WHERE TMU.UserKey = @c_UserID  
      
      IF @n_MaximumPallet > 0
      BEGIN
         SET @n_NoOfUserWorkingOnAisle = 0
         
         -- Get no of user working in the same aisle
         SELECT @n_NoOfUserWorkingOnAisle = COUNT( DISTINCT TD.UserKey)
         FROM dbo.TaskDetail TD WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON TD.FromLoc = LOC.Loc
         WHERE TD.Storerkey = @c_StorerKey
         AND   TD.[Status] = '3'
         AND   LOC.LocAisle = @c_LOCAisle
         
         IF ( @n_NoOfUserWorkingOnAisle + 1) > @n_MaximumPallet
         BEGIN
            FETCH NEXT FROM Cursor_RPFTaskCandidates INTO @c_TaskDetailKey
            CONTINUE
         END
      END
      
      -- Get To LOC info
      SELECT @c_ToLOCAisle = LocAisle 
      FROM dbo.LOC WITH (NOLOCK) 
      WHERE LOC = @c_ToLoc      
      
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
               --AND NOT L1.LocationCategory IN ('PND_OUT', 'PND') -- Exclude task going out from PND_OUT
               --AND NOT L2.LocationCategory IN ('PND_IN', 'PND')  -- Exclude task coming in into PND_IN
               AND UserKey <> @c_userid)
         BEGIN
            FETCH NEXT FROM Cursor_RPFTaskCandidates INTO @c_TaskDetailKey
            CONTINUE
         END
      END
      
      -- Get transit LOC
      IF @c_TransitLOC = ''
      BEGIN
         IF @c_LOCAisle <> @c_ToLOCAisle
         BEGIN
         -- To get PND location, get Codelkup.Code where Listname = æPNDÆ and Storerkey = <Storerkey> 
         -- and Code2 = LocAisle of Taskdetail.FromLoc and Codelkup.Long = æOUTÆ
            SELECT @c_TransitLOC = Code
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'PND'
            AND   Long = 'OUT'
            AND   Storerkey = @c_StorerKey
            AND   code2 = @c_LOCAisle
            
            IF @c_TransitLOC = ''
            BEGIN
               SET @n_err = 0
               EXECUTE rdt.rdt_GetTransitLoc05
                    @c_UserID
                  , @c_StorerKey
                  , @c_SKU
                  , @n_QTY
                  , @c_FromLOC
                  , @c_FromID
                  , @c_ToLOC
                  , 0             -- Lock PND transit LOC. 1=Yes, 0=No
                  , @c_TransitLOC OUTPUT 
                  , @n_err       OUTPUT
                  , @c_errmsg    OUTPUT
                  , @nFunc = 1764
               IF @n_err <> 0
               BEGIN
                  FETCH NEXT FROM Cursor_RPFTaskCandidates INTO @c_TaskDetailKey
                  CONTINUE
               END
            END
            ELSE
            BEGIN
               SET @n_MaxPallet = 0
               SET @n_PNDPalletCnt = 0

               SELECT @n_MaxPallet = MaxPallet
               FROM dbo.LOC WITH (NOLOCK) 
               WHERE Loc = @c_TransitLOC
               AND   Facility = @c_Facility
               
               IF @n_MaxPallet > 0
               BEGIN
                  SELECT @n_PNDPalletCnt = COUNT( DISTINCT ID) 
                  FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc) 
                  WHERE LLI.Loc = @c_TransitLOC 
                  AND  (Qty + PendingMoveIn ) > 0
                  AND   LOC.Facility = @c_Facility
               
                  IF @n_PNDPalletCnt >= @n_MaxPallet
                  BEGIN
                     FETCH NEXT FROM Cursor_RPFTaskCandidates INTO @c_TaskDetailKey
                     CONTINUE
                  END
               END
               
               EXEC rdt.rdt_Putaway_PendingMoveIn
                   @cUserName       = @c_UserID, 
                   @cType           = 'LOCK'  
                  ,@cFromLoc        = @c_FromLOC  
                  ,@cFromID         = @c_FromID  
                  ,@cSuggestedLOC   = @c_TransitLOC  
                  ,@cStorerKey      = @c_StorerKey  
                  ,@nErrNo          = @n_err    OUTPUT  
                  ,@cErrMsg         = @c_errmsg OUTPUT  
                  ,@cSKU            = @c_SKU  
                  ,@nPutawayQTY     = @n_QTY  
                  ,@nFunc           = 1764  
  
               IF @n_err <> 0  
               BEGIN
                  FETCH NEXT FROM Cursor_RPFTaskCandidates INTO @c_TaskDetailKey
                  CONTINUE
               END  
            END
         END
      END

      -- Reach final LOC
      IF @c_TransitLOC = @c_ToLOC 
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
                  --AND NOT L1.LocationCategory IN ('PND_OUT', 'PND') -- Exclude task going out from PND_OUT
                  --AND NOT L2.LocationCategory IN ('PND_IN', 'PND')  -- Exclude task coming in into PND_IN
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
         IF ( @c_TransitLOC = @c_ToLOC) OR @c_TransitLOC = ''
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
               ,TransitLOC = @c_TransitLOC
               ,FinalLOC   = @c_ToLOC
               ,FinalID    = @c_ToID
               ,ToLOC      = @c_TransitLOC
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
               IF @c_TransitLOC = @c_ToLOC
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
                     ,TransitLOC = @c_TransitLOC
                     ,FinalLOC   = @cOtherTaskToLOC
                     ,FinalID    = @cOtherTaskToID
                     ,ToLOC      = @c_TransitLOC
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
        execute nsp_logerror @n_err, @c_errmsg, 'nspTTMRP13'
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