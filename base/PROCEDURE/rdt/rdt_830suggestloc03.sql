SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_830SuggestLOC03                                          */
/* Copyright      : LFLogistics                                                  */
/*                                                                               */
/* Purpose: Suggest pick LOC                                                     */
/*                                                                               */
/* Called from: rdt_PickSKU_SuggestLOC                                           */
/*                                                                               */
/* Date        Rev  Author      Purposes                                         */
/* 2020-08-24  1.0  YeeKung     WMS14706 - Created                               */
/* 2020-12-27  1.1  YeeKung     WMS-15995 Add PickZone (yeekung01)               */
/*********************************************************************************/

CREATE PROCEDURE [RDT].[rdt_830SuggestLOC03]
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5), 
   @cStorerKey       NVARCHAR( 15),  
   @cPickSlipNo      NVARCHAR( 10), 
   @cPickZone        NVARCHAR( 10),  --(yeekung01)
   @cLOC             NVARCHAR( 10), 
   @cSuggLOC         NVARCHAR( 10) OUTPUT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
 
   DECLARE @cOrderKey   NVARCHAR( 10)  
   DECLARE @cLoadKey    NVARCHAR( 10)  
   DECLARE @cZone       NVARCHAR( 18)  
   DECLARE @cLogicalLOC NVARCHAR( 18)  
   DECLARE @cNewSuggLOC NVARCHAR( 18)  
   DECLARE @cPickConfirmStatus NVARCHAR( 1)  
  
   SET @cOrderKey = ''  
   SET @cLoadKey = ''  
   SET @cZone = ''  
   SET @cNewSuggLOC = ''  
  
   -- Get storer config  
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = '5'  
  
   -- Get loc info  
   SET @cLogicalLOC = ''  
   SELECT @cLogicalLOC = LogicalLocation FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC  
  
   -- Get PickHeader info  
   SELECT TOP 1  
      @cOrderKey = OrderKey,  
      @cLoadKey = ExternOrderKey,  
      @cZone = Zone  
   FROM dbo.PickHeader WITH (NOLOCK)  
   WHERE PickHeaderKey = @cPickSlipNo  
  
   WHILE (1=1)  
   BEGIN  
      -- Cross dock PickSlip  
      IF @cZone IN ('XD', 'LB', 'LP')  
         IF @cPickZone<>''
            SELECT TOP 1  
               @cNewSuggLOC = LOC.LOC  
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE RKL.PickSlipNo = @cPickSlipNo  
               AND PD.QTY > 0  
               AND PD.Status <> '4'  
               AND PD.Status < @cPickConfirmStatus  
               AND PD.UOM<>'1'
               AND (LOC.LogicalLocation > @cLogicalLOC  
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC)) 
               AND   LOC.PickZone=@cPickZone 
            GROUP BY LOC.LogicalLocation, LOC.LOC  
            ORDER BY LOC.LogicalLocation, LOC.LOC  
         ELSE
            SELECT TOP 1  
               @cNewSuggLOC = LOC.LOC  
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE RKL.PickSlipNo = @cPickSlipNo  
               AND PD.QTY > 0  
               AND PD.Status <> '4'  
               AND PD.Status < @cPickConfirmStatus  
               AND PD.UOM<>'1'
               AND (LOC.LogicalLocation > @cLogicalLOC  
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))  
            GROUP BY LOC.LogicalLocation, LOC.LOC  
            ORDER BY LOC.LogicalLocation, LOC.LOC  
     
      -- Discrete PickSlip  
      ELSE IF @cOrderKey <> ''
         IF @cPickZone<>''  
            SELECT TOP 1  
               @cNewSuggLOC = LOC.LOC  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE PD.OrderKey = @cOrderKey  
               AND PD.QTY > 0  
               AND PD.Status <> '4'  
               AND PD.Status < @cPickConfirmStatus 
               AND PD.UOM<>'1' 
               AND (LOC.LogicalLocation > @cLogicalLOC  
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC)) 
               AND   LOC.PickZone=@cPickZone  
            GROUP BY LOC.LogicalLocation, LOC.LOC  
            ORDER BY LOC.LogicalLocation, LOC.LOC  
         ELSE
            SELECT TOP 1  
               @cNewSuggLOC = LOC.LOC  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE PD.OrderKey = @cOrderKey  
               AND PD.QTY > 0  
               AND PD.Status <> '4'  
               AND PD.Status < @cPickConfirmStatus 
               AND PD.UOM<>'1' 
               AND (LOC.LogicalLocation > @cLogicalLOC  
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC)) 
            GROUP BY LOC.LogicalLocation, LOC.LOC  
            ORDER BY LOC.LogicalLocation, LOC.LOC  
                    
      -- Conso PickSlip  
      ELSE IF @cLoadKey <> ''
         IF @cPickZone<>''  
            SELECT TOP 1  
               @cNewSuggLOC = LOC.LOC  
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)      
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE LPD.LoadKey = @cLoadKey    
               AND PD.QTY > 0  
               AND PD.Status <> '4'  
               AND PD.Status < @cPickConfirmStatus 
               AND PD.UOM<>'1' 
               AND (LOC.LogicalLocation > @cLogicalLOC  
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC)) 
               AND   LOC.PickZone=@cPickZone   
            GROUP BY LOC.LogicalLocation, LOC.LOC  
            ORDER BY LOC.LogicalLocation, LOC.LOC  
         ELSE
            SELECT TOP 1  
               @cNewSuggLOC = LOC.LOC  
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)      
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE LPD.LoadKey = @cLoadKey    
               AND PD.QTY > 0  
               AND PD.Status <> '4'  
               AND PD.Status < @cPickConfirmStatus 
               AND PD.UOM<>'1' 
               AND (LOC.LogicalLocation > @cLogicalLOC  
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))   
            GROUP BY LOC.LogicalLocation, LOC.LOC  
            ORDER BY LOC.LogicalLocation, LOC.LOC  
      -- Custom PickSlip  
      ELSE  
         IF @cPickzone<>''
            SELECT TOP 1  
               @cNewSuggLOC = LOC.LOC  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE PD.PickSlipNo = @cPickSlipNo  
               AND PD.QTY > 0  
               AND PD.Status <> '4'  
               AND PD.Status < @cPickConfirmStatus  
               AND PD.UOM<>'1'
               AND (LOC.LogicalLocation > @cLogicalLOC  
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))  
               AND   LOC.PickZone=@cPickZone  
            GROUP BY LOC.LogicalLocation, LOC.LOC  
            ORDER BY LOC.LogicalLocation, LOC.LOC  
         ELSE
            SELECT TOP 1  
               @cNewSuggLOC = LOC.LOC  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE PD.PickSlipNo = @cPickSlipNo  
               AND PD.QTY > 0  
               AND PD.Status <> '4'  
               AND PD.Status < @cPickConfirmStatus  
               AND PD.UOM<>'1'
               AND (LOC.LogicalLocation > @cLogicalLOC  
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))  
            GROUP BY LOC.LogicalLocation, LOC.LOC  
            ORDER BY LOC.LogicalLocation, LOC.LOC  
        
      -- Found suggest LOC  
      IF @cNewSuggLOC <> ''  
         BREAK  
      ELSE  
      BEGIN  
         -- Search from begining again  
         IF @cLOC <> ''  
         BEGIN  
            SET @cLOC = ''  
            SET @cLogicalLOC = ''  
            CONTINUE  
         END     
         ELSE  
         BEGIN  
            SET @nErrNo = 157551  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task  
            SET @nErrNo = -1 -- No more task  
            BREAK  
         END  
      END  
   END  
  
   IF @cNewSuggLOC <> ''  
      SET @cSuggLOC = @cNewSuggLOC 
END

GO