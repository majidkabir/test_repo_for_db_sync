SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_629Confirm01                                          */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date         Author     Ver.  Purposes                                     */
/* 2023-04-17   Ung        1.0   WMS-22217 Created                            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_629Confirm01] (
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cStorerKey      NVARCHAR( 15)
   ,@cFacility       NVARCHAR(  5)
   ,@cFromLOC        NVARCHAR( 10)
   ,@cFromID         NVARCHAR( 18)
   ,@cSKU            NVARCHAR( 20)
   ,@cLottableCode   NVARCHAR( 30)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME
   ,@dLottable05     DATETIME
   ,@cLottable06     NVARCHAR( 30)
   ,@cLottable07     NVARCHAR( 30)
   ,@cLottable08     NVARCHAR( 30)
   ,@cLottable09     NVARCHAR( 30)
   ,@cLottable10     NVARCHAR( 30)
   ,@cLottable11     NVARCHAR( 30)
   ,@cLottable12     NVARCHAR( 30)
   ,@dLottable13     DATETIME
   ,@dLottable14     DATETIME
   ,@dLottable15     DATETIME
   ,@nQTY            INT
   ,@cToID           NVARCHAR( 18)
   ,@cToLOC          NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success    INT
   DECLARE @n_Err        INT
   DECLARE @c_ErrMsg     NVARCHAR( 20)
   DECLARE @cSQL         NVARCHAR(MAX)
   DECLARE @cSQLParam    NVARCHAR(MAX)

   DECLARE @c_Lottable01 NVARCHAR( 18)
   DECLARE @c_Lottable02 NVARCHAR( 18)
   DECLARE @c_Lottable03 NVARCHAR( 18)
   DECLARE @d_Lottable04 DATETIME
   DECLARE @d_Lottable05 DATETIME
   DECLARE @c_Lottable06 NVARCHAR( 30)
   DECLARE @c_Lottable07 NVARCHAR( 30)
   DECLARE @c_Lottable08 NVARCHAR( 30)
   DECLARE @c_Lottable09 NVARCHAR( 30)
   DECLARE @c_Lottable10 NVARCHAR( 30)
   DECLARE @c_Lottable11 NVARCHAR( 30)
   DECLARE @c_Lottable12 NVARCHAR( 30)
   DECLARE @d_Lottable13 DATETIME
   DECLARE @d_Lottable14 DATETIME
   DECLARE @d_Lottable15 DATETIME

   DECLARE @cSKU_Move   NVARCHAR( 20)
   DECLARE @nQTY_Bal    INT
   DECLARE @nQTY_LLI    INT
   DECLARE @nQTY_Move   INT
   DECLARE @cLOT        NVARCHAR( 10)
   DECLARE @cNewLOT     NVARCHAR( 10) 
   DECLARE @cWhere      NVARCHAR( MAX)
   DECLARE @curLLI      CURSOR
   
   -- Get lottable filter
   EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 5, 'LA',
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
      @cWhere   OUTPUT,
      @nErrNo   OUTPUT,
      @cErrMsg  OUTPUT

   -- Prepare cursor
   SET @cSQL =
      ' SELECT ' +
      '    LLI.SKU, ' +
      '    LLI.LOT, ' +
      '    LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) ' +
      ' FROM dbo.LOTxLOCxID LLI(NOLOCK) ' +
      '    JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT) ' +
      ' WHERE LLI.LOC = @cFromLOC ' + 
         ' AND LLI.ID = @cFromID ' +
         ' AND LLI.StorerKey = @cStorerKey ' +
         ' AND LLI.SKU = @cSKU ' +
         ' AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0 ' +
           CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END

   -- Open cursor
   SET @cSQL =
      ' SET @curLLI = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' +
         @cSQL +
      ' OPEN @curLLI '

   SET @cSQLParam =
      ' @curLLI      CURSOR OUTPUT, ' +
      ' @cStorerKey  NVARCHAR( 15), ' +
      ' @cFromLOC    NVARCHAR( 10), ' +
      ' @cFromID     NVARCHAR( 18), ' +
      ' @cSKU        NVARCHAR( 20), ' +
      ' @cLottable01 NVARCHAR( 18), ' +
      ' @cLottable02 NVARCHAR( 18), ' +
      ' @cLottable03 NVARCHAR( 18), ' +
      ' @dLottable04 DATETIME,      ' +
      ' @dLottable05 DATETIME,      ' +
      ' @cLottable06 NVARCHAR( 30), ' +
      ' @cLottable07 NVARCHAR( 30), ' +
      ' @cLottable08 NVARCHAR( 30), ' +
      ' @cLottable09 NVARCHAR( 30), ' +
      ' @cLottable10 NVARCHAR( 30), ' +
      ' @cLottable11 NVARCHAR( 30), ' +
      ' @cLottable12 NVARCHAR( 30), ' +
      ' @dLottable13 DATETIME,      ' +
      ' @dLottable14 DATETIME,      ' +
      ' @dLottable15 DATETIME       '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @curLLI OUTPUT, @cStorerKey, @cFromLOC, @cFromID, @cSKU,
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15

   SET @nQTY_Bal = @nQTY

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_629Confirm01 -- For rollback or commit only our own transaction

   -- Loop LOTxLOTxID
   FETCH NEXT FROM @curLLI INTO @cSKU_Move, @cLOT, @nQTY_LLI
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Calc LLI.QTY to take
      IF @nQTY_LLI > @nQTY_Bal
         SET @nQTY_Move = @nQTY_Bal -- LLI had enuf QTY, so charge all the balance into this LLI
      ELSE
         SET @nQTY_Move = @nQTY_LLI -- LLI not enuf QTY, take all QTY avail of this LLI

      -- Get LOT info
      SELECT
         @c_Lottable01 = Lottable01,
         @c_Lottable02 = Lottable02,
         @c_Lottable03 = Lottable03, 
         @d_Lottable04 = Lottable04,
         @d_Lottable05 = Lottable05,
         @c_Lottable06 = Lottable06,
         @c_Lottable07 = Lottable07,
         @c_Lottable08 = Lottable08,
         @c_Lottable09 = Lottable09,
         @c_Lottable10 = Lottable10,
         @c_Lottable11 = Lottable11,
         @c_Lottable12 = Lottable12,
         @d_Lottable13 = Lottable13,
         @d_Lottable14 = Lottable14,
         @d_Lottable15 = Lottable15
      FROM dbo.LOTAttribute WITH (NOLOCK)
      WHERE LOT = @cLOT

      -- Create new LOT if not exist
      BEGIN          
         -- Look up existing LOT
         SET @cNewLOT = '' 
         SET @b_Success = 0
         EXECUTE nsp_lotlookup
              @cStorerKey
            , @cSKU
            , @c_Lottable01
            , @c_Lottable02
            , @cToID -- @c_Lottable03
            , @d_Lottable04
            , @d_Lottable05
            , @c_Lottable06
            , @c_Lottable07
            , @c_Lottable08
            , @c_Lottable09
            , @c_Lottable10
            , @c_Lottable11
            , @c_Lottable12
            , @d_Lottable13
            , @d_Lottable14
            , @d_Lottable15
            , @cNewLOT     OUTPUT
            , @b_Success   OUTPUT
            , @n_err       OUTPUT
            , @c_ErrMsg    OUTPUT
         IF @b_Success = 1
         BEGIN
            IF ISNULL( @cNewLOT, '') = ''
            BEGIN
               -- Create new LOT
               SET @b_Success = 0
               EXECUTE nsp_lotgen
                    @cStorerKey
                  , @cSKU
                  , @c_Lottable01
                  , @c_Lottable02
                  , @cToID -- @c_Lottable03
                  , @d_Lottable04
                  , @d_Lottable05
                  , @c_Lottable06
                  , @c_Lottable07
                  , @c_Lottable08
                  , @c_Lottable09
                  , @c_Lottable10
                  , @c_Lottable11
                  , @c_Lottable12
                  , @d_Lottable13
                  , @d_Lottable14
                  , @d_Lottable15
                  , @cNewLOT     OUTPUT
                  , @b_Success   OUTPUT
                  , @n_err       OUTPUT
                  , @c_ErrMsg    OUTPUT
               IF @b_Success <> 1
               BEGIN
                  SET @nErrNo = 199701
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CreateLOT fail
                  GOTO Quit
               END
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 199702
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LookupLOT fail
            GOTO Quit
         END
      END

      -- Change stock to new LOT
      IF @cLOT <> @cNewLOT
      BEGIN
         -- Withdraw
         EXECUTE nspItrnAddWithdrawal
            @n_ItrnSysId  = NULL,
            @c_StorerKey  = @cStorerKey,
            @c_Sku        = @cSKU,
            @c_LOT        = @cLOT,
            @c_ToLoc      = @cFromLOC,
            @c_ToID       = @cFromID,
            @c_Status     = '',
            @c_lottable01 = @c_Lottable01,
            @c_lottable02 = @c_Lottable02,
            @c_lottable03 = @c_Lottable03,
            @d_lottable04 = @d_Lottable04,
            @d_lottable05 = @d_Lottable05,
            @c_lottable06 = @c_Lottable06,
            @c_lottable07 = @c_Lottable07,
            @c_lottable08 = @c_Lottable08,
            @c_lottable09 = @c_Lottable09,
            @c_lottable10 = @c_Lottable10,
            @c_lottable11 = @c_Lottable11,
            @c_lottable12 = @c_Lottable12,
            @d_lottable13 = @d_Lottable13,
            @d_lottable14 = @d_Lottable14,
            @d_lottable15 = @d_Lottable15,
            @n_casecnt    = 0,
            @n_innerpack  = 0,
            @n_Qty        = @nQTY_Move,
            @n_pallet     = 0,
            @f_cube       = 0,
            @f_grosswgt   = 0,
            @f_netwgt     = 0,
            @f_otherunit1 = 0,
            @f_otherunit2 = 0,
            @c_SourceKey  = '',
            @c_SourceType = 'rdt_629Confirm01',
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
            SET @nErrNo = 199706
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WITHDRAW FAIL
            GOTO RollbackTran
         END

         -- Deposit
         EXECUTE nspItrnAddDeposit
            @n_ItrnSysId  = NULL,
            @c_StorerKey  = @cStorerKey,
            @c_Sku        = @cSKU,
            @c_LOT        = @cNewLOT,
            @c_ToLoc      = @cFromLOC,
            @c_ToID       = @cFromID,
            @c_Status     = '',
            @c_lottable01 = @c_Lottable01,
            @c_lottable02 = @c_Lottable02,
            @c_lottable03 = @cToID, -- @c_Lottable03, 
            @d_lottable04 = @d_Lottable04,
            @d_lottable05 = @d_Lottable05,
            @c_lottable06 = @c_Lottable06,
            @c_lottable07 = @c_Lottable07,
            @c_lottable08 = @c_Lottable08,
            @c_lottable09 = @c_Lottable09,
            @c_lottable10 = @c_Lottable10,
            @c_lottable11 = @c_Lottable11,
            @c_lottable12 = @c_Lottable12,
            @d_lottable13 = @d_Lottable13,
            @d_lottable14 = @d_Lottable14,
            @d_lottable15 = @d_Lottable15,
            @n_casecnt    = 0,
            @n_innerpack  = 0,
            @n_Qty        = @nQTY_Move,
            @n_pallet     = 0,
            @f_cube       = 0,
            @f_grosswgt   = 0,
            @f_netwgt     = 0,
            @f_otherunit1 = 0,
            @f_otherunit2 = 0,
            @c_SourceKey  = '',
            @c_SourceType = 'rdt_629Confirm01',
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
            SET @nErrNo = 199707
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEPOSIT FAIL
            GOTO RollbackTran
         END
      
         SET @cLOT = @cNewLOT
      END

      -- Move
      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, 
         @cSourceType = 'rdt_629Confirm01',
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility,
         @cFromLOC    = @cFromLOC,
         @cToLOC      = @cToLOC,
         @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
         @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
         @cSKU        = @cSKU_Move,
         @nQTY        = @nQTY_Move,
         @cFromLOT    = @cLOT
      IF @nErrNo <> 0
         GOTO RollBackTran

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cLocation     = @cFromLOC,
         @cToLocation   = @cToLOC,
         @cID           = @cFromID,
         @cToID         = @cToID,
         @cSKU          = @cSKU_Move,
         @nQTY          = @nQTY_Move,
         @cLot          = @cLOT

      SET @nQTY_Bal = @nQTY_Bal - @nQTY_Move  -- Reduce balance
      IF @nQTY_Bal <= 0
         BREAK

      FETCH NEXT FROM @curLLI INTO @cSKU_Move, @cLOT, @nQTY_LLI
   END

   -- Still have balance, means LLI changed
   IF @nQTY_Bal <> 0
   BEGIN
      SET @nErrNo = 125569
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv changed
      GOTO RollBackTran
   END
      
   COMMIT TRAN rdt_629Confirm01 -- Only commit change made in here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_629Confirm01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO