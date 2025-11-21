SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764GetTask10                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next replenish task (only for partial pallet)           */
/*          with same PND Loc                                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2021-04-26  1.0  James     WMS-16964. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1764GetTask10] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 15),
   @cAreaKey         NVARCHAR( 10),
   @cListKey         NVARCHAR( 10),
   @cDropID          NVARCHAR( 20),
   @cNewTaskKey      NVARCHAR( 10)    OUTPUT,
   @nErrNo           INT          OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @bSkipTheTask   INT
   DECLARE @cFinalPAZone   NVARCHAR( 10)
   DECLARE @cFinalAisle    NVARCHAR( 10)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cToLOCAisle    NVARCHAR( 10)
   DECLARE @cToLOCCat      NVARCHAR( 10)
   DECLARE @cToPAZone      NVARCHAR( 10)
   DECLARE @cFromLOC       NVARCHAR( 10)
   DECLARE @cFromID        NVARCHAR( 18)
   DECLARE @cStorerKey     NVARCHAR( 10)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @nQTY           INT
   DECLARE @cToID          NVARCHAR( 18)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cTaskType      NVARCHAR( 10)
   DECLARE @cLastToLoc     NVARCHAR( 10)
   DECLARE @cLastLocAisle  NVARCHAR( 10)
   DECLARE @cLastPND       NVARCHAR( 10)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cLocAisle      NVARCHAR( 10)
   DECLARE @cPND           NVARCHAR( 10)
   DECLARE @cTransitLOC    NVARCHAR( 10)

   DECLARE @tDoc TABLE  
   (  
      Sequence INT          NOT NULL IDENTITY( 1, 1),   
      WaveKey  NVARCHAR(10) NOT NULL,   
      PRIMARY KEY (Sequence)  
   )  
   
   SET @cNewTaskKey = ''

   SELECT @cStorerKey = StorerKey, 
          @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get task info
   SELECT TOP 1
      @cLastToLoc = ToLoc,
      @cPickMethod = PickMethod
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
   AND   [Status] = '5'
   AND   TransitCount = 0
   ORDER BY 1

   IF @cPickMethod = 'PP'
   BEGIN
      SELECT @cLastLocAisle = LocAisle
      FROM dbo.LOC WITH (NOLOCK)
      WHERE Loc = @cLastToLoc
      AND   Facility = @cFacility
   
      SELECT @cLastPND = Code
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'PND'
      AND   Storerkey = @cStorerKey
      AND   Long = 'IN'
      AND   code2 = @cLastLocAisle
      --IF SUSER_SNAME() = 'jameswong'
      --   SELECT @cLastLocAisle '@cLastLocAisle', @cLastToLoc '@cLastToLoc', @cFacility '@cFacility', @cStorerKey '@cStorerKey', @cLastPND '@cLastPND', @cListKey '@cListKey'
      -- Get next task
      DECLARE @curRPTask CURSOR
      IF @cAreaKey = ''
      BEGIN
         SET @curRPTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT TaskDetailkey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
            JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutawayZone)  
         WHERE dbo.TaskDetail.TaskType = 'RPF'  
            AND TaskDetail.Status = '0'  
            AND TaskDetail.UserKeyOverRide IN (@cUserName, '')
            AND TaskDetail.PickMethod = 'PP'
            AND EXISTS( SELECT 1   
               FROM TaskManagerUserDetail tmu WITH (NOLOCK)  
               WHERE PermissionType = TaskDetail.TASKTYPE  
                 AND tmu.UserKey = @cUserName  
                 AND tmu.AreaKey = @cAreaKey  
                 AND tmu.Permission = '1')  
         ORDER BY  
             TaskDetail.Priority  
            ,CASE WHEN TaskDetail.UserKeyOverRide = @cUserName THEN '0' ELSE '1' END  
            ,CASE WHEN LOC.LOCAisle = @cLastLOCAisle THEN '0' ELSE '1' END  
            ,LOC.LogicalLocation  
            ,LOC.LOC  
      END
      ELSE
      BEGIN
         SET @curRPTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT TaskDetailkey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
            JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutawayZone)  
         WHERE AreaDetail.AreaKey = @cAreaKey  
            AND TaskDetail.TaskType = 'RPF'  
            AND TaskDetail.Status = '0'  
            AND TaskDetail.UserKeyOverRide IN (@cUserName, '')
            AND TaskDetail.PickMethod = 'PP'
            AND EXISTS( SELECT 1   
               FROM TaskManagerUserDetail tmu WITH (NOLOCK)  
               WHERE PermissionType = TaskDetail.TASKTYPE  
                  AND tmu.UserKey = @cUserName  
                  AND tmu.AreaKey = @cAreaKey  
                  AND tmu.Permission = '1')  
         ORDER BY  
             TaskDetail.Priority  
            ,CASE WHEN TaskDetail.UserKeyOverRide = @cUserName THEN '0' ELSE '1' END  
            ,CASE WHEN LOC.LOCAisle = @cLastLOCAisle THEN '0' ELSE '1' END  
            ,LOC.LogicalLocation  
            ,LOC.LOC  
      END
      
      OPEN @curRPTask
      WHILE (1=1)
      BEGIN
         FETCH NEXT FROM @curRPTask INTO @cNewTaskKey
         IF @@FETCH_STATUS <> 0
         BEGIN
            SET @cNewTaskKey = ''
            BREAK
         END

         -- Get task info  
         SELECT  
            @cTaskType  = TaskType,   
            @cStorerKey = StorerKey,   
            @cSKU       = SKU,  
            @cLOT       = LOT,  
            @nQTY       = QTY,   
            @cFromLOC   = FromLOC,  
            @cFromID    = FromID,  
            @cToLOC     = ToLOC,  
            @cToID      = ToID,   
            @cTransitLOC = TransitLOC,   
            @cWaveKey    = WaveKey,
            @cPickMethod = PickMethod  
         FROM dbo.TaskDetail WITH (NOLOCK)  
         WHERE TaskDetailKey = @cNewTaskKey  
         
         -- Get ToLOC info
   	   SELECT
   	      @cFacility = Facility,
   	      @cToPAZone = PutawayZone,
   	      @cToLOCAisle  = LocAisle,
	         @cToLOCCat = LocationCategory
         FROM LOC WITH (NOLOCK)
         WHERE LOC = @cToLOC

         -- Check if ToLOC is VNA
         IF EXISTS( SELECT 1 FROM LOC WITH (NOLOCK)
            WHERE Facility = @cFacility
               AND PutawayZone = @cToPAZone
               AND LOCAisle = @cToLOCAisle
               AND LocationCategory IN ('PND', 'PND_IN'))
               AND @cToLOCAisle <> '' -- and LocAisle is setup
               AND @cToLOCCat NOT IN ('PND', 'PND_IN') -- and itself is not PND
         BEGIN
            -- For VNA, ToLOC must be same putawayzone and aisle as current pallet destination
            IF @cToPAZone <> @cFinalPAZone OR @cToLOCAisle <> @cFinalAisle
               CONTINUE
         END
         /*
         ELSE
         BEGIN
            -- Non VNA, ToLOC must be same putawayzone as current pallet destination
            IF @cToPAZone <> @cFinalPAZone
               CONTINUE
         END
         */

         -- Check skip task
         SET @bSuccess = 0
         SET @bSkipTheTask = 0
         EXECUTE nspCheckSkipTasks
             @cUserName
            ,@cNewTaskKey
            ,@cTaskType
            ,''
            ,''
            ,''
            ,''
            ,''
            ,''
            ,@bSkipTheTask OUTPUT
            ,@bSuccess     OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @bSuccess <> 1 OR @nErrNo <> 0
            GOTO Fail

         IF @bSkipTheTask = 1
            CONTINUE

         -- Check equipment profile
         SELECT @bSuccess = 0
         EXECUTE nspCheckEquipmentProfile
             @c_Userid = @cUserName
            ,@c_TaskDetailKey = @cNewTaskKey
            ,@c_StorerKey = @cStorerKey
            ,@c_sku = @cSKU
            ,@c_lot = @cLOT
            ,@c_FromLoc = @cFromLOC
            ,@c_fromID = @cFromID
            ,@c_toLoc = '' -- @c_ToLOC
            ,@c_toID = '' -- @c_ToID
            ,@n_qty = @nQTY
            ,@b_Success = @bSuccess OUTPUT
            ,@n_err = @nErrNo OUTPUT
            ,@c_errmsg = @cErrMsg OUTPUT
         IF @bSuccess <> 1 OR @nErrNo <> 0
            CONTINUE

         SELECT @cLocAisle = LocAisle
         FROM dbo.LOC WITH (NOLOCK)
         WHERE Loc = @cToLoc
         AND   Facility = @cFacility
   
         SELECT @cPND = Code
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'PND'
         AND   Storerkey = @cStorerKey
         AND   Long = 'IN'
         AND   code2 = @cLocAisle
         
         --IF SUSER_SNAME() = 'jameswong'
         --SELECT @cNewTaskKey '@cNewTaskKey', @cToLOC '@cToLOC', @cToLOCAisle '@cToLOCAisle', @cLastLOCAisle '@cLastLOCAisle', @cPND '@cPND', @cLastPND '@cLastPND'
         IF @cPND = @cLastPND
            BREAK -- Exit loop if found a task
      END
   END
   
   IF @cNewTaskKey = ''
   BEGIN
      IF EXISTS( SELECT 1
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE ListKey = @cListKey
            AND Status = '5')
      BEGIN
         SET @nErrNo = 167651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask.ClosePL
         GOTO Fail
      END
      ELSE
      BEGIN
         SET @nErrNo = 167652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
         GOTO Fail
      END
   END

   -- Get Transit location from initial task
   SELECT @cTransitLOC = TransitLOC
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
      AND TransitCount = 0 -- initial task

   -- Update new task
   IF @cTransitLOC = ''
      UPDATE TaskDetail WITH (ROWLOCK) SET
          Status     = '3'
         ,UserKey    = @cUserName
         ,ReasonKey  = ''
         ,ListKey    = @cListKey
         ,StartTime  = CURRENT_TIMESTAMP
         ,EditDate   = CURRENT_TIMESTAMP
         ,EditWho    = @cUserName
         ,TrafficCop = NULL
      WHERE TaskDetailKey = @cNewTaskKey
   ELSE
      UPDATE TaskDetail WITH (ROWLOCK) SET
          Status     = '3'
         ,UserKey    = @cUserName
         ,ReasonKey  = ''
         ,TransitLOC = @cTransitLOC
         ,FinalLOC   = @cToLOC
         ,FinalID    = @cToID
         ,ToLOC      = @cTransitLOC
         ,ToID       = @cDropID
         ,ListKey    = @cListKey
         ,StartTime  = CURRENT_TIMESTAMP
         ,EditDate   = CURRENT_TIMESTAMP
         ,EditWho    = @cUserName
         ,TrafficCop = NULL
      WHERE TaskDetailKey = @cNewTaskKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 90154
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDtlFail
   END

Fail:

END

GO