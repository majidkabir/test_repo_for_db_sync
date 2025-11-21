SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_840CapturePack03                                */
/* Purpose: Output carton weight and carton type                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2020-07-05  1.0  James      WMS-13913. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_840CapturePack03] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerkey       NVARCHAR( 15),
   @cOrderKey        NVARCHAR( 10),
   @cPickSlipNo      NVARCHAR( 10),
   @cTrackNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nCartonNo        INT,
   @cCartonType      NVARCHAR( 10) OUTPUT,
   @fCartonWeight    FLOAT         OUTPUT,
   @cCapturePackInfo NVARCHAR( 10) OUTPUT, 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @fSKUWeight     FLOAT
   DECLARE @cCtnType       NVARCHAR( 10)
   
   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cCtnType = CartonType
         FROM dbo.PackInfo WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nCartonNo

         SELECT @fCartonWeight = CZ.CartonWeight
         FROM dbo.CARTONIZATION CZ WITH (NOLOCK)
         JOIN dbo.Storer ST WITH (NOLOCK) ON CZ.CartonizationGroup = ST.CartonGroup
         WHERE CZ.CartonType = @cCtnType
         AND   ST.StorerKey = @cStorerkey
         
         SELECT @fSKUWeight = ISNULL( SUM( SKU.STDGROSSWGT * PD.Qty), 0)
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.SKU = SKU.Sku AND PD.StorerKey = SKU.StorerKey
         WHERE PD.PickSlipNo = @cPickSlipNo
         AND   PD.CartonNo = @nCartonNo
         
         SET @cCartonType = ''
         SET @fCartonWeight = @fCartonWeight + @fSKUWeight
         
         SET @cCapturePackInfo = '1'   -- Enable capture pack info screen
      END
   END

   GOTO Quit

   Quit:

GO