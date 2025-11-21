SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_608RcvCfm05                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Finalize ASN only when receive fully                           */
/*          (Sum(beforeReceiveQty)==Sum(QtyExpected))                      */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2018-12-18 1.0  James   WMS-7280 Created                                */
/* 2018-12-18 1.0  James   WMS-8096 Check qty by line before allow         */
/*                         to finalize ASN (james01)                       */
/***************************************************************************/

CREATE PROC [RDT].[rdt_608RcvCfm05](
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
   DECLARE @nTranCount                 INT,
           @nQTYExpected_Total         INT,
           @nBeforeReceivedQTY_Total   INT,
           @cUDF09                     NVARCHAR( 30),
           @b_Success                  INT,
           @nQTYExpected               INT,
           @nBeforeReceivedQTY         INT,
           @nFinalize                  INT

   DECLARE @curRD CURSOR
   DECLARE @curChkRD CURSOR

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_608RcvCfm05 -- For rollback or commit only our own transaction

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
      @cReceiptLineNumberOutput = @cRDLineNo OUTPUT

   IF @nErrNo <> 0
      GOTO RollBackTran

   SET @nFinalize = 1

   SET @curChkRD = CURSOR FOR
      SELECT QTYExpected, BeforeReceivedQTY
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
   OPEN @curChkRD
   FETCH NEXT FROM @curChkRD INTO @nQTYExpected, @nBeforeReceivedQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @nBeforeReceivedQTY < @nQTYExpected
      BEGIN
         SET @nFinalize = 0
         BREAK
      END

      SET @nQTYExpected = 0
      SET @nBeforeReceivedQTY = 0

      FETCH NEXT FROM @curChkRD INTO @nQTYExpected, @nBeforeReceivedQTY
   END

   --SELECT 
   --   @nQTYExpected_Total = ISNULL( SUM( QTYExpected), 0),
   --   @nBeforeReceivedQTY_Total = ISNULL( SUM( BeforeReceivedQTY), 0)
   --FROM dbo.ReceiptDetail WITH (NOLOCK)
   --WHERE ReceiptKey = @cReceiptKey

   --IF @nQTYExpected_Total = @nBeforeReceivedQTY_Total
   IF @nFinalize = 1
   BEGIN
      SET @nErrNo = 0
      SET @curRD = CURSOR FOR
         SELECT ReceiptLineNumber
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
      OPEN @curRD
      FETCH NEXT FROM @curRD INTO @cRDLineNo
      WHILE @@FETCH_STATUS = 0
      BEGIN
         EXEC dbo.ispFinalizeReceipt
             @c_ReceiptKey        = @cReceiptKey
            ,@b_Success           = @b_Success  OUTPUT
            ,@n_err               = @nErrNo     OUTPUT
            ,@c_ErrMsg            = @cErrMsg    OUTPUT
            ,@c_ReceiptLineNumber = @cRDLineNo
         IF @nErrNo <> 0 OR @b_Success = 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curRD INTO @cRDLineNo
      END

      IF @nErrNo = 0
      BEGIN
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 'ASN CLOSED'

         IF @nErrNo = 1 -- Success
            SET @nErrNo = 0
      END
   END

   GOTO Quit

RollBackTran:  
   ROLLBACK TRAN rdt_608RcvCfm05 
Fail:  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN


END

GO