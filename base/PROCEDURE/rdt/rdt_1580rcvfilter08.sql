SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1580RcvFilter08                                 */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: ReceiptDetail sort order                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2020-07-06  1.0  James       WMS14064. Created                       */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1580RcvFilter08]  
    @nMobile     INT        
   ,@nFunc       INT         
   ,@cLangCode   NVARCHAR(  3)  
   ,@cReceiptKey NVARCHAR( 10)  
   ,@cPOKey      NVARCHAR( 10)  
   ,@cToLOC      NVARCHAR( 10)  
   ,@cToID       NVARCHAR( 18)  
   ,@cSKU        NVARCHAR( 20)  
   ,@cUCC        NVARCHAR( 20)  
   ,@nQTY        INT            
   ,@cLottable01 NVARCHAR( 18)  
   ,@cLottable02 NVARCHAR( 18)  
   ,@cLottable03 NVARCHAR( 18)  
   ,@dLottable04 DATETIME       
   ,@dLottable05 DATETIME       
   ,@cLottable06 NVARCHAR( 30)  
   ,@cLottable07 NVARCHAR( 30)  
   ,@cLottable08 NVARCHAR( 30)  
   ,@cLottable09 NVARCHAR( 30)  
   ,@cLottable10 NVARCHAR( 30)  
   ,@cLottable11 NVARCHAR( 30)  
   ,@cLottable12 NVARCHAR( 30)  
   ,@dLottable13 DATETIME       
   ,@dLottable14 DATETIME       
   ,@dLottable15 DATETIME       
   ,@cCustomSQL  NVARCHAR( MAX) OUTPUT   
   ,@nErrNo      INT            OUTPUT   
   ,@cErrMsg     NVARCHAR( 20)  OUTPUT   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @cExternReceiptKey NVARCHAR(20)  
   DECLARE @cExternLineNo NVARCHAR(20)  
     
   SET @cExternReceiptKey = ''  
   SET @cExternLineNo = ''  
     
   SELECT TOP 1  
      @cExternReceiptKey = ExternReceiptKey,   
      @cExternLineNo = ExternLineNo   
   FROM ReceiptDetail WITH (NOLOCK)  
   WHERE ReceiptKey = @cReceiptKey  
      AND SKU = @cSKU  
      AND ExternReceiptKey <> ''  
      AND ExternLineNo <> ''  
      AND Lottable01 = @cLottable01  
      AND Lottable02 = @cLottable02  
      AND (QTYExpected - BeforeReceivedQTY) > 0  
   ORDER BY ExternReceiptKey, ExternLineNo  
     
   IF @cExternReceiptKey <> ''   
      SET @cCustomSQL = @cCustomSQL +   
      '     AND ExternReceiptKey = '''  + @cExternReceiptKey + '''' +   
      '     AND ExternLineNo = '''  + @cExternLineNo + ''''  
  
   SET @cCustomSQL = @cCustomSQL +   
      '     AND Lottable01 = ''' + @cLottable01 + '''' +   
      '     AND Lottable02 = ''' + @cLottable02 + '''' +   
      ' ORDER BY ExternReceiptKey, ExternLineNo '        
  
QUIT:  
END -- End Procedure  

GO