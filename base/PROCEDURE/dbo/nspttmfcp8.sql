SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Stored Procedure: nspTTMFCP8                                               */
/* Copyright: IDS                                                             */
/*                                                                            */
/* Purpose: TM pallet pick strategy                                           */
/*                                                                            */
/* Modifications log:                                                         */
/* Date        Author    Ver  Purposes                                        */
/* 2021-03-25  yeekung   1.0  WMS-19059 Created                                */
/******************************************************************************/
CREATE PROC [dbo].[nspTTMFCP8]
    @c_UserID        NVARCHAR(18)
   ,@c_AreaKey01     NVARCHAR(10)
   ,@c_AreaKey02     NVARCHAR(10)
   ,@c_AreaKey03     NVARCHAR(10)
   ,@c_AreaKey04     NVARCHAR(10)
   ,@c_AreaKey05     NVARCHAR(10)
   ,@c_LastLOC       NVARCHAR(10)
   ,@n_err           INT            OUTPUT
   ,@c_errmsg        NVARCHAR(250)  OUTPUT
   ,@c_FromLOC       NVARCHAR(10)   OUTPUT
   ,@c_TaskDetailKey NVARCHAR(10)   OUTPUT
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
      ,@cFoundTask    NVARCHAR( 1)
      ,@b_SkipTheTask INT
      
   DECLARE 
       @c_StorerKey   NVARCHAR(15)
      ,@c_SKU         NVARCHAR(20)
      ,@c_FromID      NVARCHAR(18)
      ,@c_ToLOC       NVARCHAR(10)
      ,@c_ToID        NVARCHAR(18)
      ,@c_LOT         NVARCHAR(10)
      ,@n_QTY         INT
      ,@c_TaskType    NVARCHAR(10)
      ,@c_LOCCategory NVARCHAR(10)
      ,@c_LOCAisle    NVARCHAR(10)
      ,@c_Facility    NVARCHAR(5)
      ,@cGroupKey     NVARCHAR(10)
      ,@cTransitLOC   NVARCHAR(10)
      ,@cFacility     NVARCHAR(5)
      ,@cLangCode     NVARCHAR(3)

   SELECT 
       @b_debug = 0
      ,@n_starttcnt = @@TRANCOUNT
      ,@n_continue = 1
      ,@b_success = 0
      ,@n_err = 0
      ,@c_errmsg = ''
      ,@c_TaskDetailkey = ''
      ,@c_LastLOCAisle = ''

   -- Get session info
   SELECT
      @cLangCode = Lang_Code, 
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE UserName = SUSER_SNAME()

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN nspTTMFCP8 -- For rollback or commit only our own transaction
      
   SET @c_TaskDetailKey = ''

   IF @c_AreaKey01 <> '' AND @c_AreaKey01 <> 'ALL'
   BEGIN
      DECLARE Cursor_FPKTaskCandidates CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TaskDetailkey
         FROM dbo.TaskDetail WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)
            JOIN AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
         WHERE AreaDetail.AreaKey = @c_AreaKey01
            AND TaskDetail.TaskType IN ('FCP', 'FCP1')
            AND TaskDetail.Status IN( '0','3')
            AND TaskDetail.UserKeyOverRide IN (@c_userid, '')
            AND (SELECT SUM( ISNULL( QTYAllocated, 0) - ISNULL( QTYExpected, 0))
               FROM LOTxLOCxID LLI WITH (NOLOCK)
               WHERE LLI.LOC = TaskDetail.FromLOC
                  AND LLI.ID = TaskDetail.FromID) >= TaskDetail.QTY
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
            ,TaskDetail.Orderkey
            ,LOC.LogicalLocation
            ,LOC.LOC
   END
   ELSE
   BEGIN
      DECLARE Cursor_FPKTaskCandidates CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TaskDetailkey
         FROM dbo.TaskDetail WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)
         WHERE dbo.TaskDetail.TaskType IN ('FCP', 'FCP1')
            AND TaskDetail.Status IN( '0','3')
            AND TaskDetail.UserKeyOverRide IN (@c_userid, '')
            AND LOC.Facility = @cFacility
            AND (SELECT SUM( ISNULL( QTYAllocated, 0) - ISNULL( QTYExpected, 0))
               FROM LOTxLOCxID LLI WITH (NOLOCK)
               WHERE LLI.LOC = TaskDetail.FromLOC
                  AND LLI.ID = TaskDetail.FromID) >= TaskDetail.QTY
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
                 AND tmu.Permission = '1')
         ORDER BY
             TaskDetail.Priority
            ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END
            ,TaskDetail.Orderkey
            ,LOC.LogicalLocation
            ,LOC.LOC
   END

   -- Get a task
   OPEN Cursor_FPKTaskCandidates
   FETCH NEXT FROM Cursor_FPKTaskCandidates INTO @c_TaskDetailKey
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
         @cGroupKey   = GroupKey
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
         FETCH NEXT FROM Cursor_FPKTaskCandidates INTO @c_TaskDetailKey
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
         FETCH NEXT FROM Cursor_FPKTaskCandidates INTO @c_TaskDetailKey
         CONTINUE
      END

      -- Get from LOC info
      SELECT 
         @c_LOCCategory = LocationCategory, 
         @c_LOCAisle = LocAisle, 
         @c_Facility = Facility
      FROM dbo.LOC WITH (NOLOCK) 
      WHERE LOC = @c_FromLoc
      
      -- Check from aisle in used
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
            FETCH NEXT FROM Cursor_FPKTaskCandidates INTO @c_TaskDetailKey
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
            , @nFunc = 1812
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
      IF NOT EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (ROWLOCK) WHERE TaskDetailKey = @c_TaskDetailKey AND Status = '3' AND UserKey = @c_UserID)
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
            SET @n_Err = 184751                
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP') --UpdTaskDtlFail
            GOTO Fail
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

   -- Light up entire group (for PTL location only)
   IF EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_FromLOC AND LocationType = 'PTL' AND LocationCategory = 'FLOWRACK') AND @cGroupKey <> ''
   BEGIN
      DECLARE @cStation NVARCHAR(20)
      DECLARE @cPosition NVARCHAR(10)
      DECLARE @cIPAddress NVARCHAR(40)
      DECLARE @cFromLOC NVARCHAR(10)
      DECLARE @cQTY NVARCHAR(10)
      DECLARE @cLightMode NVARCHAR(10)
      DECLARE @curTD CURSOR

      SET @cLightMode = rdt.RDTGetConfig( 1812, 'LightMode', @c_StorerKey)
      
      SET @curTD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT FromLOC, SUM( QTY)
         FROM TaskDetail WITH (NOLOCK) 
         WHERE GroupKey = @cGroupKey
            AND StorerKey = @c_StorerKey
            AND TaskType = @c_TaskType
            AND Status <= '3'
         GROUP BY FromLOC
      OPEN @curTD
      FETCH NEXT FROM @curTD INTO @cFromLOC, @cQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get light LOC info
         SELECT TOP 1 
             @cStation = DeviceID, 
             @cPosition = DevicePosition, 
             @cIPAddress = IPAddress
         FROM DeviceProfile WITH (NOLOCK) 
         WHERE StorerKey = @c_StorerKey
            AND LOC = @cFromLOC 
            AND LogicalName = 'FCP'
               
         -- Light up LOC
         IF @@ROWCOUNT > 0
            EXEC PTL.isp_PTL_LightUpLoc
               @n_Func           = 1812
              ,@n_PTLKey         = 0
              ,@c_DisplayValue   = @cQTY 
              ,@b_Success        = @b_Success   OUTPUT    
              ,@n_Err            = @n_Err       OUTPUT  
              ,@c_ErrMsg         = @c_ErrMsg    OUTPUT
              ,@c_DeviceID       = @cStation
              ,@c_DevicePos      = @cPosition
              ,@c_DeviceIP       = @cIPAddress  
              ,@c_LModMode       = @cLightMode
           
         FETCH NEXT FROM @curTD INTO @cFromLOC, @cQTY
      END
   END

   COMMIT TRAN nspTTMFCP8 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN nspTTMFCP8 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO