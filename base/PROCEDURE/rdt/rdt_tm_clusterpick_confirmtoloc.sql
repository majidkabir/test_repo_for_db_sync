SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_TM_ClusterPick_ConfirmToLoc                           */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2020-06-18 1.0  James      WMS-12055 Created                               */  
/* 2021-08-19 1.1  James      WMS-17429 Fix confirm sp structure (james01)    */
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_TM_ClusterPick_ConfirmToLoc] (  
    @nMobile         INT,  
    @nFunc           INT,  
    @cLangCode       NVARCHAR( 3),  
    @nStep           INT,  
    @nInputKey       INT,  
    @cFacility       NVARCHAR( 5),  
    @cStorerKey      NVARCHAR( 15),  
    @cTaskDetailKey  NVARCHAR( 10),  
    @cToLOC          NVARCHAR( 10),  
    @tConfirm        VARIABLETABLE READONLY,
    @nErrNo          INT           OUTPUT,  
    @cErrMsg         NVARCHAR(250) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cSQL        NVARCHAR( MAX)  
   DECLARE @cSQLParam   NVARCHAR( MAX)  
   DECLARE @nTranCount  INT  
   DECLARE @cConfirmToLocSP  NVARCHAR( 20)  
  
   -- Get storer config  
   SET @cConfirmToLocSP = rdt.RDTGetConfig( @nFunc, 'ConfirmToLocSP', @cStorerKey)  
   IF @cConfirmToLocSP = '0'  
      SET @cConfirmToLocSP = ''  
  
   /***********************************************************************************************  
                                              Custom confirm  
   ***********************************************************************************************/  
   -- Check confirm SP blank  
   IF @cConfirmToLocSP <> ''  
   BEGIN  
      -- Confirm SP  
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmToLocSP) +  
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskDetailKey, @cToLOC, ' +  
         ' @tConfirm, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
      SET @cSQLParam =  
         ' @nMobile        INT,           ' +  
         ' @nFunc          INT,           ' +  
         ' @cLangCode      NVARCHAR( 3),  ' +  
         ' @nStep          INT,           ' +  
         ' @nInputKey      INT,           ' +  
         ' @cFacility      NVARCHAR( 5) , ' +  
         ' @cStorerKey     NVARCHAR( 15), ' +  
         ' @cTaskDetailKey NVARCHAR( 10), ' +  
         ' @cToLOC         NVARCHAR( 10), ' +
         ' @tConfirm       VARIABLETABLE READONLY, ' +
         ' @nErrNo         INT           OUTPUT, ' +  
         ' @cErrMsg        NVARCHAR(250) OUTPUT  '  
  
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskDetailKey, @cToLOC,
         @tConfirm, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
      GOTO Quit  
   END  
  
   /***********************************************************************************************  
                                              Standard confirm  
   ***********************************************************************************************/  
   DECLARE @cur CURSOR
   DECLARE @cGroupKey   NVARCHAR( 10)
   DECLARE @cCartID     NVARCHAR( 20)
   DECLARE @cTaskKey    NVARCHAR( 10)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nQty        INT
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cCaseID     NVARCHAR( 20)
    
   
   SELECT TOP 1 
      @cGroupKey = Groupkey,
      @cCartID = DeviceID
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   ORDER BY 1
   
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_TM_ClusterPick_ConfirmToLoc -- For rollback or commit only our own transaction  

   SET @cur = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT TaskdetailKey, FromLOC, FromID, Sku, Qty, CaseID
   FROM dbo.TASKDETAIL WITH (NOLOCK)
   WHERE Groupkey = @cGroupKey 
   AND   DeviceID = @cCartID 
   AND   [Status] = '5'
   OPEN @cur
   FETCH NEXT FROM @cur INTO @cTaskKey, @cFromLOC, @cFromID, @cSKU, @nQty, @cCaseID
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE dbo.TaskDetail SET 
         FinalLOC = @cToLoc,
         [Status] = '9',
         EditWho = SUSER_SNAME(),
         EditDate = GETDATE()
      WHERE TaskDetailKey = @cTaskKey 

      IF @@ERROR <> 0 OR @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 156801  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Confirm Fail  
         GOTO RollBackTran  
      END

      FETCH NEXT FROM @cur INTO @cTaskKey, @cFromLOC, @cFromID, @cSKU, @nQty, @cCaseID
   END
   
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_TM_ClusterPick_ConfirmToLoc -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  

Fail:
END  

GO