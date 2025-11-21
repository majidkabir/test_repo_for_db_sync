SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_JWExtendedUpd04                                 */  
/* Purpose: TM Case Putaway, Extended Update for Jack Will              */  
/*          Release tote from DRP task                                  */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2014-10-01   James     1.0   Created                                 */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_JWExtendedUpd04]  
    @nMobile         INT  
   ,@nFunc           INT  
   ,@cLangCode       NVARCHAR( 3)  
   ,@nStep           INT  
   ,@nInputKey       INT  
   ,@cTaskdetailKey  NVARCHAR( 10)  
   ,@nErrNo          INT           OUTPUT  
   ,@cErrMsg         NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cCaseID         NVARCHAR( 20), 
           @cTransferKey    NVARCHAR( 10), 
           @cRefTaskKey     NVARCHAR( 10)  
           
   -- Handling transaction  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_JWExtendedUpd04 -- For rollback or commit only our own transaction  

   IF NOT EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)  
                   WHERE TaskDetailKey = @cTaskDetailKey
                   AND   [Status] = '9')
      GOTO Quit

   -- TM Case Putaway  
   IF @nFunc = 1762  
   BEGIN  
      IF @nStep = 3 -- ToLOC  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            SELECT @cCaseID = CaseID, @cRefTaskKey = RefTaskKey 
            FROM dbo.TaskDetail WITH (NOLOCK) 
            WHERE TaskDetailKey = @cTaskDetailKey
            AND   [Status] = '9'

            UPDATE UCC WITH (ROWLOCK) SET 
               [Status] = '6'
            WHERE UCCNo = @cCaseID
            AND   [Status] <> '6'
            AND   SourceKey = @cRefTaskKey

            IF @@ERROR <> 0  
            BEGIN  
               SET @cErrMsg = 'UPD UCC FAIL'  
               GOTO RollBackTran  
            END  
         END
      END
   END  
  
   COMMIT TRAN rdt_JWExtendedUpd04 -- Only commit change made here  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_JWExtendedUpd04 -- Only rollback change made here  
Fail:  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO