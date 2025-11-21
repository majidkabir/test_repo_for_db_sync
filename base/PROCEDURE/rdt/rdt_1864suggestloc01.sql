SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_1864SuggestLOC01                                         */
/* Copyright      : Maersk                                                       */
/*                                                                               */
/* Purpose: Suggest pick LOC, with non full pallet, but can be picked entirely   */
/*                                                                               */
/* Date        Rev  Author      Purposes                                         */
/* 13-09-2023  1.0  Ung         WMS-23032 Created                                */
/*********************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1864SuggestLOC01]
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

   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 18)
   DECLARE @cPickFilter NVARCHAR( MAX) = ''
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

   -- Get pick filter
   SELECT @cPickFilter = ISNULL( Long, '')
   FROM CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'PickFilter'
      AND Code = @nFunc 
      AND StorerKey = @cStorerKey
      AND Code2 = @cFacility

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

   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      SET @cSQL = 
         ' SELECT TOP 1 ' + 
            ' @cNewSuggLOC = PD.LOC ' + 
         ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' + 
            ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' + 
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' + 
         ' WHERE RKL.PickSlipNo = @cPickSlipNo ' + 
            CASE WHEN @cPickZone = '' THEN '' ELSE ' AND PD.PickZone = @cPickZone ' END + 
            CASE WHEN @cPickFilter = '' THEN '' ELSE @cPickFilter END + 
            ' AND PD.ID <> '''' ' + 
            ' AND PD.QTY > 0 ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.Status < @cPickConfirmStatus ' + 
            ' AND (LOC.LogicalLocation > @cLogicalLOC ' + 
            ' OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC)) ' + 
         ' GROUP BY LOC.LogicalLocation, PD.LOC, PD.ID ' + 
         ' HAVING SUM( PD.QTY) = ' + 
            ' (SELECT SUM( LLI.QTYAllocated) ' + 
            ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' + 
            ' WHERE LLI.LOC = PD.LOC ' + 
               ' AND LLI.ID = PD.ID ' + 
            ' HAVING SUM( LLI.QTY-LLI.QTYAllocated-LLI.QTYPicked) = 0) ' +  
         ' ORDER BY LOC.LogicalLocation, PD.LOC '
   END

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      SET @cSQL = 
         ' SELECT TOP 1 ' +
            ' @cNewSuggLOC = PD.LOC ' +
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         ' WHERE PD.OrderKey = @cOrderKey ' +
            CASE WHEN @cPickZone = '' THEN '' ELSE ' AND PD.PickZone = @cPickZone ' END + 
            CASE WHEN @cPickFilter = '' THEN '' ELSE @cPickFilter END + 
            ' AND PD.ID <> '''' ' + 
            ' AND PD.QTY > 0 ' +
            ' AND PD.Status <> ''4'' ' +
            ' AND PD.Status < @cPickConfirmStatus ' +
            ' AND (LOC.LogicalLocation > @cLogicalLOC ' +
            ' OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC)) ' +
         ' GROUP BY LOC.LogicalLocation, PD.LOC, PD.ID ' +
         ' HAVING SUM( PD.QTY) = ' + 
            ' (SELECT SUM( LLI.QTYAllocated) ' + 
            ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' + 
            ' WHERE LLI.LOC = PD.LOC ' + 
               ' AND LLI.ID = PD.ID ' + 
            ' HAVING SUM( LLI.QTY-LLI.QTYAllocated-LLI.QTYPicked) = 0) ' +  
         ' ORDER BY LOC.LogicalLocation, PD.LOC '
   END
               
   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      SET @cSQL = 
         ' SELECT TOP 1 ' +
            ' @cNewSuggLOC = PD.LOC ' +
         ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
            ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         ' WHERE LPD.LoadKey = @cLoadKey ' +
            CASE WHEN @cPickZone = '' THEN '' ELSE ' AND PD.PickZone = @cPickZone ' END + 
            CASE WHEN @cPickFilter = '' THEN '' ELSE @cPickFilter END + 
            ' AND PD.ID <> '''' ' + 
            ' AND PD.QTY > 0 ' +
            ' AND PD.Status <> ''4'' ' +
            ' AND PD.Status < @cPickConfirmStatus ' +
            ' AND (LOC.LogicalLocation > @cLogicalLOC ' +
            ' OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC)) ' +
         ' GROUP BY LOC.LogicalLocation, PD.LOC, PD.ID ' +
         ' HAVING SUM( PD.QTY) = ' + 
            ' (SELECT SUM( LLI.QTYAllocated) ' + 
            ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' + 
            ' WHERE LLI.LOC = PD.LOC ' + 
               ' AND LLI.ID = PD.ID ' + 
            ' HAVING SUM( LLI.QTY-LLI.QTYAllocated-LLI.QTYPicked) = 0) ' +  
         ' ORDER BY LOC.LogicalLocation, PD.LOC ' 
   END
   
   -- Custom PickSlip
   ELSE
   BEGIN
      SET @cSQL = 
         ' SELECT TOP 1 ' +
            ' @cNewSuggLOC = PD.LOC ' +
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         ' WHERE PD.PickSlipNo = @cPickSlipNo ' +
            CASE WHEN @cPickZone = '' THEN '' ELSE ' AND PD.PickZone = @cPickZone ' END + 
            CASE WHEN @cPickFilter = '' THEN '' ELSE @cPickFilter END + 
            ' AND PD.ID <> '''' ' + 
            ' AND PD.QTY > 0 ' +
            ' AND PD.Status <> ''4'' ' +
            ' AND PD.Status < @cPickConfirmStatus ' +
            ' AND (LOC.LogicalLocation > @cLogicalLOC ' +
            ' OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC)) ' +
         ' GROUP BY LOC.LogicalLocation, PD.LOC, PD.ID ' +
         ' HAVING SUM( PD.QTY) = ' + 
            ' (SELECT SUM( LLI.QTYAllocated) ' + 
            ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' + 
            ' WHERE LLI.LOC = PD.LOC ' + 
               ' AND LLI.ID = PD.ID ' + 
            ' HAVING SUM( LLI.QTY-LLI.QTYAllocated-LLI.QTYPicked) = 0) ' +  
         ' ORDER BY LOC.LogicalLocation, PD.LOC ' 
   END
   
   SET @cSQLParam = 
      ' @cPickSlipNo          NVARCHAR( 10), ' + 
      ' @cPickZone            NVARCHAR( 10), ' + 
      ' @cOrderKey            NVARCHAR( 10), ' + 
      ' @cLoadKey             NVARCHAR( 10), ' + 
      ' @cPickConfirmStatus   NVARCHAR( 10), ' + 
      ' @cLOC                 NVARCHAR( 10), ' + 
      ' @cLogicalLOC          NVARCHAR( 18), ' + 
      ' @cNewSuggLOC          NVARCHAR( 10) OUTPUT '

   -- Find next LOC
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam
      ,@cPickSlipNo        = @cPickSlipNo
      ,@cPickZone          = @cPickZone
      ,@cOrderKey          = @cOrderKey
      ,@cLoadKey           = @cLoadKey
      ,@cPickConfirmStatus = @cPickConfirmStatus
      ,@cLOC               = @cLOC
      ,@cLogicalLOC        = @cLogicalLOC
      ,@cNewSuggLOC        = @cNewSuggLOC OUTPUT
         
   -- Search from begining again
   IF @cNewSuggLOC = ''
   BEGIN
      SET @cLOC = ''
      SET @cLogicalLOC = ''

      -- Find next LOC
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam
         ,@cPickSlipNo        = @cPickSlipNo
         ,@cPickZone          = @cPickZone
         ,@cOrderKey          = @cOrderKey
         ,@cLoadKey           = @cLoadKey
         ,@cPickConfirmStatus = @cPickConfirmStatus
         ,@cLOC               = @cLOC
         ,@cLogicalLOC        = @cLogicalLOC
         ,@cNewSuggLOC        = @cNewSuggLOC OUTPUT
   END

   -- Return LOC
   IF @cNewSuggLOC = ''
   BEGIN
      SET @nErrNo = 206301
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
      SET @nErrNo = -1 -- No more task
   END
   ELSE
      SET @cSuggLOC = @cNewSuggLOC

Quit:

END

GO