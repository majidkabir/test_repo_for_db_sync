SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663DecodeTK03                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2019-01-29 1.0  James    WMS7779. Created                                  */
/* 2019-05-21 1.1  James    WMS9133 - Remove * from Tracking No (james01)     */
/* 2020-02-03 1.2  James    WMS-11986 - Add shipperkey pelican decode(james02)*/
/* 2020-08-14 1.3  Chermaine WMS-14678 - remark pickslip=trackNo (cc01)       */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663DecodeTK03](
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
   @cTrackNo      NVARCHAR( 20) OUTPUT, 
   @cOrderKey     NVARCHAR( 10) OUTPUT, 
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cShipperKey    NVARCHAR( 15)
   DECLARE @cType          NVARCHAR( 10)

   IF @nStep = 3 -- TrackNo
   BEGIN
      IF @nInputKey = 1
      BEGIN

         SET @cTrackNo = REPLACE( @cTrackNo, '*', '')

         SELECT @cOrderKey = OrderKey,
                @cType = Type,
                @cShipperKey = ShipperKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   REPLACE( TrackingNo, '*', '') = @cTrackNo

         IF @@ROWCOUNT = 0
         BEGIN
            SELECT @cOrderKey = PH.OrderKey
            FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
            WHERE PH.StorerKey = @cStorerKey
            AND   PD.LabelNo = @cTrackNo

            --IF @@ROWCOUNT = 0  --(cc01)
            --BEGIN
            --   SELECT TOP 1 @cOrderKey = PH.OrderKey
            --   FROM dbo.PackDetail PD WITH (NOLOCK)
            --   JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickslipNo = PH.PickSlipNo)
            --   WHERE PH.StorerKey = @cStorerKey
            --   AND   PH.PickSlipNo = LEFT( @cTrackNo, 10)
            --   ORDER BY 1

               -- (james02)
               IF @@ROWCOUNT = 0
               BEGIN
                  SELECT TOP 1 @cOrderKey = PH.OrderKey
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickslipNo = PH.PickSlipNo)
                  WHERE PD.StorerKey = @cStorerKey
                  --AND   PH.PickSlipNo = LEFT( @cTrackNo, 12)
                  AND   EXISTS ( SELECT 1 FROM dbo.ORDERS O WITH (NOLOCK) 
                                 WHERE PH.OrderKey = O.OrderKey 
                                 AND   PH.StorerKey = O.StorerKey
                                 AND   O.ShipperKey = 'PELICAN'
                                 AND   O.TrackingNo = LEFT( @cTrackNo, 12))
                  ORDER BY 1

                  IF @@ROWCOUNT = 0
                  BEGIN
                     SET @nErrNo = 134201
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Order
                     GOTO Quit
                  END
               END
            --END
         END
         ELSE
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM CodeLkUp WITH (NOLOCK)
                              WHERE Listname= 'ECDLMODE'
                              AND   Code = @cShipperKey
                              AND   StorerKey = @cStorerKey)
            BEGIN
               SET @nErrNo = 134202
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Carrier
               GOTO Quit
            END
         END
      END
   END
Quit:

END

GO