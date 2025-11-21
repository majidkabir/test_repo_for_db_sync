SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1764GetTask12                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Get next replenish task (Levis)                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2024-12-06  1.0  JCH507    FCR-1157 (Copied from Generic GetNextTask)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_1764GetTask12] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 15),
   @cAreaKey         NVARCHAR( 10),
   @cListKey         NVARCHAR( 10),
   @cDropID          NVARCHAR( 20),
   @cNewTaskKey      NVARCHAR( 10)  OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bDebugFlag     BINARY = 0

   DECLARE @bSuccess       INT
   DECLARE @bSkipTheTask   INT
   DECLARE @cFinalLOC      NVARCHAR( 10)
   DECLARE @cFinalID       NVARCHAR( 18)
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
   DECLARE @cPalletFinalLOC NVARCHAR( 10)
   DECLARE @cOrderGroup    NVARCHAR( 20)
   DECLARE @cTaskType      NVARCHAR( 10)
   DECLARE @cPickMethod    NVARCHAR( 10)

   DECLARE @cLastToLoc     NVARCHAR( 10) --v1.0

   SET @cNewTaskKey = ''

   -- Get task info
   SELECT TOP 1
      @cLastToLoc = ToLoc, --v1.0
      @cFinalLOC = CASE WHEN FinalLOC = '' THEN ToLOC ELSE FinalLoc END,
      @cWaveKey = WaveKey,
      @cPickMethod = PickMethod --v1.0
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
      AND TransitCount = 0

   IF @bDebugFlag = 1
      SELECT 'Handled Task Info', @cLastToLoc AS LastToLoc, @cFinalLOC AS FinalLoc, @cWaveKey AS WaveKey, @cPickMethod AS PickMethod

   -- Get final LOC info
   SELECT
      @cFinalPAZone = PutawayZone,
      @cFinalAisle = LocAisle
   FROM dbo.LOC WITH (NOLOCK)
   WHERE LOC = @cFinalLOC

   IF @bDebugFlag = 1
      SELECT 'Handled FinalLoc Info', @cFinalPAZone AS FinalPAZone, @cFinalAisle AS FinalAisle

   --V1.0 JCH507
   /*
   -- Get order info
   SELECT TOP 1
      @cOrderGroup = O.OrderGroup
   FROM dbo.Orders O WITH (NOLOCK)
      JOIN dbo.WaveDetail WD WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)
   WHERE WD.WaveKey = @cWaveKey
   ORDER BY O.OrderKey


   -- Calc destination grouping
   IF @cOrderGroup = 'L'  --L/RT/WS. L=Launch, RT=Retail, WS=Wholesale
      SET @cPalletFinalLOC = @cFinalLOC
   ELSE
      SET @cPalletFinalLOC = ''
   */
   SET @cPalletFinalLOC = ''
   --V1.0 JCH507 END

   -- Get next task
   DECLARE @curRPTask CURSOR
   IF @cAreaKey = ''
      SET @curRPTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT
            TaskDetailKey, TaskType, FromLOC, FromID, StorerKey, SKU, LOT, QTY, ToLOC, ToID
         FROM dbo.TaskDetail WITH (NOLOCK)
            INNER JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)
            INNER JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
         WHERE TaskDetail.TaskType IN ('RPF')
            AND TaskDetail.PickMethod = 'PP' -- Partial pallet
            AND TaskDetail.Status = '0'
            AND TaskDetail.UserKeyOverRide IN (@cUserName, '')
            AND TaskDetail.WaveKey = @cWaveKey
            AND TaskDetail.ToLOC = CASE WHEN @cPalletFinalLOC <> '' THEN @cPalletFinalLOC ELSE TaskDetail.ToLOC END
            AND TaskDetail.PickMethod = @cPickMethod -- V1.0
            -- Have permission in FromLOC
            AND EXISTS( SELECT 1
               FROM dbo.TaskManagerUserDetail TMU WITH (NOLOCK)
                  WHERE PermissionType = TaskDetail.TaskType
                     AND TMU.UserKey = @cUserName
                     AND TMU.Permission = '1')
         ORDER BY TaskDetail.Priority, LOC.LogicalLocation, LOC.LOC
   ELSE
      SET @curRPTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT
            TaskDetailKey, TaskType, FromLOC, FromID, StorerKey, SKU, LOT, QTY, ToLOC, ToID
         FROM dbo.TaskDetail WITH (NOLOCK)
            INNER JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)
            INNER JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)
         WHERE AreaDetail.AreaKey = @cAreaKey
            AND TaskDetail.TaskType IN ('RPF')
            AND TaskDetail.PickMethod = 'PP' -- Partial pallet
            AND TaskDetail.Status = '0'
            AND TaskDetail.UserKeyOverRide IN (@cUserName, '')
            AND TaskDetail.WaveKey = @cWaveKey
            AND TaskDetail.ToLOC = CASE WHEN @cPalletFinalLOC <> '' THEN @cPalletFinalLOC ELSE TaskDetail.ToLOC END
            AND TaskDetail.PickMethod = @cPickMethod -- V1.0
            -- Have permission in FromLOC
            AND EXISTS( SELECT 1
               FROM dbo.TaskManagerUserDetail TMU WITH (NOLOCK)
                  WHERE PermissionType = TaskDetail.TaskType
                     AND TMU.UserKey = @cUserName
                     AND TMU.Permission = '1')
         ORDER BY TaskDetail.Priority, LOC.LogicalLocation, LOC.LOC

   OPEN @curRPTask
   WHILE (1=1)
   BEGIN
      FETCH NEXT FROM @curRPTask INTO @cNewTaskKey, @cTaskType, @cFromLOC, @cFromID, @cStorerKey, @cSKU, @cLOT, @nQTY, @cToLOC, @cToID
      IF @@FETCH_STATUS <> 0
      BEGIN
         SET @cNewTaskKey = ''
         BREAK
      END

      IF @bDebugFlag = 1
         SELECT 'Loop Tasks', @cNewTaskKey AS Task, @cFromLOC AS FromLoc, @cToLOC AS ToLoc

      -- Get ToLOC info
   	SELECT
   	   @cFacility = Facility,
   	   @cToPAZone = PutawayZone,
   	   @cToLOCAisle  = LocAisle,
	      @cToLOCCat = LocationCategory
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cToLOC

      IF @bDebugFlag = 1
         SELECT 'Check PAZone', @cToPAZone AS ToPAZone, @cFinalPAZone AS FinalPAZone
      --V1.0 Start
      -- NewTask's ToLoc PAZone must be same as the last Final Loc's PAZone
      -- Then the transit loc will be same
      IF @cToPAZone <> @cFinalPAZone
      BEGIN
         SELECT 'PAZoen not equal, next'
         CONTINUE
      END
      /*
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
      */
      --V1.0 End

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
      BEGIN
         SELECT 'Task Skipped, next'
         CONTINUE
      END

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
      BEGIN
         SELECT 'Equipment not qualified, next'
         CONTINUE
      END

      BREAK -- Exit loop if found a task
   END

   IF @cNewTaskKey = ''
   BEGIN
      IF EXISTS( SELECT 1
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE ListKey = @cListKey
            AND Status = '5')
      BEGIN
         SET @nErrNo = 230301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask.ClosePL
         GOTO Fail
      END
      ELSE
      BEGIN
         SET @nErrNo = 230302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
         GOTO Fail
      END
   END

   -- Get Transit location from initial task
   DECLARE @cTransitLOC NVARCHAR( 10)
   SELECT @cTransitLOC = TransitLOC
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
      AND TransitCount = 0 -- initial task

   -- Update new task
   BEGIN TRY
      IF @cTransitLOC = ''
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
            Status     = '3'
            ,UserKey    = @cUserName
            ,ReasonKey  = ''
            ,ListKey = @cListKey --V1.0
            ,StartTime  = CURRENT_TIMESTAMP
            ,EditDate   = CURRENT_TIMESTAMP
            ,EditWho    = @cUserName
            ,TrafficCop = NULL
         WHERE TaskDetailKey = @cNewTaskKey
      ELSE
         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
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
   END TRY
   BEGIN CATCH
      SET @nErrNo = 230303
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDtlFail
   END CATCH

Fail:

IF @bDebugFlag = 1
   SELECT 'Quit', @nErrNo, @cErrMsg

END

GO