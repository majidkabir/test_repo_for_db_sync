SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1837ExtValid02                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2022-04-25  1.0  James       WMS-19514. Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_1837ExtValid02] (
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

   IF @nInputKey = 1 -- Enter
   BEGIN
      IF @nStep = 2 -- Enter New Pallet ID
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.Pallet WITH (NOLOCK) 
                    WHERE PalletKey = @cPalletID
                    AND   [STATUS] = '9') 
         BEGIN
            SET @nErrNo = 186051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PALLET CLOSED
            GOTO Quit
         END
      END
   END


   Quit:

END

GO