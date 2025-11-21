SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_TM_NMVFrom_CreateNextTask                             */
/*                                                                            */
/* Purpose: Generate next task, if current putaway is transit                 */
/*                                                                            */
/* Modifications log:                                                         */
/* Date        Rev  Author    Purposes                                        */
/* 07-05-2014  1.0  Ung       SOS309834. Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_TM_NMVFrom_CreateNextTask] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @cUserName      NVARCHAR( 15), 
   @cTaskDetailKey NVARCHAR( 10),
   @cFinalLOC      NVARCHAR( 10), 
   @nErrNo         INT          OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
   DECLARE @nSuccess          INT
   DECLARE @nTransitCount     INT
   DECLARE @cNewTaskDetailKey NVARCHAR( 10)

   DECLARE @cPickMethod NVARCHAR( 10)
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cToLOC      NVARCHAR( 10)
   DECLARE @cToID       NVARCHAR( 18)
   DECLARE @cListKey    NVARCHAR( 10)
   DECLARE @cChildID    NVARCHAR( 20)
   DECLARE @cFinalID    NVARCHAR( 18)
   DECLARE @cPriority   NVARCHAR( 10)
   DECLARE @cSourcePriority NVARCHAR( 10)
   DECLARE @cSourceType     NVARCHAR( 30)
   
   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get task info
   SELECT 
      @cListKey      = ListKey, 
      @cStorerKey    = Storerkey,
      @cToLOC        = ToLOC, 
      @cToID         = ToID, 
      @cPickMethod   = PickMethod, 
      @nTransitCount = TransitCount, 
      @cPriority     = Priority, 
      @cSourcePriority = SourcePriority, 
      @cSourceType     = 'rdt_TM_NMVFrom_CreateTask'
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskdetailKey

   -- Get new TaskDetailKey
	SET @nSuccess = 1
	EXECUTE dbo.nspg_getkey
		'TASKDETAILKEY'
		, 10
		, @cNewTaskDetailKey OUTPUT
		, @nSuccess          OUTPUT
		, @nErrNo            OUTPUT
		, @cErrMsg           OUTPUT
   IF @nSuccess <> 1
   BEGIN
      SET @nErrNo = 88051
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
      GOTO Fail
   END
   
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TM_NMVFrom_CreateTask -- For rollback or commit only our own transaction

   SET @nTransitCount = @nTransitCount + 1

   -- Insert final task
   INSERT INTO TaskDetail (
      TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, 
      PickMethod, StorerKey, ListKey, TransitCount, SourceType, Priority, SourcePriority, TrafficCop)
   VALUES (
      @cNewTaskDetailKey, 'NM1', '0', '', @cToLOC, @cToID, @cFinalLOC, @cToID, 
      @cPickMethod, @cStorerKey, @cListKey, @nTransitCount, @cSourceType, @cPriority, @cSourcePriority, NULL)
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 88052
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
      GOTO RollBackTran
   END

   COMMIT TRAN rdt_TM_NMVFrom_CreateTask -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TM_NMVFrom_CreateTask -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO