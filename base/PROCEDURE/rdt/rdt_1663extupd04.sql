SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtUpd04                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2019-08-13 1.0  James    WMS-10127 Created                                 */
/* 2020-08-07 1.1  YeeKung  WMS-14482 add WSSOCFMLOG in ispGenTransmitLog2    */
/*                          change code2=facility and short=func              */
/*                          (yeekung01)                                       */
/* 2021-09-08 1.2  James    WMS-17847 Update weight and carton type to        */
/*                          PackInfo (james01)                                */
/* 2021-10-13 1.3  YeeKung  WMS-18033 Add key2 to 9 (yeekung01)               */
/* 2022-05-12 1.4  Ung      WMS-19643 Move WSSOCFMLOG trigger at order level  */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1663ExtUpd04](
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
   DECLARE @cCarrierRef1   NVARCHAR( 40)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nCartonNo      INT
   DECLARE @cUserName      NVARCHAR( 18)

   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

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
               FROM CartonTrack WITH (NOLOCK)
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
                  -- Get order info
                  DECLARE @cStatus NVARCHAR( 10)
                  DECLARE @cSOStatus NVARCHAR( 10)
                  DECLARE @cDocType NVARCHAR( 1)
                  DECLARE @cECOM_Presale_Flag NVARCHAR( 2)
                  DECLARE @cDeliveryNote NVARCHAR( 10)
                  SELECT 
                     @cStatus = Status, 
                     @cSOStatus = SOStatus, 
                     @cDocType = DocType, 
                     @cECOM_Presale_Flag = ECOM_Presale_Flag, 
                     @cDeliveryNote = DeliveryNote
                  FROM dbo.ORDERS WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  
                  -- Send order confirm interface
                  IF @cDocType= 'E' AND @cStatus = '5' 
                  BEGIN
                     IF (@cSOStatus = '5' AND @cECOM_Presale_Flag = '') OR
                        (@cSOStatus = '5' AND @cECOM_Presale_Flag = 'PR' AND @cDeliveryNote = '30') OR
                        (@cDeliveryNote = '10')
                     BEGIN
                        EXEC dbo.ispGenTransmitLog2
                           'WSSOCFMLOG'   -- TableName
                           , @cOrderKey   -- Key1
                           , 'RDT_9'      -- Key2
                           , @cStorerKey  -- Key3
                           , ''           -- Batch
                           , @bSuccess  OUTPUT
                           , @nErrNo    OUTPUT
                           , @cErrMsg   OUTPUT

                        IF @bSuccess <> 1
                        BEGIN
                           SET @nErrNo = 143054
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG2 Fail
                           GOTO Quit
                        END
                     END
                  END

                  -- Get carrier interface info
                  DECLARE @cShort      NVARCHAR(10)
                  DECLARE @cTableName  NVARCHAR(30)
                  SELECT
                     @cShort = ISNULL( Short, ''),
                     @cTableName = LEFT( ISNULL( Long, ''), 30)
                  FROM CodeLKUP WITH (NOLOCK)
                  WHERE ListName = 'CARRIERITF'
                     AND Code = @cShipperKey
                     AND StorerKey = @cStorerKey
                     AND Code2 = @nFunc

                  -- Send carrier interface
                  IF @@ROWCOUNT > 0
                  BEGIN
                     IF @cShort = '2'
                        EXEC dbo.ispGenTransmitLog2
                             @cTableName  -- TableName
                           , @cOrderKey   -- Key1
                           , '9'           -- Key2  --(yeekung01)
                           , @cStorerKey  -- Key3
                           , ''           -- Batch
                           , @bSuccess  OUTPUT
                           , @nErrNo    OUTPUT
                           , @cErrMsg   OUTPUT
                     ELSE
                        EXEC dbo.ispGenTransmitLog3
                             @cTableName  -- TableName
                           , @cOrderKey   -- Key1
                           , '9'           -- Key2  --(yeekung01)
                           , @cStorerKey  -- Key3
                           , ''           -- Batch
                           , @bSuccess  OUTPUT
                           , @nErrNo    OUTPUT
                           , @cErrMsg   OUTPUT
                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 143051
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG3 Fail
                        GOTO Quit
                     END
                  END
               END

               IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                           WHERE LISTNAME = 'DNoteToChk'
                           AND   Storerkey = @cStorerKey
                           AND   Code = @cDeliveryNote
                           AND   Short = @nFunc
                           AND   code2 = @cFacility)  --(yeekung01)
               BEGIN
                  -- TL record will be inserted from Exceed Ecom pack
                  -- then update transmitflag = 0 else insert new
                  IF EXISTS ( SELECT 1 FROM dbo.TransmitLog2 WITH (NOLOCK)
                              WHERE TableName = 'WSPICKCFMLOG'
                              AND   Key1 = @cOrderKey
                              AND   Key2 = '5'
                              AND   Key3 = @cStorerKey
                              AND   TransmitFlag = 'IGNOR')
                  BEGIN
                     UPDATE dbo.TransmitLog2 WITH (ROWLOCK) SET
                        Key2 = 'RDT_5',
                        TransmitFlag = '0'
                     WHERE TableName = 'WSPICKCFMLOG'
                     AND   Key1 = @cOrderKey
                     AND   Key2 = '5'
                     AND   Key3 = @cStorerKey
                     AND   TransmitFlag = 'IGNOR'

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 143052
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd TLOG2 Fail
                        GOTO Quit
                     END
                  END
                  ELSE
                  BEGIN
                     EXEC dbo.ispGenTransmitLog2
                         'WSPICKCFMLOG'  -- TableName
                        , @cOrderKey   -- Key1
                        , 'RDT_5'           -- Key2
                        , @cStorerKey  -- Key3
                        , ''           -- Batch
                        , @bSuccess  OUTPUT
                        , @nErrNo    OUTPUT
                        , @cErrMsg   OUTPUT

                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 143053
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG2 Fail
                        GOTO Quit
                     END
                  END
               END
            END

            -- (james01)
            IF @nStep = 5
            BEGIN
               SELECT @cCarrierRef1 = CarrierRef1
               FROM dbo.CartonTrack WITH (NOLOCK)
               WHERE TrackingNo = @cTrackNo
               AND   LabelNo = @cOrderKey

               IF ISNULL( @cCarrierRef1, '') = ''
                  SET @nCartonNo = 1
               ELSE
                  SET @nCartonNo = CAST( SUBSTRING( @cCarrierRef1, 11, 3) AS INT)

               SELECT @cPickSlipNo = PickSlipNo
               FROM dbo.PackHeader WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey

               UPDATE dbo.PackInfo SET
                  [Weight] = CAST( @cWeight AS FLOAT),
                  CartonType = @cCartonType,
                  EditWho = @cUserName,
                  EditDate = GETDATE()
               WHERE PickSlipNo = @cPickSlipNo
               AND   CartonNo = @nCartonNo

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 143056
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PackInf Er
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO