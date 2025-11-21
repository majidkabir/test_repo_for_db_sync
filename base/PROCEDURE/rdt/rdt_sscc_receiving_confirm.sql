SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_SSCC_Receiving_Confirm                             */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2021-12-09 1.0  James   WMS-18515. Created                              */
/***************************************************************************/

CREATE PROC [RDT].[rdt_SSCC_Receiving_Confirm](
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @dArriveDate    DATETIME,
   @cReceiptKey    NVARCHAR( 10),
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18),
   @cSKUCode       NVARCHAR( 20),
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,
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
   @cSSCC          NVARCHAR( 30),
   @cConditionCode NVARCHAR( 10) = 'OK',
   @cSubreasonCode NVARCHAR( 10) = '',
   @tConfirmVar    VARIABLETABLE READONLY,
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT

) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cRcptConfirmSP NVARCHAR( 20)

   -- Get storer configure
   SET @cRcptConfirmSP = rdt.RDTGetConfig( @nFunc, 'ReceiptConfirm_SP', @cStorerKey)
   IF @cRcptConfirmSP = '0'
      SET @cRcptConfirmSP = ''

   IF @cConditionCode = ''
      SET @cConditionCode = 'OK'

   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   -- Custom receive logic
   IF @cRcptConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRcptConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirmSP) +
            ' @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, ' +
            ' @dArriveDate, @cReceiptKey, @cRefNo, @cToLOC, @cToID, @cSKUCode, @cSKUUOM, @nSKUQTY, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @cSSCC, @cConditionCode, @cSubreasonCode, @tConfirmVar, ' +
            ' @cReceiptLineNumber OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nFunc          INT,            ' +
            '@nMobile        INT,            ' +
            '@cLangCode      NVARCHAR( 3),   ' +
            '@cStorerKey     NVARCHAR( 15),  ' +
            '@cFacility      NVARCHAR( 5),   ' +
            '@dArriveDate    DATETIME,       ' +
            '@cReceiptKey    NVARCHAR( 10),  ' +
            '@cToLOC         NVARCHAR( 10),  ' +
            '@cToID          NVARCHAR( 18),  ' +
            '@cSKUCode       NVARCHAR( 20),  ' +
            '@cSKUUOM        NVARCHAR( 10),  ' +
            '@nSKUQTY        INT,        ' +
            '@cLottable01    NVARCHAR( 18),  ' +
            '@cLottable02    NVARCHAR( 18),  ' +
            '@cLottable03    NVARCHAR( 18),  ' +
            '@dLottable04    DATETIME,       ' +
            '@dLottable05    DATETIME,       ' +
            '@cLottable06    NVARCHAR( 30),  ' +
            '@cLottable07    NVARCHAR( 30),  ' +
            '@cLottable08    NVARCHAR( 30),  ' +
            '@cLottable09    NVARCHAR( 30),  ' +
            '@cLottable10    NVARCHAR( 30),  ' +
            '@cLottable11    NVARCHAR( 30),  ' +
            '@cLottable12    NVARCHAR( 30),  ' +
            '@dLottable13    DATETIME,       ' +
            '@dLottable14    DATETIME,       ' +
            '@dLottable15    DATETIME,       ' +
            '@cSSCC          NVARCHAR( 30),  ' +
            '@cConditionCode NVARCHAR( 10),  ' +
            '@cSubreasonCode NVARCHAR( 10),  ' +
            '@tConfirmVar    VARIABLETABLE READONLY, ' +
            '@cReceiptLineNumber NVARCHAR( 5) OUTPUT, ' +
            '@nErrNo         INT           OUTPUT, ' +
            '@cErrMsg        NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility,
            @dArriveDate, @cReceiptKey, @cToLOC, @cToID, @cSKUCode, @cSKUUOM, @nSKUQTY,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, NULL,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @cSSCC, @cConditionCode, @cSubreasonCode, @tConfirmVar,
            @cReceiptLineNumber OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
   DECLARE @cDefaultToLoc     NVARCHAR( 10)
   DECLARE @cDefaultToId      NVARCHAR( 20)

   -- Get storer configure
   SET @cDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'DefaultToLoc', @cStorerKey)
   IF @cDefaultToLoc = '0'
      SET @cDefaultToLoc = ''

   SET @cDefaultToId = rdt.RDTGetConfig( @nFunc, 'DefaultToId', @cStorerKey)
   SET @cDefaultToId = SUBSTRING( @cDefaultToId, 1, 18) -- ReceiptDetail.ToID only accept 18 chars
   IF @cDefaultToId = '0'
      SET @cDefaultToId = ''

   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_SSCC_Receiving_Confirm

   DECLARE @ccurReceive CURSOR
   SET @ccurReceive = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT ToLoc, ToId, Sku, UOM, QtyExpected,
   Lottable01, Lottable02, Lottable03, Lottable04,
   Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
   Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   UserDefine01 = @cSSCC
   AND   ( QtyExpected - BeforeReceivedQty) > 0
   OPEN @ccurReceive
   FETCH NEXT FROM @ccurReceive INTO @cToLOC, @cToID, @cSKUCode, @cSKUUOM, @nSKUQTY,
   @cLottable01, @cLottable02, @cLottable03, @dLottable04,
   @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
   @cLottable11, @cLottable12, @dLottable13, @dLottable04, @dLottable15
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @cDefaultToLoc <> ''
         SET @cToLOC = @cDefaultToLoc

      IF @cDefaultToId <> ''
         SET @cToID = @cDefaultToId

      -- Receive
      EXEC rdt.rdt_Receive_V7
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo  OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = 'NOPO',
         @cToLOC        = @cToLOC,
         @cToID         = @cToID,
         @cSKUCode      = @cSKUCode,
         @cSKUUOM       = @cSKUUOM,
         @nSKUQTY       = @nSKUQTY,
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
         @cConditionCode = 'OK',--@cConditionCode,
         @cSubreasonCode = @cSubreasonCode,
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT

      IF @nErrNo <> 0
         GOTO RollBackTran

      FETCH NEXT FROM @ccurReceive INTO @cToLOC, @cToID, @cSKUCode, @cSKUUOM, @nSKUQTY,
      @cLottable01, @cLottable02, @cLottable03, @dLottable04,
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
      @cLottable11, @cLottable12, @dLottable13, @dLottable04, @dLottable15
   END

   -- Stock arrive date
   IF @dArriveDate IS NOT NULL
   BEGIN
      IF EXISTS( SELECT 1 FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ReceiptDate <> @dArriveDate)
      BEGIN
         UPDATE Receipt SET
            ReceiptDate = @dArriveDate,
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
         WHERE ReceiptKey = @cReceiptKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END
   END

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '2', -- Receiving
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey,
      @cReceiptKey   = @cReceiptKey,
      @cLocation     = @cToLOC,
      @cID           = @cToID,
      @cSKU          = @cSKUCode,
      @cUOM          = @cSKUUOM,
      @nQTY          = @nSKUQTY,
      @cLottable01   = @cLottable01,
      @cLottable02   = @cLottable02,
      @cLottable03   = @cLottable03,
      @dLottable04   = @dLottable04,
      @dLottable05   = @dLottable05,
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
      @cCartonID     = @cSSCC

   GOTO QUIT

RollBackTran:
   ROLLBACK TRAN rdt_SSCC_Receiving_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO