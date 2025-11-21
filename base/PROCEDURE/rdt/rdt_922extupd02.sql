SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtUpd02                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-05-14 1.2  Ung        SOS278061 Insert MBOLDetail               */
/* 2015-12-01 1.3  Ung        SOS358041 Update MBOLDetail               */
/*                            ExtendedUpdateSP reorg param              */
/* 2017-02-27 1.4  TLTING     Variable Nvarchar                         */
/* 2018-07-26 1.5  Ung        WMS-5775 Add CheckPackDetailDropID        */
/* 2018-09-24 1.6  James      WMS7751-Remove OD.loadkey (james01)       */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtUpd02] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  NVARCHAR( 15),
   @cType       NVARCHAR( 1),
   @cMBOLKey    NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10),
   @cLabelNo    NVARCHAR( 20),
   @cPackInfo   NVARCHAR( 3), 
   @cWeight     NVARCHAR( 10),
   @cCube       NVARCHAR( 10),
   @cCartonType NVARCHAR( 10),
   @cDoor       NVARCHAR( 10),
   @cRefNo      NVARCHAR( 40),
   @nErrNo      INT       OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE @cPickSlipNo NVARCHAR(10)
DECLARE @nTranCount  INT

SET @nTranCount = @@TRANCOUNT

DECLARE @cCheckPackDetailDropID  NVARCHAR(1)
SET @cCheckPackDetailDropID = rdt.RDTGetConfig( @nFunc, 'CheckPackDetailDropID', @cStorerKey)

IF @nFunc = 922
BEGIN
   IF @nStep = 2 -- LabelNo/DropID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cMBOLKey <> ''
         BEGIN
            -- Get carton info
            IF @cCheckPackDetailDropID = '1'
               SELECT @cPickSlipNo = PickSlipNo FROM PackDetail WITH (NOLOCK) WHERE DropID = @cLabelNo
            ELSE
               SELECT @cPickSlipNo = PickSlipNo FROM PackDetail WITH (NOLOCK) WHERE LabelNo = @cLabelNo
            
            -- Get order
            SELECT @cOrderKey = OrderKey FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

            -- Get Order Info
            DECLARE @dOrderDate DATETIME
            DECLARE @dDelivery_Date DATETIME
            DECLARE @cExternOrderKey NVARCHAR(30)
            DECLARE @cOrderFacility  NVARCHAR(5)
            SELECT
               @cOrderFacility = Facility,
               @dOrderDate = OrderDate,
               @dDelivery_Date = DeliveryDate,
               @cExternOrderKey = ExternOrderKey, 
               @cLoadKey = LoadKey
            FROM Orders WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            -- Insert MBOLDetail
            IF NOT EXISTS( SELECT TOP 1 1 FROM MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
            BEGIN
               DECLARE @bSuccess INT
               EXEC isp_InsertMBOLDetail
                   @cMBOLKey
                  ,@cOrderFacility
                  ,@cOrderKey
                  ,@cLoadKey
                  ,0                -- @nStdGrossWgt
                  ,0                -- @nStdCube
                  ,@cExternOrderKey
                  ,@dOrderDate
                  ,@dDelivery_Date
                  ,''               -- @cRoute
                  ,@bSuccess  OUTPUT
                  ,@nErrNo    OUTPUT
                  ,@cErrMsg   OUTPUT
            END
         END
      END
   END
   
   IF @nStep = 3 -- Weight, Cube, CartonType
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Get carton info
         DECLARE @nCartonNo INT
         IF @cCheckPackDetailDropID = '1'
            SELECT 
               @cPickSlipNo = PickSlipNo, 
               @nCartonNo = CartonNo, 
               @cRefNo = RefNo
            FROM PackDetail WITH (NOLOCK) 
            WHERE DropID = @cLabelNo
         ELSE
            SELECT 
               @cPickSlipNo = PickSlipNo, 
               @nCartonNo = CartonNo, 
               @cRefNo = RefNo
            FROM PackDetail WITH (NOLOCK) 
            WHERE LabelNo = @cLabelNo
            
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_922ExtUpd02 -- For rollback or commit only our own transaction
         
         -- Update PackInfo
         IF EXISTS( SELECT 1 FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo AND ISNULL( RefNo, '') <> @cLabelNo)
         BEGIN
            UPDATE PackInfo SET
               RefNo = @cLabelNo
            WHERE PickSlipNo = @cPickSlipNo 
               AND CartonNo = @nCartonNo 
            SET @nErrNo = @@ERROR 
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
         END

         -- Get MBOLDetail info
         DECLARE @cMBOLLineNumber NVARCHAR(5)
         SET @cMBOLLineNumber = ''
         SELECT @cOrderKey = OrderKey FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
         SELECT @cMBOLLineNumber = MBOLLineNumber FROM MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey

         -- Update MBOLDetail
         IF @cMBOLLineNumber <> ''
         BEGIN
            UPDATE MBOLDetail SET
               Weight = Weight + CAST( @cWeight AS FLOAT), 
               Cube = Cube + CAST( @cCube AS FLOAT)
            WHERE MBOLKey = @cMBOLKey 
               AND MBOLLineNumber = @cMBOLLineNumber
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
         END
         
         COMMIT TRAN rdt_922ExtUpd02 -- Only commit change made in here  
         GOTO Quit  
      END
   END
END
GOTO Quit

RollBackTran:  
   ROLLBACK TRAN rdt_922ExtUpd02  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  

GO