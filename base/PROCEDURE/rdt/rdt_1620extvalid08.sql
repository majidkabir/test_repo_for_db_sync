SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1620ExtValid08                                  */
/* Purpose: Check if LoadPlan.LoadPickMethod = 'C'                      */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2020-07-15  1.0  James      WMS-14245. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1620ExtValid08] (
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

   DECLARE @cPickslipNo          NVARCHAR( 10),
           @nMultiStorer         INT

   SET @nErrNo = 0

   IF @nFunc = 1620
   BEGIN
      IF @nStep = 2
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF ISNULL( @cLoadKey, '') <> ''
            BEGIN
               IF EXISTS ( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK)
                           WHERE LoadKey = @cLoadKey
                           AND   LoadPickMethod = 'C')
               BEGIN
                  SET @nErrNo = 154951
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LoadPickMtd=C
                  GOTO Quit
               END
            END
         END
      END
      
      IF @nStep = 3
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF EXISTS ( SELECT 1 FROM RDT.rdtPickLock RPL WITH (NOLOCK) 
                        JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( RPL.Orderkey = LPD.OrderKey) 
                        JOIN dbo.LoadPlan LP WITH (NOLOCK) ON ( LPD.LoadKey = LP.LoadKey)
                        WHERE RPL.AddWho = SUSER_SNAME()
                        AND   RPL.[Status] = '1'
                        AND   RPL.Storerkey = @cStorerkey
                        AND   LP.LoadPickMethod = 'C')
            BEGIN
               SET @nErrNo = 154952
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LoadPickMtd=C
               GOTO Quit
            END
         END
      END
   END

QUIT:

GO