SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_TM_ReplenTo_SwapTask                            */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2020-02-14 1.0  James       WMS-11971 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_TM_ReplenTo_SwapTask] (
   @nMobile               INT, 
   @nFunc                 INT, 
   @cLangCode             NVARCHAR( 3),   
   @nStep                 INT, 
   @nInputKey             INT, 
   @cFacility             NVARCHAR( 5), 
   @cStorerKey            NVARCHAR( 15), 
   @cLoc                  NVARCHAR( 18), 
   @cID                   NVARCHAR( 18), 
   @cSKU                  NVARCHAR( 20), 
   @nQty                  INT, 
   @cTaskDetailKey        NVARCHAR( 10), 
   @cType                 NVARCHAR( 10), 
   @tSwapTaskVar          VariableTable READONLY, 
   @cSwapTaskDetailKey    NVARCHAR( 10) OUTPUT, 
   @nErrNo                INT           OUTPUT, 
   @cErrMsg               NVARCHAR( 20) OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @cUserName   NVARCHAR( 20)
   DECLARE @cSwapTaskSP    NVARCHAR( 20)
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)

   -- Get extended ExtendedPltBuildCfmSP
   SET @cSwapTaskSP = rdt.rdtGetConfig( @nFunc, 'SwapTaskSP', @cStorerKey)
   IF @cSwapTaskSP = '0'
      SET @cSwapTaskSP = ''  

   -- Extended putaway
   IF @cSwapTaskSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSwapTaskSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cSwapTaskSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cFromLoc, @cID, @cSKU, @nQty, @cTaskDetailKey, @cType, @tSwapTaskVar, ' +
            ' @cSwapTaskDetailKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
         SET @cSQLParam =
            '@nMobile               INT, ' +  
            '@nFunc                 INT, ' +  
            '@cLangCode             NVARCHAR( 3),  ' +  
            '@nStep                 INT,           ' +
            '@nInputKey             INT,           ' +
            '@cFacility             NVARCHAR( 5),  ' +  
            '@cStorerKey            NVARCHAR( 15), ' +  
            '@cLoc                  NVARCHAR( 18), ' +
            '@cID                   NVARCHAR( 18), ' +  
            '@cSKU                  NVARCHAR( 20), ' +
            '@nQty                  INT,           ' +
            '@cTaskDetailKey        NVARCHAR( 10), ' +  
            '@cType                 NVARCHAR( 10), ' +
            '@tSwapTaskVar          VariableTable READONLY, ' +
            '@cSwapTaskDetailKey    NVARCHAR( 10) OUTPUT, ' +
            '@nErrNo                INT           OUTPUT, ' +  
            '@cErrMsg               NVARCHAR( 20) OUTPUT'  

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cLoc, @cID, @cSKU, @nQty, @cTaskDetailKey, @cType, @tSwapTaskVar, 
            @cSwapTaskDetailKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     

         IF @nErrNo <> 0
            GOTO Fail
      END
   END
   ELSE
   BEGIN
      SELECT @cUserName = UserName
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile
   
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_TM_ReplenTo_SwapTask -- For rollback or commit only our own transaction

      IF @cType = 'ID'
      BEGIN
         SELECT TOP 1 @cSwapTaskDetailKey = TaskDetailKey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
         WHERE TaskType = 'RPT'  
         AND FromID = @cID  
         AND FromLoc = @cLoc  
         AND Status = '0'  

         IF ISNULL(@cSwapTaskDetailKey,'')  = ''  
         BEGIN  
            SET @nErrNo = 148251  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidSwapID  
            GOTO RollBackTran  
         END  
  
         -- LOCK NEW ID Records  
         UPDATE TaskDetail SET
            [STATUS] = '3'  
           ,[UserKey] = @cUserName  
           ,[ReasonKey] = ''  
           ,[EditDate] = GetDate()  
           ,[EditWho]  = sUSER_sNAME()  
           ,[TrafficCop] = NULL  
         WHERE TaskDetailKey = @cSwapTaskDetailKey
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 148252  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDetFail  
            GOTO RollBackTran  
         END  
  
         -- RLEASE Current ID Records  
         UPDATE TaskDetail SET
            [STATUS] = '0'  
           ,[UserKey] = ''  
           ,[ReasonKey] = ''  
           ,[EditDate] = GetDate()  
           ,[EditWho]  = sUSER_sNAME()  
           ,[TrafficCop] = NULL  
         WHERE TaskDetailKey = @cTaskDetailKey
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 148253  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDetFail  
            GOTO RollBackTran  
         END  
      END   -- ID
   
      IF @cType = 'SKU'
      BEGIN
         -- Enter SKU <> Suggested SKU, 
         -- go taskdetail to retrieve the desired SKU to work on  
         SELECT TOP 1 @cSwapTaskDetailKey = TaskDetailKey  
         FROM dbo.TaskDetail WITH (NOLOCK)  
         WHERE TaskType = 'RPT'  
         AND   FromID = @cID  
         AND   FromLoc = @cLoc  
         AND   SKU = @cSKU
         AND  [Status] = '3'  
 
         IF ISNULL(@cSwapTaskDetailKey,'')  = ''  
         BEGIN  
            SET @nErrNo = 148254  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidSwapSKU  
            GOTO RollBackTran  
         END  
  /*
         -- Lock new task  
         UPDATE TaskDetail SET
            [STATUS] = '3'  
           ,[UserKey] = @cUserName  
           ,[ReasonKey] = ''  
           ,[EditDate] = GetDate()  
           ,[EditWho]  = sUSER_sNAME()  
           ,[TrafficCop] = NULL  
         WHERE TaskDetailKey = @cSwapTaskDetailKey
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 148255  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LockNewTaskErr  
            GOTO RollBackTran  
         END  
  
         -- Release currect locked task  
         UPDATE TaskDetail SET
            [STATUS] = '0'  
           ,[UserKey] = ''  
           ,[ReasonKey] = ''  
           ,[EditDate] = GetDate()  
           ,[EditWho]  = sUSER_sNAME()  
           ,[TrafficCop] = NULL  
         WHERE TaskDetailKey = @cTaskDetailKey
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 148256  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReleaseTaskErr  
            GOTO RollBackTran  
         END  
  */
      END   -- SKU

      COMMIT TRAN rdt_TM_ReplenTo_SwapTask
      GOTO Quit

      RollBackTran:
         ROLLBACK TRAN rdt_TM_ReplenTo_SwapTask -- Only rollback change made here
      Quit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
   END
   
   Fail:
END

GO