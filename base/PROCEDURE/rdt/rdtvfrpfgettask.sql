SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdtVFRPFGetTask                                     */  
/* Copyright      : Maersk                                              */  
/*                                                                      */  
/* Purpose: Get next replenish task (only for partial pallet)           */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author    Purposes                                  */  
/* 12-Jan-2015 1.0  Ung       SOS259759 Created                         */  
/* 12-Jun-2015 1.1  Ung       SOS343961 Grouping diff wave type diff UOM*/  
/* 29-Nov-2019 1.2  YeeKung   WMS11247 RPF_Task_Enhancement (yeekung01) */  
/* 21-May-2019 1.3  Ung       WMS-8537 Fix skip task force close pallet */
/* 23-Aug-2023 1.4  Ung       WMS-23369 Add UserKeyOverRide             */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdtVFRPFGetTask] (  
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
   DECLARE @cOrderGroup    NVARCHAR( 20)  
   DECLARE @cTaskType      NVARCHAR( 10)  
   DECLARE @cWaveType      NVARCHAR( 1)  
   DECLARE @cTaskUOM       NVARCHAR( 5)  
   DECLARE @cTaskSKU       NVARCHAR( 20)  
  
   SET @cNewTaskKey = ''  
  
   -- Get task info  
   SELECT TOP 1  
      @cFinalLOC = CASE WHEN FinalLOC = '' THEN ToLOC ELSE FinalLoc END,   
      @cWaveKey = WaveKey,   
      @cTaskUOM = UOM,   
      @cTaskSKU = SKU  
   FROM dbo.TaskDetail WITH (NOLOCK)  
   WHERE ListKey = @cListKey  
      AND TransitCount = 0  
  
   -- Get final LOC info  
   SELECT  
      @cFinalPAZone = PutawayZone,  
      @cFinalAisle = LocAisle  
   FROM dbo.LOC WITH (NOLOCK)  
   WHERE LOC = @cFinalLOC  
  
   -- Get wave info  
   SELECT @cWaveType = LEFT( LTRIM( UserDefine01), 1) FROM Wave WITH (NOLOCK) WHERE WaveKey = @cWaveKey  
   IF @cWaveType = ''  
   BEGIN  
      -- Get order info  
      SELECT TOP 1   
         @cOrderGroup = O.OrderGroup  
      FROM dbo.Orders O WITH (NOLOCK)  
         JOIN dbo.WaveDetail WD WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)  
      WHERE WD.WaveKey = @cWaveKey  
      ORDER BY O.OrderKey  
        
      SELECT @cWaveType = Short FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'ORDERGROUP' AND Code = @cOrderGroup  
   END  
  
   -- Get next task  
   DECLARE @curRPTask CURSOR  
   IF @cAreaKey = ''  
      SET @curRPTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT   
            TaskDetailKey, TaskType, FromLOC, FromID, StorerKey, SKU, LOT, QTY, ToLOC, ToID  
         FROM TaskDetail WITH (NOLOCK)  
            INNER JOIN LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
            INNER JOIN AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)  
         WHERE TaskDetail.TaskType IN ('RPF')  
            AND TaskDetail.PickMethod = 'PP' -- Partial pallet  
            AND TaskDetail.Status = '0'  
            AND TaskDetail.UserKeyOverRide IN (@cUserName, '')
            AND TaskDetail.WaveKey = @cWaveKey  
            AND   
            (  -- WaveType = L/N/R/E. L=Launch, N=Normal, R=Leisure, E=Ecom  
               (@cWaveType = 'N') OR                                                -- Can mix any UOM  
               (@cWaveType = 'R') OR                                                -- Can mix any UOM  
               (@cWaveType = 'L' AND @cTaskUOM = '6'  AND TaskDetail.UOM = '6') OR  -- UOM 6 must be a pallet by itself, and same SKU  
               (@cWaveType = 'L' AND @cTaskUOM <> '6' AND TaskDetail.UOM <> '6') OR -- UOM 2,7 can mix in a pallet  
               (@cWaveType = 'E')                                                   -- Can mix any UOM (yeekung01)  
            )  
            -- Have permission in FromLOC  
            AND EXISTS( SELECT 1  
               FROM TaskManagerUserDetail TMU WITH (NOLOCK)  
                  WHERE PermissionType = TaskDetail.TaskType  
                     AND TMU.UserKey = @cUserName  
                     AND TMU.Permission = '1')  
         ORDER BY 
             TaskDetail.Priority
            ,CASE WHEN TaskDetail.UserKeyOverRide = @cUserName THEN '0' ELSE '1' END
            ,LOC.LogicalLocation
            ,LOC.LOC  
   ELSE  
      SET @curRPTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT 
            TaskDetailKey, TaskType, FromLOC, FromID, StorerKey, SKU, LOT, QTY, ToLOC, ToID  
         FROM TaskDetail WITH (NOLOCK)  
            INNER JOIN LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
            INNER JOIN AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)  
         WHERE AreaDetail.AreaKey = @cAreaKey  
            AND TaskDetail.TaskType IN ('RPF')  
            AND TaskDetail.PickMethod = 'PP' -- Partial pallet  
            AND TaskDetail.Status = '0'  
            AND TaskDetail.UserKeyOverRide IN (@cUserName, '')
            AND TaskDetail.WaveKey = @cWaveKey  
            AND   
            (  -- WaveType = L/N/R/E. L=Launch, N=Normal, R=Leisure, E-Ecom  
               (@cWaveType = 'N') OR                                                -- Can mix any UOM  
               (@cWaveType = 'R') OR                                                -- Can mix any UOM  
               (@cWaveType = 'L' AND @cTaskUOM = '6'  AND TaskDetail.UOM = '6') OR  -- UOM 6 must be a pallet by itself, and same SKU  
               (@cWaveType = 'L' AND @cTaskUOM <> '6' AND TaskDetail.UOM <> '6')OR -- UOM 2,7 can mix in a pallet  
               (@cWaveType = 'E')                                                   -- Can mix any UOM (yeekung01)  
            )  
            -- Have permission in FromLOC  
            AND EXISTS( SELECT 1  
               FROM TaskManagerUserDetail TMU WITH (NOLOCK)  
                  WHERE PermissionType = TaskDetail.TaskType  
                     AND TMU.UserKey = @cUserName  
                     AND TMU.Permission = '1')  
         ORDER BY 
             TaskDetail.Priority
            ,CASE WHEN TaskDetail.UserKeyOverRide = @cUserName THEN '0' ELSE '1' END
            ,LOC.LogicalLocation
            ,LOC.LOC  
  
   OPEN @curRPTask  
   WHILE (1=1)  
   BEGIN  
      FETCH NEXT FROM @curRPTask INTO @cNewTaskKey, @cTaskType, @cFromLOC, @cFromID, @cStorerKey, @cSKU, @cLOT, @nQTY, @cToLOC, @cToID  
      IF @@FETCH_STATUS <> 0  
      BEGIN  
         SET @cNewTaskKey = ''  
         BREAK   
      END  
        
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
  
      BREAK -- Exit loop if found a task  
   END  
  
   IF @cNewTaskKey = ''  
   BEGIN  
      IF EXISTS( SELECT 1  
         FROM dbo.TaskDetail WITH (NOLOCK)  
         WHERE ListKey = @cListKey  
            AND Status = '5')  
      BEGIN  
         SET @nErrNo = 74351  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask.ClosePL  
         GOTO Fail  
      END  
      ELSE  
      BEGIN  
         SET @nErrNo = 74352  
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
      SET @nErrNo = 74353  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDtlFail  
   END  
  
Fail:  
  
END 

GO