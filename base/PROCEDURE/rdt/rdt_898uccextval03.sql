SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_898UCCExtVal03                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2019-08-08 1.0  James   WMS10119. Created                            */
/* 2019-10-24 1.1  James   WMS10928. Check if ucc received (james01)    */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898UCCExtVal03]
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
   
   IF @nFunc = 898 -- UCC receiving
   BEGIN
      DECLARE @nUCCIsMixedSKU    INT
      DECLARE @nToIDIsMixedSKU   INT
      DECLARE @cStorerKey        NVARCHAR( 15)
      DECLARE @cUCC_SKU          NVARCHAR( 20)
      DECLARE @cID_SKU           NVARCHAR( 20)
      DECLARE @cUCCStatus        NVARCHAR( 1) = ''

      SELECT @cStorerKey = StorerKey
      FROM dbo.Receipt WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      -- (james01)
      --check UCC status
      SELECT @cUCCStatus = STATUS
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   UCCNo = @cUCC

      IF RTRIM(@cUCCStatus) = '1'
      BEGIN
         SET @nErrNo = 142704
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Received
         GOTO Quit
      END

      -- No ToID, no need check
      IF ISNULL( @cToID, '') = ''
         GOTO Quit

      -- ToID not yet received anything, no need check
      IF NOT EXISTS ( SELECT 1 
                        FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                        WHERE ReceiptKey = @cReceiptKey
                        AND   ToId = @cToID
                        AND   BeforeReceivedQty > 0)
         GOTO Quit

      SET @nUCCIsMixedSKU = 0

      -- Check ucc mix sku
      IF EXISTS ( SELECT 1 
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC
         AND   Status = '0'
         GROUP BY UCCNo 
         HAVING COUNT( DISTINCT SKU) > 1)
         SET @nUCCIsMixedSKU = 1

      SET @nToIDIsMixedSKU = 0

      -- Check ToID mix sku
      IF EXISTS ( SELECT 1 
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   ToId = @cToID
         AND   BeforeReceivedQty > 0
         GROUP BY ToId 
         HAVING COUNT( DISTINCT SKU) > 1)
         SET @nToIDIsMixedSKU = 1

      -- If id mix sku, only allow receive ucc with mix sku
      -- If id single sku, only allow receive ucc with single sku
      IF @nToIDIsMixedSKU = 1
      BEGIN
         IF @nUCCIsMixedSKU = 0
         BEGIN
            SET @nErrNo = 142701
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDMix UCCNot
         END
      END
      ELSE
      BEGIN -- IF @nToIDIsMixedSKU = 0
         IF @nUCCIsMixedSKU = 1
         BEGIN
            SET @nErrNo = 142702
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCMix IDNot
         END
         ELSE
         BEGIN
            -- To id not mix sku, check if received sku same as ucc sku
            SELECT TOP 1 @cID_SKU = SKU
            FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND   ToId = @cToID
            AND   BeforeReceivedQty > 0
            ORDER BY 1

            SELECT @cUCC_SKU = SKU
            FROM dbo.UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   UCCNo = @cUCC
            AND   Status = '0'

            IF @cID_SKU <> @cUCC_SKU
            BEGIN
               SET @nErrNo = 142703
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCMix IDNot
            END
         END
      END
   END
   
Quit:

END

GO