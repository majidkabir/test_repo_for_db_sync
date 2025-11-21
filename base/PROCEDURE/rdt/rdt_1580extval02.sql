SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal02                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID                                              */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 30-07-2014  1.0  Ung         SOS331539. Created                      */
/* 01-09-2016  1.1  Ung         Performance tuning                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtVal02]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cReceiptKey  NVARCHAR( 10) 
   ,@cPOKey       NVARCHAR( 10) 
   ,@cExtASN      NVARCHAR( 20)
   ,@cToLOC       NVARCHAR( 10) 
   ,@cToID        NVARCHAR( 18) 
   ,@cLottable01  NVARCHAR( 18) 
   ,@cLottable02  NVARCHAR( 18) 
   ,@cLottable03  NVARCHAR( 18) 
   ,@dLottable04  DATETIME  
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nStep = 3 -- To ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cToID <> ''
         BEGIN
            -- Check ToID is UCC
            IF EXISTS( SELECT 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cToID)
            BEGIN
               SET @nErrNo = 51501
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID is UCCNo
               GOTO Quit
            END
   
            -- Check ToID is label no
            IF EXISTS( SELECT 1 FROM PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cToID)
            BEGIN
               SET @nErrNo = 51502
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID is LabelNo
               GOTO Quit
            END

            -- Check ID is label no
            IF EXISTS( SELECT 1 
               FROM Receipt R WITH (NOLOCK)
                  JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
               WHERE R.StorerKey = @cStorerKey 
                  AND R.ReceiptKey <> @cReceiptKey
                  AND RD.ToID = @cToID 
                  AND RD.FinalizeFlag <> 'Y'
                  AND RD.BeforeReceivedQTY > 0)
            BEGIN
               SET @nErrNo = 51503
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID used
               GOTO Quit
            END
         END
      END
   END

Quit:
END

GO