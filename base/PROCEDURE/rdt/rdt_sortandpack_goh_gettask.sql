SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_SortAndPack_GOH_GetTask                         */
/* Copyright: IDS                                                       */
/* Purpose: Get statistic                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Ver  Author   Purposes                                    */
/* 2012-10-02 1.0  Ung      SOS257627 Created                           */
/* 2012-11-27 1.1  James    SOS262231-Convert qty using Busr10 (james01)*/
/* 2013-04-26 1.2  James    SOS276422 Use config to filter GOH (james02)*/
/* 2013-05-15 1.3  James    SOS277324 Cater for no suggest sku (james03)*/
/* 2013-09-26 1.4  James    SOS287522-Exclude qty from manually created */
/*                          orderline (james04)                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_SortAndPack_GOH_GetTask]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3) 
   ,@cStorerKey      NVARCHAR( 15)
   ,@cLabelNo        NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20)
   ,@cLoadKey        NVARCHAR( 20)
   ,@cOrderKey       NVARCHAR( 10) 
   ,@nQTY            INT      OUTPUT
   ,@nOrderQTY_Total INT      OUTPUT
   ,@nOrderQTY_Bal   INT      OUTPUT
   ,@nSKUQTY_Total   INT      OUTPUT
   ,@nSKUQTY_Bal     INT      OUTPUT
   ,@nScannedQTY     INT      OUTPUT
   ,@nCtnQTY_Total   INT      OUTPUT
   ,@nUnPickQTY      INT      OUTPUT
   ,@nPickedQTY      INT      OUTPUT
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

   DECLARE   @cOrder_SKU        NVARCHAR( 20), 
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
           
   -- (james02)
   SET @cSortAndPackFilterGOH = ''
   SET @cSortAndPackFilterGOH = rdt.RDTGetConfig( @nFunc, 'SortAndPackFilterGOH', @cStorerKey)

   SET @cConvertQtySP = ''
   SET @cConvertQtySP = rdt.RDTGetConfig( @nFunc, 'ConvertQtySP', @cStorerKey)

   IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConvertQtySP AND type = 'P')    
      SET @cConvertQtySP = ''
         
   -- Get Qty (Total picked qty of sku for current store)
   SELECT @nPickQTY = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
   JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   WHERE PD.OrderKey = @cOrderKey
   AND   PD.StorerKey = @cStorerKey
   AND   PD.SKU = CASE WHEN ISNULL(@cSKU, '') = '' THEN PD.SKU ELSE @cSKU END
   AND   ISNULL( OD.UserDefine04, '') <> 'M'  -- (james04)
   
   -- Get Qty (Total packed qty of sku for current store)
   SELECT @nPackQTY = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK) 
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
   JOIN dbo.PickDetail PID WITH (NOLOCK) ON (PD.Refno = PID.PickDetailKey AND ISNULL(PD.Refno, '') <> '')
   JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PID.OrderKey = OD.OrderKey AND PID.OrderLineNumber = OD.OrderLineNumber)
   WHERE PH.OrderKey = @cOrderKey
   AND   PH.StorerKey = @cStorerKey
   AND   PD.SKU = CASE WHEN ISNULL(@cSKU, '') = '' THEN PD.SKU ELSE @cSKU END
   AND   ISNULL( OD.UserDefine04, '') <> 'M'  -- (james04)

   SET @nQTY = @nPickQTY - @nPackQTY
   SET @nScannedQTY = @nPackQTY

   -- Order QTY balance
   SET @nOrderQTY_Bal = 0
   DECLARE @curOrderQTY_Bal CURSOR
   SET @curOrderQTY_Bal = CURSOR FOR
   SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.OrderKey = @cOrderKey
      AND PD.Status = '0'
      AND O.OrderKey = @cOrderKey
      AND SKU.Measurement = CASE WHEN @cSortAndPackFilterGOH = '1' THEN 'FALSE' ELSE SKU.Measurement END   -- (james02)
      AND ISNULL( OD.UserDefine04, '') <> 'M' -- (james04)
   GROUP BY PD.SKU
   OPEN @curOrderQTY_Bal
   FETCH NEXT FROM @curOrderQTY_Bal INTO @cOrder_SKU, @nOrder_QTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Note: have to convert everytime because 1 orders contain many sku
      -- and convert qty is based on sku
      IF ISNULL(@cConvertQtySP, '') <> ''
      BEGIN
         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQtySP) +     
            ' @cType, @cStorerKey, @cSKU, @nQTY OUTPUT'    
         SET @cSQLParam =    
            '@cType      NVARCHAR( 10), ' +    
            '@cStorerKey NVARCHAR( 15), ' +    
            '@cSKU       NVARCHAR( 20), ' +      
            '@nQTY       INT OUTPUT    ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
            'ToDispQTY', @cStorerkey, @cOrder_SKU, @nOrder_QTY OUTPUT    
      END
--      EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cOrder_SKU, @nOrder_QTY OUTPUT
      SET @nOrderQTY_Bal = @nOrderQTY_Bal + @nOrder_QTY
      FETCH NEXT FROM @curOrderQTY_Bal INTO @cOrder_SKU, @nOrder_QTY
   END
   CLOSE @curOrderQTY_Bal
   DEALLOCATE @curOrderQTY_Bal

   -- Order QTY total
   SET @nOrderQTY_Total = 0
   DECLARE @curOrderQTY_Total CURSOR
   SET @curOrderQTY_Total = CURSOR FOR 
   SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND O.OrderKey = @cOrderKey
      AND SKU.Measurement = CASE WHEN @cSortAndPackFilterGOH = '1' THEN 'FALSE' ELSE SKU.Measurement END   -- (james02)
      AND ISNULL( OD.UserDefine04, '') <> 'M' -- (james04)
   GROUP BY PD.SKU
   OPEN @curOrderQTY_Total
   FETCH NEXT FROM @curOrderQTY_Total INTO @cOrder_SKU, @nOrder_QTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Note: have to convert everytime because 1 orders contain many sku
      -- and convert qty is based on sku
      IF ISNULL(@cConvertQtySP, '') <> ''
      BEGIN
         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQtySP) +     
            ' @cType, @cStorerKey, @cSKU, @nQTY OUTPUT'    
         SET @cSQLParam =    
            '@cType      NVARCHAR( 10), ' +    
            '@cStorerKey NVARCHAR( 15), ' +    
            '@cSKU       NVARCHAR( 20), ' +      
            '@nQTY       INT OUTPUT    ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
            'ToDispQTY', @cStorerkey, @cOrder_SKU, @nOrder_QTY OUTPUT    
      END
--      EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cOrder_SKU, @nOrder_QTY OUTPUT
      SET @nOrderQTY_Total = @nOrderQTY_Total + @nOrder_QTY
      FETCH NEXT FROM @curOrderQTY_Total INTO @cOrder_SKU, @nOrder_QTY
   END
   CLOSE @curOrderQTY_Total
   DEALLOCATE @curOrderQTY_Total

   -- UnPick QTY
   SET @nUnPickQTY = 0
   DECLARE @curUnPickQTY CURSOR
   SET @curUnPickQTY = CURSOR FOR 
   SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND O.OrderKey = @cOrderKey
      AND SKU.Measurement = CASE WHEN @cSortAndPackFilterGOH = '1' THEN 'FALSE' ELSE SKU.Measurement END   -- (james02)
      AND PD.Status = '0'
      AND ISNULL( OD.UserDefine04, '') <> 'M' -- (james04)
   GROUP BY PD.SKU
   OPEN @curUnPickQTY
   FETCH NEXT FROM @curUnPickQTY INTO @cOrder_SKU, @nOrder_QTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Note: have to convert everytime because 1 orders contain many sku
      -- and convert qty is based on sku
      IF ISNULL(@cConvertQtySP, '') <> ''
      BEGIN
         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQtySP) +     
            ' @cType, @cStorerKey, @cSKU, @nQTY OUTPUT'    
         SET @cSQLParam =    
            '@cType      NVARCHAR( 10), ' +    
            '@cStorerKey NVARCHAR( 15), ' +    
            '@cSKU       NVARCHAR( 20), ' +      
            '@nQTY       INT OUTPUT    ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
            'ToDispQTY', @cStorerkey, @cOrder_SKU, @nOrder_QTY OUTPUT    
      END

      SET @nUnPickQTY = @nUnPickQTY + @nOrder_QTY
      FETCH NEXT FROM @curUnPickQTY INTO @cOrder_SKU, @nOrder_QTY
   END
   CLOSE @curUnPickQTY
   DEALLOCATE @curUnPickQTY

   -- Picked QTY
   SET @nPickedQTY = 0
   DECLARE @curPickedQTY CURSOR
   SET @curPickedQTY = CURSOR FOR 
   SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND O.OrderKey = @cOrderKey
      AND SKU.Measurement = CASE WHEN @cSortAndPackFilterGOH = '1' THEN 'FALSE' ELSE SKU.Measurement END   -- (james02)
      AND PD.Status = '5'
      AND ISNULL( OD.UserDefine04, '') <> 'M' -- (james04)
   GROUP BY PD.SKU
   OPEN @curPickedQTY
   FETCH NEXT FROM @curPickedQTY INTO @cOrder_SKU, @nOrder_QTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Note: have to convert everytime because 1 orders contain many sku
      -- and convert qty is based on sku
      IF ISNULL(@cConvertQtySP, '') <> ''
      BEGIN
         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQtySP) +     
            ' @cType, @cStorerKey, @cSKU, @nQTY OUTPUT'    
         SET @cSQLParam =    
            '@cType      NVARCHAR( 10), ' +    
            '@cStorerKey NVARCHAR( 15), ' +    
            '@cSKU       NVARCHAR( 20), ' +      
            '@nQTY       INT OUTPUT    ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
            'ToDispQTY', @cStorerkey, @cOrder_SKU, @nOrder_QTY OUTPUT    
      END

      SET @nPickedQTY = @nPickedQTY + @nOrder_QTY
      FETCH NEXT FROM @curPickedQTY INTO @cOrder_SKU, @nOrder_QTY
   END
   CLOSE @curPickedQTY
   DEALLOCATE @curPickedQTY
   
   -- Get Qty (Total packed qty for current label)
   SET @nCtnQTY_Total = 0
   DECLARE @nCurPackQTY_Total CURSOR
   SET @nCurPackQTY_Total = CURSOR FOR 
   SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PackHeader PH WITH (NOLOCK) 
      JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
   WHERE PH.LoadKey = @cLoadKey
      AND PD.LabelNo = @cLabelNo
      AND SKU.Measurement = CASE WHEN @cSortAndPackFilterGOH = '1' THEN 'FALSE' ELSE SKU.Measurement END   -- (james02)
   GROUP BY PD.SKU
   OPEN @nCurPackQTY_Total
   FETCH NEXT FROM @nCurPackQTY_Total INTO @cCurPack_SKU, @nCurPack_QTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Note: have to convert everytime because 1 orders contain many sku
      -- and convert qty is based on sku
      IF ISNULL(@cConvertQtySP, '') <> ''
      BEGIN
         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQtySP) +     
            ' @cType, @cStorerKey, @cSKU, @nQTY OUTPUT'    
         SET @cSQLParam =    
            '@cType      NVARCHAR( 10), ' +    
            '@cStorerKey NVARCHAR( 15), ' +    
            '@cSKU       NVARCHAR( 20), ' +      
            '@nQTY       INT OUTPUT    ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
            'ToDispQTY', @cStorerkey, @cCurPack_SKU, @nCurPack_QTY OUTPUT    
      END
--      EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cOrder_SKU, @nOrder_QTY OUTPUT
      SET @nCtnQTY_Total = @nCtnQTY_Total + @nCurPack_QTY
      FETCH NEXT FROM @nCurPackQTY_Total INTO @cCurPack_SKU, @nCurPack_QTY
   END
   CLOSE @nCurPackQTY_Total
   DEALLOCATE @nCurPackQTY_Total
   
   -- SKU balance
   SELECT @nSKUQTY_Bal = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.OrderKey = @cOrderKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = CASE WHEN ISNULL(@cSKU, '') = '' THEN PD.SKU ELSE @cSKU END
      AND PD.Status = '0'
      AND ISNULL( OD.UserDefine04, '') <> 'M' -- (james04)
      
   -- SKU total
   SELECT @nSKUQTY_Total = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.OrderKey = @cOrderKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = CASE WHEN ISNULL(@cSKU, '') = '' THEN PD.SKU ELSE @cSKU END
      AND ISNULL( OD.UserDefine04, '') <> 'M' -- (james04)
      
   -- Convert qty    (james02)
   IF @cConvertQtySP <> '' AND ISNULL(@cSKU, '') <> ''
   BEGIN    
      SET @cSQL = 'EXEC ' + RTRIM( @cConvertQtySP) +     
         ' @cType, @cStorerKey, @cSKU, @nQTY OUTPUT'    
      SET @cSQLParam =    
         '@cType      NVARCHAR( 10), ' +    
         '@cStorerKey NVARCHAR( 15), ' +    
         '@cSKU       NVARCHAR( 20), ' +      
         '@nQTY       INT OUTPUT    ' 
          
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
         'ToDispQTY', @cStorerkey, @cSKU, @nQTY OUTPUT    

      SET @cSQL = 'EXEC ' + RTRIM( @cConvertQtySP) +     
         ' @cType, @cStorerKey, @cSKU, @nQTY OUTPUT'    
      SET @cSQLParam =    
         '@cType      NVARCHAR( 10), ' +    
         '@cStorerKey NVARCHAR( 15), ' +    
         '@cSKU       NVARCHAR( 20), ' +      
         '@nQTY       INT OUTPUT    ' 

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
         'ToDispQTY', @cStorerkey, @cSKU, @nSKUQTY_Bal OUTPUT    

      SET @cSQL = 'EXEC ' + RTRIM( @cConvertQtySP) +     
         ' @cType, @cStorerKey, @cSKU, @nQTY OUTPUT'    
      SET @cSQLParam =    
         '@cType      NVARCHAR( 10), ' +    
         '@cStorerKey NVARCHAR( 15), ' +    
         '@cSKU       NVARCHAR( 20), ' +      
         '@nQTY       INT OUTPUT    ' 

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
         'ToDispQTY', @cStorerkey, @cSKU, @nSKUQTY_Total OUTPUT    

      SET @cSQL = 'EXEC ' + RTRIM( @cConvertQtySP) +     
         ' @cType, @cStorerKey, @cSKU, @nQTY OUTPUT'    
      SET @cSQLParam =    
         '@cType      NVARCHAR( 10), ' +    
         '@cStorerKey NVARCHAR( 15), ' +    
         '@cSKU       NVARCHAR( 20), ' +      
         '@nQTY       INT OUTPUT    ' 

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
         'ToDispQTY', @cStorerkey, @cSKU, @nScannedQTY OUTPUT    
   END    

Quit:

END

GO