SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtVal06                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-09-30 1.0  Ung        SOS352466 Created                         */
/* 2016-11-13 1.1  James      Add SOStatus checking. Limit no of orders */
/*                            that can add into mboldetail (james01)    */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtVal06] (
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

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE @cPickSlipNo NVARCHAR(10)
DECLARE @cSOStatus   NVARCHAR(10)
DECLARE @cShipperKey NVARCHAR(15)
DECLARE @cNoOfOrdersAllowed  NVARCHAR( 5)
DECLARE @nOrderCount INT


IF @nFunc = 922
BEGIN
   IF @nStep = 2 -- LabelNo/DropID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cMBOLKey <> ''
         BEGIN
            -- Get carton info
            SELECT @cPickSlipNo = PickSlipNo FROM PackDetail WITH (NOLOCK) WHERE DropID = @cLabelNo
            SELECT @cOrderKey = OrderKey FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
            SELECT @cShipperKey = ShipperKey, 
                   @cSOStatus = SOStatus 
            FROM Orders WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey

            IF ISNULL( @cSOStatus, '') = 'HOLD'
            BEGIN
               SET @nErrNo = 56452
               SET @cErrMsg = rdt.rdtgetmessage( 105151, @cLangCode, 'DSP')   --Order is HOLD
               GOTO Quit
            END

            IF ISNULL( @cSOStatus, '') = 'PENDPACK'
            BEGIN
               SET @nErrNo = 56453
               SET @cErrMsg = rdt.rdtgetmessage( 105151, @cLangCode, 'DSP')   --Pending UPD
               GOTO Quit
            END

            IF ISNULL( @cSOStatus, '') = 'PENDCANC'
            BEGIN
               SET @nErrNo = 56454
               SET @cErrMsg = rdt.rdtgetmessage( 105151, @cLangCode, 'DSP')   --Pending CANC
               GOTO Quit
            END

            IF ISNULL( @cSOStatus, '') = 'CANC'
            BEGIN
               SET @nErrNo = 56455
               SET @cErrMsg = rdt.rdtgetmessage( 105151, @cLangCode, 'DSP')   --Order is Canc
               GOTO Quit
            END

            -- (james01)
            SET @cNoOfOrdersAllowed = rdt.rdtGetConfig( @nFunc, 'NoOfOrdersAllowed', @cStorerKey)
            IF rdt.rdtIsValidQTY( @cNoOfOrdersAllowed, 0) = 0
               SET @cNoOfOrdersAllowed = '0'   

            -- Limit no of orders per mbol, 0 = no limit
            IF CAST( @cNoOfOrdersAllowed AS INT) > 0
            BEGIN
               SET @nOrderCount = 0
               SELECT @nOrderCount = Count (Orderkey)
               FROM dbo.MBOLDetail WITH (NOLOCK)
               WHERE MBOLKey = @cMBOLKey

               IF @cNoOfOrdersAllowed < @nOrderCount + 1
               BEGIN
                  SET @nErrNo = 56456
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   --Allow #OfOrds
                  GOTO Quit
               END
            END
   
            -- 1 MBOL 1 ShipperKey
            IF EXISTS( SELECT 1 
               FROM MBOLDetail M WITH (NOLOCK) 
                  JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = M.OrderKey)
               WHERE M.MBOLKey = @cMBOLKey
                  AND O.ShipperKey <> @cShipperKey)
            BEGIN
               SET @nErrNo = 56451
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff Shipper
               GOTO Quit
            END  
         END
      END
   END

Quit:

END


GO