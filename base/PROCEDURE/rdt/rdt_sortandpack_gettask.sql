SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_SortAndPack_GetTask                             */
/* Copyright: IDS                                                       */
/* Purpose: Get statistic                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Ver  Author   Purposes                                    */
/* 2012-10-02 1.0  Ung      SOS257627 Created                           */
/* 2012-11-27 1.1  James    SOS262231-Convert qty using Busr10 (james01)*/
/* 2013-09-26 1.2  James    SOS287522-Exclude qty from manually created */
/*                          orderline (james02)                         */
/* 2018-03-29 1.3  James    Add type REFRESH (james03)                  */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_SortAndPack_GetTask]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR(3) 
   ,@cPackByType     NVARCHAR(10) -- CONSO, BLANK = DISCRETE
   ,@cType           NVARCHAR(4)  -- NEXT = next consignee (conso), next orderkey (discrete). BLANK = current/next consignee (conso), current/next orderkey (discrete)
   ,@cLoadKey        NVARCHAR(10)
   ,@cStorerKey      NVARCHAR(15)
   ,@cSKU            NVARCHAR(20)
   ,@cConsigneeKey   NVARCHAR(15) OUTPUT
   ,@cOrderKey       NVARCHAR(10) OUTPUT
   ,@nQTY            INT      OUTPUT
   ,@nConsCNT_Total  INT      OUTPUT
   ,@nConsCNT_Bal    INT      OUTPUT
   ,@nConsQTY_Total  INT      OUTPUT
   ,@nConsQTY_Bal    INT      OUTPUT
   ,@nOrderQTY_Total INT      OUTPUT
   ,@nOrderQTY_Bal   INT      OUTPUT
   ,@nSKUQTY_Total   INT      OUTPUT
   ,@nSKUQTY_Bal     INT      OUTPUT
   ,@nErrNo          INT      OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0
   SET @cErrMsg = ''

   DECLARE @cNextConsigneeKey NVARCHAR( 15)
   DECLARE @cNextOrderKey     NVARCHAR( 10)
   DECLARE @cCons_SKU         NVARCHAR( 20), 
           @cOrder_SKU        NVARCHAR( 20), 
           @nCons_QTY         INT,
           @nOrder_QTY        INT

   IF @cType = 'REFRESH'
      GOTO Quit

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
            AND PD.Status = '0'
            AND PD.QTY > 0
            AND O.ConsigneeKey > @cConsigneeKey
            AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james02)
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
            AND PD.SKU = @cSKU
            AND PD.Status = '0'
            AND PD.QTY > 0
            AND O.ConsigneeKey >= @cConsigneeKey
            AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james02)
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
            AND PD.Status = '0'
            AND PD.QTY > 0
            AND O.ConsigneeKey + O.OrderKey > @cConsigneeKey + @cOrderKey
            AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james02)
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
            AND PD.SKU = @cSKU
            AND PD.Status = '0'
            AND PD.QTY > 0
            AND O.ConsigneeKey + O.OrderKey >= @cConsigneeKey + @cOrderKey
            AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james02)
         ORDER BY O.ConsigneeKey + O.OrderKey
   END
   
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 77451
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
      AND PD.Status = '0'
      AND O.ConsigneeKey = @cConsigneeKey
      AND O.OrderKey = CASE WHEN @cPackByType = 'CONSO' THEN O.OrderKey ELSE @cOrderKey END
      AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james02)

   -- Consignee balance count
   SELECT @nConsCNT_Bal = COUNT( DISTINCT O.ConsigneeKey)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.Status = '0'
      AND PD.QTY > 0
      --AND O.ConsigneeKey > @cConsigneeKey
   
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
      AND PD.Status = '0'
      AND PD.SKU = @cSKU
      AND PD.OrderKey = @cOrderKey
      AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james02)
      --AND O.ConsigneeKey = @cConsigneeKey

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
      AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james02)
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
         AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james02)
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
         AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james02)
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
      AND PD.Status = '0'
      AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james02)
      --AND O.ConsigneeKey > @cConsigneeKey --Exclude current consignee

   -- SKU total
   SELECT @nSKUQTY_Total = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james02)
      
   IF ISNULL(rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey), '') <> ''
   BEGIN
      EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nQTY OUTPUT
      EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nConsQTY_Bal OUTPUT
      EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nSKUQTY_Bal OUTPUT
      EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nSKUQTY_Total OUTPUT
   END
Quit:

END

GO