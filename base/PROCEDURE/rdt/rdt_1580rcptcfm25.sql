SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm25                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2021-01-05 1.0  YeeKung WMS-15666. Created                              */
/***************************************************************************/
CREATE PROC [RDT].[rdt_1580RcptCfm25](
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
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
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT, 
   @cSerialNo      NVARCHAR( 30) = '', 
   @nSerialQTY     INT = 0, 
   @nBulkSNO       INT = 0,
   @nBulkSNOQTY    INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cBarcode    NVARCHAR( 60)
   DECLARE @cSeason     NVARCHAR( 2)  
   DECLARE @cLOT        NVARCHAR( 12)  
   DECLARE @cCOO        NVARCHAR( 2)  
   DECLARE @cDocType    NVARCHAR( 1)  
   DECLARE @cLottable06 NVARCHAR( 30)    
   DECLARE @cLottable07 NVARCHAR( 30)    
   DECLARE @cLottable08 NVARCHAR( 30)    
   DECLARE @cLottable09 NVARCHAR( 30)    
   DECLARE @cLottable10 NVARCHAR( 30)    
   DECLARE @cLottable11 NVARCHAR( 30)    
   DECLARE @cLottable12 NVARCHAR( 30)    
   DECLARE @dLottable13 DATETIME         
   DECLARE @dLottable14 DATETIME         
   DECLARE @dLottable15 DATETIME
   DECLARE @bSuccess    INT
   DECLARE @nTranCount  INT 

   SET @nTranCount = @@TRANCOUNT

   SELECT TOP 1 @cLottable06 = Lottable06,
                @cLottable03=lottable03
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   Lottable01 = @cLottable01  
   AND   lottable02 = @clottable02
   AND SKU=@cSKUCode

   BEGIN TRAN    
   SAVE TRAN rdt_1580RcptCfm25  

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
      @dLottable05   = @dLottable05,  
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
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT  

   
   IF @nErrNo <> 0
      GOTO ROLLBACKTRAN

   ---- Auto finalize upon receive
   --DECLARE @cFinalizeRD NVARCHAR(1)
   --SET @cFinalizeRD = rdt.RDTGetConfig( @nFunc, 'FinalizeReceiptDetails', @cStorerKey)
   --IF @cFinalizeRD IN ('', '0')
   --   SET @cFinalizeRD = '1' -- Default = 1

   --DECLARE @nbeforereceivedqty INT,@nQtyExpected INT

   --SELECT @nBeforereceivedqty =SUM(beforereceivedqty)
   --      ,@nQtyExpected=SUM(qtyexpected)
   --FROM dbo.RECEIPTDETAIL (NOLOCK)
   --WHERE ReceiptKey = @cReceiptKey
   --AND sku=@cSKUCode
   --AND storerkey=@cStorerKey

   --IF (@nbeforereceivedqty=@nQtyExpected)
   --BEGIN
   --   -- Finalize ASN by line if no more variance
   --   DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   --   SELECT ReceiptLineNumber 
   --   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   --   WHERE ReceiptKey = @cReceiptKey
   --   AND   FinalizeFlag <> 'Y'
   --   AND   sku=@cSKUCode

   --   OPEN CUR_UPD
   --   FETCH NEXT FROM CUR_UPD INTO @cReceiptLineNumber
   --   WHILE @@FETCH_STATUS <> -1
   --   BEGIN
   --      IF @cFinalizeRD = '1'
   --      BEGIN
   --         -- Bulk update (so that trigger fire only once, compare with row update that fire trigger each time)
   --         UPDATE dbo.ReceiptDetail SET
   --            QTYReceived = RD.BeforeReceivedQTY,
   --            FinalizeFlag = 'Y', 
   --            EditWho = SUSER_SNAME(), 
   --            EditDate = GETDATE()
   --         FROM dbo.ReceiptDetail RD
   --         WHERE ReceiptKey = @cReceiptKey
   --            AND ReceiptLineNumber = @cReceiptLineNumber
   --         SET @nErrNo = @@ERROR
   --         IF @nErrNo <> 0
   --         BEGIN
   --            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
   --            GOTO RollBackTran
   --         END
   --      END

   --      IF @cFinalizeRD = '2'
   --      BEGIN
   --         EXEC dbo.ispFinalizeReceipt
   --             @c_ReceiptKey        = @cReceiptKey
   --            ,@b_Success           = @bSuccess   OUTPUT
   --            ,@n_err               = @nErrNo     OUTPUT
   --            ,@c_ErrMsg            = @cErrMsg    OUTPUT
   --            ,@c_ReceiptLineNumber = @cReceiptLineNumber
   --         IF @nErrNo <> 0 OR @bSuccess = 0
   --         BEGIN
   --            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
   --            GOTO RollBackTran
   --         END
   --      END

   --      FETCH NEXT FROM CUR_UPD INTO @cReceiptLineNumber
   --   END
   --   CLOSE CUR_UPD
   --   DEALLOCATE CUR_UPD    
   
   --   IF rdt.RDTGetConfig( @nFunc, 'CloseASNUponFinalize', @cStorerKey) = '1'
   --      AND @cFinalizeRD > 0
   --      AND NOT EXISTS ( SELECT 1 
   --                       FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   --                       WHERE ReceiptKey = @cReceiptKey
   --                       AND   FinalizeFlag = 'N')
   --   BEGIN
   --      -- Close Status and ASNStatus here. If turn on config at WMS side then all ASN will be affected,
   --      -- no matter doctype. This only need for ecom ASN only. So use rdt config to control
   --      UPDATE dbo.RECEIPT SET  
   --         ASNStatus = '9',    
   --         -- Status    = '9',  -- Should not overule Exceed trigger logic
   --         ReceiptDate = GETDATE(),
   --         FinalizeDate = GETDATE(),
   --         EditDate = GETDATE(),    
   --         EditWho = SUSER_SNAME()     
   --      WHERE ReceiptKey = @cReceiptKey    
   --      SET @nErrNo = @@ERROR
   --      IF @nErrNo <> 0
   --      BEGIN
   --         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
   --         GOTO RollBackTran
   --      END   
   --   END
   --END
   --GOTO QUIT   

   GOTO QUIT
           
   RollBackTran:          
      ROLLBACK TRAN rdt_1580RcptCfm25 -- Only rollback change made here          
          
   Quit:          
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started          
         COMMIT TRAN rdt_1580RcptCfm25 

END

GO