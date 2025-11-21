SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_CartonPack_ValidateDoc                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Validate Doc                                                */
/*                                                                      */
/* Called from: rdtfnc_CartonPack                                       */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2019-05-29   1.0  James    WMS9064. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_CartonPack_ValidateDoc] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5), 
   @tValidateDoc     VARIABLETABLE READONLY,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cDocLabel           NVARCHAR( 20),
           @cDocValue           NVARCHAR( 20),
           @cCartonPackDoc      NVARCHAR( 30),
           @cOrderKey           NVARCHAR( 10),
           @cLoadKey            NVARCHAR( 10),
           @cZone               NVARCHAR( 10),
           @cPSType             NVARCHAR( 10),
           @nRowCount           INT

   -- Variable mapping
   SELECT @cDocLabel = Value FROM @tValidateDoc WHERE Variable = '@cDocLabel'
   SELECT @cDocValue = Value FROM @tValidateDoc WHERE Variable = '@cDocValue'
   SELECT @cCartonPackDoc = Value FROM @tValidateDoc WHERE Variable = '@cCartonPackDoc'

   SELECT @cDocLabel = Long
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE ListName = 'CartonPack'
   AND   Code = @cCartonPackDoc
   AND   StorerKey = @cStorerKey
   AND   code2 = @nFunc

   IF @cCartonPackDoc = 'WAVEKEY'
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.Wave WITH (NOLOCK) WHERE WaveKey = @cDocValue)
      BEGIN
         SET @nErrNo = 141851
         SET @cErrMsg = rdt.rdtgetmessage( 65901, @cLangCode, 'DSP') --Bad WaveKey
         GOTO Fail
      END

      SET @nRowCount = 0
      SELECT @nRowCount = COUNT( PD.OrderKey)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
      WHERE PD.StorerKey = @cStorerKey
      AND   PD.Status < '9'
      AND   PD.Status <> '4'
      AND   PD.QTY > 0

      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 141852
         SET @cErrMsg = rdt.rdtgetmessage( 65901, @cLangCode, 'DSP') --Nothing to pack
         GOTO Fail
      END
   END

   IF @cCartonPackDoc = 'LOADKEY'
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cDocValue)
      BEGIN
         SET @nErrNo = 141853
         SET @cErrMsg = rdt.rdtgetmessage( 65902, @cLangCode, 'DSP') --Bad LoadKey
         GOTO Fail
      END

      SET @nRowCount = 0
      SELECT @nRowCount = COUNT( PD.OrderKey)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
      WHERE PD.StorerKey = @cStorerKey
      AND   PD.Status < '9'
      AND   PD.Status <> '4'
      AND   PD.QTY > 0

      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 141854
         SET @cErrMsg = rdt.rdtgetmessage( 65901, @cLangCode, 'DSP') --Nothing to pack
         GOTO Fail
      END
   END

   IF @cCartonPackDoc = 'ORDERKEY'
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cDocValue)
      BEGIN
         SET @nErrNo = 141855
         SET @cErrMsg = rdt.rdtgetmessage( 65902, @cLangCode, 'DSP') --Bad OrderKey
         GOTO Fail
      END

      SET @nRowCount = 0
      SELECT @nRowCount = COUNT( OrderKey)
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cDocValue
      AND   Status < '9'
      AND   Status <> '4'
      AND   QTY > 0

      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 141856
         SET @cErrMsg = rdt.rdtgetmessage( 65901, @cLangCode, 'DSP') --Nothing to pack
         GOTO Fail
      END
   END

   IF @cCartonPackDoc = 'PickSlipNo'
   BEGIN
      SELECT @cOrderKey = OrderKey,    
             @cLoadKey = ExternOrderKey,    
             @cZone = Zone    
      FROM dbo.PickHeader WITH (NOLOCK)     
      WHERE PickHeaderKey = @cDocValue  

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 141857
         SET @cErrMsg = rdt.rdtgetmessage( 65902, @cLangCode, 'DSP') --Bad PickSlip
         GOTO Fail
      END

      -- Get PickSlip type
      IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
         SET @cPSType = 'XD'
      ELSE IF @cOrderKey = ''
         SET @cPSType = 'CONSO'
      ELSE
         SET @cPSType = 'DISCRETE'

      IF @cPSType = 'DISCRETE'
      BEGIN
         SET @nRowCount = 0
         SELECT @nRowCount = COUNT( OrderKey)
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         WHERE PD.OrderKey = @cOrderKey
         AND   PD.StorerKey = @cStorerKey
         AND   PD.Status < '9'
         AND   PD.Status <> '4'
         AND   PD.QTY > 0
      END
      ELSE IF @cPSType = 'CONSO'
      BEGIN
         SET @nRowCount = 0
         SELECT @nRowCount = COUNT( PD.OrderKey)
         FROM LoadPlanDetail LPD WITH (NOLOCK) 
         JOIN PickDetail PD WITH (NOLOCK) ON ( LPD.OrderKey = PD.OrderKey)
         WHERE LPD.Loadkey = @cLoadKey
         AND   PD.StorerKey = @cStorerKey
         AND   PD.Status < '9'
         AND   PD.Status <> '4'
         AND   PD.QTY > 0
      END
      ELSE IF @cPSType = 'XD'
      BEGIN
         SET @nRowCount = 0
         SELECT @nRowCount = COUNT( PD.OrderKey)
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.RefKeyLookup RKL WITH (NOLOCK) ON ( RKL.PickDetailKey = PD.PickDetailKey)
         WHERE RKL.PickslipNo = @cDocValue
         AND   PD.StorerKey = @cStorerKey
         AND   PD.Status < '9'
         AND   PD.Status <> '4'
         AND   PD.QTY > 0
      END
      ELSE
      BEGIN
         SET @nRowCount = 0
         SELECT @nRowCount = COUNT( OrderKey)
         FROM dbo.PickDetail WITH (NOLOCK)    
         WHERE PickSlipNo = @cDocValue    
         AND   StorerKey = @cStorerKey
         AND   Status < '9'
         AND   Status <> '4'
         AND   QTY > 0
      END

      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 141858
         SET @cErrMsg = rdt.rdtgetmessage( 65901, @cLangCode, 'DSP') --Nothing to pack
         GOTO Fail
      END
   END


   Fail:
END

GO