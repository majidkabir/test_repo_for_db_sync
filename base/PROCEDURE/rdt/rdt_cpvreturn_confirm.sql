SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_CPVReturn_Confirm                               */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Date        Rev  Author    Purposes                                  */  
/* 14-Sep-2018 1.0  Ung        WMS-6632 Created                         */  
/* 07-Mar-2019 1.1  ChewKP     Changes                                  */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_CPVReturn_Confirm] (  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,  
   @nInputKey     INT,  
   @cStorerKey    NVARCHAR( 15),   
   @cFacility     NVARCHAR( 5),   
   @cReceiptKey   NVARCHAR( 10),   
   @cToLOC        NVARCHAR( 10),   
   @cSKU          NVARCHAR( 20),   
   @dLottable04   DATETIME,   
   @cLottable07   NVARCHAR( 30),   
   @cLottable08   NVARCHAR( 30),   
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cReturnLOC NVARCHAR( 10)  
   DECLARE @cUOM NVARCHAR( 10)  
   DECLARE @nQTY INT  
          ,@dTempLottable05 DATETIME
          ,@cCode           NVARCHAR(10) 
     
   -- Get SKU info  
   SELECT   
      @cUOM = Pack.PackUOM2,   
      @nQTY = Pack.InnerPack,   
      @cReturnLOC = ISNULL( SKU.ReturnLOC, '')  
   FROM SKU WITH (NOLOCK)  
      JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
   WHERE StorerKey = @cStorerKey   
      AND SKU = @cSKU  
      
   SELECT @cCode = Code 
   FROM CODELKUP (NOLOCK)
   WHERE LISTNAME = 'ASNREASON'
   AND STORERKEY = @cStorerKey
   AND UDF05 = 'RTNCODE' 
   
   SET @dTempLottable05 = GETDATE()
        
   IF @cReturnLOC = ''  
      SET @cReturnLOC = @cToLOC  
  
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
      @cPOKey        = '',  
      @cToLOC        = @cReturnLOC,  
      @cToID         = '',  
      @cSKUCode      = @cSKU,  
      @cSKUUOM       = @cUOM,  
      @nSKUQTY       = @nQTY,  
      @cUCC          = '',  
      @cUCCSKU       = '',  
      @nUCCQTY       = '',  
      @cCreateUCC    = '',  
      @cLottable01   = '',  
      @cLottable02   = '',  
      @cLottable03   = '',  
      @dLottable04   = @dLottable04,  
      @dLottable05   = @dTempLottable05,  
      @cLottable06   = '',  
      @cLottable07   = @cLottable07,  
      @cLottable08   = @cLottable08,  
      @cLottable09   = '',  
      @cLottable10   = '',  
      @cLottable11   = '',  
      @cLottable12   = '',  
      @dLottable13   = NULL,  
      @dLottable14   = NULL,  
      @dLottable15   = NULL,  
      @nNOPOFlag     = 1,  
      @cConditionCode = @cCode,  
      @cSubreasonCode = ''  
      -- @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT  
  
END  

GO