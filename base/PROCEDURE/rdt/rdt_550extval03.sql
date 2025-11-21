SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_550ExtVal03                                     */
/* Purpose: Update DropID                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* To check if over receive by ASN + pallet id + SKU.                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-11-26 1.0  Ung        SOS326375 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_550ExtVal03] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,
   @cLottable01  NVARCHAR(18),
   @cLottable02  NVARCHAR(18),
   @cLottable03  NVARCHAR(18),
   @dLottable04  DATETIME,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nQty_Received INT
   DECLARE @nQty_Expected INT

   IF @nFunc = 550 -- Normal receiving
   BEGIN
      IF @nStep = 6 -- Lottables
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get L02 received
            SELECT @nQty_Received = ISNULL( SUM( BeforeReceivedQty), 0)
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND SKU = @cSKU
               AND Lottable02 = @cLottable02

            -- Get L02 expected
            SELECT @nQty_Expected = ISNULL( SUM( QtyExpected), 0)
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND SKU = @cSKU
               AND Lottable02 = @cLottable02

            -- Check L02 over received
            IF @nQty_Received + @nQty > @nQty_Expected
            BEGIN
               SET @nErrNo = 92251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OVER RECEIVED
               GOTO Quit
            END

            -- Receive with pallet ID
            IF @cID <> ''
            BEGIN
               -- Check pallet have multi SKU
               IF NOT EXISTS( SELECT 1 
                  FROM ReceiptDetail WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                     AND ToID = @cID
                     AND SKU <> @cSKU
                     AND BeforeReceivedQTY > 0)
               BEGIN
                  -- Get pallet count
                  DECLARE @nPalletCnt INT
                  SELECT @nPalletCnt = Pallet 
                  FROM SKU WITH (NOLOCK) 
                     JOIN Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
                  WHERE SKU.StorerKey = @cStorerKey
                     AND SKU.SKU = @cSKU
                  
                  -- Get existing pallet QTY
                  DECLARE @nPalletQTY INT
                  SELECT @nPalletQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
                  FROM ReceiptDetail WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                     AND ToID = @cID
                     AND SKU = @cSKU
                     AND BeforeReceivedQTY > 0
                  
                  -- Check pallet over received
                  IF @nPalletQTY + @nQty > @nPalletCnt
                  BEGIN
                     SET @nErrNo = 92252
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PL OverReceive
                     GOTO Quit
                  END
               END
            END     
         END
      END
   END
Quit:


GO