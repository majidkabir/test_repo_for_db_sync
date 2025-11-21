SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_607ExtInfo05                                    */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Purpose: Show sugg Loc qty                                           */  
/*                                                                      */  
/* Date        Rev  Author       Purposes                               */  
/* 09-10-2019  1.0  YeeKung     WMS-10667 Created                       */  
/************************************************************************/  
              
CREATE PROCEDURE [RDT].[rdt_607ExtInfo05]  
   @nMobile       INT,             
   @nFunc         INT,             
   @cLangCode     NVARCHAR( 3),    
   @nStep         INT,             
   @nAfterStep    INT,              
   @nInputKey     INT,             
   @cFacility     NVARCHAR( 5),     
   @cStorerKey    NVARCHAR( 15),   
   @cReceiptKey   NVARCHAR( 10),   
   @cPOKey        NVARCHAR( 10),   
   @cRefNo        NVARCHAR( 20),   
   @cSKU          NVARCHAR( 20),   
   @nQTY          INT,             
   @cLottable01   NVARCHAR( 18),   
   @cLottable02   NVARCHAR( 18),   
   @cLottable03   NVARCHAR( 18),   
   @dLottable04   DATETIME,        
   @dLottable05   DATETIME,        
   @cLottable06   NVARCHAR( 30),   
   @cLottable07   NVARCHAR( 30),   
   @cLottable08   NVARCHAR( 30),   
   @cLottable09   NVARCHAR( 30),   
   @cLottable10   NVARCHAR( 30),   
   @cLottable11   NVARCHAR( 30),   
   @cLottable12   NVARCHAR( 30),   
   @dLottable13   DATETIME,        
   @dLottable14   DATETIME,        
   @dLottable15   DATETIME,        
   @cReasonCode   NVARCHAR( 10),   
   @cSuggToID     NVARCHAR( 18),   
   @cSuggToLOC    NVARCHAR( 10),   
   @cID           NVARCHAR( 18),   
   @cLOC          NVARCHAR( 10),   
   @cReceiptLineNumber NVARCHAR( 10),   
   @cExtendedInfo NVARCHAR(20)  OUTPUT,   
   @nErrNo        INT           OUTPUT,   
   @cErrMsg       NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   IF @nFunc = 607 -- Return V7  
   BEGIN  
       DECLARE @nTotalQTYRcV INT   
         -- Get statistic  
         SET @nTotalQTYRcV = 0  
  
      IF @nAfterStep in(3) -- SKU  
      BEGIN  
  
         SELECT   
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)  
         FROM dbo.ReceiptDetail WITH (NOLOCK)  
         WHERE ReceiptKey = @cReceiptKey  
            AND Toloc=@cSuggToLOC  
              
         SET @cExtendedInfo = N'ToLoc: '   
  
         SET @cExtendedInfo=@cExtendedInfo+ cast(@nTotalQTYRcv as NVARCHAR(5))  
           
         
      END  
   END  
     
Quit:  
     
END  

GO