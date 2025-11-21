SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtUpd04                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-05-19 1.0  Ung        WMS-1937 Created                          */
/* 2018-01-30 1.1  CheeMun    INC0113568 - Sku's Weight + Carton Weight */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtUpd04] (
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
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @cPickSlipNo    NVARCHAR(10)
   DECLARE @cCartonGroup   NVARCHAR(10)
   DECLARE @fCube          FLOAT
   DECLARE @fWeight        FLOAT
   DECLARE @tWeight        FLOAT    --INC0113568

   IF @nFunc = 922 -- Scan to truck (by label no)
   BEGIN
      IF @nStep = 2 -- LabelNo/DropID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cMBOLKey <> ''
            BEGIN
               -- Get storer config
               DECLARE @cCheckPackDetailDropID NVARCHAR(1)
               DECLARE @cCheckPickDetailDropID NVARCHAR(1)
               SET @cCheckPackDetailDropID = rdt.RDTGetConfig( @nFunc, 'CheckPackDetailDropID', @cStorerKey)
               SET @cCheckPickDetailDropID = rdt.RDTGetConfig( @nFunc, 'CheckPickDetailDropID', @cStorerKey)

               IF @cCheckPickDetailDropID = '1'
               BEGIN
                  -- Get OrderKey
                  SELECT @cOrderKey = OrderKey
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND DropID = @cLabelNo                     
               END
    
               ELSE IF @cCheckPackDetailDropID = '1'
                  SELECT TOP 1
                     @cPickSlipNo = PH.PickSlipNo,
                     @cOrderKey = PH.OrderKey,
                     @cLoadKey = PH.LoadKey
                  FROM dbo.PackHeader PH WITH (NOLOCK)
                     JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                  WHERE PD.StorerKey = @cStorerKey
                     AND PD.DropID = @cLabelNo
                  ORDER BY PH.PickslipNo DESC
   
               ELSE
                  SELECT TOP 1 
                     @cPickSlipNo = PH.PickSlipNo,
                     @cOrderKey = PH.OrderKey,
                     @cLoadKey = PH.LoadKey
                  FROM dbo.PackHeader PH WITH (NOLOCK)
                     JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                  WHERE PD.StorerKey = @cStorerKey
                     AND PD.LabelNo = @cLabelNo
                  ORDER BY PH.PickslipNo DESC         
               
               -- Check order
               IF @cOrderKey = ''
               BEGIN
                  SET @nErrNo = 111052
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OrderKey
                  GOTO Quit
               END

               -- Insert MBOLDetail
               IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
               BEGIN
                  -- Get PickSlipNo
                  IF @cPickSlipNo = ''
                     SELECT @cPickSlipNo = PickSlipNo FROM dbo.PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
                  
                  -- Check pick slip
                  IF @cPickSlipNo = ''
                  BEGIN
                     SET @nErrNo = 111051
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedPickSlipNo
                     GOTO Quit
                  END
                  
                  -- Get storer info
                  SELECT @cCartonGroup = CartonGroup FROM Storer WITH (NOLOCK) WHERE StorerKey = @cStorerKey

                  -- Calc carton cube weight
                  SELECT @fCube = ISNULL( SUM( Cube), 0)
                  FROM PackInfo WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo

                  -- Calc SKU weight
                  SELECT @fWeight = ISNULL( SUM( PD.QTY * SKU.STDGrossWGT), 0)
                  FROM PackDetail PD WITH (NOLOCK)
                     JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
                  WHERE PD.PickSlipNo = @cPickSlipNo
                  
                  -- Calc Carton Type Weight                  
                  SELECT @tWeight = ISNULL( SUM( CartonWeight ), 0) 
                  FROM PackInfo P WITH (NOLOCK) 
                  JOIN Cartonization C WITH (NOLOCK) ON (P.CartonType = C.CartonType)
                  WHERE P.PickSlipNo = @cPickSlipNo
                  
                  SELECT @tWeight = @tWeight + + @fWeight      --INC0113568
                  
                  -- Get Order Info
                  DECLARE @dOrderDate DATETIME
                  DECLARE @dDeliveryDate DATETIME
                  DECLARE @cExternOrderKey NVARCHAR(30)
                  DECLARE @cOrderFacility  NVARCHAR(5)
                  SELECT
                     @cOrderFacility = Facility,
                     @dOrderDate = OrderDate,
                     @dDeliveryDate = DeliveryDate,
                     @cExternOrderKey = ExternOrderKey
                  FROM dbo.Orders WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey

                  -- Get OrderDetail info
                  SELECT TOP 1 @cLoadKey = LoadKey FROM dbo.OrderDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey
                  
                  EXEC isp_InsertMBOLDetail
                      @cMBOLKey
                     ,@cOrderFacility
                     ,@cOrderKey
                     ,@cLoadKey
                     ,@tWeight            -- @nStdGrossWgt  --INC0113568
                     ,@fCube              -- @nStdCube
                     ,@cExternOrderKey
                     ,@dOrderDate
                     ,@dDeliveryDate
                     ,''                  -- @cRoute
                     ,@bSuccess  OUTPUT
                     ,@nErrNo    OUTPUT
                     ,@cErrMsg   OUTPUT
               END
            END
         END
      END
   END

Quit:

END

GO