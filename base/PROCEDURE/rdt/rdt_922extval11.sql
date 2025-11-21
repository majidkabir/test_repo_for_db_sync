SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtVal11                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-01-06 1.0  James      WMS-16016. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtVal11] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  NVARCHAR( 15),
   @cType       NVARCHAR( 1),
   @cMBOLKey    NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10),
   @cLabelNo    NVARCHAR( 20),
   @cPackInfo   NVARCHAR( 3),
   @cWeight     NVARCHAR( 10),
   @cCube       NVARCHAR( 10),
   @cCartonType NVARCHAR( 10),
   @cDoor       NVARCHAR( 10),
   @cRefNo      NVARCHAR( 40),
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

IF @nFunc = 922 -- Scan to truck
BEGIN
   IF @nStep = 1 -- MBOL, Load, Order
   BEGIN
      IF @cLoadKey <> ''
      BEGIN
         DECLARE @cToday NVARCHAR(10)
         SET @cToday = CONVERT( NVARCHAR(10), GETDATE(), 120) --YYYY-MM-DD

         -- Check labelno in load (site)
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.Orders (NOLOCK)
            WHERE LoadKey = @cLoadKey
               AND UserDefine10 <> @cToday)
         BEGIN
            SET @nErrNo = 161951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff GI date
            GOTO Quit
         END
      END
   END

   IF @nStep = 2 -- LabelNo
   BEGIN
      IF @cLoadKey <> ''
      BEGIN
         -- Check labelno in load (site)
         IF NOT EXISTS( SELECT TOP 1 1
            FROM dbo.PackHeader PH (NOLOCK)
               JOIN dbo.PackDetail PD (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            WHERE PH.LoadKey = @cLoadKey
               AND PD.StorerKey = @cStorerKey
               AND PD.RefNo = @cRefNo
               AND PD.LabelNo = @cLabelNo)
         BEGIN
            SET @nErrNo = 161952
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelNotInLoad
            GOTO Quit
         END

         /***********************************************************************************************
                                                   Pick VS Pack
         ***********************************************************************************************/
         DECLARE @nPackQTY INT
         DECLARE @nExpQTY INT

         DECLARE @tPickZone TABLE
         (
            PickZone NVARCHAR( 10) PRIMARY KEY CLUSTERED
         )

         INSERT INTO @tPickZone (PickZone)
         SELECT Code2
         FROM dbo.CodelkUp WITH (NOLOCK)
         WHERE ListName = 'ALLSorting'
            AND StorerKey = @cStorerKey
            AND Code = @cRefNo

         -- Get pack QTY
         SELECT
            @nExpQTY = ISNULL( SUM( PD.ExpQTY), 0),
            @nPackQTY = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.PackHeader PH (NOLOCK)
            JOIN dbo.PackDetail PD (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         WHERE PH.LoadKey = @cLoadKey
            AND PD.RefNo = @cRefNo
            AND PD.LabelNo = @cLabelNo

         -- Check pack finish
         IF @nExpQTY > 0 AND @nExpQTY <> @nPackQTY
         BEGIN
            SET @nErrNo = 161953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack NotFinish
            GOTO Quit
         END
      END
   END

   IF @nStep = 4  -- DOOR, REFNO
   BEGIN
      IF @cLoadKey = ''
      BEGIN
         SET @nErrNo = 161954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LoadKey
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo
         GOTO Quit
      END

      -- Check site
      IF @cRefNo = ''
      BEGIN
         SET @nErrNo = 161955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SITE
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo
         GOTO Quit
      END

      -- Check site valid
      IF NOT EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'Allsorting' AND Code = @cRefNo AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 161956
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid site
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo
         GOTO Quit
      END

      -- Check site in load
      IF NOT EXISTS( SELECT TOP 1 1
         FROM dbo.PackHeader PH (NOLOCK)
            JOIN dbo.PackDetail PD (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         WHERE PH.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey
            AND PD.RefNo = @cRefNo)
      BEGIN
         SET @nErrNo = 161957
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Site NotInLoad
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo
         GOTO Quit
      END
   END
END
Quit:


GO