SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/    
/* Store procedure: isp_850ExtInfoSP01                                        */    
/* Copyright      : IDS                                                       */    
/*                                                                            */    
/* Purpose: Inditex PPA Extended info                                         */    
/*                                                                            */    
/* Called from:                                                               */    
/*                                                                            */    
/* Exceed version: 5.4                                                        */    
/*                                                                            */    
/* Modifications log:                                                         */    
/*                                                                            */    
/* Date       Rev  Author   Purposes                                          */    
/* 2012-12-24 1.0  ChewKP   SOS#303019 Created                                */    
/* 2014-05-14 1.1  James    Output extended info (james01)                    */
/* 2014-08-04 1.2  Ung      SOS316605 Change parameters                       */
/* 05-07-2017 1.3  Ung      WMS-2331 Migrate ExtendedInfoSP to VariableTable  */
/******************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_850ExtInfoSP01] -- dbo.isp_850ExtInfoSP01   
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tExtInfo       VariableTable READONLY, 
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @cBUSR10        NVARCHAR(30)    
          ,@nCartonQty     INT  
          ,@nScannedQty    INT  
          ,@nTotalQty      INT  
          ,@cMeasurement   NVARCHAR( 5)  
          ,@nMeasurement   INT
          ,@nTotalCtnQty   INT 
          ,@cPickSlipNo    NVARCHAR( 10)
          ,@cLoadKey       NVARCHAR( 10)
          ,@cOrderKey      NVARCHAR( 10)
          ,@cSKU           NVARCHAR( 20)
     
   SET @cExtendedInfo = ''  
   SET @nScannedQty   = 0  
   SET @nTotalQty     = 0  

   -- Variable mapping
   SELECT @cPickSlipNo = Value FROM @tExtInfo WHERE Variable = '@cPickSlipNo'
   SELECT @cSKU = Value FROM @tExtInfo WHERE Variable = '@cSKU'

   IF @cPickSlipNo= ''
      GOTO Quit

   SELECT @cMeasurement = Measurement
   FROM dbo.SKU WITH (NOLOCK)   
   WHERE SKU = @cSKU  
   AND StorerKey = @cStorerKey  
     
   IF ISNULL( CAST( @cMeasurement AS FLOAT), 0) <= 1   -- (james01)
      SET @nMeasurement = 1   
   ELSE
      SET @nMeasurement = CAST( @cMeasurement AS FLOAT)

   SELECT @cOrderKey = ISNULL(OrderKey,'')   
          ,@cLoadKey = ISNULL(ExternOrderKey,'')  
   FROM dbo.PickHeader WITH (NOLOCK)   
   WHERE PickHeaderKey = @cPickSlipNo   
      
   IF @cOrderKey <> ''   
   BEGIN  
      SELECT @nScannedQty = SUM(PD.QTY)   
      FROM dbo.PickDetail PD WITH (NOLOCK)   
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey  
      WHERE PD.StorerKey = @cStorerKey  
      AND   PD.SKU    = @cSKU  
      AND   PD.OrderKey = @cOrderKey  
        
      SELECT @nTotalQty = SUM(PD.QTY)   
      FROM dbo.PickDetail PD WITH (NOLOCK)   
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey  
      WHERE PD.StorerKey = @cStorerKey  
      AND   PD.OrderKey = @cOrderKey  
        
   END  
   ELSE IF @cLoadKey <> ''  
   BEGIN  
      SELECT @nScannedQty = ISNULL( SUM(CQTY), 0)
      FROM rdt.rdtPPA WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo
      AND   StorerKey = @cStorerKey

      SELECT @nTotalQty = ISNULL( SUM( QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
      WHERE PD.StorerKey = @cStorerKey  
      AND   LPD.LoadKey = @cLoadKey  

      SELECT @nTotalCtnQty = SUM(PPA.CQTY * 
                                   CAST( CASE WHEN ISNULL( CAST( SKU.Measurement AS FLOAT), 0) <= 1 THEN 1 ELSE CAST( SKU.Measurement AS FLOAT) END AS INT))
      FROM rdt.rdtPPA PPA WITH (NOLOCK) 
      JOIN dbo.SKU SKU WITH (NOLOCK) ON PPA.StorerKey = SKU.StorerKey AND PPA.SKU = SKU.SKU
      WHERE PPA.PickSlipNo = @cPickSlipNo
      AND   PPA.StorerKey = @cStorerKey

        
   END  
     
   IF @cSKU <> ''  
   BEGIN  
--      SET @cOField12 = 'CartonQty: ' + CAST(@nMeasurement AS NVARCHAR(5))   
--      SET @cOField13 = 'ScannedQty: ' + CAST(@nScannedQty AS NVARCHAR(5))   
--      SET @cOField14 = 'TotalQty: ' + CAST(@nTotalQty AS NVARCHAR(5))   
      -- (james01)
      SET @cExtendedInfo = 'SCA/TTL/CTN:' + CAST(@nScannedQty AS NVARCHAR(3)) + '/'
                                          + CAST(@nTotalQty AS NVARCHAR(4)) + '/' 
                                          + CAST(@nTotalCtnQty AS NVARCHAR(4)) 
   END  
     
  
     
QUIT:    
END -- End Procedure  


GO