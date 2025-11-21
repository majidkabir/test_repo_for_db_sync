SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1628ExtValid03                                  */
/* Purpose: Check if dropid already picked (status = 5)                 */
/*          Check dropid cannot have sku with different COO (L01)       */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 21-May-2019 1.0  James      WMS8817. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1628ExtValid03] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerkey       NVARCHAR( 15),
   @cWaveKey         NVARCHAR( 10),
   @cLoadKey         NVARCHAR( 10),
   @cOrderKey        NVARCHAR( 10),
   @cLoc             NVARCHAR( 10),
   @cDropID          NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQty             INT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cLottable01          NVARCHAR( 18),
           @cCOO                 NVARCHAR( 18),
           @cUserName            NVARCHAR( 18),
           @cPutAwayZone         NVARCHAR( 10),
           @cPickZone            NVARCHAR( 10),
           @nMultiStorer         INT

   SET @nErrNo = 0

   SELECT @cUserName = UserName, 
          @cPutAwayZone = V_String10, 
          @cPickZone = V_String11
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 7
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.DropID  WITH (NOLOCK) 
                     WHERE DropID = @cDropID 
                     AND   Status = '5') AND
            EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
                     WHERE PD.StorerKey = @cStorerkey
                     AND   PD.DropID = @cDropID
                     AND   PD.Status < '9'
                     AND   O.LoadKey <> @cLoadKey
                     AND   O.PrintFlag <> '2')
         BEGIN
            SET @nErrNo = 138851
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Use
            GOTO Quit
         END
      END
   END

   IF @nStep IN (7, 8)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Check same dropid cannot mix COO (lottable01)
         SET @cLottable01 = ''
         SELECT TOP 1 @cLottable01 = LA.Lottable01
         FROM RDT.RDTPICKLOCK RPL WITH (NOLOCK)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( RPL.Lot = LA.Lot)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( RPL.OrderKey = LPD.OrderKey)
         WHERE RPL.StorerKey = @cStorerKey
         AND   RPL.SKU = @cSKU
         AND   RPL.LOC = @cLOC
         AND   RPL.Status = '1'
         AND   RPL.AddWho = @cUserName
         AND (( ISNULL( @cPutAwayZone, '') = 'ALL') OR ( RPL.PutAwayZone = @cPutAwayZone))
         AND (( ISNULL( @cPickZone, '') = '') OR ( RPL.PickZone = @cPickZone))
         AND   LPD.LoadKey = @cLoadKey
         ORDER BY 1

         SET @cCOO = ''
         SELECT TOP 1 @cCOO = LA.Lottable01
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( PD.Lot = LA.Lot)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
         WHERE PD.Storerkey = @cStorerkey
         AND   PD.Status = '5'
         AND   PD.DropID = @cDropID
         AND   PD.SKU = @cSKU
         --AND   PD.LOC = @cLOC
         AND   LPD.LoadKey = @cLoadKey
         ORDER BY 1

         IF @cCOO <> '' AND ( @cLottable01 <> @cCOO)
         BEGIN
            SET @nErrNo = 138852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiCOOSameSKU
            GOTO Quit
         END
      END
   END

QUIT:

GO