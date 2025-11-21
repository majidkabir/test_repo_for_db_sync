SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_ReceiveReserval_UCCQtyAdjustment                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purposes:                                                            */
/* 1) Update UCC QTY and RECEIPTDETAIL QTY                              */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2022-09-22  1.0  James       WMS-20734 Add itrn adjustment (james01) */
/************************************************************************/

CREATE PROC [RDT].[rdt_ReceiveReserval_UCCQtyAdjustment] (
   @nMobile                INT,
   @nFunc                  INT,
   @cLangCode              NVARCHAR( 3),
   @nStep                  INT,
   @nInputKey              INT,
   @cFacility              NVARCHAR( 5),
   @cStorerkey             NVARCHAR( 15),
   @cReceiptKey            NVARCHAR( 10),
   @cLOC                   NVARCHAR( 10),
   @cID                    NVARCHAR( 18),
   @cUCC                   NVARCHAR( 20),
   @cQTY                   NVARCHAR( 4),
   @cNewQty                NVARCHAR( 4),
   @cReceiptLineNo         NVARCHAR( 5),
   @cType                  NVARCHAR( 10),
   @nErrNo                 INT      OUTPUT,
   @cErrMsg                NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_debug           INT   
   DECLARE @nIsFinalized      INT = 0
   DECLARE @nRowRef           INT
   DECLARE @nRcvQty           INT
   DECLARE @nQty              INT
   DECLARE @curUCC            CURSOR
   DECLARE @curRCV            CURSOR
   DECLARE @curDel            CURSOR
   DECLARE @cReceiptLineNumber      NVARCHAR(5)
   DECLARE @cChannelInventoryMgmt   NVARCHAR( 1) = ''
   DECLARE @cChannel                NVARCHAR( 20) = ''
   DECLARE @nChannel_ID             BIGINT = 0
   DECLARE @cUOM                    NVARCHAR( 10)
   DECLARE @dEffectiveDate    DATETIME
   DECLARE @cLot              NVARCHAR( 10)
   DECLARE @cSku              NVARCHAR( 20)
   DECLARE @cNewLot           NVARCHAR( 10)
   DECLARE @nUCC_RowRef       INT
   DECLARE @nIsAdjusted       INT = 0
   
   DECLARE
   @nNewQty             INT,
   @bdebug              INT,
   @nTranCount          INT,
   @cRDSKU              NVARCHAR( 20),
   @cItrnKey            NVARCHAR( 10),
   @cLot01              NVARCHAR( 30),
   @cLot02              NVARCHAR( 20),
   @cLot03              NVARCHAR( 20),
   @cLot04              NVARCHAR( 20),
   @cLot05              NVARCHAR( 20),
   @cLottableCode       NVARCHAR( 30),
   @nMorePage           INT,
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
   @cSourceKey          NVARCHAR( 20),
   @nCasecnt            INT,
   @nInnerpack          INT,
   @nPallet             INT,
   @fCube               FLOAT,
   @fGrossWgt           FLOAT,
   @fNetWgt             FLOAT,
   @fOtherUnit1         FLOAT,
   @fOtherUnit2         FLOAT,
   @cPackKey            NVARCHAR( 10),
   @bSuccess            INT,
   @nOpenQty            INT,
   @cPOKey              NVARCHAR( 10),
   @cPOLineNumber       NVARCHAR( 5),
   @cRD_SKU             NVARCHAR( 20),
   @nRD_QtyReceived     INT,
   @nPO_QtyReceived     INT,
   @nBeforeReceivedQty  INT,
   @cRDID               NVARCHAR( 18)  
   
   SET @nNewQty = CAST( @cNewQty AS INT)
   
   SELECT TOP 1 @cChannelInventoryMgmt = SC.Authority
   FROM dbo.RECEIPT R WITH (NOLOCK)
   CROSS APPLY fnc_SelectGetRight (R.facility, R.StorerKey, '', 'ChannelInventoryMgmt') SC
   WHERE r.ReceiptKey = @cReceiptKey

   SELECT @cUOM = DefaultUOM
   FROM RDT.rdtMobRec M WITH (NOLOCK)
   JOIN RDT.rdtUser U WITH (NOLOCK) ON ( M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND   ReceiptLineNumber = @cReceiptLineNo
               AND   FinalizeFlag = 'Y')
      SET @nIsFinalized = 1

   SET @dEffectiveDate = GETDATE()

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN UCCQtyAdjust -- For rollback or commit only our own transaction
   
   IF @cType = 'EDT'
   BEGIN
      IF @nIsFinalized = 1
      BEGIN
         SELECT 
            @cLot = LLI.LOT, 
            @cLOC = LLI.LOC,
            @cSku = LLI.SKU, 
            @cRDID = RD.ToId,
            @nRcvQty = ISNULL( SUM( IT.QTY), 0)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
         JOIN dbo.RECEIPTDETAIL RD(NOLOCK) ON LLI.loc=RD.toloc AND LLI.SKU=RD.SKU AND LLI.ID=RD.TOID AND LLI.storerkey=RD.storerkey
         JOIN dbo.itrn IT (NOLOCK) ON IT.SourceKey= rd.ReceiptKey+rd.ReceiptLineNumber AND lli.lot=IT.lot AND lli.id=IT.TOID AND lli.loc=IT.ToLoc
         WHERE LLI.StorerKey = @cStorerKey
         AND   LLI.LOC = CASE WHEN @cLOC = '' THEN LLI.LOC ELSE @cLOC END
         AND   LLI.ID = CASE WHEN @cID = '' THEN LLI.ID ELSE @cID END
         AND   RD.Receiptkey=@cReceiptkey
         AND   ReceiptLineNumber = @cReceiptLineNo
         AND   LOC.Facility = @cFacility
         GROUP BY LLI.LOT, LLI.LOC, LLI.SKU, RD.ToId
         HAVING ISNULL( SUM( LLI.Qty), 0) > 0

         IF @nRcvQty = 0 OR @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 191858
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Stock Found
            GOTO RollBackTran
         END
         
      	SET @nQty = 0 - @nRcvQty

      	SET @cSourceKey = @cReceiptkey + @cReceiptLineNo
      		
         SELECT
            @nCasecnt        = P.CaseCnt,
            @nInnerpack      = P.InnerPack,
            @nPallet         = P.Pallet,
            @fCube           = P.Cube,
            @fGrosswgt       = P.GrossWgt,
            @fNetwgt         = P.NetWgt,
            @fOtherunit1     = P.OtherUnit1,
            @fOtherunit2     = P.OtherUnit2,
            @cPackKey        = P.PackKey
         FROM dbo.SKU S WITH (NOLOCK)
         JOIN dbo.Pack P WITH (NOLOCK) ON ( S.PackKey = P.PackKey)
         WHERE S.StorerKey = @cStorerKey
         AND   S.SKU = @cSku

         SELECT
            @cLottable01     = Lottable01,
            @cLottable02     = Lottable02,
            @cLottable03     = Lottable03,
            @dLottable04     = Lottable04,
            @dLottable05     = Lottable05,
            @cLottable06     = Lottable06,
            @cLottable07     = Lottable07,
            @cLottable08     = Lottable08,
            @cLottable09     = Lottable09,
            @cLottable10     = Lottable10,
            @cLottable11     = Lottable11,
            @cLottable12     = Lottable12,
            @dLottable13     = Lottable13,
            @dLottable14     = Lottable14,
            @dLottable15     = Lottable15
         FROM dbo.LotAttribute WITH (NOLOCK)
         WHERE LOT = @cLot

         IF @@ROWCOUNT > 0
         BEGIN
      	   IF @cChannelInventoryMgmt = '1'
      	   BEGIN
      		   SELECT 
      		      @cChannel = Channel,
      		      @nChannel_ID = Channel_ID
      		   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      		   WHERE ReceiptKey = @cReceiptKey
               AND   ReceiptLineNumber = @cReceiptLineNo
      	   END
      	   
      	   -- Withdraw
            EXECUTE  nspItrnAddAdjustment
               @n_ItrnSysId  = NULL,
               @c_StorerKey  = @cStorerKey,
               @c_Sku        = @cSku,
               @c_Lot        = @cLot,
               @c_ToLoc      = @cLoc,
               @c_ToID       = @cRDID,
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
               @n_casecnt    = @nCasecnt,
               @n_innerpack  = @nInnerPack,
               @n_qty        = @nQty,
               @n_pallet     = @nPallet,
               @f_cube       = @fCube,
               @f_grosswgt   = @fGrossWgt,
               @f_netwgt     = @fNetWgt,
               @f_otherunit1 = @fOtherUnit1,
               @f_otherunit2 = @fOtherUnit2,
               @c_SourceKey  = @cSourceKey,
               @c_SourceType = 'rdt_ReceiptReversal_Confirm',
               @c_PackKey    = @cPackkey,
               @c_UOM        = @cUom,
               @b_UOMCalc    = 0,
               @d_EffectiveDate = @dEffectiveDate,
               @c_itrnkey    = @cItrnKey OUTPUT,
               @b_Success    = @bSuccess OUTPUT,
               @n_err        = @nErrNo   OUTPUT,
               @c_errmsg     = @cErrmsg  OUTPUT, 
               @c_Channel    = @cChannel, 
               @n_Channel_ID = @nChannel_ID OUTPUT

            IF @bSuccess <> 1
               GOTO RollBackTran

            EXECUTE dbo.nsp_LotGen
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
             , @cNewLOT  OUTPUT
             , @bSuccess OUTPUT
             , @nErrNo   OUTPUT
             , @cErrMsg  OUTPUT

            IF @bSuccess <> 1
               GOTO RollbackTran
            
            -- Deposit
            EXECUTE nspItrnAddDeposit
               @n_ItrnSysId  = NULL,
               @c_StorerKey  = @cStorerKey,
               @c_Sku        = @cSKU,
               @c_Lot        = @cNewLOT,
               @c_ToLoc      = @cLOC,
               @c_ToID       = @cRDID,
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
               @n_casecnt    = @nCasecnt,
               @n_innerpack  = 0,
               @n_Qty        = @nNewQty,
               @n_pallet     = @nInnerPack,
               @f_cube       = @fCube,
               @f_grosswgt   = @fGrossWgt,
               @f_netwgt     = @fNetWgt,
               @f_otherunit1 = @fOtherUnit1,
               @f_otherunit2 = @fOtherUnit2,
               @c_SourceKey  = @cSourceKey,
               @c_SourceType = 'rdt_ReceiptReversal_Confirm',
               @c_PackKey    = @cPackkey,
               @c_UOM        = @cUom,
               @b_UOMCalc    = 0,
               @d_EffectiveDate = @dEffectiveDate,
               @c_ItrnKey    = @cItrnKey  OUTPUT,
               @b_Success    = @bSuccess  OUTPUT,
               @n_err        = @nErrNo    OUTPUT,
               @c_errmsg     = @cErrMsg   OUTPUT, 
               @c_Channel    = @cChannel, 
               @n_Channel_ID = @nChannel_ID OUTPUT
            --EXECUTE  nspItrnAddAdjustment
            --   @n_ItrnSysId  = NULL,
            --   @c_StorerKey  = @cStorerKey,
            --   @c_Sku        = @cSku,
            --   @c_Lot        = @cLot,
            --   @c_ToLoc      = @cLoc,
            --   @c_ToID       = @cID,
            --   @c_Status     = '',
            --   @c_lottable01 = @cLottable01,
            --   @c_lottable02 = @cLottable02,
            --   @c_lottable03 = @cLottable03,
            --   @d_lottable04 = @dLottable04,
            --   @d_lottable05 = @dLottable05,
            --   @c_lottable06 = @cLottable06,
            --   @c_lottable07 = @cLottable07,
            --   @c_lottable08 = @cLottable08,
            --   @c_lottable09 = @cLottable09,
            --   @c_lottable10 = @cLottable10,
            --   @c_lottable11 = @cLottable11,
            --   @c_lottable12 = @cLottable12,
            --   @d_lottable13 = @dLottable13,
            --   @d_lottable14 = @dLottable14,
            --   @d_lottable15 = @dLottable15,
            --   @n_casecnt    = @nCasecnt,
            --   @n_innerpack  = @nInnerPack,
            --   @n_qty        = @nNewQty,
            --   @n_pallet     = @nPallet,
            --   @f_cube       = @fCube,
            --   @f_grosswgt   = @fGrossWgt,
            --   @f_netwgt     = @fNetWgt,
            --   @f_otherunit1 = @fOtherUnit1,
            --   @f_otherunit2 = @fOtherUnit2,
            --   @c_SourceKey  = @cSourceKey,
            --   @c_SourceType = 'rdt_ReceiptReversal_Confirm',
            --   @c_PackKey    = @cPackkey,
            --   @c_UOM        = @cUom,
            --   @b_UOMCalc    = 0,
            --   @d_EffectiveDate = @dEffectiveDate,
            --   @c_itrnkey    = @cItrnKey OUTPUT,
            --   @b_Success    = @bSuccess OUTPUT,
            --   @n_err        = @nErrNo   OUTPUT,
            --   @c_errmsg     = @cErrmsg  OUTPUT, 
            --   @c_Channel    = @cChannel, 
            --   @n_Channel_ID = @nChannel_ID OUTPUT

            IF @bSuccess <> 1
               GOTO RollBackTran
         END
      END

      UPDATE dbo.UCC WITH (ROWLOCK) SET
         QTY = CAST(@cNewQty AS INT),
         Lot = @cNewLot
      WHERE Storerkey = @cStorerkey 
         AND  ReceiptKey = @cReceiptKey 
         AND  ReceiptLineNumber = @cReceiptLineNo 
         AND  UCCNo = @cUCC 
         AND  Status = '1'

      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 191851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd UCCQty Err
         GOTO RollBackTran
      END

      UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK) SET 
         BeforeReceivedQty = (BeforeReceivedQty - CAST(@cQTY AS INT)) + CAST(@cNewQty AS INT),
         QtyReceived = CASE WHEN @nIsFinalized = 1 
                       THEN (QtyReceived - CAST(@cQTY AS INT)) + CAST(@cNewQty AS INT) 
                       ELSE QtyReceived END,
         Trafficcop = NULL
      WHERE Storerkey = @cStorerkey 
         AND  ReceiptKey = @cReceiptKey 
         AND  ReceiptLineNumber = @cReceiptLineNo 

      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 191852
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RCVQty Err
         GOTO RollBackTran
      END
   
      IF EXISTS ( SELECT 1 FROM RDT.RdtPreReceiveSort WITH (NOLOCK)
                  WHERE StorerKey = @cStorerkey
                  AND   ReceiptKey = @cReceiptKey
                  AND   UCCNo = @cUCC)
      BEGIN
         SET @curDel = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef
         FROM RDT.RdtPreReceiveSort WITH (NOLOCK)
         WHERE StorerKey = @cStorerkey
         AND   ReceiptKey = @cReceiptKey
         AND   UCCNo = @cUCC
         ORDER BY 1
         OPEN @curDel
         FETCH NEXT FROM @curDel INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
      	   UPDATE RDT.RdtPreReceiveSort SET
      	      QTY = CAST(@cNewQty AS INT)
      	   WHERE Rowref = @nRowRef
      	
      	   IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 191853
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd LogQty Err
               GOTO RollBackTran
            END
      	   FETCH NEXT FROM @curDel INTO @nRowRef
         END
    
      END
   END
   ELSE
   BEGIN
 	   SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
 	   SELECT UCC_RowRef, ReceiptLineNumber
 	   FROM dbo.UCC WITH (NOLOCK)
 	   WHERE Storerkey = @cStorerkey
 	   AND   UCCNo = @cUCC
 	   OPEN @curUCC
 	   FETCH NEXT FROM @curUCC INTO @nUCC_RowRef, @cReceiptLineNumber
 	   WHILE @@FETCH_STATUS = 0
 	   BEGIN
         IF @nIsFinalized = 1
         BEGIN
         	SET @nIsAdjusted = 0
            SET @curRCV = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT LLI.LOT, LLI.LOC, LLI.SKU, RD.ToId, ISNULL( SUM( IT.QTY), 0) 
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
            JOIN dbo.RECEIPTDETAIL RD(NOLOCK) ON LLI.loc=RD.toloc AND LLI.SKU=RD.SKU AND LLI.ID=RD.TOID AND LLI.storerkey=RD.storerkey --(yeekung01)
            JOIN dbo.itrn IT (NOLOCK) ON IT.SourceKey= rd.ReceiptKey+rd.ReceiptLineNumber AND lli.lot=IT.lot AND lli.id=IT.TOID AND lli.loc=IT.ToLoc
            WHERE LLI.StorerKey = @cStorerKey
            AND   LLI.LOC = CASE WHEN @cLOC = '' THEN LLI.LOC ELSE @cLOC END
            AND   LLI.ID = CASE WHEN @cID = '' THEN LLI.ID ELSE @cID END
            AND   RD.Receiptkey=@cReceiptkey
            AND   RD.ReceiptLineNumber = @cReceiptLineNumber
            AND   LOC.Facility = @cFacility
            GROUP BY LLI.LOT, LLI.LOC, LLI.SKU, RD.ToId
            HAVING ISNULL( SUM( LLI.Qty), 0) > 0
            OPEN @curRCV
            FETCH NEXT FROM @curRCV INTO @cLot, @cLoc, @cSku, @cRDID, @nQty
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF @nRcvQty = 0 
               BEGIN
                  SET @nErrNo = 191859
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Stock Found
                  GOTO RollBackTran
               END
               
               SET @nQty = 0 - @nQty   -- deduct qty from pallet
               SET @dEffectiveDate = GETDATE()
               SET @cSourceKey = @cReceiptKey + @cReceiptLineNumber
               
               -- checked 0 alloc & picked during intial stage
               SELECT
                  @nCasecnt        = P.CaseCnt,
                  @nInnerpack      = P.InnerPack,
                  @nPallet         = P.Pallet,
                  @fCube           = P.Cube,
                  @fGrosswgt       = P.GrossWgt,
                  @fNetwgt         = P.NetWgt,
                  @fOtherunit1     = P.OtherUnit1,
                  @fOtherunit2     = P.OtherUnit2,
                  @cPackKey        = P.PackKey
               FROM dbo.SKU S WITH (NOLOCK)
               JOIN dbo.Pack P WITH (NOLOCK) ON ( S.PackKey = P.PackKey)
               WHERE S.StorerKey = @cStorerKey
               AND   S.SKU = @cSku

               SELECT
                  @cLottable01     = Lottable01,
                  @cLottable02     = Lottable02,
                  @cLottable03     = Lottable03,
                  @dLottable04     = Lottable04,
                  @dLottable05     = Lottable05,
                  @cLottable06     = Lottable06,
                  @cLottable07     = Lottable07,
                  @cLottable08     = Lottable08,
                  @cLottable09     = Lottable09,
                  @cLottable10     = Lottable10,
                  @cLottable11     = Lottable11,
                  @cLottable12     = Lottable12,
                  @dLottable13     = Lottable13,
                  @dLottable14     = Lottable14,
                  @dLottable15     = Lottable15
               FROM dbo.LotAttribute WITH (NOLOCK)
               WHERE LOT = @cLot

               IF @@ROWCOUNT > 0
               BEGIN
      	         IF @cChannelInventoryMgmt = '1'
      	         BEGIN
      		         SELECT 
      		            @cChannel = Channel,
      		            @nChannel_ID = Channel_ID
      		         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      		         WHERE ReceiptKey = @cReceiptKey
      		         AND   ReceiptLineNumber = @cReceiptLineNumber
      	         END
      	
                  EXECUTE  nspItrnAddAdjustment
                           @n_ItrnSysId  = NULL,
                           @c_StorerKey  = @cStorerKey,
                           @c_Sku        = @cSku,
                           @c_Lot        = @cLot,
                           @c_ToLoc      = @cLoc,
                           @c_ToID       = @cRDID,
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
                           @n_casecnt    = @nCasecnt,
                           @n_innerpack  = @nInnerPack,
                           @n_qty        = @nQty,
                           @n_pallet     = @nPallet,
                           @f_cube       = @fCube,
                           @f_grosswgt   = @fGrossWgt,
                           @f_netwgt     = @fNetWgt,
                           @f_otherunit1 = @fOtherUnit1,
                           @f_otherunit2 = @fOtherUnit2,
                           @c_SourceKey  = @cSourceKey,
                           @c_SourceType = 'rdt_ReceiptReversal_Confirm',
                           @c_PackKey    = @cPackkey,
                           @c_UOM        = @cUom,
                           @b_UOMCalc    = 0,
                           @d_EffectiveDate = @dEffectiveDate,
                           @c_itrnkey    = @cItrnKey OUTPUT,
                           @b_Success    = @bSuccess OUTPUT,
                           @n_err        = @nErrNo   OUTPUT,
                           @c_errmsg     = @cErrmsg  OUTPUT, 
                           @c_Channel    = @cChannel, 
                           @n_Channel_ID = @nChannel_ID OUTPUT

                     IF @bSuccess <> 1
                        GOTO Quit
                     
                     SET @nIsAdjusted = 1
               END

               FETCH NEXT FROM @curRCV INTO @cLot, @cLoc, @cSku, @cRDID, @nQty
            END

            IF @nIsAdjusted = 0 
            BEGIN
               SET @nErrNo = 191860
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Stock Found
               GOTO RollBackTran
            END
               
            UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET
               BeforeReceivedQty = 0,
               QtyReceived = 0,
               QtyAdjusted = 0,
               FinalizeFlag = 'N',
               ToId = '',   -- Prepare for the next receiving for the same line but with a different ID.
               Trafficcop = NULL
            WHERE ReceiptKey = @cReceiptKey
            AND   ReceiptLineNumber = @cReceiptLineNumber

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 191854
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Rev Rcvdt fail
               GOTO RollBackTran
            END
         END
         
         UPDATE dbo.UCC SET 
            STATUS = '0',
            Lot = '',
            Loc = '',
            ID = '',
            Receiptkey = '',
            ReceiptLineNumber = '',
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE UCC_RowRef = @nUCC_RowRef

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 191855
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Del UCC fail
            GOTO RollBackTran
         END

 	   	FETCH NEXT FROM @curUCC INTO @nUCC_RowRef, @cReceiptLineNumber
 	   END

      IF EXISTS ( SELECT 1 FROM RDT.RdtPreReceiveSort WITH (NOLOCK)
                  WHERE StorerKey = @cStorerkey
                  AND   ReceiptKey = @cReceiptKey
                  AND   UCCNo = @cUCC)
      BEGIN
         SET @curDel = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef
         FROM RDT.RdtPreReceiveSort WITH (NOLOCK)
         WHERE StorerKey = @cStorerkey
         AND   ReceiptKey = @cReceiptKey
         AND   UCCNo = @cUCC
         ORDER BY 1
         OPEN @curDel
         FETCH NEXT FROM @curDel INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
      	   DELETE FROM RDT.RdtPreReceiveSort 
      	   WHERE Rowref = @nRowRef
      	
      	   IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 191856
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del Log Err
               GOTO RollBackTran
            END
      	   FETCH NEXT FROM @curDel INTO @nRowRef
         END
    
      END
   END

   -- Recalculate open qty  
   SELECT @nOpenQty = ISNULL( SUM( QtyExpected - QtyReceived) , 0)  
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
   WHERE ReceiptKey = @cReceiptKey  
  
   UPDATE dbo.Receipt WITH (ROWLOCK) SET  
      OpenQty = @nOpenQty,  
      Status = '0',  
      ASNStatus = '0',  
      Trafficcop = NULL  
   WHERE ReceiptKey = @cReceiptKey  

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 191857
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd OpenQty Err
      GOTO RollBackTran
   END
               
   COMMIT TRAN UCCQtyAdjust
      GOTO Quit

   RollBackTran:
      ROLLBACK TRAN UCCQtyAdjust -- Only rollback change made here
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
   END



GO