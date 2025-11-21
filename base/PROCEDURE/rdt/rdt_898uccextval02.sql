SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_898UCCExtVal02                                     */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2017-05-03 1.0  James   WMS1803.Created                                 */
/***************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898UCCExtVal02]
    @nMobile     INT
   ,@nFunc       INT
   ,@cLangCode   NVARCHAR(  3)
   ,@cReceiptKey NVARCHAR( 10)
   ,@cPOKey      NVARCHAR( 10)
   ,@cLOC        NVARCHAR( 10)
   ,@cToID       NVARCHAR( 18)
   ,@cLottable01 NVARCHAR( 18)
   ,@cLottable02 NVARCHAR( 18)
   ,@cLottable03 NVARCHAR( 18)
   ,@dLottable04 DATETIME
   ,@cUCC        NVARCHAR( 20)
   ,@nErrNo      INT           OUTPUT
   ,@cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cRD_Lottable01       NVARCHAR( 18)
   DECLARE @cUCC_Lottable01      NVARCHAR( 18)
   DECLARE @cStorerKey           NVARCHAR( 15)
   DECLARE @nStep                INT
   DECLARE @nTtl_UCCQty          INT
   DECLARE @nTtl_RDUCCQty        INT

   SELECT @nStep = Step, 
          @cStorerKey = StorerKey
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nFunc = 898 -- UCC receiving
   BEGIN
      IF @nStep = 6
      BEGIN
         -- Get current UCC is single/multi SKU
         DECLARE @nSKUCount INT
         SET @nSKUCount = 0
         SELECT @nSKUCount = COUNT( DISTINCT UCC.SKU) 
         FROM UCC WITH (NOLOCK) 
            JOIN SKU WITH (NOLOCK) ON (UCC.StorerKey = SKU.StorerKey AND UCC.SKU = SKU.SKU)
         WHERE UCC.StorerKey = @cStorerKey
            AND UCC.UCCNo = @cUCC
         
         -- Check single UCC mix on multi SKU UCC pallet
         IF @nSKUCount = 1
         BEGIN
            IF EXISTS( SELECT 1
               FROM UCC WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND ID = @cToID
               GROUP BY UCCNo
               HAVING COUNT( DISTINCT SKU) > 1)
            BEGIN
               SET @nErrNo = 108801
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mix Multi UCC
               GOTO Quit
            END
         END

         -- Check multi SKU UCC mix on single SKU UCC pallet
         IF @nSKUCount > 1
         BEGIN
            IF EXISTS( SELECT 1
               FROM UCC WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND ID = @cToID
               GROUP BY UCCNo
               HAVING COUNT( DISTINCT SKU) = 1)
            BEGIN
               SET @nErrNo = 108802
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mix Single UCC
               GOTO Quit
            END
         END

         -- Not allow receive different receiptdetail.lottable01 into one Pallet
         SELECT TOP 1 @cRD_Lottable01 = Lottable01
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
         AND   ToID = @cToID
         ORDER BY Lottable01 DESC -- Get receiptdetail line with lottable01 value first

         SELECT TOP 1 @cUCC_Lottable01 = Lottable01
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
         AND   UserDefine01 = @cUCC

         IF ISNULL( @cRD_Lottable01, '') <> ISNULL( @cUCC_Lottable01, '')
         BEGIN
            SET @nErrNo = 108803
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Diff Lot01
            GOTO Quit
         END

         -- If sum(UCC.qty) <> sum(receiptdetail.qty) group by uccno, not allow to receive
         SELECT @nTtl_UCCQty = ISNULL( SUM( Qty), 0)
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   (( @cPOKey = '') OR ( ReceiptKey = @cPOKey))
         AND   UCCNo = @cUCC

         SELECT @nTtl_RDUCCQty = ISNULL( SUM( BeforeReceivedQty + QtyExpected), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
         AND   UserDefine01 = @cUCC

         IF @nTtl_UCCQty <> @nTtl_RDUCCQty
         BEGIN
            SET @nErrNo = 108804
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCQty X Tally
            GOTO Quit
         END
      END   -- @nStep = 6
   END
   
   
Quit:

END

GO