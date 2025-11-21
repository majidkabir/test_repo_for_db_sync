SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_ANF_GetTask01                                   */  
/* Copyright      : LFL                                                 */  
/*                                                                      */  
/* Purpose: Get next consignee of SKU to Pack                           */  
/*                                                                      */  
/* Called from: rdtfnc_SortAndPack                                      */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author    Purposes                                  */  
/* 2014-04-01  1.0  Chee      SOS#307177 Created                        */  
/* 2017-05-16  1.1  CheeMun   IN00346713 - Extend Field size.           */  
/* 2017-09-21  1.2  ChewKP    Performance Tuning (ChewKP01)             */  
/* 2021-07-22  1.3  James     Output label no (james01)                 */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_ANF_GetTask01] (  
   @nMobile                   INT,  
   @nFunc                     INT,   
   @cLangCode                 NVARCHAR( 3),  
   @cPackByType               NVARCHAR( 10),  
   @cType                     NVARCHAR( 10),  
   @cLoadKey                  NVARCHAR( 10),  
   @cStorerKey                NVARCHAR( 15),  
   @cSKU                      NVARCHAR( 20),  
   @cConsigneeKey             NVARCHAR( 15)      OUTPUT,  
   @cOrderKey                 NVARCHAR( 10)      OUTPUT,  
   @c_oFieled01               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled02               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled03               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled04               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled05               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled06               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled07               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled08               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled09               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled10               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled11               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled12               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled13               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled14               NVARCHAR( 20)      OUTPUT,  
   @c_oFieled15               NVARCHAR( 20)      OUTPUT,   
   @bSuccess                  INT                OUTPUT,  
   @nErrNo                    INT                OUTPUT,  
   @cErrMsg                   NVARCHAR( 20)      OUTPUT   -- screen limitation, 20 char max  
)  
AS  
BEGIN  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cNextConsigneeKey NVARCHAR( 15),   
           @cNextOrderKey     NVARCHAR( 10),   
           @cCons_SKU         NVARCHAR( 20),   
           @cOrder_SKU        NVARCHAR( 20),   
           @nCons_QTY         INT,  
           @nOrder_QTY        INT,   
           @nQTY              INT,   
           @nConsCNT_Total    INT,        
           @nConsCNT_Bal      INT,  
           @nConsQTY_Total    INT,  
           @nConsQTY_Bal      INT,  
           @nOrderQTY_Total   INT,  
           @nOrderQTY_Bal     INT,  
           @nSKUQTY_Total     INT,  
           @nSKUQTY_Bal       INT,  
           @cUCCNo            NVARCHAR(20),  
           @nStep             INT,
           @cCaseID           NVARCHAR( 20)
           
   SELECT 
      @nStep = Step, 
      @cCaseID = V_CaseID 
   FROM rdt.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
   IF EXISTS(SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)   
             JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)  
             WHERE LPD.LoadKey = @cLoadKey     
             AND PD.StorerKey = @cStorerKey  
             AND PD.SKU = @cSKU  
             AND PD.Status NOT IN ('3', '5'))  
   BEGIN  
      SET @nErrNo = 86652  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not fully pick  
      GOTO Quit  
   END  
  
   IF @cType = 'UCC'  
   BEGIN  
      SET @cUCCNo = @c_oFieled10  
      SELECT @nConsCNT_Bal = COUNT( DISTINCT OD.UserDefine02)  
      FROM dbo.PickDetail PD WITH (NOLOCK)   
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber) -- (ChewKP01)  
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
         --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey) -- (ChewKP01)   
      --WHERE LPD.LoadKey = @cLoadKey -- (ChewKP01)   
      WHERE O.LoadKey = @cLoadKey  
         AND PD.StorerKey = @cStorerKey  
         AND PD.DropID = @cUCCNo  
         AND PD.QTY > 0  
         AND PD.UOM = '6'  
         AND PD.Status IN ('3', '5')  
         AND ISNULL(PD.CaseID,'') = ''      
  
      IF @nConsCNT_Bal <> 1  
      BEGIN  
         SET @nErrNo = 86653  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC  
         GOTO Quit  
      END  
   END  
  
   -- If no more task for this consignee in this load, ask user to close carton  
   IF ISNULL(@cConsigneeKey, '') <> '' AND   
      NOT EXISTS(SELECT 1  
                 FROM dbo.PickDetail PD WITH (NOLOCK)   
                 JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)  
                 JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
                 --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey) -- (ChewKP01)   
                 --WHERE LPD.LoadKey = @cLoadKey -- (ChewKP01)     
                 WHERE O.LoadKey = @cLoadKey     
                   AND PD.StorerKey = @cStorerKey  
                   AND PD.Status IN ('3', '5')  
                   AND OD.Userdefine02 = @cConsigneeKey  
                   AND ISNULL(PD.CaseID, '') = '')  
   BEGIN  
      SET @nErrNo = 86654  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask4Consig  
      GOTO Quit  
   END  
  
   -- Get Consignee, OrderKey   
   SELECT TOP 1   
      @cNextConsigneeKey = OD.Userdefine02,   
      @cNextOrderKey = O.OrderKey,  
      @c_oFieled10 = PD.SKU  
   FROM dbo.PickDetail PD WITH (NOLOCK)   
   JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)  
   JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
   --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey) -- (ChewKP01)   
   --WHERE LPD.LoadKey = @cLoadKey   -- (ChewKP01)   
   WHERE O.LoadKey = @cLoadKey     
     AND PD.StorerKey = @cStorerKey  
     AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END  
     AND PD.SKU = CASE WHEN @cType = 'UCC' THEN PD.SKU ELSE @cSKU END  
     AND PD.Status IN ('3', '5')  
     AND PD.QTY > 0  
     AND ISNULL(PD.CaseID,'') = ''      
   ORDER BY OD.Userdefine02, O.OrderKey  
  
   IF ISNULL(@cNextConsigneeKey, '') = ''  
   BEGIN  
      SET @nErrNo = 86651  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task  
      GOTO Quit  
   END  
  
   SET @cConsigneeKey = @cNextConsigneeKey  
   SET @cOrderKey = @cNextOrderKey  
  
   -- Get QTY  
   SELECT @nQTY = ISNULL( SUM( PD.QTY), 0)  
   FROM dbo.PickDetail PD WITH (NOLOCK)   
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)  
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
      --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey) -- (ChewKP01)   
   --WHERE LPD.LoadKey = @cLoadKey -- (ChewKP01)   
   WHERE O.LoadKey = @cLoadKey  
      AND PD.StorerKey = @cStorerKey  
      AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END  
      AND PD.SKU = CASE WHEN @cType = 'UCC' THEN @c_oFieled10 ELSE @cSKU END  
      AND O.OrderKey = @cOrderKey  
      AND OD.Userdefine02 = @cConsigneeKey  
  AND PD.Status IN ('3', '5')  
      AND ISNULL(PD.CaseID,'') = ''      
  
   -- Consignee balance count  
   SELECT @nConsCNT_Bal = COUNT( DISTINCT OD.UserDefine02)  
   FROM dbo.PickDetail PD WITH (NOLOCK)   
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)   
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
      --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey) -- (ChewKP01)   
   --WHERE LPD.LoadKey = @cLoadKey -- (ChewKP01)   
   WHERE O.LoadKey = @cLoadKey  
      AND PD.StorerKey = @cStorerKey  
      AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END  
      AND PD.SKU = CASE WHEN @cType = 'UCC' THEN @c_oFieled10 ELSE @cSKU END  
      AND PD.QTY > 0  
      AND PD.Status IN ('3', '5')  
      AND ISNULL(PD.CaseID,'') = ''      
     
   -- Consignee total count  
   SELECT @nConsCNT_Total = COUNT( DISTINCT OD.UserDefine02)  
   FROM dbo.PickDetail PD WITH (NOLOCK)   
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)  
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
      --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)  
   --WHERE LPD.LoadKey = @cLoadKey -- (ChewKP01)   
   WHERE O.LoadKey = @cLoadKey  
      AND PD.StorerKey = @cStorerKey  
      AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END  
      AND PD.SKU = CASE WHEN @cType = 'UCC' THEN @c_oFieled10 ELSE @cSKU END  
      AND PD.QTY > 0   
  
   -- Consignee QTY balance  
   SELECT @nConsQTY_Bal = ISNULL( SUM( PD.QTY), 0)  
   FROM dbo.PickDetail PD WITH (NOLOCK)   
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)  
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
      --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey) -- (ChewKP01)   
   --WHERE LPD.LoadKey = @cLoadKey -- (ChewKP01)   
   WHERE O.LoadKey = @cLoadKey  
      AND PD.StorerKey = @cStorerKey  
      AND PD.OrderKey = @cOrderKey  
      AND OD.Userdefine02 = @cConsigneeKey  
      AND PD.Status IN ('3', '5')  
      AND ISNULL(PD.CaseID,'') = ''      
  
   SET @nConsQTY_Total = 0  
   -- Consignee QTY total  
   DECLARE @curConsQTY_Total CURSOR  
   SET @curConsQTY_Total = CURSOR FOR   
   SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)   
   FROM dbo.PickDetail PD WITH (NOLOCK)   
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)  
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
      --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey) -- (ChewKP01)   
   --WHERE LPD.LoadKey = @cLoadKey -- (ChewKP01)   
   WHERE O.LoadKey = @cLoadKey  
     AND PD.StorerKey = @cStorerKey  
     AND PD.OrderKey = @cOrderKey  
     AND OD.Userdefine02 = @cConsigneeKey  
   GROUP BY PD.SKU  
   OPEN @curConsQTY_Total  
   FETCH NEXT FROM @curConsQTY_Total INTO @cCons_SKU, @nCons_QTY  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      SET @nConsQTY_Total = @nConsQTY_Total + @nCons_QTY  
      FETCH NEXT FROM @curConsQTY_Total INTO @cCons_SKU, @nCons_QTY  
   END  
   CLOSE @curConsQTY_Total  
   DEALLOCATE @curConsQTY_Total  
     
   -- Order QTY balance  
   SET @nOrderQTY_Bal = 0  
   DECLARE @curOrderQTY_Bal CURSOR  
   SET @curOrderQTY_Bal = CURSOR FOR  
   SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)  
   FROM dbo.PickDetail PD WITH (NOLOCK)   
      --JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber) -- (ChewKP01)   
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
      --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey) -- (ChewKP01)   
   --WHERE LPD.LoadKey = @cLoadKey -- (ChewKP01)   
   WHERE O.LoadKey = @cLoadKey   
      AND O.OrderKey = @cOrderKey  
      AND PD.Status IN ('3', '5')  
   AND ISNULL(PD.CaseID,'') = ''      
   GROUP BY PD.SKU  
   OPEN @curOrderQTY_Bal  
   FETCH NEXT FROM @curOrderQTY_Bal INTO @cOrder_SKU, @nOrder_QTY  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      SET @nOrderQTY_Bal = @nOrderQTY_Bal + @nOrder_QTY  
      FETCH NEXT FROM @curOrderQTY_Bal INTO @cOrder_SKU, @nOrder_QTY  
   END  
   CLOSE @curOrderQTY_Bal  
   DEALLOCATE @curOrderQTY_Bal  
  
   SET @nOrderQTY_Total = 0  
   DECLARE @curOrderQTY_Total CURSOR  
   SET @curOrderQTY_Total = CURSOR FOR   
   SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)  
   FROM dbo.PickDetail PD WITH (NOLOCK)   
      --JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber) -- (ChewKP01)   
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
      --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey) -- (ChewKP01)   
   --WHERE LPD.LoadKey = @cLoadKey -- (ChewKP01)   
   WHERE O.LoadKey = @cLoadKey   
      AND O.OrderKey = @cOrderKey     
   GROUP BY PD.SKU  
   OPEN @curOrderQTY_Total  
   FETCH NEXT FROM @curOrderQTY_Total INTO @cOrder_SKU, @nOrder_QTY  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      SET @nOrderQTY_Total = @nOrderQTY_Total + @nOrder_QTY  
      FETCH NEXT FROM @curOrderQTY_Total INTO @cOrder_SKU, @nOrder_QTY  
   END  
   CLOSE @curOrderQTY_Total  
   DEALLOCATE @curOrderQTY_Total  
  
   -- SKU balance  
   SELECT @nSKUQTY_Bal = ISNULL( SUM( PD.QTY), 0)  
   FROM dbo.PickDetail PD WITH (NOLOCK)   
      --JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber) -- (ChewKP01)   
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
      --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey) -- (ChewKP01)   
   --WHERE LPD.LoadKey = @cLoadKey -- (ChewKP01)   
   WHERE O.LoadKey = @cLoadKey  
      AND PD.StorerKey = @cStorerKey  
      AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END  
      AND PD.SKU = CASE WHEN @cType = 'UCC' THEN @c_oFieled10 ELSE @cSKU END  
      AND PD.Status IN ('3', '5')  
      AND ISNULL(PD.CaseID,'') = ''      
  
   -- SKU total  
   SELECT @nSKUQTY_Total = ISNULL( SUM( PD.QTY), 0)  
   FROM dbo.PickDetail PD WITH (NOLOCK)   
      --JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber) -- (ChewKP01)   
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
      --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey) -- (ChewKP01)   
   --WHERE LPD.LoadKey = @cLoadKey -- (ChewKP01)   
   WHERE O.LoadKey = @cLoadKey  
      AND PD.StorerKey = @cStorerKey  
      AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END  
      AND PD.SKU = CASE WHEN @cType = 'UCC' THEN @c_oFieled10 ELSE @cSKU END  
  
   SET @c_oFieled01 = CAST(@nQTY AS NVARCHAR(5))   
   SET @c_oFieled02 = CAST(@nConsCNT_Total AS NVARCHAR(5))  
   SET @c_oFieled03 = CAST(@nConsCNT_Bal AS NVARCHAR(5))  
   SET @c_oFieled04 = CAST(@nConsQTY_Total AS NVARCHAR(10))    --IN00346713  
   SET @c_oFieled05 = CAST(@nConsQTY_Bal AS NVARCHAR(10))      --IN00346713  
   SET @c_oFieled06 = CAST(@nOrderQTY_Total AS NVARCHAR(10))   --IN00346713  
   SET @c_oFieled07 = CAST(@nOrderQTY_Bal AS NVARCHAR(10))     --IN00346713  
   SET @c_oFieled08 = CAST(@nSKUQTY_Total AS NVARCHAR(5))  
   SET @c_oFieled09 = CAST(@nSKUQTY_Bal AS NVARCHAR(5))  

Quit:  
   IF @nStep = 2
     SET @c_oFieled11 = ''
   ELSE
     SET @c_oFieled11 = @cCaseID

END  

GO