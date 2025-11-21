SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_TM_Assist_Putaway_Confirm                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2019-09-12  1.0  Ung      WMS-10452 Add override LOC                 */
/* 2020-08-01  1.1  YeeKung  WMS-14344 Add CustomSP(yeekung01)          */
/************************************************************************/

CREATE PROC [RDT].[rdt_TM_Assist_Putaway_Confirm] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cTaskDetailKey   NVARCHAR( 10), 
   @cFromLOC         NVARCHAR( 10), 
   @cFromID          NVARCHAR( 18), 
   @cSuggLOC         NVARCHAR( 10), 
   @cPickAndDropLOC  NVARCHAR( 10), 
   @cToLOC           NVARCHAR( 10), 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cToID       NVARCHAR( 18),
           @cConfirmSP  NVARCHAR( 20),
           @cSQL        NVARCHAR( MAX),   
           @cSQLParam   NVARCHAR( MAX)  

   -- Get storer config  
   SET @cConfirmSP = rdt.rdtGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)  
   IF @cConfirmSP = '0'  
      SET @cConfirmSP = ''  

   /***********************************************************************************************  
                                          Custom confirm  
   ***********************************************************************************************/  
   IF @cConfirmSP <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +  
            ' @nMobile,@nFunc,@cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,@cTaskDetailKey,@cFromLOC,'+
            '@cFromID,@cSuggLOC,@cPickAndDropLOC,@cToLOC,@nErrNo OUTPUT,@cErrMsg   OUTPUT '
         SET @cSQLParam =  
            ' @nMobile          INT,                  '+
            ' @nFunc            INT,                  '+
            ' @cLangCode        NVARCHAR( 3),         '+
            ' @nStep            INT,                  '+
            ' @nInputKey        INT,                  '+
            ' @cStorerKey       NVARCHAR( 15),        '+
            ' @cFacility        NVARCHAR( 5),         '+
            ' @cTaskDetailKey   NVARCHAR( 10),        '+
            ' @cFromLOC         NVARCHAR( 10),        '+
            ' @cFromID          NVARCHAR( 18),        '+
            ' @cSuggLOC         NVARCHAR( 10),        '+
            ' @cPickAndDropLOC  NVARCHAR( 10),        '+
            ' @cToLOC           NVARCHAR( 10),        '+
            ' @nErrNo           INT           OUTPUT, '+
            ' @cErrMsg          NVARCHAR( 20) OUTPUT  '             
  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
           @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,@cTaskDetailKey,@cFromLOC,
           @cFromID,@cSuggLOC,@cPickAndDropLOC,@cToLOC,@nErrNo OUTPUT,@cErrMsg   OUTPUT   
  
         GOTO Quit  
      END  
   END  
  
   /***********************************************************************************************  
                                          Standard confirm   
   ***********************************************************************************************/  

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get LoseID
   DECLARE @cLoseID NVARCHAR(1)
   SELECT @cLoseID = @cLoseID FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLOC
   IF @cLoseID = '1'
      SET @cToID = ''
   ELSE
      SET @cToID = @cFromID

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TM_Assist_Putaway_Confirm -- For rollback or commit only our own transaction

   -- Execute move process
   EXECUTE rdt.rdt_Move
      @nMobile     = @nMobile,
      @cLangCode   = @cLangCode, 
      @nErrNo      = @nErrNo  OUTPUT,
      @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
      @cSourceType = 'rdt_TM_Assist_Putaway_Confirm', 
      @cStorerKey  = @cStorerKey,
      @cFacility   = @cFacility, 
      @cFromLOC    = @cFromLOC, 
      @cToLOC      = @cToLOC, 
      @cFromID     = @cFromID, 
      @cToID       = NULL,  -- NULL means not changing ID
      @nFunc       = @nFunc
   IF @nErrNo <> 0
      GOTO RollBackTran

   IF @cPickAndDropLOC <> ''
      SET @cSuggLOC = @cPickAndDropLOC

   -- Unlock SuggestedLOC
   EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK' 
      ,''        --@cLOC      
      ,@cToID    --@cID       
      ,@cSuggLOC --@cSuggLOC 
      ,''        --@cStorerKey
      ,@nErrNo  OUTPUT
      ,@cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

   -- Update task
   UPDATE dbo.TaskDetail SET
      Status = '9',
      ToLOC = @cSuggLOC,
      UserKey = SUSER_SNAME(),
      EditWho = SUSER_SNAME(),
      EditDate = GETDATE(), 
      Trafficcop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 143851
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
      GOTO RollBackTran
   END

   COMMIT TRAN rdt_TM_Assist_Putaway_Confirm -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TM_Assist_Putaway_Confirm -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO