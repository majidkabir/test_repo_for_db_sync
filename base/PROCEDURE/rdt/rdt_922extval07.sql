SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtVal07                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Check if mbol only contain 1 orders.rdd                     */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-10-30 1.0  James      SOS356041 Created                         */
/* 2021-08-27 1.1  James      WMS-17659 Add checking cannot mix shipper */
/*                            Limit no of orders in Mbol (james01)      */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtVal07] (
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

DECLARE @cPickSlipNo    NVARCHAR( 10),
        @cSOStatus      NVARCHAR( 10),
        @cRDD           NVARCHAR( 30),
        @cNew_RDD       NVARCHAR( 30),
        @cChk_MBOLKey   NVARCHAR( 10),
        @cErrMsg1       NVARCHAR( 20),
        @cErrMsg2       NVARCHAR( 20),
        @cErrMsg3       NVARCHAR( 20),
        @cShipperKey    NVARCHAR( 15),
        @cOtherShipperKey  NVARCHAR( 15),
        @nOrderCnt         INT,
        @nNoOfOrderAllowed INT
        
IF @nFunc = 922
BEGIN
   SET @nNoOfOrderAllowed = rdt.RDTGetConfig( @nFunc, 'CheckMaxParcels', @cStorerKey)
   
   IF @nStep = 1 --MbolKey
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cMBOLKey <> ''
         BEGIN
            SELECT @nOrderCnt = COUNT( DISTINCT OrderKey)
            FROM dbo.MBOLDETAIL WITH (NOLOCK) 
            WHERE MbolKey = @cMBOLKey

            IF @nOrderCnt >= @nNoOfOrderAllowed
            BEGIN
               SET @nErrNo = 94857
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MBOL>100Parcel
               GOTO Quit
            END
         END         
      END
   END
   
   IF @nStep = 2 -- LabelNo/DropID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cMBOLKey <> ''
         BEGIN
            SET @cPickSlipNo = ''
            SET @cOrderKey = ''
            SET @cNew_RDD = ''
            SET @cChk_MBOLKey = ''

            -- Get carton info
            SELECT @cPickSlipNo = PickSlipNo 
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE LabelNo = @cLabelNo
            
            SELECT @cOrderKey = OrderKey 
            FROM dbo.PackHeader WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
            
            SELECT @cNew_RDD = RDD, 
                   @cChk_MBOLKey = MBOLKey, 
                   @cShipperKey = ShipperKey 
            FROM dbo.Orders WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey
            
            IF ( ISNULL( @cChk_MBOLKey, '') <> '') AND @cChk_MBOLKey <> @cMBOLKey
            BEGIN
               SET @nErrNo = 94851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff MBOLKey
               GOTO Quit
            END  

            IF ISNULL( @cNew_RDD, '') = ''
            BEGIN
               SET @nErrNo = 94852
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Region
               GOTO Quit
            END  

            -- 1 MBOL 1 Orders.RDD (destination)
            IF EXISTS ( SELECT 1 FROM dbo.MBOLDetail MD WITH (NOLOCK) 
                        JOIN dbo.Orders O WITH (NOLOCK) ON ( MD.OrderKey = O.OrderKey)
                        WHERE MD.MBOLKey = @cMBOLKey 
                        GROUP BY RDD 
                        HAVING COUNT( DISTINCT RDD) > 1) 
            BEGIN
               SET @nErrNo = 94853
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mbol > 1 Region
               GOTO Quit
            END  

            -- If this orders not yet inserted into mbol, check no of parcel allow in mbol
            IF NOT EXISTS ( SELECT 1 FROM dbo.MBOLDETAIL WITH (NOLOCK) 
                            WHERE MbolKey = @cMBOLKey 
                            AND   OrderKey = @cOrderKey)
            BEGIN
               SELECT @nOrderCnt = COUNT( DISTINCT OrderKey)
               FROM dbo.MBOLDETAIL WITH (NOLOCK) 
               WHERE MbolKey = @cMBOLKey

               IF ( @nOrderCnt + 1) > @nNoOfOrderAllowed
               BEGIN
                  SET @nErrNo = 94858
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MBOL>100Parcel
                  GOTO Quit
               END
            END
            
            -- Get current scanned shipperkey
            SELECT @cShipperKey = SUBSTRING( C.Short, 1, 3) 
            FROM dbo.ORDERS O WITH (NOLOCK) 
            JOIN dbo.CODELKUP C WITH (NOLOCK) ON ( O.ShipperKey = C.Code)
            WHERE C.Listname = 'HMCourier'
            AND O.OrderKey = @cOrderKey

            -- Get shipperkey from current mbol 
            SELECT TOP 1 @cOtherShipperKey = SUBSTRING( C.Short, 1, 3) 
            FROM dbo.ORDERS O WITH (NOLOCK) 
            JOIN dbo.CODELKUP C WITH (NOLOCK) ON ( O.ShipperKey = C.Code)
            WHERE C.Listname = 'HMCourier'
            AND O.MbolKey = @cMBOLKey
            ORDER BY 1

            -- 1 MBOL 1 Orders.ShipperKey (courier)
            IF ISNULL( @cOtherShipperKey, '') <> ''
            BEGIN
               IF rdt.RDTGetConfig( @nFunc, 'NotAllowMixCourier', @cStorerKey) = '1' AND  
                  @cShipperKey <> @cOtherShipperKey
               BEGIN
                  SET @nErrNo = 94859
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mbol Mix Courier
                  GOTO Quit
               END  
            END
            
            -- If it is not 1st orders in mboldetail, check the rdd
            IF EXISTS ( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey)
            BEGIN
               -- Get existing RDD and compare with new RDD. Make sure is same
               SELECT TOP 1 @cRDD = RDD
               FROM dbo.Orders WITH (NOLOCK)  
               WHERE MBOLKey = @cMBOLKey

               IF ISNULL( @cNew_RDD, '') <> ISNULL( @cRDD, '')
               BEGIN
                  SET @nErrNo = 0
                  SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 94854, @cLangCode, 'DSP'), 7, 14)
                  SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 94855, @cLangCode, 'DSP'), 7, 14)
                  SET @cErrMsg3 = SUBSTRING( rdt.rdtgetmessage( 94856, @cLangCode, 'DSP'), 7, 14)
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                       @cErrMsg1, @cErrMsg2, @cErrMsg3
                  IF @nErrNo = 1
                  BEGIN
                     SET @cErrMsg1 = ''
                     SET @cErrMsg2 = ''
                     SET @cErrMsg3 = ''

                     GOTO Quit
                  END
               END  
            END
         END
      END
   END

Quit:

END

GO