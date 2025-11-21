SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_PickSKU_SuggestID                                        */
/* Copyright      : LFLogistics                                                  */
/*                                                                               */
/* Purpose: Suggest pick ID                                                      */
/*                                                                               */
/* Date        Rev  Author      Purposes                                         */
/* 2017-10-03  1.0  Ung         WMS-3052 Created                                 */
/* 2020-01-22  1.1  YeeKung     WMS15995 Add Pickzone (yeekung01)                */
/*********************************************************************************/

CREATE PROCEDURE rdt.rdt_PickSKU_SuggestID
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
   @cSuggID          NVARCHAR( 18) OUTPUT, 
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
   DECLARE @cSuggestIDSP NVARCHAR(20)
   SET @cSuggestIDSP = rdt.RDTGetConfig( @nFunc, 'SuggestIDSP', @cStorerKey)
   IF @cSuggestIDSP = '0'
      SET @cSuggestIDSP = ''
   
   /***********************************************************************************************
                                             Custom suggest ID
   ***********************************************************************************************/
   -- Check confirm SP blank
   IF @cSuggestIDSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSuggestIDSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestIDSP) + 
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cLOC, ' +
            ' @cSuggID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam = 
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nInputKey     INT,           ' +
            '@cFacility     NVARCHAR( 5),  ' + 
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cPickSlipNo   NVARCHAR( 10), ' +
            '@cPickZone     NVARCHAR( 10), ' +
            '@cLOC          NVARCHAR( 10), ' +
            '@cSuggID      NVARCHAR( 18), ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cLOC,  
            @cSuggID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
      END
      GOTO Quit
   END

   /***********************************************************************************************
                                           Standard suggest ID
   ***********************************************************************************************/
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 18)
   DECLARE @cNewSuggID  NVARCHAR( 18)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''
   SET @cNewSuggID = ''

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

   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      IF @cPickZone<>''
         SELECT TOP 1
            @cNewSuggID = PD.ID
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE RKL.PickSlipNo = @cPickSlipNo
            AND PD.LOC = @cLOC
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
            AND LOC.PickZone=@cPickZone
         ORDER BY PD.ID
      ELSE
         SELECT TOP 1
            @cNewSuggID = PD.ID
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE RKL.PickSlipNo = @cPickSlipNo
            AND PD.LOC = @cLOC
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
         ORDER BY PD.ID
   END

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      IF @cPickZone<>''
         SELECT TOP 1
            @cNewSuggID = PD.ID
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.LOC = @cLOC
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
            AND LOC.PickZone=@cPickZone
         ORDER BY PD.ID
      ELSE
         SELECT TOP 1
            @cNewSuggID = PD.ID
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.LOC = @cLOC
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
         ORDER BY PD.ID
   END
               
   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      IF @cPickZone<>''
         SELECT TOP 1
            @cNewSuggID = PD.ID
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE LPD.LoadKey = @cLoadKey  
            AND PD.LOC = @cLOC
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
            AND LOC.PickZone=@cPickZone
         ORDER BY PD.ID
      ELSE
         SELECT TOP 1
            @cNewSuggID = PD.ID
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE LPD.LoadKey = @cLoadKey  
            AND PD.LOC = @cLOC
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
         ORDER BY PD.ID
   END
   
   -- Custom PickSlip
   ELSE
   BEGIN
      IF @cPickZone<>''
         SELECT TOP 1
            @cNewSuggID = PD.ID
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.LOC = @cLOC
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
            AND LOC.PickZone=@cPickZone --(yeekung01)
         ORDER BY PD.ID
      ELSE
         SELECT TOP 1
            @cNewSuggID = PD.ID
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.LOC = @cLOC
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
         ORDER BY PD.ID
   END
      
   -- Found suggest LOC
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 107251
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
      SET @nErrNo = -1 -- No more task
   END
   ELSE
      SET @cSuggID = @cNewSuggID

Quit:

END

GO