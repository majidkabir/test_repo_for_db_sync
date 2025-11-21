SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_898RcvCfm09                                           */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Support transfer UCC with multi SKU, even same SKU multi lines    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2021-12-10 1.0  Ung        WMS-18390 Created                               */
/* 2022-08-12 1.1  YeeKung    JSM-83781 Add rollback tran (yeekung01)         */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_898RcvCfm09] (
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT,
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10),
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18),
   @cSKUCode       NVARCHAR( 20),
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,
   @cCreateUCC     NVARCHAR( 1),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10)
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount   INT
   DECLARE @nRowCount    INT
   DECLARE @nTransferASN INT = 0
   DECLARE @nUCC_RowRef  INT
   DECLARE @cLOT         NVARCHAR( 10) = ''
   DECLARE @cUOM         NVARCHAR( 10)
   DECLARE @cUCC_POKey   NVARCHAR( 10)
   DECLARE @cNotFinalizeRD NVARCHAR(1)
   DECLARE @cReceiptLineNumber NVARCHAR( 5) = ''

   SET @nTranCount = @@TRANCOUNT
   SET @nTransferASN = 0

   -- Get the UCC line not yet received
   SELECT TOP 1
      @nUCC_RowRef = UCC_RowRef,
      @cUCC_POKey = SUBSTRING( SourceKey, 1, 10)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cUCC
      AND StorerKey = @cStorerKey
      AND Status = '0'
   ORDER BY UCC_RowRef

   /*
      Transfer UCC with same SKU multiple line, but wrong POType, is treated as normal multi SKU UCC
      rdt_Receive update UCC is by SKU (not lines), causing next loop of same SKU have no UCC.status = 0
   */
   IF @@ROWCOUNT <> 1
   BEGIN
      SET @nErrNo = 179901
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PO/UCC DataErr
      GOTO Quit
   END

   -- Check if transfer ASN
   IF EXISTS( SELECT 1 FROM dbo.PO WITH (NOLOCK) WHERE POKey = @cUCC_POKey AND POType = 'STO')
      SET @nTransferASN = 1

   -- Transfer ASN
   IF @nTransferASN = 1
   BEGIN
      -- Get SKU info
      SELECT @cUOM = PACKUOM3
      FROM dbo.SKU WITH (NOLOCK)
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PACKKey = PACK.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cUCCSKU

      -- Get finalize setting
      SET @cNotFinalizeRD = rdt.RDTGetConfig( 0, 'RDT_NotFinalizeReceiptDetail', @cStorerKey)

      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_898RcvCfm09 -- For rollback or commit only our own transaction

      /*
         Transfer UCC:
            1 UCC multi SKU
            1 UCC multi PO
            Same SKU in UCC multi lines (coz different PO)

         Easiest is receive as loose (with filter to tie ReceiptDetail and UCC), then manually update that UCC line
         Need to stamp the UCC on MobRec, for use in FilterSP later, as below is not passing-in UCC
      */
      -- Stamp UCC (for use in filter SP later)
      UPDATE rdt.rdtMobRec SET
         V_UCC = @cUCC,
         EditDate = GETDATE()
      WHERE Mobile = @nMobile
      IF @@ERROR <> 0
         GOTO RollBackTran

      -- Receive as loose QTY (without UCC)
      EXEC rdt.rdt_Receive
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cUCC_POKey,
         @cToLOC        = @cToLOC,
         @cToID         = @cTOID,
         @cSKUCode      = @cUCCSKU,
         @cSKUUOM       = @cUOM,
         @nSKUQTY       = @nUCCQTY,
         @cUCC          = '',
         @cUCCSKU       = '',
         @nUCCQTY       = 0,
         @cCreateUCC    = @cCreateUCC,
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = @dLottable05,
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = @cSubreasonCode,
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      -- Auto finalize, get the LOT
      IF @cNotFinalizeRD <> '1'  -- 1=Not finalize
         SELECT @cLOT = LOT
         FROM dbo.ITRn WITH (NOLOCK)
         WHERE SourceKey = @cReceiptKey + @cReceiptLineNumber
            AND TranType = 'DP'

      UPDATE dbo.UCC SET
         LOT = @cLOT,
         LOC = @cToLOC,
         ID = @cTOID,
         Status = '1',
         ReceiptKey = @cReceiptKey,
         ReceiptLineNumber = @cReceiptLineNumber,
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE UCC_RowRef = @nUCC_RowRef
      SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
      IF @nErrNo <> 0 OR @nRowCount <> 1
         GOTO RollBackTran

      COMMIT TRAN rdt_898RcvCfm09
      GOTO Quit
   END

   -- Normal ASN
   ELSE
   BEGIN
       -- Stamp UCC (for use in filter SP later)
      UPDATE rdt.rdtMobRec SET
         V_UCC = @cUCC,
         EditDate = GETDATE()
      WHERE Mobile = @nMobile
      IF @@ERROR <> 0
         GOTO RollBackTran

      EXEC rdt.rdt_Receive
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cUCC_POKey,
         @cToLOC        = @cToLOC,
         @cToID         = @cTOID,
         @cSKUCode      = '',
         @cSKUUOM       = '',
         @nSKUQTY       = '',
         @cUCC          = @cUCC,
         @cUCCSKU       = @cUCCSKU,
         @nUCCQTY       = @nUCCQTY,
         @cCreateUCC    = @cCreateUCC,
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = @dLottable05,
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = @cSubreasonCode,
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
      IF @nErrNo <> 0 --(yeekung01)
         GOTO RollBackTran

      UPDATE dbo.UCC SET
         LOT = @cLOT,
         LOC = @cToLOC,
         ID = @cTOID,
         Status = '1',
         ReceiptKey = @cReceiptKey,
         ReceiptLineNumber = @cReceiptLineNumber,
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE UCC_RowRef = @nUCC_RowRef
      SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
      IF @nErrNo <> 0 OR @nRowCount <> 1
         GOTO RollBackTran

      GOTO Quit
   END

RollBackTran:
   ROLLBACK TRAN rdt_898RcvCfm09

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO