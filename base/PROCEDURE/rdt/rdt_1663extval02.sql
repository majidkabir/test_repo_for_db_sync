SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtVal02                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2017-09-29 1.0  Ung      WMS-3128 Created                                  */
/* 2017-10-16 1.1  Ung      Performance tuning (remove @tVar)                 */
/* 2018-04-24 1.2  WinSern  Revised Logic (INC0208496)                        */
/* 2021-04-16 1.3  James    WMS-16024 Standarized use of TrackingNo (james01) */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663ExtVal02](
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
      --UserDefine04 NVARCHAR( 40) NOT NULL  --WinSern
      TrackingNo NVARCHAR( 40) NOT NULL  -- (james01)
   )

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      IF @nStep = 3 -- Track no
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cCCountry      NVARCHAR( 30)
            DECLARE @cOrderType     NVARCHAR( 10)
            DECLARE @cUserDefine02  NVARCHAR( 20)

            DECLARE @cOtherOrderkey    NVARCHAR( 10)
            DECLARE @cOtherCCountry    NVARCHAR( 30)
            DECLARE @cOtherOrderType   NVARCHAR( 10)
            DECLARE @cOtherUserDefine02 NVARCHAR( 20)
            
            -- Get order info
            SET @cUserDefine02 = ''
            SET @cCCountry = ''
            SET @cOrderType = ''
            SELECT
               @cUserDefine02 = ISNULL( RTRIM( UserDefine02), ''), 
               @cCCountry = ISNULL( RTRIM( C_Country), ''), 
               @cOrderType = ISNULL( RTRIM( Type), '')
            FROM dbo.Orders WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            -- Get other order, on this pallet
            SET @cOtherOrderKey = ''
            SELECT TOP 1 
               @cOtherOrderKey = O.OrderKey
            FROM dbo.MBOLDetail MD WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = MD.OrderKey)
            WHERE MD.MBOLKey = @cMBOLKey
               AND O.OrderKey <> @cOrderKey

            -- Other order
            IF @cOtherOrderKey <> ''
            BEGIN
               -- Get other order info
               SET @cOtherUserDefine02 = ''
               SET @cOtherCCountry = ''
               SET @cOtherOrderType = ''
               SELECT
                  @cOtherUserDefine02 = ISNULL( RTRIM( UserDefine02), ''), 
                  @cOtherCCountry = ISNULL( RTRIM( C_Country), ''), 
                  @cOtherOrderType = ISNULL( RTRIM( Type), '')
               FROM dbo.Orders WITH (NOLOCK)
               WHERE OrderKey = @cOtherOrderKey
   
               -- Cannot Mix UserDefine02 --
               IF @cUserDefine02 <> @cOtherUserDefine02
               BEGIN
                  SET @nErrNo = 115403
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UDF02 Diff
                  GOTO QUIT
               END
   
               -- Cannot Mix CCountry --
               IF @cCCountry <> @cOtherCCountry
               BEGIN
                  SET @nErrNo = 115404
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Country Diff
                  GOTO QUIT
               END
   
               -- Cannot Mix OrderType --
               IF @cOrderType <> @cOtherOrderType
               BEGIN
                  SET @nErrNo = 115405
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderTypeDiff
                  GOTO QUIT
               END
            END
            
            DECLARE @cOtherTrackNo NVARCHAR( 20)
            DECLARE @nRowCount INT

            -- Get other carton in order
            SELECT @cOtherTrackNo = TrackingNo
            FROM CartonTrack WITH (NOLOCK) 
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
                  SET @nErrNo = 111401
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
                  SET @nErrNo = 111402
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
               --INSERT INTO @tOrders (OrderKey, UserDefine04)  --WinSern
               --SELECT DISTINCT O.OrderKey, O.UserDefine04  --WinSern
               INSERT INTO @tOrders (OrderKey, TrackingNo)  --(james01)
               SELECT DISTINCT O.OrderKey, O.TrackingNo  --(james01)
               FROM PalletDetail PD WITH (NOLOCK)
                  JOIN CartonTrack CT WITH (NOLOCK) ON (PD.StorerKey = @cStorerKey AND PD.CaseID = CT.TrackingNo)
                  JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey AND CT.TrackingNo = O.TrackingNo)  --WinSern/(james01)
               WHERE PD.PalletKey = @cPalletKey

               -- Get all orders track no
               SELECT @nOrderTrackNo = COUNT(1)
               FROM CartonTrack CT WITH (NOLOCK)
                  JOIN @tOrders O ON (CT.LabelNo = O.OrderKey AND CT.TrackingNo = O.TrackingNo)  --WinSern/(james01)

               -- Check all track no scanned
               IF @nPalletTrackNo <> @nOrderTrackNo
               BEGIN
                  SET @nErrNo = 115406
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