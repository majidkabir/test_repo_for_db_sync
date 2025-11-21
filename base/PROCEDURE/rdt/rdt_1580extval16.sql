SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal16                                    */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Check TO ID valid.                                          */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-04-29 1.0  James      WMS-13044 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1580ExtVal16] (
   @nMobile      INT,
   @nFunc        INT,
   @nStep        INT,
   @nInputKey    INT,
   @cLangCode    NVARCHAR( 3),
   @cStorerkey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey    NVARCHAR( 10),
   @cExtASN      NVARCHAR( 20),
   @cToLOC       NVARCHAR( 10),
   @cToID        NVARCHAR( 18),
   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,    
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT          
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
  
   
   IF @nStep = 4 -- Lottables
   BEGIN
      IF @nInputKey = 1 
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                         WHERE ReceiptKey = @cReceiptKey
                         AND   UserDefine01 = @cLottable01)
         BEGIN
            SET @nErrNo = 151501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UCC NOT EXISTS 
            GOTO Quit
         END
      END   
   END      

   IF @nStep = 5 -- SKU/QTY
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                      WHERE ReceiptKey = @cReceiptKey
                      AND   SKU = @cSKU
                      AND   UserDefine01 = @cLottable01)
      BEGIN
         SET @nErrNo = 151502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU NOT IN UCC 
         GOTO Quit
      END
   END

   Quit:


GO