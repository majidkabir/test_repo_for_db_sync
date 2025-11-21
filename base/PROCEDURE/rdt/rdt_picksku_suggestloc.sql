SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_PickSKU_SuggestLOC                                       */
/* Copyright      : LFLogistics                                                  */
/*                                                                               */
/* Purpose: Suggest pick LOC                                                     */
/*                                                                               */
/* Date        Rev  Author      Purposes                                         */
/* 21-06-2016  1.0  Ung         SOS372037 Created                                */
/* 2017-02-21  1.1  Ung         WMS-1715 Add SkipLOC                             */
/* 2018-05-21  1.2  James       WMS-5005 Bug fix (james01)                       */
/* 2020-12-27  1.3  YeeKung     WMS-15995 Add PickZone (yeekung01)               */
/*********************************************************************************/

CREATE PROCEDURE rdt.rdt_PickSKU_SuggestLOC
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5), 
   @cStorerKey       NVARCHAR( 15),  
   @cPickSlipNo      NVARCHAR( 10), 
   @cPickZone        NVARCHAR( 10), 
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

   -- Get RDT storer configure
   DECLARE @cSuggestLOCSP NVARCHAR(20)
   SET @cSuggestLOCSP = rdt.RDTGetConfig( @nFunc, 'SuggestLOCSP', @cStorerKey)
   IF @cSuggestLOCSP = '0'
      SET @cSuggestLOCSP = ''
   
   /***********************************************************************************************
                                             Custom suggest LOC
   ***********************************************************************************************/
   -- Check confirm SP blank
   IF @cSuggestLOCSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSuggestLOCSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestLOCSP) + 
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cLOC, ' +
            ' @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam = 
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nInputKey     INT,           ' +
            '@cFacility     NVARCHAR( 5),  ' + 
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cPickSlipNo   NVARCHAR( 10), ' +
            '@cPickZone     NVARCHAR( 10), ' + --(yeekung01)
            '@cLOC          NVARCHAR( 10), ' +
            '@cSuggLOC      NVARCHAR( 10) OUTPUT, ' + -- (james01)
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cLOC,  
            @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
      END
      GOTO Quit
   END

   /***********************************************************************************************
                                           Standard suggest LOC
   ***********************************************************************************************/
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
      BEGIN
         IF (@cPickZone<>'')
            SELECT TOP 1
               @cNewSuggLOC = LOC.LOC
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cLogicalLOC
               AND  LOC.PickZone = @cPickZone
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
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
               AND (LOC.LogicalLocation > @cLogicalLOC
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC
            ORDER BY LOC.LogicalLocation, LOC.LOC

      END
   
      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         IF @cPickZone<>''
            SELECT TOP 1
               @cNewSuggLOC = LOC.LOC
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cLogicalLOC
               AND LOC.Pickzone=@cPickZone
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
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
               AND (LOC.LogicalLocation > @cLogicalLOC
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC
            ORDER BY LOC.LogicalLocation, LOC.LOC
      END
                  
      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
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
               AND (LOC.LogicalLocation > @cLogicalLOC
               AND LOC.Pickzone=@cPickZone
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
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
               AND (LOC.LogicalLocation > @cLogicalLOC
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC
            ORDER BY LOC.LogicalLocation, LOC.LOC
      END
      
      -- Custom PickSlip
      ELSE
      BEGIN
         IF @cPickZone<>''
            SELECT TOP 1
               @cNewSuggLOC = LOC.LOC
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cLogicalLOC
               AND LOC.PickZone=@cPickZone
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
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
               AND (LOC.LogicalLocation > @cLogicalLOC
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC
            ORDER BY LOC.LogicalLocation, LOC.LOC
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
            SET @cLogicalLOC = ''
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