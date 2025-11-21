SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtVal14                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Validate same pallet cannot mix shipperkey and c_country          */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2021-08-20 1.0  James    WMS-17712 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663ExtVal14](
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
            DECLARE @cCCountry      NVARCHAR( 30)

            DECLARE @cOtherOrderkey    NVARCHAR( 10)
            DECLARE @cOtherCCountry    NVARCHAR( 30)
            DECLARE @cOtherShipperKey  NVARCHAR( 15)
            
            -- Get order info
            SET @cCCountry = ''
            SET @cShipperKey = ''
            SELECT
               @cCCountry = ISNULL( RTRIM( C_Country), ''), 
               @cShipperKey = ISNULL( RTRIM( ShipperKey), '')
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
               SET @cOtherCCountry = ''
               SET @cOtherShipperKey = ''
               SELECT
                  @cOtherCCountry = ISNULL( RTRIM( C_Country), ''), 
                  @cOtherShipperKey = ISNULL( RTRIM( ShipperKey), '')
               FROM dbo.Orders WITH (NOLOCK)
               WHERE OrderKey = @cOtherOrderKey
   
               -- Cannot Mix CCountry --
               IF @cCCountry <> @cOtherCCountry
               BEGIN
                  SET @nErrNo = 174001
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Country Diff
                  GOTO QUIT
               END
   
               -- Cannot Mix OrderType --
               IF @cShipperKey <> @cOtherShipperKey
               BEGIN
                  SET @nErrNo = 174002
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderTypeDiff
                  GOTO QUIT
               END
            END
         END
      END
   END

Quit:

END

GO