SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_921ExtValidSP02                                 */
/* Purpose: Validate  LabelNo                                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-08-25 1.0  Ung        SOS368362 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_921ExtValidSP02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cDropID        NVARCHAR( 20),
   @cLabelNo       NVARCHAR( 20),
   @cOrderKey      NVARCHAR( 10),
   @cCartonNo      NVARCHAR( 5),
   @cPickSlipNo    NVARCHAR( 10),
   @cCartonType    NVARCHAR( 10),
   @cCube          NVARCHAR( 10),
   @cWeight        NVARCHAR( 10),
   @cLength        NVARCHAR( 10),
   @cWidth         NVARCHAR( 10),
   @cHeight        NVARCHAR( 10),
   @cRefNo         NVARCHAR( 20),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

IF @nFunc = 921 -- PackInfo
BEGIN
   IF @nStep = 2 -- CartonType, cube, weight... etc
   BEGIN
      IF @nInputKey = 1 -- Enter
      BEGIN
         -- Get OrderKey
         SET @cOrderKey = ''
         SELECT @cOrderKey = OrderKey FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

         -- Check order shipped
         IF EXISTS( SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status = '9')
         BEGIN
            SET @nErrNo = 103151
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order shipped
            GOTO Quit
         END
      END
   END
END

QUIT:



GO