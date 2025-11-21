SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_SSCC_Receiving1_Confirm                                  */
/* Copyright      : LFLogistics                                                  */
/*                                                                               */
/* Purpose: SSCC receiving                                                       */
/*                                                                               */
/* Date       Rev  Author   Purposes                                             */
/* 2023-03-01 1.0  Ung      WMS-21709 Created                                    */
/*********************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_SSCC_Receiving1_Confirm] (
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT, 
   @nInputKey      INT, 
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cRefNo         NVARCHAR( 20),
   @cLOC           NVARCHAR( 10),
   @cID            NVARCHAR( 18),
   @cPalletSSCC    NVARCHAR( 30), 
   @cCaseSSCC      NVARCHAR( 30), 
   @cSKU           NVARCHAR( 20),
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
   @nQTY           INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT,
   @cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)

   DECLARE @cRcptConfirmSP NVARCHAR( 20)
   SET @cRcptConfirmSP = rdt.RDTGetConfig( @nFunc, 'ReceiptConfirm_SP', @cStorerKey)
   IF @cRcptConfirmSP = '0'
      SET @cRcptConfirmSP = ''

   /***********************************************************************************************
                                          Custom confirm
   ***********************************************************************************************/
   -- Custom logic
   IF @cRcptConfirmSP <> ''
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirmSP) +
         ' @nFunc, @nMobile, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' + 
         ' @cReceiptKey, @cRefNo, @cLOC, @cID, @cPalletSSCC, @cCaseSSCC, @cSKU, ' +
         ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
         ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
         ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
         ' @nQTY, @cConditionCode, @cSubreasonCode, ' +
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cReceiptLineNumberOutput OUTPUT '

      SET @cSQLParam =
         '@nFunc          INT,            ' +
         '@nMobile        INT,            ' +
         '@cLangCode      NVARCHAR( 3),   ' +
         '@nStep          INT,            ' + 
         '@nInputKey      INT,            ' + 
         '@cStorerKey     NVARCHAR( 15),  ' +
         '@cFacility      NVARCHAR( 5),   ' +
         '@cReceiptKey    NVARCHAR( 10),  ' +
         '@cRefNo         NVARCHAR( 20),  ' +
         '@cLOC           NVARCHAR( 10),  ' +
         '@cID            NVARCHAR( 18),  ' +
         '@cPalletSSCC    NVARCHAR( 30),  ' +
         '@cCaseSSCC      NVARCHAR( 30),  ' +
         '@cSKU           NVARCHAR( 20),  ' +
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
         '@nQTY           INT,            ' +
         '@cConditionCode NVARCHAR( 10),  ' +
         '@cSubreasonCode NVARCHAR( 10),  ' +
         '@nErrNo         INT           OUTPUT, ' +
         '@cErrMsg        NVARCHAR( 20) OUTPUT, ' +
         '@cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nFunc, @nMobile, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
         @cReceiptKey, @cRefNo, @cLOC, @cID, @cPalletSSCC, @cCaseSSCC, @cSKU, 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @nQTY, @cConditionCode, @cSubreasonCode, 
         @nErrNo OUTPUT, @cErrMsg OUTPUT, @cReceiptLineNumberOutput OUTPUT 
   
      GOTO Quit
   END

   /***********************************************************************************************
                                          Standard confirm
   ***********************************************************************************************/
   -- Get UOM
   DECLARE @cUOM NVARCHAR(10)
   SELECT @cUOM = Pack.PackUOM3
   FROM dbo.SKU WITH (NOLOCK)
      JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_SSCC_Receiving1_Confirm -- For rollback or commit only our own transaction
   
   -- Receive
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
      @cToLOC        = @cLOC,
      @cToID         = @cID,
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
      @nNOPOFlag     = 1, -- 1=NOPO
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = '',
      @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '2', -- Receiving
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey,
      @cReceiptKey   = @cReceiptKey,
      @cLocation     = @cLOC,
      @cID           = @cID,
      @cSKU          = @cSKU,
      @cUOM          = @cUOM,
      @nQTY          = @nQTY,
      @cRefNo1       = @cRefNo,
      @cReasonKey    = @cConditionCode,
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
      @dLottable15   = @dLottable15

   COMMIT TRAN rdt_SSCC_Receiving1_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_SSCC_Receiving1_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO