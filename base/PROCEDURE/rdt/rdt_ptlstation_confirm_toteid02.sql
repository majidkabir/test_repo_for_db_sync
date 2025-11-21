SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLStation_Confirm_ToteID02                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Close working batch                                         */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2021-04-12 1.0  James       WMS-15658. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_Confirm_ToteID02] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cType        NVARCHAR( 15) -- ID=confirm ID, CLOSECARTON/SHORTCARTON = confirm carton
   ,@cStation1    NVARCHAR( 10)
   ,@cStation2    NVARCHAR( 10)
   ,@cStation3    NVARCHAR( 10)
   ,@cStation4    NVARCHAR( 10)
   ,@cStation5    NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1) 
   ,@cScanID      NVARCHAR( 20) 
   ,@cSKU         NVARCHAR( 20)
   ,@nQTY         INT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
   ,@cCartonID    NVARCHAR( 20) = '' 
   ,@nCartonQTY   INT           = 0
   ,@cNewCartonID NVARCHAR( 20) = ''   -- For close carton with balance
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
   DECLARE @nRowRef        INT
   DECLARE @nPTLKey        INT
   DECLARE @nQTY_PTL       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
                           
   DECLARE @cActCartonID   NVARCHAR( 20)
   DECLARE @cIPAddress     NVARCHAR(40)
   DECLARE @cPosition      NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR(10)
   DECLARE @nCartonNo      INT
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @nPackQTY       INT
   DECLARE @nPickQTY       INT
   DECLARE @cUserName      NVARCHAR( 10)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cAreaKey       NVARCHAR( 10)
   DECLARE @cCloseTote     NVARCHAR( 10)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @cConsigneeKey  NVARCHAR( 15)
   DECLARE @cOrd_Type      NVARCHAR( 10)
   DECLARE @cOrd_Group     NVARCHAR( 10)
   DECLARE @cCartonLabel   NVARCHAR( 10)
   DECLARE @cStoreLabel    NVARCHAR( 10)
   DECLARE @cNSOManFest    NVARCHAR( 10)
   DECLARE @tCartonLabel   VARIABLETABLE
   DECLARE @tStoreLabel    VARIABLETABLE
   DECLARE @tNSOManFest    VARIABLETABLE
   
   DECLARE @curPTL CURSOR
   DECLARE @curLOG CURSOR
   DECLARE @curPD  CURSOR

   SELECT @cLabelPrinter = Printer, 
          @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get storer config
   DECLARE @cUpdatePickDetail NVARCHAR(1)
   DECLARE @cUpdatePackDetail NVARCHAR(1)
   DECLARE @cAutoPackConfirm  NVARCHAR(1)
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)
   SET @cAutoPackConfirm = rdt.rdtGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)


   /***********************************************************************************************

                                              CONFIRM CARTON 

   ***********************************************************************************************/
   -- Confirm carton
   IF @cType <> 'ID'
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_PTLStation_Confirm -- For rollback or commit only our own transaction


      -- Update new carton
      IF @cType = 'CLOSECARTON' AND @cNewCartonID <> ''
      BEGIN
         -- Loop current carton
         SET @curLOG = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef 
            FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND CartonID = @cCartonID
         OPEN @curLOG
         FETCH NEXT FROM @curLOG INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Change carton on rdtPTLStationLog
            UPDATE rdt.rdtPTLStationLog SET
               CartonID = @cNewCartonID
            WHERE RowRef = @nRowRef 
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 101824
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curLOG INTO @nRowRef
         END
      END
      
      COMMIT TRAN rdt_PTLStation_Confirm
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

   -- Confirm carton
   IF @cType <> 'ID'
   BEGIN
      -- Update new carton
      IF @cType = 'CLOSECARTON' AND @cNewCartonID <> ''
      BEGIN
         SELECT @cOrderKey = OrderKey 
         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
         WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND CartonID = @cNewCartonID

         SELECT @cConsigneeKey = ConsigneeKey, 
                @cOrd_Type = [Type],
                @cOrd_Group = OrderGroup
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
         SELECT @cPickSlipNo = PickSlipNo
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
        SELECT @nCartonNo = CartonNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   LabelNo = @cCartonID

         SET @cCartonLabel = rdt.RDTGetConfig( @nFunc, 'CartonLbl', @cStorerKey)
         IF @cCartonLabel = '0'
            SET @cCartonLabel = ''

         IF @cCartonLabel <> ''
         BEGIN
            INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cStorerkey', @cStorerkey)
            INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)     
            INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)     
            INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)    

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
               @cCartonLabel, -- Report type
               @tCartonLabel, -- Report params
               'rdt_PTLStation_Confirm_ToteID02', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT 
               
            IF @nErrNo <> 0
               GOTO Fail
         END

         IF EXISTS ( SELECT 1 FROM dbo.CodeLKup WITH (NOLOCK)   
                     WHERE ListName = 'LULUSTLBL'  
                     AND StorerKey = @cStorerKey   
                     AND Code = @cConsigneeKey  
                     AND Code2 = @cOrd_Type )   
         BEGIN
            SET @cStoreLabel = rdt.RDTGetConfig( @nFunc, 'StoreLbl', @cStorerKey)
            IF @cStoreLabel = '0'
               SET @cStoreLabel = ''

            IF @cStoreLabel <> ''
            BEGIN
               INSERT INTO @tStoreLabel (Variable, Value) VALUES ( '@cStorerkey', @cStorerkey)
               INSERT INTO @tStoreLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)     
               INSERT INTO @tStoreLabel (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)     
               INSERT INTO @tStoreLabel (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)    

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                  @cStoreLabel, -- Report type
                  @tStoreLabel, -- Report params
                  'rdt_PTLStation_Confirm_ToteID02', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 
               
               IF @nErrNo <> 0
                  GOTO Fail
            END
         END
         
         IF EXISTS ( SELECT 1 FROM dbo.CodeLKup WITH (NOLOCK)   
                     WHERE ListName = 'LULUNSO'  
                     AND StorerKey = @cStorerKey   
                     AND Code = @cOrd_Group)  
         BEGIN
            SET @cNSOManFest = rdt.RDTGetConfig( @nFunc, 'NSOManFest', @cStorerKey)
            IF @cNSOManFest = '0'
               SET @cNSOManFest = ''

            IF @cNSOManFest <> ''
            BEGIN
               INSERT INTO @tNSOManFest (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)     
               INSERT INTO @tNSOManFest (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)     
               INSERT INTO @tNSOManFest (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)    

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                  @cNSOManFest, -- Report type
                  @tNSOManFest, -- Report params
                  'rdt_PTLStation_Confirm_ToteID02', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 
               
               IF @nErrNo <> 0
                  GOTO Fail
            END
         END
      END
   END
END
Fail:

GO