SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_830SuggestLOC02                                          */
/* Copyright      : LFLogistics                                                  */
/*                                                                               */
/* Purpose: Suggest pick LOC                                                     */
/*                                                                               */
/* Called from: rdt_PickSKU_SuggestLOC                                           */
/*                                                                               */
/* Date        Rev  Author      Purposes                                         */
/* 2019-01-10  1.0  James       WMS-7521 Created                                 */
/* 2020-01-22  1.1  YeeKung     WMS15995 Add Pickzone (yeekung01)                */  
/*********************************************************************************/

CREATE PROCEDURE [RDT].[rdt_830SuggestLOC02]
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5), 
   @cStorerKey       NVARCHAR( 15),  
   @cPickSlipNo      NVARCHAR( 10), 
   @cPickZone        NVARCHAR( 10), --(yeekung01)
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

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 18)
   DECLARE @cCurrLogicalLOC NVARCHAR( 18)
   DECLARE @cNewSuggLOC NVARCHAR( 18)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cItemClass NVARCHAR( 30)
   DECLARE @cSKU NVARCHAR( 20)

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''
   SET @cNewSuggLOC = ''

   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   -- Get loc info
   SET @cCurrLogicalLOC = ''
   SELECT @cCurrLogicalLOC = LogicalLocation FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC

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
      BEGIN
         IF @cPickZone<>''
            SELECT TOP 1
               @cNewSuggLOC = LOC.LOC, @cItemClass = SKU.ItemClass, @cSKU = PD.SKU
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               AND LOC.PickZone=@cPickZone
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY SKU.ItemClass, LOC.LOC, PD.SKU
            ORDER BY SKU.ItemClass, LOC.LOC, PD.SKU
         ELSE
            SELECT TOP 1
               @cNewSuggLOC = LOC.LOC, @cItemClass = SKU.ItemClass, @cSKU = PD.SKU
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY SKU.ItemClass, LOC.LOC, PD.SKU
            ORDER BY SKU.ItemClass, LOC.LOC, PD.SKU
      END
   
      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         IF @cPickZone<>''
            SELECT TOP 1
               @cNewSuggLOC = LOC.LOC, @cItemClass = SKU.ItemClass, @cSKU = PD.SKU
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               AND LOC.PickZone=@cPickZone
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY SKU.ItemClass, LOC.LOC, PD.SKU
            ORDER BY SKU.ItemClass, LOC.LOC, PD.SKU
         ELSE
            SELECT TOP 1
               @cNewSuggLOC = LOC.LOC, @cItemClass = SKU.ItemClass, @cSKU = PD.SKU
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY SKU.ItemClass, LOC.LOC, PD.SKU
            ORDER BY SKU.ItemClass, LOC.LOC, PD.SKU
      END           
      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         IF @cPickZone<>''
            SELECT TOP 1
               @cNewSuggLOC = LOC.LOC, @cItemClass = SKU.ItemClass, @cSKU = PD.SKU
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU)
            WHERE LPD.LoadKey = @cLoadKey  
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               AND LOC.PickZone=@cPickZone
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY SKU.ItemClass, LOC.LOC, PD.SKU
            ORDER BY SKU.ItemClass, LOC.LOC, PD.SKU
         ELSE
            SELECT TOP 1
               @cNewSuggLOC = LOC.LOC, @cItemClass = SKU.ItemClass, @cSKU = PD.SKU
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU)
            WHERE LPD.LoadKey = @cLoadKey  
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               AND LOC.PickZone=@cPickZone
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY SKU.ItemClass, LOC.LOC, PD.SKU
            ORDER BY SKU.ItemClass, LOC.LOC, PD.SKU
      END
      
      -- Custom PickSlip
      ELSE
      BEGIN
         IF @cPickZone<>''
            SELECT TOP 1
               @cNewSuggLOC = LOC.LOC, @cItemClass = SKU.ItemClass, @cSKU = PD.SKU
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               AND LOC.PickZone=@cPickZone
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY SKU.ItemClass, LOC.LOC, PD.SKU
            ORDER BY SKU.ItemClass, LOC.LOC, PD.SKU
         ELSE
            SELECT TOP 1
               @cNewSuggLOC = LOC.LOC, @cItemClass = SKU.ItemClass, @cSKU = PD.SKU
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.SKU = SKU.SKU)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY SKU.ItemClass, LOC.LOC, PD.SKU
            ORDER BY SKU.ItemClass, LOC.LOC, PD.SKU
      END
      
      -- Found suggest LOC
      IF @cNewSuggLOC <> ''
         BREAK
      ELSE
      BEGIN
         -- Search from begining again
         IF @cLOC <> ''
         BEGIN
            SET @cLOC = ''
            SET @cCurrLogicalLOC = ''
            CONTINUE
         END   
         ELSE
         BEGIN
            SET @nErrNo = 102101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
            SET @nErrNo = -1 -- No more task
            BREAK
         END
      END
   END

   IF @cNewSuggLOC <> ''
      SET @cSuggLOC = @cNewSuggLOC

Quit:

END


GO