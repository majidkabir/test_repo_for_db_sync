SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1663ExtVal17                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2021-11-01 1.0  yeekung  WMS-18301 allow SF and SF2 can pick in same pallet*/ 
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663ExtVal17](
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

   DECLARE @tOrders TABLE 
   (
      OrderKey   NVARCHAR( 10) NOT NULL,
      ShipperKey NVARCHAR( 15) NOT NULL
   )

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      IF @nStep = 3 -- Track no
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cOtherTrackNo NVARCHAR( 20)
            DECLARE @nRowCount INT

            DECLARE @cChkOrderKey NVARCHAR(10)    
            DECLARE @cChkShipperKey NVARCHAR(20)  
              
            SELECT     
               @cChkOrderKey = UserDefine01     
            FROM PalletDetail WITH (NOLOCK)     
            WHERE PalletKey = @cPalletKey 

            SET @nRowCount = @@ROWCOUNT    
          
            -- Pallet level checking    
            IF @nRowCount > 0    
            BEGIN    

               SELECT     
                  @cChkShipperKey = ShipperKey
               FROM Orders WITH (NOLOCK)     
               WHERE OrderKey = @cChkOrderKey   

               IF @cChkShipperKey <> @cShipperKey  AND (ISNULL(@cChkShipperKey,'') NOT IN('SF','SF5') OR ISNULL(@cShipperKey,'') NOT IN('SF','SF5'))
               BEGIN    
                  SET @nErrNo = 178301    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Carrier    
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg    
                  GOTO Quit    
               END    
            END

            SET @nRowCount=0

            -- Get other carton in order
            SELECT @cOtherTrackNo = TrackingNo
            FROM CartonTrack WITH (NOLOCK, INDEX = idx_cartontrack_LabelNo)   -- (james01)
            WHERE LabelNo = @cOrderKey
               AND CarrierName = @cShipperKey
               AND TrackingNo <> @cTrackNo
            SET @nRowCount = @@ROWCOUNT
            
            -- Order only 1 carton
            IF @nRowCount = 0
               GOTO Quit
            
            -- Order has 2 cartons
            ELSE IF @nRowCount = 1
            BEGIN
               -- Check other carton in another pallet
               IF EXISTS( SELECT 1
                  FROM PalletDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND CaseID = @cOtherTrackNo
                     AND PalletKey <> @cPalletKey)
               BEGIN
                  SET @nErrNo = 178302
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderInDiffPLT
                  GOTO Quit
               END
            END
            
            -- Order more then 2 cartons
            ELSE 
            BEGIN
               IF EXISTS( SELECT 1
                  FROM PalletDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND CaseID IN (
                        SELECT TrackingNo
                        FROM CartonTrack WITH (NOLOCK) 
                        WHERE LabelNo = @cOrderKey
                           AND CarrierName = @cShipperKey)
                     AND PalletKey <> @cPalletKey)
               BEGIN
                  SET @nErrNo = 178303
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderInDiffPLT
                  GOTO Quit
               END
            END
         END
      END
      
      IF @nStep = 6 -- Close pallet?
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cOption = '1' -- Yes
            BEGIN
               DECLARE @nPalletTrackNo INT
               DECLARE @nOrderTrackNo INT

               -- Get pallet info
               SELECT @nPalletTrackNo = COUNT(1) FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey

               -- Get order in pallet
               INSERT INTO @tOrders (OrderKey, ShipperKey)
               SELECT DISTINCT O.OrderKey, O.ShipperKey
               FROM PalletDetail PD WITH (NOLOCK)
                  JOIN CartonTrack CT WITH (NOLOCK) ON (PD.StorerKey = @cStorerKey AND PD.CaseID = CT.TrackingNo)
                  JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey AND CT.CarrierName = O.ShipperKey)
               WHERE PD.PalletKey = @cPalletKey
               
               -- Get all orders track no
               SELECT @nOrderTrackNo = COUNT(1)
               FROM CartonTrack CT WITH (NOLOCK)
                  JOIN @tOrders O ON (CT.LabelNo = O.OrderKey AND CT.CarrierName = O.ShipperKey)

               -- Check all track no scanned
               IF @nPalletTrackNo <> @nOrderTrackNo
               BEGIN
                  SET @nErrNo = 178304
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotAllScanned
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO