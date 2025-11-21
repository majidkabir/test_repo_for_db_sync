SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispSortNPackExtInfo                                 */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Decode Label No Scanned                                     */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2012-10-02 1.0  Ung      SOS257627 Created                           */  
/* 2012-11-27 1.1  James    Add SKU.BUSR10 to extended info (james01)   */
/* 2012-12-21 1.2  James    Add extended info2              (james02)   */
/* 2013-10-02 1.3  James    SOS287522-Exclude qty from manually created */
/*                          orderline (james03)                         */
/* 2013-11-20 1.4  James    Add Orderkey to get loc seq (james04)       */
/* 2014-03-21 1.5  TLTING   Bug fix                                     */
/* 2014-04-24 1.6  Chee     Add Additional Error Parameters (Chee01)    */
/* 2014-05-26 1.7  Chee     Add Mobile Parameter (Chee02)               */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispSortNPackExtInfo]  
   @cLoadKey         NVARCHAR(10),  
   @cOrderKey        NVARCHAR(10),  -- (james07)
   @cConsigneeKey    NVARCHAR(15),  
   @cLabelNo         NVARCHAR(20) OUTPUT,  
   @cStorerKey       NVARCHAR(15),  
   @cSKU             NVARCHAR(20),  
   @nQTY             INT,   
   @cExtendedInfo    NVARCHAR(20) OUTPUT,  
   @cExtendedInfo2   NVARCHAR(20) OUTPUT,
   @cLangCode        NVARCHAR(3),           -- (Chee01)
   @bSuccess         INT          OUTPUT,   -- (Chee01)
   @nErrNo           INT          OUTPUT,   -- (Chee01) 
   @cErrMsg          NVARCHAR(20) OUTPUT,   -- (Chee01)
   @nMobile          INT                    -- (Chee02)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @nSKUQTY_Total  INT  
   DECLARE @nSKUQTY_Bal    INT 
   DECLARE @cMeasurement   NVARCHAR(5),   
           @cBUSR10        NVARCHAR(30),
           @cSUSR3         NVARCHAR(20), 
           @cLOC_Seq       NVARCHAR(10)   -- (james04)

   DECLARE @cCons_SKU      NVARCHAR(20), 
           @nCons_QTY      INT 
  
   SET @cExtendedInfo = ''  
   SET @cMeasurement = ''  
  
   -- Get SKU info  
   SELECT @cMeasurement = Measurement, 
          @cBUSR10 = ISNULL(BUSR10, '0')    -- (james01) 
   FROM dbo.SKU WITH (NOLOCK)  
   WHERE StorerKey = @cStorerKey  
      AND SKU = @cSKU  

   IF @cMeasurement IN ('true', 'false') -- True=flatpack, false=GOH  
   BEGIN
      SET @nSKUQTY_Bal = 0
      -- SKU balance. Cater for sku with multi busr10  
      DECLARE @curSKUQTY_Bal CURSOR
      SET @curSKUQTY_Bal = CURSOR FOR 
      SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)  
      FROM dbo.SKU SKU1 WITH (NOLOCK)   
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (SKU1.StorerKey = PD.StorerKey AND SKU1.SKU = PD.SKU) 
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)  
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
      WHERE LPD.LoadKey = @cLoadKey  
         AND O.ConsigneeKey = @cConsigneeKey  
         AND PD.StorerKey = @cStorerKey  
         AND SKU1.Measurement = @cMeasurement  
         AND PD.Status = '0'  
         AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james01)
      GROUP BY PD.SKU
      OPEN @curSKUQTY_Bal
      FETCH NEXT FROM @curSKUQTY_Bal INTO @cCons_SKU, @nCons_QTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cCons_SKU, @nCons_QTY OUTPUT
         SET @nSKUQTY_Bal = @nSKUQTY_Bal + @nCons_QTY
         FETCH NEXT FROM @curSKUQTY_Bal INTO @cCons_SKU, @nCons_QTY
      END
      CLOSE @curSKUQTY_Bal
      DEALLOCATE @curSKUQTY_Bal

      SET @nSKUQTY_Total = 0
      -- SKU total  
      DECLARE @curSKUQTY_Total CURSOR
      SET @curSKUQTY_Total = CURSOR FOR 
      SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)  
      FROM dbo.SKU SKU1 WITH (NOLOCK)   
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (SKU1.StorerKey = PD.StorerKey AND SKU1.SKU = PD.SKU)  
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)  
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
      WHERE LPD.LoadKey = @cLoadKey  
         AND O.ConsigneeKey = @cConsigneeKey  
         AND PD.StorerKey = @cStorerKey  
         AND SKU.Measurement = @cMeasurement  
         AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james03)
      GROUP BY PD.SKU
      OPEN @curSKUQTY_Total
      FETCH NEXT FROM @curSKUQTY_Total INTO @cCons_SKU, @nCons_QTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cCons_SKU, @nCons_QTY OUTPUT
         SET @nSKUQTY_Total = @nSKUQTY_Total + @nCons_QTY
         FETCH NEXT FROM @curSKUQTY_Total INTO @cCons_SKU, @nCons_QTY
      END
      CLOSE @curSKUQTY_Total
      DEALLOCATE @curSKUQTY_Total
      
      SET @cExtendedInfo =   
         CASE WHEN @cMeasurement = 'true' THEN 'FPK' ELSE 'G/S' END + ': ' +   
         CAST( @nSKUQTY_Bal AS NVARCHAR(5)) + '/' + CAST( @nSKUQTY_Total AS NVARCHAR(5)) 
   END  

   IF ISNULL(@cExtendedInfo, '') <> ''
      SET @cExtendedInfo = RTRIM(@cExtendedInfo) + ' U/L: ' + LEFT(@cBUSR10, 5)
   ELSE 
      SET @cExtendedInfo = 'U/L: ' + LEFT(@cBUSR10, 5)
/*
   -- (james02)
   SELECT @cSUSR3 = ISNULL(SUSR3, '')    
   FROM dbo.Storer WITH (NOLOCK)  
   WHERE StorerKey = @cConsigneeKey  
      AND Type = '2'

   SET @cExtendedInfo2 = 'LOC: ' + LEFT(@cSUSR3, 5)
*/
   -- (james04)
   -- Get current loc seq
   IF ISNULL(@cOrderKey, '') <> ''
      SELECT @cLOC_Seq = ISNULL(Userdefine05, '')   
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cOrderKey
   ELSE
      SET @cLOC_Seq = ''

   SET @cExtendedInfo2 = 'LOC: ' + LEFT(@cLOC_Seq, 5)

QUIT:  
END -- End Procedure  

GO