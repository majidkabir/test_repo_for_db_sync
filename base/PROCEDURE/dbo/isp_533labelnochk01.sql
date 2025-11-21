SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_533LabelNoChk01                                 */
/*                                                                      */
/* Purpose: Check to labelno exists in packdetail                       */
/*                                                                      */
/* Called from: rdtfnc_MoveByLabelNo                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2018-03-19 1.0  James    WMS8054. Created                            */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_533LabelNoChk01]
   @nMobile       INT, 
   @nFunc         INT, 
   @cLangCode     NVARCHAR(3),
   @cFromLabelNo  NVARCHAR(20),
   @cToLabelNo    NVARCHAR(20),
   @nErrNo        INT      OUTPUT, 
   @cErrMsg       NVARCHAR(20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cStorerKey     NVARCHAR( 15),
           @nStep          INT,
           @nInputKey      INT,
           @cFromPickSlipNo   NVARCHAR( 10),
           @cToPickSlipNo     NVARCHAR( 10)

   SELECT @cStorerKey = StorerKey,
          @nStep = Step,
          @nInputKey = InputKey
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         --IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
         --                WHERE StorerKey = @cStorerKey
         --                AND   LabelNo = @cToLabelNo)
         --BEGIN
         --   SET @nErrNo = 136301
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLblNotExists
         --   GOTO Quit
         --END

         SELECT TOP 1 @cFromPickSlipNo = PickSlipNo 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   LabelNo = @cFromLabelNo
         ORDER BY 1

         SELECT TOP 1 @cToPickSlipNo = PickSlipNo 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   LabelNo = @cToLabelNo
         ORDER BY 1

         IF @@ROWCOUNT = 0 OR ISNULL( @cToPickSlipNo, '') = ''
         BEGIN
            SET @nErrNo = 136301
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLblNotExists
            GOTO Quit
         END

         IF ISNULL( @cFromPickSlipNo, '') <> ISNULL( @cToPickSlipNo, '')
         BEGIN
            SET @nErrNo = 136302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CrossPickSlip
            GOTO Quit
         END
      END
   END

QUIT:
END -- End Procedure

GO