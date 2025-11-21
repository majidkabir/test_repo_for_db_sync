SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/***************************************************************************/
/* Store procedure: rdt_898ExtValPMI                                       */
/* Copyright      : Maersk WMS                                             */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2024-10-29 1.0  PYU015     UWP-26527 Created                            */
/***************************************************************************/

CREATE    PROCEDURE [RDT].[rdt_898ExtValPMI]
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
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE
      @cFacility        NVARCHAR( 5),  
      @cStorerKey       NVARCHAR( 15)

   SELECT @cStorerKey = StorerKey,
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile 

   IF @nFunc = 898
   BEGIN
      IF @nStep = 1  -- ASN
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF EXISTS(SELECT 1
                        FROM RECEIPTDETAIL WITH(NOLOCK) 
                       WHERE StorerKey = @cStorerKey 
                         AND ReceiptKey = @cReceiptKey
                         AND (
                             isnull(Lottable01,'') = ''
                          OR isnull(Lottable02,'') = ''
                          OR isnull(Lottable03,'') = ''
                          OR Lottable04 is null
                             )
                      )
            BEGIN
               SET @nErrNo = 219921 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid lottable
               GOTO Quit
            END
         END
      END
   END

Quit:
END


GO