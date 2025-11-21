SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1764GetTask11                                         */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose: lock by LOCAisle                                                  */
/*                                                                            */
/* Date        Rev  Author    Purposes                                        */
/* 05-09-2022  1.0  Ung       WMS-20659 Created (from rdt_1764GetTask08)      */
/* 28-03-2023  1.1  Ung       WMS-22053 Remove lock by aisle                  */
/*                            Add OpsPosition                                 */
/* 21-May-2019 1.2  Ung       WMS-8537 Fix skip task force close pallet       */
/* 23-08-2023  1.3  Ung       WMS-23369 Add UserKeyOverRide                   */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1764GetTask11] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 15),
   @cAreaKey         NVARCHAR( 10),
   @cListKey         NVARCHAR( 10),
   @cDropID          NVARCHAR( 20),
   @cNewTaskKey      NVARCHAR( 10) OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @bSkipTheTask   INT

   DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cFromFacility  NVARCHAR( 5)
   DECLARE @cFromLOC       NVARCHAR( 10)
   DECLARE @cFromID        NVARCHAR( 18)
   DECLARE @cStorerKey     NVARCHAR( 10)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @nQTY           INT
   DECLARE @cToID          NVARCHAR( 18)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cTaskType      NVARCHAR( 10)
   DECLARE @nMaxCartons    INT
   DECLARE @cResult        NVARCHAR(10)
   DECLARE @nTotCtn        INT
   DECLARE @cGroupKey      NVARCHAR( 10)
   DECLARE @cPalletFinalLOC   NVARCHAR( 10)
   DECLARE @cPalletFinalZone  NVARCHAR( 10)
   DECLARE @cFinalLOC         NVARCHAR( 10)
   DECLARE @cFinalPKZone      NVARCHAR( 10)
   DECLARE @cFinalPKZoneInLOC NVARCHAR( 10)
   DECLARE @cOPSPosition      NVARCHAR( 60)

   DECLARE @tLOCAisle TABLE 
   (
      LOCAisle NVARCHAR(10)
   )

   SET @cNewTaskKey = ''

   -- Get session info
   SELECT 
      @cStorerKey = StorerKey, 
      @cFromFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cResult = ''
   SET @cResult = rdt.RDTGetConfig( 1764, 'MaxCartons', @cStorerkey)
   IF ISNUMERIC(@cResult) = 1 AND @cResult NOT IN ('', '0')
   BEGIN
      SET @nMaxCartons = CAST(@cResult AS INT)

      SET @nTotCtn=0
      SELECT @nTotCtn=COUNT(DISTINCT UCCNo)
      FROM rdt.rdtRPFLog WITH (NOLOCK)
      WHERE DropID = @cDropID

      IF @nTotCtn + 1 > @nMaxCartons
      BEGIN
         SET @nErrNo = 196401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Exceed Max Ctns
         GOTO Fail
      END
   END

   -- Get task info
   SELECT TOP 1
      @cFinalLOC = CASE WHEN FinalLOC = '' THEN ToLOC ELSE FinalLoc END,
      @cWaveKey = WaveKey, 
      @cGroupKey = ISNULL( GroupKey, '')
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
      AND TransitCount = 0

   -- Get LOC info
   SELECT @cFinalPKZone = PickZone
   FROM dbo.LOC WITH (NOLOCK)
   WHERE LOC = @cFinalLOC

   -- Get FinalPKZone InLOC
   SET @cFinalPKZoneInLOC = ''
   SELECT @cFinalPKZoneInLOC = InLOC FROM PickZone WITH (NOLOCK) WHERE PickZone = @cFinalPKZone

   -- Calc destination grouping
   IF @cFinalPKZoneInLOC = ''
   BEGIN
      SET @cPalletFinalLOC = @cFinalLOC
      SET @cPalletFinalZone = ''
   END
   ELSE
   BEGIN
      SET @cPalletFinalLOC = ''
      SET @cPalletFinalZone = @cFinalPKZone
   END
   
   -- Get user info
   SELECT @cOPSPosition = OPSPosition
   FROM rdt.rdtUser WITH (NOLOCK)
   WHERE UserName = @cUserName
   
   -- Get next task
   DECLARE @curRPTask CURSOR
   IF @cAreaKey = ''
   BEGIN
      SET @curRPTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT 
            TaskDetailKey, TaskType, FromLOC, FromID, StorerKey, SKU, LOT, QTY, ToLOC, ToID
         FROM TaskDetail WITH (NOLOCK)
            JOIN LOC LOC1 WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC1.LOC)
            JOIN LOC LOC2 WITH (NOLOCK) ON (TaskDetail.ToLOC = LOC2.LOC)
            JOIN PickZone PickZone2 (NOLOCK) ON (LOC2.PickZone = PickZone2.PickZone)
            JOIN AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC1.PickZone)
         WHERE LOC1.Facility = @cFromFacility
            AND TaskDetail.TaskType IN ('RPF')
            AND TaskDetail.PickMethod = 'PP' -- Partial pallet
            AND TaskDetail.Status = '0'
            AND TaskDetail.UserKeyOverRide IN (@cUserName, '')
            AND TaskDetail.WaveKey = @cWaveKey
            AND TaskDetail.GroupKey = CASE WHEN @cGroupKey <> '' THEN @cGroupKey ELSE TaskDetail.GroupKey END
            AND PickZone2.InLOC = CASE WHEN @cPalletFinalLOC <> '' THEN @cPalletFinalLOC ELSE PickZone2.InLOC END
            AND PickZone2.PickZone = CASE WHEN @cPalletFinalZone <> '' THEN @cPalletFinalZone ELSE PickZone2.PickZone END
            AND LOC2.LocationRoom = @cOPSPosition
            -- Have permission in FromLOC
            AND EXISTS( SELECT 1
               FROM TaskManagerUserDetail TMU WITH (NOLOCK)
               WHERE PermissionType = TaskDetail.TaskType
                  AND TMU.UserKey = @cUserName
                  AND TMU.Permission = '1')
         ORDER BY 
             TaskDetail.Priority
            ,CASE WHEN TaskDetail.UserKeyOverRide = @cUserName THEN 1 ELSE 2 END
            ,CASE 
               WHEN LOC2.LocationType = 'DYNPPICK'    THEN 1 
               WHEN LOC2.LocationRoom = 'SafetyStock' THEN 2
               WHEN LOC2.LocationRoom = 'PACKSTATION' THEN 3
               ELSE 4
             END
            ,LOC1.LogicalLocation
            ,LOC1.LOC
   END
   ELSE
   BEGIN
      SET @curRPTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT 
            TaskDetailKey, TaskType, FromLOC, FromID, StorerKey, SKU, LOT, QTY, ToLOC, ToID
         FROM TaskDetail WITH (NOLOCK)
            JOIN LOC LOC1 WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC1.LOC)
            JOIN LOC LOC2 WITH (NOLOCK) ON (TaskDetail.ToLOC = LOC2.LOC)
            JOIN PickZone PickZone2 (NOLOCK) ON (LOC2.PickZone = PickZone2.PickZone)
            JOIN AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC1.PickZone)
         WHERE AreaDetail.AreaKey = @cAreaKey
            AND TaskDetail.TaskType IN ('RPF')
            AND TaskDetail.PickMethod = 'PP' -- Partial pallet
            AND TaskDetail.Status = '0'
            AND TaskDetail.UserKeyOverRide IN (@cUserName, '')
            AND TaskDetail.WaveKey = @cWaveKey
            AND TaskDetail.GroupKey = CASE WHEN @cGroupKey <> '' THEN @cGroupKey ELSE TaskDetail.GroupKey END
            AND PickZone2.InLOC = CASE WHEN @cPalletFinalLOC <> '' THEN @cPalletFinalLOC ELSE PickZone2.InLOC END
            AND PickZone2.PickZone = CASE WHEN @cPalletFinalZone <> '' THEN @cPalletFinalZone ELSE PickZone2.PickZone END
            AND LOC2.LocationRoom = @cOPSPosition
            -- Have permission in FromLOC
            AND EXISTS( SELECT 1
               FROM TaskManagerUserDetail TMU WITH (NOLOCK)
                  WHERE PermissionType = TaskDetail.TaskType
                     AND TMU.UserKey = @cUserName
                     AND TMU.Permission = '1')
         ORDER BY 
             TaskDetail.Priority
            ,CASE WHEN TaskDetail.UserKeyOverRide = @cUserName THEN 1 ELSE 2 END
            ,CASE 
               WHEN LOC2.LocationType = 'DYNPPICK'    THEN 1 
               WHEN LOC2.LocationRoom = 'SafetyStock' THEN 2
               WHEN LOC2.LocationRoom = 'PACKSTATION' THEN 3
               ELSE 4
             END
            ,LOC1.LogicalLocation
            ,LOC1.LOC
   END
   
   OPEN @curRPTask
   WHILE (1=1)
   BEGIN
      FETCH NEXT FROM @curRPTask INTO @cNewTaskKey, @cTaskType, @cFromLOC, @cFromID, @cStorerKey, @cSKU, @cLOT, @nQTY, @cToLOC, @cToID
      IF @@FETCH_STATUS <> 0
      BEGIN
         SET @cNewTaskKey = ''
         BREAK
      END

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

      BREAK -- Exit loop if found a task
   END

   IF @cNewTaskKey = ''
   BEGIN
      IF EXISTS( SELECT 1
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE ListKey = @cListKey
            AND Status = '5')
      BEGIN
         SET @nErrNo = 196402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask.ClosePL
         GOTO Fail
      END
      ELSE
      BEGIN
         SET @nErrNo = 196403
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
      SET @nErrNo = 196404
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDtlFail
   END

Fail:

END

GO