SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1837ExtValid01                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2019-09-26  1.0  James       WMS-10316. Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_1837ExtValid01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cCartonID      NVARCHAR( 20), 
   @cPalletID      NVARCHAR( 20), 
   @cLoadKey       NVARCHAR( 10), 
   @cLoc           NVARCHAR( 10), 
   @cOption        NVARCHAR( 1), 
   @tExtValidate   VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nStep = 1 -- Carton ID
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF ISNULL( @cCartonID, '') <> ''
         BEGIN
            IF NOT EXISTS ( 
               SELECT 1 FROM rdt.RDTPPA WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   DropID = @cCartonID)
            BEGIN
               SET @nErrNo = 144351
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PPA req
               GOTO Quit
            END
         END
      END
   END


   Quit:

END

GO