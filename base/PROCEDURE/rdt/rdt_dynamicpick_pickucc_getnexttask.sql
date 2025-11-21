SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_DynamicPick_PickUCC_GetNextTask                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next location for Pick And Pack function                */
/*                                                                      */
/* Called from: rdtfnc_DynamicPick_PickAndPack                          */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 20-Mar-2022 1.0  yeekung    	  Created                              */
/************************************************************************/

CREATE PROC [RDT].[rdt_DynamicPick_PickUCC_GetNextTask] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cStorerKey      NVARCHAR( 15),
   @cType           NVARCHAR( 10),
   @cPickSlipNo     NVARCHAR( 20), 
   @cSuggLOC        NVARCHAR( 10)  OUTPUT,
   @cSuggSKU        NVARCHAR( 20)  OUTPUT,
   @nSuggQTY        INT            OUTPUT,
   @cUCCNo          NVARCHAR( 20)  OUTPUT, 
   @nErrNo     	  INT            OUTPUT, 
   @cErrMsg    	  NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max   
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @nRowCount INT,
            @cCurrLOC  NVARCHAR(20)

   DECLARE @cOrderKey   NVARCHAR( 10)    
   DECLARE @cLoadKey    NVARCHAR( 10)    
   DECLARE @cZone       NVARCHAR( 18) 
   DECLARE @cPickConfirmStatus NVARCHAR(1)
   DECLARE @cNextSKU    NVARCHAR(20)

   SET @nErrNo = 0
   SET @cErrMsg = ''

   SET @cCurrLOC = @cSuggLOC

   -- Get logical LOC
   DECLARE @cCurrLogicalLOC NVARCHAR(18)
   SET @cCurrLogicalLOC = ''
   SELECT @cCurrLogicalLOC = LogicalLocation FROM LOC WITH (NOLOCK) WHERE LOC = @cCurrLOC

   SET @cOrderKey = ''    
   SET @cLoadKey = ''    
   SET @cZone = ''    

   -- Get storer config    
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
   IF @cPickConfirmStatus = '0'    
      SET @cPickConfirmStatus = '5'    

   -- Get PickHeader info    
   SELECT TOP 1    
      @cOrderKey = OrderKey,    
      @cLoadKey = ExternOrderKey,    
      @cZone = Zone    
   FROM dbo.PickHeader WITH (NOLOCK)    
   WHERE PickHeaderKey = @cPickSlipNo   

   IF @cType='NextLoc'
   BEGIN

      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         SELECT TOP 1    
            @cSuggLOC = LOC.LOC,     
            @cNextSKU = PD.SKU,     
            @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
            @cUCCNo   = PD.DropID                   
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)    
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE RKL.PickSlipNo = @cPickSlipNo    
            AND PD.QTY > 0    
            AND PD.Status <> '4' 
            AND PD.UOM ='2'
            AND PD.Status < @cPickConfirmStatus    
            AND (LOC.LogicalLocation > ''    
            OR  (LOC.LogicalLocation = '' AND LOC.LOC > ''))    
         GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,PD.DropID    
         ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU  

      END

      -- Discrete PickSlip    
      ELSE IF @cOrderKey <> ''    
      BEGIN   
         SELECT TOP 1    
            @cSuggLOC = LOC.LOC,     
            @cNextSKU = PD.SKU,     
            @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
            @cUCCNo   = DropID   
         FROM dbo.PickDetail PD WITH (NOLOCK)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE PD.OrderKey = @cOrderKey     
            AND PD.QTY > 0    
            AND PD.Status <> '4' 
            AND PD.UOM ='2'
            AND PD.Status < @cPickConfirmStatus    
            AND (LOC.LogicalLocation > @cCurrLogicalLOC    
            OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))    
         GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,PD.DropID 
         ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU  
      END

      -- Conso PickSlip    
      ELSE IF @cLoadKey <> ''
      BEGIN
         SELECT TOP 1    
            @cSuggLOC = LOC.LOC,     
            @cNextSKU = PD.SKU,     
            @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
            @cUCCNo   = DropID 
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)     
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)        
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE LPD.LoadKey = @cLoadKey      
            AND PD.QTY > 0    
            AND PD.Status <> '4'  
            AND PD.UOM ='2'
            AND PD.Status < @cPickConfirmStatus    
            AND (LOC.LogicalLocation > @cCurrLogicalLOC    
            OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))    
         GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,PD.DropID    
         ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU 
      END

      -- Custom PickSlip    
      ELSE    
      BEGIN 
         SELECT TOP 1    
            @cSuggLOC = LOC.LOC,     
            @cNextSKU = PD.SKU,     
            @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
            @cUCCNo   = DropID
         FROM dbo.PickDetail PD WITH (NOLOCK)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE PD.OrderKey = @cOrderKey     
            AND PD.QTY > 0    
            AND PD.Status <> '4' 
            AND PD.UOM ='2'
            AND PD.Status < @cPickConfirmStatus    
            AND (LOC.LogicalLocation > @cCurrLogicalLOC    
            OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))    
         GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,PD.DropID    
         ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU  
      END
   END

   IF @cType='NextSKU'
   BEGIN
      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         SELECT TOP 1    
            @cSuggLOC = LOC.LOC,     
            @cNextSKU = PD.SKU,     
            @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
            @cUCCNo   = DropID
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)    
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE RKL.PickSlipNo = @cPickSlipNo    
            AND PD.QTY > 0    
            AND PD.Status <> '4' 
            AND PD.UOM ='2'
            AND PD.Status < @cPickConfirmStatus    
            AND LOC.LOC = @cCurrLOC   
            AND PD.SKU >= @cSuggSKU
         GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,PD.DropID    
         ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU   
      END

      -- Discrete PickSlip    
      ELSE IF @cOrderKey <> ''    
      BEGIN   
         SELECT TOP 1    
            @cSuggLOC = LOC.LOC,     
            @cNextSKU = PD.SKU,     
            @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
            @cUCCNo   = DropID
         FROM dbo.PickDetail PD WITH (NOLOCK)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE PD.OrderKey = @cOrderKey     
            AND PD.QTY > 0    
            AND PD.Status <> '4' 
            AND PD.UOM ='2'
            AND PD.Status < @cPickConfirmStatus    
            AND LOC.LOC = @cCurrLOC   
            AND PD.SKU >= @cSuggSKU   
         GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,PD.DropID   
         ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU  
      END

      -- Conso PickSlip    
      ELSE IF @cLoadKey <> ''
      BEGIN
         SELECT TOP 1    
            @cSuggLOC = LOC.LOC,     
            @cNextSKU = PD.SKU,     
            @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
            @cUCCNo   = DropID
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)     
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)        
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE LPD.LoadKey = @cLoadKey      
            AND PD.QTY > 0    
            AND PD.Status <> '4'  
            AND PD.UOM ='2'
            AND PD.Status < @cPickConfirmStatus    
            AND LOC.LOC = @cCurrLOC   
            AND PD.SKU >= @cSuggSKU      
         GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,PD.DropID   
         ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU 
      END

      -- Custom PickSlip    
      ELSE    
      BEGIN 
         SELECT TOP 1    
            @cSuggLOC = LOC.LOC,     
            @cNextSKU = PD.SKU,     
            @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
            @cUCCNo   = DropID
         FROM dbo.PickDetail PD WITH (NOLOCK)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE PD.OrderKey = @cOrderKey     
            AND PD.QTY > 0    
            AND PD.Status <> '4' 
            AND PD.UOM ='2'
            AND PD.Status < @cPickConfirmStatus    
            AND LOC.LOC = @cCurrLOC   
            AND PD.SKU >= @cSuggSKU      
         GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,PD.DropID 
         ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU  
      END
   END

   IF ISNULL(@cNextSKU,'') =''
   BEGIN    
      SET @nErrNo = 184551    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task    
      GOTO QUIT
   END 
   ELSE
   BEGIN
      SET @cSuggSKU=@cNextSKU
   END

   
Quit:

END



GO