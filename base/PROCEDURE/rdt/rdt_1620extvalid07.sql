SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1620ExtValid07                                  */
/* Purpose: Check if dropid already picked (status = 5)                 */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 21-May-2019 1.0  James      WMS8817. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1620ExtValid07] (
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

   IF @nStep = 7
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cPickslipNo = PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                     WHERE DropID = @cDropID 
                     AND   Status = '5') AND
            EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
                     WHERE PD.StorerKey = @cStorerkey
                     AND   PD.DropID = @cDropID
                     AND   PD.Status < '9'
                     AND   O.PrintFlag <> '2')
         BEGIN
            SET @nErrNo = 138801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Use
            GOTO Quit
         END

         IF @cDropID <> @cPickslipNo
         BEGIN
            SET @nErrNo = 138802
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID<>PSlip#
            GOTO Quit
         END
      END

   END

QUIT:

GO