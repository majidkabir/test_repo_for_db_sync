SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtUpd08                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2022-03-24 1.0  Ung      WMS-19221 Created (base on rdt_1663ExtUpd01)      */
/* 2023-04-14 1.1  ZG       INC2056448 Add-On ISNULL (ZG01)                   */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1663ExtUpd08](
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

   DECLARE @bSuccess INT

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
               DECLARE @cPickSlipNo    NVARCHAR( 10)
               DECLARE @nCartonNo      INT
               DECLARE @nCube          FLOAT
               DECLARE @nWeight        FLOAT
               DECLARE @nCartonWeight  FLOAT
               DECLARE @nOrderTrackNo  INT
               DECLARE @nPalletTrackNo INT
               DECLARE @cOtherTrackNo  NVARCHAR( 20)
               DECLARE @nRowCount      INT

               -- Get pack info
               SELECT @cPickSlipNo = PickSlipNo FROM dbo.PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
               SELECT 
                  @nCartonNo = CartonNo, 
                  @cCartonType = CartonType, 
                  @nCube = Cube
               FROM dbo.PackInfo WITH (NOLOCK) 
               WHERE PickSlipNo = @cPickSlipNo 
                  AND TrackingNo = @cTrackno

               -- Free size carton type, don't have a cube, so take from SKU
               IF @cCartonType = 'KUAIDIDAI'
                  SELECT @nCube = ISNULL( SUM( SKU.STDCube * PD.QTY), 0)
                  FROM dbo.PackDetail PD WITH (NOLOCK) 
                     JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
                  WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCartonNo

               -- Weight (of SKU)
               SELECT @nWeight = ISNULL( SUM( SKU.STDGrossWGT * PD.QTY), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK) 
                  JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
               WHERE PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
               
               -- Weight (of empty carton)
               SELECT @nCartonWeight = CartonWeight
               FROM Cartonization C WITH (NOLOCK)
                  JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
               WHERE S.StorerKey = @cStorerKey
                  AND C.CartonType = @cCartonType
                  
               -- Total carton weight
               SET @nWeight = @nWeight + @nCartonWeight
               
               -- Update MBOL             
               UPDATE dbo.MBOLDetail SET
                   Cube     = Cube + ISNULL(@nCube, 0),      --ZG01 
                   Weight   = Weight + ISNULL(@nWeight, 0),  --ZG01 
                   EditWho  = SUSER_SNAME(),
                   EditDate = GETDATE(), 
                   TrafficCop = NULL -- ntrMBOLDetailUpdate could configure to update cube, weight
               WHERE MBOLKey = @cMBOLKey
                  AND OrderKey = @cOrderKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 185601
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MBDtl Fail
               END
               
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
                           , '9'           -- Key2    --(yeekung01)
                           , @cStorerKey  -- Key3
                           , ''           -- Batch
                           , @bSuccess  OUTPUT
                           , @nErrNo    OUTPUT
                           , @cErrMsg   OUTPUT
                     ELSE
                        EXEC dbo.ispGenTransmitLog3
                             @cTableName  -- TableName
                           , @cOrderKey   -- Key1
                           , '9'           -- Key2   --(yeekung01)
                           , @cStorerKey  -- Key3
                           , ''           -- Batch
                           , @bSuccess  OUTPUT
                           , @nErrNo    OUTPUT
                           , @cErrMsg   OUTPUT
                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 185602
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG3 Fail
                        GOTO Quit
                     END
                  END
               END
            END
         END
      END
   END

Quit:

END

GO