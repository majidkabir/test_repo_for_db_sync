SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_898ExtVal04                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2022-07-01 1.0  yeekung WMS-19671 Created                            */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_898ExtVal04]
    @nMobile     INT
   ,@nFunc       INT
   ,@cLangCode   NVARCHAR(  3)
   ,@nStep       INT
   ,@nInputKey   INT
   ,@cReceiptKey NVARCHAR( 10)
   ,@cPOKey      NVARCHAR( 10)
   ,@cLOC        NVARCHAR( 10)
   ,@cToID       NVARCHAR( 18)
   ,@cLottable01 NVARCHAR( 18)
   ,@cLottable02 NVARCHAR( 18)
   ,@cLottable03 NVARCHAR( 18)
   ,@dLottable04 DATETIME
   ,@cUCC        NVARCHAR( 20)
   ,@cSKU        NVARCHAR( 20)
   ,@nQTY        INT
   ,@cParam1     NVARCHAR( 20) OUTPUT
   ,@cParam2     NVARCHAR( 20) OUTPUT
   ,@cParam3     NVARCHAR( 20) OUTPUT
   ,@cParam4     NVARCHAR( 20) OUTPUT
   ,@cParam5     NVARCHAR( 20) OUTPUT
   ,@cOption     NVARCHAR( 1)
   ,@nErrNo      INT       OUTPUT
   ,@cErrMsg     NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPOType     NVARCHAR( 10)
          ,@cPOSource   NVARCHAR( 2)
          ,@cStorerKey  NVARCHAR( 15)

   SELECT @cStorerKey = StorerKey,
          @nStep = @nStep,
          @nInputKey = @nInputKey
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile 


   IF @nStep = 3  -- ID
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF EXISTS(SELECT 1
            FROM DROPID (NOLOCK)
            WHERE DROPID=@ctoID
            AND status='9')
         BEGIN
            SET @nErrNo = 188001 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDClosed
            GOTO Quit
         END
      END
   END

Quit:

END

GO