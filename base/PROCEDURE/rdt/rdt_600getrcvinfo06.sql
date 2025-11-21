SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600GetRcvInfo06                                       */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Retrieve ReceitDetail info                                        */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 15-04-2020 YeeKung   1.0   WMS12871 Created                                */
/******************************************************************************/
  
CREATE PROC [RDT].[rdt_600GetRcvInfo06] (  
   @nMobile      INT,             
   @nFunc        INT,             
   @cLangCode    NVARCHAR( 3),    
   @nStep        INT,             
   @nInputKey    INT,             
   @cStorerKey   NVARCHAR( 15),   
   @cReceiptKey  NVARCHAR( 10),   
   @cPOKey       NVARCHAR( 10),   
   @cLOC         NVARCHAR( 10),   
   @cID          NVARCHAR( 18)  OUTPUT,   
   @cSKU         NVARCHAR( 20)  OUTPUT,   
   @nQTY         INT            OUTPUT,   
   @cLottable01  NVARCHAR( 18)  OUTPUT,   
   @cLottable02  NVARCHAR( 18)  OUTPUT,   
   @cLottable03  NVARCHAR( 18)  OUTPUT,   
   @dLottable04  DATETIME       OUTPUT,   
   @dLottable05  DATETIME       OUTPUT,   
   @cLottable06  NVARCHAR( 30)  OUTPUT,   
   @cLottable07  NVARCHAR( 30)  OUTPUT,   
   @cLottable08  NVARCHAR( 30)  OUTPUT,   
   @cLottable09  NVARCHAR( 30)  OUTPUT,   
   @cLottable10  NVARCHAR( 30)  OUTPUT,   
   @cLottable11  NVARCHAR( 30)  OUTPUT,   
   @cLottable12  NVARCHAR( 30)  OUTPUT,   
   @dLottable13  DATETIME       OUTPUT,   
   @dLottable14  DATETIME       OUTPUT,   
   @dLottable15  DATETIME       OUTPUT,   
   @nErrNo       INT            OUTPUT,   
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   IF @nFunc = 600 -- Normal receiving  
   BEGIN  
      IF @nStep = 4 -- SKU  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            SELECT TOP 1     
               @cLottable01 = Case when IsNull(@cLottable01,'') = '' then Lottable01 else @cLottable01 end,    
               @cLottable02 = Case when IsNull(@cLottable02,'') = '' then Lottable02 else @cLottable02 end,    
               @cLottable03 = Case when IsNull(@cLottable03,'') = '' then Lottable03 else @cLottable03 end,    
               @dLottable04 = Case when IsNull(@dLottable04,'1900-01-01') = '1900-01-01' then Lottable04 else @dLottable04 end,    
               @dLottable05 = Case when IsNull(@dLottable05,'1900-01-01') = '1900-01-01' then Lottable05 else @dLottable05 end,    
               @cLottable06 = Case when IsNull(@cLottable06,'') = '' then Lottable06 else @cLottable06 end,    
               @cLottable07 = Case when IsNull(@cLottable07,'') = '' then Lottable07 else @cLottable07 end,    
               @cLottable08 = Case when IsNull(@cLottable08,'') = '' then Lottable08 else @cLottable08 end,    
               @cLottable09 = Case when IsNull(@cLottable09,'') = '' then Lottable09 else @cLottable09 end,    
               @cLottable10 = Case when IsNull(@cLottable10,'') = '' then Lottable10 else @cLottable10 end,    
               @cLottable11 = Case when IsNull(@cLottable11,'') = '' then Lottable11 else @cLottable11 end,    
               @cLottable12 = Case when IsNull(@cLottable12,'') = '' then Lottable12 else @cLottable12 end,    
               @dLottable13 = Case when IsNull(@dLottable13,'1900-01-01') = '1900-01-01' then Lottable13 else @dLottable13 end,    
               @dLottable14 = Case when IsNull(@dLottable14,'1900-01-01') = '1900-01-01' then Lottable14 else @dLottable14 end,    
               @dLottable15 = Case when IsNull(@dLottable15,'1900-01-01') = '1900-01-01' then Lottable15 else @dLottable15 end  
            FROM dbo.ReceiptDetail WITH (NOLOCK)    
            WHERE ReceiptKey = @cReceiptKey    
                  AND SKU = @cSKU    
            ORDER BY     
               CASE WHEN QTYExpected > 0 AND QTYExpected > BeforeReceivedQTY THEN 0 ELSE 1 END,    
               ReceiptLineNumber DESC  
         END  
      END  
   END  
END  

GO