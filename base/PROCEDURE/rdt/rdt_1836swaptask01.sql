SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/ 
/* Store procedure: rdt_1836SwapTask01                                  */  
/* Purpose: swap task if user scan different case id than suggested     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2021-02-15   James     1.1   WMS-15659 Created                       */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1836SwapTask01]  
   @nMobile             INT,  
   @nFunc               INT,  
   @cLangCode           NVARCHAR( 3),  
   @nStep               INT,  
   @nInputKey           INT,  
   @cNewCaseID          NVARCHAR( 20),
   @cTaskdetailKey      NVARCHAR( 10),  
   @cNewTaskdetailKey   NVARCHAR( 10)  OUTPUT,
   @nErrNo              INT            OUTPUT,  
   @cErrMsg             NVARCHAR( 20)  OUTPUT  
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
   DECLARE @nQTY              INT 
   DECLARE @cToLoc            NVARCHAR( 20)
   DECLARE @cUserID           NVARCHAR( 20)
   DECLARE @cFromLoc          NVARCHAR( 20)
   DECLARE @cFromID           NVARCHAR( 20)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cAreaKey          NVARCHAR( 20)
     
   SELECT @cUserID = UserName, 
          @cStorerKey = StorerKey
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SELECT @cCaseID = Caseid
   FROM dbo.Taskdetail WITH (NOLOCK)
   WHERE TaskdetailKey = @cTaskdetailKey

   --SET @nTranCount = @@TRANCOUNT  
   --BEGIN TRAN  
   --SAVE TRAN rdt_1836SwapTask01
  
   -- TM Replen From  
   IF @nFunc = 1836  
   BEGIN   
      IF @nStep = 3 -- Case Id   
      BEGIN
         IF @nInputKey = '1'
         BEGIN
            SELECT TOP 1 @cNewTaskDetailKey = TaskDetailKey
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   [Status] IN ('H', '0')
            AND   TaskType = 'ASTRPT'
            AND   Caseid = @cNewCaseID
            ORDER BY 1

            ---- Update taskdetail for new case id
            --UPDATE dbo.TaskDetail SET 
            --   [Status] = '3',
            --   UserKey = @cUserID,
            --   EditWho = SUSER_SNAME(),   
            --   EditDate = GETDATE(),  
            --   Trafficcop = NULL  
            --WHERE Taskdetailkey = @cNewTaskDetailKey

            --IF @@ERROR <> 0
            --BEGIN
            --   SET @nErrNo = 156001  
            --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SwapTask Fail  
            --   GOTO RollBackTran  
            --END

            ---- Update taskdetail for original case id
            --UPDATE dbo.TaskDetail SET 
            --   [Status] = '0',
            --   UserKey = '',
            --   EditWho = SUSER_SNAME(),   
            --   EditDate = GETDATE(),  
            --   Trafficcop = NULL  
            --WHERE Taskdetailkey = @cTaskDetailKey

            --IF @@ERROR <> 0
            --BEGIN
            --   SET @nErrNo = 156002  
            --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SwapTask Fail  
            --   GOTO RollBackTran  
            --END
            
            --UPDATE RDT.RDTMOBREC SET 
            --   V_TaskDetailKey = @cNewTaskDetailKey,
            --   EditDate = GETDATE()
            --WHERE Mobile = @nMobile 

            --IF @@ERROR <> 0
            --BEGIN
            --   SET @nErrNo = 156003  
            --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdMOBREC Fail  
            --   GOTO RollBackTran  
            --END
         END
      END
   END  
  
--   GOTO Quit  
  
--RollBackTran:  
--   ROLLBACK TRAN rdt_1836SwapTask01 -- Only rollback change made here  
Fail:  
--Quit:  
--   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
--      COMMIT TRAN  
END  

GO