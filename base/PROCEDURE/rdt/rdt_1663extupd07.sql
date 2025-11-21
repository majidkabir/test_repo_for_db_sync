SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtUpd07                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2020-09-23 1.0  Chermaine  WMS-14997 Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663ExtUpd07](
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
      IF @nStep = 3  -- Track no
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- MBOLDetail created
            IF EXISTS( SELECT 1 FROM MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
            BEGIN
               DECLARE @cExternOrderkey   NVARCHAR( 50)
               DECLARE @cEcomOrderId      NVARCHAR( 45)
   
               -- Get ExternOrderkey
               SELECT @cExternOrderkey = ExternOrderkey
               FROM dbo.ORDERS WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
               
               -- Get ExternOrderkey
               SELECT @cEcomOrderId = EcomOrderId
               FROM dbo.OrderInfo WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
               
               UPDATE dbo.MBOLDetail WITH (ROWLOCK) SET 
                  ExternOrderkey = @cExternOrderkey,
                  Userdefine01 = @cEcomOrderId
               WHERE MBOLKey = @cMBOLKey 
               AND   OrderKey = @cOrderKey
                  
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 160351
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MBDtl Fail
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO