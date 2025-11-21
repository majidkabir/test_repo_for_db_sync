SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_741ExtUpd01                                     */  
/* Purpose: Unbook RFPutaway                                            */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2019-11-07 1.0  James     WMS11033. Created                          */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_741ExtUpd01] (  
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT, 
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cTrolleyNo      NVARCHAR( 5),  
   @cUCC            NVARCHAR( 20), 
   @nQty            INT,           
   @cSuggestedLOC   NVARCHAR( 10), 
   @tExtUpdVar      VariableTable READONLY,
   @nErrNo          INT           OUTPUT,  
   @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  

SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cTaskDetailKey    NVARCHAR( 10)
   DECLARE @nTranCount        INT
   DECLARE @nPABookingKey     INT = 0
   
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_741ExtUpd01

   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 4
      BEGIN
         DECLARE @curPD CURSOR
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT TaskDetailKey
         FROM dbo.TaskDetail AS td WITH (NOLOCK)
         WHERE td.Storerkey = @cStorerKey 
         AND   td.Caseid = @cUCC
         AND   EXISTS ( SELECT 1 FROM dbo.RFPUTAWAY AS r WITH (NOLOCK) WHERE td.TaskDetailKey = r.TaskDetailKey)
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cTaskDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @nErrNo = 0
            -- Unlock  suggested location
            EXEC rdt.rdt_Putaway_PendingMoveIn 
               @cUserName     = '',
               @cType         = 'UNLOCK',      -- LOCK / UNLOCK
               @cFromLOC      = '',
               @cFromID       = '',
               @cSuggestedLOC = '',
               @cStorerKey    = '',
               @nErrNo        = @nErrNo    OUTPUT,
               @cErrMsg       = @cErrMsg  OUTPUT, 
               @cSKU          = '',
               @nPutawayQTY   = 0,
               @cUCCNo        = '', 
               @cFromLOT      = '', 
               @cToID         = '', 
               @cTaskDetailKey= @cTaskDetailKey, 
               @nFunc         = @nFunc, 
               @nPABookingKey = @nPABookingKey OUTPUT, 
               @cMoveQTYAlloc = '',
               @cMoveQTYPick  = ''

            IF @nErrNo <> 0
               GOTO RollBackTran
               
            FETCH NEXT FROM @curPD INTO @cTaskDetailKey
         END
      END
   END
    
   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_741ExtUpd01
   Quit:         
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN
 

GO