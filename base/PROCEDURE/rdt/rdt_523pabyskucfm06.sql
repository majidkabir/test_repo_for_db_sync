SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_523PABySKUCfm06                                 */  
/*                                                                      */  
/* Purpose: Conditional trigger transfer                                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author   Purposes                                   */  
/* 2024-03-19  1.0  YeeKung  WMS-23779 Created                          */  
/************************************************************************/  
  
CREATE   PROC [rdt].[rdt_523PABySKUCfm06] (  
   @nMobile         INT,  
   @nFunc           INT,  
   @cLangCode       NVARCHAR( 3),  
   @cStorerKey      NVARCHAR( 15),  
   @cFacility       NVARCHAR( 5),  
   @tPABySKU        VariableTable READONLY,  
   @nPABookingKey   INT           OUTPUT,  
   @nErrNo          INT           OUTPUT,  
   @cErrMsg         NVARCHAR( 20) OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Success   INT = 0  
   DECLARE @n_Err       INT = 0  
   DECLARE @c_ErrMsg    NVARCHAR(215) = '' 
   DECLARE @nRowRef     INT
  
   DECLARE @nTranCount  INT  
   DECLARE @cLLI_LOT    NVARCHAR( 10)  
   DECLARE @nLLI_QTY    INT  
   DECLARE @nPA_QTY     INT  
  
   DECLARE @cUserName   NVARCHAR( 18)  
   DECLARE @cLOT        NVARCHAR( 10)  
   DECLARE @cLOC        NVARCHAR( 10)  
   DECLARE @cID         NVARCHAR( 18)  
   DECLARE @cSKU        NVARCHAR( 20)  
   DECLARE @nQTY        INT  
   DECLARE @cFinalLOC   NVARCHAR( 10)  
   DECLARE @cLabelType  NVARCHAR( 20)   
   DECLARE @cUCC        NVARCHAR( 20)  

   DECLARE @c_outstring NVARCHAR( 255)

   DECLARE @cPA_StorerKey NVARCHAR( 15)
   DECLARE @cPA_SKU   NVARCHAR( 20)
   DECLARE @cPA_LOT   NVARCHAR( 10)
   DECLARE @cPackKey  NVARCHAR( 10)
   DECLARE @cPackUOM3 NVARCHAR( 10)

   DECLARE @cTransferKey   NVARCHAR( 10) = ''  
   DECLARE @cTransferLineNumber  NVARCHAR( 5) 
   DECLARE @cLocHostWHCode NVARCHAR(20)
   DECLARE @cLottable06    NVARCHAR( 30)
   DECLARE @cToLottable06  NVARCHAR( 30)
   DECLARE @cToLottable01  NVARCHAR( 18)  
   DECLARE @cToLottable02  NVARCHAR( 18)  
   DECLARE @cToLottable03  NVARCHAR( 18)  
   DECLARE @dToLottable04  DATETIME  
   DECLARE @dToLottable05  DATETIME   
   DECLARE @cToLottable07  NVARCHAR( 30)  
   DECLARE @cToLottable08  NVARCHAR( 30)  
   DECLARE @cToLottable09  NVARCHAR( 30)  
   DECLARE @cToLottable10  NVARCHAR( 30)  
   DECLARE @cToLottable11  NVARCHAR( 30)  
   DECLARE @cToLottable12  NVARCHAR( 30)  
   DECLARE @dToLottable13  DATETIME  
   DECLARE @dToLottable14  DATETIME  
   DECLARE @dToLottable15  DATETIME
   DECLARE @curPutaway     CURSOR 
   DECLARE @cNewLOT        NVARCHAR( 10)
   
   -- Get PackKey, UOM
   SELECT @cPackKey = PackKey FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   SELECT @cPackUOM3 = PackUOM3 FROM Pack WITH (NOLOCK) WHERE PackKey = @cPackKey
   
   -- Variable mapping  
   SELECT @cUserName  = Value FROM @tPABySKU WHERE Variable = '@cUserName'  
   SELECT @cLOT       = Value FROM @tPABySKU WHERE Variable = '@cLOT'  
   SELECT @cLOC       = Value FROM @tPABySKU WHERE Variable = '@cLOC'  
   SELECT @cID        = Value FROM @tPABySKU WHERE Variable = '@cID'  
   SELECT @cSKU       = Value FROM @tPABySKU WHERE Variable = '@cSKU'  
   SELECT @nQTY       = Value FROM @tPABySKU WHERE Variable = '@cQTY'  
   SELECT @cFinalLOC  = Value FROM @tPABySKU WHERE Variable = '@cFinalLOC'  
   SELECT @cLabelType = Value FROM @tPABySKU WHERE Variable = '@cLabelType'  
   SELECT @cUCC       = Value FROM @tPABySKU WHERE Variable = '@cUCC'  
  
   -- Handling transaction  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_523PABySKUCfm06 -- For rollback or commit only our own transaction  

   IF EXISTS(  SELECT 1
               FROM dbo.RFPutaway WITH (NOLOCK)
               WHERE PABookingKey = @nPABookingKey)
   BEGIN
      SET @curPutaway = CURSOR FOR
      SELECT 
        StorerKey, SKU, LOT,QTY,Rowref
      FROM dbo.RFPutaway WITH (NOLOCK)
      WHERE PABookingKey = @nPABookingKey
   END
   ELSE
   BEGIN
      SET @curPutaway = CURSOR FOR
      SELECT Storerkey, SKU, LOT, (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)),''  
      FROM LOTxLOCxID WITH (NOLOCK)  
      WHERE LOC = @cLOC  
         AND ID = @cID  
         AND SKU = @cSKU 
         AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0  
   END

   OPEN @curPutaway
   FETCH NEXT FROM @curPutaway INTO @cPA_StorerKey, @cPA_SKU, @cPA_LOT, @nPA_QTY,@nRowRef

   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @nQTY < @nPA_QTY
         SET @nPA_QTY = @nQTY

      EXEC rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode, 
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
         @cSourceType = 'rdt_523PABySKUCfm06', 
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility, 
         @cFromLOC    = @cLOC, 
         @cToLOC      = @cFinalLOC, 
         @cFromID     = @cID,       -- NULL means not filter by ID. Blank is a valid ID
         @cToID       = @cID,       -- NULL means not changing ID. Blank consider a valid ID
         @cSKU        = @cPA_SKU, 
         @nQTY        = @nPA_QTY, 
         @cFromLOT    = @cPA_LOT


      IF @nErrNo <> 0
         GOTO RollBackTran

      IF ISNULL(@nRowRef,'') <>''
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --FromLOC
            ,'' --FromID
            ,'' --SuggLOC
            ,'' --Storer
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nRowRef = @nRowRef
         IF @nErrNo <> 0
            GOTO RollBackTran
      END


      SELECT  
         @cToLottable01 = Lottable01,  
         @cToLottable02 = Lottable02,  
         @cToLottable03 = Lottable03,   
         @dToLottable04 = Lottable04,  
         @dToLottable05 = Lottable05,  
         @cLottable06   = Lottable06,  
         @cToLottable07 = Lottable07,  
         @cToLottable08 = Lottable08,  
         @cToLottable09 = Lottable09,  
         @cToLottable10 = Lottable10,  
         @cToLottable11 = Lottable11,  
         @cToLottable12 = Lottable12,  
         @dToLottable13 = Lottable13,  
         @dToLottable14 = Lottable14,  
         @dToLottable15 = Lottable15  
      FROM dbo.LOTAttribute WITH (NOLOCK)  
      WHERE LOT = @cPA_LOT  

      SELECT @cToLottable06 = HOSTWHCODE
      FROM LOC (NOLOCK) 
      WHERE LOC = @cFinalLOC
         AND Facility = @cFacility

      IF ISNULL(@cLottable06,'') = ''
      BEGIN
         EXECUTE dbo.nsp_LotGen
            @cStorerKey
          , @cSKU
          , @cToLottable01
          , @cToLottable02
          , @cToLottable03
          , @dToLottable04
          , @dToLottable05
          , @cToLottable06  
          , @cToLottable07
          , @cToLottable08
          , @cToLottable09
          , @cToLottable10
          , @cToLottable11
          , @cToLottable12
          , @dToLottable13
          , @dToLottable14
          , @dToLottable15
          , @cNewLOT  OUTPUT
          , @b_Success OUTPUT
          , @nErrNo   OUTPUT
          , @cErrMsg  OUTPUT

         IF @b_Success <> 1
            GOTO RollbackTran


         EXECUTE nspItrnAddWithdrawal
            @n_ItrnSysId  = NULL,
            @c_StorerKey  = @cStorerKey,
            @c_Sku        = @cSKU,
            @c_Lot        = @cPA_LOT,
            @c_ToLoc      = @cFinalLOC,
            @c_ToID       = '',
            @c_Status     = '',
            @c_lottable01 = @cToLottable01,
            @c_lottable02 = @cToLottable02,
            @c_lottable03 = @cToLottable03,
            @d_lottable04 = @dToLottable04,
            @d_lottable05 = @dToLottable05,
            @c_lottable06 = @cLottable06,
            @c_lottable07 = @cToLottable07,
            @c_lottable08 = @cToLottable08,
            @c_lottable09 = @cToLottable09,
            @c_lottable10 = @cToLottable10,
            @c_lottable11 = @cToLottable11,
            @c_lottable12 = @cToLottable12,
            @d_lottable13 = @dToLottable13,
            @d_lottable14 = @dToLottable14,
            @d_lottable15 = @dToLottable15,
            @n_casecnt    = 0,
            @n_innerpack  = 0,
            @n_Qty        = @nPA_QTY,
            @n_pallet     = 0,
            @f_cube       = 0,
            @f_grosswgt   = 0,
            @f_netwgt     = 0,
            @f_otherunit1 = 0,
            @f_otherunit2 = 0,
            @c_SourceKey  = '',
            @c_SourceType = 'rdt_523PABySKUCfm06',
            @c_PackKey    = '',
            @c_UOM        = '',
            @b_UOMCalc    = 0,
            @d_EffectiveDate = NULL,
            @c_ItrnKey    = '',
            @b_Success    = @b_Success OUTPUT,
            @n_err        = @nErrNo   OUTPUT,
            @c_errmsg     = @cErrMsg  OUTPUT

         IF @b_Success <> 1
         BEGIN
            GOTO RollbackTran
         END

         EXECUTE nspItrnAddDeposit
            @n_ItrnSysId  = NULL,
            @c_StorerKey  = @cStorerKey,
            @c_Sku        = @cSKU,
            @c_Lot        = @cNewLOT,
            @c_ToLoc      = @cFinalLOC,
            @c_ToID       = '',
            @c_Status     = '',
            @c_lottable01 = @cToLottable01,
            @c_lottable02 = @cToLottable02,
            @c_lottable03 = @cToLottable03,
            @d_lottable04 = @dToLottable04,
            @d_lottable05 = @dToLottable05,
            @c_lottable06 = @cToLottable06,
            @c_lottable07 = @cToLottable07,
            @c_lottable08 = @cToLottable08,
            @c_lottable09 = @cToLottable09,
            @c_lottable10 = @cToLottable10,
            @c_lottable11 = @cToLottable11,
            @c_lottable12 = @cToLottable12,
            @d_lottable13 = @dToLottable13,
            @d_lottable14 = @dToLottable14,
            @d_lottable15 = @dToLottable15,
            @n_casecnt    = 0,
            @n_innerpack  = 0,
            @n_Qty        = @nPA_QTY,
            @n_pallet     = 0,
            @f_cube       = 0,
            @f_grosswgt   = 0,
            @f_netwgt     = 0,
            @f_otherunit1 = 0,
            @f_otherunit2 = 0,
            @c_SourceKey  = '',
            @c_SourceType = 'rdt_523PABySKUCfm06',
            @c_PackKey    = '',
            @c_UOM        = '',
            @b_UOMCalc    = 0,
            @d_EffectiveDate = NULL,
            @c_ItrnKey    = '',
            @b_Success    = @b_Success OUTPUT,
            @n_err        = @nErrNo   OUTPUT,
            @c_errmsg     = @cErrMsg  OUTPUT

         IF @b_Success <> 1
         BEGIN
            GOTO RollbackTran
         END
      END

      SET @nQTY = @nQTY - @nPA_QTY
      IF @nQTY = 0
         BREAK
         
      FETCH NEXT FROM @curPutaway INTO @cPA_StorerKey, @cPA_SKU, @cPA_LOT, @nPA_QTY,@nRowRef
   END
   CLOSE @curPutaway
   DEALLOCATE @curPutaway
   -- Unlock current session suggested LOC   

   COMMIT TRAN rdt_523PABySKUCfm06 -- Only commit change made here  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_523PABySKUCfm06 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO