SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/    
/* Store procedure: rdt_TM_Assist_ClusterPick_ConfirmToLoc                       */    
/* Copyright      : LF Logistics                                                 */    
/*                                                                               */    
/* Purpose: Confirm To Loc                                                       */  
/*                                                                               */  
/* Called from: rdtfnc_TM_Assist_ClusterPick                                     */  
/*                                                                               */  
/* Date         Rev  Author   Purposes                                           */  
/* 2020-07-26   1.0  James    WMS-17335 Created                                  */
/* 2024-12-17   1.1  JCH507   UWP-28528 Donot move inventory when task qty = 0   */  
/*********************************************************************************/    
    
CREATE PROC rdt.rdt_TM_Assist_ClusterPick_ConfirmToLoc (    
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
   DECLARE @cDropID     NVARCHAR( 20)  
   DECLARE @cConfirmToLocMoveInventory NVARCHAR( 1)  
   DECLARE @cUserName   NVARCHAR( 18)  
     
   SELECT @cUserName = UserName  
   FROM rdt.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
     
   SET @cConfirmToLocMoveInventory = rdt.rdtGetConfig( @nFunc, 'ConfirmToLocMoveInventory', @cStorerKey)  

   SELECT TOP 1   
      @cGroupKey = Groupkey,  
      @cCartID = DeviceID  
   FROM dbo.TaskDetail WITH (NOLOCK)  
   WHERE TaskDetailKey = @cTaskDetailKey  
   ORDER BY 1  
     
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
   SAVE TRAN ConfirmToLoc -- For rollback or commit only our own transaction    
  
   SET @cur = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
   SELECT TaskdetailKey, FromLOC, FromID, Sku, Qty, DropID  
   FROM dbo.TASKDETAIL WITH (NOLOCK)  
   WHERE Groupkey = @cGroupKey   
   AND   DeviceID = @cCartID   
   AND   [Status] = '5'  
   OPEN @cur  
   FETCH NEXT FROM @cur INTO @cTaskKey, @cFromLOC, @cFromID, @cSKU, @nQty, @cDropID  
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
         SET @nErrNo = 171901    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Confirm Fail    
         GOTO RollBackTran    
      END  
        
      IF @cConfirmToLocMoveInventory = '1'  
      BEGIN  
         -- Move inventory
         IF @nQty > 0 --V1.1
         BEGIN
            EXECUTE rdt.rdt_Move  
               @nMobile     = @nMobile,  
               @cLangCode   = @cLangCode,  
               @nErrNo      = @nErrNo  OUTPUT,  
               @cErrMsg     = @cErrMsg OUTPUT,  
               @cSourceType = 'ASTCPK_ConfirmToLoc',  
               @cStorerKey  = @cStorerKey,  
               @cFacility   = @cFacility,  
               @cFromLOC    = @cFromLOC,  
               @cToLOC      = @cToLoc,  
               @cFromID     = @cFromID,  
               @cToID       = @cFromID,  
               @cSKU        = @cSKU,  
               @nQTY        = @nQTY,  
               @nQTYPick    = @nQTY,  
               @cDropID     = @cDropID,  
               @nFunc       = @nFunc  
         
            IF @nErrNo <> 0  
               GOTO RollBackTran
         END --Qty > 0 --V1.1 
      END  
  
      FETCH NEXT FROM @cur INTO @cTaskKey, @cFromLOC, @cFromID, @cSKU, @nQty, @cDropID  
   END  
     
    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN ConfirmToLoc -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
        
Fail:  
END    

GO