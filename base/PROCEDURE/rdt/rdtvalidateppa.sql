SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtValidatePPA                                      */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Validate whether all item scanned in rdtPPA table before    */
/*          proceed to scan out                                         */
/*                                                                      */
/* Called from: rdtfnc_ScanOut                                          */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2014-05-21  1.0  James       SOS303019 Created                       */  
/************************************************************************/

CREATE PROC [RDT].[rdtValidatePPA] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerKey                NVARCHAR( 15),
   @cPickslip                 NVARCHAR( 10),
   @nValid                    INT                OUTPUT,
   @nErrNo                    INT                OUTPUT,
   @cErrMsg                   NVARCHAR( 20)      OUTPUT   -- screen limitation, 20 char max

)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUOM        NVARCHAR( 10), 
           @nCSKU       NVARCHAR( 20), 
           @nPSKU       NVARCHAR( 20), 
           @cOrderKey   NVARCHAR( 10), 
           @cLoadKey    NVARCHAR( 10), 
           @cWaveKey    NVARCHAR( 10), 
           @nCQTY       INT, 
           @nPQTY       INT 

   SET @nValid = 1

   IF @nStep <> 1 OR @nInputKey <> 1
      GOTO Quit

   IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPPA WITH (NOLOCK) 
                   WHERE PickSlipNo = @cPickslip 
                   AND StorerKey = @cStorerKey)
   BEGIN
      SET @cErrMsg = 'PPA NOT SCAN'
      SET @nValid = 0
      GOTO Quit
   END

   SELECT @cUOM = V_UOM FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
   
   EXECUTE rdt.rdt_PostPickAudit_GetStat @nMobile, @nFunc, '', @cPickSlip, '', '', '', @cStorerKey, @cUOM,
      @nCSKU OUTPUT,
      @nCQTY OUTPUT,
      @nPSKU OUTPUT,
      @nPQTY OUTPUT

   -- Discrepancy found
   IF @nCSKU <> @nPSKU OR @nCQTY <> @nPQTY
   BEGIN
      SET @cErrMsg = 'PPA NOT MATCH'
      SET @nValid = 0
      GOTO Quit
   END

   SELECT @cOrderKey = OrderKey, 
          @cLoadKey = ExternOrderKey, 
          @cWaveKey = WaveKey  
   FROM dbo.PickHeader WITH (NOLOCK) 
   WHERE PickHeaderKey = @cPickslip

   IF ISNULL( @cWaveKey, '') <> ''
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                  WHERE PD.StorerKey = @cStorerKey
                  AND   O.UserDefine09 = @cWaveKey
                  AND   PD.SKU NOT IN ( SELECT 1 FROM rdt.rdtPPA PPA WITH (NOLOCK) 
                                        WHERE PPA.PickSlipNo = @cPickslip AND PPA.SKU = PD.SKU))
      BEGIN
         SET @cErrMsg = 'PPA SKU NOT MATCH'
         SET @nValid = 0
         GOTO Quit
      END
      GOTO Quit
   END

   IF ISNULL( @cLoadKey, '') <> ''
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                  WHERE PD.StorerKey = @cStorerKey
                  AND   O.LoadKey = @cLoadKey
                  AND   PD.SKU NOT IN ( SELECT 1 FROM rdt.rdtPPA PPA WITH (NOLOCK) 
                                        WHERE PPA.PickSlipNo = @cPickslip AND PPA.SKU = PD.SKU))
      BEGIN
         SET @cErrMsg = 'PPA SKU NOT MATCH'
         SET @nValid = 0
         GOTO Quit
      END
   END

   IF ISNULL( @cOrderKey, '') <> ''
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                  WHERE PD.StorerKey = @cStorerKey
                  AND   O.OrderKey = @cOrderKey
                  AND   PD.SKU NOT IN ( SELECT 1 FROM rdt.rdtPPA PPA WITH (NOLOCK) 
                                        WHERE PPA.PickSlipNo = @cPickslip AND PPA.SKU = PD.SKU))
      BEGIN
         SET @cErrMsg = 'PPA SKU NOT MATCH'
         SET @nValid = 0
         GOTO Quit
      END
   END
   
Quit:
END

GO