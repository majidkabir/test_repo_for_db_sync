SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1663ExtVal09                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Prompt error if diff carrier, ord type and not pick scan to pallet*/
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2020-03-27 1.0  James    WMS-12611 Created                                 */
/* 2023-08-02 1.1  WyeChun	Filter with Orderkey instead of TrackingNo (WC01) */
/******************************************************************************/

CREATE     PROC [RDT].[rdt_1663ExtVal09](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPalletKey    NVARCHAR( 20), 
   @cPalletLOC    NVARCHAR( 10), 
   @cMBOLKey      NVARCHAR( 10), 
   @cTrackNo      NVARCHAR( 20), 
   @cOrderKey     NVARCHAR( 10), 
   @cShipperKey   NVARCHAR( 15),  
   @cCartonType   NVARCHAR( 10),  
   @cWeight       NVARCHAR( 10), 
   @cOption       NVARCHAR( 1),  
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cORDType       NVARCHAR( 10),  
        @cNew_ORDType   NVARCHAR( 10),
        @cStatus        NVARCHAR( 10),  
        @cRDD           NVARCHAR( 30),  
        @cNew_RDD       NVARCHAR( 30),  
        @cChk_MBOLKey   NVARCHAR( 10),
        @cNew_OrderKey  NVARCHAR( 10),
        @cNew_Status    NVARCHAR( 10),
        @cCarrierKey    NVARCHAR( 30),
        @cNew_CarrierKey      NVARCHAR( 30),
        @cNew_ShipperKey      NVARCHAR( 15),
        @cORD_ShipperKey      NVARCHAR( 15),
        @cNotAllowDiffOrdType NVARCHAR( 1),
        @cNotAllowDiffCarrier NVARCHAR( 1)

   DECLARE @cErrMsg1    NVARCHAR( 20)
   DECLARE @cErrMsg2    NVARCHAR( 20)
   DECLARE @cErrMsg3    NVARCHAR( 20)

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      SET @cNotAllowDiffOrdType = rdt.rdtGetConfig( @nFunc, 'NotAllowDiffOrdType', @cStorerKey)  
      SET @cNotAllowDiffCarrier = rdt.rdtGetConfig( @nFunc, 'NotAllowDiffCarrier', @cStorerKey)
      
      SELECT TOP 1 @cOrderKey = UserDefine01
      FROM dbo.PALLETDETAIL WITH (NOLOCK)
      WHERE PalletKey = @cPalletKey
      ORDER BY 1
      
      SELECT @cORDType = [Type],
             @cORD_ShipperKey = ShipperKey
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
      
      IF @nStep = 3 -- Tracking No
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
		    SELECT @cOrderKey = LabelNo 
            FROM CartonTrack WITH (NOLOCK) 
            WHERE TrackingNo = @cTrackNo        --WC01 
			
            SELECT @cNew_OrderKey = OrderKey, 
                   @cNew_Status = [Status],
                   @cNew_ORDType = [Type],
                   @cNew_ShipperKey = ShipperKey
            FROM dbo.Orders WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
            --AND   TrackingNo = @cTrackNo
            AND   OrderKey = @cOrderKey         --WC01

            IF @cNew_Status <> '5'
            BEGIN  
               SET @nErrNo = 150301  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv Ord Status  
               GOTO Quit  
            END  

            IF @cNotAllowDiffOrdType = '1'
            BEGIN
               IF @cORDType <> @cNew_ORDType
               BEGIN  
                  SET @nErrNo = 150302  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff Ord Type  
                  GOTO Quit  
               END  
            END
            
            IF @cNotAllowDiffCarrier = '1'
            BEGIN
               SELECT @cCarrierKey = UDF04
               FROM  dbo.CODELKUP WITH (NOLOCK)
               WHERE LISTNAME = 'HMCOURIER'
               AND   Code = @cORD_ShipperKey
               AND   Storerkey = @cStorerKey
      
               SELECT @cNew_CarrierKey = UDF04
               FROM dbo.CODELKUP WITH (NOLOCK)
               WHERE LISTNAME = 'HMCOURIER'
               AND   Code = @cNew_ShipperKey
               AND   Storerkey = @cStorerKey
               
               IF @cCarrierKey <> @cNew_CarrierKey
               BEGIN  
                  SET @nErrNo = 150303  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff Carrier  
                  GOTO Quit  
               END 
            
            END
            
            SELECT @cNew_RDD = RDD,   
                   @cChk_MBOLKey = MBOLKey   
            FROM dbo.Orders WITH (NOLOCK)    
            WHERE OrderKey = @cNew_OrderKey  
              
            IF ( ISNULL( @cChk_MBOLKey, '') <> '') AND @cChk_MBOLKey <> @cMBOLKey  
            BEGIN  
               SET @nErrNo = 150304  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff MBOLKey  
               GOTO Quit  
            END    
  
            IF ISNULL( @cNew_RDD, '') = ''  
            BEGIN  
               SET @nErrNo = 150305  
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
               SET @nErrNo = 150306  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mbol > 1 Region  
               GOTO Quit  
            END    
  
            -- If it is not 1st orders in mboldetail, check the rdd  
            IF EXISTS ( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey)  
            BEGIN  
               -- Get existing RDD and compare with new RDD. Make sure is same  
               SELECT TOP 1 @cRDD = RDD  
               FROM dbo.Orders WITH (NOLOCK)    
               WHERE MBOLKey = @cMBOLKey  
               ORDER BY 1

               IF ISNULL( @cNew_RDD, '') <> ISNULL( @cRDD, '')  
               BEGIN  
                  SET @nErrNo = 0  
                  SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 150307, @cLangCode, 'DSP'), 7, 14)  --Invalid Region
                  SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 150308, @cLangCode, 'DSP'), 7, 14)  -- Pls Try A 
                  SET @cErrMsg3 = SUBSTRING( rdt.rdtgetmessage( 150309, @cLangCode, 'DSP'), 7, 14)  -- New MBOL
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