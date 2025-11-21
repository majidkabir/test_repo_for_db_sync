SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_870ExtValidSP01                                 */  
/* Purpose: Validate  SerialNo                                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2014-08-28 1.2  ChewKP     SOS#331416 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_870ExtValidSP01] (  
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT, 
   @cStorerKey     NVARCHAR( 15), 
   @cSKU           NVARCHAR( 20), 
   @cOrderKey      NVARCHAR( 10), 
   @cSerialNo      NVARCHAR( 30), 
   @cLotNo         NVARCHAR( 20), 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 870  
BEGIN  
   
     
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    
    
    IF NOT EXISTS ( SELECT 1
                    FROM dbo.PickDetail PD WITH (NOLOCK)
                    INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.Lot = PD.Lot AND LA.SKU = PD.SKU)
                    WHERE PD.StorerKey   = @cStorerKey
                    AND PD.OrderKey      = @cOrderKey
                    AND PD.SKU           = @cSKU
                    AND LA.Lottable02    = @cSerialNo ) 
    BEGIN                      
        
        SET @nErrNo = 93001
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidSerialNo'
        GOTO QUIT
       
    END
    
   
END  
  
QUIT:  

 

GO