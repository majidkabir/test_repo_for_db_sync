SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/      
/* Store procedure: rdt_727Inquiry04                                       */      
/*                                                                         */      
/* Modifications log:                                                      */      
/*                                                                         */      
/* Date       Rev  Author   Purposes                                       */      
/* 2018-03-27 1.0  ChewKP   WMS-4388 Created                               */
/* 2019-09-20 1.1  YeeKung  WMS-10536 Change the parameter                 */      
/***************************************************************************/      
      
CREATE PROC [RDT].[rdt_727Inquiry04] (      
	 @nMobile    		INT,               
	 @nFunc      		INT,               
	 @nStep      		INT,                
	 @cLangCode  		NVARCHAR( 3),      
	 @cStorerKey 		NVARCHAR( 15),      
	 @cOption    		NVARCHAR( 1),      
	 @cParam1Label    NVARCHAR(20), 
	 @cParam2Label    NVARCHAR(20),   
	 @cParam3Label    NVARCHAR(20),   
	 @cParam4Label    NVARCHAR(20),  
	 @cParam5Label    NVARCHAR(20),  
	 @cParam1         NVARCHAR(20),   
	 @cParam2         NVARCHAR(20),   
	 @cParam3         NVARCHAR(20),   
	 @cParam4         NVARCHAR(20),   
	 @cParam5         NVARCHAR(20),          
	 @cOutField01  	NVARCHAR(20) OUTPUT,    
	 @cOutField02  	NVARCHAR(20) OUTPUT,    
	 @cOutField03  	NVARCHAR(20) OUTPUT,    
	 @cOutField04  	NVARCHAR(20) OUTPUT,    
	 @cOutField05  	NVARCHAR(20) OUTPUT,    
	 @cOutField06  	NVARCHAR(20) OUTPUT,    
	 @cOutField07  	NVARCHAR(20) OUTPUT,    
	 @cOutField08  	NVARCHAR(20) OUTPUT,    
	 @cOutField09  	NVARCHAR(20) OUTPUT,    
	 @cOutField10  	NVARCHAR(20) OUTPUT,
	 @cOutField11  	NVARCHAR(20) OUTPUT,
	 @cOutField12  	NVARCHAR(20) OUTPUT,
	 @cFieldAttr02 	NVARCHAR( 1) OUTPUT,  
	 @cFieldAttr04 	NVARCHAR( 1) OUTPUT,  
	 @cFieldAttr06 	NVARCHAR( 1) OUTPUT,  
	 @cFieldAttr08 	NVARCHAR( 1) OUTPUT,  
	 @cFieldAttr10 	NVARCHAR( 1) OUTPUT,        
	 @nNextPage    	INT          OUTPUT,    
	 @nErrNo     		INT 			 OUTPUT,        
	 @cErrMsg    		NVARCHAR( 20) OUTPUT  
)      
AS      
   SET NOCOUNT ON          
   SET ANSI_NULLS OFF          
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF       
      
   DECLARE @cReceiptKey NVARCHAR(10)  
          ,@cSKU        NVARCHAR(20)  
          ,@cUPC        NVARCHAR(20)   
          ,@cCartonNo   NVARCHAR(30)   
     
   DECLARE @nSKUCnt     INT  
          ,@b_Success   INT  
            
      
            
SET @nErrNo = 0   
  
  
IF @cOption = '1'   
BEGIN            
   --IF @nStep = 2 OR @nStep = 3 OR @nStep = 4   
   --BEGIN  
        
      IF @nStep = 2   
      BEGIN  
         SET @cReceiptKey = @cParam1   
         SET @cUPC        = @cParam3  
           
         IF @cReceiptKey = ''  
         BEGIN  
            SET @nErrNo = 121801  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReceiptKeyReq  
            GOTO QUIT   
         END  
           
         IF NOT EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK)   
                         WHERE ReceiptKey = @cReceiptKey  
                         AND StorerKey = @cStorerKey   )  
         BEGIN  
            SET @nErrNo = 121802  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidReceiptKey  
            GOTO QUIT   
         END  
           
         IF ISNULL(@cUPC,'') = ''   
         BEGIN  
            SET @nErrNo = 121803  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUReq  
            GOTO QUIT   
         END  
           
         -- Get SKU/UPC  
         SET @nSKUCnt = 0  
  
         EXEC RDT.rdt_GETSKUCNT  
             @cStorerKey  = @cStorerKey  
            ,@cSKU        = @cUPC  
            ,@nSKUCnt     = @nSKUCnt       OUTPUT  
            ,@bSuccess    = @b_Success     OUTPUT  
            ,@nErr        = @nErrNo        OUTPUT  
            ,@cErrMsg     = @cErrMsg       OUTPUT  
  
         -- Validate SKU/UPC  
         IF @nSKUCnt = 0  
         BEGIN  
            SET @nErrNo = 121804  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidSKU  
            GOTO QUIT  
         END  
  
         IF @nSKUCnt = 1  
            EXEC [RDT].[rdt_GETSKU]  
                @cStorerKey  = @cStorerKey  
               ,@cSKU        = @cUPC          OUTPUT  
               ,@bSuccess    = @b_Success     OUTPUT  
               ,@nErr        = @nErrNo        OUTPUT  
               ,@cErrMsg     = @cErrMsg       OUTPUT  
  
-- Validate barcode return multiple SKU  
         IF @nSKUCnt > 1  
         BEGIN  
              
            SET @nErrNo = 121805  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiBarcode  
            GOTO QUIT  
         END  
         ELSE   
            SET @cSKU = @cUPC  
  
              
         IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)   
                         WHERE StorerKey = @cStorerKey  
                         AND ReceiptKey = @cReceiptKey  
                         AND SKU = @cSKU )  
         BEGIN  
            SET @nErrNo = 121806  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInASN  
            GOTO QUIT  
         END  
           
         SELECT TOP 1 @cCartonNo = UserDefine05  
         FROM dbo.ReceiptDetail WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND ReceiptKey = @cReceiptKey  
         AND SKU = @cSKU   
           
           
         SET @cOutField01 = 'ASN :'  + @cReceiptKey  
         SET @cOutField02 = 'SKU :'    
         SET @cOutField03 = @cSKU  
         SET @cOutField04 = ''  
         SET @cOutField05 = ''  
         SET @cOutField06 = 'CARTON NO:' + @cCartonNo  
         SET @cOutField07 = ''  
         SET @cOutField08 = ''  
         SET @cOutField09 = ''  
         SET @cOutField10 = ''  
           
         SET @nNextPage = 0  
           
      END  
  
   --END  
END  
QUIT:  
          

        

GO