SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal17                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2024-06-14  1.0  JHU151       FCR-352 Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_838ExtVal17] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cFromDropID      NVARCHAR( 20),
   @nCartonNo        INT,
   @cLabelNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cUCCNo           NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @cOption          NVARCHAR( 1),
   @cPackDtlRefNo    NVARCHAR( 20),
   @cPackDtlRefNo2   NVARCHAR( 20),
   @cPackDtlUPC      NVARCHAR( 30),
   @cPackDtlDropID   NVARCHAR( 20),
   @cPackData1       NVARCHAR( 30),
   @cPackData2       NVARCHAR( 30),
   @cPackData3       NVARCHAR( 30),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE
		@cOrdKey				   NVARCHAR( 10), 
		@cExtOrderKey			NVARCHAR( 50)
   
   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 3 -- Statistics
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN

			-- check picked qty for sku
			IF rdt.RDTGetConfig( @nFunc, 'DefaultPSSKUQty', @cStorerkey) = '1'
			BEGIN			 
			SELECT @cOrdKey = OrderKey, @cExtOrderKey = ExternOrderKey     
				FROM dbo.PickHeader WITH (NOLOCK)     
				WHERE PickHeaderKey = @cPickSlipNo

			IF ISNULL(@cOrdKey, '') <> ''
			BEGIN

				IF NOT EXISTS(SELECT 1 
						FROM dbo.PickHeader PH (NOLOCK)     
						JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)  
						WHERE PD.SKU = @cSKU
						AND PD.storerkey = @cStorerKey
						AND PH.PickHeaderKey = @cPickSlipNo
						AND PD.Status = '5'
						)
				BEGIN
					SET @nErrNo = 216901
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU Not yet picked 
					GOTO Quit
				END
			END
			ELSE
			BEGIN
				IF NOT EXISTS(SELECT 1 
						FROM dbo.PickHeader PH (NOLOCK)     
						JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
						JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
						WHERE SKU = @cSKU
						AND PD.Storerkey = @cStorerKey
						AND PH.PickHeaderKey = @cPickSlipNo
						AND PD.Status = '5'
						)
				BEGIN
					SET @nErrNo = 216902
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU Not yet picked 
					GOTO Quit
				END

			END
			END
         END
      END
   END

Quit:

END

GO