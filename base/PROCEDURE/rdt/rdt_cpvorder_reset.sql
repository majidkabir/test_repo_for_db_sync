SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_CPVOrder_Reset                                  */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 28-08-2018 1.0  Ung       WMS-5368 Created                           */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_CPVOrder_Reset] (  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,  
   @nInputKey     INT,  
   @cStorerKey    NVARCHAR( 15),   
   @cFacility     NVARCHAR( 5),   
   @cOrderKey     NVARCHAR( 10),  
   @cOption       NVARCHAR( 1) , 
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
        
   DECLARE @nRowRef INT  
   DECLARE @nTranCount INT  
   DECLARE @cPickDetailKey NVARCHAR( 10)  

   DECLARE @curLog CURSOR   
     
   SET @nTranCount = @@TRANCOUNT  
  
   -- Handling transaction  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_Reset -- For rollback or commit only our own transaction  
   
   IF @cOption = '1' 
   BEGIN
      -- Loop log  
      
      SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT RowRef  
         FROM rdt.rdtCPVOrderLog WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
         ORDER BY RowRef  
      OPEN @curLog   
      FETCH NEXT FROM @curLog INTO @nRowRef  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         DELETE rdt.rdtCPVOrderLog WHERE RowRef = @nRowRef  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 128301  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL LOG Fail  
            GOTO RollbackTran  
         END  
         FETCH NEXT FROM @curLog INTO @nRowRef  
      END  
     
      -- Loop PickDetail  
      DECLARE @curPD CURSOR   
      SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT PickDetailKey  
         FROM PickDetail WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
      OPEN @curPD   
      FETCH NEXT FROM @curPD INTO @cPickDetailKey  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         DELETE PickDetail WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 128302  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PKDtl Fail  
            GOTO RollbackTran  
         END  
         FETCH NEXT FROM @curPD INTO @cPickDetailKey  
      END  
   END
   ELSE IF @cOption = '3'
   BEGIN
      -- Loop log
      
      SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT RowRef  
         FROM rdt.rdtCPVOrderLog WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
         ORDER BY RowRef  
      OPEN @curLog   
      FETCH NEXT FROM @curLog INTO @nRowRef  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         DELETE rdt.rdtCPVOrderLog WHERE RowRef = @nRowRef  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 128303  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL LOG Fail  
            GOTO RollbackTran  
         END  
         FETCH NEXT FROM @curLog INTO @nRowRef  
      END  
      
      -- Reset flag  
      UPDATE Orders SET   
         UserDefine10 = '',    
         EditWho = SUSER_SNAME(),   
         EditDate = GETDATE()   
      WHERE OrderKey = @cOrderKey 
      
      IF @@ERROR <> 0  
      BEGIN  
        SET @nErrNo = 128304  
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LOG Fail  
        GOTO RollbackTran  
      END 
      
      
   END
  
   COMMIT TRAN rdt_Reset  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_Reset -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  


GO