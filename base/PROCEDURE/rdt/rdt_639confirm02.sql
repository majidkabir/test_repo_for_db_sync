SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_639Confirm02                                          */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2023-01-31   Ung       1.0   WMS-21506 Created                             */
/* 2023-04-28   Ung       1.1   WMS-21506 Add L12 inaccessible                */
/* 2023-04-11   Ung       1.2   WMS-22105 Allow SKU to process once Printed   */
/******************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_639Confirm02]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
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
   @tConfirm        VariableTable READONLY,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success   INT
   DECLARE @n_err       INT
   DECLARE @c_errmsg    NVARCHAR( 20)

   DECLARE @nTranCount  INT
   DECLARE @nRowCount   INT

   /*
   To lottables:
      L01, 03, 09, take random any set from FromLOC 
      L02, 10, 11, 12, only 1 set at FromLOC 
      L04, 06, 07, 08, 13, 14, 15 set to blank/NULL
   */
   SELECT TOP 1 
      @cLottable01 = @cFromLOC,
      @cLottable02 = Lottable02,
      @cLottable03 = @cFromLOC,
      @dLottable04 = NULL,
      @dLottable05 = CAST( GETDATE() AS DATE),
      @cLottable06 = '',
      @cLottable07 = '',
      @cLottable08 = '',
      @cLottable09 = @cFromLOC,
      @cLottable10 = Lottable10,
      @cLottable11 = Lottable11,
      @cLottable12 = Lottable12,
      @dLottable13 = NULL,
      @dLottable14 = NULL,
      @dLottable15 = NULL 
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
   WHERE LLI.LOC = @cFromLOC
      AND LLI.ID = @cFromID
      AND LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - LLI.QTYReplen > 0
      AND LA.Lottable12 <> 'inaccessible'

   /************************************************************************************************
      Create new LOT if not exist
   ************************************************************************************************/
   BEGIN 
      DECLARE @cNewLOT NVARCHAR( 10) 
      
      -- Look up existing LOT
      SET @b_Success = 0
      EXECUTE nsp_lotlookup
           @cStorerKey
         , @cSKU
         , @cLottable01
         , @cLottable02
         , @cLottable03
         , @dLottable04
         , @dLottable05
         , @cLottable06
         , @cLottable07
         , @cLottable08
         , @cLottable09
         , @cLottable10
         , @cLottable11
         , @cLottable12
         , @dLottable13
         , @dLottable14
         , @dLottable15
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
               , @cLottable01
               , @cLottable02
               , @cLottable03
               , @dLottable04
               , @dLottable05
               , @cLottable06
               , @cLottable07
               , @cLottable08
               , @cLottable09
               , @cLottable10
               , @cLottable11
               , @cLottable12
               , @dLottable13
               , @dLottable14
               , @dLottable15
               , @cNewLOT     OUTPUT
               , @b_Success   OUTPUT
               , @n_err       OUTPUT
               , @c_ErrMsg    OUTPUT
            IF @b_Success <> 1
            BEGIN
               SET @nErrNo = 196351
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CreateLOT fail
               GOTO Quit
            END
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 196352
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LookupLOT fail
         GOTO Quit
      END
   END

   /************************************************************************************************
      Cancel PendingNoveIn of old LOT, if any
      Change stock to new LOT, using Withdraw, Deposit
   ************************************************************************************************/
   BEGIN
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

      DECLARE @cLOT        NVARCHAR( 10)
      DECLARE @nQTY_Bal    INT
      DECLARE @nQTY_RF     INT
      DECLARE @nQTY_Reduce INT
      DECLARE @nRowRef     INT
      DECLARE @cSuggestedLOC NVARCHAR( 10)

      SET @nTranCount = @@TRANCOUNT
      SET @nQTY_Bal = @nQTY -- Qty to move
      
      BEGIN TRAN
      SAVE TRAN rdt_639Confirm02
      
      -- Loop booking
      DECLARE @curRF CURSOR
      SET @curRF = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef, RF.LOT, RF.QTY, RF.SuggestedLOC
         FROM dbo.RFPutaway RF WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (RF.SuggestedLOC = LOC.LOC)
         WHERE RF.FromLOC = @cFromLOC
            AND RF.FromID = @cFromID
            AND RF.StorerKey = @cStorerKey
            AND RF.SKU = @cSKU
            AND RF.QTYPrinted > 0
            AND LOC.LocationCategory IN ('FP','HP','FC')
         ORDER BY 
            CASE LOC.LocationCategory 
               WHEN 'FP' THEN 1
               WHEN 'HP' THEN 2
               WHEN 'FC' THEN 3
               ELSE 9
            END
      OPEN @curRF 
      FETCH NEXT FROM @curRF INTO @nRowRef, @cLOT, @nQTY_RF, @cSuggestedLOC
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Calc booking to reduce
         IF @nQTY_RF > @nQTY_Bal
            SET @nQTY_Reduce = @nQTY_Bal
         ELSE
            SET @nQTY_Reduce = @nQTY_RF
         
         -- Reduce RFPutaway
         IF @nQTY_RF <= @nQTY_Reduce
         BEGIN
            DELETE dbo.RFPutaway WHERE RowRef = @nRowREf
            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 196353
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL RFP Fail
               GOTO RollbackTran
            END            
         END
         ELSE
         BEGIN
            UPDATE dbo.RFPutaway SET
               QTY = QTY - @nQTY_Reduce, 
               QTYPrinted = QTYPrinted - @nQTY_Reduce
            WHERE RowRef = @nRowREf
            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 196354
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL RFP Fail
               GOTO RollbackTran
            END
         END

         -- Reduce LLI
         UPDATE dbo.LOTxLOCxID SET
            PendingMoveIn = PendingMoveIn - @nQTY_Reduce
         WHERE LOC = @cSuggestedLOC
            AND ID = @cFromID
            AND LOT = @cLOT
            AND PendingMoveIn >= @nQTY_Reduce
         IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
         BEGIN
            SET @nErrNo = 196355
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail
            GOTO RollbackTran
         END

         -- Change stock to new LOT
         IF @cLOT <> @cNewLOT
         BEGIN
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
               @n_Qty        = @nQTY_Reduce,
               @n_pallet     = 0,
               @f_cube       = 0,
               @f_grosswgt   = 0,
               @f_netwgt     = 0,
               @f_otherunit1 = 0,
               @f_otherunit2 = 0,
               @c_SourceKey  = '',
               @c_SourceType = 'rdt_639Confirm02',
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
               SET @nErrNo = 196356
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
               @c_lottable01 = @cLottable01,
               @c_lottable02 = @cLottable02,
               @c_lottable03 = @cLottable03,
               @d_lottable04 = @dLottable04,
               @d_lottable05 = @dLottable05,
               @c_lottable06 = @cLottable06,
               @c_lottable07 = @cLottable07,
               @c_lottable08 = @cLottable08,
               @c_lottable09 = @cLottable09,
               @c_lottable10 = @cLottable10,
               @c_lottable11 = @cLottable11,
               @c_lottable12 = @cLottable12,
               @d_lottable13 = @dLottable13,
               @d_lottable14 = @dLottable14,
               @d_lottable15 = @dLottable15,
               @n_casecnt    = 0,
               @n_innerpack  = 0,
               @n_Qty        = @nQTY_Reduce,
               @n_pallet     = 0,
               @f_cube       = 0,
               @f_grosswgt   = 0,
               @f_netwgt     = 0,
               @f_otherunit1 = 0,
               @f_otherunit2 = 0,
               @c_SourceKey  = '',
               @c_SourceType = 'rdt_639Confirm02',
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
               SET @nErrNo = 196357
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEPOSIT FAIL
               GOTO RollbackTran
            END
         END
         
         SET @nQTY_Bal = @nQTY_Bal - @nQTY_Reduce
         IF @nQTY_Bal = 0
            BREAK

         FETCH NEXT FROM @curRF INTO @nRowRef, @cLOT, @nQTY_RF, @cSuggestedLOC
      END
   END

   /************************************************************************************************
      Move stock and create/update new UCC
   ************************************************************************************************/
   BEGIN
      -- Move stock
      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, 
         @cSourceType = 'rdt_639Confirm02',
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility,
         @cFromLOC    = @cFromLOC,
         @cToLOC      = @cToLOC,
         @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
         @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
         @cSKU        = @cSKU,
         @nQTY        = @nQTY,
         @cFromLOT    = @cNewLOT,
         @nFunc       = @nFunc
      IF @nErrNo <> 0
         GOTO RollbackTran

      -- Create/update UCC
      IF NOT EXISTS (SELECT 1 
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cUCC
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND LOT = @cNewLOT
            AND ID = @cToID
            AND LOC = @cToLOC)
      BEGIN
         INSERT INTO dbo.UCC (UCCNo, StorerKey, ExternKey, Qty, SourceType, Status, SKU, LOT, LOC, ID, UserDefined10)
         VALUES (@cUCC, @cStorerKey, '', @nQTY, 'rdt_639Confirm02', '1', @cSKU, @cNewLOT, @cToLOC ,@cToID, @cSuggestedLOC)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 196358
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS UCC Fail
            GOTO RollbackTran
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.UCC SET 
            QTY = QTY + @nQTY, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE UCCNo = @cUCC
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND LOT = @cNewLOT
            AND ID = @cToID
            AND LOC = @cToLOC
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 196359
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC fail
            GOTO RollbackTran
         END
      END
   END

   /************************************************************************************************
      Check new UCC at TOLOC cause UCC mix with loose QTY
   ************************************************************************************************/
   BEGIN
      DECLARE @cStorerConfig_ByPassCantMixSKUnUCC NVARCHAR( 1)
      DECLARE @cStorerConfig_UCC NVARCHAR( 1)
      DECLARE @cMoveQTYAlloc     NVARCHAR(1)
      DECLARE @cToLocType        NVARCHAR(10)
      DECLARE @cLoseUCC          NVARCHAR(1)
      DECLARE @nFromLOC_SKU      INT
      DECLARE @nFromLOC_UCC      INT
      DECLARE @nToLOC_SKU        INT
      DECLARE @nToLOC_UCC        INT
      
      -- SET @cStorerConfig_ByPassCantMixSKUnUCC = rdt.RDTGetConfig( @nFunc, 'ByPassCantMixSKUnUCC', @cStorerKey)
      -- IF @cStorerConfig_ByPassCantMixSKUnUCC <> '1'
      BEGIN
         -- Get StorerConfig 'UCC'
         SET @cStorerConfig_UCC = '0' -- Default Off
         SELECT @cStorerConfig_UCC = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
         FROM dbo.StorerConfig (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ConfigKey = 'UCC'

         SET @cMoveQTYAlloc = rdt.RDTGetConfig(@nFunc, 'MoveQTYAlloc', @cStorerKey)

         SELECT @cLoseUCC = LoseUCC FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC

         -- Get ToLOC LocationType
         SET @cToLocType = '' -- Default as BULK (just in case SKUxLOC not yet setup)
         SELECT @cToLocType = LocationType
         FROM dbo.SKUxLOC (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND LOC = @cToLOC

         -- Validate if moved ToLOC will cause SKU + UCC mixed
         -- Check bulk location only. Pick location always lose UCC and become SKU
         IF @cStorerConfig_UCC = '1' AND                             -- When warehouse has SKU and UCC
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
                  SET @nErrNo = 196360
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CantMixSKU&UCC
                  GOTO RollbackTran
               END
            END
         END
      END
   END

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
      @cSKU          = @cSKU,
      @nQTY          = @nQTY,
      @cUCC          = @cUCC

   GOTO Quit

RollbackTran:
   ROLLBACK TRAN rdt_639Confirm02
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO