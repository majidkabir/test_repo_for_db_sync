SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_898ExtVal05                                        */
/* Copyright      : Maersk WMS                                             */
/* Customer       : Granite                                                */
/*                                                                         */
/* Date       Rev    Author     Purposes                                   */
/* 2024-10-01 1.0    NLT013     FCR-926 Created                            */
/* 2025-02-13 1.1.0  ASK138     FCR-2724                                   */
/***************************************************************************/

CREATE     PROCEDURE [RDT].[rdt_898ExtVal05]
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
      -- FCR-2724 - OnLOT Validation  
      IF @nStep = 1  -- ASN 
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF EXISTS(SELECT 1
               FROM dbo.RECEIPT WITH(NOLOCK) 
               WHERE ReceiptKey = @cReceiptKey 
                  AND Facility = @cFacility
                  AND StorerKey = @cStorerKey 
                  AND ISNULL(UserDefine06, '') = '')
            BEGIN
               SET @nErrNo = 225302 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OnLOT not triggered
               GOTO Quit
            END
         END
      END
      ELSE IF @nStep = 3  -- To ID
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF EXISTS(SELECT 1
               FROM RDT.RDTSTDEVENTLOG WITH(NOLOCK) 
               WHERE FunctionID = @nFunc 
                  AND Facility = @cFacility
                  AND StorerKey = @cStorerKey 
                  AND ID = @cToID
                  AND ISNULL(Refno1, '') = 'CLOSE')
            BEGIN
               SET @nErrNo = 225301 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToIDClosed
               GOTO Quit
            END
         END
      END
   END

Quit:
END

GO