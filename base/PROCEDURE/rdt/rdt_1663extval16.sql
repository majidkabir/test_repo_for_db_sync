SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtVal16                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2021-09-24 1.0  James    WMS-17778 Created base on rdt_1663ExtVal04        */
/* 2021-11-11 1.1  Pakyuen  INC1667905 (PY01)                                 */   
/* 2022-01-26 1.2  Ung      WMS-18622 Change pallet must be same shipper to   */
/*                          same shipper group                                */
/* 2022-01-25 1.3  Ung      WMS-18774 Add check MBOL field                    */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1663ExtVal16](
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

   DECLARE @cActTrackingNo    NVARCHAR( 60)
   DECLARE @nEstCtnCount      INT
   DECLARE @nCtnCount         INT
   DECLARE @nStart            INT
   DECLARE @nEnd              INT
   DECLARE @cUserdefine10     NVARCHAR(20)
   DECLARE @cVerifyM_FAX2     NVARCHAR( 1)
   DECLARE @cVerifyM_UDF5     NVARCHAR( 1)
   DECLARE @cVerifyM_OthRef   NVARCHAR( 1)
   DECLARE @cM_Fax2           NVARCHAR( 18)
   DECLARE @cOtherM_Fax2      NVARCHAR( 18)
   DECLARE @cOtherOrderKey    NVARCHAR( 10)
   DECLARE @cOrdShipperKey    NVARCHAR( 15)
   DECLARE @cVerifyShipperKey NVARCHAR( 1)
   DECLARE @nExists           INT
   DECLARE @cOtherShipperkey  NVARCHAR( 15)  
   DECLARE @cOtherM_Fax2Group   NVARCHAR( 30)  
   DECLARE @cM_Fax2Group        NVARCHAR( 30)  

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      IF @nStep = 1 -- PalletKey
      BEGIN
         IF EXISTS ( SELECT 1 FROM codelkup (NOLOCK)
                     WHERE storerkey =@cStorerKey
                        AND LISTNAME='IKCourier'
                        AND long=LEFT(@cPalletKey,5))
         BEGIN
            IF EXISTS ( SELECT 1 FROM codelkup (NOLOCK)
                        WHERE storerkey =@cStorerKey
                           AND LISTNAME='IKCourier'
                           AND long=LEFT(@cPalletKey,5)
                           AND CODE2 <> @cFacility)
            BEGIN
               SET @nErrNo = 176157
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPallet
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 176159
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPallet
            GOTO Quit
         END
      END

      IF @nStep = 3 -- Track no
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cActTrackingNo = I_Field03
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

            SELECT @cUserdefine10=LEFT(userdefine10,4),
                   @cM_Fax2 = ISNULL( RTRIM( M_Fax2), ''),
                   @cOrdShipperKey = o.ShipperKey
            FROM dbo.orders (NOLOCK) o JOIN cartontrack (NOLOCK) CT on
            o.orderkey=CT.labelno
            WHERE ct.TrackingNo=@cTrackNo AND storerkey=@cStorerKey

            -- (james01)
            IF @cShipperKey <> 'SN'
            BEGIN
               IF @cTrackNo NOT LIKE '%-%'
               BEGIN
                  SET @nErrNo = 176154
                  SET @cErrMsg =  rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Track No
                  GOTO Quit
               END
            END

            -- (james04)
            SET @cVerifyShipperKey = rdt.rdtGetConfig( @nFunc, 'VerifyShipperKey', @cStorerKey)
            SET @nExists = 0

            IF @cVerifyShipperKey = '0'
            BEGIN
               SELECT @nExists = COUNT( 1)
               FROM codelkup (NOLOCK) --(yeekung01)
               WHERE storerkey =@cStorerKey
                  AND LISTNAME='IKCourier'
                  AND long=LEFT(@cPalletKey,5)
                  AND CODE2 = @cFacility
                  AND short <> LEFT (@cTrackNo,2)
            END
            ELSE
            BEGIN
               SELECT @nExists = COUNT( 1)
               FROM dbo.CODELKUP WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   LISTNAME = 'IKCourier'
               AND   Long = LEFT(@cPalletKey,5)
               AND   code2 = @cFacility
               AND   Short <> @cOrdShipperKey
            END

            IF @nExists = 1
            BEGIN
               SET @nErrNo = 176158
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidTrackNo
               GOTO Quit
            END

            IF EXISTS ( SELECT 1 FROM codelkup (NOLOCK) --(yeekung01)
            WHERE storerkey =@cStorerKey
               AND LISTNAME='IKCourier'
               AND code2=@cfacility
               AND LEFT(long,4) <> LEFT(@cuserdefine10,4)
               AND long=LEFT(@cPalletKey,5))
            BEGIN
               SET @nErrNo = 176160
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidTrackNo
               GOTO Quit
            END

            -- (james02)
            IF @cShipperKey = ''
            BEGIN
               --Actual track no on label will have extra 3 chars
               -- After scan will decode and remove last 3 chars
               --TrackNo = 'JD0001-1-2- 2 = total 2 carton
               SET @nStart = CHARINDEX( '-', @cActTrackingNo, ( CHARINDEX('-', @cActTrackingNo, 1)) + 2) + 1
               SET @nEnd = CHARINDEX('-', @cActTrackingNo, @nStart)                                                  -- ZG01
               --SET @nEnd = CHARINDEX( '-', @cActTrackingNo, ( CHARINDEX('-', @cActTrackingNo, 1)) + 4)             -- ZG01
               SET @nCtnCount = CAST( SUBSTRING( @cActTrackingNo, @nStart, @nEnd - @nStart) AS INT)

               -- Tracking no on orders do not have '-'
               SELECT @cOrderKey = OrderKey
               FROM dbo.ORDERS WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   TrackingNo = LEFT( @cActTrackingNo, CHARINDEX( '-', @cActTrackingNo, ( CHARINDEX( '-', @cActTrackingNo, 1))) - 1) -- (james03)

               IF @@ROWCOUNT = 0
                  SELECT TOP 1 @cOrderKey = LabelNo
                  FROM dbo.CartonTrack WITH (NOLOCK)
                  WHERE TrackingNo = @cTrackNo
                  AND   CarrierRef2 = 'GET'
                  AND   LabelNo <> ''  -- to use index
                  ORDER BY 1

               IF ISNULL( @cOrderKey, '') <> ''
               BEGIN
                  SELECT @nEstCtnCount = EstimateTotalCtn
                  FROM dbo.PackHeader WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   OrderKey = @cOrderKey
                  AND   [Status] = '9'    -- (james02)

                  -- Total carton count on label not match estimated
                  IF ISNULL( @nCtnCount, 0) <> ISNULL( @nEstCtnCount, 0)
                  BEGIN
                     SET @nErrNo = 176155
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CtnCountNotMatch
                     GOTO Quit
                  END
               END
               ELSE
               BEGIN
                  SET @nErrNo = 176156
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Track No
                  GOTO Quit
               END
            END

            -- (james04)
            SET @cVerifyM_FAX2 = rdt.rdtGetConfig( @nFunc, 'VerifyM_FAX2', @cStorerKey)
            IF @cVerifyM_FAX2 = '1'
            BEGIN
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
                  SET @cOtherM_Fax2 = ''
                  SELECT @cOtherM_Fax2 = ISNULL( RTRIM( M_Fax2), '')
                  FROM dbo.Orders WITH (NOLOCK)
                  WHERE OrderKey = @cOtherOrderKey

                  SET @cOtherM_Fax2Group = ''  
                  SELECT @cOtherM_Fax2Group = Short     
                  FROM dbo.CODELKUP WITH (NOLOCK)     
                  WHERE ListName = 'CourierVal'  
                  AND   Code = @cOtherM_Fax2    
                  AND   StorerKey = @cStorerKey    
   
                  SET @cM_Fax2Group = ''  
                  SELECT @cM_Fax2Group = Short     
                  FROM dbo.CODELKUP WITH (NOLOCK)     
                  WHERE ListName = 'CourierVal'  
                  AND   Code = @cM_Fax2    
                  AND   StorerKey = @cStorerKey    
                    
                  -- Cannot Mix CCountry --
                  IF @cM_Fax2Group <> @cOtherM_Fax2Group  
                  BEGIN
                     SET @nErrNo = 176161
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv ShipperKey
                     GOTO QUIT
                  END
               END
            END

            -- Get MBOL info
            DECLARE @cUserdefine05 NVARCHAR( 20)
            DECLARE @cOtherReference NVARCHAR( 30)
            SELECT
               @cUserdefine05 = ISNULL( Userdefine05, ''),
               @cOtherReference = OtherReference
            FROM dbo.MBOL WITH (NOLOCK)
            WHERE MBOLKey = @cMBOLKey

            SET @cVerifyM_UDF5 = rdt.rdtGetConfig( @nFunc, 'VerifyM_UDF5', @cStorerKey)
            IF @cVerifyM_UDF5 = '1'
            BEGIN
               IF @cUserdefine05 = ''
               BEGIN
                  SET @nErrNo = 176162
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv MBOL.UDF5
                  GOTO Quit
               END
            END

            SET @cVerifyM_OthRef = rdt.rdtGetConfig( @nFunc, 'VerifyM_OthRef', @cStorerKey)
            IF @cVerifyM_OthRef = '1'
            BEGIN
               IF @cOtherReference = ''
               BEGIN
                  SET @nErrNo = 176163
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv MBOL.OthRef
                  GOTO Quit
               END
            END

            DECLARE @cOtherTrackNo NVARCHAR( 20)
            DECLARE @nRowCount INT

            -- Get other carton in order
            SELECT @cOtherTrackNo = TrackingNo
            FROM CartonTrack WITH (NOLOCK)
            WHERE LabelNo = @cOrderKey
               -- AND CarrierName = @cShipperKey
               AND @cShipperKey LIKE CarrierName + '%'  -- ShipperKey = SF1, CarrierName = SF
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
                  SET @nErrNo = 176151
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
                           --AND CarrierName = @cShipperKey)
                           AND @cShipperKey LIKE CarrierName + '%' )
                     AND PalletKey <> @cPalletKey)
               BEGIN
                  SET @nErrNo = 176152
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
               DECLARE @cTempTrackNo      NVARCHAR( 20)
               DECLARE @cTempShipperKey   NVARCHAR( 15)

               -- Get pallet info
               SELECT @nPalletTrackNo = COUNT(1) FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey

               SELECT TOP 1 @cTempTrackNo = CaseId
               FROM dbo.PALLETDETAIL WITH (NOLOCK)
               WHERE PalletKey = @cPalletKey
               ORDER BY 1

               SELECT @cTempShipperKey = ShipperKey
               FROM dbo.ORDERS WITH (NOLOCK)
               WHERE TrackingNo = @cTempTrackNo

               IF @cTempShipperKey = 'SN'
               BEGIN
                  -- Get order in pallet
                  INSERT INTO @tOrders (OrderKey, ShipperKey)
                  SELECT DISTINCT O.OrderKey, O.M_Fax2
                  FROM PalletDetail PD WITH (NOLOCK)
                     JOIN CartonTrack CT WITH (NOLOCK) ON (PD.StorerKey = @cStorerKey AND PD.CaseID = CT.TrackingNo)
                     JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey AND O.M_Fax2 LIKE CT.CarrierName + '%')
                  WHERE PD.PalletKey = @cPalletKey

                  -- Get all orders track no
                  SELECT @nOrderTrackNo = COUNT(1)
                  FROM CartonTrack CT WITH (NOLOCK)
                     JOIN @tOrders O ON (CT.LabelNo = O.OrderKey AND O.ShipperKey LIKE CT.CarrierName + '%')
                  --WHERE CT.TrackingNo LIKE '%-%'
                  WHERE (( O.ShipperKey in ('SN', 'SF', 'ZT1', 'ZT2') AND CT.TrackingNo NOT LIKE '%-%') OR ( O.ShipperKey <> 'SN' AND CT.TrackingNo LIKE '%-%'))
               END
               ELSE
               BEGIN
                  -- Get order in pallet
                  INSERT INTO @tOrders (OrderKey, ShipperKey)
                  SELECT DISTINCT O.OrderKey, O.ShipperKey
                  FROM PalletDetail PD WITH (NOLOCK)
                     JOIN CartonTrack CT WITH (NOLOCK) ON (PD.StorerKey = @cStorerKey AND PD.CaseID = CT.TrackingNo)
                    -- JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey AND O.ShipperKey LIKE CT.CarrierName + '%')    
                     JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey )  --py01  
                  WHERE PD.PalletKey = @cPalletKey

                  -- Get all orders track no
                  SELECT @nOrderTrackNo = COUNT(1)
                  FROM CartonTrack CT WITH (NOLOCK)
                    -- JOIN @tOrders O ON (CT.LabelNo = O.OrderKey AND O.ShipperKey LIKE CT.CarrierName + '%')    
                    JOIN @tOrders O ON (CT.LabelNo = O.OrderKey )  --py01  
                  --WHERE CT.TrackingNo LIKE '%-%'
                  WHERE (( O.ShipperKey = 'SN' AND CT.TrackingNo NOT LIKE '%-%') OR ( O.ShipperKey <> 'SN' AND CT.TrackingNo LIKE '%-%'))
               END

               -- Check all track no scanned
               IF @nPalletTrackNo <> @nOrderTrackNo
               BEGIN
                  SET @nErrNo = 176153
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