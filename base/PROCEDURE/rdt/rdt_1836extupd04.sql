SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1836ExtUpd04                                    */
/* Purpose: Adidas update pick task from status H -> 0                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2022-08-03   yeekung 1.0   WMS-20242 Created                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1836ExtUpd04]
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
   DECLARE @cTDWaveKey        NVARCHAR( 10)
   DECLARE @cFacility         NVARCHAR( 5)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cLot              NVARCHAR( 10)
   DECLARE @cLoc              NVARCHAR( 10)
   DECLARE @cId               NVARCHAR( 10)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @nQty              INT
   DECLARE @nPDQty            INT
   DECLARE @nBalQty           INT
   DECLARE @curTask           CURSOR
   DECLARE @curPD             CURSOR
   DECLARE @curCPK            CURSOR
   DECLARE @cAreakey          NVARCHAR(20)

   SET @nTranCount = @@TRANCOUNT

   SELECT @cFacility = FACILITY
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- TM Replen From
   IF @nFunc = 1836
   BEGIN
      IF @nStep = 1 -- Final Loc
      BEGIN
         DECLARE @tWaveKey TABLE
         (
            waveKey NVARCHAR( 10) NOT NULL
            PRIMARY KEY CLUSTERED
          (
           [waveKey]
          )
         )

         -- Get task info
         SELECT
            @cTaskType = TaskType,
            @cStorerKey = Storerkey,
            @cWaveKey = WaveKey,
            @cAreakey = Areakey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskdetailKey = @cTaskdetailKey

         --INSERT INTO @tWaveKey
         --VALUES(@cWaveKey)

         INSERT INTO @tWaveKey
         SELECT DISTINCT WaveKey
         FROM PickDetail (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND DropID IN ( SELECT CaseID FROM TaskDetail (NOLOCK) WHERE StorerKey = @cStorerKey AND TaskType = 'RPF' AND WaveKey = @cWaveKey )
         --EXCEPT
         --SELECT WaveKey FROM TaskDetail (NOLOCK) WHERE StorerKey = @cStorerKey AND TaskType IN ( 'RPF', 'ASTRPT' ) AND Status < '9'


         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.ToLoc = LOC.Loc)
                     WHERE TD.Storerkey = @cStorerKey
                     AND   TD.WaveKey = @cWaveKey
                     AND   TD.TaskType = 'RPF'
                     AND   TD.[Status] < '9'
                     AND   loc.Facility = @cFacility
                     AND   TD.Areakey= @cAreakey
                     AND   LOC.LocationGroup NOT IN ('PACKING','SORTING') )
            GOTO Quit

         -- Only update pickdetail.taskDetailKey when all ASTRPT task is completed to prevent mismatch
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                     WHERE TD.Storerkey = @cStorerKey
                     AND   TD.WaveKey = @cWaveKey
                     AND   TD.TaskType = 'ASTRPT'
                     AND   TD.Areakey= @cAreakey
                     AND   TD.[Status] <> '9' )
            GOTO Quit


         -- Update pick task from status H -> 0
         IF @cTaskType = 'ASTRPT'
         BEGIN
            BEGIN TRAN
            SAVE TRAN rdt_1836ExtUpd04
            -- Loop tasks
            -- If all RPF task for this wave has completed then
            -- release all CPK task
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TaskDetailKey, CaseID, OrderKey, Lot, FromLoc, FromID, TaskType, QTY, SKU, TD.WaveKey
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               JOIN @tWaveKey TW ON (TD.waveKey = TW.waveKey)
               WHERE StorerKey = @cStorerKey
               AND   TaskType in ('CPK','ASTCPK')
               AND   [Status] = 'H'
               AND   TD.Areakey= @cAreakey
               --AND   WaveKey = @cWaveKey
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cCaseID, @cOrderKey, @cLot, @cLoc, @cId, @cTaskType, @nQty, @cSKU, @cTDWaveKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SET @nBalQty = @nQty

               IF @cTaskType = 'CPK'
                BEGIN
                  SET @curCPK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PickDetailKey, QTY
                     FROM dbo.PICKDETAIL WITH (NOLOCK)
                     WHERE Storerkey = @cStorerKey
                     AND   OrderKey = @cOrderKey
                     AND   CaseID = @cCaseID
                     --AND   Lot = @cLot
                     AND   Qty = @nQty
                     AND   loc = @cLoc
                     AND   ID = @cId
                     AND   SKU = @cSKU
                     AND   [Status] IN ( '0', '3')
                     ORDER BY editDate
                     OPEN @curCPK
                     FETCH NEXT FROM @curCPK INTO @cPickDetailKey, @nPDQty
                     WHILE @@FETCH_STATUS = 0
                     BEGIN

                        UPDATE dbo.PickDetail SET
                           TaskDetailKey = @cTaskKey,
                           EditWho = SUSER_SNAME(),
                           EditDate = GETDATE()
                        WHERE PickDetailKey = @cPickDetailKey

                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 189101
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickdetFail
                           GOTO RollBackTran
                        END

                        SET @nBalQty = @nBalQty - @nPDQty
                        IF @nBalQty = 0
                           BREAK


                        FETCH NEXT FROM @curCPK INTO @cPickDetailKey, @nPDQty
                     END
                     CLOSE @curCPK
                     DEALLOCATE @curCPK
                END

                IF @cTaskType = 'ASTCPK'
                BEGIN
                  SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PickDetailKey, Qty
                     FROM dbo.PICKDETAIL WITH (NOLOCK)
                     WHERE Storerkey = @cStorerKey
                     AND   waveKey = @cTDWaveKey
                     AND   CaseID = @cCaseID
                     --AND   Lot = @cLot
                     AND   Qty = @nQty
                     AND   loc = @cLoc
                     AND   ID = @cId
                     AND   SKU = @cSKU
                     AND   [Status] IN ( '0', '3')
                     ORDER BY editDate
                     OPEN @curPD
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPDQty
                     WHILE @@FETCH_STATUS = 0
                     BEGIN
                        UPDATE dbo.PickDetail SET
                           TaskDetailKey = @cTaskKey,
                           EditWho = SUSER_SNAME(),
                           EditDate = GETDATE()
                        WHERE PickDetailKey = @cPickDetailKey

                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 189102
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickdetFail
                           GOTO RollBackTran
                        END

                        SET @nBalQty = @nBalQty - @nPDQty
                        IF @nBalQty = 0
                           BREAK

                        FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPDQty
                     END
                     CLOSE @curPD
                     DEALLOCATE @curPD
                END


               -- Update Task
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                  [Status] = '0', -- Ready
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE(),
                  Trafficcop = NULL
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 189103
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curTask INTO @cTaskKey, @cCaseID, @cOrderKey, @cLot, @cLoc, @cId, @cTaskType, @nQty, @cSKU, @cTDWaveKey
            END

            COMMIT TRAN rdt_1836ExtUpd04 -- Only commit change made here
         END
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1836ExtUpd04 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO