SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_638RcvCfm04                                     */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Custom map lottable to userdefine                           */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2020-07-21  1.0  Ung         WMS-13962 Created                       */
/* 2020-11-24  1.1  Ung         WMS-14691 Add serial no params          */
/* 2022-09-23  1.2  YeeKung     WMS-20820 Extended refno length (yeekung01)*/
/* 2023-07-20  1.3  YeeKung     WMS-23153 Add Eventlog (yeekung02)      */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_638RcvCfm04]
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @dArriveDate    DATETIME,
   @cReceiptKey    NVARCHAR( 10),
   @cRefNo         NVARCHAR( 60), --(yeekung01)
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
   @cData1         NVARCHAR( 60),
   @cData2         NVARCHAR( 60),
   @cData3         NVARCHAR( 60),
   @cData4         NVARCHAR( 60),
   @cData5         NVARCHAR( 60),
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10),
   @cSerialNo      NVARCHAR( 60),
   @nSerialQTY     INT,
   @tConfirmVar    VARIABLETABLE READONLY,
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @cSQL           NVARCHAR( MAX) = ''
   DECLARE @cSQLUpdate     NVARCHAR( MAX) = ''
	DECLARE @cSQLParam      NVARCHAR( MAX)

	DECLARE @cLottableCol   NVARCHAR( 15)
	DECLARE @cUserDefineCol NVARCHAR( 15)
   DECLARE @cUserDefine01  NVARCHAR( 30)
   DECLARE @cUserDefine02  NVARCHAR( 30)
   DECLARE @cUserDefine03  NVARCHAR( 30)
   DECLARE @cUserDefine04  NVARCHAR( 30)
   DECLARE @cUserDefine05  NVARCHAR( 30)
   DECLARE @dUserDefine06  DATETIME
   DECLARE @dUserDefine07  DATETIME
   DECLARE @cUserDefine08  NVARCHAR( 30)
   DECLARE @cUserDefine09  NVARCHAR( 30)
   DECLARE @cUserDefine10  NVARCHAR( 30)

   -- Lookup Lottable, UserDefine column mapping
   DECLARE @curMap CURSOR
   SET @curMap = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Code, Long
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'LOTUDFMAP'
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility
      ORDER BY Short
   OPEN @curMap
   FETCH NEXT FROM @curMap INTO @cLottableCol, @cUserDefineCol
   WHILE @@FETCH_STATUS = 0
   BEGIN
		-- Construct copy lottable to userdefine
      -- Construct update ReceiptDetail
		IF SUBSTRING( @cLottableCol, 9, 2) IN ( '03', '04', '13', '14', '15') AND
		   SUBSTRING( @cUserDefineCol, 11, 2) IN ( '06', '07')
	   BEGIN
			SET @cSQL = @cSQL +
				' @d' + @cUserDefineCol + ' = @d' + @cLottableCol + ', ' +
				' @d' + @cLottableCol + ' = NULL, '
         SET @cSQLUpdate = @cSQLUpdate +
				' ' + @cUserDefineCol + ' = @d' + @cUserDefineCol + ', '
		END
		ELSE
		BEGIN
			SET @cSQL = @cSQL +
				' @c' + @cUserDefineCol + ' = @c' + @cLottableCol + ', ' +
				' @c' + @cLottableCol + ' = '''', '
         SET @cSQLUpdate = @cSQLUpdate +
				' ' + @cUserDefineCol + ' = @c' + @cUserDefineCol + ', '
      END

      FETCH NEXT FROM @curMap INTO @cLottableCol, @cUserDefineCol
   END

	-- Prepare SQL to copy lottable to userdefine
	IF @cSQL <> ''
	BEGIN
		SET @cSQL = 'SELECT ' + LEFT( @cSQL, LEN( @cSQL) - 1) -- Remove last comma

		SET @cSQLParam =
				'  @cLottable01 NVARCHAR( 18) OUTPUT, @cUserDefine01 NVARCHAR( 30) OUTPUT, ' +
				'  @cLottable02 NVARCHAR( 18) OUTPUT, @cUserDefine02 NVARCHAR( 30) OUTPUT, ' +
				'  @cLottable03 NVARCHAR( 18) OUTPUT, @cUserDefine03 NVARCHAR( 30) OUTPUT, ' +
				'  @dLottable04 DATETIME      OUTPUT, @cUserDefine04 NVARCHAR( 30) OUTPUT, ' +
				'  @dLottable05 DATETIME      OUTPUT, @cUserDefine05 NVARCHAR( 30) OUTPUT, ' +
				'  @cLottable06 NVARCHAR( 30) OUTPUT, @dUserDefine06 DATETIME      OUTPUT, ' +
				'  @cLottable07 NVARCHAR( 30) OUTPUT, @dUserDefine07 DATETIME      OUTPUT, ' +
				'  @cLottable08 NVARCHAR( 30) OUTPUT, @cUserDefine08 NVARCHAR( 30) OUTPUT, ' +
				'  @cLottable09 NVARCHAR( 30) OUTPUT, @cUserDefine09 NVARCHAR( 30) OUTPUT, ' +
				'  @cLottable10 NVARCHAR( 30) OUTPUT, @cUserDefine10 NVARCHAR( 30) OUTPUT, ' +
				'  @cLottable11 NVARCHAR( 30) OUTPUT, ' +
				'  @cLottable12 NVARCHAR( 30) OUTPUT, ' +
				'  @dLottable13 DATETIME      OUTPUT, ' +
				'  @dLottable14 DATETIME      OUTPUT, ' +
				'  @dLottable15 DATETIME      OUTPUT  '

		EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
			@cLottable01 OUTPUT, @cUserDefine01 OUTPUT,
			@cLottable02 OUTPUT, @cUserDefine02 OUTPUT,
			@cLottable03 OUTPUT, @cUserDefine03 OUTPUT,
			@dLottable04 OUTPUT, @cUserDefine04 OUTPUT,
			@dLottable05 OUTPUT, @cUserDefine05 OUTPUT,
			@cLottable06 OUTPUT, @dUserDefine06 OUTPUT,
			@cLottable07 OUTPUT, @dUserDefine07 OUTPUT,
			@cLottable08 OUTPUT, @cUserDefine08 OUTPUT,
			@cLottable09 OUTPUT, @cUserDefine09 OUTPUT,
			@cLottable10 OUTPUT, @cUserDefine10 OUTPUT,
			@cLottable11 OUTPUT,
			@cLottable12 OUTPUT,
			@dLottable13 OUTPUT,
			@dLottable14 OUTPUT,
			@dLottable15 OUTPUT
   END

	-- Handling transaction
	DECLARE @nTranCount INT
	SET @nTranCount = @@TRANCOUNT
	BEGIN TRAN  -- Begin our own transaction
	SAVE TRAN rdt_638RcvCfm04 -- For rollback or commit only our own transaction

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
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = @cSubreasonCode,
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

   IF @cSQLUpdate <> ''
	BEGIN
	   SET @cSQLUpdate = LEFT( @cSQLUpdate, LEN( @cSQLUpdate) - 1) -- Remove last comma
		SET @cSQLUpdate =
		   ' UPDATE ReceiptDetail SET ' +
		      @cSQLUpdate +
		   ' WHERE ReceiptKey = @cReceiptKey ' +
		      ' AND ReceiptLineNumber = @cReceiptLineNumber ' +
		   ' SET @nErrNo = @@ERROR '

		SET @cSQLParam =
			' @cReceiptKey   NVARCHAR( 30), ' +
			' @cReceiptLineNumber   NVARCHAR( 5), ' +
			' @cUserDefine01 NVARCHAR( 30), ' +
			' @cUserDefine02 NVARCHAR( 30), ' +
			' @cUserDefine03 NVARCHAR( 30), ' +
			' @cUserDefine04 NVARCHAR( 30), ' +
			' @cUserDefine05 NVARCHAR( 30), ' +
			' @dUserDefine06 DATETIME     , ' +
			' @dUserDefine07 DATETIME     , ' +
			' @cUserDefine08 NVARCHAR( 30), ' +
			' @cUserDefine09 NVARCHAR( 30), ' +
			' @cUserDefine10 NVARCHAR( 30), ' +
			' @nErrNo        INT OUTPUT     '

		EXEC sp_ExecuteSQL @cSQLUpdate, @cSQLParam,
			@cReceiptKey,
         @cReceiptLineNumber,
			@cUserDefine01,
			@cUserDefine02,
			@cUserDefine03,
			@cUserDefine04,
			@cUserDefine05,
			@dUserDefine06,
			@dUserDefine07,
			@cUserDefine08,
			@cUserDefine09,
			@cUserDefine10,
			@nErrNo OUTPUT
		IF @nErrNo <> 0
		BEGIN
		   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
		   GOTO RollBackTran
		END
   END

   -- EventLog (yeekung02)
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '2', -- Receiving
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey,
      @cReceiptKey   = @cReceiptKey,
      @cRefNo1       = @cRefNo,
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
      @cSerialNo     = @cSerialNo

   COMMIT TRAN rdt_638RcvCfm04
   GOTO Quit

RollBackTran:
	ROLLBACK TRAN rdt_638RcvCfm04 -- Only rollback change made here
Quit:
	WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
		COMMIT TRAN
END

GO