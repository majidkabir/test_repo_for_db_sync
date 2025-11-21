SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtVal09                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2018-04-12 1.0  Ung        WMS-4476 Created                          */
/* 2019-03-01 1.1  Ung        WMS-8124 Add GI date check, pick vs pack  */
/* 2019-06-12 1.2  Ung        Fix date time convertion runtime error    */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtVal09] (
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
            SET @nErrNo = 122751
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
            SET @nErrNo = 122752
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelNotInLoad
            GOTO Quit
         END

         /***********************************************************************************************
                                                   Pick VS Pack
         ***********************************************************************************************/
         DECLARE @nNotPickQTY INT
         DECLARE @nShortQTY INT
         DECLARE @nPickQTY INT
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

         -- Get pick QTY
         SELECT
            @nNotPickQTY = ISNULL( SUM( CASE WHEN PD.Status <= '3' THEN PD.QTY ELSE 0 END), 0),
            @nShortQTY = ISNULL( SUM( CASE WHEN PD.Status = '4' THEN PD.QTY ELSE 0 END), 0),
            @nPickQTY = ISNULL( SUM( CASE WHEN PD.Status >= '5' THEN PD.QTY ELSE 0 END), 0)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.CaseID = @cLabelNo

         -- Check not pick
         IF @nNotPickQTY > 0
         BEGIN
            SET @nErrNo = 122753
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pick NotFinish
            GOTO Quit
         END

         -- Check short pick
         IF @nShortQTY > 0
         BEGIN
            SET @nErrNo = 122754
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FoundShortPick
            GOTO Quit
         END

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
            SET @nErrNo = 122755
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack NotFinish
            GOTO Quit
         END

         -- Check pick pack tally
         IF @nPickQTY <> @nPackQTY
         BEGIN
            SET @nErrNo = 122756
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickPackQTYDif
            GOTO Quit
         END
      END
   END

   IF @nStep = 4  -- DOOR, REFNO
   BEGIN
      IF @cLoadKey = ''
      BEGIN
         SET @nErrNo = 122757
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LoadKey
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo
         GOTO Quit
      END

      -- Check site
      IF @cRefNo = ''
      BEGIN
         SET @nErrNo = 122758
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SITE
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo
         GOTO Quit
      END

      -- Check site valid
      IF NOT EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'Allsorting' AND Code = @cRefNo AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 122759
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
         SET @nErrNo = 122760
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Site NotInLoad
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo
         GOTO Quit
      END
   END
END
Quit:


GO