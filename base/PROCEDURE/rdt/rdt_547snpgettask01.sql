SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_547SNPGetTask01                                 */
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
/* 2021-04-01  1.0  James     WMS-15660. Created                        */
/* 2021-08-11  1.1  James     Fix carton closed but system still prompt */
/*                            closed carton labelno (james01)           */
/************************************************************************/

CREATE PROC [RDT].[rdt_547SNPGetTask01] (
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

   SET @nErrNo = 0
   SET @cErrMsg = ''

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
           @cUCCNo            NVARCHAR(20)
           
   IF @cType = 'REFRESH'
      GOTO Quit

   IF @cType = 'UCC'
   BEGIN
      SET @cUCCNo = @c_oFieled10
      
      IF EXISTS ( SELECT 1
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber) 
            JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         WHERE O.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey
            AND PD.DropID = @cUCCNo
            AND PD.QTY > 0
            AND PD.Status IN ('3', '5')
            AND ISNULL(PD.CaseID,'') = ''    
            AND PD.UOM <> '2')
         BEGIN
            SET @nErrNo = 166751
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCCUOM
            GOTO Quit
         END

      SELECT @nConsCNT_Bal = COUNT( DISTINCT O.ConsigneeKey)
      FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      WHERE O.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey
         AND PD.DropID = @cUCCNo
         AND PD.QTY > 0
         AND PD.Status IN ('3', '5')
         AND ISNULL(PD.CaseID,'') = ''    
         AND PD.UOM = '2'

      IF @nConsCNT_Bal <> 1
      BEGIN
         SET @nErrNo = 166752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC
         GOTO Quit
      END
   END
   
   -- Get Consignee, OrderKey
   IF @cPackByType = 'CONSO'
   BEGIN
      IF @cType = 'NEXT' 
         -- Next consignee
         SELECT TOP 1 
            @cNextConsigneeKey = O.ConsigneeKey, 
            @cNextOrderKey = 'CONSO'
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
            JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.[Status] <= '5'
            AND PD.[Status] <> '4'
            AND PD.QTY > 0
            AND PD.CaseID = ''
            AND O.ConsigneeKey > @cConsigneeKey
         ORDER BY O.ConsigneeKey
      ELSE
         -- Same or next consignee
         SELECT TOP 1 
            @cNextConsigneeKey = O.ConsigneeKey, 
            @cNextOrderKey = 'CONSO'
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
            JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey
            AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END
            AND PD.SKU = CASE WHEN @cType = 'UCC' THEN PD.SKU ELSE @cSKU END
            AND PD.[Status] <= '5'
            AND PD.[Status] <> '4'
            AND PD.QTY > 0
            AND PD.CaseID = ''
            AND O.ConsigneeKey >= @cConsigneeKey
         ORDER BY O.ConsigneeKey
   END
   ELSE
   BEGIN
      IF @cType = 'NEXT' 
         -- Next OrderKey
         SELECT TOP 1 
            @cNextConsigneeKey = O.ConsigneeKey, 
            @cNextOrderKey = O.OrderKey
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
            JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.[Status] <= '5'
            AND PD.[Status] <> '4'
            AND PD.QTY > 0
            AND PD.CaseID = ''
            AND O.ConsigneeKey + O.OrderKey > @cConsigneeKey + @cOrderKey
         ORDER BY O.ConsigneeKey + O.OrderKey
     ELSE
         -- Same or next OrderKey
         SELECT TOP 1 
            @cNextConsigneeKey = O.ConsigneeKey, 
            @cNextOrderKey = O.OrderKey
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
            JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey
            AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END
            AND PD.SKU = CASE WHEN @cType = 'UCC' THEN PD.SKU ELSE @cSKU END
            AND PD.[Status] <= '5'
            AND PD.[Status] <> '4'
            AND PD.QTY > 0
            AND PD.CaseID = ''
            AND O.ConsigneeKey + O.OrderKey >= @cConsigneeKey + @cOrderKey
         ORDER BY O.ConsigneeKey + O.OrderKey
   END
   
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 166753
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
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END
      AND PD.SKU = CASE WHEN @cType = 'UCC' THEN PD.SKU ELSE @cSKU END
      AND PD.[Status] <= '5'
      AND PD.[Status] <> '4'
      AND PD.CaseID = ''
      AND O.ConsigneeKey = @cConsigneeKey
      AND O.OrderKey = CASE WHEN @cPackByType = 'CONSO' THEN O.OrderKey ELSE @cOrderKey END

   -- Consignee balance count
   SELECT @nConsCNT_Bal = COUNT( DISTINCT O.ConsigneeKey)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END
      AND PD.SKU = CASE WHEN @cType = 'UCC' THEN PD.SKU ELSE @cSKU END
      AND PD.[Status] <= '5'
      AND PD.[Status] <> '4'
      AND PD.QTY > 0
      AND PD.CaseID = ''
      --AND O.ConsigneeKey > @cConsigneeKey
   
   -- Consignee total count
   SELECT @nConsCNT_Total = COUNT( DISTINCT O.ConsigneeKey)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END
      AND PD.SKU = CASE WHEN @cType = 'UCC' THEN PD.SKU ELSE @cSKU END
      AND PD.QTY > 0

   -- Consignee QTY balance
   SELECT @nConsQTY_Bal = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.[Status] <= '5'
      AND PD.[Status] <> '4'
      AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END
      AND PD.SKU = CASE WHEN @cType = 'UCC' THEN PD.SKU ELSE @cSKU END
      AND PD.OrderKey = @cOrderKey
      AND PD.CaseID = ''

   SET @nConsQTY_Total = 0
   -- Consignee QTY total
   DECLARE @curConsQTY_Total CURSOR
   SET @curConsQTY_Total = CURSOR FOR 
   SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0) 
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND O.ConsigneeKey = @cConsigneeKey
      AND O.OrderKey = @cOrderKey
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
   IF @cPackByType <> 'CONSO'
   BEGIN
      SET @nOrderQTY_Bal = 0
      DECLARE @curOrderQTY_Bal CURSOR
      SET @curOrderQTY_Bal = CURSOR FOR
      SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.Status = '5'
         AND O.OrderKey = @cOrderKey
         AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james02)
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
   END
   
   -- Order QTY total
   IF @cPackByType <> 'CONSO'
   BEGIN
      SET @nOrderQTY_Total = 0
      DECLARE @curOrderQTY_Total CURSOR
      SET @curOrderQTY_Total = CURSOR FOR 
      SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
      WHERE LPD.LoadKey = @cLoadKey
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
   END
   -- SKU balance
   SELECT @nSKUQTY_Bal = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END
      AND PD.SKU = CASE WHEN @cType = 'UCC' THEN PD.SKU ELSE @cSKU END
      AND PD.[Status] <= '5'
      AND PD.[Status] <> '4'
      AND PD.CaseID = ''

   -- SKU total
   SELECT @nSKUQTY_Total = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.DropID = CASE WHEN @cType = 'UCC' THEN @cUCCNo ELSE PD.DropID END
      AND PD.SKU = CASE WHEN @cType = 'UCC' THEN PD.SKU ELSE @cSKU END

   DECLARE @cLabelNo      NVARCHAR( 20) = ''
   DECLARE @cPickSlipNo   NVARCHAR( 10) = ''

   SELECT @cPickSlipNo = PickHeaderKey  
   FROM dbo.PickHeader WITH (NOLOCK)  
   WHERE ExternOrderKey = @cLoadKey  
      AND OrderKey = @cOrderKey  

   IF @cPickSlipNo <> ''
   BEGIN
      SELECT TOP 1 @cLabelNo = LabelNo
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND   NOT EXISTS ( SELECT 1 FROM dbo.Dropid D WITH (NOLOCK)
                         WHERE D.PickSlipNo = PD.PickSlipNo
                         AND   D.Dropid = PD.LabelNo
                         AND   D.LabelPrinted = 'Y')
      ORDER BY 1
      
      -- If carton is closed then reset and generate a new labelno (james01)
      IF EXISTS ( SELECT 1 FROM dbo.Dropid WITH (NOLOCK) 
                  WHERE Dropid = @cLabelNo
                  AND   LabelPrinted = 'Y'
                  AND   [Status] = '9')
         SET @cLabelNo = ''
   END
      
   IF @cLabelNo = ''
   BEGIN
      -- Get new LabelNo
      EXECUTE isp_GenUCCLabelNo
               @cStorerKey,
               @cLabelNo     OUTPUT,
               @bSuccess     OUTPUT,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT

      IF @bSuccess <> 1
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO Quit
      END
   END
   
   SET @c_oFieled01 = CAST(@nQTY AS NVARCHAR(5)) 
   SET @c_oFieled02 = CAST(@nConsCNT_Total AS NVARCHAR(5))
   SET @c_oFieled03 = CAST(@nConsCNT_Bal AS NVARCHAR(5))
   SET @c_oFieled04 = CAST(@nConsQTY_Total AS NVARCHAR(10))    --IN00346713
   SET @c_oFieled05 = CAST(@nConsQTY_Bal AS NVARCHAR(10))      --IN00346713
   SET @c_oFieled06 = CAST(@nOrderQTY_Total AS NVARCHAR(10))   --IN00346713
   SET @c_oFieled07 = CAST(@nOrderQTY_Bal AS NVARCHAR(10))     --IN00346713
   SET @c_oFieled08 = CAST(@nSKUQTY_Total AS NVARCHAR(5))
   SET @c_oFieled09 = CAST(@nSKUQTY_Bal AS NVARCHAR(5))
   IF @cType = 'UCC'
      SELECT TOP 1 @c_oFieled10 = SKU FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cUCCNo AND Storerkey = @cStorerKey ORDER BY 1
   SET @c_oFieled11 = @cLabelNo
Quit:

END

GO