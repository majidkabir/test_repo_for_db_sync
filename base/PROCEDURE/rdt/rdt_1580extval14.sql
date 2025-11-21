SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal14                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: check mix SKU on carton (L01)                               */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author    Purposes                                  */
/* 28-02-2019  1.0  Ung       WMS-7837 Created                          */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtVal14]
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

   DECLARE @nQTYExpected INT
   DECLARE @nBeforeReceivedQTY INT
   
   IF @nStep = 4 -- Lottable
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Check L02 blank
         IF @cLottable02 = ''
         BEGIN
            SET @nErrNo = 135201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lottable2
            GOTO Quit
         END

         -- Check L02 in ASN
         IF NOT EXISTS( SELECT TOP 1 1 
            FROM ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey 
               AND Lottable02 = @cLottable02)
         BEGIN
            SET @nErrNo = 135202
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L02 not in ASN
            GOTO Quit
         END

         -- Get ReceiptDetail info
         SELECT 
            @nQTYExpected = ISNULL( SUM( QTYExpected), 0), 
            @nBeforeReceivedQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
         FROM ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey 
            AND StorerKey = @cStorerKey 
            AND Lottable02 = @cLottable02
         
         -- Check L02 fully received
         IF @nBeforeReceivedQTY >= @nQTYExpected
         BEGIN
            SET @nErrNo = 135205
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L02 full Recv
            GOTO Quit
         END
      END
   END
   
   IF @nStep = 5 -- SKU, QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN         
         -- Check SKU, L02 in ASN
         IF NOT EXISTS( SELECT TOP 1 1 
            FROM ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey 
               AND StorerKey = @cStorerKey 
               AND SKU = @cSKU 
               AND Lottable02 = @cLottable02)
         BEGIN
            SET @nErrNo = 135203
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUL02NotInASN
            GOTO Quit
         END

         -- Get ReceiptDetail info
         SELECT 
            @nQTYExpected = ISNULL( SUM( QTYExpected), 0), 
            @nBeforeReceivedQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
         FROM ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey 
            AND StorerKey = @cStorerKey 
            AND SKU = @cSKU 
            AND Lottable02 = @cLottable02
         
         -- Check over receive SKU, L02
         IF @nQTYExpected < @nBeforeReceivedQTY + @nQTY
         BEGIN
            SET @nErrNo = 135204
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUL02OverRecv
            GOTO Quit
         END
      END
   END
         
Quit:

END

GO