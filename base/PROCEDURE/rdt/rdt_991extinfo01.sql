SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_991ExtInfo01                                    */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2019-11-08 1.0  YeeKung    WMS-11200 Created                         */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_991ExtInfo01] (    
   @nMobile      INT,             
   @nFunc        INT,             
   @cLangCode    NVARCHAR( 3),    
   @nStep        INT,         
   @nAfterStep   INT,      
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
   @nActQty      INT,  
   @nSuggQTY     INT,  
   @cExtendedInfo NVARCHAR(20) OUTPUT,   
   @nErrNo       INT           OUTPUT,   
   @cErrMsg      NVARCHAR(250) OUTPUT    
)    
AS    
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
  
    IF @nAfterStep = 4   
    BEGIN  
      SET @cExtendedInfo = 'DropID:'+ @cDropID  
    END  
    
QUIT:    


GO