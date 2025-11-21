SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_876ExtValidSP01                                 */  
/* Purpose: Validate                                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2016-02-25 1.2  ChewKP     SOS#364494 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_876ExtValidSP01] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cExternOrderKey   NVARCHAR(18),  
   @cOrderKey         NVARCHAR(18),  
   @cSerialNo         NVARCHAR(18),  
   @cSKU              NVARCHAR(20),
   @nErrNo            INT       OUTPUT,   
   @cErrMsg           CHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 876  
BEGIN  
   

    DECLARE @nTTLQtyPicked INT 
           ,@nTTLQtyScanned INT

    SET @nTTLQtyPicked = 0 
    SET @nTTLQtyScanned = 0
    
    IF @nStep = '2'
    BEGIN
         
         SELECT @nTTLQtyPicked = SUM(QTYPicked) 
         FROM dbo.OrderDetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         AND StorerKey = @cStorerKey 
         
         SELECT @nTTLQtyScanned = SUM(QTY) 
         FROM dbo.SerialNo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey
         
 

         IF ( ISNULL( @nTTLQtyScanned, 0 ) + 1 ) > ISNULL ( @nTTLQtyPicked, 0 ) 
         BEGIN
            SET @nErrNo = 96401
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OverScanned'
            GOTO QUIT 
         END       
    END
    
    
    

   
END  
  
QUIT:  

 

GO