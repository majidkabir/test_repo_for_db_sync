SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtVal22                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2023-01-10 1.0  yeekung  WMS-21497 Created                                 */
/* 2023-08-29 1.1  yeekung  JSM-168168 Add left 10 character labelno          */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1663ExtVal22](
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
            DECLARE @cOtherSalesman  NVARCHAR(20)
            DECLARE @cSalesman  NVARCHAR(20)


            SELECT TOP 1 @cOtherSalesman = O.Salesman 
            FROM PalletDetail PD WITH (NOLOCK)
               JOIN CartonTrack CT WITH (NOLOCK) ON (PD.StorerKey = @cStorerKey AND PD.CaseID = CT.TrackingNo)
               JOIN Orders O WITH (NOLOCK) ON (LEFT(CT.LabelNo,10) = O.OrderKey AND CT.CarrierName = O.ShipperKey)
            WHERE PD.PalletKey = @cPalletKey
            SET @nRowCount = @@ROWCOUNT

            IF @nRowCount  >=1
            BEGIN
               SELECT  @cSalesman = Salesman 
               FROM ORDERS (NOLOCK)
               WHERE orderkey=@cOrderkey
                  AND storerkey=@cstorerkey
            
               IF (@cSalesman <>@cOtherSalesman)
               BEGIN
                  SET @nErrNo = 195704
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderDiffISO
                  GOTO Quit
               END
            END

            SET @nRowCount=0
            -- Get other carton in order
            SELECT @cOtherTrackNo = TrackingNo
            FROM CartonTrack WITH (NOLOCK)
            WHERE LEFT(LabelNo,10) = @cOrderKey
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
                  SET @nErrNo = 195701
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
                        WHERE LEFT(LabelNo,10) = @cOrderKey
                           AND CarrierName = @cShipperKey)
                     AND PalletKey <> @cPalletKey)
               BEGIN
                  SET @nErrNo = 195702
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
                  JOIN Orders O WITH (NOLOCK) ON (LEFT(CT.LabelNo,10) = O.OrderKey AND CT.CarrierName = O.ShipperKey)
               WHERE PD.PalletKey = @cPalletKey

               -- Get all orders track no
               SELECT @nOrderTrackNo = COUNT(1)
               FROM CartonTrack CT WITH (NOLOCK)
                  JOIN @tOrders O ON (LEFT(CT.LabelNo,10)  = O.OrderKey AND CT.CarrierName = O.ShipperKey)

               -- Check all track no scanned
               IF @nPalletTrackNo <> @nOrderTrackNo
               BEGIN
                  SET @nErrNo = 195703
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