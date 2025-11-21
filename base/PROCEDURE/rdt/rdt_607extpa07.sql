SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/    
/* Store procedure: rdt_607ExtPA07                                            */    
/* Copyright      : LF Logistics                                              */    
/*                                                                            */    
/* Purpose: Extended putaway                                                  */    
/*                                                                            */    
/* Date         Author    Ver.  Purposes                                      */    
/* 02-10-2019   YeeKung    1.0  WMS-10667                                     */    
/******************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_607ExtPA07]    
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
  
   DECLARE  @cFacility NVARCHAR(20)  
  
   SELECT @cFacility= facility  
   FROM rdt.rdtmobrec WITH (NOLOCK)  
   WHERE MOBILE=@nMobile  
  
   IF @nFunc = 607 -- Return v7  
   BEGIN  
      IF @cSuggLOC = ''  
      BEGIN  
         SELECT TOP 1  
            @cSuggLOC = toloc  
         FROM Receiptdetail RD WITH (NOLOCK) join   
         SKU SK WITH (NOLOCK) ON RD.SKU=SK.SKU AND RD.storerkey=SK.storerkey  
         WHERE RD.receiptkey= @cReceiptKey  
            AND SK.sku=@cSKU  
            AND RD.storerkey=@cStorerKey  
         ORDER BY RD.editdate  
  
         IF @cSuggLOC = ''  
         BEGIN  
            SELECT TOP 1  
               @cSuggLOC = loc  
            FROM Loc WITH (NOLOCK)  
            WHERE facility=@cFacility  
               AND HostwhCode= @cReceiptKey  
               AND status='HOLD'  
               And loc NOT IN (select toloc from v_receiptdetail where receiptkey=@cReceiptKey AND storerkey=@cStorerKey group by toloc)  
               Order by logicallocation,loc  
  
         END  
      END  
   END  
  
   Quit:  
  
END  

GO