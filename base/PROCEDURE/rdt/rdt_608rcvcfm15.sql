SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/***************************************************************************/
/* Store procedure: rdt_608RcvCfm15                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Stamp serialno as EPC Barcode                                  */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2023-06-01 1.0  yeekung   WMS-22630 Created                             */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_608RcvCfm15](
    @nFunc          INT,
    @nMobile        INT,
    @cLangCode      NVARCHAR( 3),
    @cStorerKey     NVARCHAR( 15),
    @cFacility      NVARCHAR( 5),
    @cReceiptKey    NVARCHAR( 10),
    @cPOKey         NVARCHAR( 10),
    @cToLOC         NVARCHAR( 10),
    @cToID          NVARCHAR( 18),
    @cSKUCode       NVARCHAR( 20),
    @cSKUUOM        NVARCHAR( 10),
    @nSKUQTY        INT,
    @cUCC           NVARCHAR( 20),
    @cUCCSKU        NVARCHAR( 20),
    @nUCCQTY        INT,
    @cCreateUCC     NVARCHAR( 1),
    @cLottable01    NVARCHAR( 18),
    @cLottable02    NVARCHAR( 18),
    @cLottable03    NVARCHAR( 18),
    @dLottable04    DATETIME,
    @dLottable05    DATETIME,
    @cLottable06    NVARCHAR( 30),
    @cLottable07    NVARCHAR( 30),
    @cLottable08    NVARCHAR( 30),
    @cLottable09    NVARCHAR( 30),
    @cLottable10    NVARCHAR( 30),
    @cLottable11    NVARCHAR( 30),
    @cLottable12    NVARCHAR( 30),
    @dLottable13    DATETIME,
    @dLottable14    DATETIME,
    @dLottable15    DATETIME,
    @nNOPOFlag      INT,
    @cConditionCode NVARCHAR( 10),
    @cSubreasonCode NVARCHAR( 10),
    @cRDLineNo      NVARCHAR( 5)  OUTPUT,
    @nErrNo         INT           OUTPUT,
    @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Handling transaction
   DECLARE @nTranCount        INT
   DECLARE @cSerialNo         NVARCHAR( 30)
   DECLARE @nSerialQTY        INT
   DECLARE @nBulkSNO          INT = 0
   DECLARE @nBulkSNOQTY       INT = 0

   -- This storer not all sku has serial no to scan, even same sku some does not have serialno
   -- So need to turn off serialnocapture and manually insert here
   SELECT @cSerialNo = I_Field03
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   IF LEN(@cSerialNo) <>24
   BEGIN
      SET @cSerialNo =''
      SET @nSerialQTY = 0
   END
   ELSE
   BEGIN
      SET @nSerialQTY = @nSKUQTY
   END

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_608RcvCfm15 -- For rollback or commit only our own transaction

   -- Receive
   EXEC rdt.rdt_Receive_V7
      @nFunc         = @nFunc,
      @nMobile       = @nMobile,
      @cLangCode     = @cLangCode,
      @nErrNo        = @nErrNo OUTPUT,
      @cErrMsg       = @cErrMsg OUTPUT,
      @cStorerKey    = @cStorerKey,
      @cFacility     = @cFacility,
      @cReceiptKey   = @cReceiptKey,
      @cPOKey        = @cPOKey,
      @cToLOC        = @cToLOC,
      @cToID         = @cToID,
      @cSKUCode      = @cSKUCode,
      @cSKUUOM       = @cSKUUOM,
      @nSKUQTY       = @nSKUQTY,
      @cUCC          = '',
      @cUCCSKU       = '',
      @nUCCQTY       = '',
      @cCreateUCC    = '',
      @cLottable01   = @cLottable01,
      @cLottable02   = @cLottable02,
      @cLottable03   = @cLottable03,
      @dLottable04   = @dLottable04,
      @dLottable05   = NULL,
      @cLottable06   = @cLottable06,
      @cLottable07   = @cLottable07,
      @cLottable08   = @cLottable08,
      @cLottable09   = @cLottable09,
      @cLottable10   = @cLottable10,
      @cLottable11   = @cLottable11,
      @cLottable12   = @cLottable12,
      @dLottable13   = @dLottable13,
      @dLottable14   = @dLottable14,
      @dLottable15   = @dLottable15,
      @nNOPOFlag     = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = '',
      @cReceiptLineNumberOutput = @cRDLineNo OUTPUT,
      @cSerialNo      = @cSerialNo,
      @nSerialQTY     = @nSerialQTY

   IF @nErrNo <> 0
      GOTO RollBackTran

   DECLARE  @cRDLineNumber  NVARCHAR( 5),
            @bSuccess       INT

   -- Check variance
   IF NOT EXISTS( SELECT 1 
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      HAVING  SUM(QTYExpected) <> SUM(BeforeReceivedQTY))
   BEGIN
      -- Finalize ASN by line if no more variance
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT ReceiptLineNumber 
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   FinalizeFlag <> 'Y'
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @cRDLineNumber
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @bSuccess = 0
         EXEC dbo.ispFinalizeReceipt
               @c_ReceiptKey        = @cReceiptKey
            ,@b_Success           = @bSuccess   OUTPUT
            ,@n_err               = @nErrNo     OUTPUT
            ,@c_ErrMsg            = @cErrMsg    OUTPUT
            ,@c_ReceiptLineNumber = @cRDLineNumber

         IF @nErrNo <> 0 OR @bSuccess = 0
         BEGIN
            -- Direct retrieve err msg from stored proc as some exceed stored prod
            -- do not have standard error no & msg
            IF ISNULL( @cErrMsg, '') = '' -- (james01)
               SET @cErrMsg = CAST( @nErrNo AS NVARCHAR( 6)) + rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            GOTO RollBackTran
         END

         FETCH NEXT FROM CUR_UPD INTO @cRDLineNumber
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_608RcvCfm15
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN


END

GO