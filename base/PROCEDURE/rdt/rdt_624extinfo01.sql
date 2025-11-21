SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_624ExtInfo01                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Call From rdtfnc_UCC_SortAndMove                            */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2017-10-10  1.0  ChewKP   WMS-3166 Created                           */   
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_624ExtInfo01] (    
    @nMobile        INT,                
    @nFunc          INT,                
    @cLangCode      NVARCHAR(3),        
    @nStep          INT,                
    @nInputKey      INT,
    @cUserName      NVARCHAR( 18),       
    @cFacility      NVARCHAR( 5),        
    @cStorerKey     NVARCHAR( 15),       
    @cUCC           NVARCHAR( 20),       
    @cSortCodeText  NVARCHAR( 20) OUTPUT ,     
    @cSortCode      NVARCHAR( 20) OUTPUT ,     
    @nErrNo         INT OUTPUT,      
    @cErrMsg        NVARCHAR( 20) OUTPUT  
) AS    
BEGIN    
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   
   DECLARE @cPOKey NVARCHAR(10) 
          ,@cExternPOKey NVARCHAR(20)
          
            
   SET @nErrNo   = 0            
   SET @cErrMsg  = ''     
   
   
   IF @nFunc = 624          
   BEGIN     
         
         IF @nStep = 1  -- Get Input Information    
         BEGIN       
            
            SELECT @cSortCode = UserDefined03 
            FROm dbo.UCC WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
            
            --SELECT @cPOKey = POKey
            --FROM dbo.PO WITH (NOLOCK) 
            --WHERE StorerKey = @cStorerKey
            --AND ExternPOKey = @cExternPOKey
            
            SET @cSortCodeText = 'SORT GROUPID:'
            
            --SELECT @cSortCode = RD.UserDefine03 
            --FROM dbo.Receipt R WITH (NOLOCK) 
            --INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
            --WHERE R.StorerKey = @cStorerKey
            --AND R.POKey = @cPOKey
            --AND RD.UserDefine01 = @cUCC 
            
                      
         END      
                
   END          
          

            
       
END     

GO