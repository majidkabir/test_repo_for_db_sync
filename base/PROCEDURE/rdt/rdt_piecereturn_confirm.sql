SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PieceReturn_Confirm                                   */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Receive across multiple ASN                                       */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2015-10-18 1.0  Ung        SOS352968 Created                               */
/* 2017-08-14 1.1  Ung        WMS-2622 Add condition code                     */
/* 2018-04-17 1.2  Ung        WMS-4675 Fix ToIDQTY to include LOC             */
/* 2017-07-26 1.3  ChewKP     WMS-2465 Default Lottable05 (ChewKP01)          */
/* 2019-12-19 1.4  James      WMS-11111 Default L05 on custom cfm (james01)   */
/* 2021-06-21 1.5  James      WMS-17258 Customize the calling of config       */
/*                            ReceiptConfirm_SP to cope with stored proc      */
/*                            rdt_Receive_V7_L05 (james02)                    */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_PieceReturn_Confirm] (
   @nFunc               INT,
   @nMobile             INT,
   @cLangCode           NVARCHAR( 3),
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cReceiptKey         NVARCHAR( 10),
   @cPOKey              NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cID                 NVARCHAR( 18), -- Blank = receive to blank ToID
   @cSKU                NVARCHAR( 20), -- SKU code. Not SKU barcode
   @cUOM                NVARCHAR( 10),
   @nQTY                INT,           -- In master unit
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,
   @cLottable06         NVARCHAR( 30),
   @cLottable07         NVARCHAR( 30),
   @cLottable08         NVARCHAR( 30),
   @cLottable09         NVARCHAR( 30),
   @cLottable10         NVARCHAR( 30),
   @cLottable11         NVARCHAR( 30),
   @cLottable12         NVARCHAR( 30),
   @dLottable13         DATETIME,
   @dLottable14         DATETIME,
   @dLottable15         DATETIME,
   @cConditionCode      NVARCHAR( 10),
   @cSubreasonCode      NVARCHAR( 10),
   @cRDLineNo           NVARCHAR( 5)  OUTPUT,
   @nIDQTY              INT           OUTPUT,
   @nQTYExpected        INT           OUTPUT,
   @nBeforeReceivedQTY  INT           OUTPUT,
   @nErrNo              INT           OUTPUT,
   @cErrMsg             NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cSQL      NVARCHAR( MAX)
DECLARE @cSQLParam NVARCHAR( MAX)

-- NOPO flag
DECLARE @nNOPOFlag INT
SET @nNOPOFlag = CASE WHEN @cPOkey = 'NOPO' THEN 1 ELSE 0 END

-- Reason code
IF @cConditionCode = ''
   SET @cConditionCode = 'OK'

-- Get custom
DECLARE @cRcptConfirmSP NVARCHAR( 20)
SET @cRcptConfirmSP = rdt.RDTGetConfig( @nFunc, 'ReceiptConfirm_SP', @cStorerKey)
IF @cRcptConfirmSP = '0'
   SET @cRcptConfirmSP = ''

-- Custom receiving logic
IF @cRcptConfirmSP <> ''
BEGIN
   SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirmSP) +
      ' @nFunc       = @nFunc,         ' +
      ' @nMobile     = @nMobile,       ' +
      ' @cLangCode   = @cLangCode,     ' +
      ' @cStorerKey  = @cStorerKey,    ' +
      ' @cFacility   = @cFacility,     ' +
      ' @cReceiptKey = @cReceiptKey,   ' +
      ' @cPOKey      = @cPOKey,        ' +
      ' @cToLOC      = @cToLOC,        ' +
      ' @cToID       = @cToID,         ' +
      ' @cSKUCode    = @cSKUCode,      ' +
      ' @cSKUUOM     = @cSKUUOM,       ' +
      ' @nSKUQTY     = @nSKUQTY,       ' +
      ' @cUCC        = @cUCC,          ' +
      ' @cUCCSKU     = @cUCCSKU,       ' +
      ' @nUCCQTY     = @nUCCQTY,       ' +
      ' @cCreateUCC  = @cCreateUCC,    ' +
      ' @cLottable01 = @cLottable01,   ' +
      ' @cLottable02 = @cLottable02,   ' +
      ' @cLottable03 = @cLottable03,   ' +
      ' @dLottable04 = @dLottable04,   ' +
      ' @dLottable05 = @dLottable05,   ' +
      ' @cLottable06 = @cLottable06,   ' +
      ' @cLottable07 = @cLottable07,   ' +
      ' @cLottable08 = @cLottable08,   ' +
      ' @cLottable09 = @cLottable09,   ' +
      ' @cLottable10 = @cLottable10,   ' +
      ' @cLottable11 = @cLottable11,   ' +
      ' @cLottable12 = @cLottable12,   ' +
      ' @dLottable13 = @dLottable13,   ' +
      ' @dLottable14 = @dLottable14,   ' +
      ' @dLottable15 = @dLottable15,   ' +
      ' @nNOPOFlag   = @nNOPOFlag,     ' +
      ' @cConditionCode = @cConditionCode,  ' +
      ' @cSubreasonCode = @cSubreasonCode,  ' +
      CASE WHEN @cRcptConfirmSP LIKE '%_L05' THEN ' @cReceiptLineNumberOutput = @cRDLineNo OUTPUT,  '
           ELSE ' @cRDLineNo = @cRDLineNo OUTPUT,  '
      END +
      ' @nErrNo      = @nErrNo OUTPUT, ' +
      ' @cErrMsg     = @cErrMsg OUTPUT '

   SET @cSQLParam =
      '@nFunc          INT,            ' +
      '@nMobile        INT,            ' +
      '@cLangCode      NVARCHAR( 3),   ' +
      '@cStorerKey     NVARCHAR( 15),  ' +
      '@cFacility      NVARCHAR( 5),   ' +
      '@cReceiptKey    NVARCHAR( 10),  ' +
      '@cPOKey         NVARCHAR( 10),  ' +
      '@cToLOC         NVARCHAR( 10),  ' +
      '@cToID          NVARCHAR( 18),  ' +
      '@cSKUCode       NVARCHAR( 20),  ' +
      '@cSKUUOM        NVARCHAR( 10),  ' +
      '@nSKUQTY        INT,            ' +
      '@cUCC           NVARCHAR( 20),  ' +
      '@cUCCSKU        NVARCHAR( 20),  ' +
      '@nUCCQTY        INT,            ' +
      '@cCreateUCC     NVARCHAR( 1),   ' +
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
      '@nNOPOFlag      INT,            ' +
      '@cConditionCode NVARCHAR( 10),  ' +
      '@cSubreasonCode NVARCHAR( 10),  ' +
      '@cRDLineNo      NVARCHAR( 5)  OUTPUT, ' +
      '@nErrNo         INT           OUTPUT, ' +
      '@cErrMsg        NVARCHAR( 20) OUTPUT  '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cLOC, @cID,
      @cSKU, @cUOM, @nQTY, '', '', 0, '',
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, -- NULL, -- (ChewKP01) ,   -- (james01)
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
      @nNOPOFlag, @cConditionCode, '', @cRDLineNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
END
ELSE
BEGIN
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
      @cPOKey        = @cPOKey,
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
      @dLottable05   = @dLottable05, -- NULL, -- (ChewKP01)
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
      @nNOPOFlag     = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = '',
      @cReceiptLineNumberOutput = @cRDLineNo OUTPUT
END

IF @nErrNo <> 0
   GOTO Quit

DECLARE @cUserName NVARCHAR( 18)
SET @cUserName = SUSER_SNAME()

-- EventLog
EXEC RDT.rdt_STD_EventLog
   @cActionType   = '2', -- Receiving
   @cUserID       = @cUserName,
   @nMobileNo     = @nMobile,
   @nFunctionID   = @nFunc,
   @cFacility     = @cFacility,
   @cStorerKey    = @cStorerKey,
   @cReceiptKey   = @cReceiptKey,
   @cPOKey        = @cPOKey,
   @cLocation     = @cLOC,
   @cID           = @cID,
   @cSKU          = @cSKU,
   @cUOM          = @cUOM,
   @nQTY          = @nQTY,
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

-- Get IDQTY
SELECT @nIDQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
FROM dbo.ReceiptDetail WITH (NOLOCK)
WHERE ReceiptKey = @cReceiptKey
   AND ToLOC = @cLOC
   AND ToID = @cID

-- Get QTY statistic
SELECT
   @nBeforeReceivedQTY = ISNULL( SUM( BeforeReceivedQTY), 0),
   @nQTYExpected = ISNULL( SUM( QTYExpected), 0)
FROM dbo.ReceiptDetail WITH (NOLOCK)
WHERE Receiptkey = @cReceiptKey
   AND Storerkey = @cStorerKey
   AND SKU = @cSKU

Quit:


GO