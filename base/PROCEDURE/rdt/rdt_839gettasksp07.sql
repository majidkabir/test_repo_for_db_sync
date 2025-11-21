SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************************/
/* Store procedure: rdt_839GetTaskSP07                                                             */
/* Copyright      : LF Logistics                                                                   */
/*                                                                                                 */
/* Date       Rev  Author      Purposes                                                            */
/* 09-12-2022 1.0  Ung         WMS-21244 base on rdt_PickPiece_GetTask                             */
/* 25-05-2023 1.1  Ung         WMS-22391 NEXTLOC no task, loop back skipped LOC, if there is any   */
/* 28-07-2023 1.2  Ung         WMS-23002 Add serial no                                             */
/***************************************************************************************************/

CREATE   PROC [RDT].[rdt_839GetTaskSP07] (
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nStep            INT
   ,@nInputKey        INT
   ,@cFacility        NVARCHAR( 5)
   ,@cStorerKey       NVARCHAR( 15)
   ,@cType            NVARCHAR( 10) -- NEXTSKU / NEXTLOC
   ,@cPickSlipNo      NVARCHAR( 10)
   ,@cPickZone        NVARCHAR( 10)
   ,@nLottableOnPage  INT
   ,@cLOC             NVARCHAR( 10) OUTPUT
   ,@cSKU             NVARCHAR( 20) OUTPUT
   ,@cSKUDescr        NVARCHAR( 60) OUTPUT
   ,@nQTY             INT           OUTPUT
   ,@cDisableQTYField NVARCHAR( 1)  OUTPUT
   ,@cLottableCode    NVARCHAR( 30) OUTPUT
   ,@cLottable01      NVARCHAR( 18) OUTPUT
   ,@cLottable02      NVARCHAR( 18) OUTPUT
   ,@cLottable03      NVARCHAR( 18) OUTPUT
   ,@dLottable04      DATETIME      OUTPUT
   ,@dLottable05      DATETIME      OUTPUT
   ,@cLottable06      NVARCHAR( 30) OUTPUT
   ,@cLottable07      NVARCHAR( 30) OUTPUT
   ,@cLottable08      NVARCHAR( 30) OUTPUT
   ,@cLottable09      NVARCHAR( 30) OUTPUT
   ,@cLottable10      NVARCHAR( 30) OUTPUT
   ,@cLottable11      NVARCHAR( 30) OUTPUT
   ,@cLottable12      NVARCHAR( 30) OUTPUT
   ,@dLottable13      DATETIME      OUTPUT
   ,@dLottable14      DATETIME      OUTPUT
   ,@dLottable15      DATETIME      OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR(250) OUTPUT
   ,@cSuggID          NVARCHAR(20)  OUTPUT --(yeekung03)
   ,@nTtlBalQty       INT           OUTPUT
   ,@nBalQty          INT           OUTPUT
   ,@cSKUSerialNoCapture NVARCHAR(1) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL            NVARCHAR( MAX)
   DECLARE @cSQLParam       NVARCHAR( MAX)
   DECLARE @cSQLCommonFrom  NVARCHAR( MAX)
   DECLARE @cSQLCommonWhere NVARCHAR( MAX)
   DECLARE @cSQLCommonParam NVARCHAR( MAX)

   DECLARE @cTempLottable01 NVARCHAR( 18)
   DECLARE @cTempLottable02 NVARCHAR( 18)
   DECLARE @cTempLottable03 NVARCHAR( 18)
   DECLARE @dTempLottable04 DATETIME
   DECLARE @dTempLottable05 DATETIME
   DECLARE @cTempLottable06 NVARCHAR( 30)
   DECLARE @cTempLottable07 NVARCHAR( 30)
   DECLARE @cTempLottable08 NVARCHAR( 30)
   DECLARE @cTempLottable09 NVARCHAR( 30)
   DECLARE @cTempLottable10 NVARCHAR( 30)
   DECLARE @cTempLottable11 NVARCHAR( 30)
   DECLARE @cTempLottable12 NVARCHAR( 30)
   DECLARE @dTempLottable13 DATETIME
   DECLARE @dTempLottable14 DATETIME
   DECLARE @dTempLottable15 DATETIME
   DECLARE @cTempLottableCode NVARCHAR( 30)
   DECLARE @cGetNextSKU NVARCHAR( 1)

   SET @nErrNo = 0 -- Require if calling GetTask multiple times (NEXTSKU then NEXTLOC)
   SET @cErrMsg = ''

   /***********************************************************************************************
                                              Standard get task
   ***********************************************************************************************/
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 18)
   DECLARE @cSuggAisle  NVARCHAR( 10) = ''
   DECLARE @cSuggLOC    NVARCHAR( 10) = ''
   DECLARE @cSuggSKU    NVARCHAR( 20) = ''
   DECLARE @nSuggQTY    INT = 0
   DECLARE @cCurrAisle         NVARCHAR( 10) = ''
   DECLARE @cCurrLogicalLOC    NVARCHAR( 18) = ''
   DECLARE @cCurrLOC           NVARCHAR( 10)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)

   DECLARE @cSelect  NVARCHAR( MAX)
   DECLARE @cFrom    NVARCHAR( MAX)
   DECLARE @cWhere1  NVARCHAR( MAX)
   DECLARE @cWhere2  NVARCHAR( MAX)
   DECLARE @cGroupBy NVARCHAR( MAX)
   DECLARE @cOrderBy NVARCHAR( MAX)
   DECLARE @cCurrSKU NVARCHAR( 20)

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''

   SET @cCurrLOC = @cLOC
   SET @cCurrSKU = CASE WHEN @cType = 'BALPICK' THEN @cSKU ELSE '' END

   -- Get LOC info
   SELECT 
      @cCurrLogicalLOC = LogicalLocation, 
      @cCurrAisle = LOCAisle
   FROM LOC WITH (NOLOCK) 
   WHERE LOC = @cCurrLOC

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

   /***********************************************************************************************
                                             Built common SQL
   ***********************************************************************************************/
   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      SET @cSQLCommonFrom = 
         ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' + 
            ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' + 
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' 
      SET @cSQLCommonWhere = 
         ' WHERE RKL.PickSlipNo = @cPickSlipNo ' + 
            ' AND PD.QTY > 0 ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.Status < @cPickConfirmStatus ' 
   END
        
   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      SET @cSQLCommonFrom = 
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' 
      SET @cSQLCommonWhere = 
         ' WHERE PD.OrderKey = @cOrderKey ' + 
            ' AND PD.QTY > 0 ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.Status < @cPickConfirmStatus '
   END
      
   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      SET @cSQLCommonFrom = 
         ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' + 
            ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' + 
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) '
      SET @cSQLCommonWhere = 
         ' WHERE LPD.LoadKey = @cLoadKey ' + 
            ' AND PD.QTY > 0 ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.Status < @cPickConfirmStatus '
   END
   
   -- Custom PickSlip
   ELSE
   BEGIN
      SET @cSQLCommonFrom = 
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) '
      SET @cSQLCommonWhere = 
         ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
            ' AND PD.QTY > 0 ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.Status < @cPickConfirmStatus '
   END

   SET @cSQLCommonParam = 
      '@cPickSlipNo        NVARCHAR( 10), ' + 
      '@cOrderKey          NVARCHAR( 10), ' + 
      '@cLoadKey           NVARCHAR( 10), ' + 
      '@cPickConfirmStatus NVARCHAR( 1),  ' + 
      '@cPickZone          NVARCHAR( 10) = '''', ' + 
      '@cLOCAisle          NVARCHAR( 10) = '''', ' + 
      '@cLogicalLOC        NVARCHAR( 10) = '''', ' + 
      '@cLOC               NVARCHAR( 10) = '''', ' + 
      '@cSKU               NVARCHAR( 20) = '''', ' + 
      '@cSuggAisle         NVARCHAR( 10) = '''' OUTPUT, ' +   
      '@cSuggLOC           NVARCHAR( 10) = '''' OUTPUT, ' +   
      '@cSuggSKU           NVARCHAR( 20) = '''' OUTPUT, ' +   
      '@nSuggQTY           INT           = 0    OUTPUT, ' +   
      '@cLottable01        NVARCHAR( 18) = '''' OUTPUT, ' +
      '@cLottable02        NVARCHAR( 18) = '''' OUTPUT, ' +
      '@cLottable03        NVARCHAR( 18) = '''' OUTPUT, ' +
      '@dLottable04        DATETIME      = NULL OUTPUT, ' +
      '@dLottable05        DATETIME      = NULL OUTPUT, ' +
      '@cLottable06        NVARCHAR( 30) = '''' OUTPUT, ' +
      '@cLottable07        NVARCHAR( 30) = '''' OUTPUT, ' +
      '@cLottable08        NVARCHAR( 30) = '''' OUTPUT, ' +
      '@cLottable09        NVARCHAR( 30) = '''' OUTPUT, ' +
      '@cLottable10        NVARCHAR( 30) = '''' OUTPUT, ' +
      '@cLottable11        NVARCHAR( 30) = '''' OUTPUT, ' +
      '@cLottable12        NVARCHAR( 30) = '''' OUTPUT, ' +
      '@dLottable13        DATETIME      = NULL OUTPUT, ' +
      '@dLottable14        DATETIME      = NULL OUTPUT, ' +
      '@dLottable15        DATETIME      = NULL OUTPUT  '

   /***********************************************************************************************
                                           Insert rdtPickPieceLock
   ***********************************************************************************************/
   IF NOT EXISTS( SELECT TOP 1 1 FROM rdt.rdtPickPieceLock WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
   BEGIN
      SET @cSQL = 
         ' INSERT INTO rdt.rdtPickPieceLock (PickSlipNo, PickZone, LOCAisle) ' + 
         ' SELECT @cPickSlipNo, LOC.PickZone, LOC.LOCAisle ' + 
         @cSQLCommonFrom + 
         @cSQLCommonWhere + 
         ' GROUP BY LOC.PickZone, LOC.LOCAisle ' + 
         ' ORDER BY LOC.PickZone, LOC.LOCAisle '

      exec sp_executeSQL @cSQL, @cSQLCommonParam, 
         @cPickSlipNo = @cPickSlipNo, 
         @cOrderKey   = @cOrderKey, 
         @cLoadKey    = @cLoadKey, 
         @cPickConfirmStatus = @cPickConfirmStatus
   END

   /***********************************************************************************************
                                              Get next Zone
   ***********************************************************************************************/
   IF @cType = 'NEXTZONE'
   BEGIN
      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         IF @cPickZone = ''
            SELECT TOP 1
               @cSuggLOC = LOC.LOC,
               @cSuggSKU = PD.SKU,
               @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
            ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
         ELSE
            SELECT TOP 1
               @cSuggLOC = LOC.LOC,
               @cSuggSKU = PD.SKU,
               @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND LOC.PickZone <> @cPickZone
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
            ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
      END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         IF @cPickZone = ''
            SELECT TOP 1
               @cSuggLOC = LOC.LOC,
               @cSuggSKU = PD.SKU,
               @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
            ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
         ELSE
            SELECT TOP 1
               @cSuggLOC = LOC.LOC,
               @cSuggSKU = PD.SKU,
               @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.OrderKey = @cOrderKey
               AND LOC.PickZone <> @cPickZone
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
            ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
      END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         IF @cPickZone = ''
            SELECT TOP 1
               @cSuggLOC = LOC.LOC,
               @cSuggSKU = PD.SKU,
               @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
            ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
         ELSE
            SELECT TOP 1
               @cSuggLOC = LOC.LOC,
               @cSuggSKU = PD.SKU,
               @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE LPD.LoadKey = @cLoadKey
               AND LOC.PickZone <> @cPickZone
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
            ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         IF @cPickZone = ''
            SELECT TOP 1
               @cSuggLOC = LOC.LOC,
               @cSuggSKU = PD.SKU,
               @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
            ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
         ELSE
            SELECT TOP 1
               @cSuggLOC = LOC.LOC,
               @cSuggSKU = PD.SKU,
               @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND LOC.PickZone <> @cPickZone
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cCurrLogicalLOC
               OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
            ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU
      END

      -- Get SKU info
      SELECT
         @cTempLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSuggSKU

      SET @cGetNextSKU = 'N'

      -- Assign to temp
      SET @cTempLottable01 = @cLottable01
      SET @cTempLottable02 = @cLottable02
      SET @cTempLottable03 = @cLottable03
      SET @dTempLottable04 = @dLottable04
      SET @dTempLottable05 = @dLottable05
      SET @cTempLottable06 = @cLottable06
      SET @cTempLottable07 = @cLottable07
      SET @cTempLottable08 = @cLottable08
      SET @cTempLottable09 = @cLottable09
      SET @cTempLottable10 = @cLottable10
      SET @cTempLottable11 = @cLottable11
      SET @cTempLottable12 = @cLottable12
      SET @dTempLottable13 = @dLottable13
      SET @dTempLottable14 = @dLottable14
      SET @dTempLottable15 = @dLottable15
      SET @cTempLottableCode = @cTempLottableCode   -- (james02)

      /************************************** Get QTY and lottables *********************************/
      SET @nSuggQTY = 0

      -- Get lottable filter
      EXEC rdt.rdt_Lottable_GetNextSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @nLottableOnPage, @cTempLottableCode, 'LA',
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @cSelect  OUTPUT,
         @cWhere1  OUTPUT,
         @cWhere2  OUTPUT,
         @cGroupBy OUTPUT,
         @cOrderBy OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         SET @cSQL =
         ' SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
         ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +
         '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +
         '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +
         '    AND PD.QTY > 0 ' +
         '    AND PD.Status <> ''4'' ' +
         '    AND PD.Status < @cStatus ' +
         '    AND LOC.LOC = @cLOC ' +
         '    AND PD.SKU = @cSKU ' +
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +
         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +
         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END

      END
      
      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         SET @cSQL =
         ' SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
         '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         ' WHERE PD.OrderKey = @cOrderKey ' +
         '    AND PD.QTY > 0 ' +
         '    AND PD.Status <> ''4'' ' +
         '    AND PD.Status < @cStatus ' +
         '    AND LOC.LOC = @cLOC ' +
         '    AND PD.SKU = @cSKU ' +
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +
         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +
         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END
      END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         SET @cSQL =
         ' SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
         ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
         '    JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
         '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         ' WHERE LPD.LoadKey = @cLoadKey ' +
         '    AND PD.QTY > 0 ' +
         '    AND PD.Status <> ''4'' ' +
         '    AND PD.Status < @cStatus ' +
         '    AND LOC.LOC = @cLOC ' +
         '    AND PD.SKU = @cSKU ' +
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +
         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +
         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
         '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE PD.PickSlipNo = @cPickSlipNo ' +
         '    AND PD.QTY > 0 ' +
         '    AND PD.Status <> ''4'' ' +
         '    AND PD.Status < @cStatus ' +
         '    AND LOC.LOC = @cLOC ' +
         '    AND PD.SKU = @cSKU ' +
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +
         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +
         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END
      END

      SET @cSQLParam =
         '@cPickSlipNo NVARCHAR( 10) , ' +
         '@cOrderKey   NVARCHAR( 10) , ' +
         '@cLoadKey    NVARCHAR( 10) , ' +
         '@cLOC        NVARCHAR( 10) , ' +
         '@cSKU        NVARCHAR( 20) , ' +
         '@cStatus     NVARCHAR( 1)  , ' +
         '@cPickZone   NVARCHAR( 10) , ' +
         '@nQTY        INT           OUTPUT, ' +
         '@cLottable01 NVARCHAR( 18) OUTPUT, ' +
         '@cLottable02 NVARCHAR( 18) OUTPUT, ' +
         '@cLottable03 NVARCHAR( 18) OUTPUT, ' +
         '@dLottable04 DATETIME      OUTPUT, ' +
         '@dLottable05 DATETIME      OUTPUT, ' +
         '@cLottable06 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable07 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable08 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable09 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable10 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable11 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable12 NVARCHAR( 30) OUTPUT, ' +
         '@dLottable13 DATETIME      OUTPUT, ' +
         '@dLottable14 DATETIME      OUTPUT, ' +
         '@dLottable15 DATETIME      OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @cPickSlipNo = @cPickSlipNo,
         @cOrderKey   = @cOrderKey,
         @cLoadKey    = @cLoadKey,
         @cLOC        = @cSuggLOC,
         @cSKU        = @cSuggSKU,
         @cStatus     = @cPickConfirmStatus,
         @cPickZone   = @cPickZone,
         @nQTY        = @nSuggQTY        OUTPUT,
         @cLottable01 = @cTempLottable01 OUTPUT,
         @cLottable02 = @cTempLottable02 OUTPUT,
         @cLottable03 = @cTempLottable03 OUTPUT,
         @dLottable04 = @dTempLottable04 OUTPUT,
         @dLottable05 = @dTempLottable05 OUTPUT,
         @cLottable06 = @cTempLottable06 OUTPUT,
         @cLottable07 = @cTempLottable07 OUTPUT,
         @cLottable08 = @cTempLottable08 OUTPUT,
         @cLottable09 = @cTempLottable09 OUTPUT,
         @cLottable10 = @cTempLottable10 OUTPUT,
         @cLottable11 = @cTempLottable11 OUTPUT,
         @cLottable12 = @cTempLottable12 OUTPUT,
         @dLottable13 = @dTempLottable13 OUTPUT,
         @dLottable14 = @dTempLottable14 OUTPUT,
         @dLottable15 = @dTempLottable15 OUTPUT

      IF ISNULL( @nSuggQTY, 0) = 0
      BEGIN
         -- Cross dock PickSlip
         IF @cZone IN ('XD', 'LB', 'LP')
         BEGIN
            SET @cSQL =
            ' SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +
            '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +
            '    AND PD.QTY > 0 ' +                 '    AND PD.Status <> ''4'' ' +
            '    AND PD.Status < @cStatus ' +
            '    AND LOC.LOC = @cLOC ' +
            '    AND PD.SKU = @cSKU ' +
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END
         END
         
         -- Discrete PickSlip
         ELSE IF @cOrderKey <> ''
         BEGIN
            SET @cSQL =
            ' SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
            ' WHERE PD.OrderKey = @cOrderKey ' +
            '    AND PD.QTY > 0 ' +
            '    AND PD.Status <> ''4'' ' +
            '    AND PD.Status < @cStatus ' +
            '    AND LOC.LOC = @cLOC ' +
            '    AND PD.SKU = @cSKU ' +
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END
         END

         -- Conso PickSlip
         ELSE IF @cLoadKey <> ''
         BEGIN
            SET @cSQL =
            ' SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
            '    JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
            ' WHERE LPD.LoadKey = @cLoadKey ' +
            '    AND PD.QTY > 0 ' +
            '    AND PD.Status <> ''4'' ' +
            '    AND PD.Status < @cStatus ' +
            '    AND LOC.LOC = @cLOC ' +
            '    AND PD.SKU = @cSKU ' +
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END
         END

         -- Custom PickSlip
         ELSE
         BEGIN
            SET @cSQL =
            '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
            '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +
            '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
            '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
            '    WHERE PD.PickSlipNo = @cPickSlipNo ' +
            '    AND PD.QTY > 0 ' +
            '    AND PD.Status <> ''4'' ' +
            '    AND PD.Status < @cStatus ' +
            '    AND LOC.LOC = @cLOC ' +
            '    AND PD.SKU = @cSKU ' +
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END
         END

         SET @cSQLParam =
            '@cPickSlipNo NVARCHAR( 10) , ' +
            '@cOrderKey   NVARCHAR( 10) , ' +
            '@cLoadKey    NVARCHAR( 10) , ' +
            '@cLOC        NVARCHAR( 10) , ' +
            '@cSKU        NVARCHAR( 20) , ' +
            '@cStatus     NVARCHAR( 1)  , ' +
            '@cPickZone   NVARCHAR( 10) , ' +
            '@nQTY        INT           OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @cPickSlipNo = @cPickSlipNo,
            @cOrderKey   = @cOrderKey,
            @cLoadKey    = @cLoadKey,
            @cLOC        = @cSuggLOC,
            @cSKU        = @cSuggSKU,
            @cStatus     = @cPickConfirmStatus,
            @cPickZone   = @cPickZone,
            @nQTY        = @nSuggQTY        OUTPUT

      END

   END

   /***********************************************************************************************
                                              Get next LOC
   ***********************************************************************************************/
NextLOC: -- For loop back to skipped LOC, after reach last LOC

   IF @cType = 'NEXTLOC'
   BEGIN
      -- Get picker initial sequence, if already picking
      DECLARE @cPickSEQ NVARCHAR( 4) = ''
      SELECT TOP 1 @cPickSEQ = PickSEQ FROM rdt.rdtPickPieceLock WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LockWho = SUSER_SNAME()
      
      -- Calc pick seq (initial pick or new picker join)
      IF @cPickSEQ = ''
      BEGIN
         -- Get picker in ASC and DESC sequence
         DECLARE @cPickSEQInASC  INT
         DECLARE @cPickSEQInDESC INT
         SELECT @cPickSEQInASC = COUNT(1) FROM rdt.rdtPickPieceLock WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LockWho <> '' AND PickSEQ = 'A'
         SELECT @cPickSEQInDESC = COUNT(1) FROM rdt.rdtPickPieceLock WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LockWho <> '' AND PickSEQ = 'D'
         
         IF @cPickSEQInASC <= @cPickSEQInDESC
            SET @cPickSEQ = 'A'
         ELSE
            SET @cPickSEQ = 'D'
      END

      SET @cPickSEQ = CASE WHEN @cPickSEQ = 'A' THEN 'ASC' ELSE 'DESC' END
      SET @cSuggAisle = ''
      SET @cSuggLOC = ''
      SET @cSuggSKU = ''
      
      -- Build suggest LOC
      SET @cSQL = 
         ' SELECT TOP 1 ' + 
              ' @cSuggAisle = LOC.LOCAisle, ' + 
              ' @cSuggLOC = LOC.LOC, ' + 
              ' @cSuggSKU = PD.SKU ' + 
           @cSQLCommonFrom + 
              ' JOIN rdt.rdtPickPieceLock L WITH (NOLOCK) ON (LOC.PickZone = L.PickZone AND LOC.LOCAisle = L.LOCAisle AND L.PickSlipNo = @cPickSlipNo) ' + 
           @cSQLCommonWhere + 
              CASE WHEN @cLOC = '' THEN '' ELSE 
                 ' AND CAST( LOC.LOCAisle AS NCHAR( 10)) + CAST( LOC.LogicalLocation AS NCHAR( 18)) + CAST( LOC.LOC AS NCHAR( 10)) ' + 
                       CASE WHEN @cPickSEQ = 'ASC' THEN '>' ELSE '<' END + 
                     ' CAST( @cLOCAisle AS NCHAR( 10)) + CAST( @cLogicalLOC AS NCHAR( 18)) + CAST( @cLOC AS NCHAR( 10)) ' 
              END + 
              ' AND (L.LockWho = '''' ' + 
              ' OR   L.LockWho = SUSER_SNAME())' + 
              CASE WHEN @cPickZone = '' THEN '' ELSE ' AND LOC.PickZone = @cPickZone ' END + 
         ' ORDER BY ' + 
            ' LOC.LOCAisle ' + @cPickSEQ + ', ' +  
            ' LOC.LogicalLocation ' + @cPickSEQ + ', ' +  
            ' LOC.LOC ' + @cPickSEQ + ', ' +  
            ' PD.StorerKey, ' + 
            ' PD.SKU '
      
      -- Get suggest LOC
      EXEC sp_executeSQL @cSQL, @cSQLCommonParam, 
         @cPickSlipNo = @cPickSlipNo, 
         @cOrderKey   = @cOrderKey, 
         @cLoadKey    = @cLoadKey, 
         @cPickZone   = @cPickZone, 
         @cLOCAisle   = @cCurrAisle, 
         @cLogicalLOC = @cCurrLogicalLOC, 
         @cLOC        = @cCurrLOC, 
         @cSuggLOC    = @cSuggLOC   OUTPUT, 
         @cSuggSKU    = @cSuggSKU   OUTPUT, 
         @cSuggAisle  = @cSuggAisle OUTPUT, 
         @cPickConfirmStatus = @cPickConfirmStatus

      -- No suggest LOC
      IF @cSuggLOC = ''
      BEGIN
         IF @cLOC = ''
            GOTO Quit
         ELSE
         BEGIN
            SET @cLOC = '' -- For Loop back to skipped LOC
            GOTO NextLOC
         END
      END
      
      -- Lock aisle
      IF @cSuggLOC <> ''
      BEGIN
         DECLARE @nRowRef INT = 0
         DECLARE @cLockWho NVARCHAR( 128) = ''

         -- Get lock aisle info
         IF @cPickZone = ''
            SELECT 
               @nRowRef = RowRef, 
               @cLockWho = LockWho
            FROM rdt.rdtPickPieceLock WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
               AND LOCAisle = @cSuggAisle
         ELSE
            SELECT 
               @nRowRef = RowRef, 
               @cLockWho = LockWho
            FROM rdt.rdtPickPieceLock WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
               AND PickZone = @cPickZone
               AND LOCAisle = @cSuggAisle

         -- Check data error
         IF @nRowRef = 0
         BEGIN
            SET @nErrNo = 194652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LockAisleFail
            GOTO Quit
         END
         
         -- Check aisle locked by others
         IF @cLockWho NOT IN ('', SUSER_SNAME())
         BEGIN
            SET @nErrNo = 194653
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LockAisleFail
            GOTO Quit
         END

         -- Lock aisle
         IF @cLockWho = ''
         BEGIN
            UPDATE rdt.rdtPickPieceLock SET
               PickSEQ = LEFT( @cPickSEQ, 1), 
               LockWho = SUSER_SNAME(), 
               LockDate = GETDATE()
            WHERE RowRef = @nRowRef 
               AND LockWho = ''
            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 194654
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LockAisleFail
               GOTO Quit
            END
         END
      END

      -- Get SKU info
      SELECT @cTempLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSuggSKU

      -- Assign to temp
      SET @cTempLottable01 = @cLottable01
      SET @cTempLottable02 = @cLottable02
      SET @cTempLottable03 = @cLottable03
      SET @dTempLottable04 = @dLottable04
      SET @dTempLottable05 = @dLottable05
      SET @cTempLottable06 = @cLottable06
      SET @cTempLottable07 = @cLottable07
      SET @cTempLottable08 = @cLottable08
      SET @cTempLottable09 = @cLottable09
      SET @cTempLottable10 = @cLottable10
      SET @cTempLottable11 = @cLottable11
      SET @cTempLottable12 = @cLottable12
      SET @dTempLottable13 = @dLottable13
      SET @dTempLottable14 = @dLottable14
      SET @dTempLottable15 = @dLottable15

      /************************************** Get QTY and lottables *********************************/
      -- Get lottable filter
      EXEC rdt.rdt_Lottable_GetNextSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @nLottableOnPage, @cTempLottableCode, 'LA',
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @cSelect  OUTPUT,
         @cWhere1  OUTPUT,
         @cWhere2  OUTPUT,
         @cGroupBy OUTPUT,
         @cOrderBy OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      SET @nSuggQTY = 0

      -- Build suggest QTY, lottable
      SET @cSQL = 
         ' SELECT TOP 1 ' + 
            ' @nSuggQTY = ISNULL( SUM( PD.QTY), 0) ' +
              CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
           @cSQLCommonFrom + 
            ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
           @cSQLCommonWhere + 
            ' AND LOC.LOC = @cLOC ' +
            ' AND PD.SKU = @cSKU ' +
              CASE WHEN @cPickZone = '' THEN '' ELSE ' AND LOC.PickZone = @cPickZone ' END + 
              CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
              CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +
              CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
              CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END

      EXEC sp_ExecuteSQL @cSQL, @cSQLCommonParam,
         @cPickSlipNo = @cPickSlipNo,
         @cOrderKey   = @cOrderKey,
         @cLoadKey    = @cLoadKey,
         @cLOC        = @cSuggLOC,
         @cSKU        = @cSuggSKU,
         @cPickZone   = @cPickZone,
         @nSuggQTY    = @nSuggQTY        OUTPUT,
         @cLottable01 = @cTempLottable01 OUTPUT,
         @cLottable02 = @cTempLottable02 OUTPUT,
         @cLottable03 = @cTempLottable03 OUTPUT,
         @dLottable04 = @dTempLottable04 OUTPUT,
         @dLottable05 = @dTempLottable05 OUTPUT,
         @cLottable06 = @cTempLottable06 OUTPUT,
         @cLottable07 = @cTempLottable07 OUTPUT,
         @cLottable08 = @cTempLottable08 OUTPUT,
         @cLottable09 = @cTempLottable09 OUTPUT,
         @cLottable10 = @cTempLottable10 OUTPUT,
         @cLottable11 = @cTempLottable11 OUTPUT,
         @cLottable12 = @cTempLottable12 OUTPUT,
         @dLottable13 = @dTempLottable13 OUTPUT,
         @dLottable14 = @dTempLottable14 OUTPUT,
         @dLottable15 = @dTempLottable15 OUTPUT,
         @cPickConfirmStatus = @cPickConfirmStatus
   END
   
   /***********************************************************************************************
                                              Get next SKU
   ***********************************************************************************************/
   ELSE IF @cType IN ( 'NEXTSKU', 'BALPICK')
   BEGIN
      SET @cSuggLOC = @cCurrLOC

      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         IF @cPickZone = ''
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)      --INC0720911
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND (( @cType = 'BALPICK' AND PD.SKU > @cCurrSKU) OR
                    ( @cType = 'NEXTSKU' AND PD.SKU = PD.SKU))
            --GROUP BY PD.StorerKey, PD.SKU
            ORDER BY PD.StorerKey, PD.SKU
         ELSE
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)    --INC0720911
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND LOC.PickZone = @cPickZone
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND (( @cType = 'BALPICK' AND PD.SKU > @cCurrSKU) OR
                    ( @cType = 'NEXTSKU' AND PD.SKU = PD.SKU))
            --GROUP BY PD.StorerKey, PD.SKU
            ORDER BY PD.StorerKey, PD.SKU
      END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         IF @cPickZone = ''
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)    --INC0720911
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND (( @cType = 'BALPICK' AND PD.SKU > @cCurrSKU) OR
                    ( @cType = 'NEXTSKU' AND PD.SKU = PD.SKU))
            --GROUP BY PD.StorerKey, PD.SKU
            ORDER BY PD.StorerKey, PD.SKU
         ELSE
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)      --INC0720911
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.OrderKey = @cOrderKey
               AND LOC.PickZone = @cPickZone
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND (( @cType = 'BALPICK' AND PD.SKU > @cCurrSKU) OR
                    ( @cType = 'NEXTSKU' AND PD.SKU = PD.SKU))
            --GROUP BY PD.StorerKey, PD.SKU
            ORDER BY PD.StorerKey, PD.SKU
      END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         IF @cPickZone = ''
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)      --INC0720911
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND (( @cType = 'BALPICK' AND PD.SKU > @cCurrSKU) OR
                    ( @cType = 'NEXTSKU' AND PD.SKU = PD.SKU))
            --GROUP BY PD.StorerKey, PD.SKU
            ORDER BY PD.StorerKey, PD.SKU
         ELSE
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)      --INC0720911
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE LPD.LoadKey = @cLoadKey
               AND LOC.PickZone = @cPickZone
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND (( @cType = 'BALPICK' AND PD.SKU > @cCurrSKU) OR
                    ( @cType = 'NEXTSKU' AND PD.SKU = PD.SKU))
            --GROUP BY PD.StorerKey, PD.SKU
            ORDER BY PD.StorerKey, PD.SKU
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         IF @cPickZone = ''
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)  --INC0720911
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND (( @cType = 'BALPICK' AND PD.SKU > @cCurrSKU) OR
                    ( @cType = 'NEXTSKU' AND PD.SKU = PD.SKU))
               --GROUP BY PD.StorerKey, PD.SKU
               ORDER BY PD.StorerKey, PD.SKU
         ELSE
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)  --INC0720911
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND LOC.PickZone = @cPickZone
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND (( @cType = 'BALPICK' AND PD.SKU > @cCurrSKU) OR
                    ( @cType = 'NEXTSKU' AND PD.SKU = PD.SKU))
               --GROUP BY PD.StorerKey, PD.SKU
               ORDER BY PD.StorerKey, PD.SKU
      END

      -- Get SKU info
      SELECT
         @cTempLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSuggSKU

      SET @cGetNextSKU = 'N'

      -- Assign to temp
      SET @cTempLottable01 = @cLottable01
      SET @cTempLottable02 = @cLottable02
      SET @cTempLottable03 = @cLottable03
      SET @dTempLottable04 = @dLottable04
      SET @dTempLottable05 = @dLottable05
      SET @cTempLottable06 = @cLottable06
      SET @cTempLottable07 = @cLottable07
      SET @cTempLottable08 = @cLottable08
      SET @cTempLottable09 = @cLottable09
      SET @cTempLottable10 = @cLottable10
      SET @cTempLottable11 = @cLottable11
      SET @cTempLottable12 = @cLottable12
      SET @dTempLottable13 = @dLottable13
      SET @dTempLottable14 = @dLottable14
      SET @dTempLottable15 = @dLottable15
      SET @cTempLottableCode = @cTempLottableCode   -- (james02)

      /************************************** Get QTY and lottables *********************************/
      SET @nSuggQTY = 0
      SET @cSKU =  @cSuggSKU  --INC0720911

      -- Get lottable filter
      EXEC rdt.rdt_Lottable_GetNextSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @nLottableOnPage, @cTempLottableCode, 'LA',
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @cSelect  OUTPUT,
         @cWhere1  OUTPUT,
         @cWhere2  OUTPUT,
         @cGroupBy OUTPUT,
         @cOrderBy OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
         '    FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +
         '       JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE RKL.PickSlipNo = @cPickSlipNo ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
         '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +
         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +
         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END
      END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
         '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE PD.OrderKey = @cOrderKey ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
         '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +
         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +
         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END
      END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
         '    FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
         '       JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE LPD.LoadKey = @cLoadKey ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
   '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +
         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +
         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
         '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE PD.PickSlipNo = @cPickSlipNo ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
         '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +
         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +
         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END
      END

      SET @cSQLParam =
         '@cPickSlipNo NVARCHAR( 10) , ' +
         '@cOrderKey   NVARCHAR( 10) , ' +
         '@cLoadKey    NVARCHAR( 10) , ' +
         '@cLOC        NVARCHAR( 10) , ' +
         '@cSKU        NVARCHAR( 20) , ' +
         '@cStatus     NVARCHAR( 1)  , ' +
         '@cPickZone   NVARCHAR( 10) , ' +
         '@nQTY        INT           OUTPUT, ' +
         '@cLottable01 NVARCHAR( 18) OUTPUT, ' +
         '@cLottable02 NVARCHAR( 18) OUTPUT, ' +
         '@cLottable03 NVARCHAR( 18) OUTPUT, ' +
         '@dLottable04 DATETIME      OUTPUT, ' +
         '@dLottable05 DATETIME      OUTPUT, ' +
         '@cLottable06 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable07 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable08 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable09 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable10 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable11 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable12 NVARCHAR( 30) OUTPUT, ' +
         '@dLottable13 DATETIME      OUTPUT, ' +
         '@dLottable14 DATETIME      OUTPUT, ' +
         '@dLottable15 DATETIME      OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @cPickSlipNo = @cPickSlipNo,
         @cOrderKey   = @cOrderKey,
         @cLoadKey    = @cLoadKey,
         @cLOC        = @cSuggLOC,
         @cSKU        = @cSuggSKU,
         @cStatus     = @cPickConfirmStatus,
         @cPickZone   = @cPickZone,
         @nQTY        = @nSuggQTY        OUTPUT,
         @cLottable01 = @cTempLottable01 OUTPUT,
         @cLottable02 = @cTempLottable02 OUTPUT,
         @cLottable03 = @cTempLottable03 OUTPUT,
         @dLottable04 = @dTempLottable04 OUTPUT,
         @dLottable05 = @dTempLottable05 OUTPUT,
         @cLottable06 = @cTempLottable06 OUTPUT,
         @cLottable07 = @cTempLottable07 OUTPUT,
         @cLottable08 = @cTempLottable08 OUTPUT,
         @cLottable09 = @cTempLottable09 OUTPUT,
         @cLottable10 = @cTempLottable10 OUTPUT,
         @cLottable11 = @cTempLottable11 OUTPUT,
         @cLottable12 = @cTempLottable12 OUTPUT,
         @dLottable13 = @dTempLottable13 OUTPUT,
         @dLottable14 = @dTempLottable14 OUTPUT,
         @dLottable15 = @dTempLottable15 OUTPUT

      IF ISNULL( @nSuggQty, 0) = 0
      BEGIN
              -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         '    FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +
         '       JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE RKL.PickSlipNo = @cPickSlipNo ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
         '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END
      END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE PD.OrderKey = @cOrderKey ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
         '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END
      END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         '    FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
         '       JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE LPD.LoadKey = @cLoadKey ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
   '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE PD.PickSlipNo = @cPickSlipNo ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
         '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END
      END

      SET @cSQLParam =
         '@cPickSlipNo NVARCHAR( 10) , ' +
         '@cOrderKey   NVARCHAR( 10) , ' +
         '@cLoadKey    NVARCHAR( 10) , ' +
         '@cLOC        NVARCHAR( 10) , ' +
         '@cSKU        NVARCHAR( 20) , ' +
         '@cStatus     NVARCHAR( 1)  , ' +
         '@cPickZone   NVARCHAR( 10) , ' +
         '@nQTY        INT           OUTPUT '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @cPickSlipNo = @cPickSlipNo,
         @cOrderKey   = @cOrderKey,
         @cLoadKey    = @cLoadKey,
         @cLOC        = @cSuggLOC,
         @cSKU        = @cSuggSKU,
         @cStatus     = @cPickConfirmStatus,
         @cPickZone   = @cPickZone,
         @nQTY        = @nSuggQTY        OUTPUT
      END
   END

   /***********************************************************************************************
                                              Get next SKU
   ***********************************************************************************************/
   ELSE IF @cType IN ('CLOSE')
   BEGIN
      SET @cSuggLOC = @cCurrLOC

      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         IF @cPickZone = ''
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)      --INC0720911
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND PD.SKU = PD.SKU
            --GROUP BY PD.StorerKey, PD.SKU
            ORDER BY PD.StorerKey, PD.SKU
         ELSE
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)    --INC0720911
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND LOC.PickZone = @cPickZone
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND PD.SKU = PD.SKU
            --GROUP BY PD.StorerKey, PD.SKU
            ORDER BY PD.StorerKey, PD.SKU
      END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         IF @cPickZone = ''
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)    --INC0720911
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND PD.SKU = PD.SKU
            --GROUP BY PD.StorerKey, PD.SKU
            ORDER BY PD.StorerKey, PD.SKU
         ELSE
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)      --INC0720911
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.OrderKey = @cOrderKey
               AND LOC.PickZone = @cPickZone
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND PD.SKU = PD.SKU
            --GROUP BY PD.StorerKey, PD.SKU
            ORDER BY PD.StorerKey, PD.SKU
      END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         IF @cPickZone = ''
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)      --INC0720911
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND PD.SKU = PD.SKU
            --GROUP BY PD.StorerKey, PD.SKU
            ORDER BY PD.StorerKey, PD.SKU
         ELSE
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)      --INC0720911
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE LPD.LoadKey = @cLoadKey
               AND LOC.PickZone = @cPickZone
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND PD.SKU = PD.SKU
            --GROUP BY PD.StorerKey, PD.SKU
            ORDER BY PD.StorerKey, PD.SKU
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         IF @cPickZone = ''
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)  --INC0720911
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND PD.SKU = PD.SKU
               --GROUP BY PD.StorerKey, PD.SKU
               ORDER BY PD.StorerKey, PD.SKU
         ELSE
            SELECT TOP 1
               @cSuggSKU = PD.SKU
               --@nSuggQTY = ISNULL( SUM( PD.QTY), 0)  --INC0720911
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND LOC.PickZone = @cPickZone
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND LOC.LOC = @cCurrLOC
               AND PD.SKU = PD.SKU
            ORDER BY PD.StorerKey, PD.SKU
      END

      -- Get SKU info
      SELECT
         @cTempLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSuggSKU

      SET @cGetNextSKU = 'N'

      -- Assign to temp
      SET @cTempLottable01 = @cLottable01
      SET @cTempLottable02 = @cLottable02
      SET @cTempLottable03 = @cLottable03
      SET @dTempLottable04 = @dLottable04
      SET @dTempLottable05 = @dLottable05
      SET @cTempLottable06 = @cLottable06
      SET @cTempLottable07 = @cLottable07
      SET @cTempLottable08 = @cLottable08
      SET @cTempLottable09 = @cLottable09
      SET @cTempLottable10 = @cLottable10
      SET @cTempLottable11 = @cLottable11
      SET @cTempLottable12 = @cLottable12
      SET @dTempLottable13 = @dLottable13
      SET @dTempLottable14 = @dLottable14
      SET @dTempLottable15 = @dLottable15
      SET @cTempLottableCode = @cTempLottableCode   -- (james02)

      /************************************** Get QTY and lottables *********************************/
      SET @nSuggQTY = 0
      SET @cSKU =  @cSuggSKU  --INC0720911

      -- Get lottable filter
      EXEC rdt.rdt_Lottable_GetNextSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @nLottableOnPage, @cTempLottableCode, 'LA',
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @cSelect  OUTPUT,
         @cWhere1  OUTPUT,
         @cWhere2  OUTPUT,
         @cGroupBy OUTPUT,
         @cOrderBy OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
         '    FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +
         '       JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE RKL.PickSlipNo = @cPickSlipNo ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
         '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +
         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +
         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END
      END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
         '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE PD.OrderKey = @cOrderKey ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
         '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +
         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +
         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END
      END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
         '    FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
         '       JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE LPD.LoadKey = @cLoadKey ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
   '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +
         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +
         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
         '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE PD.PickSlipNo = @cPickSlipNo ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
         '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +
         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +
         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END
      END

      SET @cSQLParam =
         '@cPickSlipNo NVARCHAR( 10) , ' +
         '@cOrderKey   NVARCHAR( 10) , ' +
         '@cLoadKey    NVARCHAR( 10) , ' +
         '@cLOC        NVARCHAR( 10) , ' +
         '@cSKU        NVARCHAR( 20) , ' +
         '@cStatus     NVARCHAR( 1)  , ' +
         '@cPickZone   NVARCHAR( 10) , ' +
         '@nQTY        INT           OUTPUT, ' +
         '@cLottable01 NVARCHAR( 18) OUTPUT, ' +
         '@cLottable02 NVARCHAR( 18) OUTPUT, ' +
         '@cLottable03 NVARCHAR( 18) OUTPUT, ' +
         '@dLottable04 DATETIME      OUTPUT, ' +
         '@dLottable05 DATETIME      OUTPUT, ' +
         '@cLottable06 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable07 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable08 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable09 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable10 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable11 NVARCHAR( 30) OUTPUT, ' +
         '@cLottable12 NVARCHAR( 30) OUTPUT, ' +
         '@dLottable13 DATETIME      OUTPUT, ' +
         '@dLottable14 DATETIME      OUTPUT, ' +
         '@dLottable15 DATETIME      OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @cPickSlipNo = @cPickSlipNo,
         @cOrderKey   = @cOrderKey,
         @cLoadKey    = @cLoadKey,
         @cLOC        = @cSuggLOC,
         @cSKU        = @cSuggSKU,
         @cStatus     = @cPickConfirmStatus,
         @cPickZone   = @cPickZone,
         @nQTY        = @nSuggQTY        OUTPUT,
     @cLottable01 = @cTempLottable01 OUTPUT,
         @cLottable02 = @cTempLottable02 OUTPUT,
         @cLottable03 = @cTempLottable03 OUTPUT,
         @dLottable04 = @dTempLottable04 OUTPUT,
         @dLottable05 = @dTempLottable05 OUTPUT,
         @cLottable06 = @cTempLottable06 OUTPUT,
         @cLottable07 = @cTempLottable07 OUTPUT,
         @cLottable08 = @cTempLottable08 OUTPUT,
         @cLottable09 = @cTempLottable09 OUTPUT,
         @cLottable10 = @cTempLottable10 OUTPUT,
         @cLottable11 = @cTempLottable11 OUTPUT,
         @cLottable12 = @cTempLottable12 OUTPUT,
         @dLottable13 = @dTempLottable13 OUTPUT,
         @dLottable14 = @dTempLottable14 OUTPUT,
         @dLottable15 = @dTempLottable15 OUTPUT

      IF ISNULL( @nSuggQty, 0) = 0
      BEGIN
              -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         '    FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +
         '       JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE RKL.PickSlipNo = @cPickSlipNo ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
         '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END
      END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE PD.OrderKey = @cOrderKey ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
         '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END
      END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         '    FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
         '       JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE LPD.LoadKey = @cLoadKey ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
   '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         SET @cSQL =
         '    SELECT TOP 1 @nQTY = ISNULL( SUM( PD.QTY), 0) ' +
         '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +
         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         '    WHERE PD.PickSlipNo = @cPickSlipNo ' +
         '       AND PD.QTY > 0 ' +
         '       AND PD.Status <> ''4'' ' +
         '       AND PD.Status < @cStatus ' +
         '       AND LOC.LOC = @cLOC ' +
         '       AND PD.SKU = @cSKU ' + --INC0720911
         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END
      END

      SET @cSQLParam =
         '@cPickSlipNo NVARCHAR( 10) , ' +
         '@cOrderKey   NVARCHAR( 10) , ' +
         '@cLoadKey    NVARCHAR( 10) , ' +
         '@cLOC        NVARCHAR( 10) , ' +
         '@cSKU        NVARCHAR( 20) , ' +
         '@cStatus     NVARCHAR( 1)  , ' +
         '@cPickZone   NVARCHAR( 10) , ' +
         '@nQTY        INT           OUTPUT '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @cPickSlipNo = @cPickSlipNo,
         @cOrderKey   = @cOrderKey,
         @cLoadKey    = @cLoadKey,
         @cLOC        = @cSuggLOC,
         @cSKU        = @cSuggSKU,
         @cStatus     = @cPickConfirmStatus,
         @cPickZone   = @cPickZone,
         @nQTY        = @nSuggQTY        OUTPUT
      END
   END

  /***********************************************************************************************
                                              Get Balance task
   ***********************************************************************************************/
   IF @nTtlBalQty = 0
   BEGIN
      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         IF @cPickZone = ''
            SELECT  @nTtlBalQty= SUM(PD.QTY)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.QTY > 0
         ELSE
            SELECT  @nTtlBalQty= SUM(PD.QTY)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND LOC.PickZone = @cPickZone
                  AND PD.QTY > 0
      END
      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         IF @cPickZone = ''
            SELECT  @nTtlBalQty= SUM(PD.QTY)
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.QTY > 0
         ELSE
            SELECT  @nTtlBalQty= SUM(PD.QTY)
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.OrderKey = @cOrderKey
               AND LOC.PickZone = @cPickZone
               AND PD.QTY > 0
      END
       -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         IF @cPickZone = ''
            SELECT  @nTtlBalQty= SUM(PD.QTY)
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
              JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
              JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.QTY > 0
         ELSE
            SELECT  @nTtlBalQty= SUM(PD.QTY)
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE LPD.LoadKey = @cLoadKey
               AND LOC.PickZone = @cPickZone
               AND PD.QTY > 0
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         IF @cPickZone = ''
            SELECT  @nTtlBalQty= SUM(PD.QTY)
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
         ELSE
           SELECT  @nTtlBalQty= SUM(PD.QTY)
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND LOC.PickZone = @cPickZone
               AND PD.QTY > 0
      END
   END

   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      IF @cPickZone = ''
         SELECT  @nBalQty= SUM(PD.QTY)
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               --AND PD.Status <>'4'
               AND PD.Status <@cPickConfirmStatus
      ELSE
         SELECT  @nBalQty= SUM(PD.QTY)
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND LOC.PickZone = @cPickZone
               AND PD.QTY > 0
               --AND PD.Status <>'4'
               AND PD.Status <@cPickConfirmStatus
   END
   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      IF @cPickZone = ''
         SELECT  @nBalQty= SUM(PD.QTY)
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.QTY > 0
            --AND PD.Status <>'4'
            AND PD.Status <@cPickConfirmStatus

      ELSE
         SELECT  @nBalQty= SUM(PD.QTY)
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE PD.OrderKey = @cOrderKey
            AND LOC.PickZone = @cPickZone
            AND PD.QTY > 0
            --AND PD.Status <>'4'
            AND PD.Status <@cPickConfirmStatus
   END
      -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      IF @cPickZone = ''
         SELECT  @nBalQty= SUM(PD.QTY)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.QTY > 0
            --AND PD.Status <>'4'
            AND PD.Status <@cPickConfirmStatus
      ELSE
         SELECT  @nBalQty= SUM(PD.QTY)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE LPD.LoadKey = @cLoadKey
            AND LOC.PickZone = @cPickZone
            AND PD.QTY > 0
            --AND PD.Status <>'4'
            AND PD.Status <@cPickConfirmStatus
   END

   -- Custom PickSlip
   ELSE
   BEGIN
      IF @cPickZone = ''
         SELECT  @nBalQty= SUM(PD.QTY)
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.QTY > 0
            --AND PD.Status <>'4'
            AND PD.Status <@cPickConfirmStatus
      ELSE
         SELECT  @nBalQty= SUM(PD.QTY)
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND LOC.PickZone = @cPickZone
            AND PD.QTY > 0
            --AND PD.Status <>'4'
            AND PD.Status <@cPickConfirmStatus
   END

Quit:
   /***********************************************************************************************
                                              Return task
   ***********************************************************************************************/
   IF ISNULL( @cSuggSKU, '') = ''
   BEGIN
      SET @nErrNo = 194651
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
      SET @nErrNo = -1 -- No more task
   END
   ELSE
   BEGIN
      -- Assign to actual
      SET @cLottable01 = @cTempLottable01
      SET @cLottable02 = @cTempLottable02
      SET @cLottable03 = @cTempLottable03
      SET @dLottable04 = @dTempLottable04
      SET @dLottable05 = @dTempLottable05
      SET @cLottable06 = @cTempLottable06
      SET @cLottable07 = @cTempLottable07
      SET @cLottable08 = @cTempLottable08
      SET @cLottable09 = @cTempLottable09
      SET @cLottable10 = @cTempLottable10
      SET @cLottable11 = @cTempLottable11
      SET @cLottable12 = @cTempLottable12
      SET @dLottable13 = @dTempLottable13
      SET @dLottable14 = @dTempLottable14
      SET @dLottable15 = @dTempLottable15
      SET @cLottableCode = @cTempLottableCode

      SET @cLOC = @cSuggLOC
      SET @cSKU = @cSuggSKU
      SET @nQTY = @nSuggQTY

      -- Get SKU description
      DECLARE @cDispStyleColorSize  NVARCHAR( 20)
      SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)


      --yeekung05
      DECLARE @cDispExtValue  NVARCHAR( 20)
      SET @cDispExtValue = rdt.RDTGetConfig( @nFunc, 'DispExtValues', @cStorerKey)  --(yeekung03)


      IF @cDispStyleColorSize = '0'
         SELECT @cSKUDescr = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

      ELSE IF @cDispStyleColorSize = '1'
         SELECT @cSKUDescr =
            CAST( Style AS NCHAR(20)) +
            CAST( Color AS NCHAR(10)) +
            CAST( Size  AS NCHAR(10))
         FROM SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU

      IF @cDispExtValue ='1' --(yeekung05)
      BEGIN
         DECLARE @cTable NVARCHAR(20)
         DECLARE @cNotes NVARCHAR(MAX)
         DECLARE @cColumnName NVARCHAR(20)

         SELECT @cTable=long,
                @cNotes = notes,
                @cColumnName=udf01
         FROM codelkup (NOLOCK)
         where storerkey=@cStorerKey
         AND LISTNAME='RefColLkup'

        SET @cSQL =
         '    SELECT @cSKUDescr = ' + @cNotes +
         '    FROM dbo.'+@cTable + ' WITH (NOLOCK)' +
         '    WHERE storerkey=@cStorerkey ' +
         '       AND ' + @cColumnName + '= @c' + @cColumnName

         SET @cSQLParam =
            '@cOrderKey   NVARCHAR( 10) , ' +
            '@cStorerkey  NVARCHAR( 20) , ' +
            '@cSKU        NVARCHAR( 20) , ' +
            '@cSKUDescr   NVARCHAR( 60)   '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @cStorerKey = @cStorerKey,
            @cOrderKey   = @cOrderKey,
            @cSKU        = @cSuggSKU,
            @cSKUDescr   = @cSKUDescr        OUTPUT
      END

      -- Get DisableQTYField
      DECLARE @cDisableQTYFieldSP NVARCHAR( 20)
      SET @cDisableQTYFieldSP = rdt.rdtGetConfig( @nFunc, 'DisableQTYFieldSP', @cStorerKey)

      IF @cDisableQTYFieldSP = '0'
         SET @cDisableQTYField = ''
      ELSE IF @cDisableQTYFieldSP = '1'
         SET @cDisableQTYField = '1'
      ELSE
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cPickZone, @cLOC, @cSKU, @nQTY, ' +
               ' @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile          INT,           ' +
               '@nFunc            INT,           ' +
               '@cLangCode        NVARCHAR( 3),  ' +
               '@nStep            INT,           ' +
               '@nInputKey        INT,           ' +
               '@cFacility        NVARCHAR( 5),  ' +
               '@cStorerKey       NVARCHAR( 15), ' +
               '@cPickSlipNo      NVARCHAR( 10), ' +
               '@cPickZone        NVARCHAR( 10), ' +
               '@cLOC             NVARCHAR( 10), ' +
               '@cSKU             NVARCHAR( 20), ' +
               '@nQTY             INT,           ' +
               '@cDisableQTYField NVARCHAR( 1)  OUTPUT, ' +
               '@nErrNo           INT           OUTPUT, ' +
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cPickZone, @cLOC, @cSKU, @nQTY,
               @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         END
      END
   END
END

GO