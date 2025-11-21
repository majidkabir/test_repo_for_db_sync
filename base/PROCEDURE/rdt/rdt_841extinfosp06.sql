SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_841ExtInfoSP06                                  */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-04-25 1.0  YeeKung    WMS-22390 Created                         */
/************************************************************************/

CREATE     PROC [RDT].[rdt_841ExtInfoSP06] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR(3),
   @nStep       INT,
   @cStorerKey  NVARCHAR(15),
   @cDropID     NVARCHAR(20),
   @cSKU        NVARCHAR(20),
   @cPickSlipNo NVARCHAR(10),
   @cLoadKey    NVARCHAR(20),
   @cWavekey    NVARCHAR(20),
   @nInputKey   INT,
   @cSerialNo   NVARCHAR( 30),
   @nSerialQTY   INT,
   @cExtendedinfo  NVARCHAR( 20) OUTPUT,
   @nErrNo      INT       OUTPUT,
   @cErrMsg     CHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN

         IF EXISTS (SELECT 1
                     FROM SKU (NOLOCK)
                     WHERE  SKU = @cSKU
                        AND Storerkey = @cStorerKey
                        AND OVAS ='P')
         BEGIN
            SELECT @cExtendedinfo = Right(SKU.Altsku,5) + ' Ñ' + CAST (SKU.Price AS NVARCHAR(20))
            FROM SKU SKU (NOLOCK)
            WHERE  SKU = @cSKU
               AND Storerkey = @cStorerKey
               AND OVAS ='P'
         END
      END
   END


QUIT:
END


GO