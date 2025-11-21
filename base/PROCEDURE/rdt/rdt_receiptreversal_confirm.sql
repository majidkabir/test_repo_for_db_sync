SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_ReceiptReversal_Confirm                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Confirm receipt reversal                                    */
/*          Option 1 = reverse by whole pallet                          */
/*                 2 = reverse by sku                                   */
/*                                                                      */
/* Called from: rdtfnc_Receipt_Reversal                                 */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 28-Jul-2015 1.0  James       SOS338503 - Created                     */
/* 30-Jun-2016 1.1  Leong       IN00075246 - Initialize variable.       */
/* 21-Aug-2017 1.2  James       WMS2702 - Include PODetail (james01)    */
/* 19-May-2021 1.3  James       WMS-19674 Add channel mgmt (james02)    */
/* 19-Jul-2022 1.4  YeeKung     JSM-81095 Join RDetail (yeekung01)      */
/************************************************************************/

CREATE     PROC [RDT].[rdt_ReceiptReversal_Confirm] (
   @nMobile                INT,
   @nFunc                  INT,
   @cLangCode              NVARCHAR( 3),
   @nScn                   INT,
   @nInputKey              INT,
   @cStorerKey             NVARCHAR( 15),
   @cReceiptKey            NVARCHAR( 10),
   @cFacility              NVARCHAR( 5),
   @cID                    NVARCHAR( 18),
   @cSKU                   NVARCHAR( 20),
   @cLottable1Value        NVARCHAR( 20),
   @cLottable2Value        NVARCHAR( 20),
   @cLottable3Value        NVARCHAR( 20),
   @cLottable4Value        NVARCHAR( 20),
   @cLottable5Value        NVARCHAR( 20),
   @cOption                NVARCHAR( 1),
   @nQty                   INT,
   @nErrNo                 INT                OUTPUT,
   @cErrMsg                NVARCHAR( 20)      OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
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
   @cReceiptLineNumber  NVARCHAR( 5),
   @cLot                NVARCHAR( 10),
   @cSourceKey          NVARCHAR( 20),
   @cLoc                NVARCHAR( 10),
   @nCasecnt            INT,
   @nInnerpack          INT,
   @nPallet             INT,
   @fCube               FLOAT,
   @fGrossWgt           FLOAT,
   @fNetWgt             FLOAT,
   @fOtherUnit1         FLOAT,
   @fOtherUnit2         FLOAT,
   @cPackKey            NVARCHAR( 10),
   @cUOM                NVARCHAR( 10),
   @dEffectiveDate      DATETIME,
   @bSuccess            INT,
   @nOpenQty            INT,
   @cPOKey              NVARCHAR( 10), -- (james01)
   @cPOLineNumber       NVARCHAR( 5),  -- (james01)
   @cRD_SKU             NVARCHAR( 20), -- (james01)
   @nRD_QtyReceived     INT,           -- (james01)
   @nPO_QtyReceived     INT,           -- (james01)
   @nBeforeReceivedQty  INT,           -- (james01)
   @cChannelInventoryMgmt  NVARCHAR( 1) = '',
   @cChannel            NVARCHAR( 20) = '',
   @nChannel_ID         BIGINT = 0
   
   SELECT TOP 1 @cChannelInventoryMgmt = SC.Authority
   FROM dbo.RECEIPT R WITH (NOLOCK)
   CROSS APPLY fnc_SelectGetRight (R.facility, R.StorerKey, '', 'ChannelInventoryMgmt') SC
   WHERE r.ReceiptKey = @cReceiptKey
         
   set @bdebug = 0

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_ReceiptReversal_Confirm

   SELECT @cUOM = DefaultUOM
   FROM RDT.rdtMobRec M WITH (NOLOCK)
   JOIN RDT.rdtUser U WITH (NOLOCK) ON ( M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   IF ISNULL( @cOption, '') NOT IN ('1', '2')
   BEGIN
      SET @nErrNo = 55851
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Opt
      GOTO RollBackTran
   END

   IF ISNULL( @cID, '') = ''
   BEGIN
      SET @nErrNo = 55852
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ID
      GOTO RollBackTran
   END

   IF @cOption = '2' AND ISNULL( @cSKU, '') = ''
   BEGIN
      SET @nErrNo = 55853
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Sku
      GOTO RollBackTran
   END

   -- Final check. Make sure this ASN not yet have transmitlog3
   -- No need check transmitflag, maybe the record will be interfaced anytime
   IF EXISTS ( SELECT 1 FROM dbo.TransmitLog3 WITH (NOLOCK)
               WHERE Key3 = @cStorerKey
               AND   Key1 = @cReceiptKey
               AND   TableName = 'RCPTLOG')
   BEGIN
      SET @nErrNo = 55854
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Tl3 exists
      GOTO RollBackTran
   END

   -- Reverse whole pallet
   IF @cOption = '1'
      SET @cSKU = ''

   DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT LLI.LOT, LLI.LOC, LLI.SKU,  ISNULL( SUM( IT.QTY), 0) --(yeekung01)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
   JOIN dbo.RECEIPTDETAIL RD(NOLOCK) ON LLI.loc=RD.toloc AND LLI.SKU=RD.SKU AND LLI.ID=RD.TOID AND LLI.storerkey=RD.storerkey --(yeekung01)
   JOIN dbo.itrn IT (NOLOCK) ON IT.SourceKey= rd.ReceiptKey+rd.ReceiptLineNumber AND lli.lot=IT.lot AND lli.id=IT.TOID AND lli.loc=IT.ToLoc
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.ID = @cID
   AND   RD.Receiptkey=@cReceiptkey
   AND   LLI.SKU = CASE WHEN @cSKU = '' THEN LLI.SKU ELSE @cSKU END
   AND   LOC.Facility = @cFacility
   GROUP BY LLI.LOT, LLI.LOC, LLI.SKU
   HAVING ISNULL( SUM( LLI.Qty), 0) > 0

   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @cLot, @cLoc, @cSku, @nQty
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @nQty = 0 - @nQty   -- deduct qty from pallet
      SET @dEffectiveDate = GETDATE()

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
      		SELECT TOP 1
      		   @cChannel = Channel,
      		   @nChannel_ID = Channel_ID
      		FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      		WHERE ReceiptKey = @cReceiptKey
            AND   ToID = @cID
            AND   SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END
            AND   ( BeforeReceivedQty > 0 OR QtyReceived > 0)
      		ORDER BY 1
      	END
      	
         EXECUTE  nspItrnAddAdjustment
                  @n_ItrnSysId  = NULL,
                  @c_StorerKey  = @cStorerKey,
                  @c_Sku        = @cSku,
                  @c_Lot        = @cLot,
                  @c_ToLoc      = @cLoc,
                  @c_ToID       = @cID,
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
                  @c_SourceKey  = '',
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

         IF @bdebug = 1
            SELECT '@cLot', @cLot, '@cLoc', @cLoc, '@cID', @cID, '@cSku', @cSku
      END

      FETCH NEXT FROM CUR_LOOP INTO @cLot, @cLoc, @cSku, @nQty
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   -- Reverse whole pallet
   IF @cOption = '1'
   BEGIN
      SET @cSKU = ''--IN00075246
   END

   DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT ReceiptLineNumber, QtyReceived, POKey, SKU FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   ToID = @cID
   AND   SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END
   AND   ( BeforeReceivedQty > 0 OR QtyReceived > 0)
   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @cReceiptLineNumber, @nRD_QtyReceived, @cPOKey, @cRD_SKU
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET
         BeforeReceivedQty = 0,
         QtyReceived = 0,
         QtyAdjusted = 0,
         FinalizeFlag = 'N',
         Trafficcop = NULL
      WHERE ReceiptKey = @cReceiptKey
      AND   ReceiptLineNumber = @cReceiptLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 55855
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Rev Rcvdt fail
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP
         GOTO RollBackTran
      END

      IF ISNULL( @cPOKey, '') <> '' AND  ISNULL( @cRD_SKU, '') <> '' AND @nRD_QtyReceived > 0
      BEGIN
         SELECT @cPOLineNumber = POLineNumber
         FROM dbo.PODetail WITH (NOLOCK) 
         WHERE PoKey = @cPOKey
         AND   SKU = @cRD_SKU

         IF @@ROWCOUNT > 0
         BEGIN
            UPDATE dbo.PODetail WITH (ROWLOCK) SET 
               QtyReceived = CASE WHEN ( QtyReceived - @nRD_QtyReceived) <=0 THEN 0 
                             ELSE ( QtyReceived - @nRD_QtyReceived) END
            WHERE PoKey = @cPOKey
            AND   POLineNumber = @cPOLineNumber

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 55857
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Rev PODTL fail
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               GOTO RollBackTran
            END
         END
      END

      FETCH NEXT FROM CUR_LOOP INTO @cReceiptLineNumber, @nRD_QtyReceived, @cPOKey, @cRD_SKU
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

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
      SET @nErrNo = 55856
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Rev Rcvhd fail
      GOTO RollBackTran
   END

   IF @bdebug = 1
      GOTO RollBackTran

   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_ReceiptReversal_Confirm
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN
END

GO