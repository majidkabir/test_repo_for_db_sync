SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_640CfmToLoc01                                         */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Confirm To Loc                                                    */
/*                                                                            */
/* Called from: rdtfnc_TM_ClusterPick                                         */
/*                                                                            */
/* Date         Rev  Author   Purposes                                        */
/* 2021-08-19   1.0  James    WMS-17429 Created                               */
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_640CfmToLoc01] (  
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
  
   DECLARE @cur CURSOR
   DECLARE @cGroupKey   NVARCHAR( 10)
   DECLARE @cCartID     NVARCHAR( 20)
   DECLARE @cTaskKey    NVARCHAR( 10)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nQty        INT
   DECLARE @nTranCount  INT
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cCaseID     NVARCHAR( 20)
   DECLARE @cConfirmToLocMoveInventory NVARCHAR( 1)
   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)
   DECLARE @nQTYAlloc   INT
   DECLARE @nQTYPick    INT
   DECLARE @cFromLot    NVARCHAR( 10)
   
   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   SET @cConfirmToLocMoveInventory = rdt.rdtGetConfig( @nFunc, 'ConfirmToLocMoveInventory', @cStorerKey)
   --IF @cUserName = 'james'
   --   SET @cConfirmToLocMoveInventory = '0'
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
   SELECT TaskdetailKey, FromLOC, FromID, ToLoc, Sku, CaseID
   FROM dbo.TASKDETAIL WITH (NOLOCK)
   WHERE Groupkey = @cGroupKey 
   AND   DeviceID = @cCartID 
   AND   [Status] = '5'
   OPEN @cur
   FETCH NEXT FROM @cur INTO @cTaskKey, @cFromLOC, @cFromID, @cToLoc, @cSKU, @cCaseID
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
      
      --IF NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)
      --                WHERE TaskDetailKey = @cTaskKey
      --                AND (Status = '4' OR Status < @cPickConfirmStatus))
      --BEGIN
         IF @cConfirmToLocMoveInventory = '1'
         BEGIN
            SELECT @nQTY = SUM( Qty)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskKey
            AND   STATUS = @cPickConfirmStatus
            
            IF @cPickConfirmStatus = '5'
            BEGIN
               SET @nQTYAlloc = 0
               SET @nQTYPick = @nQTY
            END
            ELSE
            BEGIN
               SET @nQTYAlloc = @nQTY
               SET @nQTYPick = 0
            END
            
            SELECT TOP 1 @cFromLot = LOT
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskKey
            AND   STATUS = @cPickConfirmStatus
            ORDER BY 1
            
            --IF SUSER_SNAME() = 'jameswong'
            --SELECT @cTaskKey '@cTaskKey', @cFromLOC '@cFromLOC', @cFromID '@cFromID', @cToLoc '@cToLoc', @cFromLot '@cFromLot', 
            --@cSKU '@cSKU', @nQty '@nQty', @cCaseID '@cCaseID', @nQTYAlloc '@nQTYAlloc', @nQTYPick '@nQTYPick',
            --@cGroupKey '@cGroupKey', @cCartID '@cCartID'
            -- Move inventory
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT,
               @cSourceType = 'rdt_640CfmToLoc01',
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cToLoc,
               @cFromID     = @cFromID,
               @cToID       = @cFromID,
               @cSKU        = @cSKU,
               @nQTY        = @nQTY,
               @cFromLot    = @cFromLot,
               @nQTYAlloc   = @nQTYAlloc,          
               @nQTYPick    = @nQTYPick,
               @cCaseID     = @cCaseID,
               @nFunc       = @nFunc

      
            IF @nErrNo <> 0
               GOTO RollBackTran
         END
      --END
      
      FETCH NEXT FROM @cur INTO @cTaskKey, @cFromLOC, @cFromID, @cToLoc, @cSKU, @cCaseID
   END
   
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN ConfirmToLoc -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
      --IF @nErrNo <> 0
      --INSERT INTO TRACEINFO (TraceName, TimeIn, Col1, Col2, Col3, Col4) VALUES
      --('123', GETDATE(), @cFromLOC, @cToLoc, @cSKU, @nQTY)
      
Fail:
END  

GO