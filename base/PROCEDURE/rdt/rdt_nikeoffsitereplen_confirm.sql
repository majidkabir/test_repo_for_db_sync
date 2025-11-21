SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_NIKEOffSiteReplen_Confirm                             */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2023-04-26 1.0  Ung      WMS-22246 Based on rdt_1764SwapUCC08              */ 
/******************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_NIKEOffSiteReplen_Confirm] (
   @nMobile    INT, 
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3),
   @nStep      INT, 
   @nInputKey  INT, 
   @cFacility  NVARCHAR( 5),
   @cStorerKey NVARCHAR( 15),
   @cWaveKey   NVARCHAR( 10), 
   @cPickZone  NVARCHAR( 10), 
   @cToArea    NVARCHAR( 10), 
   @cDropID    NVARCHAR( 20), 
   @cUCCNo     NVARCHAR( 20), 
   @nErrNo     INT           OUTPUT, 
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   
   DECLARE @cTaskDetailKey NVARCHAR( 10) = ''
   DECLARE @cTransitLOC    NVARCHAR( 10)
   DECLARE @cFromID        NVARCHAR( 18)
   DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cToID          NVARCHAR( 18)
   DECLARE @cCaseID        NVARCHAR( 20)

   DECLARE @cUCCSKU        NVARCHAR( 20)
   DECLARE @cUCCLOC        NVARCHAR( 10)
   DECLARE @cUCCID         NVARCHAR( 18)
   DECLARE @nUCCQTY        INT

   DECLARE @cSwapUCCSP NVARCHAR( 20)
   SET @cSwapUCCSP = rdt.RDTGetConfig( @nFunc, 'SwapUCCSP', @cStorerKey)
   IF @cSwapUCCSP = '0'
      SET @cSwapUCCSP = ''

   -- Get UCC info
   SELECT 
      @cUCCSKU = SKU, 
      @nUCCQTY = QTY,
      @cUCCLOC = LOC,
      @cUCCID = ID 
   FROM dbo.UCC WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND UCCNo = @cUCCNo 
      AND Status IN ('1', '3')

   -- Find task
   SELECT TOP 1 
      @cTaskDetailKey = TaskDetailKey, 
      @cTransitLOC = TransitLOC, 
      @cFromID = FromID, 
      @cToLOC = ToLOC, 
      @cToID = ToID, 
      @cCaseID = CaseID
   FROM dbo.TaskDetail TD WITH (NOLOCK) 
      JOIN dbo.LOC FromLOC WITH (NOLOCK) ON (TD.FromLOC = FromLOC.LOC)
      JOIN dbo.LOC ToLOC WITH (NOLOCK) ON (TD.ToLOC = ToLOC.LOC)
      JOIN dbo.PickZone ToPicKZone WITH (NOLOCK) ON (ToLOC.PickZone = ToPicKZone.PickZone)
   WHERE TD.StorerKey = @cStorerKey
      AND TD.WaveKey = @cWaveKey
      AND TD.TaskType = 'RPF'
      AND TD.Status = '0'
      AND FromLOC.PickZone = @cPickZone
      AND ToPickZone.InLOC = @cToArea
      AND TD.FromLOC = @cUCCLOC
      AND TD.FromID = @cUCCID
      AND TD.SKU = @cUCCSKU
      AND TD.QTY = @nUCCQTY
   ORDER BY
      CASE WHEN TD.CaseID = @cUCCNo THEN 1 ELSE 2 END -- Exact match
   
   -- Check no task
   IF @cTaskDetailKey = ''
   BEGIN
      SET @nErrNo = 200001
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No swap task
      GOTO Quit
   END

   -- Check no swap
   IF @cCaseID <> @cUCCNo AND @cSwapUCCSP = ''
   BEGIN
      SET @nErrNo = 200002
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickExactUCC
      GOTO Quit
   END

   -- Get transit LOC
   IF @cTransitLOC = ''
   BEGIN
      SET @nErrNo = 0
      EXECUTE rdt.rdt_GetTransitLOC01
           '' -- @c_UserID
         , @cStorerKey
         , @cUCCSKU
         , @nUCCQTY
         , @cUCCLOC
         , @cUCCID
         , @cToLOC
         , 0             -- Lock PND transit LOC. 1=Yes, 0=No
         , @cTransitLOC OUTPUT
         , @nErrNo      OUTPUT
         , @cErrMsg     OUTPUT
         , @nFunc = @nFunc
      IF @nErrNo <> 0
         GOTO Quit
   END

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN 
   SAVE TRAN rdt_NIKEOffSiteReplen

   -- Take the task
   IF @cTransitLOC = @cToLOC
      UPDATE TaskDetail WITH (ROWLOCK) SET
          Status     = '3'
         ,UserKey    = SUSER_SNAME()
         ,ReasonKey  = ''
         -- ,ListKey    = CASE WHEN ListKey = '' THEN @cTaskDetailKey ELSE ListKey END
         ,StartTime  = CURRENT_TIMESTAMP
         ,EditDate   = CURRENT_TIMESTAMP
         ,EditWho    = SUSER_SNAME()
         ,TrafficCop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
         AND Status IN ('0')
   ELSE
      UPDATE TaskDetail WITH (ROWLOCK) SET
          Status     = '3'
         ,UserKey    = SUSER_SNAME()
         ,ReasonKey  = ''
         ,TransitLOC = @cTransitLOC
         ,FinalLOC   = @cToLOC
         ,FinalID    = @cToID
         ,ToLOC      = @cTransitLOC
         ,ToID       = @cFromID
         -- ,ListKey    = CASE WHEN ListKey = '' THEN @cTaskDetailKey ELSE ListKey END
         ,StartTime  = CURRENT_TIMESTAMP
         ,EditDate   = CURRENT_TIMESTAMP
         ,EditWho    = SUSER_SNAME()
         ,TrafficCop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
         AND Status IN ('0')

   IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
   BEGIN
      SET @nErrNo = 200003
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDetFail
      GOTO RollbackTran
   END

   -- Swap UCC (must be same FromLOC, FromID, SKU, QTY)
   IF @cSwapUCCSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSwapUCCSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cSwapUCCSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cBarcode, ' +
            ' @cSKU OUTPUT, @cUCC OUTPUT, @nUCCQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile            INT,           ' +
            '@nFunc              INT,           ' +
            '@cLangCode          NVARCHAR( 3),  ' +
            '@nStep              INT,           ' +  
            '@nInputKey          INT,           ' + 
            '@cTaskdetailKey     NVARCHAR( 10), ' +
            '@cBarcode           NVARCHAR( 60), ' +
            '@cSKU               NVARCHAR( 20)  OUTPUT, ' +
            '@cUCC               NVARCHAR( 20)  OUTPUT, ' +
            '@nUCCQTY            INT            OUTPUT, ' +
            '@nErrNo             INT            OUTPUT, ' +
            '@cErrMsg            NVARCHAR( 20)  OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cUCCNo, 
            @cUCCSKU OUTPUT, @cUCCNo OUTPUT, @nUCCQTY OUTPUT,  @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO RollBackTran
      END
   END

   -- Mark UCC scanned
   INSERT INTO rdt.rdtRPFLog (TaskDetailKey, DropID, UCCNo, QTY) VALUES (@cTaskDetailKey, @cDropID, @cUCCNo, @nUCCQTY)
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 200004
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RPFLogFail
      GOTO Quit
   END
   
   -- Get task info
   DECLARE @cListKey NVARCHAR(10) = ''
   SELECT TOP 1 
      @cListKey = ListKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND TaskType = 'RPF'
      AND DropID = @cDropID
      AND Status = '5'
   
   IF @cListKey = '' 
      SET @cListKey = @cTaskDetailKey
   
   -- Update Task
   UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
      ListKey = @cListKey, 
      Status = '5', -- Picked
      DropID = @cDropID, 
      ToID = @cDropID, -- CASE WHEN PickMethod = 'PP' THEN @cDropID ELSE ToID END, 
      -- QTY = @nQTY,
      -- SystemQTY = @nSystemQTY, 
      -- ReasonKey = @cReasonKey, 
      EndTime = GETDATE(),
      EditDate = GETDATE(),
      EditWho  = SUSER_SNAME(), 
      Trafficcop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 200005
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskdetFail
      GOTO RollBackTran
   END
   
   COMMIT TRAN rdt_NIKEOffSiteReplen
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_NIKEOffSiteReplen
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO