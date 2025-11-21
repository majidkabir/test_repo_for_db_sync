SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtUpd03                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-11-19 1.0  James      SOS353558 - Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtUpd03] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   CHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  CHAR( 15),
   @cType       CHAR( 1),
   @cMBOLKey    CHAR( 10),
   @cLoadKey    CHAR( 10),
   @cOrderKey   CHAR( 10),
   @cLabelNo    CHAR( 20),
   @cPackInfo   NVARCHAR( 3), 
   @cWeight     NVARCHAR( 10),
   @cCube       NVARCHAR( 10),
   @cCartonType NVARCHAR( 10),
   @cDoor       NVARCHAR( 10),
   @cRefNo      NVARCHAR( 40),
   @nErrNo      INT       OUTPUT,
   @cErrMsg     CHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE @cPickSlipNo NVARCHAR(10)

IF @nFunc = 922
BEGIN
   IF @nStep = 2 -- LabelNo/DropID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cMBOLKey <> ''
         BEGIN
            -- Get carton info
            SELECT @cPickSlipNo = PickSlipNo FROM dbo.PackDetail WITH (NOLOCK) WHERE LabelNo = @cLabelNo
            SELECT @cOrderKey = OrderKey FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

            -- Get Order Info
            DECLARE @dOrderDate DATETIME
            DECLARE @dDelivery_Date DATETIME
            DECLARE @cExternOrderKey NVARCHAR(30)
            DECLARE @cOrderFacility  NVARCHAR(5)
            SELECT
               @cOrderFacility = O.Facility,
               @dOrderDate = O.OrderDate,
               @dDelivery_Date = O.DeliveryDate,
               @cExternOrderKey = O.ExternOrderKey, 
               @cLoadKey = OD.LoadKey
            FROM dbo.Orders O WITH (NOLOCK)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
            WHERE O.OrderKey = @cOrderKey

            -- Insert MBOLDetail
            IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
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
         SELECT 
            @cPickSlipNo = PickSlipNo, 
            @nCartonNo = CartonNo, 
            @cRefNo = RefNo
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE DropID = @cLabelNo

         -- Update PackInfo
         IF EXISTS( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                    WHERE PickSlipNo = @cPickSlipNo 
                    AND   CartonNo = @nCartonNo 
                    AND   ISNULL( RefNo, '') <> @cLabelNo)
         BEGIN
            UPDATE PackInfo WITH (ROWLOCK) SET
               RefNo = @cLabelNo
            WHERE PickSlipNo = @cPickSlipNo 
               AND CartonNo = @nCartonNo 
            SET @nErrNo = @@ERROR 
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Fail
            END
         END
      END
   END
END

Quit:
Fail:

GO