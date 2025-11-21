SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_UCCReceiveAudit_Adj                                   */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date         Rev  Author      Purposes                                     */
/* 10-Dec-2019  1.0  Chermaine   WMS-11357 - Created                          */
/******************************************************************************/

CREATE PROC [RDT].[rdt_UCCReceiveAudit_Adj] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3),
   @cUserName     NVARCHAR( 15), 
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 20),
   @cUCCNo        NVARCHAR( 20),
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max 
)
AS
BEGIN
SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE 
@cSKUCode         NVARCHAR( 15)
,@nQty            INT
,@cAdjustmentKey  NVARCHAR( 10)
,@cAdjDetailLine	NVARCHAR( 5)
,@cLoc            NVARCHAR( 10)
,@cLot            NVARCHAR( 10)
,@cPackKey        NVARCHAR( 10)
,@cUOM            NVARCHAR( 10)

,@cLottable01     NVARCHAR(18)
,@cLottable02     NVARCHAR(18)
,@cLottable03     NVARCHAR(18)
,@dLottable04     DATETIME
,@dLottable05     DATETIME
,@cLottable06     NVARCHAR(30)
,@cLottable07     NVARCHAR(30)
,@cLottable08     NVARCHAR(30)
,@cLottable09     NVARCHAR(30)
,@cLottable10     NVARCHAR(30)
,@cLottable11     NVARCHAR(30)
,@cLottable12     NVARCHAR(30)

,@b_success       INT
,@n_err				INT
,@c_errmsg			NVARCHAR( 250)

-- Handling transaction  
DECLARE @nTranCount INT  
SET @nTranCount = @@TRANCOUNT  
BEGIN TRAN  -- Begin our own transaction  
SAVE TRAN rdt_UCCReceiveAudit_Adj -- For rollback or commit only our own transaction
   
DECLARE @curSKU CURSOR
SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT SKU, CQty-ISNULL(PQty,0)
FROM rdt.RDTReceiveAudit WITH (NOLOCK)
WHERE StorerKey = @cStorerKey
   AND UCCNo = @cUCCNo
   AND receiptKey = @cReceiptKey
   AND CQty <> ISNULL(PQty,0)
   
OPEN @curSKU
   FETCH NEXT FROM @curSKU INTO @cSKUCode,@nQty
   WHILE @@FETCH_STATUS = 0 
   BEGIN        
      SELECT 
         @cLoc = i.ToLoc
         ,@cLot = i.Lot
      FROM RECEIPTdetail rd (NOLOCK)
      JOIN Itrn i (NOLOCK)
      ON i.StorerKey = rd.StorerKey
         AND i.sku = rd.sku
         AND i.sourceKey = rd.receiptKey + receiptLineNumber
      WHERE ReceiptKey = @cReceiptKey
         AND i.Sku = @cSKUCode  
         AND userdefine01 = @cUCCNo
         
      SELECT @cPackKey = packKey
      FROM dbo.SKU (nolock)  
      WHERE StorerKey = @cStorerKey
         AND Sku = @cSKUCode
         
      SELECT @cUOM = packuom3
      FROM PACK (NOLOCK) 
      WHERE packkey = @cPackKey
      
      SELECT @cLottable01 = Lottable01, @cLottable02 = Lottable02, @cLottable03 = Lottable03, @dLottable04 = Lottable04, @dLottable05 = Lottable05,
      @cLottable06 = Lottable06, @cLottable07 = Lottable07, @cLottable08 = Lottable08, @cLottable09 = Lottable09, @cLottable10 = Lottable10,
      @cLottable11 = Lottable11, @cLottable12 = Lottable12
      FROM LOTATTRIBUTE (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND Sku = @cSKUCode 
      AND lot = @cLot
      
      SELECT @cAdjustmentKey = AdjustmentKey
      FROM adjustment (NOLOCK) 
      WHERE adjustmentType = 'SDC'
         AND storerKey = @cStorerKey
         AND userdefine01 = @cReceiptKey
      
      --Ins Adjustment
      IF ISNULL(RTRIM(@cAdjustmentKey),'') = ''
      BEGIN
      	--insert   
         SET @b_success = 0
			EXECUTE dbo.nspg_getkey
				'Adjustment'
				, 10
				, @cAdjustmentKey OUTPUT
				, @b_success OUTPUT
				, @n_err OUTPUT
				, @c_errmsg OUTPUT
			IF @b_success <> 1
			BEGIN
            SET @nErrNo = 147069
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetADJKeyFail
            GOTO RollbackTran 
	      END
			ELSE 
			BEGIN           
            -- Insert new adjustment header
				INSERT dbo.ADJUSTMENT (AdjustmentKey, StorerKey, Facility, AdjustmentType, userDefine01)
				VALUES (@cAdjustmentKey, @cStorerKey, @cFacility, 'SDC', @cReceiptKey)

				SELECT @n_err = @@error
				IF @n_err > 0
				BEGIN
               SET @nErrNo = 147070
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ADJ Fail
               GOTO RollbackTran 
				END
			END       	
      END
      
      SET @cAdjDetailLine =''
      SELECT @cAdjDetailLine = AdjustmentLineNumber
      FROM adjustmentDetail (NOLOCK) 
      WHERE AdjustmentKey = @cAdjustmentKey
         AND storerKey = @cStorerKey
         AND userdefine01 = @cUCCNo
         AND sku = @cSKUCode
                 
      --Ins/Upd AdjustmentDetail  
      IF ISNULL(RTRIM(@cAdjDetailLine),'') = ''
      BEGIN
      	SELECT @cAdjDetailLine = RIGHT('0000' + RTRIM(Cast( (ISNULL(MAX(AdjustmentLineNumber),0) + 1) as NVARCHAR(5))),5)
         FROM  dbo.AdjustmentDetail (NOLOCK)
         WHERE AdjustmentKey = @cAdjustmentKey
                  
			INSERT INTO dbo.AdjustmentDetail (AdjustmentKey, AdjustmentLineNumber, StorerKey, SKU, LOC, LOT, UOM, PackKey, Qty, userdefine01,
                     Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12)
         VALUES (@cAdjustmentKey, @cAdjDetailLine, @cStorerKey, @cSKUCode, @cLOC, @cLOT, @cUOM, @cPackKey, @nQty, @cUCCNo,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, @cLottable11, @cLottable12)
         
         SET @n_err = @@error
		   IF @n_err <> 0
		   BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 147071
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ADJDT Fail
            GOTO RollbackTran
   	   END  
      END
      ELSE
      BEGIN
         UPDATE dbo.AdjustmentDetail WITH (ROWLOCK)
         SET QTY = @nQty
         WHERE AdjustmentKey = @cAdjustmentKey
            AND AdjustmentLineNumber = @cAdjDetailLine
            AND storerKey = @cStorerKey
            AND SKU = @cSKUCode

         SET @n_err = @@error
         IF @n_err <> 0
         BEGIN
            SET @nErrNo = 147072
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD ADJDT Fail
            GOTO RollbackTran
         END    
      END
	FETCH NEXT FROM @curSKU INTO @cSKUCode,@nQty
   END
   
COMMIT TRAN rdt_UCCReceiveAudit_Adj -- Only commit change made here  
GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_UCCReceiveAudit_Adj -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO