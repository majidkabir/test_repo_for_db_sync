SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1663ExtVal13                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Prompt error if diff carrier, ord type and not pick scan to pallet*/
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2020-09-23 1.0  Chermaine  WMS-14997 Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663ExtVal13](
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

DECLARE  @nPackQty   INT
DECLARE  @nPickQty   INT 

DECLARE @tOrders TABLE 
   (
      OrderKey   NVARCHAR( 10) NOT NULL,
      ShipperKey NVARCHAR( 15) NOT NULL
   )

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN      
      IF @nStep = 3 -- Tracking No
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
         	DECLARE @cOtherTrackNo NVARCHAR( 20)
            DECLARE @nRowCount INT

            -- Get other carton in order
            SELECT @cOtherTrackNo = TrackingNo
            FROM CartonTrack WITH (NOLOCK, INDEX = idx_cartontrack_LabelNo)
            WHERE LabelNo = @cOrderKey
               AND CarrierName = @cShipperKey
               AND TrackingNo <> @cTrackNo
            SET @nRowCount = @@ROWCOUNT
            
            ---- Order only 1 carton
            --IF @nRowCount = 0
            --   GOTO Quit
            
            -- Order has 2 cartons
            IF @nRowCount = 1
            BEGIN
               -- Check other carton in another pallet
               IF EXISTS( SELECT 1
                  FROM PalletDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND CaseID = @cOtherTrackNo
                     AND PalletKey <> @cPalletKey)
               BEGIN
                  SET @nErrNo = 159301
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderInDiffPLT
                  GOTO Quit
               END
            END
            
            -- Order more then 2 cartons
            ELSE IF @nRowCount > 1
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
                  SET @nErrNo = 159302
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderInDiffPLT
                  GOTO Quit
               END
            END
            
            IF EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND   TrackingNo = @cTrackNo AND SOStatus = 'PCANC')
            BEGIN  
               SET @nErrNo = 159303  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SO_PCANC
               GOTO Quit  
            END  
            
            SELECT @nPackQty = SUM(PD.Qty)
            FROM packHeader PH WITH (NOLOCK)
            JOIN packDetail PD WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo AND PH.StorerKey = PD.StorerKey
            WHERE PH.orderKey = @cOrderKey
            AND PH.StorerKey = @cStorerKey
            
            SELECT @nPickQty = SUM(Qty)  
            FROM PickDetail WITH (NOLOCK)   
            WHERE OrderKey = @cOrderKey 
            
            IF @nPackQty <> @nPickQty
            BEGIN
            	SET @nErrNo = 159304 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Repack
               GOTO Quit  
            END      
            
            IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE storerKey = @cStorerKey AND orderKey = @cOrderKey AND STATUS = '5' AND UserDefine03 = 'For_Canc')
            BEGIN
            	SET @nErrNo = 159305 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- For_Canc
               GOTO Quit  
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
                  SET @nErrNo = 159306
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