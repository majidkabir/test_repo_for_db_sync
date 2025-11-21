SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_839ExtInfo05                                    */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2019-11-08 1.0  YeeKung    WMS-11040 Initial Revision                */
/* 2022-04-20 1.1  YeeKung    WMS-19311 Add Data capture (yeekung01)    */
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_839ExtInfo05] (    
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
   @cPackData1   NVARCHAR( 30),
   @cPackData2   NVARCHAR( 30),
   @cPackData3   NVARCHAR( 30), 
   @cExtendedInfo NVARCHAR(20) OUTPUT,   
   @nErrNo       INT           OUTPUT,   
   @cErrMsg      NVARCHAR(250) OUTPUT    
)    
AS    
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
  
    IF @nAfterStep = 3    
    BEGIN  
      set @cExtendedInfo = 'DropID:'+ @cDropID  
    END  
    
QUIT:

GO