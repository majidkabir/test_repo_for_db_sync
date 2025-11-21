SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/    
/* Store procedure: rdt_1580ExtVal17                                    */    
/* Copyright      : LF logistics                                        */    
/*                                                                      */    
/* Purpose: validate To ID only can have 1 sku                          */    
/*          rdt_1580ExtVal07-rdt_1580ExtVal17                           */  
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author      Purposes                                */    
/* 12-06-2020  1.0  YeeKung     WMS-13609. Created                      */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1580ExtVal17]    
    @nMobile      INT    
   ,@nFunc        INT    
   ,@nStep        INT    
   ,@nInputKey    INT    
   ,@cLangCode    NVARCHAR( 3)    
   ,@cStorerKey   NVARCHAR( 15)    
   ,@cReceiptKey  NVARCHAR( 10)     
   ,@cPOKey       NVARCHAR( 10)     
   ,@cExtASN      NVARCHAR( 20)    
   ,@cToLOC       NVARCHAR( 10)     
   ,@cToID        NVARCHAR( 18)     
   ,@cLottable01  NVARCHAR( 18)     
   ,@cLottable02  NVARCHAR( 18)     
   ,@cLottable03  NVARCHAR( 18)     
   ,@dLottable04  DATETIME      
   ,@cSKU         NVARCHAR( 20)     
   ,@nQTY         INT    
   ,@nErrNo       INT           OUTPUT     
   ,@cErrMsg      NVARCHAR( 20) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @cErrMsg1    NVARCHAR( 20),    
           @cErrMsg2    NVARCHAR( 20),    
           @cErrMsg3    NVARCHAR( 20),    
           @cErrMsg4    NVARCHAR( 20),    
           @cErrMsg5    NVARCHAR( 20),  
           @cErrMsg6    NVARCHAR( 20),  
           @cErrMsg7    NVARCHAR( 20),  
           @cErrMsg8    NVARCHAR( 20),  
           @cErrMsg9    NVARCHAR( 20),  
           @cSKUClass   NVARCHAR( 20),  
           @cSKUBUSR5   NVARCHAR( 20),  
           @cSKUDECODE  NVARCHAR( 60)  
   
   IF @nStep = 3 -- To ID    
   BEGIN    
      IF @nInputKey = 1 -- ENTER    
      BEGIN    
         -- To ID is mandatory    
         IF ISNULL( @cToID, '') = ''    
         BEGIN    
            SET @nErrNo = 153551    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDReq    
            GOTO Quit    
         END    
      END    
   END    
    
   IF @nStep = 5 -- SKU, QTY    
   BEGIN    
      IF @nInputKey = 1 -- ENTER    
      BEGIN     
             
         IF EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)     
                    WHERE StorerKey = @cStorerKey    
                    AND   ReceiptKey = @cReceiptKey    
                    AND   ToID = @cToID    
                    --AND   BeforeReceivedQty > 0    
                    AND   SKU <> @cSKU)    
         BEGIN    
            SET @nErrNo = 153552    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixSKUinID    
            GOTO Quit    
         END    
             
             
         IF EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK)     
                    WHERE StorerKey = @cStorerKey    
                    AND ID = @cToID    
                    AND SKU <> @cSKU    
                    AND Loc = @cToLoc    
                    AND Qty > 0 )    
         BEGIN    
            SET @nErrNo = 153553    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMixSKUinID    
            GOTO Quit    
         END    
  
         SELECT @cSKUClass=TRIM(class)   
               ,@cSKUBUSR5=TRIM(BUSR5)  
         FROM SKU (NOLOCK)  
         WHERE SKU=@cSKU  
  
         SET @cSKUDECODE=@cSKUClass +' '+@cSKUBUSR5  
  
         IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE LISTNAME='POPUPDtl'   
                     AND long=@cSKUDECODE  
                     AND storerkey=@cStorerKey   
                     AND code2=@nFunc)  
                     AND NOT EXISTS (SELECT 1 FROM DBO.RECEIPTDETAIL WITH (NOLOCK)  
                                 WHERE receiptkey =@cReceiptKey        
                                    AND sku=@cSKU  
                                    AND beforereceivedqty<>0)   
         BEGIN  
              
            SELECT @cErrMsg1=description   
            FROM CODELKUP (NOLOCK)   
            WHERE LISTNAME='POPUPDtl'   
               AND long=@cSKUDECODE   
               AND code2=@nFunc  
  
            IF LEN(@cErrMsg1)>20  
            BEGIN  
               SET @cErrMsg2 = CASE WHEN LEN(@cErrMsg1) between 21 and 40 THEN SUBSTRING(@cErrMsg1,21,40) ELSE '' END  
               SET @cErrMsg3 = CASE WHEN LEN(@cErrMsg1) between 41 and 60 THEN SUBSTRING(@cErrMsg1,41,60) ELSE '' END  
            END  
  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,      
               @cErrMsg1,      
               @cErrMsg2,      
               @cErrMsg3,      
               @cErrMsg4,      
               @cErrMsg5,      
               @cErrMsg6,      
               @cErrMsg7,      
               @cErrMsg8,      
               @cErrMsg9  
  
            SET @nErrNo=0  
    
         END  
      END    
   END    
    
Quit:    
END     

GO