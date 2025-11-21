SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_868ExtVal02                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 20-Aug-2015 1.0  Ung       SOS350973 Created                         */
/* 16-Apr-2021 1.1  James     WMS-16024 Standarized use of TrackingNo   */
/*                            (james01)                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_868ExtVal02] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cOrderKey   NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cDropID     NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @cADCode     NVARCHAR( 18),
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 868 -- Pick and pack
   BEGIN
      IF @nStep = 2 -- DropID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cDropID = ''
            BEGIN
               SET @nErrNo = 56101
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID needed
               GOTO Fail
            END
            
            DECLARE @cShipperKey  NVARCHAR(15)
            DECLARE @cTrackRegExp NVARCHAR(255)
            DECLARE @cUDF04       NVARCHAR(20)
         
            SET @cShipperKey = ''
            SET @cTrackRegExp = ''
            
            -- Get order info
            SELECT 
               @cShipperKey = ShipperKey, 
               --@cUDF04 = UserDefine04
               @cUDF04 = TrackingNo -- (james01)
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE Orderkey = @cOrderkey
               AND Storerkey = @cStorerkey
            IF ISNULL(@cShipperKey,'') = ''
               GOTO Fail
         
            -- Get TrackNo format
            SELECT @cTrackRegExp = Notes1 FROM dbo.Storer WITH (NOLOCK)
            WHERE Storerkey = @cShipperKey
         
            -- Check TrackNo format
            IF master.dbo.RegExIsMatch(ISNULL(RTRIM(@cTrackRegExp),''), ISNULL(RTRIM(@cDropID),''), 0) <> 1
            BEGIN
               SET @nErrNo = 56102
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
               GOTO Fail
            END
            
            -- Check DropID used
            IF EXISTS( SELECT TOP 1 1 
               FROM PackHeader PH WITH (NOLOCK)
                  JOIN PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
               WHERE PH.OrderKey <> @cOrderKey
                  AND PD.LabelNo = @cDropID)
            BEGIN
               SET @nErrNo = 56103
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID used
               GOTO Fail
            END
            
            -- Check tracking no match pre-assigned tracking no
            IF @cUDF04 <> @cDropID
            BEGIN
               -- Check 1st carton track no must be the order assigned track no
               IF NOT EXISTS( SELECT 1 FROM PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cUDF04)
               BEGIN
                  SET @nErrNo = 56104
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffTrackingNo
                  GOTO Fail
               END
            END
         END
      END
   END

Fail:
Quit:

END

GO