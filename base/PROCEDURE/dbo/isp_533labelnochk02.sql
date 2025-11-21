SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_533LabelNoChk02                                 */
/*                                                                      */
/* Purpose: Check from/to labelno exists in same orderkey               */
/*                                                                      */
/* Called from: rdtfnc_MoveByLabelNo                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2022-08-18 1.0  James    WMS-20234. Created                           */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_533LabelNoChk02]
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
           @cFromOrderKey  NVARCHAR( 10) = '',
           @cToOrderKey    NVARCHAR( 10) = ''

   SELECT @cStorerKey = StorerKey,
          @nStep = Step,
          @nInputKey = InputKey
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
      	SELECT @cFromOrderKey = OrderKey
      	FROM dbo.PICKDETAIL WITH (NOLOCK)
      	WHERE Storerkey = @cStorerKey
      	AND   CaseID = @cFromLabelNo

      	SELECT @cToOrderKey = OrderKey
      	FROM dbo.PICKDETAIL WITH (NOLOCK)
      	WHERE Storerkey = @cStorerKey
      	AND   CaseID = @cToLabelNo
      	
      	IF @cFromOrderKey <> @cToOrderKey
         BEGIN
            SET @nErrNo = 189901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToIDDiffOrders
            GOTO Quit
         END
      END
   END

QUIT:
END -- End Procedure

GO