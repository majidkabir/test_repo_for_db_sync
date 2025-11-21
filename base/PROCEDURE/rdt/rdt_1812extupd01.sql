SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812ExtUpd01                                    */
/* Purpose: Extended Update                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-02-05   Ung       1.0   WMS-3333 Created                        */
/* 2018-02-05   Ung       1.0   WMS-6906 Add SKIP                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1812ExtUpd01]
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT,          
   @nInputKey       INT,          
   @cTaskdetailKey  NVARCHAR( 10),
   @cDropID         NVARCHAR( 20),
   @nQTY            INT,          
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT OUTPUT,   
   @cErrMsg         NVARCHAR( 20) OUTPUT,
   @nAfterStep      INT      
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
   DECLARE @cFromLOC       NVARCHAR(10)
   DECLARE @cStatus        NVARCHAR(10)
   DECLARE @cStorerKey     NVARCHAR(15)
   DECLARE @cFacility      NVARCHAR(5)
   DECLARE @cLOCType       NVARCHAR(10)
   DECLARE @cPutawayZone   NVARCHAR(10)
   DECLARE @cListKey       NVARCHAR(10)
   DECLARE @cStation       NVARCHAR( 20)
   DECLARE @cPosition      NVARCHAR( 10)                  

   SET @nTranCount = @@TRANCOUNT

   -- TM Case Pick
   IF @nFunc = 1812
   BEGIN
      IF @nStep = 6 -- TO LOC
      BEGIN
         IF @nInputKey = '1' -- ENTER
         BEGIN
            -- Get login info
            SELECT 
               @cFacility = Facility, 
               @cListKey = V_String7
            FROM rdt.rdtMobRec WITH (NOLOCK) 
            WHERE Mobile = @nMobile

            -- Get task info
            SELECT TOP 1 
               @cStorerKey = StorerKey, 
               @cFromLOC = FromLOC, 
               @cStatus = Status
            FROM TaskDetail WITH (NOLOCK)  
            WHERE ListKey = @cListKey
               AND Status = '5'
            
            -- Task confirmed
            IF @@ROWCOUNT = 1
            BEGIN
               -- Get LOC info
               SELECT 
                  @cLOCType = LocationType, 
                  @cPutawayZone = PutawayZone
               FROM LOC WITH (NOLOCK) 
               WHERE LOC = @cFromLOC
            
               -- PTL LOC
               IF @cLOCType = 'PTL'
               BEGIN 
                  -- No outstanding tasks in the zone
                  IF NOT EXISTS( SELECT TOP 1 1 
                     FROM TaskDetail TD WITH (NOLOCK) 
                        JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)
                     WHERE TD.StorerKey = @cStorerKey
                        AND TD.TaskType = 'FCP'
                        AND TD.Status = '0'
                        AND LOC.PutawayZone = @cPutawayZone
                        AND LOC.LocationType = 'PTL')
                  BEGIN
                     -- Get indicator light of the zone
                     SELECT TOP 1
                        @cStation = DeviceID, 
                        @cPosition = DevicePosition
                     FROM DeviceProfile DP WITH (NOLOCK)
                        JOIN LOC WITH (NOLOCK) ON (DP.LOC = LOC.LOC)
                     WHERE DP.DeviceType = 'STATION'
                        AND LOC.Facility = @cFacility
                        AND LOC.PutawayZone = @cPutawayZone
                        AND LOC.LocationType = 'PTL'
                        AND LOC.LocationCategory = 'PTLTOWER'
                     ORDER BY LOC.LOC
                     
                     -- Turn off indicator light of the zone
                     IF @@ROWCOUNT > 0
                     BEGIN
                        EXEC PTL.isp_PTL_TerminateModuleSingle
                           @cStorerKey
                          ,@nFunc
                          ,@cStation
                          ,@cPosition
                          ,@bSuccess   OUTPUT
                          ,@nErrNo     OUTPUT
                          ,@cErrMsg    OUTPUT
                        IF @nErrNo <> 0
                           GOTO Quit
                     END
                  END
               END
            END

            -- SKIP or CANCEL tasks
            IF EXISTS( SELECT TOP 1 1 
               FROM TaskDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
                  AND ListKey = @cListKey 
                  AND Status IN ('0', 'X'))
            BEGIN
               DECLARE @cTaskKey    NVARCHAR(10)
               DECLARE @cTransitLOC NVARCHAR(10) 
               DECLARE @cFinalLOC   NVARCHAR(10)
               DECLARE @cFinalID    NVARCHAR(10)
               DECLARE @curTask     CURSOR
               
               BEGIN TRAN
               SAVE TRAN rdt_1812ExtUpd01
               
               -- Loop task
               SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT TaskDetailKey, TransitLOC, FinalLOC, FinalID
                  FROM TaskDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey 
                     AND ListKey = @cListKey 
                     AND Status IN ('0', 'X')
               OPEN @curTask
               FETCH NEXT FROM @curTask INTO @cTaskKey, @cTransitLOC, @cFinalLOC, @cFinalID
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- Update tasks
                  IF @cTransitLOC = ''
                     UPDATE dbo.TaskDetail SET
                         ListKey = ''
                        ,DropID = ''
                        ,EditDate = GETDATE()
                        ,EditWho  = SUSER_SNAME()
                        ,TrafficCop = NULL
                     WHERE TaskDetailKey = @cTaskKey
                  ELSE
                     UPDATE dbo.TaskDetail SET
                         ListKey = ''
                        ,DropID = ''
                        ,TransitLOC = ''
                        ,FinalLOC = ''
                        ,FinalID = ''
                        ,ToLOC = @cFinalLOC
                        ,ToID = @cFinalID
                        ,EditDate = GETDATE()
                        ,EditWho  = SUSER_SNAME()
                        ,TrafficCop = NULL
                     WHERE TaskDetailKey = @cTaskKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 132051
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
                     GOTO RollBackTran
                  END

                  FETCH NEXT FROM @curTask INTO @cTaskKey, @cTransitLOC, @cFinalLOC, @cFinalID
               END

               COMMIT TRAN rdt_1812ExtUpd01 -- Only commit change made here
            END
         END
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1812ExtUpd01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO