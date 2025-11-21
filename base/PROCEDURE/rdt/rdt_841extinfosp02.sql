SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_841ExtInfoSP02                                  */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2021-09-21 1.0  Chermaine  WMS-17410. Created                        */ 
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_841ExtInfoSP02] (    
   @nMobile     INT,    
   @nFunc       INT,     
   @cLangCode   NVARCHAR(3),     
   @nStep       INT,     
   @cStorerKey  NVARCHAR(15),     
   @cDropID     NVARCHAR(20),    
   @cSKU        NVARCHAR(20),   
   @cPickSlipNo NVARCHAR(10),  
   @cLoadKey    NVARCHAR(20),  
   @cWavekey    NVARCHAR(20),  
   @nInputKey   INT,
   @cSerialNo   NVARCHAR( 30), 
   @nSerialQTY   INT,  
   @cExtendedinfo  NVARCHAR( 20) OUTPUT,   
   @nErrNo      INT       OUTPUT,     
   @cErrMsg     CHAR( 20) OUTPUT  
)    
AS    
  
SET NOCOUNT ON         
SET QUOTED_IDENTIFIER OFF         
SET ANSI_NULLS OFF        
SET CONCAT_NULL_YIELDS_NULL OFF     
  
   DECLARE @cShipperKey NVARCHAR(15)
   DECLARE @cOrderKey   NVARCHAR(10)
   
     
   IF @nStep = 7  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
      	SELECT 
      	   @cOrderKey = OrderKey
      	FROM rdt.rdtECOMMLog 
         WHERE ToteNo = @cDropID  
         AND   Sku = @cSKU  
         AND   STATUS = '9'
         AND (batchKey = '' OR batchKey = '1')
      
      	SELECT @cShipperKey = shipperKey
      	FROM orders (NOLOCK) 
      	WHERE storerKey = @cStorerKey
      	AND OrderKey = @cOrderKey
  
         SET @cExtendedinfo = 'ShipperKey: '+ @cShipperKey
      END  
   END  
  
    
QUIT:         
 

GO