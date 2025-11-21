SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_TM_Assist_ReplenTo_Confirm                            */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2019-08-13   Ung       1.0   WMS-10166 Created                             */
/* 2019-10-10   Ung       1.1   WMS-10698 Fix PendingMoveIn unlock by UCC     */
/*                              Add ConfirmSP                                 */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_TM_Assist_ReplenTo_Confirm]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cFinalLOC       NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   DECLARE @cSQL       NVARCHAR(MAX)
   DECLARE @cSQLParam  NVARCHAR(MAX)
   DECLARE @cConfirmSP NVARCHAR(20)

   -- Get storer config
   SET @cConfirmSP = rdt.rdtGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''

   SET @nTranCount = @@TRANCOUNT
   
   /***********************************************************************************************
                                          Custom confirm
   ***********************************************************************************************/
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskDetailKey, @cFinalLOC, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' + 
            ' @nFunc          INT,           ' + 
            ' @cLangCode      NVARCHAR( 3),  ' + 
            ' @nStep          INT,           ' + 
            ' @nInputKey      INT,           ' + 
            ' @cFacility      NVARCHAR( 5),  ' + 
            ' @cStorerKey     NVARCHAR( 15), ' + 
            ' @cTaskDetailKey NVARCHAR( 10), ' + 
            ' @cFinalLOC      NVARCHAR( 20), ' + 
            ' @nErrNo         INT           OUTPUT, ' + 
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskDetailKey, @cFinalLOC,   
            @nErrNo OUTPUT, @cErrMsg OUTPUT 

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                          Standard confirm 
   ***********************************************************************************************/
   DECLARE @cFromLOC NVARCHAR(10)
   DECLARE @cFromID  NVARCHAR(18)
   DECLARE @cCaseID  NVARCHAR(20)

   -- Get task info
   SELECT 
      @cFromLOC = FromLOC, 
      @cFromID = FromID, 
      @cCaseID = CaseID
   FROM TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TM_Assist_ReplenTo_Confirm -- For rollback or commit only our own transaction

   -- Move by UCC
   EXECUTE rdt.rdt_Move
      @nMobile     = @nMobile,
      @cLangCode   = @cLangCode, 
      @nErrNo      = @nErrNo  OUTPUT,
      @cErrMsg     = @cErrMsg OUTPUT,
      @cSourceType = 'rdt_TM_Assist_ReplenTo_Confirm', 
      @cStorerKey  = @cStorerKey,
      @cFacility   = @cFacility, 
      @cFromLOC    = @cFromLOC, 
      @cFromID     = @cFromID,  
      @cToLOC      = @cFinalLoc, 
      @cUCC        = @cCaseID, 
      @cToID       = NULL,  -- NULL means not changing ID
      @nFunc       = @nFunc 
   IF @nErrNo <> 0
      GOTO RollbackTran

   -- Unlock by ASTRPT task  
   EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
      ,'' --FromLOC  
      ,'' --FromID  
      ,'' --SuggLOC  
      ,@cStorerKey --Storer  
      ,@nErrNo  OUTPUT  
      ,@cErrMsg OUTPUT  
      ,@cUCCNo = @cCaseID  
   IF @nErrNo <> 0
      GOTO RollbackTran
   
   -- Update task
   UPDATE dbo.TaskDetail SET
      Status = '9',
      ToLOC = @cFinalLoc,
      UserKey = SUSER_SNAME(),
      EditWho = SUSER_SNAME(),
      EditDate = GETDATE(), 
      Trafficcop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 143001
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
      GOTO RollbackTran
   END

   COMMIT TRAN rdt_TM_Assist_ReplenTo_Confirm -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TM_Assist_ReplenTo_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO