SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_898RcvCfm02                                           */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: If UCC is having multi lines same sku then need to combine first  */
/*          before receive. Create new ucc line with sum(qty) then delete the */
/*          existing multi line ucc. Get the max value for Udf01, 06-10.      */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 2017-05-12 1.0  James       Created. WMS1803                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898RcvCfm02] (
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, -- screen limitation, 20 char max
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10), -- Blank = receive to ReceiptDetail with blank POKey
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18), -- Blank = receive to blank ToID
   @cSKUCode       NVARCHAR( 20), -- SKU code. Not SKU barcode
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,       -- In master unit
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,       -- In master unit. Pass in the QTY for UCCWithDynamicCaseCNT
   @cCreateUCC     NVARCHAR( 1),  -- Create UCC. 1=Yes, the rest=No
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10)
) AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE  @nTranCount          INT
DECLARE  @cSKU                NVARCHAR( 20),
         @cQTY                NVARCHAR( 10), 
         @cUOM                NVARCHAR( 10), 
         @cReceiptLineNumber  NVARCHAR( 5), 
         @cUserdefined01      NVARCHAR( 10), 
         @cUserdefined06      NVARCHAR( 10), 
         @cUserdefined07      NVARCHAR( 10), 
         @cUserdefined08      NVARCHAR( 10), 
         @cUserdefined09      NVARCHAR( 10), 
         @cUserdefined10      NVARCHAR( 10),
         @cUCCWithMultiSKU    NVARCHAR( 1), 
         @cPOKeyValue         NVARCHAR( 10), 
         @cUCC_SKU            NVARCHAR( 20), 
         @nQTY                INT, 
         @nUCC_Qty            INT

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_898RcvCfm02 -- For rollback or commit only our own transaction

   SET @cUCCWithMultiSKU = rdt.RDTGetConfig( @nFunc, 'UCCWithMultiSKU', @cStorerKey)

   IF @cUCCWithMultiSKU = '1'
   BEGIN
      -- If the UCC is having multiple lines then check
      -- whether is mixed sku with multi line
      IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND   UCCNO = @cUCC 
                  AND   [Status] = '0'
                  GROUP BY UCCNo
                  HAVING COUNT( 1) > 1)
      BEGIN
         DECLARE CUR_CHECKUCC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT DISTINCT SKU FROM dbo.UCC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC
         AND   [Status] = '0'
         OPEN CUR_CHECKUCC
         FETCH NEXT FROM CUR_CHECKUCC INTO @cUCC_SKU
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- If the UCC is having same sku multiple lines then 
            -- need combine the 2 lines before perform receiving
            IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   UCCNO = @cUCC 
               AND   [Status] = '0'
               AND   SKU = @cUCC_SKU
               GROUP BY UCCNo, SKU
               HAVING COUNT( 1) > 1)
            BEGIN
               SELECT 
                  @nUCC_Qty = SUM( QTY), 
                  @cUserdefined01 = MAX( Userdefined01), 
                  @cUserdefined06 = MAX( Userdefined06), 
                  @cUserdefined07 = MAX( Userdefined07), 
                  @cUserdefined08 = MAX( Userdefined08), 
                  @cUserdefined09 = MAX( Userdefined09), 
                  @cUserdefined10 = MAX( Userdefined10)
               FROM dbo.UCC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   UCCNO = @cUCC 
               AND   [Status] = '0'
               AND   SKU = @cUCC_SKU

               INSERT INTO dbo.UCC (
                  UCCNo, Storerkey, ExternKey, SKU, Qty, Sourcekey, Sourcetype, 
                  Userdefined01, Userdefined02, Userdefined03, [Status], Lot, Loc, Id, 
                  Receiptkey, ReceiptLineNumber, Orderkey, OrderLineNumber, WaveKey, 
                  PickDetailKey, Userdefined04, Userdefined05, Userdefined06, 
                  Userdefined07, Userdefined08, Userdefined09, Userdefined10) 
               SELECT TOP 1 
                  UCCNo, Storerkey, ExternKey, SKU, @nUCC_Qty AS Qty, Sourcekey, Sourcetype, 
                  @cUserdefined01 AS Userdefined01, Userdefined02, Userdefined03, 'X' AS [Status], Lot, Loc, Id, 
                  Receiptkey, ReceiptLineNumber, Orderkey, OrderLineNumber, WaveKey, 
                  PickDetailKey, Userdefined04, Userdefined05, @cUserdefined01 as Userdefined06, 
                  @cUserdefined07 AS Userdefined07, @cUserdefined08 AS Userdefined08, 
                  @cUserdefined09 AS Userdefined09, @cUserdefined10 AS Userdefined10
               FROM dbo.UCC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   UCCNO = @cUCC 
               AND   [Status] = '0'
               AND   SKU = @cUCC_SKU

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 109201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Combine UCC Err
                  GOTO RollBackTran
               END

               -- Delete existing multiple lines
               DELETE FROM UCC 
               WHERE StorerKey = @cStorerKey
               AND   UCCNO = @cUCC 
               AND   [Status] = '0'
               AND   SKU = @cUCC_SKU

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 109202
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Delete UCC Err
                  GOTO RollBackTran
               END

               -- Activate the new UCC (combined UCC)
               UPDATE dbo.UCC WITH (ROWLOCK) SET 
                  [Status] = '0' 
               WHERE StorerKey = @cStorerKey
               AND   UCCNo = @cUCC 
               AND   [Status] = 'X'
               AND   SKU = @cUCC_SKU

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 109203
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Active UCC Err
                  GOTO RollBackTran
               END
            END   -- UCC same sku multiple lines

            FETCH NEXT FROM CUR_CHECKUCC INTO @cUCC_SKU
         END
         CLOSE CUR_CHECKUCC
         DEALLOCATE CUR_CHECKUCC
      END

      -- Start multi sku ucc receiving
      DECLARE CUR_UCC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT SKU, QTY 
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND   UCCNo = @cUCC
      ORDER BY UCC_RowRef  
      OPEN CUR_UCC
      FETCH NEXT FROM CUR_UCC INTO @cSKU, @cQTY
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Check if UCC + SKU not received only can do receiving.
         -- There is scenario where UCC with miltiple same sku line exist
         -- in UCC table and need ysytem to combine to become 1 UCC line
         -- So cursor may not reflect the current data
         IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey 
                     AND UCCNo = @cUCC
                     AND SKU = @cSKU
                     AND [Status] = '0')
         BEGIN
            -- Get UOM
            SELECT @cUOM = PackUOM3 
            FROM dbo.SKU WITH (NOLOCK) 
               JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSKU
                  
            -- Update ReceiptDetail
            EXEC rdt.rdt_Receive    
               @nFunc         = @nFunc,
               @nMobile       = @nMobile,
               @cLangCode     = @cLangCode,
               @nErrNo        = @nErrNo OUTPUT,
               @cErrMsg       = @cErrMsg OUTPUT,
               @cStorerKey    = @cStorerKey,
               @cFacility     = @cFacility,
               @cReceiptKey   = @cReceiptKey,
               @cPOKey        = @cPOKey,
               @cToLOC        = @cToLOC,
               @cToID         = @cTOID,
               @cSKUCode      = '',
               @cSKUUOM       = '',
               @nSKUQTY       = '',
               @cUCC          = @cUCC,
               @cUCCSKU       = @cSKU,
               @nUCCQTY       = @cQTY,
               @cCreateUCC    = '0',
               @cLottable01   = @cLottable01,
               @cLottable02   = @cLottable02,   
               @cLottable03   = @cLottable03,
               @dLottable04   = @dLottable04,
               @dLottable05   = NULL,
               @nNOPOFlag     = @nNOPOFlag,
               @cConditionCode = 'OK',
               @cSubreasonCode = '' 

            IF @nErrno <> 0
               GOTO RollBackTran
         END

         FETCH NEXT FROM CUR_UCC INTO @cSKU, @cQTY
      END
      CLOSE CUR_UCC
      DEALLOCATE CUR_UCC
   END
   ELSE
   BEGIN
      EXEC rdt.rdt_Receive
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPOKey,
         @cToLOC        = @cToLOC,
         @cToID         = @cTOID,
         @cSKUCode      = '',
         @cSKUUOM       = '',
         @nSKUQTY       = '',
         @cUCC          = @cUCC,
         @cUCCSKU       = @cSku,
         @nUCCQTY       = @cQty,
         @cCreateUCC    = '0',
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = NULL,
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = 'OK',
         @cSubreasonCode = ''

         IF @nErrno <> 0
            GOTO RollBackTran
   END

   GOTO Quit
  
RollBackTran:  
   ROLLBACK TRAN rdt_898RcvCfm02  

Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  

GO