SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtUpd05                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2020-01-14 1.1  James    WMS-11523. Created                                */
/* 2021-10-13 1.2  YeeKung  WMS-18033 Add key2 to 9 (yeekung01)               */ 
/* 2023-04-14 1.3  Ung      WMS-22284 Fix TrackOrderWeight SValue             */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1663ExtUpd05](
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

   DECLARE @bSuccess       INT
   DECLARE @nWeight        FLOAT
   DECLARE @nGiftWeight    FLOAT
   DECLARE @nCartonWeight  FLOAT
   DECLARE @nMaxWeight     FLOAT
   DECLARE @cDeliveryNote  NVARCHAR( 10)
   DECLARE @cECOM_SINGLE_Flag NVARCHAR( 1)
   
   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      IF @nStep = 3 OR -- Track no
         @nStep = 4 OR -- Weight
         @nStep = 5    -- Carton type
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- MBOLDetail created
            IF EXISTS( SELECT 1 FROM MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
            BEGIN
               DECLARE @nOrderTrackNo  INT
               DECLARE @nPalletTrackNo INT
               DECLARE @cOtherTrackNo  NVARCHAR( 20)
               DECLARE @nRowCount INT
   
               -- Get other carton in order
               SELECT @cOtherTrackNo = TrackingNo
               FROM CartonTrack WITH (NOLOCK, INDEX = idx_cartontrack_LabelNo)   -- (james01) 
               WHERE LabelNo = @cOrderKey
                  AND CarrierName = @cShipperKey
                  AND TrackingNo <> @cTrackNo
               SET @nRowCount = @@ROWCOUNT
               
               -- Order only 1 carton
               IF @nRowCount = 0
               BEGIN
                  SET @nOrderTrackNo = 1
                  SET @nPalletTrackNo = 1
               END
               
               -- Order has 2 cartons
               ELSE IF @nRowCount = 1
               BEGIN
                  SET @nOrderTrackNo = 2
                  SET @nPalletTrackNo = 1
                  
                  -- Check other carton in had scanned to pallet
                  IF EXISTS( SELECT 1
                     FROM PalletDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND CaseID = @cOtherTrackNo)
                  BEGIN
                     SET @nPalletTrackNo = 2
                  END
               END
               
               -- Order more then 2 cartons
               ELSE 
               BEGIN
                  SET @nOrderTrackNo = @nRowCount + 1
                  
                  SELECT @nPalletTrackNo = COUNT(1)
                  FROM PalletDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND CaseID IN (
                        SELECT TrackingNo
                        FROM CartonTrack WITH (NOLOCK) 
                        WHERE LabelNo = @cOrderKey
                           AND CarrierName = @cShipperKey)
               END               
               
               -- All track no of the order scanned
               IF @nPalletTrackNo > 0 AND 
                  @nOrderTrackNo > 0 AND 
                  @nPalletTrackNo = @nOrderTrackNo 
               BEGIN
                  -- Get interface info
                  DECLARE @cShort NVARCHAR(10)
                  DECLARE @cTableName NVARCHAR(30)
                  SELECT 
                     @cShort = ISNULL( Short, ''), 
                     @cTableName = LEFT( ISNULL( Long, ''), 30)
                  FROM CodeLKUP WITH (NOLOCK)
                  WHERE ListName = 'CARRIERITF'
                     AND Code = @cShipperKey
                     AND StorerKey = @cStorerKey
                     AND Code2 = @nFunc
                  
                  -- Send order confirm to carrier
                  IF @@ROWCOUNT > 0
                  BEGIN
                     IF @cShort = '2'
                        EXEC dbo.ispGenTransmitLog2
                             @cTableName  -- TableName
                           , @cOrderKey   -- Key1
                           , '9'           -- Key2
                           , @cStorerKey  -- Key3
                           , ''           -- Batch
                           , @bSuccess  OUTPUT
                           , @nErrNo    OUTPUT
                           , @cErrMsg   OUTPUT
                     ELSE
                        EXEC dbo.ispGenTransmitLog3 
                             @cTableName  -- TableName
                           , @cOrderKey   -- Key1
                           , '9'           -- Key2
                           , @cStorerKey  -- Key3
                           , ''           -- Batch
                           , @bSuccess  OUTPUT
                           , @nErrNo    OUTPUT
                           , @cErrMsg   OUTPUT
                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 150851
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG3 Fail
                        GOTO Quit
                     END
                  END
               END
               
               -- (james02)
               -- Update mboldetail.weight here
               -- If config turn off then user will key in weight on the screen
               IF rdt.rdtGetConfig( @nFunc, 'TrackOrderWeight', @cStorerKey) = '0' AND 
                  @nStep = 3
               BEGIN
                  SET @nGiftWeight = 0
                  SET @nWeight = 0
                  SET @nCartonWeight = 0
                  
                  SELECT @nCartonWeight = CZ.CartonWeight * 1, 
                         @nMaxWeight = cz.MaxWeight
                  FROM dbo.CARTONIZATION CZ WITH (NOLOCK)
                  JOIN dbo.STORER ST WITH (NOLOCK) ON ( CZ.CartonizationGroup = ST.CartonGroup)
                  WHERE ST.StorerKey = @cStorerKey
                  AND   CZ.CartonType = @cCartonType

                  SELECT @nWeight = ISNULL( SUM( SKU.STDGrossWGT * PD.QTY), 0) 
                  FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                  WHERE PD.OrderKey = @cOrderKey

                  SELECT @cDeliveryNote = DeliveryNote, 
                         @cECOM_SINGLE_Flag = ECOM_SINGLE_Flag
                  FROM dbo.ORDERS WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  
                  IF @cECOM_SINGLE_Flag = 'S'
                     SET @nMaxWeight = @nMaxWeight * 0
                  ELSE IF @cECOM_SINGLE_Flag = 'M'
                     SET @nMaxWeight = @nMaxWeight * 1

                  IF ISNULL( @cDeliveryNote, '') <> ''
                  BEGIN
                     --SELECT @nGiftWeight = ISNULL( SUM( SKU.STDGrossWGT * 1), 0) 
                     --FROM dbo.PickDetail PD WITH (NOLOCK) 
                     --JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                     --WHERE PD.OrderKey = @cOrderKey
                     --AND   SKU.BUSR1 = @cDeliveryNote

                     SELECT @nGiftWeight = ISNULL( SUM( SKU.STDGrossWGT * 1), 0) 
                     FROM dbo.SKU SKU WITH (NOLOCK) 
                     WHERE SKU.StorerKey = @cStorerKey
                     AND   SKU.BUSR1 = @cDeliveryNote
                  END
                  
                  UPDATE dbo.MBOLDetail WITH (ROWLOCK) SET 
                     WEIGHT = ( @nCartonWeight + @nWeight + @nGiftWeight + @nMaxWeight)
                  WHERE MBOLKey = @cMBOLKey 
                  AND   OrderKey = @cOrderKey
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 150852
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MBDtl Fail
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