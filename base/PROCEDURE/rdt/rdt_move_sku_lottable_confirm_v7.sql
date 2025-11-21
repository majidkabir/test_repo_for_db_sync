SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_Move_SKU_Lottable_Confirm_V7                          */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date         Author     Ver.  Purposes                                     */
/* 2023-04-17   Ung        1.0   WMS-22217 Created                            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_Move_SKU_Lottable_Confirm_V7] (
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

   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)
   DECLARE @cConfirmSP     NVARCHAR(20)

   SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''
   
   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @cLottableCode, ' + 
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' + 
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' + 
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' + 
            ' @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR(  5), ' +
            '@cFromLOC        NVARCHAR( 10), ' +
            '@cFromID         NVARCHAR( 18), ' +
            '@cSKU            NVARCHAR( 20), ' +
            '@cLottableCode   NVARCHAR( 30), ' + 
            '@cLottable01     NVARCHAR( 18), ' + 
            '@cLottable02     NVARCHAR( 18), ' + 
            '@cLottable03     NVARCHAR( 18), ' + 
            '@dLottable04     DATETIME,      ' + 
            '@dLottable05     DATETIME,      ' + 
            '@cLottable06     NVARCHAR( 30), ' + 
            '@cLottable07     NVARCHAR( 30), ' + 
            '@cLottable08     NVARCHAR( 30), ' + 
            '@cLottable09     NVARCHAR( 30), ' + 
            '@cLottable10     NVARCHAR( 30), ' + 
            '@cLottable11     NVARCHAR( 30), ' + 
            '@cLottable12     NVARCHAR( 30), ' + 
            '@dLottable13     DATETIME,      ' + 
            '@dLottable14     DATETIME,      ' + 
            '@dLottable15     DATETIME,      ' + 
            '@nQTY            INT,           ' +
            '@cToID           NVARCHAR( 18), ' +
            '@cToLOC          NVARCHAR( 10), ' +
            '@nErrNo          INT OUTPUT,    ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @cLottableCode, 
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END
   
   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
   DECLARE @cSKU_Move   NVARCHAR( 20)
   DECLARE @nQTY_Bal    INT
   DECLARE @nQTY_LLI    INT
   DECLARE @nQTY_Move   INT
   DECLARE @cLOT        NVARCHAR( 10)
   DECLARE @cWhere      NVARCHAR( MAX)
   DECLARE @curLLI      CURSOR
   DECLARE @cMoveAllSKUWithinSameLottable NVARCHAR( 1)
   
   SET @cMoveAllSKUWithinSameLottable = rdt.RDTGetConfig( @nFunc, 'MoveAllSKUWithinSameLottable', @cStorerKey)
   
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
           CASE WHEN @cMoveAllSKUWithinSameLottable = '1' THEN '' ELSE ' AND LLI.SKU = @cSKU ' END +
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
   SAVE TRAN rdt_Move_SKU_Lottable_Confirm_V7 -- For rollback or commit only our own transaction

   -- Loop LOTxLOTxID
   FETCH NEXT FROM @curLLI INTO @cSKU_Move, @cLOT, @nQTY_LLI
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Calc LLI.QTY to take
      IF @nQTY_LLI > @nQTY_Bal
         SET @nQTY = @nQTY_Bal -- LLI had enuf QTY, so charge all the balance into this LLI
      ELSE
         SET @nQTY = @nQTY_LLI -- LLI not enuf QTY, take all QTY avail of this LLI

      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, 
         @cSourceType = 'rdt_Move_SKU_Lottable_Confirm_V7',
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility,
         @cFromLOC    = @cFromLOC,
         @cToLOC      = @cToLOC,
         @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
         @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
         @cSKU        = @cSKU_Move,
         @nQTY        = @nQTY,
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
         @nQTY          = @nQTY,
         @cLot          = @cLOT

      SET @nQTY_Bal = @nQTY_Bal - @nQTY  -- Reduce balance
      IF @nQTY_Bal <= 0
         BREAK

      FETCH NEXT FROM @curLLI INTO @cSKU_Move, @cLOT, @nQTY_LLI
   END

   -- Still have balance, means no LLI changed
   IF @nQTY_Bal <> 0
   BEGIN
      SET @nErrNo = 199651
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv changed
      GOTO RollBackTran
   END
      
   COMMIT TRAN rdt_Move_SKU_Lottable_Confirm_V7 -- Only commit change made in here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Move_SKU_Lottable_Confirm_V7 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO