SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_1663ExtVal08                                          */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Prompt error if not all carton for the orders are scanned         */  
/*                                                                            */  
/* Date       Rev  Author   Purposes                                          */  
/* 2019-04-24 1.0  James    WMS-8751 Created                                  */  
/* 2020-08-28 1.1  YeeKung  WMS-14798 Add listname='CourierVal' (yeekung01)   */
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_1663ExtVal08](  
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
      TrackingNo NVARCHAR( 20) NOT NULL  
   )  
  
   DECLARE @cOrderKey1  NVARCHAR( 10)  
   DECLARE @cOrderKey2  NVARCHAR( 10)  
   DECLARE @cOrderKey3  NVARCHAR( 10)  
   DECLARE @cOrderKey4  NVARCHAR( 10)  
   DECLARE @cOrderKey5  NVARCHAR( 10)  
   DECLARE @cErrMsg1    NVARCHAR( 20)  
   DECLARE @cErrMsg2    NVARCHAR( 20)  
   DECLARE @cErrMsg3    NVARCHAR( 20)  
   DECLARE @cErrMsg4    NVARCHAR( 20)  
   DECLARE @cErrMsg5    NVARCHAR( 20)  
   DECLARE @cErrMsg6    NVARCHAR( 20)  
   DECLARE @cErrMsg7    NVARCHAR( 20)  
   DECLARE @cErrMsg8    NVARCHAR( 20)  
   DECLARE @cErrMsg9    NVARCHAR( 20)  
   DECLARE @cErrMsg10   NVARCHAR( 20)  
   DECLARE @n           INT  
   DECLARE @cCourrierGroup NVARCHAR( 20) 
   DECLARE @cOtherOrderKey NVARCHAR(20) 
   DECLARE @cOtherCourrierGroup NVARCHAR(20)
   DECLARE @cOtherShipperkey NVARCHAR(20)
  
   IF @nFunc = 1663 -- TrackNoToPallet  
   BEGIN  
      SELECT @cShipperKey = ShipperKey  
      FROM dbo.Orders WITH (NOLOCK)  
      WHERE OrderKey = @cOrderKey  
  
      IF @nStep = 3 -- Tracking No  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            IF @cTrackNo NOT LIKE '%-%' AND @cShipperKey = 'JD'  
            BEGIN  
               SET @nErrNo = 138304  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv TrackingNo  
               GOTO Quit  
            END  

            SELECT @cCourrierGroup=short 
            FROM codelkup (NOLOCK) 
            where code=@cShipperkey
            and storerkey=@cstorerkey
            and listname='CourierVal'

            IF @@Rowcount=0
            BEGIN
               SET @nErrNo = 138305
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GroupNoSetup
               GOTO QUIT
            END

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
               SET @cOtherCourrierGroup=''
               SET @cOtherShipperkey=''
               SELECT
                  @cOtherShipperkey =ISNULL( RTRIM( shipperkey), '')
               FROM dbo.Orders WITH (NOLOCK)
               WHERE OrderKey = @cOtherOrderKey

               SELECT @cOtherCourrierGroup=short 
               FROM codelkup (NOLOCK) 
               where code=@cOtherShipperkey
               and storerkey=@cstorerkey
               and listname='CourierVal'

               IF @cOtherCourrierGroup<>@cCourrierGroup
               BEGIN
                  SET @nErrNo = 138306
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CourierGrpDiff
                  GOTO QUIT
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
               INSERT INTO @tOrders (OrderKey, ShipperKey, TrackingNo)  
               SELECT DISTINCT O.OrderKey, O.ShipperKey, PD.CaseId  
               FROM PalletDetail PD WITH (NOLOCK)  
                  JOIN CartonTrack CT WITH (NOLOCK) ON (PD.StorerKey = @cStorerKey AND PD.CaseID = CT.TrackingNo)  
                  JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey AND CT.CarrierName = O.ShipperKey)  
               WHERE PD.PalletKey = @cPalletKey  
                 
               -- Get all orders track no  
               SELECT @nOrderTrackNo = COUNT(1)  
               FROM CartonTrack CT WITH (NOLOCK)  
                  JOIN @tOrders O ON (CT.LabelNo = O.OrderKey AND CT.CarrierName = O.ShipperKey)  
  
          SET @cOrderKey1 = ''  
               SET @cOrderKey2 = ''  
               SET @cOrderKey3 = ''  
               SET @cOrderKey4 = ''  
               SET @cOrderKey5 = ''  
  
               -- Check all track no scanned  
               IF @nPalletTrackNo <> @nOrderTrackNo  
               BEGIN  
                  SET @n = 1  
                  DECLARE @curOrd CURSOR    
                  SET @curOrd = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
                  SELECT DISTINCT TOP 5 CT.LabelNo  
                  FROM dbo.CartonTrack CT WITH (NOLOCK)  
                  JOIN @tOrders O ON CT.LabelNo = O.OrderKey AND CT.CarrierName = O.ShipperKey  
                  WHERE ( ( CT.TrackingNo LIKE '%-%' AND O.ShipperKey = 'JD') OR ( O.ShipperKey <> 'JD' AND 1= 1))  -- exclude original tracking no which doesn't have '-'  
                  AND   NOT EXISTS (  
                            SELECT 1 FROM PalletDetail PD WITH (NOLOCK)  
                            WHERE PD.PalletKey = @cPalletKey   
                            AND   PD.StorerKey = @cStorerKey   
                            AND   PD.CaseID = CT.TrackingNo )  
                  ORDER BY 1  
                  OPEN @curOrd  
                  FETCH NEXT FROM @curOrd INTO @cOrderKey  
                  WHILE @@FETCH_STATUS = 0  
                  BEGIN  
                     IF @n = 1 SET @cOrderKey1 = @cOrderKey  
                     IF @n = 2 SET @cOrderKey2 = @cOrderKey  
                     IF @n = 3 SET @cOrderKey3 = @cOrderKey  
                     IF @n = 4 SET @cOrderKey4 = @cOrderKey  
                     IF @n = 5 SET @cOrderKey5 = @cOrderKey  
  
                     SET @n = @n + 1  
                     IF @n > 5  
                        BREAK  
  
                     FETCH NEXT FROM @curOrd INTO @cOrderKey  
                  END  
  
                  IF @cOrderKey1 = '' AND   
                     @cOrderKey2 = '' AND   
                     @cOrderKey3 = '' AND   
                     @cOrderKey4 = '' AND   
                     @cOrderKey5 = ''  
                     GOTO Quit  
  
                  SET @cErrMsg1 = rdt.rdtGetMessage( 138301, @cLangCode, 'DSP') --Not All Ctn Scanned  
                  SET @cErrMsg2 = ''  
                  SET @cErrMsg3 = rdt.rdtGetMessage( 138302, @cLangCode, 'DSP') --Top 5 Order With  
                  SET @cErrMsg4 = rdt.rdtGetMessage( 138303, @cLangCode, 'DSP') --Missing Carton  
                  SET @cErrMsg5 = CASE WHEN ISNULL( @cOrderKey1, '') <> '' THEN '1. ' + @cOrderKey1 ELSE '' END  
                  SET @cErrMsg6 = CASE WHEN ISNULL( @cOrderKey2, '') <> '' THEN '2. ' + @cOrderKey2 ELSE '' END  
                  SET @cErrMsg7 = CASE WHEN ISNULL( @cOrderKey3, '') <> '' THEN '3. ' + @cOrderKey3 ELSE '' END  
                  SET @cErrMsg8 = CASE WHEN ISNULL( @cOrderKey4, '') <> '' THEN '4. ' + @cOrderKey4 ELSE '' END  
                  SET @cErrMsg9 = CASE WHEN ISNULL( @cOrderKey5, '') <> '' THEN '5. ' + @cOrderKey5 ELSE '' END  
                  SET @nErrNo = 0  
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
                     @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4,   
                     @cErrMsg5, @cErrMsg6, @cErrMsg7, @cErrMsg8,   
                     @cErrMsg9  
  
                  IF @nErrNo = 1  
                  BEGIN  
                     SET @cErrMsg1 = ''  
                     SET @cErrMsg2 = ''  
                     SET @cErrMsg3 = ''  
                     SET @cErrMsg4 = ''  
                     SET @cErrMsg5 = ''  
                     SET @cErrMsg6 = ''  
                     SET @cErrMsg7 = ''  
                     SET @cErrMsg8 = ''  
                     SET @cErrMsg9 = ''  
                  END  
  
                  --SET @nErrNo = 137901  
                  --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotAllScanned  
                  GOTO Quit  
               END  
            END  
         END  
      END  
   END  
  
Quit:  
  
END

GO