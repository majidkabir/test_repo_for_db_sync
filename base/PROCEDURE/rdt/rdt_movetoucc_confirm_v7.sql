SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_MoveToUCC_Confirm_V7                            */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Move to ucc confirm                                         */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-02-17 1.0  James      WMS-12070. Created                        */
/* 2021-07-27 2.0  SYChua     Bug Fix: Include condition when @cWhere is*/
/*                            NULL  (SY01)                              */
/************************************************************************/

CREATE PROC [RDT].[rdt_MoveToUCC_Confirm_V7] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR(3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cToLOC          NVARCHAR( 10),
   @cToID           NVARCHAR( 18),
   @cFromLOC        NVARCHAR( 10),
   @cFromID         NVARCHAR( 18),
   @cUCC            NVARCHAR( 20),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cLottableCode   NVARCHAR( 30),
   @cLottable01     NVARCHAR( 18),
   @cLottable02     NVARCHAR( 18),
   @cLottable03     NVARCHAR( 18),
   @dLottable04     DATETIME,
   @dLottable05     DATETIME,
   @cLottable06     NVARCHAR( 30),
   @cLottable07     NVARCHAR( 30),
   @cLottable08     NVARCHAR( 30),
   @cLottable09     NVARCHAR( 30),
   @cLottable10     NVARCHAR( 30),
   @cLottable11     NVARCHAR( 30),
   @cLottable12     NVARCHAR( 30),
   @dLottable13     DATETIME,
   @dLottable14     DATETIME,
   @dLottable15     DATETIME,
   @tConfirm        VARIABLETABLE READONLY,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cMoveToUCCConfirmSP  NVARCHAR( 20) = ''
   DECLARE @cSelect     NVARCHAR( MAX)
   DECLARE @cFrom       NVARCHAR( MAX)
   DECLARE @cWhere      NVARCHAR( MAX)
   DECLARE @cWhere1     NVARCHAR( MAX)
   DECLARE @cWhere2     NVARCHAR( MAX)
   DECLARE @cGroupBy    NVARCHAR( MAX)
   DECLARE @cOrderBy    NVARCHAR( MAX)

   DECLARE @b_success   INT
   DECLARE @n_err       INT
   DECLARE @c_errmsg    NVARCHAR( 20)
   DECLARE @nMultiStorer INT = 0
   DECLARE @cLot        NVARCHAR( 10)
   DECLARE @nLOTQty     INT
   DECLARE @nReLOTQty   INT
   DECLARE @c_LOT       NVARCHAR( 10)
   DECLARE @c_LOC       NVARCHAR( 10)
   DECLARE @c_ID        NVARCHAR( 18)
   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @cMUOM_Desc  NCHAR(5)    -- Master UOM desc
   DECLARE @cLoseUCC    NVARCHAR(1)
   DECLARE @cUCCLot     NVARCHAR( 10)
   DECLARE @cPrevLot    NVARCHAR( 10)
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
   DECLARE @ndebug       INT = 0
   DECLARE @nTtl_ReLOTQty     INT
   DECLARE @cStorerConfig_UCC NVARCHAR( 1)
   DECLARE @cStorerConfig_ByPassCantMixSKUnUCC  NVARCHAR( 1)
   DECLARE @cMoveQTYAlloc     NVARCHAR(1)
   DECLARE @cToLocType        NVARCHAR(10)
   DECLARE @nFromLOC_SKU      INT
   DECLARE @nFromLOC_UCC      INT
   DECLARE @nToLOC_SKU        INT
   DECLARE @nToLOC_UCC        INT

   SET @nErrNo = 0
   SET @cErrMsg = ''

   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
   BEGIN
      SELECT TOP 1 @cStorerKey = SKU.StorerKey
      FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.StorerGroup SG WITH (NOLOCK) ON (SKU.StorerKey = SG.StorerKey)
      JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (SKU.SKU = LLI.SKU AND SKU.StorerKey = LLI.StorerKey)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE SKU.SKU = @cSKU
      AND   SG.StorerGroup = @cStorerkey
      AND   LLI.LOC = @cFromLOC
      AND   (( ISNULL(@cFromID, '') = '') OR ( LLI.ID = @cFromID))
      AND   LOC.Facility = @cFacility

      IF @@ROWCOUNT <> 0
         SET @nMultiStorer = 1
   END

   SET @cMoveToUCCConfirmSP = rdt.RDTGetConfig( @nFunc, 'MoveToUCCConfirmSP', @cStorerKey)

   IF @cMoveToUCCConfirmSP <> '' AND
      EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cMoveToUCCConfirmSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cMoveToUCCConfirmSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, ' +
         ' @cToLoc, @cToID, @cFromLoc, @cFromID, @cUCC, @cSKU,  @nQTY, @cLottableCode, ' +
         ' @cLottable01,  @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
         ' @cLottable06,  @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
         ' @cLottable11,  @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
         ' @tConfirm,  @nErrNo   OUTPUT, @cErrMsg  OUTPUT '

      SET @cSQLParam =
         ' @nMobile         INT, ' +
         ' @nFunc           INT, ' +
         ' @cLangCode       NVARCHAR( 3), ' +
         ' @nStep           INT, ' +
         ' @nInputKey       INT, ' +
         ' @cStorerKey      NVARCHAR( 15), ' +
         ' @cFacility       NVARCHAR( 5),  ' +
         ' @cToLOC          NVARCHAR( 10), ' +
         ' @cToID           NVARCHAR( 18), ' +
         ' @cFromLOC        NVARCHAR( 10), ' +
         ' @cFromID         NVARCHAR( 18), ' +
         ' @cUCC            NVARCHAR( 20), ' +
         ' @cSKU            NVARCHAR( 20), ' +
         ' @nQTY            INT,           ' +
         ' @cLottableCode   NVARCHAR( 30), ' +
         ' @cLottable01     NVARCHAR( 18), ' +
         ' @cLottable02     NVARCHAR( 18), ' +
         ' @cLottable03     NVARCHAR( 18), ' +
         ' @dLottable04     DATETIME,      ' +
         ' @dLottable05     DATETIME,      ' +
         ' @cLottable06     NVARCHAR( 30), ' +
         ' @cLottable07     NVARCHAR( 30), ' +
         ' @cLottable08     NVARCHAR( 30), ' +
         ' @cLottable09     NVARCHAR( 30), ' +
         ' @cLottable10     NVARCHAR( 30), ' +
         ' @cLottable11     NVARCHAR( 30), ' +
         ' @cLottable12     NVARCHAR( 30), ' +
         ' @dLottable13     DATETIME,      ' +
         ' @dLottable14     DATETIME,      ' +
         ' @dLottable15     DATETIME,      ' +
         ' @tConfirm        VariableTable READONLY, ' +
         ' @nErrNo          INT           OUTPUT, ' +
         ' @cErrMsg         NVARCHAR( 20) OUTPUT '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
         @cToLoc, @cToID, @cFromLoc, @cFromID, @cUCC, @cSKU,  @nQTY, @cLottableCode,
         @cLottable01,  @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06,  @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11,  @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @tConfirm,  @nErrNo   OUTPUT, @cErrMsg  OUTPUT

      GOTO Quit
   END

   -- Get lottable filter
   EXEC rdt.rdt_Lottable_GetNextSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 4, @cLottableCode, 'LA',
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
      @cSelect  OUTPUT,
      @cWhere1  OUTPUT,
      @cWhere2  OUTPUT,
      @cGroupBy OUTPUT,
      @cOrderBy OUTPUT,
      @nErrNo   OUTPUT,
      @cErrMsg  OUTPUT

   -- Lottable filter
   IF @cWhere1 <> '' AND @cWhere2 <> ''
      SET @cWhere = @cWhere1 + ' = ' + @cWhere2

   IF ISNULL(@cWhere,'') <> ''     --SY01
      SET @cWhere = ' AND   ' + @cWhere

   SET @nReLOTQty = @nQty   -- Qty to move
   SET @nTtl_ReLOTQty = 0

   -- Standard confirm process
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN BuildUCC


   SET @cSQL = ''
   SET @cSQL =
   ' SELECT TOP 1 @cLot = LLI.LOT, ' +
   ' @nLOTQty = ISNULL( SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0)  ' +
   ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' +
   ' JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot) ' +
   ' WHERE LLI.StorerKey = @cStorerKey ' +
   ' AND   LLI.LOC = @cFromLOC ' +
   ' AND   (( ISNULL(@cFromID, '''') = '''') OR ( LLI.ID = @cFromID)) ' +
   ' AND   LLI.SKU = @cSKU ' +
   ' AND   LLI.QTY > 0 ' +
   CASE WHEN @cWhere = '' THEN '' ELSE @cWhere END  +
   ' GROUP BY LLI.LOT ' +
   ' ORDER BY LLI.LOT '

   SET @cSQLParam =
      '@cStorerKey   NVARCHAR( 15) , ' +
      '@cFromLOC     NVARCHAR( 10) , ' +
      '@cFromID      NVARCHAR( 18) , ' +
      '@cSKU         NVARCHAR( 20) , ' +
      '@cLottable01  NVARCHAR( 18), ' +
      '@cLottable02  NVARCHAR( 18), ' +
      '@cLottable03  NVARCHAR( 18), ' +
      '@dLottable04  DATETIME, ' +
      '@dLottable05  DATETIME, ' +
      '@cLottable06  NVARCHAR( 30), ' +
      '@cLottable07  NVARCHAR( 30), ' +
      '@cLottable08  NVARCHAR( 30), ' +
      '@cLottable09  NVARCHAR( 30), ' +
      '@cLottable10  NVARCHAR( 30), ' +
      '@cLottable11  NVARCHAR( 30), ' +
      '@cLottable12  NVARCHAR( 30), ' +
      '@dLottable13  DATETIME, ' +
      '@dLottable14  DATETIME, ' +
      '@dLottable15  DATETIME, ' +
      '@cLot         NVARCHAR( 10) OUTPUT, ' +
      '@nLOTQty      INT OUTPUT '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @cStorerKey  = @cStorerKey,
      @cFromLOC    = @cFromLOC,
      @cFromID     = @cFromID,
      @cSKU        = @cSKU,
      @cLottable01 = @cLottable01,
      @cLottable02 = @cLottable02,
      @cLottable03 = @cLottable03,
      @dLottable04 = @dLottable04,
      @dLottable05 = @dLottable05,
      @cLottable06 = @cLottable06,
      @cLottable07 = @cLottable07,
      @cLottable08 = @cLottable08,
      @cLottable09 = @cLottable09,
      @cLottable10 = @cLottable10,
      @cLottable11 = @cLottable11,
      @cLottable12 = @cLottable12,
      @dLottable13 = @dLottable13,
      @dLottable14 = @dLottable14,
      @dLottable15 = @dLottable15,
      @cLot        = @cLot       OUTPUT,
      @nLOTQty     = @nLOTQty    OUTPUT

   -- Move what is available first
   IF @nLOTQty > 0
   BEGIN
      IF @nLOTQty > @nReLOTQty
         SET @nLOTQty = @nReLOTQty

      -- Move to LOC
      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
         @cSourceType = 'rdt_MoveToUCC_V7',
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility,
         @cFromLOC    = @cFromLOC,
         @cToLOC      = @cToLOC,
         @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
         @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
         @cSKU        = @cSKU,
         @nQTY        = @nLOTQty,
         @cFromLOT    = @cLot,        -- Chee02
         @nFunc       = @nFunc        -- SKIP CantMixSKU&UCC Checking

      IF @nErrNo <> 0
         GOTO RollbackTran
      ELSE
      BEGIN
         -- EventLog - QTY
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '4', -- Move
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cLocation     = @cFromLOC,
            @cToLocation   = @cToLOC,
            @cID           = @cFromID,
            @cToID         = @cToID,
            @cSKU          = @cSKU,
            @cUOM          = @cMUOM_Desc,
            @nQTY          = @nLOTQty,
            @nStep         = @nStep,
            @cUCC          = @cUCC
      END

      SET @nReLOTQty = @nReLOTQty - @nLOTQty
   END

   WHILE @nReLOTQty > 0
   BEGIN
      DECLARE @curRelot CURSOR
      SET @cSQL = ''
      SET @cSQL =
      ' SELECT LLI.LOT, LLI.LOC, LLI.ID, ' +
      '          QTYAVAILABLE = (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen) ' +
      ' FROM dbo.LOTxLOCxID LLI (NOLOCK) ' +
      ' JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON (LLI.LOT = LA.LOT) ' +
      ' WHERE LLI.StorerKey = @cStorerKey ' +
      ' AND   LLI.LOC = @cFromLOC ' +
      ' AND   (( ISNULL(@cFromID, '''') = '''') OR ( LLI.ID = @cFromID)) ' +
      ' AND   LLI.SKU = @cSKU ' +
      ' AND   LLI.QTY > 0 ' +
      CASE WHEN @cWhere = '' THEN '' ELSE @cWhere END  +
      ' AND   LLI.LOT <> @cFromLot ' +
      ' ORDER BY 1 '

      SET @cSQLParam =
         '@curRelot     CURSOR  OUTPUT, ' +
         '@cStorerKey   NVARCHAR( 15) , ' +
         '@cFromLot     NVARCHAR( 10) , ' +
         '@cFromLOC     NVARCHAR( 10) , ' +
         '@cFromID      NVARCHAR( 18) , ' +
         '@cSKU         NVARCHAR( 20) , ' +
         '@cLottable01  NVARCHAR( 18), ' +
         '@cLottable02  NVARCHAR( 18), ' +
         '@cLottable03  NVARCHAR( 18), ' +
         '@dLottable04  DATETIME, ' +
         '@dLottable05  DATETIME, ' +
         '@cLottable06  NVARCHAR( 30), ' +
         '@cLottable07  NVARCHAR( 30), ' +
         '@cLottable08  NVARCHAR( 30), ' +
         '@cLottable09  NVARCHAR( 30), ' +
         '@cLottable10  NVARCHAR( 30), ' +
         '@cLottable11  NVARCHAR( 30), ' +
         '@cLottable12  NVARCHAR( 30), ' +
         '@dLottable13  DATETIME, ' +
         '@dLottable14  DATETIME, ' +
         '@dLottable15  DATETIME, ' +
         '@cLot         NVARCHAR( 10) OUTPUT, ' +
         '@cLoc         NVARCHAR( 10) OUTPUT, ' +
         '@cId          NVARCHAR( 18) OUTPUT, ' +
         '@nLotQty      INT OUTPUT '
      SET @cSQL = ' SET @curRelot = CURSOR FOR ' + @cSQL + ' OPEN @curRelot '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @curRelot    = @curRelot OUTPUT,
         @cStorerKey  = @cStorerKey,
         @cFromLot    = @cLot,
         @cFromLOC    = @cFromLOC,
         @cFromID     = @cFromID,
         @cSKU        = @cSKU,
         @cLottable01 = @cLottable01,
         @cLottable02 = @cLottable02,
         @cLottable03 = @cLottable03,
         @dLottable04 = @dLottable04,
         @dLottable05 = @dLottable05,
         @cLottable06 = @cLottable06,
         @cLottable07 = @cLottable07,
         @cLottable08 = @cLottable08,
         @cLottable09 = @cLottable09,
         @cLottable10 = @cLottable10,
         @cLottable11 = @cLottable11,
         @cLottable12 = @cLottable12,
         @dLottable13 = @dLottable13,
         @dLottable14 = @dLottable14,
         @dLottable15 = @dLottable15,
         @cLot        = @c_LOT   OUTPUT,
         @cLoc        = @c_LOC   OUTPUT,
         @cId         = @c_ID    OUTPUT,
         @nLotQty     = @nLOTQty OUTPUT

      FETCH NEXT FROM @curRelot INTO @c_LOT, @c_LOC, @c_ID, @nLOTQty

      WHILE (@@FETCH_STATUS <> -1 AND ISNULL( @nReLOTQty, 0) > 0)
      BEGIN
         IF @nLOTQty > @nReLOTQty
            SET @nLOTQty = @nReLOTQty

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
         FROM LOTATTRIBUTE WITH (NOLOCK)
         WHERE LOT = @c_LOT

         -- RELOT
         EXECUTE nspItrnAddWithdrawal
            @n_ItrnSysId  = NULL,
            @c_StorerKey  = @cStorerKey,
            @c_Sku        = @cSKU,
            @c_Lot        = @c_LOT,
            @c_ToLoc      = @c_LOC,
            @c_ToID       = @c_ID,
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
            @n_Qty        = @nLOTQty,
            @n_pallet     = 0,
            @f_cube       = 0,
            @f_grosswgt   = 0,
            @f_netwgt     = 0,
            @f_otherunit1 = 0,
            @f_otherunit2 = 0,
            @c_SourceKey  = '',
            @c_SourceType = 'rdt_MoveToUCC_V7',
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
            SET @nErrNo = 148401
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --WITHDRAW FAIL
            GOTO RollbackTran
         END

         EXECUTE nspItrnAddDeposit
            @n_ItrnSysId  = NULL,
            @c_StorerKey  = @cStorerKey,
            @c_Sku        = @cSKU,
            @c_Lot        = @cLOT,
            @c_ToLoc      = @c_LOC,
            @c_ToID       = @c_ID,
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
            @n_Qty        = @nLOTQty,
            @n_pallet     = 0,
            @f_cube       = 0,
            @f_grosswgt   = 0,
            @f_netwgt     = 0,
            @f_otherunit1 = 0,
            @f_otherunit2 = 0,
            @c_SourceKey  = '',
            @c_SourceType = 'rdt_MoveToUCC_V7',
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
            SET @nErrNo = 148402
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --DEPOSIT FAIL
            GOTO RollbackTran
         END

         SET @nReLOTQty = @nReLOTQty - @nLOTQty
         SET @nTtl_ReLOTQty = @nTtl_ReLOTQty + @nLOTQty

         IF @nReLOTQty = 0
            BREAK

         FETCH NEXT FROM @curRelot INTO @c_LOT, @c_LOC, @c_ID, @nLOTQty
      END -- END WHILE FOR CURSOR_RELOT

      CLOSE @curRelot
      DEALLOCATE @curRelot

      -- Move to LOC
      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
         @cSourceType = 'rdt_MoveToUCC_V7',
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility,
         @cFromLOC    = @cFromLOC,
         @cToLOC      = @cToLOC,
         @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
         @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
         @cSKU        = @cSKU,
         @nQTY        = @nTtl_ReLOTQty,
         @cFromLOT    = @cLot,        -- Chee02
         @nFunc       = @nFunc        -- SKIP CantMixSKU&UCC Checking

      IF @nErrNo <> 0
         GOTO RollbackTran
      ELSE
      BEGIN
         -- EventLog - QTY
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '4', -- Move
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cLocation     = @cFromLOC,
            @cToLocation   = @cToLOC,
            @cID           = @cFromID,
            @cToID         = @cToID,
            @cSKU          = @cSKU,
            @cUOM          = @cMUOM_Desc,
            @nQTY          = @nQTY,
            @nStep         = @nStep,
            @cUCC          = @cUCC
      END

      IF @nTtl_ReLOTQty >= @nReLOTQTY
         BREAK
   END

   SET @cUCCLot = @cLot

   DECLARE @cBarCode       NVARCHAR( 60)
   DECLARE @cUserdefined01 NVARCHAR( 15)
   DECLARE @cUserdefined02 NVARCHAR( 15)
   DECLARE @cUserdefined03 NVARCHAR( 20)
   DECLARE @cUserdefined04 NVARCHAR( 30)
   DECLARE @cUserdefined05 NVARCHAR( 30)
   DECLARE @cUserdefined06 NVARCHAR( 30)
   DECLARE @cUserdefined07 NVARCHAR( 30)
   DECLARE @cUserdefined08 NVARCHAR( 30)
   DECLARE @cUserdefined09 NVARCHAR( 30)
   DECLARE @cUserdefined10 NVARCHAR( 30)

   SET @cUserdefined01 = ''
   SET @cUserdefined02 = ''
   SET @cUserdefined03 = ''
   SET @cUserdefined04 = ''
   SET @cUserdefined05 = ''
   SET @cUserdefined06 = ''
   SET @cUserdefined07 = ''
   SET @cUserdefined08 = ''
   SET @cUserdefined09 = ''
   SET @cUserdefined10 = ''

   -- Build/Update UCC
   IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                  WHERE UCCNo   = @cUCC
                  AND StorerKey = @cStorerKey
                  AND SKU       = @cSKU
                  AND Lot       = @cUCCLot
                  AND ID        = @cToID
                  AND Loc       = @cToLoc )
   BEGIN
      IF @nMultiStorer = 1
         INSERT INTO UCC (UCCNo, StorerKey, ExternKey, Qty, SourceType, Status, SKU, Lot, Loc, ID,
            Userdefined01, Userdefined02, Userdefined03, Userdefined04, Userdefined05,
            Userdefined06, Userdefined07, Userdefined08, Userdefined09, Userdefined10)
         VALUES (@cUCC, @cStorerKey, '', @nQTY, 'rdt_MoveToUCC_V7', '1', @cSKU, @cUCCLot, @cToLOC ,@cToID,
            @cUserdefined01, @cUserdefined02, @cUserdefined03, @cUserdefined04, @cUserdefined05,
            @cUserdefined06, @cUserdefined07, @cUserdefined08, @cUserdefined09, @cUserdefined10)
      ELSE
         INSERT INTO UCC (UCCNo, StorerKey, ExternKey, Qty, SourceType, Status, SKU, Lot, Loc, ID,
            Userdefined01, Userdefined02, Userdefined03, Userdefined04, Userdefined05,
            Userdefined06, Userdefined07, Userdefined08, Userdefined09, Userdefined10)
         VALUES (@cUCC, @cStorerKey, '', @nQTY, 'rdt_MoveToUCC_V7', '1', @cSKU, @cUCCLot, @cToLOC ,@cToID,
            @cUserdefined01, @cUserdefined02, @cUserdefined03, @cUserdefined04, @cUserdefined05,
            @cUserdefined06, @cUserdefined07, @cUserdefined08, @cUserdefined09, @cUserdefined10)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 148403
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'INS UCC FAIL'
         GOTO RollbackTran
      END
   END
   ELSE
   BEGIN
      UPDATE dbo.UCC
      SET Qty = Qty + @nQty
      WHERE UCCNo = @cUCC
      AND StorerKey = @cStorerKey
      AND SKU       = @cSKU
      AND Lot       = @cUCCLot
      AND ID        = @cToID
      AND Loc       = @cToLoc

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 148404
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'UpdUCCFail'
         GOTO RollbackTran
      END

   END

   SET @cStorerConfig_ByPassCantMixSKUnUCC = rdt.RDTGetConfig( @nFunc, 'ByPassCantMixSKUnUCC', @cStorerKey)

   IF @cStorerConfig_ByPassCantMixSKUnUCC <> '1'
   BEGIN
      -- Get StorerConfig 'UCC'
      SET @cStorerConfig_UCC = '0' -- Default Off
      SELECT @cStorerConfig_UCC = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
      FROM dbo.StorerConfig (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ConfigKey = 'UCC'

      SET @cMoveQTYAlloc = rdt.RDTGetConfig(@nFunc, 'MoveQTYAlloc', @cStorerKey)

      -- Get ToLOC LocationType
      SET @cToLocType = '' -- Default as BULK (just in case SKUxLOC not yet setup)
      SELECT @cToLocType = LocationType
      FROM dbo.SKUxLOC (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND LOC = @cToLOC

      -- Validate if moved ToLOC will cause SKU + UCC mixed
      -- Check bulk location only. Pick location always lose UCC and become SKU
      IF @cStorerConfig_UCC = '1' AND                           -- When warehouse has SKU and UCC
         NOT (@cToLocType IN ('CASE', 'PICK') OR @cLoseUCC = '1') -- ToLOC keep UCC
      BEGIN
         -- Get ToLOC SKU QTY
         SELECT @nToLOC_SKU =
            CASE WHEN @cMoveQTYAlloc = '1'
               THEN IsNULL( SUM( QTY - QTYPicked), 0)
               ELSE IsNULL( SUM( QTY - QtyAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)), 0) -- (Avail + Alloc)
            END
         FROM dbo.LOTxLOCxID (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cToLOC
            AND ID  = CASE WHEN @cToID IS NULL THEN ID ELSE @cToID END
            AND SKU = @cSKU

         -- Get ToLOC UCC QTY
         SELECT @nToLOC_UCC = IsNULL( SUM( UCC.QTY), 0)
         FROM dbo.UCC UCC (NOLOCK)
         WHERE UCC.StorerKey = @cStorerKey
            AND UCC.LOC = @cToLOC
            AND UCC.ID  = CASE WHEN @cToID IS NULL THEN UCC.ID ELSE @cToID END
            AND UCC.Status = '1' -- Received (Avail + Alloc)
            AND UCC.SKU = @cSKU

         IF @nToLOC_SKU > 0 -- Means SKU or UCC have stock
         BEGIN
            IF @nToLOC_SKU = @nToLOC_UCC -- To contain only UCC
               SET @nToLOC_SKU = 0
            IF (@nToLOC_SKU <> 0 AND @nToLOC_UCC <> 0) -- ToLOC is already mix SKU and UCC
            BEGIN
               SET @nErrNo = 148405
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'CantMixSKU&UCC'
               GOTO RollbackTran
            END
         END
      END
   END

   GOTO Quit

   RollbackTran:
      ROLLBACK TRAN BuildUCC
   Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

   Fail:


GO