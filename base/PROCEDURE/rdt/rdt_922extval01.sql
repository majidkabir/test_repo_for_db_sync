SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtVal01                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-09-30 1.0  Ung        SOS321796 Created                         */
/* 2015-09-02 1.1  Ung        SOS351487 MBOL only 1 ShipperKey          */
/* 2015-10-26 1.2  Ung        SOS355268 Check Orders.SOStatus = HOLD    */
/* 2016-11-13 1.3  James      Add SOStatus checking. Limit no of orders */
/*                            that can add into mboldetail (james01)    */
/* 2016-12-20 1.4  Ung        IN00225951 Add check ID in different MBOL */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtVal01] (
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
            SELECT 
               @cSOStatus = SOStatus, 
               @cShipperKey = ShipperKey
            FROM Orders WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey
   
            -- Check order status
            IF @cSOStatus = 'PendCanc'
            BEGIN
               SET @nErrNo = 50651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Order PendCanc
               GOTO Quit
            END
   
            IF @cSOStatus = 'PendPack'
            BEGIN
               SET @nErrNo = 50652
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Order PendPack
               GOTO Quit
            END
   
            IF @cSOStatus = '0'
            BEGIN
               SET @nErrNo = 50653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ord StatusOpen
               GOTO Quit
            END

            IF @cSOStatus = 'HOLD'
            BEGIN
               SET @nErrNo = 50655
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ord StatusHold
               GOTO Quit
            END
            
            -- 1 MBOL 1 ShipperKey
            IF EXISTS( SELECT 1 
               FROM MBOLDetail M WITH (NOLOCK) 
                  JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = M.OrderKey)
               WHERE M.MBOLKey = @cMBOLKey
                  AND O.ShipperKey <> @cShipperKey)
            BEGIN
               SET @nErrNo = 50654
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff Shipper
               GOTO Quit
            END 

            -- Scanned to different MBOL
            IF EXISTS( SELECT TOP 1 1 FROM MBOLDetail WITH (NOLOCK) WHERE MBOLKey <> @cMBOLKey AND OrderKey = @cOrderKey)
            BEGIN
               SET @nErrNo = 50657
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AdyInDiffMBOL
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
                  SET @nErrNo = 50656
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   --ExceedMaxOrder
                  GOTO Quit
               END
            END             
         END
      END
   END

Quit:

END

GO