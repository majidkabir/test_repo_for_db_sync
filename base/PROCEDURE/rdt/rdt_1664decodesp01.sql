SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1664DecodeSP01                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2019-08-20  James     1.0   WMS-10283 Created                              */
/* 2021-04-16  James     1.1   WMS-16024 Standard use of TrackingNo (james01) */
/* 2021-09-24  James     1.2   WMS-17954 Add more shipperkey (james02)        */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1664DecodeSP01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cBarcode       NVARCHAR( MAX), 
   @cMbolKey       NVARCHAR( 10)  OUTPUT, 
   @cTrackNo       NVARCHAR( 20)  OUTPUT, 
   @cOrderWeight   NVARCHAR( 10)  OUTPUT, 
   @cCartonLabelNo NVARCHAR( 20)  OUTPUT, 
   @cLabelCount    NVARCHAR( 5)   OUTPUT, 
   @nLabelScanned  NVARCHAR( 5)   OUTPUT, 
   @cPalletID      NVARCHAR( 20)  OUTPUT, 
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTempTrackNo      NVARCHAR( 20)


   IF @nStep = 2 -- Track no
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cBarcode <> ''
         BEGIN
            SET @cTempTrackNo = SUBSTRING( @cBarcode, 1, 12)

            IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey
                           AND   Facility = @cFacility
                           --AND   (( UserDefine04 = @cTempTrackNo) OR ( TrackingNo = @cTempTrackNo))
                           AND   TrackingNo = @cTempTrackNo --(james01)
                           AND   ShipperKey IN ('FEDEX', 'FDXI'))
               SET @cTrackNo = @cBarcode -- Assign back original track no
            ELSE
               SET @cTrackNo = @cTempTrackNo -- Assign the FEDEX track no
         END
      END
   END


Quit:

END

GO