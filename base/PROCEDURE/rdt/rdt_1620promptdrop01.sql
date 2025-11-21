SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1620PromptDrop01                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: If SKU+LOC+ID changed then go back drop id screen           */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 08-Nov-2018  1.0  James       WMS6843. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1620PromptDrop01] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15),
   @cWaveKey                  NVARCHAR( 10),
   @cLoadKey                  NVARCHAR( 10),
   @cOrderKey                 NVARCHAR( 10),
   @cLoc                      NVARCHAR( 10),
   @cDropID                   NVARCHAR( 20),
   @cSKU                      NVARCHAR( 20),
   @nQty                      INT,
   @nPromptDropIDScn          INT               OUTPUT,
   @nErrNo                    INT               OUTPUT,
   @cErrMsg                   NVARCHAR( 20)     OUTPUT   -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLastPickedLOC    NVARCHAR( 10)
   DECLARE @cLastPickedID     NVARCHAR( 18)
   DECLARE @cLastPickedSKU    NVARCHAR( 20)
   DECLARE @cToPickLOC        NVARCHAR( 10)
   DECLARE @cToPickID         NVARCHAR( 18)
   DECLARE @cToPickSKU        NVARCHAR( 20)
   DECLARE @cUserName         NVARCHAR( 18)
   DECLARE @cO_Field08        NVARCHAR( 20)
   DECLARE @cPickSameID       NVARCHAR( 1)
   DECLARE @bSuccess          INT
   DECLARE @nIDQty2Pick       INT
   DECLARE @nIDQtyPickED      INT

   SET @nPromptDropIDScn = 0
   SET @cPickSameID = '0'

   SELECT @cUserName = UserName, @cO_Field08 = O_Field08
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 8
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cLastPickedSKU = I_Field04
         FROM RDT.RDTMOBREC WITH (NOLOCK)
         WHERE UserName = @cUserName
         ORDER BY EditDate DESC

         EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cLastPickedSKU  OUTPUT
         ,@bSuccess    = @bSuccess        OUTPUT
         ,@nErr        = @nErrNo          OUTPUT
         ,@cErrMsg     = @cErrMsg         OUTPUT

         SELECT TOP 1 @cLastPickedID = PD.ID, 
                      @cLastPickedLOC = PD.LOC
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.Status = '3'
         AND   PD.LOC = @cLOC
         AND   PD.SKU = @cLastPickedSKU
         AND   WD.WaveKey = @cWaveKey
         AND   EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK RPL WITH (NOLOCK) 
                        WHERE RPL.WaveKey = WD.WaveKey
                        AND   RPL.SKU = PD.SKU
                        AND   RPL.LOC = PD.LOC
                        AND   RPL.LOT = PD.LOT
                        AND   RPL.Status = '5'
                        AND   RPL.AddWho = @cUserName)
         ORDER BY PD.EditDate DESC

         -- Check if last picked id still have something to pick in loc + sku
         IF @@ROWCOUNT > 0 AND 
            EXISTS ( SELECT 1 
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.WaveDetail WD WITH (NOLOCK) ON PD.OrderKey = WD.OrderKey         
                     WHERE PD.StorerKey = @cStorerKey
                     AND   PD.Status = '0'
                     AND   PD.LOC = @cLOC
                     AND   PD.ID = @cLastPickedID
                     AND   PD.SKU = @cLastPickedSKU
                     AND   WD.WaveKey = @cWaveKey)
         SET @cPickSameID = '1'


         SELECT TOP 1 @cToPickID = PD.ID, 
                      @cToPickLOC = PD.LOC, 
                      @cToPickSKU = PD.SKU
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.WaveDetail WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.Status = '0'
         AND   PD.LOC = @cLOC
         AND   PD.SKU = @cSKU
         AND   ( ( @cPickSameID = '0') OR ( @cPickSameID = '1' AND PD.ID = @cLastPickedID))
         AND   WD.WaveKey = @cWaveKey
         AND   EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK RPL WITH (NOLOCK) 
                        WHERE RPL.WaveKey = WD.WaveKey
                        AND   RPL.SKU = PD.SKU
                        AND   RPL.LOC = PD.LOC
                        AND   RPL.LOT = PD.LOT
                        AND   RPL.Status = '1'
                        AND   RPL.AddWho = @cUserName)         
         ORDER BY 1

         IF ( @cLastPickedID + @cLastPickedLOC + @cLastPickedSKU) <> 
            ( @cToPickID + @cToPickLOC + @cToPickSKU)
            SET @nPromptDropIDScn = 1

         INSERT INTO TraceInfo (TraceName, TimeIn, Col1, Col2, Col3, Step1, Step2, Step3, Step4, Step5) VALUES
         ('1620DROPID', GETDATE(), @cLastPickedID , @cLastPickedLOC , @cLastPickedSKU, @cToPickID , @cToPickLOC , @cToPickSKU, @cLoc, @cSKU)
      END
   END

   Quit:
END

GO