SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_PalletReceive_Confirm                                 */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Receive ASN by pallet ID                                          */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2015-08-18 1.0  Ung        SOS347636 Created                               */
/* 2023-03-28 1.1  James      WMS-21934 Add DefaultToLoc config (james01)     */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_PalletReceive_Confirm] (
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR(  3),
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR(  5),
   @cReceiptKey    NVARCHAR( 10),
   @cToID          NVARCHAR( 18),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL         NVARCHAR( MAX)
   DECLARE @cSQLParam    NVARCHAR( MAX)

   DECLARE @cToLOC       NVARCHAR( 10)
   DECLARE @cSKU         NVARCHAR( 20)
   DECLARE @cUOM         NVARCHAR( 10)
   DECLARE @nQTY         INT           -- In master unit
   DECLARE @cLottable01  NVARCHAR( 18)
   DECLARE @cLottable02  NVARCHAR( 18)
   DECLARE @cLottable03  NVARCHAR( 18)
   DECLARE @dLottable04  DATETIME
   DECLARE @dLottable05  DATETIME
   DECLARE @cLottable06  NVARCHAR( 30)
   DECLARE @cLottable07  NVARCHAR( 30)
   DECLARE @cLottable08  NVARCHAR( 30)
   DECLARE @cLottable09  NVARCHAR( 30)
   DECLARE @cLottable10  NVARCHAR( 30)
   DECLARE @cLottable11  NVARCHAR( 30)
   DECLARE @cLottable12  NVARCHAR( 30)
   DECLARE @dLottable13  DATETIME
   DECLARE @dLottable14  DATETIME
   DECLARE @dLottable15  DATETIME
   DECLARE @cReceiptLineNumberOutput NVARCHAR( 5)
   DECLARE @cDefaultToLoc  NVARCHAR( 10)
   
   -- Get storer config
   DECLARE @cRcptConfirmSP NVARCHAR( 20)
   SET @cRcptConfirmSP = rdt.RDTGetConfig( @nFunc, 'ReceiptConfirm_SP', @cStorerKey)
   IF @cRcptConfirmSP = '0'
      SET @cRcptConfirmSP = ''

   SET @cDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'DefaultToLoc', @cStorerKey)
   IF @cDefaultToLoc = '0'
      SET @cDefaultToLoc = ''

   -- Custom receiving logic
   IF @cRcptConfirmSP <> ''
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirmSP) +
         ' @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, @cReceiptKey, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT '
      SET @cSQLParam =
         '@nFunc        INT,            ' +
         '@nMobile      INT,            ' +
         '@cLangCode    NVARCHAR( 3),   ' +
         '@cStorerKey   NVARCHAR( 15),  ' +
         '@cFacility    NVARCHAR( 5),   ' +
         '@cReceiptKey  NVARCHAR( 10),  ' +
         '@cToID        NVARCHAR( 18),  ' +
         '@nErrNo       INT           OUTPUT, ' +
         '@cErrMsg      NVARCHAR( 20) OUTPUT  '
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, @cReceiptKey, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT
      GOTO Quit
   END

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PalletReceive_Confirm -- For rollback or commit only our own transaction

   DECLARE @curReceipt CURSOR
   SET @curReceipt = CURSOR FOR
      SELECT
         ToLOC, SKU, QTYExpected,
         Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND ToID = @cToID
         AND BeforeReceivedQTY = 0
      ORDER BY ReceiptLineNumber
   OPEN @curReceipt
   FETCH NEXT FROM @curReceipt INTO @cToLOC, @cSKU, @nQTY,
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15

   WHILE @@FETCH_STATUS = 0
   BEGIN
   	IF @cDefaultToLoc <> '' SET @cToLOC = @cDefaultToLoc
   	
      -- Get SKU info
      SELECT @cUOM = Pack.PackUOM3
      FROM SKU WITH (NOLOCK)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

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
         @cSKUCode      = @cSKU,
         @cSKUUOM       = @cUOM,
         @nSKUQTY       = @nQTY,
         @cUCC          = '',
         @cUCCSKU       = '',
         @nUCCQTY       = '',
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
         @cConditionCode = 'OK',
         @cSubreasonCode = '',
         @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      FETCH NEXT FROM @curReceipt INTO @cToLOC, @cSKU, @nQTY,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15
   END

GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PalletReceive_Confirm
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO