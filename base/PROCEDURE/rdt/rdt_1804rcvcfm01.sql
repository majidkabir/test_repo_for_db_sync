SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1804RcvCfm01                                       */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2018-01-29 1.0  ChewKP  WMS-3850 Created                                */
/***************************************************************************/
CREATE PROC [RDT].[rdt_1804RcvCfm01](
   @nMobile        INT,
   @nFunc          INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cFromLoc       NVARCHAR( 10),
   @cFromID        NVARCHAR( 18),
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18),
   @cSKU           NVARCHAR( 20),
   @cLot           NVARCHAR( 10),
   @nQty           INT,
   @cUCC           NVARCHAR( 20),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @nMultiStorer   INT,     
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
   
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nLotQty           INT
          ,@nReLOTQty         INT
          ,@c_LOT             NVARCHAR(10) 
          ,@c_LOC             NVARCHAR(10)
          ,@c_ID              NVARCHAR(18)
          ,@c_Lottable01      NVARCHAR(18)
          ,@c_Lottable02      NVARCHAR(18)
          ,@c_Lottable03      NVARCHAR(18)
          ,@d_Lottable04      DATETIME
          ,@d_Lottable05      DATETIME
          ,@c_Lottable06      NVARCHAR(30)   
          ,@c_Lottable07      NVARCHAR(30)   
          ,@c_Lottable08      NVARCHAR(30)   
          ,@c_Lottable09      NVARCHAR(30)   
          ,@c_Lottable10      NVARCHAR(30)   
          ,@c_Lottable11      NVARCHAR(30)   
          ,@c_Lottable12      NVARCHAR(30)   
          ,@d_Lottable13      DATETIME       
          ,@d_Lottable14      DATETIME       
          ,@d_Lottable15      DATETIME       
          ,@b_Success         INT
          ,@cSKU_StorerKey    NVARCHAR(20) 
          ,@cUserName         NVARCHAR(18) 
          ,@cNewLot           NVARCHAR(10) 

          ,@clottable06   NVARCHAR(30) 
          ,@clottable07   NVARCHAR(30) 
          ,@clottable08   NVARCHAR(30) 
          ,@clottable09   NVARCHAR(30) 
          ,@clottable10   NVARCHAR(30) 
          ,@clottable11   NVARCHAR(30) 
          ,@clottable12   NVARCHAR(30) 
          ,@dlottable13   datetime 
          ,@dlottable14   datetime 
          ,@dlottable15   datetime 
          ,@bSuccess      INT

   SELECT @cUserName = UserName
   FROM rdt.rdtMobrec WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1804RcvCfm01   
      
   
   IF @nFunc = 1804 
   BEGIN
   

      IF @nStep = 7
      BEGIN
         SELECT @cSKU_StorerKey = StorerKey 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 

         SELECT
               @cLottable01 = Lottable01,
               @cLottable02 = Lottable02,
               @cLottable03 = Lottable03,
               @dLottable04 = Lottable04,
               @dLottable05 = Lottable05,
               @cLottable06 = Lottable06,
               @cLottable07 = Lottable07,
               @cLottable08 = Lottable08,
               @cLottable09 = Lottable09,
               @cLottable10 = Lottable10,
               @cLottable11 = Lottable11,
               @cLottable12 = Lottable12,
               @dLottable13 = Lottable13,
               @dLottable14 = Lottable14,
               @dLottable15 = Lottable15
         FROM LOTATTRIBUTE WITH (NOLOCK)
         WHERE LOT = @cLOT


         EXECUTE dbo.nsp_LotGen
            @cStorerKey
          , @cSKU
          , @cLottable01
          , @cLottable02
          , @cLottable03
          , @dLottable04
          , @dLottable05
          , @cLottable06   --(CS01)
          , @cLottable07   --(CS01)
          , @cLottable08   --(CS01)
          , @cLottable09   --(CS01)
          , @nQty--, @cLottable10   --(CS01)
          , @cUCC--, @cLottable11   --(CS01)
          , @cLottable12   --(CS01)
          , @dLottable13   --(CS01)
          , @dLottable14   --(CS01)
          , @dLottable15   --(CS01)
          , @cNewLOT  OUTPUT
          , @bSuccess OUTPUT
          , @nErrNo   OUTPUT
          , @cErrMsg  OUTPUT

         IF @bSuccess <> 1
            GOTO RollbackTran

         

         -- Get @nLOTQty
         --SELECT @nLOTQty = SUM(QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END))
         --FROM dbo.LOTxLOCxID (NOLOCK)
         --WHERE StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
         --  AND LOC = @cFromLOC
         --  AND ID = CASE WHEN ISNULL(@cFromID, '') <> '' THEN @cFromID ELSE ID END
         --  AND SKU = @cSKU
         --  AND QTY > 0
         --  AND LOT = @cLOT

         
         SET @nReLOTQty = @nQty 
         --SET @nReLOTQty = @nQty - @nLOTQty

         
		 

         DECLARE CURSOR_RELOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.LOT,
                LLI.LOC,
                LLI.ID,
                QTYAVAILABLE = (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen)
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
         JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN @cSKU_StorerKey ELSE @cStorerKey END
           AND LLI.LOC = @cFromLOC
           AND LLI.ID = CASE WHEN ISNULL(@cFromID, '') <> '' THEN @cFromID ELSE LLI.ID END
           AND LLI.SKU = @cSKU
           AND LLI.QTY > 0
           AND LA.Lottable01 = @cLottable01
           AND LA.Lottable02 = @cLottable02
           AND LA.Lottable03 = @cLottable03
           AND LA.Lottable04 = @dLottable04
           AND LLI.LOT <> @cNewLOT

         OPEN CURSOR_RELOT
         FETCH NEXT FROM CURSOR_RELOT INTO @c_LOT, @c_LOC, @c_ID, @nLOTQty

         WHILE (@@FETCH_STATUS <> -1 AND @nReLOTQty > 0)
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
            IF @nMultiStorer = 0
            BEGIN
               
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
                  @c_Lottable06 = @c_Lottable06,
                  @c_Lottable07 = @c_Lottable07,
                  @c_Lottable08 = @c_Lottable08,
                  @c_Lottable09 = @c_Lottable09,
                  @c_Lottable10 = @c_Lottable10,
                  @c_Lottable11 = @c_Lottable11,
                  @c_Lottable12 = @c_Lottable12,
                  @d_Lottable13 = @d_Lottable13,
                  @d_Lottable14 = @d_Lottable14,
                  @d_Lottable15 = @d_Lottable15,
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
                  @c_SourceType = 'rdt_1804RcvCfm01',
                  @c_PackKey    = '',
                  @c_UOM        = '',
                  @b_UOMCalc    = 0,
                  @d_EffectiveDate = NULL,
                  @c_ItrnKey    = '',
                  @b_Success    = @b_Success OUTPUT,
                  @n_err        = @nErrNo    OUTPUT,
                  @c_errmsg     = @cErrMsg   OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 82924
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --WITHDRAW FAIL
                  GOTO RollBackTran
               END

               

               EXECUTE nspItrnAddDeposit
                  @n_ItrnSysId  = NULL,
                  @c_StorerKey  = @cStorerKey,
                  @c_Sku        = @cSKU,
                  @c_Lot        = @cNewLOT,--@cLOT,
                  @c_ToLoc      = @c_LOC,
                  @c_ToID       = @c_ID,
                  @c_Status     = '',
                  @c_lottable01 = @cLottable01,
                  @c_lottable02 = @cLottable02,
                  @c_lottable03 = @cLottable03,
                  @d_lottable04 = @dLottable04,
                  @d_lottable05 = @dLottable05,
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
                  @n_Qty        = @nLOTQty,
                  @n_pallet     = 0,
                  @f_cube       = 0,
                  @f_grosswgt   = 0,
                  @f_netwgt     = 0,
                  @f_otherunit1 = 0,
                  @f_otherunit2 = 0,
                  @c_SourceKey  = '',
                  @c_SourceType = 'rdt_1804RcvCfm01',
                  @c_PackKey    = '',
                  @c_UOM        = '',
                  @b_UOMCalc    = 0,
                  @d_EffectiveDate = NULL,
                  @c_ItrnKey    = '',
                  @b_Success    = @b_Success OUTPUT,
                  @n_err        = @nErrNo    OUTPUT,
                  @c_errmsg     = @cErrMsg   OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 82925
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --DEPOSIT FAIL
                  GOTO RollBackTran
               END

		
                
            END
            ELSE
            BEGIN
               EXECUTE nspItrnAddWithdrawal
                  @n_ItrnSysId  = NULL,
                  @c_StorerKey  = @cSKU_StorerKey,
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
                  @c_Lottable06 = @c_Lottable06,
                  @c_Lottable07 = @c_Lottable07,
                  @c_Lottable08 = @c_Lottable08,
                  @c_Lottable09 = @c_Lottable09,
                  @c_Lottable10 = @c_Lottable10,
                  @c_Lottable11 = @c_Lottable11,
                  @c_Lottable12 = @c_Lottable12,
                  @d_Lottable13 = @d_Lottable13,
                  @d_Lottable14 = @d_Lottable14,
                  @d_Lottable15 = @d_Lottable15,
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
                  @c_SourceType = 'rdtfnc_MoveToUCC',
                  @c_PackKey    = '',
                  @c_UOM        = '',
                  @b_UOMCalc    = 0,
                  @d_EffectiveDate = NULL,
                  @c_ItrnKey    = '',
                  @b_Success    = @b_Success OUTPUT,
                  @n_err        = @nErrNo    OUTPUT,
                  @c_errmsg     = @cErrMsg   OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 82926
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --WITHDRAW FAIL
                  GOTO RollBackTran
               END

               EXECUTE nspItrnAddDeposit
                  @n_ItrnSysId  = NULL,
                  @c_StorerKey  = @cSKU_StorerKey,
                  @c_Sku        = @cSKU,
                  @c_Lot        = @cNewLOT,
                  @c_ToLoc      = @c_LOC,
                  @c_ToID       = @c_ID,
                  @c_Status     = '',
                  @c_lottable01 = @cLottable01,
                  @c_lottable02 = @cLottable02,
                  @c_lottable03 = @cLottable03,
                  @d_lottable04 = @dLottable04,
                  @d_lottable05 = @dLottable05,
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
                  @n_Qty        = @nLOTQty,
                  @n_pallet     = 0,
                  @f_cube       = 0,
                  @f_grosswgt   = 0,
                  @f_netwgt     = 0,
                  @f_otherunit1 = 0,
                  @f_otherunit2 = 0,
                  @c_SourceKey  = '',
                  @c_SourceType = 'rdtfnc_MoveToUCC',
                  @c_PackKey    = '',
                  @c_UOM        = '',
                  @b_UOMCalc    = 0,
                  @d_EffectiveDate = NULL,
                  @c_ItrnKey    = '',
                  @b_Success    = @b_Success OUTPUT,
                  @n_err        = @nErrNo    OUTPUT,
                  @c_errmsg     = @cErrMsg   OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 82927
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --DEPOSIT FAIL
                  GOTO RollBackTran
               END
            END

            SET @nReLOTQty = @nReLOTQty - @nLOTQty

            FETCH NEXT FROM CURSOR_RELOT INTO @c_LOT, @c_LOC, @c_ID, @nLOTQty
         END -- END WHILE FOR CURSOR_RELOT
         CLOSE CURSOR_RELOT
         DEALLOCATE CURSOR_RELOT

         -- Move to LOC
         IF @nMultiStorer = 0
         BEGIN
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType = 'rdtfnc_MoveToUCC',
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cToLOC,
               @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
               @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
               @cSKU        = @cSKU,
               @nQTY        = @nQTY,
               @cFromLOT    = @cNewLot,        -- Chee02
               @nFunc       = @nFunc        -- SKIP CantMixSKU&UCC Checking
         END
         ELSE
         BEGIN
            -- For multi storer move by sku, only able to move sku from loc contain
            -- only 1 sku 1 storer because if 1 sku multi storer then move by sku
            -- don't know which storer's sku to move
            -- If contain SKU A (Storer 1), SKU A (Storer 2) then will be blocked @ decode label sp
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType = 'rdtfnc_MoveToUCC',
               @cStorerKey  = @cSKU_StorerKey,
               @cFacility   = @cFacility,
               @cFromLOC    = @cFromLOC,
               @cToLOC      = @cToLOC,
               @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
               @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
               @cSKU        = @cSKU,
               @nQTY        = @nQTY,
               @cFromLOT    = @cNewLot,        -- Chee02
               @nFunc       = @nFunc        -- SKIP CantMixSKU&UCC Checking
         END

         IF @nErrNo <> 0
         BEGIN
            -- Chee01
   --         SET @nErrNo = 82928
   --         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --RDTMOVE FAIL
            GOTO RollBackTran
         END
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
                @cUOM          = '',
                @nQTY          = @nQTY
         END
      
      END   
      
      GOTO Quit
      
   END


RollBackTran:
   ROLLBACK TRAN rdt_1804RcvCfm01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_1804RcvCfm01  
      
END

GO