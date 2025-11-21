SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1836ExtUpd01                                    */
/* Purpose: Nikeph update pick task from status H -> 0                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2020-04-16   Ung       1.0   WMS-12812 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1836ExtUpd01]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cTaskdetailKey  NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @nErrNo          INT             OUTPUT,
   @cErrMsg         NVARCHAR( 20)   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
   DECLARE @cTaskKey          NVARCHAR( 10)
   DECLARE @cTaskType         NVARCHAR( 10)
   DECLARE @cCaseID           NVARCHAR( 20)
   DECLARE @cStorerKey        NVARCHAR( 15)
   DECLARE @cPickDetailKey    NVARCHAR( 15)
   DECLARE @cWaveKey          NVARCHAR( 10)
   DECLARE @cFacility         NVARCHAR( 5)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cLot              NVARCHAR( 10)
   DECLARE @cLoc              NVARCHAR( 10)
   DECLARE @cId               NVARCHAR( 10)
   DECLARE @curTask           CURSOR
   DECLARE @curPD             CURSOR
   
   SET @nTranCount = @@TRANCOUNT

   SELECT @cFacility = FACILITY
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- TM Replen From
   IF @nFunc = 1836
   BEGIN
      IF @nStep = 1 -- Final Loc
      BEGIN
         -- Get task info
         SELECT
            @cTaskType = TaskType,
            @cStorerKey = Storerkey,
            @cWaveKey = WaveKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskdetailKey = @cTaskdetailKey
         
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.ToLoc = LOC.Loc)
                     WHERE TD.Storerkey = @cStorerKey
                     AND   TD.WaveKey = @cWaveKey
                     AND   TD.TaskType = 'RPF'
                     AND   TD.[Status] = '0'
                     AND   loc.Facility = @cFacility
                     AND   LOC.LocationGroup <> 'PACKING')
            GOTO Quit

         -- Update pick task from status H -> 0
         IF @cTaskType = 'ASTRPT'
         BEGIN
            BEGIN TRAN
            SAVE TRAN rdt_1836ExtUpd01

            -- Loop tasks
            -- If all RPF task for this wave has completed then 
            -- release all CPK task
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TaskDetailKey, CaseID, OrderKey, Lot, FromLoc, FromID
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   TaskType = 'CPK'
               AND   [Status] = 'H'
               AND   WaveKey = @cWaveKey
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cCaseID, @cOrderKey, @cLot, @cLoc, @cId
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey
               FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
               AND   OrderKey = @cOrderKey
               AND   CaseID = @cCaseID
               AND   Lot = @cLot
               AND   loc = @cLoc
               AND   ID = @cId
               AND   [Status] IN ( '0', '3')
               OPEN @curPD
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  UPDATE dbo.PickDetail SET
                     TaskDetailKey = @cTaskKey,
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE()
                  WHERE PickDetailKey = @cPickDetailKey
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 151001
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickdetFail
                     GOTO RollBackTran
                  END

                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
               END
               CLOSE @curPD
               DEALLOCATE @curPD
               
               -- Update Task
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                  [Status] = '0', -- Ready
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(),
                  Trafficcop = NULL
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 151002
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curTask INTO @cTaskKey, @cCaseID, @cOrderKey, @cLot, @cLoc, @cId
            END

            COMMIT TRAN rdt_1836ExtUpd01 -- Only commit change made here
         END
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1836ExtUpd01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO