SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/      
/* Store procedure: rdt_573ExtValidSP03                                 */      
/* Purpose: Validate  UCC                                               */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date       Rev  Author     Purposes                                  */      
/* 2020-06-12 1.0  YeeKung    WMS-13608 Created                         */      
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_573ExtValidSP03] (      
   @nMobile     INT,     
   @nFunc       INT,     
   @cLangCode   NVARCHAR(3),     
   @nStep       INT,     
   @cStorerKey  NVARCHAR(15),    
   @cFacility   NVARCHAR(5),     
   @cReceiptKey1 NVARCHAR(20),              
   @cReceiptKey2 NVARCHAR(20),              
   @cReceiptKey3 NVARCHAR(20),              
   @cReceiptKey4 NVARCHAR(20),              
   @cReceiptKey5 NVARCHAR(20),              
   @cLoc        NVARCHAR(20),               
   @cID         NVARCHAR(18),               
   @cUCC        NVARCHAR(20),               
   @nErrNo      INT  OUTPUT,                
   @cErrMsg     NVARCHAR(1024) OUTPUT    
)      
AS      
      
   SET NOCOUNT ON        
   SET QUOTED_IDENTIFIER OFF        
   SET ANSI_NULLS OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
      
       
   DECLARE @nInputKey  INT     
   DECLARE @cID_ReceiptKey    NVARCHAR( 10)    
   DECLARE @cUCC_ReceiptKey   NVARCHAR( 10)    
   DECLARE @cErrMsg01         NVARCHAR( 20)    
   DECLARE @cBUSR5            NVARCHAR( 20)  
   DECLARE @cSKU              NVARCHAR( 20)  
   DECLARE @cDECODE           NVARCHAR( 60)  
   DECLARE @cClass            NVARCHAR( 20)  
   DECLARE @nInteger15        INT  
  
   DECLARE @cErrMsg1          NVARCHAR( 20),  
           @cErrMsg2          NVARCHAR( 20),  
           @cErrMsg3          NVARCHAR( 20),  
           @cErrMsg4          NVARCHAR( 20),  
           @cErrMsg5          NVARCHAR( 20),  
           @cErrMsg6          NVARCHAR( 20),  
           @cErrMsg7          NVARCHAR( 20),  
           @cErrMsg8          NVARCHAR( 20),  
           @cErrMsg9          NVARCHAR( 20)  
  
   SET @nErrNo          = 0    
   SET @cErrMSG         = ''    
  
    
   SELECT @nInputKey = InputKey  
         ,@nInteger15=V_Integer15    
   FROM RDT.RDTMOBREC WITH (NOLOCK)    
   WHERE Mobile = @nMobile    
    
   IF @nStep = '4'    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
  
         SELECT TOP 1 @cSKU=sku  
         FROM DBO.RECEIPTDETAIL WITH (NOLOCK)  
         WHERE receiptkey IN (@cReceiptKey1,@cReceiptKey2,@cReceiptKey3,@cReceiptKey4,@cReceiptKey5)  
            AND userdefine01 = @cUCC   
           -- AND beforereceivedqty<>0  
         Order by ReceiptLineNumber   
  
         SELECT @cBUSR5 =TRIM(busr5),@cClass=TRIM(class)   
         FROM SKU WITH (NOLOCK)  
         WHERE SKU=@cSKU  
  
         SET @cDECODE=@cClass +' '+@cBUSR5  
  
         IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE LISTNAME='POPUPDtl'   
                     AND long=@cDECODE  
                     AND storerkey=@cStorerKey   
                     AND code2=@nFunc)  
                     AND NOT EXISTS (SELECT 1 FROM DBO.RECEIPTDETAIL WITH (NOLOCK)  
                                 WHERE receiptkey IN (@cReceiptKey1,@cReceiptKey2,@cReceiptKey3,@cReceiptKey4,@cReceiptKey5)        
                                    AND sku=@cSKU  
                                    AND beforereceivedqty<>0)   
         BEGIN  
              
            SELECT @cErrMsg1=description   
            FROM CODELKUP (NOLOCK)   
            WHERE LISTNAME='POPUPDtl'   
                  AND long=@cDECODE   
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
      
QUIT:        

GO