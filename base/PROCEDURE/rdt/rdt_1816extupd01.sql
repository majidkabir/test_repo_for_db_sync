SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1816ExtUpd01                                    */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Purpose: Validate location type                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2015-03-04   Ung       1.0   SOS332730 Created                       */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1816ExtUpd01]  
    @nMobile         INT   
   ,@nFunc           INT   
   ,@cLangCode       NVARCHAR( 3)   
   ,@nStep           INT   
   ,@nInputKey       INT  
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
  
   DECLARE @cFromLOC NVARCHAR(10)  
   DECLARE @cFromID  NVARCHAR(18)  
  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
     
   -- Get task info  
   SELECT   
      @cFromLOC = FromLOC,   
      @cFromID = FromID  
   FROM TaskDetail WITH (NOLOCK)  
   WHERE TaskDetailKey = @cTaskDetailKey  
  
   -- TM assist NMV  
   IF @nFunc = 1816  
   BEGIN  
      IF @nStep = 1 -- FinalLOC  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            DECLARE @cPickDetailKey NVARCHAR(10)  
            DECLARE @cOrderKey NVARCHAR(10)  
            DECLARE @cLoadKey NVARCHAR(10)  
  
            SET @cOrderKey = ''  
            SET @cLoadKey = ''  
  
            -- Get OrderKey  
            SELECT @cOrderKey = OrderKey  
            FROM PickDetail PD WITH (NOLOCK)  
               JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)  
            WHERE LOC.LOC = @cFromLOC  
               AND ID = @cFromID  
               AND PD.Status = '5'  
              
            -- Get LoadKey  
            SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey   
              
            -- Handling transaction  
            BEGIN TRAN  -- Begin our own transaction  
            SAVE TRAN rdt_1816ExtUpd01 -- For rollback or commit only our own transaction  
              
            -- Drop ID  
            IF EXISTS( SELECT 1 FROM DropID WITH (NOLOCK) WHERE DropID = @cFromID)  
            BEGIN  
               -- Update DropID  
               UPDATE dbo.DropID SET  
                  DropLOC = @cFinalLoc,  
                  LabelPrinted = 'Y',  
                  Status = '5',   
                  LoadKey = @cLoadKey,   
                  EditWho = SUSER_SNAME(),  
                  EditDate = GETDATE(),   
                  Trafficcop = NULL  
               WHERE DropID = @cFromID  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 52253  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD DropIDFail  
                  GOTO RollbackTran  
               END  
            END  
            ELSE  
            BEGIN  
               -- Insert DropID  
               INSERT INTO DropID (DropID, DropLOC, LabelPrinted, Status, LoadKey) VALUES (@cFromID, @cFinalLOC, 'Y', '5', @cLoadKey)  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 52254  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail  
                  GOTO RollbackTran  
               END  
            END  
              
            -- Get PickDetail  
            DECLARE @curPD CURSOR  
            SET @curPD = CURSOR FOR  
               SELECT PickDetailKey   
               FROM PickDetail PD WITH (NOLOCK)  
                  JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)  
               WHERE LOC.LOC = @cFromLOC  
                  AND PD.ID = @cFromID  
                  AND PD.Status = '5'  
  
            -- Loop PickDetail  
            OPEN @curPD  
            FETCH NEXT FROM @curPD INTO @cPickDetailKey  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               -- Update PickDetail  
               UPDATE PickDetail SET  
                  DropID = @cFromID,   
                  EditDate = GETDATE(),   
                  EditWho = SUSER_SNAME(),   
                  TrafficCop = NULL  
               WHERE PickDetailKey = @cPickDetailKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 52255  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                  GOTO RollbackTran  
               END  
               FETCH NEXT FROM @curPD INTO @cPickDetailKey  
            END  
  
            COMMIT TRAN rdt_1816ExtUpd01 -- Only commit change made here  
            GOTO Quit  
         END  
      END  
   END  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_1816ExtUpd01 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO