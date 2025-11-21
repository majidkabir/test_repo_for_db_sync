SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/    
/* Store procedure: rdt_839ExtValidSP13                                 */    
/* Purpose: Validate scanned Dropid cannot exists in pickdetail before  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2023-07-07 1.0  James      WMS-22968. Created                        */    
/************************************************************************/    
CREATE   PROC [RDT].[rdt_839ExtValidSP13] (    
   @nMobile      INT,             
   @nFunc        INT,             
   @cLangCode    NVARCHAR( 3),    
   @nStep        INT,             
   @nInputKey    INT,             
   @cFacility    NVARCHAR( 5) ,   
   @cStorerKey   NVARCHAR( 15),   
   @cType        NVARCHAR( 10),   
   @cPickSlipNo  NVARCHAR( 10),   
   @cPickZone    NVARCHAR( 10),    
   @cDropID      NVARCHAR( 20),   
   @cLOC         NVARCHAR( 10),   
   @cSKU         NVARCHAR( 20),   
   @nQTY         INT,           
   @cPackData1   NVARCHAR( 30),
   @cPackData2   NVARCHAR( 30),
   @cPackData3   NVARCHAR( 30),     
   @nErrNo       INT           OUTPUT,   
   @cErrMsg      NVARCHAR(250) OUTPUT    
)    
AS    
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
    
IF @nFunc = 839    
BEGIN    
   DECLARE @cOrderKey         NVARCHAR( 10) = ''  
   DECLARE @cStop             NVARCHAR( 10) = ''  
     
   SET @nErrNo          = 0  
   SET @cErrMSG         = ''  
     
   IF @nStep = 2   
   BEGIN  
      IF @nInputKey = 1 -- ENTER  
      BEGIN  
         SELECT TOP 1 @cOrderKey = OrderKey  
         FROM dbo.PICKDETAIL WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickSlipNo  
         ORDER BY 1  
         
         SELECT @cStop = [Stop]
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
         IF @cStop = '20'
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPIDFW', @cDropID) = 0    
            BEGIN    
               SET @nErrNo = 203751    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format    
               GOTO QUIT    
            END    
         END

         IF ISNULL( @cDropID, '') = ''
            GOTO QUIT
            
      	IF EXISTS ( SELECT 1 
      	            FROM dbo.PICKDETAIL WITH (NOLOCK)
      	            WHERE Storerkey = @cStorerKey
      	            AND   DropID = @cDropID
      	            AND   [Status] < '9')
         BEGIN    
            SET @nErrNo = 203752    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID Exists     
            GOTO QUIT    
         END    
      END  
   END  
END    
    
QUIT:    

GO