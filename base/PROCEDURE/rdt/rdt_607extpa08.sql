SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/    
/* Store procedure: rdt_607ExtPA08                                            */    
/* Copyright      : LF Logistics                                              */    
/*                                                                            */    
/* Purpose: Extended putaway                                                  */    
/*                                                                            */    
/* Date         Author    Ver.  Purposes                                      */    
/* 01-04-2020   YeeKung   1.0   WMS12705 - Created                            */
/* 22-06-2020   YeeKung   1.1   WMS13847- Update UDF03->UDF04 (yeekung01)     */    
/******************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_607ExtPA08]    
   @nMobile      INT,               
   @nFunc        INT,               
   @cLangCode    NVARCHAR( 3),      
   @nStep        INT,               
   @nInputKey    INT,               
   @cStorerKey   NVARCHAR( 15),     
   @cReceiptKey  NVARCHAR( 10),     
   @cPOKey       NVARCHAR( 10),     
   @cRefNo       NVARCHAR( 20),     
   @cSKU         NVARCHAR( 20),     
   @nQTY         INT,               
   @cLottable01  NVARCHAR( 18),     
   @cLottable02  NVARCHAR( 18),     
   @cLottable03  NVARCHAR( 18),     
   @dLottable04  DATETIME,          
   @dLottable05  DATETIME,          
   @cLottable06  NVARCHAR( 30),     
   @cLottable07  NVARCHAR( 30),     
   @cLottable08  NVARCHAR( 30),     
   @cLottable09  NVARCHAR( 30),     
   @cLottable10  NVARCHAR( 30),     
   @cLottable11  NVARCHAR( 30),     
   @cLottable12  NVARCHAR( 30),     
   @dLottable13  DATETIME,          
   @dLottable14  DATETIME,          
   @dLottable15  DATETIME,     
   @cReasonCode  NVARCHAR( 10),     
   @cID          NVARCHAR( 18),     
   @cLOC         NVARCHAR( 10),     
   @cReceiptLineNumber NVARCHAR( 10),     
   @cSuggID      NVARCHAR( 18)  OUTPUT,     
   @cSuggLOC     NVARCHAR( 10)  OUTPUT,     
   @nErrNo       INT            OUTPUT,     
   @cErrMsg      NVARCHAR( 20)  OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
          
   IF @nFunc = 607 -- Return v7    
   BEGIN    
          
      -- Get suggest loc    
      IF @cSuggLOC = ''   
      BEGIN   
         SELECT @cSuggLOC=UDF01 FROM CODELKUP(NOLOCK)   
         WHERE LISTNAME='ASNREASON'   
            AND CODE=@cReasonCode   
            AND STORERKEY=@cStorerKey  
         IF @cSuggLOC = ''   
         BEGIN   
            SELECT @cSuggLOC=UDF04 FROM CODELKUP(NOLOCK)   --(yeekung01)
            WHERE LISTNAME='PLATFORM'   
            AND CODE=(SELECT RECEIPTGROUP FROM RECEIPT (NOLOCK) WHERE receiptkey=@cReceiptKey)  
            AND STORERKEY=@cStorerKey  
         END  
      END  
    
  
   END    
Quit:    
    
END    

GO