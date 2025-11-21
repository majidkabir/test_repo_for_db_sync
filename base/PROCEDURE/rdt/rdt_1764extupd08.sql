SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtUpd08                                    */
/* Purpose: TM Replen From, Extended Update for HK Pearson              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-11-02   Ung       1.0   WMS-6906 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764ExtUpd08]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
   ,@cDropID         NVARCHAR( 20) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success   INT
   DECLARE @n_err       INT
   DECLARE @c_errmsg    NVARCHAR( 250)
   DECLARE @nTranCount  INT
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   
   DECLARE @cWaveKey    NVARCHAR( 10)
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cUCC        NVARCHAR( 20)
   DECLARE @cFromLOT    NVARCHAR( 10)
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cToLOC      NVARCHAR( 10)
   DECLARE @cPickMethod NVARCHAR( 10)
   DECLARE @cStatus     NVARCHAR( 10)
   DECLARE @cReasonKey  NVARCHAR( 10)
   DECLARE @cUserKey    NVARCHAR( 10)
   DECLARE @cTaskType   NVARCHAR( 10)
   DECLARE @cTaskKey    NVARCHAR( 10)
   DECLARE @cRefTaskKey NVARCHAR( 10)
   DECLARE @cListKey    NVARCHAR( 10)
   DECLARE @nTaskQTY    INT
   DECLARE @cPickDetailKey  NVARCHAR( 10)
   DECLARE @cLabelGenCode   NVARCHAR( 10)
   DECLARE @nQTY            INT

   DECLARE @curTask     CURSOR
   DECLARE @curPD       CURSOR
   DECLARE @tTask TABLE
   (
      TaskDetailKey NVARCHAR(10)
   )

   SET @nTranCount = @@TRANCOUNT

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         DECLARE @cPickSlipNo NVARCHAR(10)
         DECLARE @cLabelNo    NVARCHAR(20)
         DECLARE @nCartonNo   INT
         DECLARE @fWeight     FLOAT
         DECLARE @fCube       FLOAT

         -- Get task info
         SELECT
            @cWaveKey = WaveKey, 
            @cTaskType = TaskType, 
            @cPickMethod = PickMethod,
            @cStorerKey = StorerKey,
            @cFromID = FromID,
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
         SAVE TRAN rdt_1764ExtUpd08

         -- Loop tasks
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
                  SET @nErrNo = 102305
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END
            END

            FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus
         END

         COMMIT TRAN rdt_1764ExtUpd08 -- Only commit change made here
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764ExtUpd08 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO