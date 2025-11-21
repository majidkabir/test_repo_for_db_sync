SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_808ExtUpd01                                     */    
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Purpose: Extended update                                             */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */    
/* 25-May-2015 1.0  Ung         SOS336312 Created                       */    
/* 30-Mar-2021 1.1  James       WMS-16553 Add scan-in (james01)         */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_808ExtUpd01] (    
    @nMobile    INT    
   ,@nFunc      INT    
   ,@cLangCode  NVARCHAR( 3)    
   ,@nStep      INT    
   ,@nInputKey  INT    
   ,@cFacility  NVARCHAR( 5)    
   ,@cStorerKey NVARCHAR( 15)    
   ,@cLight     NVARCHAR( 1)     
   ,@cDPLKey    NVARCHAR( 10)    
   ,@cCartID    NVARCHAR( 10)    
   ,@cPickZone  NVARCHAR( 10)    
   ,@cMethod    NVARCHAR( 10)    
   ,@cLOC       NVARCHAR( 10)    
   ,@cSKU       NVARCHAR( 20)    
   ,@cToteID    NVARCHAR( 20)    
   ,@nQTY       INT          
   ,@cNewToteID NVARCHAR( 20)    
   ,@nErrNo     INT            OUTPUT    
   ,@cErrMsg    NVARCHAR( 20)  OUTPUT    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @cActToteID  NVARCHAR(20)    
   DECLARE @cOrderKey   NVARCHAR(10)    
   DECLARE @cLoadKey    NVARCHAR(10)    
   DECLARE @cPickSlipNo NVARCHAR(10)    
   DECLARE @cUserName   NVARCHAR( 18)
   
   SELECT @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Transaction at order level    
   DECLARE @nTranCount INT    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
   SAVE TRAN rdt_808ExtUpd01 -- For rollback or commit only our own transaction             
    
   IF @nFunc = 808 -- PTLCart    
   BEGIN    
      IF @nStep = 2 -- Dynamic assign    
      BEGIN    
         -- Create DropID    
         DECLARE @curOrder CURSOR    
         SET @curOrder = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT ToteID, OrderKey    
            FROM rdt.rdtPTLCartLog WITH (NOLOCK)     
            WHERE CartID = @cCartID     
               AND OrderKey <> ''    
         OPEN @curOrder    
         FETCH NEXT FROM @curOrder INTO @cActToteID, @cOrderKey    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
            -- Delete DropID    
            IF EXISTS( SELECT 1 FROM DropID WITH (NOLOCK) WHERE DropID = @cActToteID)    
            BEGIN    
               DELETE DropID WHERE DropID = @cActToteID    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 54801    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL DID Fail    
                  GOTO RollBackTran    
               END    
            END    
                
            -- Get LoadKey    
            SET @cLoadKey = ''    
            SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey    
    
            -- Get PickSlipNo    
            SET @cPickSlipNo = ''    
            SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey    
            IF @cPickSlipNo = ''    
               SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey    
                
            -- Insert DropID    
            INSERT INTO DropID (DropID, DropIDType, Status, UDF01, LoadKey, PickSlipNo)     
            VALUES( @cActToteID, 'MULTIS', '5', @cOrderKey, @cLoadKey, @cPickSlipNo)    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 54802    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS DID Fail    
               GOTO RollBackTran    
            END    

            -- (james01)
            SELECT TOP 1 @cPickSlipNo = BatchKey
            FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
            WHERE CartID = @cCartID
            AND   ToteID = @cActToteID
            AND   StorerKey = @cStorerKey
            ORDER BY 1

            IF NOT EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                            WHERE PickSlipNo = @cPickSlipNo)
            BEGIN
               INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID)  
               VALUES (@cPickSlipNo, GETDATE(), @cUserName)  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 54803  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail scan-in  
                  GOTO RollBackTran  
               END  
            END
            
            FETCH NEXT FROM @curOrder INTO @cActToteID, @cOrderKey    
       END    
      END    
   END    
    
   COMMIT TRAN rdt_808ExtUpd01    
   GOTO Quit    
       
RollBackTran:    
   ROLLBACK TRAN rdt_808ExtUpd01 -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END    

GO