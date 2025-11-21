SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_608ExtVal02                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID only can have 1 sku                          */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 28-02-2018  1.0  ChewKP      WMS-4054. Created                       */
/* 08-09-2022  1.1  Ung         WMS-20348 Expand RefNo to 60 chars      */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtVal02]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cPOKey        NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60),
   @cID           NVARCHAR( 18),
   @cLOC          NVARCHAR( 10),
   @cMethod       NVARCHAR( 1),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @cRDLineNo     NVARCHAR( 10),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cErrMsg1    NVARCHAR( 20),
           @cErrMsg2    NVARCHAR( 20),
           @cErrMsg3    NVARCHAR( 20),
           @cErrMsg4    NVARCHAR( 20),
           @cErrMsg5    NVARCHAR( 20)
               
 

   IF @nStep = 4 -- SKU, QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- 1 pallet only allow 1 sku
--         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
--                     WHERE StorerKey = @cStorerKey
--                     AND   ReceiptKey = @cReceiptKey
--                     AND   ToID = @cToID
--                     AND   BeforeReceivedQty > 0
--                     AND   SKU <> @cSKU)
--         BEGIN
--            SET @nErrNo = 119852
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixSKUinID
--            GOTO Quit
--         END
         
         IF EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                    WHERE StorerKey = @cStorerKey
                    AND   ReceiptKey = @cReceiptKey
                    AND   ToID = @cID
                    --AND   BeforeReceivedQty > 0
                    AND   SKU <> @cSKU)
         BEGIN
            SET @nErrNo = 120101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixSKUinID
            GOTO Quit
         END
         
         
         IF EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK) 
                    WHERE StorerKey = @cStorerKey
                    AND ID = @cID
                    AND SKU <> @cSKU
                    AND Loc = @cLoc
                    AND Qty > 0 )
         BEGIN
            SET @nErrNo = 120102
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixSKUinID
            GOTO Quit
         END

      END
   END

Quit:
END

GO