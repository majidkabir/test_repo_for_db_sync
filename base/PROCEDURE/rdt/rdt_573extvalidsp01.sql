SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_573ExtValidSP01                                 */  
/* Purpose: Validate  UCC                                               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2017-05-17 1.0  ChewKP     WMS-1920 Created                          */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_573ExtValidSP01] (  
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
  
IF @nFunc = 573  
BEGIN  
   
	 DECLARE @nNewType  		   INT 
	        ,@nType            INT
	        ,@cIDtype          NVARCHAR(1)
	        ,@cNewIDType       NVARCHAR(1) 
    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''

       
    IF @nStep = '4'
    BEGIN
			 
			 SELECT @nNewType = ISNULL(COUNT(1) ,0 ) 
          FROM RECEIPTDETAIL (NOLOCK)
          WHERE ReceiptKey = @cReceiptKey1
          AND UserDefine01 = @cUCC
          GROUP BY Userdefine01
			
			 SET @cNewIDType = CASE WHEN @nNewType = 1 THEN 'S' ELSE 'M' END 
			 
			 SELECT TOP 1 @nType = ISNULL(COUNT(1) ,0 )  
          FROM RECEIPTDETAIL (NOLOCK)
          WHERE ReceiptKey = @cReceiptKey1
          AND ToLOC  = @cLoc
          AND ToID   = @cID
          AND BeforeReceivedQty > 0
          GROUP BY Userdefine01
          
          SET @cIDType = CASE WHEN @nType = 1 THEN 'S' ELSE 'M' END 
	       
          IF ISNULL(@nType,0) <> 0 
          BEGIN
	          IF ISNULL(@cNewIDType,'')  <> ISNULL(@cIDType  ,'') 
	          BEGIN
			         SET @nErrNo = 109351
	               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'IDTypeNotMatch'
	            
	               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg, ''
                  SET @nErrNo = 109351
	               GOTO QUIT
	          END  
          END
   END
       
       
    
    
    

   
END  
  
QUIT:  

 

GO