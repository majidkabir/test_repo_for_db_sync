SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_608ExtVal09                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: validate To ID only can have 1 sku                          */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2021-01-07  1.0  James       WMS-16046. Created                      */
/* 2022-09-08  1.1  Ung         WMS-20348 Expand RefNo to 60 chars      */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtVal09]
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

   DECLARE @cReceiptGroup        NVARCHAR( 10)
   DECLARE @nTtl_ExpectedQty     INT
   DECLARE @nTtl_B4ReceivedQty   INT
   
   IF @nFunc = 608 -- Piece return 
   BEGIN
      IF @nStep = 4 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check ID only 1 SKU
            IF EXISTS( SELECT 1 
               FROM dbo.ReceiptDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND ReceiptKey = @cReceiptKey
                  AND ToID = @cID
                  AND BeforeReceivedQty > 0
                  AND SKU <> @cSKU)
            BEGIN
               SET @nErrNo = 162001
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixSKUinID
               GOTO Quit
            END
         
            SELECT @cReceiptGroup = ReceiptGroup
            FROM dbo.RECEIPT WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
         
            IF @cReceiptGroup = 'R'
            BEGIN
               SELECT @nTtl_ExpectedQty = SUM( QtyExpected), 
                      @nTtl_B4ReceivedQty = SUM( BeforeReceivedQty)
               FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND   Sku = @cSKU
            
               IF ( @nTtl_B4ReceivedQty + @nQTY) > @nTtl_ExpectedQty
               BEGIN
                  SET @nErrNo = 162002
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Receive
                  GOTO Quit
               END
            
               IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
                               WHERE ReceiptKey = @cReceiptKey 
                               AND Sku = @cSKU)
               BEGIN
                  SET @nErrNo = 162003
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotAllowAddSKU
                  GOTO Quit
               END
            END
         END
      END

      IF @nStep = 5 -- Lottable after
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check ID only 1 SKU + 1 L01
            IF EXISTS( SELECT 1 
               FROM dbo.ReceiptDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND ReceiptKey = @cReceiptKey
                  AND ToID = @cID
                  AND BeforeReceivedQty > 0
                  AND ((SKU <> @cSKU) OR (Lottable01 <> @cLottable01)))
            BEGIN
               SET @nErrNo = 162004
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixL01inID
               GOTO Quit
            END
         END
      END
   END
   
Quit:

END

GO