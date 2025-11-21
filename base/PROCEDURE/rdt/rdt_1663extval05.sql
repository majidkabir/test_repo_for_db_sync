SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtVal05                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-10-02 1.0  Ung      WMS-6516 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663ExtVal05](
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

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      IF @nStep = 3 -- Track no
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @nRowCount      INT
            DECLARE @cCarrier       NVARCHAR(10)

            DECLARE @cChkOrderKey   NVARCHAR(10)
            DECLARE @cChkShipperKey NVARCHAR(15)
            DECLARE @cChkCarrier    NVARCHAR(10)

            -- Get random track no on pallet
            SELECT 
               @cChkOrderKey = UserDefine01
            FROM PalletDetail WITH (NOLOCK) 
            WHERE PalletKey = @cPalletKey 
            
            SET @nRowCount = @@ROWCOUNT
            
            -- Pallet level checking
            IF @nRowCount > 0
            BEGIN
               -- Get order info
               SELECT @cShipperKey = ShipperKey FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
               SELECT @cCarrier = SHORT FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'ECDLMODE' AND Code = @cShipperKey AND StorerKey = @cStorerKey

               -- Get check order info
               SELECT @cChkShipperKey = ShipperKey FROM Orders WITH (NOLOCK) WHERE OrderKey = @cChkOrderKey
               SELECT @cChkCarrier = SHORT FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'ECDLMODE' AND Code = @cChkShipperKey AND StorerKey = @cStorerKey
               
               -- Check different carrier
               IF @cChkCarrier <> @cCarrier 
               BEGIN
                  SET @nErrNo = 129601
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Carrier
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO