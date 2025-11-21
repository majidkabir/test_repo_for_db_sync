SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_540ExtGetTask03                                 */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Custom sort (ConsigneeKey is numeric, without leading zero) */
/*          Add PickStatus                                              */
/*                                                                      */
/* Date       Ver  Author   Purposes                                    */
/* 2020-06-05 1.0  Ung      WMS-13538 Created                           */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_540ExtGetTask03]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR(  3) 
   ,@cPackByType     NVARCHAR( 10) -- CONSO, BLANK = DISCRETE
   ,@cType           NVARCHAR( 10)  -- NEXT = next consignee (conso), next orderkey (discrete). BLANK = current/next consignee (conso), current/next orderkey (discrete)
   ,@cLoadKey        NVARCHAR( 10)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cSKU            NVARCHAR( 20)
   ,@cConsigneeKey   NVARCHAR( 15)  OUTPUT
   ,@cOrderKey       NVARCHAR( 10)  OUTPUT
   ,@c_oFieled01     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled02     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled03     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled04     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled05     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled06     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled07     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled08     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled09     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled10     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled11     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled12     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled13     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled14     NVARCHAR( 20)  OUTPUT
   ,@c_oFieled15     NVARCHAR( 20)  OUTPUT 
   ,@bSuccess        INT            OUTPUT
   ,@nErrNo          INT            OUTPUT
   ,@cErrMsg         NVARCHAR( 20)  OUTPUT   -- screen limitation, 20 char max

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0
   SET @cErrMsg = ''

   DECLARE @cPickStatus       NVARCHAR( 1)
   DECLARE @cNextConsigneeKey NVARCHAR( 15)
   DECLARE @cNextOrderKey     NVARCHAR( 10)
   DECLARE @cCons_SKU         NVARCHAR( 20), 
           @cOrder_SKU        NVARCHAR( 20), 
           @nCons_QTY         INT,
           @nOrder_QTY        INT, 
           @nQTY              INT,
           @nConsCNT_Bal      INT,
           @nConsCNT_Total    INT,
           @nConsQTY_Bal      INT,
           @nConsQTY_Total    INT,
           @nOrderQTY_Total   INT,
           @nOrderQTY_Bal     INT,
           @nSKUQTY_Bal       INT,
           @nSKUQTY_Total     INT,
           @cUserName         NVARCHAR( 18),
           @nStep             INT

   SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerKey)

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
            AND PD.Status = @cPickStatus
            AND PD.QTY > 0
            AND CAST( O.ConsigneeKey AS INT) > CAST( @cConsigneeKey AS INT)
         ORDER BY CAST( O.ConsigneeKey AS INT)
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
            AND PD.SKU = @cSKU
            AND PD.Status = @cPickStatus
            AND PD.QTY > 0
            AND CAST( O.ConsigneeKey AS INT) >= CAST( @cConsigneeKey AS INT)
         ORDER BY CAST( O.ConsigneeKey AS INT)
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
            AND PD.Status = @cPickStatus
            AND PD.QTY > 0
            AND ((CAST( O.ConsigneeKey AS INT) > CAST( @cConsigneeKey AS INT))
             OR  (O.ConsigneeKey = @cConsigneeKey AND O.OrderKey > @cOrderKey))
         ORDER BY CAST( O.ConsigneeKey AS INT), O.OrderKey
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
            AND PD.SKU = @cSKU
            AND PD.Status = @cPickStatus
            AND PD.QTY > 0
            AND ((CAST( O.ConsigneeKey AS INT) > CAST( @cConsigneeKey AS INT))
             OR  (O.ConsigneeKey = @cConsigneeKey AND O.OrderKey >= @cOrderKey))
         ORDER BY CAST( O.ConsigneeKey AS INT), O.OrderKey
   END
   
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 153601
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
      AND PD.SKU = @cSKU
      AND PD.Status = @cPickStatus
      AND O.ConsigneeKey = @cConsigneeKey
      AND O.OrderKey = CASE WHEN @cPackByType = 'CONSO' THEN O.OrderKey ELSE @cOrderKey END

   -- Consignee balance count
   SELECT @nConsCNT_Bal = COUNT( DISTINCT O.ConsigneeKey)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.Status = @cPickStatus
      AND PD.QTY > 0
   
   -- Consignee total count
   SELECT @nConsCNT_Total = COUNT( DISTINCT O.ConsigneeKey)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.QTY > 0

   -- Consignee QTY balance
   SELECT @nConsQTY_Bal = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.Status = @cPickStatus
      AND PD.SKU = @cSKU
      AND PD.OrderKey = @cOrderKey

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
      EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cCons_SKU, @nCons_QTY OUTPUT
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
      GROUP BY PD.SKU
      OPEN @curOrderQTY_Bal
      FETCH NEXT FROM @curOrderQTY_Bal INTO @cOrder_SKU, @nOrder_QTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cOrder_SKU, @nOrder_QTY OUTPUT
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
         EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cOrder_SKU, @nOrder_QTY OUTPUT
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
      AND PD.SKU = @cSKU
      AND PD.Status = @cPickStatus

   -- SKU total
   SELECT @nSKUQTY_Total = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      
   IF ISNULL(rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey), '') <> ''
   BEGIN
      EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nQTY OUTPUT
      EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nConsQTY_Bal OUTPUT
      EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nSKUQTY_Bal OUTPUT
      EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nSKUQTY_Total OUTPUT
   END
   
   SET @c_oFieled01 = CAST(@nQTY AS NVARCHAR( 5)) 
   SET @c_oFieled02 = CAST(@nConsCNT_Total AS NVARCHAR( 5))
   SET @c_oFieled03 = CAST(@nConsCNT_Bal AS NVARCHAR( 5))
   SET @c_oFieled04 = CAST(@nConsQTY_Total AS NVARCHAR( 5)) 
   SET @c_oFieled05 = CAST(@nConsQTY_Bal AS NVARCHAR( 5))   
   SET @c_oFieled06 = CAST(@nOrderQTY_Total AS NVARCHAR( 5))
   SET @c_oFieled07 = CAST(@nOrderQTY_Bal AS NVARCHAR( 5))
   SET @c_oFieled08 = CAST(@nSKUQTY_Total AS NVARCHAR( 5))
   SET @c_oFieled09 = CAST(@nSKUQTY_Bal AS NVARCHAR( 5))

Quit:

END

GO