SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/        
/* Store procedure: rdt_SAP_GetTask01                                   */        
/* Copyright: IDS                                                       */        
/* Purpose: Sort And Pack GOH GetTask                                   */        
/*                                                                      */        
/* Modifications log:                                                   */        
/*                                                                      */        
/* Date       Ver  Author   Purposes                                    */        
/* 2020-04-28 1.0  YeeKung  WMS-12853  Created                          */           
/************************************************************************/        
        
CREATE PROCEDURE [RDT].[rdt_SAP_GetTask01]       
   @nMobile         INT,         
   @nFunc           INT,         
   @cLangCode       NVARCHAR( 3),     
   @cStorerKey      NVARCHAR( 15),     
   @cLabelNo        NVARCHAR( 20),     
   @cLoadKey        NVARCHAR( 20),  
   @cStoreNo        NVARCHAR( 15),   
   @cSKU            NVARCHAR( 20),       
   @cOrderKey       NVARCHAR( 10),     
   @nExpQTY         INT      OUTPUT,   
   @nOrderQTY_Total INT      OUTPUT,   
   @nOrderQTY_Bal   INT      OUTPUT,   
   @nSKUQTY_Total   INT      OUTPUT,   
   @nSKUQTY_Bal     INT      OUTPUT,   
   @nScannedQTY     INT      OUTPUT,   
   @nCtnQTY_Total   INT      OUTPUT,   
   @nUnPickQTY      INT      OUTPUT,   
   @nPickedQTY      INT      OUTPUT,   
   @nErrNo          INT      OUTPUT,   
   @cErrMsg         NVARCHAR( 20) OUTPUT         
AS        
BEGIN        
   SET NOCOUNT ON        
   SET QUOTED_IDENTIFIER OFF        
   SET ANSI_NULLS OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
  
   DECLARE     @cOrder_SKU        NVARCHAR( 20),   
               @nOrder_QTY        INT,         
               @nPickQTY          INT,         
               @nPackQTY          INT,         
               @cCurPack_SKU      NVARCHAR( 20),         
               @nCurPack_QTY      INT         
                     
   -- (james02)        
   DECLARE @cSortAndPackFilterGOH   NVARCHAR( 1),         
           @cConvertQtySP           NVARCHAR( 20),         
           @cSQL                    NVARCHAR(1000),             
           @cSQLParam               NVARCHAR(1000)  
     
   SET @nExpQTY=0  
  
   IF(@nPickQTY='' and @nPackQTY='')
   BEGIN

      -- Get Qty (Total picked qty of sku for current store)        
      SELECT @nPickQTY = ISNULL( SUM( PD.QTY), 0)        
      FROM dbo.PickDetail PD WITH (NOLOCK)         
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)        
      WHERE PD.StorerKey = @cStorerKey   
      AND   PD.Status IN ('3', '5')        
      AND   PD.SKU = CASE WHEN ISNULL(@cSKU, '') = '' THEN PD.SKU ELSE @cSKU END     
      AND   OD.userdefine02= @cStoreNo    
  
      -- Get Qty (Total packed qty of sku for current store)        
      SELECT @nPackQTY = ISNULL( SUM( PD.QTY), 0)        
      FROM dbo.PackDetail PD WITH (NOLOCK)         
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)        
      JOIN dbo.PickDetail PID WITH (NOLOCK) ON (PD.Refno = PID.PickDetailKey AND ISNULL(PD.Refno, '') <> '')        
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PID.OrderKey = OD.OrderKey AND PID.OrderLineNumber = OD.OrderLineNumber)        
      WHERE  PH.StorerKey = @cStorerKey        
      AND   PD.SKU = CASE WHEN ISNULL(@cSKU, '') = '' THEN PD.SKU ELSE @cSKU END         
      AND   OD.userdefine02= @cStoreNo         
        
   END
   ELSE
   BEGIN
            -- Get Qty (Total picked qty of sku for current store)        
      SELECT @nPickQTY = ISNULL( SUM( PD.QTY), 0)        
      FROM dbo.PickDetail PD WITH (NOLOCK)         
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)        
      WHERE PD.StorerKey = @cStorerKey   
      AND   PD.Status IN ('3', '5')        
      AND   PD.SKU  > @cSKU     
      AND   OD.userdefine02= @cStoreNo    
  
      -- Get Qty (Total packed qty of sku for current store)        
      SELECT @nPackQTY = ISNULL( SUM( PD.QTY), 0)        
      FROM dbo.PackDetail PD WITH (NOLOCK)         
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)        
      JOIN dbo.PickDetail PID WITH (NOLOCK) ON (PD.Refno = PID.PickDetailKey AND ISNULL(PD.Refno, '') <> '')        
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PID.OrderKey = OD.OrderKey AND PID.OrderLineNumber = OD.OrderLineNumber)        
      WHERE  PH.StorerKey = @cStorerKey        
      AND   PD.SKU > @cSKU          
      AND   OD.userdefine02= @cStoreNo      
   END
   SET @nExpQTY = @nPickQTY - @nPackQTY        
   SET @nScannedQTY = @nPackQTY  
  
   SELECT  @nOrderQTY_Total=ISNULL( SUM( PD.QTY), 0)        
   FROM dbo.PickDetail PD WITH (NOLOCK)         
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)        
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)        
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)        
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)        
   WHERE LPD.LoadKey = @cLoadKey        
      AND O.OrderKey = @cOrderKey   
      AND PD.Status IN ('3', '5')        
      AND   OD.userdefine02= @cStoreNo         
      AND ISNULL( OD.UserDefine04, '') <> 'M' -- (james04)        
   GROUP BY  PD.SKU    
     
    SELECT  @nOrderQTY_Bal=ISNULL( SUM( PD.QTY), 0)        
    FROM dbo.PackDetail PD WITH (NOLOCK)         
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)        
      JOIN dbo.PickDetail PID WITH (NOLOCK) ON (PD.Refno = PID.PickDetailKey AND ISNULL(PD.Refno, '') <> '')         
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PID.OrderKey = OD.OrderKey AND PID.OrderLineNumber = OD.OrderLineNumber)        
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)        
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)        
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)        
   WHERE LPD.LoadKey = @cLoadKey        
     -- AND O.OrderKey = @cOrderKey        
      AND   OD.userdefine02= @cStoreNo         
      AND ISNULL( OD.UserDefine04, '') <> 'M' -- (james04)        
   GROUP BY  PD.SKU    
     
    SELECT  @nSKUQTY_Total=ISNULL( SUM( PD.QTY), 0)        
   FROM dbo.PickDetail PD WITH (NOLOCK)         
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)        
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)        
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)        
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)        
   WHERE LPD.LoadKey = @cLoadKey        
     -- AND O.OrderKey = @cOrderKey        
      AND SKU.sku=@cSKU    
      AND PD.Status IN ('3', '5')   
      AND   OD.userdefine02= @cStoreNo          
      AND ISNULL( OD.UserDefine04, '') <> 'M' -- (james04)        
   GROUP BY PD.SKU     
     
    SELECT  @nSKUQTY_Bal=ISNULL( SUM( PD.QTY), 0)        
    FROM dbo.PackDetail PD WITH (NOLOCK)         
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)        
      JOIN dbo.PickDetail PID WITH (NOLOCK) ON (PD.Refno = PID.PickDetailKey AND ISNULL(PD.Refno, '') <> '')         
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PID.OrderKey = OD.OrderKey AND PID.OrderLineNumber = OD.OrderLineNumber)        
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)        
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)        
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)        
   WHERE LPD.LoadKey = @cLoadKey        
     -- AND O.OrderKey = @cOrderKey        
      AND SKU.sku=@cSKU    
      AND   OD.userdefine02= @cStoreNo     
      AND ISNULL( OD.UserDefine04, '') <> 'M' -- (james04)        
   GROUP BY PD.SKU      
        
   
END   

GO