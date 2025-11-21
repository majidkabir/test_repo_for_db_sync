SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_550RcptCfm02                                          */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: When insert new receiptdetail line, copy lottable value to new    */  
/*          line from original line                                           */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2019-02-26 1.0  James      WMS7968 Created                                 */  
/* 2019-04-11 1.1  SPChin     INC0658405 - Revised Receiving Logic            */  
/* 2020-06-05 1.2  LZG        INC1155163 - Loop through ReceiptDetail to      */
/*                                         finalize (ZG01)                    */
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_550RcptCfm02] (  
   @nFunc          INT,  
   @nMobile        INT,  
   @cLangCode      NVARCHAR( 3),  
   @nErrNo         INT   OUTPUT,  
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
   @cReceiptLineNumberOutput NVARCHAR( 5) = '' OUTPUT,  
   @cDebug         NVARCHAR( 1) = '0'  
) AS  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cDuplicateFrom       NVARCHAR( 5)  
   DECLARE @cReceiptLineNumber   NVARCHAR( 5)  
   DECLARE @cLottable06          NVARCHAR( 30)  
   DECLARE @cLottable07          NVARCHAR( 30)  
   DECLARE @cLottable08          NVARCHAR( 30)  
   DECLARE @cLottable09          NVARCHAR( 30)  
   DECLARE @cLottable10          NVARCHAR( 30)  
   DECLARE @cLottable11          NVARCHAR( 30)  
   DECLARE @cLottable12          NVARCHAR( 30)  
   DECLARE @dLottable13          DATETIME  
   DECLARE @dLottable14          DATETIME  
   DECLARE @dLottable15          DATETIME  
   DECLARE @b_success            INT  
  
   -- Handling transaction  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_550RcptCfm02 -- For rollback or commit only our own transaction  
  
   EXEC rdt.rdt_Receive  
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
      @nNOPOFlag     = @nNOPOFlag,  
      @cConditionCode = @cConditionCode,  
      @cSubreasonCode = '',  
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT  
  
   IF @nErrNo <> 0  
      GOTO RollBackTran  
  
   SET @cDuplicateFrom = ''  
   SELECT @cDuplicateFrom = DuplicateFrom   
   FROM dbo.ReceiptDetail WITH (NOLOCK)  
   WHERE ReceiptKey = @cReceiptKey  
   AND   ReceiptLineNumber = @cReceiptLineNumber  
     
   IF ISNULL( @cDuplicateFrom, '') <> ''  
   BEGIN  
      SELECT @cLottable06 = Lottable06,  
             @cLottable07 = Lottable07,  
             @cLottable08 = Lottable08,  
             @cLottable09 = Lottable09,  
             @cLottable10 = Lottable10  
      FROM dbo.ReceiptDetail WITH (NOLOCK)   
      WHERE ReceiptKey = @cReceiptKey  
      AND   ReceiptLineNumber = @cDuplicateFrom  
  
      IF @@ROWCOUNT > 0  
      BEGIN  
         UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET  
            Lottable06 = CASE WHEN ISNULL( Lottable06, '') = '' THEN @cLottable06 ELSE Lottable06 END,  
            Lottable07 = CASE WHEN ISNULL( Lottable07, '') = '' THEN @cLottable07 ELSE Lottable07 END,  
            Lottable08 = CASE WHEN ISNULL( Lottable08, '') = '' THEN @cLottable08 ELSE Lottable08 END,  
            Lottable09 = CASE WHEN ISNULL( Lottable09, '') = '' THEN @cLottable09 ELSE Lottable09 END,  
            Lottable10 = CASE WHEN ISNULL( Lottable10, '') = '' THEN @cLottable10 ELSE Lottable10 END  
         WHERE ReceiptKey = @cReceiptKey  
         AND   ReceiptLineNumber = @cReceiptLineNumber  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 134851  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RcptCfm Fail  
            GOTO RollBackTran  
         END  
      END  
   END  
     
   --INC0658405 Start  
   DECLARE @c_NotFinalizeRD NVARCHAR(1)    
   SET @c_NotFinalizeRD = rdt.RDTGetConfig( 0, 'RDT_NotFinalizeReceiptDetail', @cStorerKey)     
     
   IF @c_NotFinalizeRD = '1'    
   BEGIN  
      /*EXEC dbo.ispFinalizeReceipt    
          @c_ReceiptKey        = @cReceiptKey    
         ,@b_Success           = @b_Success  OUTPUT    
         ,@n_err               = @nErrNo     OUTPUT    
         ,@c_ErrMsg            = @cErrMsg    OUTPUT    
         ,@c_ReceiptLineNumber = @cReceiptLineNumber    */
         
      -- ZG01 (Start)
      -- Finalize ASN by line 
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT ReceiptLineNumber   
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
         WHERE ReceiptKey = @cReceiptKey  
         AND   BeforeReceivedQTY > 0
         AND   FinalizeFlag <> 'Y'  
         OPEN CUR_UPD    
         FETCH NEXT FROM CUR_UPD INTO @cReceiptLineNumber  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
         SET @b_Success = 0  
         EXEC dbo.ispFinalizeReceipt    
              @c_ReceiptKey        = @cReceiptKey    
             ,@b_Success           = @b_Success  OUTPUT    
             ,@n_err               = @nErrNo     OUTPUT    
             ,@c_ErrMsg            = @cErrMsg    OUTPUT    
             ,@c_ReceiptLineNumber = @cReceiptLineNumber    
         
         IF @nErrNo <> 0 OR @b_Success = 0    
             GOTO RollBackTran    
         
         FETCH NEXT FROM CUR_UPD INTO @cReceiptLineNumber  
         END  
      CLOSE CUR_UPD  
      DEALLOCATE CUR_UPD 
      -- ZG01 (End)
    
      IF @nErrNo <> 0 OR @b_Success = 0    
         GOTO RollBackTran    
   END  
   --INC0658405 End  
  
   GOTO Quit  
  
RollBackTran:    
   ROLLBACK TRAN rdt_550RcptCfm02   
Fail:    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN 


GO