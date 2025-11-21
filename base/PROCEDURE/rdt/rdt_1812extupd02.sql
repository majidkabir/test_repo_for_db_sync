SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812ExtUpd02                                    */
/* Purpose: Extended Update                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-03-08   Ung       1.0   WMS-4221 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1812ExtUpd02]
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

   DECLARE @nTranCount  INT
   
   DECLARE @tTask TABLE
   (
      TaskDetailKey NVARCHAR(10)
   )
   
   SET @nTranCount = @@TRANCOUNT

   -- TM Case Pick
   IF @nFunc = 1812
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         DECLARE @cPickSlipNo NVARCHAR(10)
         DECLARE @cTaskKey    NVARCHAR(10)
         DECLARE @cStatus     NVARCHAR(10)
         DECLARE @cListKey    NVARCHAR(10)

         -- Get task info
         SELECT
            @cDropID = DropID, -- Cancel/SKIP might not have DropID
            @cListKey = ListKey -- Cancel/SKIP might not have ListKey (e.g. last carton SKIP)
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskdetailKey = @cTaskdetailKey

         -- Get list key (quick fix)
         IF @cListKey = ''
            SELECT @cListKey = V_String7 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

         -- Get initial task
         IF @cListKey <> ''  -- For protection, in case ListKey is blank
            INSERT INTO @tTask (TaskDetailKey)
            SELECT TaskDetailKey
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE ListKey = @cListKey
               AND TransitCount = 0

         BEGIN TRAN
         SAVE TRAN rdt_1812ExtUpd02

         -- Loop tasks
         DECLARE @curTask CURSOR 
         SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT T.TaskDetailKey, TD.Status
            FROM dbo.TaskDetail TD WITH (NOLOCK)
               JOIN @tTask T ON (TD.TaskDetailKey = T.TaskDetailKey)
         OPEN @curTask
         FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Cancel/skip task
            IF @cStatus IN ('X', '0')
            BEGIN
               -- Update Task
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                  ListKey = '',
                  DropID = '',
                  EndTime = GETDATE(),
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  Trafficcop = NULL
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 120951
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END
            END

            -- Completed task
            IF @cStatus = '9'
            BEGIN
               DECLARE @cOrderKey NVARCHAR(10)
               DECLARE @dScanOutDate DATETIME
               DECLARE @curPSNO CURSOR

               -- Loop orders
               SET @curPSNO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT DISTINCT OrderKey
                  FROM PickDetail WITH (NOLOCK)
                  WHERE TaskDetailKey = @cTaskKey
               OPEN @curPSNO
               FETCH NEXT FROM @curPSNO INTO @cOrderKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  SET @cPickSlipNo = ''

                  -- Get pick slip (discrete)
                  SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WHERE OrderKey = @cOrderKey

                  IF @cPickSlipNo <> ''
                  BEGIN
                     -- Get PickingInfo info
                     SELECT @dScanOutDate = ScanOutDate FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

                     -- Scan-in
                     IF @@ROWCOUNT = 0
                     BEGIN
                        INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
                        VALUES (@cPickSlipNo, GETDATE(), SUSER_SNAME(), GETDATE())
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 120952
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-Out Fail
                           GOTO RollBackTran
                        END
                     END

                     -- Scan-out
                     IF @dScanOutDate IS NULL
                     BEGIN
                        -- Check outstanding PickDetail
                        IF NOT EXISTS( SELECT TOP 1 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status < '5')
                        BEGIN
                           UPDATE PickingInfo WITH (ROWLOCK) SET
                              ScanOutDate = GETDATE(),
                              PickerID = SUSER_SNAME(),
                              EditWho = SUSER_SNAME()
                           WHERE PickSlipNo = @cPickSlipNo
                           IF @@ERROR <> 0
                           BEGIN
                              SET @nErrNo = 120953
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-Out Fail
                              GOTO RollBackTran
                           END
                        END
                     END
                  END
                  FETCH NEXT FROM @curPSNO INTO @cOrderKey
               END
            END
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus
         END
         
         COMMIT TRAN rdt_1812ExtUpd02 -- Only commit change made here
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1812ExtUpd02 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO