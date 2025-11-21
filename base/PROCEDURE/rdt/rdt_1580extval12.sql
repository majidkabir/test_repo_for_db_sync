SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal12                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: check mix SKU on carton (L01)                               */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 25-10-2018  1.0  ChewKP      WMS-6769 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtVal12]
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

   DECLARE @nReceivedQty   INT
          ,@nExpectedQty   INT
   
   IF @nStep = 4 -- Lottable
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Check L01 (RSO) blank
         IF @cLottable01 = ''
         BEGIN
            SET @nErrNo = 130651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lottable1
            GOTO Quit
         END
         
         -- Check L01 in ASN
         IF NOT EXISTS( SELECT TOP 1 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND Lottable01 = @cLottable01)
         BEGIN
            SET @nErrNo = 130652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid L01
            GOTO Quit
         END
      END
   END

   IF @nStep = 5 -- SKU, QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Check SKU in ASN
         IF NOT EXISTS( SELECT TOP 1 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND Lottable01 = @cLottable01 AND SKU = @cSKU)
         BEGIN
            SET @nErrNo = 130653
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            GOTO Quit
         END
         
         SET @nReceivedQty = 0 
         SET @nExpectedQty = 0 

         SELECT @nReceivedQty = SUM(BeforeReceivedQty)
               ,@nExpectedQty = SUM(QtyExpected)
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey 
         AND Lottable01 = @cLottable01 
         AND SKU = @cSKU
         GROUP BY ReceiptKey, Lottable01, SKU 
         
         IF (@nReceivedQty + 1 )  > @nExpectedQty 
         BEGIN
            SET @nErrNo = 130654
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OverReceivedRSO
            GOTO Quit
         END
         
         
         
      END
   END
         
Quit:
END

GO