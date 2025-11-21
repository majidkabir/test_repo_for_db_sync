SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1581ExtVal02                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: check mix SKU on carton (L01)                               */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 18-04-2018  1.0  Ung         WMS-4695 Created                        */
/* 18-10-2018  1.1  James       WMS-6749-Remove chk SKU in ASN (james01)*/
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1581ExtVal02]
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
   
   IF @nStep = 4 -- Lottable
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Check L01 (RSO) blank
         IF @cLottable01 = ''
         BEGIN
            SET @nErrNo = 123051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lottable1
            GOTO Quit
         END
         
         -- Check L01 in ASN
         IF NOT EXISTS( SELECT TOP 1 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND Lottable01 = @cLottable01)
         BEGIN
            SET @nErrNo = 123052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid L01
            GOTO Quit
         END
      END
   END
   /*
   IF @nStep = 5 -- SKU, QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Check SKU in ASN
         IF NOT EXISTS( SELECT TOP 1 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND Lottable01 = @cLottable01 AND SKU = @cSKU)
         BEGIN
            SET @nErrNo = 123053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            GOTO Quit
         END
      END
   END
   */      
Quit:
END

GO