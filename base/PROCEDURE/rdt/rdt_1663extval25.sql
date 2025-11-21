SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtVal25                                          */
/* Copyright      : LF Logistics                                              */
/* Purpose: rdt_1663ExtVal06->rdt_1663ExtVal25                                */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2020-08-13 1.0  YeeKung  WMS-14715 Created                                 */
/* 2021-04-16 1.1  James    WMS-16024 Standarized use of TrackingNo (james01) */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1663ExtVal25](
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
      ShipperKey NVARCHAR( 15) NOT NULL,
      SUSR1      NVARCHAR( 15) NOT NULL
   )
   
   DECLARE @cOtherTrackNo NVARCHAR( 20)
   DECLARE @nRowCount INT
   
   DECLARE @cTemp_OrderKey    NVARCHAR( 20), 
           --@cShipperKey       NVARCHAR( 15), 
           @cTemp_ShipperKey  NVARCHAR( 15), 
           @cSUSR1            NVARCHAR( 15), 
           @cTemp_SUSR1       NVARCHAR( 15),
           @cTemp_MBOLKey     NVARCHAR( 10)

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      IF @nStep = 3 -- Track no
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            
            SELECT TOP 1 @cTemp_OrderKey = OrderKey 
            FROM dbo.MBOLDETAIL WITH (NOLOCK) 
            WHERE MbolKey = @cMBOLKey
            ORDER By AddDate Desc -- (ChewKP01) 

            -- If it is the first orderkey to scan
            IF ISNULL( @cTemp_OrderKey, '') <> ''
            BEGIN

               SELECT @cTemp_ShipperKey = ShipperKey
               FROM dbo.Orders WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   OrderKey = @cTemp_OrderKey

               SELECT --@cShipperKey = ShipperKey
                     @cTemp_MBOLKey = MBOLKey
               FROM dbo.Orders WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               --AND   UserDefine04 = @cTrackNo
               AND   TrackingNo = @cTrackNo  -- (james01)
               AND   [Status] < '9'
               
               IF ISNULL(@cTemp_MBOLKey,'') <> '' 
               BEGIN
                  IF ISNULL(@cTemp_MBOLKey,'') <> @cMBOLKey
                  BEGIN
                     SET @nErrNo = 156201
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNoDiffMBOLKey
                     GOTO Quit
                  END
               END
               
--               IF ISNULL(@cTemp_ShipperKey,'') <> @cShipperKey
--               BEGIN
--                  SET @nErrNo = 130605
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffShipperKey
--                  GOTO Quit
--               END

               SELECT @cSUSR1 = SUSR1 
               FROM dbo.Storer WITH (NOLOCK) 
               WHERE StorerKey = @cShipperKey

               SELECT @cTemp_SUSR1 = SUSR1 
               FROM dbo.Storer WITH (NOLOCK) 
               WHERE StorerKey = @cTemp_ShipperKey

               IF ISNULL( @cTemp_SUSR1, '') <> ISNULL( @cSUSR1, '')
               BEGIN
                  SET @nErrNo = 156202
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffSUSR1
                  GOTO Quit
               END
            
            END

            -- Get other carton in order
--            SELECT @cOtherTrackNo = TrackingNo
--            FROM CartonTrack WITH (NOLOCK, INDEX = idx_cartontrack_LabelNo)   
--            WHERE LabelNo = @cOrderKey
--               AND CarrierName = @cShipperKey
--               AND TrackingNo <> @cTrackNo
--            SET @nRowCount = @@ROWCOUNT
--            
--            -- Order only 1 carton
--            IF @nRowCount = 0
--               GOTO Quit
--            
--            -- Order has 2 cartons
--            ELSE IF @nRowCount = 1
--            BEGIN
--               -- Check other carton in another pallet
--               
--               IF EXISTS( SELECT 1
--                  FROM PalletDetail WITH (NOLOCK)
--                  WHERE StorerKey = @cStorerKey
--                     AND CaseID = @cOtherTrackNo
--                     AND PalletKey <> @cPalletKey)
--               BEGIN
--                  SET @nErrNo = 130601
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderInDiffPLT
--                  GOTO Quit
--               END
--            END
--            
--            -- Order more then 2 cartons
--            ELSE 
--            BEGIN
--               IF EXISTS( SELECT 1
--                  FROM PalletDetail WITH (NOLOCK)
--                  WHERE StorerKey = @cStorerKey
--                     AND CaseID IN (
--                        SELECT TrackingNo
--                        FROM CartonTrack WITH (NOLOCK) 
--                        WHERE LabelNo = @cOrderKey
--                           AND CarrierName = @cShipperKey)
--                     AND PalletKey <> @cPalletKey)
--               BEGIN
--                  SET @nErrNo = 130602
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderInDiffPLT
--                  GOTO Quit
--               END
--            END
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
               INSERT INTO @tOrders (OrderKey, ShipperKey,SUSR1)
               SELECT DISTINCT O.OrderKey, O.ShipperKey,S.SUSR1
               FROM PalletDetail PD WITH (NOLOCK)
                  JOIN CartonTrack CT WITH (NOLOCK) ON (PD.StorerKey = @cStorerKey AND PD.CaseID = CT.TrackingNo)
                  JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey)
                  JOIN STORER S WITH (NOLOCK) ON (O.SHIPPERKEY = S.STORERKEY AND CT.CARRIERNAME = S.SUSR1)
               WHERE PD.PalletKey = @cPalletKey
               
               -- Get all orders track no
               SELECT @nOrderTrackNo = COUNT(1)
               FROM CartonTrack CT WITH (NOLOCK)
                  JOIN @tOrders O ON (CT.LabelNo = O.OrderKey AND CT.CARRIERNAME = O.SUSR1)

               -- Check all track no scanned
               IF @nPalletTrackNo <> @nOrderTrackNo
               BEGIN
                  SET @nErrNo = 156203
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