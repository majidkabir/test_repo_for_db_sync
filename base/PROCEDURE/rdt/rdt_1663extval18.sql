SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtVal18                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2022-02-07 1.0  Ung      WMS-18743 Created (based on rdt_1663ExtVal05)     */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663ExtVal18](
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
            DECLARE @nRowCount         INT
            DECLARE @cCarrier          NVARCHAR(10)
            DECLARE @cCarrierGroup     NVARCHAR(30)

            DECLARE @cChkOrderKey      NVARCHAR(10)
            DECLARE @cChkShipperKey    NVARCHAR(15)
            DECLARE @cChkCarrierGroup  NVARCHAR(30)
            DECLARE @cChkCarrier       NVARCHAR(10)

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
               SELECT 
                  @cShipperKey = ShipperKey, 
                  @cCarrierGroup = ISNULL( Salesman, '')
               FROM Orders WITH (NOLOCK) 
               WHERE OrderKey = @cOrderKey
               
               SELECT @cCarrier = SHORT 
               FROM CodeLKUP WITH (NOLOCK) 
               WHERE ListName = 'ECDLMODE' 
                  AND Code = @cShipperKey 
                  AND StorerKey = @cStorerKey 
                  AND Code2 = @cCarrierGroup

               -- Get check order info
               SELECT 
                  @cChkShipperKey = ShipperKey, 
                  @cChkCarrierGroup = ISNULL( Salesman, '')
               FROM Orders WITH (NOLOCK) 
               WHERE OrderKey = @cChkOrderKey
               
               SELECT @cChkCarrier = SHORT 
               FROM CodeLKUP WITH (NOLOCK) 
               WHERE ListName = 'ECDLMODE' 
                  AND Code = @cChkShipperKey 
                  AND StorerKey = @cStorerKey 
                  AND Code2 = @cChkCarrierGroup
               
               /*
               -- Check carrier group
               IF @cCarrierGroup <> @cChkCarrierGroup
               BEGIN
                  SET @nErrNo = 181701
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffCarrierGrp
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
                  GOTO Quit
               END
               */

               -- Check different carrier
               IF @cChkCarrier <> @cCarrier 
               BEGIN
                  SET @nErrNo = 181702
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Carrier
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
                  GOTO Quit
               END
            END
         
            -- Alert personal service
            DECLARE @cEngraving NVARCHAR( 1)
            SET @cEngraving = rdt.rdtGetConfig( @nFunc, 'Engraving', @cStorerKey)  
            IF @cEngraving = '1'
            BEGIN
               DECLARE @cSpecialHandling NVARCHAR(1)
               SELECT @cSpecialHandling = SpecialHandling 
               FROM dbo.Orders WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND TrackingNo = @cTrackNo

               IF @cSpecialHandling <> ''
               BEGIN
                  DECLARE @cMsg1 NVARCHAR( 20)
                  DECLARE @cMsg2 NVARCHAR( 20)
                  SET @cMsg1 = rdt.rdtgetmessage( 181703, @cLangCode, 'DSP') --PERSONAL SERVICE
                  SET @cMsg2 = rdt.rdtgetmessage( 181704, @cLangCode, 'DSP') --PLEASE CHECK
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cMsg1, '', @cMsg2
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO