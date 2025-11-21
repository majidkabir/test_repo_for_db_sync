SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_598RcvCfm02                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Receive across multiple ASN                                       */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2021-06-24 1.0  Chermaine  WMS-17244 Created                               */
/* 2022-07-19 2.0  Ung        WMS-20246 Change V_String40 to 41               */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_598RcvCfm02] (
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cRefNo         NVARCHAR( 20),
   @cColumnName    NVARCHAR( 20),
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18), -- Blank = receive to blank ToID
   @cSKUCode       NVARCHAR( 20), -- SKU code. Not SKU barcode
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,           -- In master unit
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,           -- In master unit. Pass in the QTY for UCCWithDynamicCaseCNT
   @cCreateUCC     NVARCHAR( 1),  -- Create UCC. 1=Yes, the rest=No
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,
   @dLottable14    DATETIME,
   @dLottable15    DATETIME,
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10),
   @nErrNo         INT                    OUTPUT,
   @cErrMsg        NVARCHAR( 20)          OUTPUT,
   @cReceiptKeyOutput NVARCHAR( 10)       OUTPUT,
   @cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT,
   @cDebug         NVARCHAR( 1) = '0'
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cReceiptKey  NVARCHAR(10)
DECLARE @nQTY_Bal     INT
DECLARE @nUcc_QTY     INT
DECLARE @nRD_Qty      INT
DECLARE @cExternReceiptKey NVARCHAR( 20)
DECLARE @cBusr7         NVARCHAR(30)
DECLARE @cItemClass     NVARCHAR(10)
DECLARE @cSKU           NVARCHAR(20)
DECLARE @cToLot         NVARCHAR(10) --(cc01)

-- Copy QTY to process
SET @nQTY_Bal = @nSKUQTY

-- Handling transaction
DECLARE @nTranCount INT
SET @nTranCount = @@TRANCOUNT
BEGIN TRAN  -- Begin our own transaction
SAVE TRAN rdt_598RcvCfm02 -- For rollback or commit only our own transaction

SELECT @cUCC = V_String41 FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile

SET @cConditionCode = 'OK'

SELECT top 1
   @cItemClass = s.ItemClass,
   @cBusr7 = S.Busr7
FROM UCC u WITH (NOLOCK)
JOIN Receipt R WITH (NOLOCK) ON (R.externreceiptkey = U.ExternKey AND R.StorerKey = U.Storerkey)
Join ReceiptDetail RD WITH (nolock) on (R.ReceiptKey = RD.ReceiptKey and R.StorerKey = RD.StorerKey and RD.SKU = U.SKU)
JOIN SKU S WITH (nolock) on (S.SKU = U.SKU and S.StorerKey = U.StorerKey)
WHERE R.UserDefine04 = @cRefNo
AND R.StorerKey = @cStorerKey
AND U.UccNo = @cUCC
AND R.ASNStatus <> 'CANC'

SELECT
   @cLottable02 = UDF03
FROM Codelkup
WHERE ListName = 'SKUGROUP'
AND Storerkey = @cStorerKey
AND Code = @cBusr7

--SELECT top 1
--   @cLottable02 = C.UDF03
--FROM Receipt R WITH (NOLOCK)
--Join ReceiptDetail RD with (nolock) on (R.ReceiptKey = RD.ReceiptKey and R.StorerKey = RD.StorerKey )
--JOIN SKU S with (nolock) on (S.SKU = RD.SKU and S.StorerKey = RD.StorerKey)
--Join Codelkup C WITH (NOLOCK) on (Code = @cBusr7 and C.storerKey = S.StorerKey)
--WHERE R.UserDefine04 = @cRefNo
--AND R.StorerKey = @cStorerKey
--AND R.ASNStatus <> 'CANC'
--AND s.ItemClass = @cItemClass
--and S.Busr7 = @cBusr7
--and RD.ToID <> ''
--and RD.beforeReceivedQty < C.UDF02
--AND C.ListName='SKUGROUP'
--order by RD.editDate desc


DECLARE @curReceipt CURSOR
SET @curReceipt = CURSOR FOR
    SELECT
      RD.ReceiptKey,
      U.Qty,
      S.SKU,
      P.PackUOM3,
      ISNULL( SUM( QTYExpected-BeforeReceivedQTY), 0)
   FROM UCC u WITH (NOLOCK)
   JOIN Receipt R WITH (NOLOCK) ON (R.externreceiptkey = U.ExternKey AND R.StorerKey = U.Storerkey)
   Join ReceiptDetail RD WITH (nolock) on (R.ReceiptKey = RD.ReceiptKey and R.StorerKey = RD.StorerKey and RD.SKU = U.SKU)
   JOIN SKU S WITH (nolock) on (S.SKU = U.SKU and S.StorerKey = U.StorerKey)
   JOIN dbo.Pack P WITH (NOLOCK) ON (S.PackKey = P.PackKey)
   WHERE R.UserDefine04 = @cRefNo
   AND R.StorerKey = @cStorerKey
   AND U.UccNo = @cUCC
   AND R.ASNStatus <> 'CANC'
   GROUP BY RD.ReceiptKey,U.Qty,S.SKU,P.PackUOM3



OPEN @curReceipt
FETCH NEXT FROM @curReceipt INTO @cReceiptKey, @nUcc_QTY, @cSKU, @cSKUUOM, @nRD_Qty
WHILE @@FETCH_STATUS = 0
BEGIN
   IF @nRD_Qty > 0
   BEGIN
      IF @nUcc_QTY < @nRD_Qty
         SET @nRD_Qty = @nUcc_QTY


      EXEC rdt.rdt_Receive_V7
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = 'NOPO',
         @cToLOC        = @cToLOC,
         @cToID         = @cToID,
         @cSKUCode      = '',--@cSKU,
         @cSKUUOM       = @cSKUUOM,
         @nSKUQTY       = '',--@nRD_Qty,
         @cUCC          = @cUCC,
         @cUCCSKU       = @cSKU,--'',
         @nUCCQTY       = @nUcc_QTY,--'',
         @cCreateUCC    = '',
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = NULL,
         @cLottable06   = @cLottable06,
         @cLottable07   = @cLottable07,
         @cLottable08   = @cLottable08,
         @cLottable09   = @cLottable09,
         @cLottable10   = @cLottable10,
         @cLottable11   = @cLottable11,
         @cLottable12   = @cLottable12,
         @dLottable13   = @dLottable13,
         @dLottable14   = @dLottable14,
         @dLottable15   = @dLottable15,
         @nNOPOFlag     = 1,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = '',
         @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @cReceiptKeyOutput = @cReceiptKey
      SET @nUcc_QTY = @nUcc_QTY - @nRD_Qty
      --IF @nUcc_QTY = 0
      --   BREAK
   END
   FETCH NEXT FROM @curReceipt INTO @cReceiptKey, @nUcc_QTY, @cSKU, @cSKUUOM, @nRD_Qty
END

---- If still have balance, means offset has error
--IF @nQTY_Bal <> 0
--BEGIN
--   SET @nErrNo = 169551
--   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error
--   GOTO RollBackTran
--END


GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_598RcvCfm02
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO