SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_608RcvCfm10                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: SET TOLOC AS skuxloc.locationtype =ÆPICKÆ                      */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2020-04-08 1.0  YeeKung WMS-14415 Created                               */
/***************************************************************************/

CREATE PROC [RDT].[rdt_608RcvCfm10](
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

   SELECT TOP 1 @cToLOC=LOC
   FROM skuxloc (NOLOCK)
   WHERE locationtype ='PICK'
      AND sku=@cSKUCode
      AND storerkey=@cStorerKey

   
   IF @cLottable03='D'
      SET @cToLOC='EX2D0202A '
   ELSE IF @cLottable03='A'
      SET @cToLOC='EX2D0301A'

   SELECT --@cLottable01 = Lottable01,
          @cLottable02 = Lottable02,
          @cLottable03 = CASE WHEN ISNULL(@cLottable03,'')<>'' THEN @cLottable03 ELSE lottable03 END,
          @dLottable04 = Lottable04,
          @cLottable06 = Lottable06,
          @cLottable07 = Lottable07,
          @cLottable08 = Lottable08,
          @cLottable09 = Lottable09,
          @cLottable10 = Lottable10,
          @cLottable11 = Lottable11,
          @cLottable12 = Lottable12,
          @dLottable13 = Lottable13,
          @dLottable14 = Lottable14
          --@dLottable15 = Lottable15
   from receiptdetail (nolock)
   where receiptkey=@cReceiptKey
      and sku=@cSKUCode

   SELECT TOP 1   @cLottable01 = Lottable01,
                  @dLottable15 = Lottable15
   FROM LOTXLOCXID LLI (NOLOCK) JOIN LOTATTRIBUTE LA (NOLOCK)
   ON LLI.LOT=LA.LOT
   WHERE LLI.SKU=@cSKUCode
   AND LA.Lottable01<>''
   AND LLI.storerkey =@cStorerKey
   AND LLI.qty<>0
   AND  ISNULL(LA.Lottable15,'')<>''
   ORDER BY LA.LOTTABLE15, LA.LOTTABLE01 

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
      @cConditionCode = 'OK',  
      @cSubreasonCode = '',   
      @cReceiptLineNumberOutput = @cRDLineNo OUTPUT    

      IF (@nErrNo<>'')
      BEGIN
         GOTO QUIT
      END

END
QUIT:

GO