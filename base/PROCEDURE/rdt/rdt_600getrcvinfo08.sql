SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_600GetRcvInfo08                                       */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Purpose: Retrieve ReceitDetail info                                        */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 2021-11-03  James     1.0   WMS-18181. Created                             */  
/* 2021-12-30  Chermaine 1.1   WMS-18586 Add expDate decode logic (cc01)      */  
/******************************************************************************/  
    
CREATE    PROC [RDT].[rdt_600GetRcvInfo08] (    
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
     
   DECLARE @cMax        NVARCHAR( MAX)  
   DECLARE @cSeparator  NVARCHAR( 2)  
   DECLARE @cLot01      NVARCHAR( 18)  
   DECLARE @cLot04      DATETIME    --(cc01)  
     
   IF @nFunc = 600 -- Normal receiving    
   BEGIN    
      IF @nStep = 4 -- SKU    
      BEGIN    
         IF @nInputKey = 1 -- ENTER    
         BEGIN    
            SELECT @cMax = V_Max  
            FROM rdt.RDTMOBREC WITH (NOLOCK)  
            WHERE Mobile = @nMobile  
  
            IF LEN(@cMax) > 24 --(cc01)  
            BEGIN  
               SET @cSeparator = SUBSTRING( @cMax, 25, 2)   
               IF SUBSTRING( @cMax, 17, 2) = '17'  
               BEGIN  
                SET @cLot04 = @dLottable04  
               END  
            END   
            ELSE  
            BEGIN  
             SET @cSeparator = SUBSTRING( @cMax, 17, 2)  
            END               
              
            IF @cSeparator NOT IN ('10','21')
               SET @cLot01 = ''  
            ELSE  
               SET @cLot01 = @cLottable01  
              
                    
            SELECT TOP 1        
               @cLottable01 = Lottable01,        
               @cLottable02 = Lottable02,        
               @cLottable03 = Lottable03,        
               @dLottable04 = CASE WHEN @cLot04 <> Lottable04 AND @cLot04 IS NOT null THEN @cLot04 ELSE Lottable04 END,      --(cc01)  
               @dLottable05 = Lottable05,        
               @cLottable06 = Lottable06,        
               @cLottable07 = Lottable07,        
               @cLottable08 = Lottable08,        
               @cLottable09 = Lottable09,        
               @cLottable10 = Lottable10,        
               @cLottable11 = Lottable11,        
               @cLottable12 = Lottable12,        
               @dLottable13 = Lottable13,        
               @dLottable14 = Lottable14,        
               @dLottable15 = Lottable15        
            FROM dbo.ReceiptDetail WITH (NOLOCK)        
            WHERE ReceiptKey = @cReceiptKey        
            AND   POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END        
            AND   SKU = @cSKU        
            AND (( @cLot01 = '') OR ( Lottable01 = @cLot01))  
            ORDER BY        
               CASE WHEN @cID = ToID THEN 0 ELSE 1 END,        
               CASE WHEN QTYExpected > 0 AND QTYExpected > BeforeReceivedQTY THEN 0 ELSE 1 END,        
               ReceiptLineNumber        
         END    
      END    
   END    
END    

GO