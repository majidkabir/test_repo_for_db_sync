SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_839ExtInfo03                                          */  
/* Copyright      : LFLogistics                                               */
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2019-07-02 1.0  Ung        WMS-9548 Created                                */ 
/* 2022-04-20 1.1  YeeKung    WMS-19311 Add Data capture (yeekung01)          */
/******************************************************************************/  
  
CREATE   PROC [RDT].[rdt_839ExtInfo03] (  
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
  
IF @nFunc = 839 -- Pick piece
BEGIN  
   IF @nAfterStep = 3 -- SKU, QTY
   BEGIN
      DECLARE @cZone          NVARCHAR( 18) = ''
      DECLARE @cLoadKey       NVARCHAR( 10) = ''
      DECLARE @cOrderKey      NVARCHAR( 10) = ''
      DECLARE @nSKUSequence   INT = 0

      -- Get PickHeader info
      SELECT TOP 1
         @cOrderKey = OrderKey,
         @cLoadKey = ExternOrderKey,
         @cZone = Zone
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         SELECT @nSKUSequence = SKUSequence
         FROM
         (
            SELECT PD.SKU, ROW_NUMBER() OVER( ORDER BY MIN( LOC.LOC)) SKUSequence
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.StorerKey = @cStorerKey
               AND PD.QTY > 0
               AND LOC.LocationType IN ('FASTPICK', 'PICK', 'PICK-Piece')
            GROUP BY PD.SKU
            HAVING COUNT( DISTINCT LOC.LocationType) > 1
         ) a
         WHERE a.SKU = @cSKU
      END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         SELECT @nSKUSequence = SKUSequence
         FROM
         (
            SELECT PD.SKU, ROW_NUMBER() OVER( ORDER BY MIN( LOC.LOC)) SKUSequence
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.StorerKey = @cStorerKey
               AND PD.QTY > 0
               AND LOC.LocationType IN ('FASTPICK', 'PICK', 'PICK-Piece')
            GROUP BY PD.SKU
            HAVING COUNT( DISTINCT LOC.LocationType) > 1
         ) a
         WHERE a.SKU = @cSKU
      END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         SELECT @nSKUSequence = SKUSequence
         FROM
         (
            SELECT PD.SKU, ROW_NUMBER() OVER( ORDER BY MIN( LOC.LOC)) SKUSequence
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.StorerKey = @cStorerKey
               AND PD.QTY > 0
               AND LOC.LocationType IN ('FASTPICK', 'PICK', 'PICK-Piece')
            GROUP BY PD.SKU
            HAVING COUNT( DISTINCT LOC.LocationType) > 1
         ) a
         WHERE a.SKU = @cSKU
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         SELECT @nSKUSequence = SKUSequence
         FROM
         (
            SELECT PD.SKU, ROW_NUMBER() OVER( ORDER BY MIN( LOC.LOC)) SKUSequence
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.StorerKey = @cStorerKey
               AND PD.QTY > 0
               AND LOC.LocationType IN ('FASTPICK', 'PICK', 'PICK-Piece')
            GROUP BY PD.SKU
            HAVING COUNT( DISTINCT LOC.LocationType) > 1
         ) a
         WHERE a.SKU = @cSKU
      END

      IF @nSKUSequence > 0
         SET @cExtendedInfo = RIGHT( @cPickSlipNo, 4) + '-' + CAST( @nSKUSequence AS NVARCHAR(5))
      ELSE
         SET @cExtendedInfo = ''
   END   
END  
  
Quit:
 

GO