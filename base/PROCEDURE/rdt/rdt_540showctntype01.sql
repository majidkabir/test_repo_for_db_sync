SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_540ShowCtnType01                                */  
/* Purpose: Validate whether need show carton type screen               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2017-01-13 1.0  James      WMS907 Created                            */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_540ShowCtnType01] (  
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT, 
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15), 
   @cLoadKey         NVARCHAR( 10),     
   @cOrderKey        NVARCHAR( 10),    
   @cConsigneeKey    NVARCHAR( 15),     
   @cLabelNo         NVARCHAR( 20),     
   @cSKU             NVARCHAR( 20),       
   @nQTY             INT,                 
   @cShowCtTypeScn   NVARCHAR( 20) OUTPUT, 
   @nErrNo           INT           OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
   IF @nInputKey = 1
   BEGIN  
      IF @nStep = 3
      BEGIN   
         -- Check if current carton scanned is a new carton or not
         IF EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK) 
                     JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
                     JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PH.LoadKey = LPD.LoadKey)
                     WHERE LPD.LoadKey = @cLoadKey
                     AND   PD.LabelNo = @cLabelNo
                     AND   PD.StorerKey = @cStorerKey)
            SET @cShowCtTypeScn = 0
         ELSE
            SET @cShowCtTypeScn = 1
      END
   END  
  
QUIT:  

 

GO