SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_UATransfer                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 26-03-2020  1.0  Ung      WMS-12631 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_UATransfer] (
	@nMobile       INT,
	@nFunc         INT,
	@cLangCode     NVARCHAR( 3),
	@nStep         INT,
	@nInputKey     INT, 
	@cStorerKey    NVARCHAR( 15),
	@cFacility     NVARCHAR( 5),
	@cFromLOC      NVARCHAR( 10),
	@cFromID       NVARCHAR( 18),
	@cFromLOT      NVARCHAR( 10), 
	@cSKU          NVARCHAR( 20), 
   @nQTY          INT, 
   @cChkQuality   NVARCHAR( 10), 
   @cITrnKey      NVARCHAR( 10)  OUTPUT, 
	@nErrNo        INT            OUTPUT,
	@cErrMsg       NVARCHAR( 20)  OUTPUT
) AS
BEGIN
	SET NOCOUNT ON
	SET QUOTED_IDENTIFIER OFF
	SET ANSI_NULLS OFF
	SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @b_Success INT
	DECLARE @n_err     INT
	DECLARE @c_errmsg  NVARCHAR( 250)
		
	DECLARE @nTranCount    INT
	DECLARE @cFromLottable NVARCHAR( 10)
	DECLARE @cToLottable   NVARCHAR( 10)
	DECLARE @cSQL          NVARCHAR( MAX) = ''
	DECLARE @cSQLParam     NVARCHAR( MAX)

	DECLARE @cLottable01 NVARCHAR( 18)
	DECLARE @cLottable02 NVARCHAR( 18)
	DECLARE @cLottable03 NVARCHAR( 18)
	DECLARE @dLottable04 DATETIME
	DECLARE @dLottable05 DATETIME
	DECLARE @cLottable06 NVARCHAR( 30)
	DECLARE @cLottable07 NVARCHAR( 30)
	DECLARE @cLottable08 NVARCHAR( 30)
	DECLARE @cLottable09 NVARCHAR( 30)
	DECLARE @cLottable10 NVARCHAR( 30)
	DECLARE @cLottable11 NVARCHAR( 30)
	DECLARE @cLottable12 NVARCHAR( 30)
	DECLARE @dLottable13 DATETIME
	DECLARE @dLottable14 DATETIME
	DECLARE @dLottable15 DATETIME

	DECLARE @cNewLottable01 NVARCHAR( 18)
	DECLARE @cNewLottable02 NVARCHAR( 18)
	DECLARE @cNewLottable03 NVARCHAR( 18)
	DECLARE @dNewLottable04 DATETIME
	DECLARE @dNewLottable05 DATETIME
	DECLARE @cNewLottable06 NVARCHAR( 30)
	DECLARE @cNewLottable07 NVARCHAR( 30)
	DECLARE @cNewLottable08 NVARCHAR( 30)
	DECLARE @cNewLottable09 NVARCHAR( 30)
	DECLARE @cNewLottable10 NVARCHAR( 30)
	DECLARE @cNewLottable11 NVARCHAR( 30)
	DECLARE @cNewLottable12 NVARCHAR( 30)
	DECLARE @dNewLottable13 DATETIME
	DECLARE @dNewLottable14 DATETIME
	DECLARE @dNewLottable15 DATETIME

	SET @nTranCount = @@TRANCOUNT

	-- Loop swap setting
	DECLARE @curSwap CURSOR
	SET @curSwap = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
		SELECT TRIM( Short), TRIM( Long)
		FROM CodeLKUP WITH (NOLOCK)
		WHERE ListName = 'UAPALOTTRF'
			AND StorerKey = @cStorerKey
		ORDER BY Code
	OPEN @curSwap
	FETCH NEXT FROM @curSwap INTO @cFromLottable, @cToLottable
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- Construct swap lottable var
		IF SUBSTRING( @cFromLottable, 9, 2) IN ( '03', '04', '13', '14', '15')
			SET @cSQL = @cSQL +
				' @dNew' + @cFromLottable + ' = @d' + @cToLottable   + ', ' + 
				' @dNew' + @cToLottable   + ' = @d' + @cFromLottable + ', '
		ELSE
			SET @cSQL = @cSQL +
				' @cNew' + @cFromLottable + ' = @c' + @cToLottable   + ', ' + 
				' @cNew' + @cToLottable   + ' = @c' + @cFromLottable + ', '

		FETCH NEXT FROM @curSwap INTO @cFromLottable, @cToLottable
	END
   
	-- Prepare SQL to swap lottables
	IF @cSQL <> ''
	BEGIN
		SET @cSQL = 'SELECT ' + LEFT( @cSQL, LEN( @cSQL) - 1) -- Remove last comma

		SET @cSQLParam =
				'  @cNewLottable01 NVARCHAR( 18) OUTPUT, @cLottable01 NVARCHAR( 18) ' +
				' ,@cNewLottable02 NVARCHAR( 18) OUTPUT, @cLottable02 NVARCHAR( 18) ' +
				' ,@cNewLottable03 NVARCHAR( 18) OUTPUT, @cLottable03 NVARCHAR( 18) ' +
				' ,@dNewLottable04 DATETIME      OUTPUT, @dLottable04 DATETIME      ' +
				' ,@dNewLottable05 DATETIME      OUTPUT, @dLottable05 DATETIME      ' +
				' ,@cNewLottable06 NVARCHAR( 30) OUTPUT, @cLottable06 NVARCHAR( 30) ' +
				' ,@cNewLottable07 NVARCHAR( 30) OUTPUT, @cLottable07 NVARCHAR( 30) ' +
				' ,@cNewLottable08 NVARCHAR( 30) OUTPUT, @cLottable08 NVARCHAR( 30) ' +
				' ,@cNewLottable09 NVARCHAR( 30) OUTPUT, @cLottable09 NVARCHAR( 30) ' +
				' ,@cNewLottable10 NVARCHAR( 30) OUTPUT, @cLottable10 NVARCHAR( 30) ' +
				' ,@cNewLottable11 NVARCHAR( 30) OUTPUT, @cLottable11 NVARCHAR( 30) ' +
				' ,@cNewLottable12 NVARCHAR( 30) OUTPUT, @cLottable12 NVARCHAR( 30) ' +
				' ,@dNewLottable13 DATETIME      OUTPUT, @dLottable13 DATETIME      ' +
				' ,@dNewLottable14 DATETIME      OUTPUT, @dLottable14 DATETIME      ' +
				' ,@dNewLottable15 DATETIME      OUTPUT, @dLottable15 DATETIME      '

   	-- Get lottables
   	SELECT
   		@cNewLottable01 = Lottable01, @cLottable01 = Lottable01, 
   		@cNewLottable02 = Lottable02, @cLottable02 = Lottable02, 
   		@cNewLottable03 = Lottable03, @cLottable03 = Lottable03, 
   		@dNewLottable04 = Lottable04, @dLottable04 = Lottable04, 
   		@dNewLottable05 = Lottable05, @dLottable05 = Lottable05, 
   		@cNewLottable06 = Lottable06, @cLottable06 = Lottable06, 
   		@cNewLottable07 = Lottable07, @cLottable07 = Lottable07, 
   		@cNewLottable08 = Lottable08, @cLottable08 = Lottable08, 
   		@cNewLottable09 = Lottable09, @cLottable09 = Lottable09, 
   		@cNewLottable10 = Lottable10, @cLottable10 = Lottable10, 
   		@cNewLottable11 = Lottable11, @cLottable11 = Lottable11, 
   		@cNewLottable12 = Lottable12, @cLottable12 = Lottable12, 
   		@dNewLottable13 = Lottable13, @dLottable13 = Lottable13, 
   		@dNewLottable14 = Lottable14, @dLottable14 = Lottable14, 
   		@dNewLottable15 = Lottable15, @dLottable15 = Lottable15
      FROM LOTAttribute WITH (NOLOCK)
      WHERE LOT = @cFromLOT

      -- Check quality
      IF @cChkQuality <> ''
      BEGIN
         -- Check quality of stock is in allowed list. Lottable10 prefix (1 CHAR, indicate quality)
         IF CHARINDEX( LEFT( @cLottable10, 1), @cChkQuality) = 0 
         BEGIN
            SET @nErrNo = 150201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WRONG LOT TYPE
            GOTO Quit
         END
      END

   	-- Swap lottables
		EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
			@cNewLottable01 OUTPUT, @cLottable01,
			@cNewLottable02 OUTPUT, @cLottable02,
			@cNewLottable03 OUTPUT, @cLottable03,
			@dNewLottable04 OUTPUT, @dLottable04,
			@dNewLottable05 OUTPUT, @dLottable05,
			@cNewLottable06 OUTPUT, @cLottable06,
			@cNewLottable07 OUTPUT, @cLottable07,
			@cNewLottable08 OUTPUT, @cLottable08,
			@cNewLottable09 OUTPUT, @cLottable09,
			@cNewLottable10 OUTPUT, @cLottable10,
			@cNewLottable11 OUTPUT, @cLottable11,
			@cNewLottable12 OUTPUT, @cLottable12,
			@dNewLottable13 OUTPUT, @dLottable13,
			@dNewLottable14 OUTPUT, @dLottable14,
			@dNewLottable15 OUTPUT, @dLottable15

   	-- Handling transaction
   	BEGIN TRAN  -- Begin our own transaction
   	SAVE TRAN rdt_UATransfer -- For rollback or commit only our own transaction

   	-- Withdraw
   	BEGIN
   		EXECUTE nspItrnAddWithdrawal
   			@n_ItrnSysId  = NULL,
   			@c_StorerKey  = @cStorerKey,
   			@c_Sku        = @cSKU,
   			@c_Lot        = @cFromLOT,
   			@c_ToLoc      = @cFromLOC,
   			@c_ToID       = @cFromID,
   			@c_Status     = '',
   			@c_Lottable01 = @cLottable01,
   			@c_Lottable02 = @cLottable02,
   			@c_Lottable03 = @cLottable03,
   			@d_Lottable04 = @dLottable04,
   			@d_Lottable05 = @dLottable05,
   			@c_Lottable06 = @cLottable06,
   			@c_Lottable07 = @cLottable07,
   			@c_Lottable08 = @cLottable08,
   			@c_Lottable09 = @cLottable09,
   			@c_Lottable10 = @cLottable10,
   			@c_Lottable11 = @cLottable11,
   			@c_Lottable12 = @cLottable12,
   			@d_Lottable13 = @dLottable13,
   			@d_Lottable14 = @dLottable14,
   			@d_Lottable15 = @dLottable15,
   			@n_casecnt    = 0,
   			@n_innerpack  = 0,
   			@n_Qty        = @nQTY,
   			@n_pallet     = 0,
   			@f_cube       = 0,
   			@f_grosswgt   = 0,
   			@f_netwgt     = 0,
   			@f_otherunit1 = 0,
   			@f_otherunit2 = 0,
   			@c_SourceKey  = '',
   			@c_SourceType = 'rdt_UATransfer',
   			@c_PackKey    = '',
   			@c_UOM        = '',
   			@b_UOMCalc    = 0,
   			@d_EffectiveDate = NULL,
   			@c_ItrnKey    = '',
   			@b_Success    = @b_Success OUTPUT,
   			@n_err        = @n_err     OUTPUT,
   			@c_errmsg     = @c_errmsg  OUTPUT
   		IF @b_success <> 1
   		BEGIN
   			SET @nErrNo = 150252
   			SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --WITHDRAW FAIL
   			GOTO RollBackTran
   		END
      END

      -- Deposit
      BEGIN
         SET @cITrnKey = ''
   		EXECUTE nspItrnAddDeposit
   			@n_ItrnSysId  = NULL,
   			@c_StorerKey  = @cStorerKey,
   			@c_Sku        = @cSKU,
   			@c_Lot        = '',
   			@c_ToLoc      = @cFromLOC,
   			@c_ToID       = @cFromID,
   			@c_Status     = '',
   			@c_Lottable01 = @cNewLottable01,
   			@c_Lottable02 = @cNewLottable02,
   			@c_Lottable03 = @cNewLottable03,
   			@d_Lottable04 = @dNewLottable04,
   			@d_Lottable05 = @dNewLottable05,
   			@c_Lottable06 = @cNewLottable06,
   			@c_Lottable07 = @cNewLottable07,
   			@c_Lottable08 = @cNewLottable08,
   			@c_Lottable09 = @cNewLottable09,
   			@c_Lottable10 = @cNewLottable10,
   			@c_Lottable11 = @cNewLottable11,
   			@c_Lottable12 = @cNewLottable12,
   			@d_Lottable13 = @dNewLottable13,
   			@d_Lottable14 = @dNewLottable14,
   			@d_Lottable15 = @dNewLottable15,
   			@n_casecnt    = 0,
   			@n_innerpack  = 0,
   			@n_Qty        = @nQTY,
   			@n_pallet     = 0,
   			@f_cube       = 0,
   			@f_grosswgt   = 0,
   			@f_netwgt     = 0,
   			@f_otherunit1 = 0,
   			@f_otherunit2 = 0,
   			@c_SourceKey  = '',
   			@c_SourceType = 'rdt_UATransfer',
   			@c_PackKey    = '',
   			@c_UOM        = '',
   			@b_UOMCalc    = 0,
   			@d_EffectiveDate = NULL,
   			@c_ItrnKey    = @cITrnKey  OUTPUT,
   			@b_Success    = @b_Success OUTPUT,
   			@n_err        = @n_err     OUTPUT,
   			@c_errmsg     = @c_errmsg  OUTPUT

   		IF @b_success <> 1
   		BEGIN
   			SET @nErrNo = 150253
   			SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --DEPOSIT FAIL
   			GOTO RollBackTran
   		END
   	END

   	COMMIT TRAN rdt_UATransfer -- Only commit change made here
   	GOTO Quit
   END
   GOTO Quit

RollBackTran:
	ROLLBACK TRAN rdt_UATransfer -- Only rollback change made here
Quit:
	WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
		COMMIT TRAN
END

GO