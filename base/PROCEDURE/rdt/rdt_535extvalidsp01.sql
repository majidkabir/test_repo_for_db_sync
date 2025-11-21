SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/    
/* Store procedure: rdt_535ExtValidSP01                                 */    
/* Purpose: Validate SKU on UCC                                         */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2014-04-16 1.0  ChewKP     Created                                   */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_535ExtValidSP01] (    
  @nMobile    INT,             
  @nFunc      INT,             
  @cLangCode  NVARCHAR( 3),    
  @nStep      INT,             
  @cStorerKey NVARCHAR( 15),   
  @cFromUCC   NVARCHAR( 20),   
  @cToUCc     NVARCHAR( 20),   
  @cSKU       NVARCHAR( 20),   
  @cQty       NVARCHAR( 5),    
  @nErrNo     INT OUTPUT,      
  @cErrMsg    NVARCHAR( 20) OUTPUT  
)    
AS    
    
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
    
IF @nFunc = 535    
BEGIN    
     
    DECLARE @cDDropID NVARCHAR(20)  
           ,@cDropLoc NVARCHAR(10)  
           ,@nSKUCount INT  
             
      
    SET @nErrNo          = 0  
    SET @cErrMSG         = ''  
      
      
    IF @nStep = '2'  
    BEGIN  
      SELECT @nSKUCount = Count (DISTINCT SKU )  FROM dbo.UCC WITH (NOLOCK)   
      WHERE UccNo = @cToUCC   
                    
      IF @nSKUCount > 1   
      BEGIN  
         SET @nErrNo = 87351  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'>1 SKU'  
    
         GOTO Quit  
      END  
    END  
      
      
    IF @nStep = '3'  
    BEGIN  
      SELECT @nSKUCount = Count (DISTINCT SKU )  FROM dbo.UCC WITH (NOLOCK)   
      WHERE UccNo = @cToUCC   
                    
      IF @nSKUCount > 1   
      BEGIN  
         SET @nErrNo = 87352  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'>1 SKU'  
    
         GOTO Quit  
      END  
        
      IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)   
                      WHERE UCCNo = @cToUCC   
                      AND SKU = @cSKU  
                      AND StorerKey = @cStorerKey )  
      BEGIN  
          SET @nErrNo = 87353  
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'Invalid SKU'  
    
          GOTO Quit  
      END                         
    END  
      
      
END    
    
   
QUIT:    

GO