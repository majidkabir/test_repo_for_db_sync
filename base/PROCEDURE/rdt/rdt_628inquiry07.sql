SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_628Inquiry07                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Inquiry V7                                                  */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2022-01-05 1.0  James    WMS-18568. Created                          */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_628Inquiry07] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cType           NVARCHAR( 10),
   @cStorerkey      NVARCHAR( 15),
   @cPUOM           NVARCHAR( 1),
   @cInquiry_LOC    NVARCHAR( 10),
   @cInquiry_ID     NVARCHAR( 18),
   @cInquiry_SKU    NVARCHAR( 20),
   @cLOC            NVARCHAR( 10)  OUTPUT,
   @cID             NVARCHAR( 18)  OUTPUT,
   @cSKU            NVARCHAR( 20)  OUTPUT,
   @cSKUDescr       NVARCHAR( 60)  OUTPUT,
   @nTotalRec       INT            OUTPUT,
   @nMQTY_TTL       INT            OUTPUT,
   @nMQTY_PMV       INT            OUTPUT,
   @nMQTY_Alloc     INT            OUTPUT,
   @nMQTY_Pick      INT            OUTPUT,
   @nMQTY_RPL       INT            OUTPUT,
   @nMQTY_Avail     INT            OUTPUT,
   @nPQTY_TTL       INT            OUTPUT,
   @nPQTY_PMV       INT            OUTPUT,
   @nPQTY_Alloc     INT            OUTPUT,
   @nPQTY_Pick      INT            OUTPUT,
   @nPQTY_RPL       INT            OUTPUT,
   @nPQTY_Avail     INT            OUTPUT,
   @cPUOM_Desc      NVARCHAR( 5)   OUTPUT,
   @cMUOM_Desc      NVARCHAR( 5)   OUTPUT,
   @cLottableCode   NVARCHAR( 30)  OUTPUT,
   @cLottable01     NVARCHAR( 18)  OUTPUT,
   @cLottable02     NVARCHAR( 18)  OUTPUT,
   @cLottable03     NVARCHAR( 18)  OUTPUT,
   @dLottable04     DATETIME       OUTPUT,
   @dLottable05     DATETIME       OUTPUT,
   @cLottable06     NVARCHAR( 30)  OUTPUT,
   @cLottable07     NVARCHAR( 30)  OUTPUT,
   @cLottable08     NVARCHAR( 30)  OUTPUT,
   @cLottable09     NVARCHAR( 30)  OUTPUT,
   @cLottable10     NVARCHAR( 30)  OUTPUT,
   @cLottable11     NVARCHAR( 30)  OUTPUT,
   @cLottable12     NVARCHAR( 30)  OUTPUT,
   @dLottable13     DATETIME       OUTPUT,
   @dLottable14     DATETIME       OUTPUT,
   @dLottable15     DATETIME       OUTPUT,
   @cHasLottable    NVARCHAR( 1)   OUTPUT,
   @nErrNo          INT            OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nPUOM_Div         INT
   DECLARE @cTempLOT          NVARCHAR( 10)
   DECLARE @cTempLOC          NVARCHAR( 10)
   DECLARE @cTempID           NVARCHAR( 18)
   DECLARE @cTempSKU          NVARCHAR( 20)
   DECLARE @cSQL              NVARCHAR( MAX)
   DECLARE @cSQLParam         NVARCHAR( MAX)
   DECLARE @cTempLottable01   NVARCHAR( 18)
   DECLARE @cTempLottable02   NVARCHAR( 18)
   DECLARE @cTempLottable03   NVARCHAR( 18)
   DECLARE @dTempLottable04   DATETIME
   DECLARE @dTempLottable05   DATETIME
   DECLARE @cTempLottable06   NVARCHAR( 30)
   DECLARE @cTempLottable07   NVARCHAR( 30)
   DECLARE @cTempLottable08   NVARCHAR( 30)
   DECLARE @cTempLottable09   NVARCHAR( 30)
   DECLARE @cTempLottable10   NVARCHAR( 30)
   DECLARE @cTempLottable11   NVARCHAR( 30)
   DECLARE @cTempLottable12   NVARCHAR( 30)
   DECLARE @dTempLottable13   DATETIME
   DECLARE @dTempLottable14   DATETIME
   DECLARE @dTempLottable15   DATETIME
   DECLARE @cTempLottableCode NVARCHAR( 30)
   DECLARE @nTempTotalRec     INT
   DECLARE @cLot              NVARCHAR( 10)
   DECLARE @cAltSKU           NVARCHAR( 20)

   SET @cTempSKU = @cSKU
   SET @cTempLOC = @cLOC
   SET @cTempID = @cID
   SET @cTempLOT = @cLOT
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
   SET @cTempLottableCode = @cLottableCode
   SET @nTempTotalRec = @nTotalRec

   SELECT TOP 1 @cAltSKU = AltSKU
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerkey
   AND   Sku = @cInquiry_SKU
   ORDER BY 1

   -- Get the 1st sku
   IF ISNULL( @cTempSKU, '') = ''
   BEGIN
      SELECT TOP 1 @cTempSKU = LLI.SKU
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LOC.Facility = @cFacility
      AND  (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
      AND   ( (ISNULL( @cInquiry_LOC, '') = '') OR ( LLI.LOC = @cInquiry_LOC))
      AND   ( (ISNULL( @cInquiry_ID, '') = '') OR ( LLI.ID = @cInquiry_ID))
      AND   ( (ISNULL( @cInquiry_SKU, '') = '') OR ( SKU.AltSKU = @cAltSKU))
      ORDER BY LLI.SKU

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 181001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No record'
         GOTO Quit
      END

      -- Get SKU info
      SELECT @cTempLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cTempSKU
   END

   /************************************** Get QTY and lottables *********************************/
   DECLARE @cSelect  NVARCHAR( MAX)
   DECLARE @cFrom    NVARCHAR( MAX)
   DECLARE @cWhere1  NVARCHAR( MAX)
   DECLARE @cWhere2  NVARCHAR( MAX)
   DECLARE @cGroupBy NVARCHAR( MAX)
   DECLARE @cOrderBy NVARCHAR( MAX)

   -- Get lottable filter
   EXEC rdt.rdt_Lottable_GetNextSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 4, @cTempLottableCode, 'LA',
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

   IF @nTempTotalRec = 0
   BEGIN
      SET @cSQL = ''
      SET @cSQL =
      '    SELECT @nTotalRec = COUNT( 1)  ' +
      '    FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' +
      '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC) ' +
      '    JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT) ' +
      '    JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU) ' +
      '    WHERE LOC.Facility = @cFacility ' +
      '    AND  (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) ' +
      '    AND   LLI.StorerKey = @cStorerKey ' +
      '    AND ( (ISNULL( @cInquiry_LOC, '''') = '''') OR ( LLI.LOC = @cInquiry_LOC)) ' +
      '    AND ( (ISNULL( @cInquiry_ID, '''') = '''') OR ( LLI.ID = @cInquiry_ID)) ' +
      '    AND ( (ISNULL( @cInquiry_SKU, '''') = '''') OR ( SKU.ALTSKU = @cAltSKU)) ' +
      CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +
      CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END

      SET @cSQLParam =
         '@cStorerKey   NVARCHAR( 15) , ' +
         '@cFacility    NVARCHAR( 5) , ' +
         '@cInquiry_LOC NVARCHAR( 10) , ' +
         '@cInquiry_ID  NVARCHAR( 18) , ' +
         '@cInquiry_SKU NVARCHAR( 20) , ' +
         '@cLottable01  NVARCHAR( 18), ' +
         '@cLottable02  NVARCHAR( 18), ' +
         '@cLottable03  NVARCHAR( 18), ' +
         '@dLottable04  DATETIME, ' +
         '@dLottable05  DATETIME, ' +
         '@cLottable06  NVARCHAR( 30), ' +
         '@cLottable07  NVARCHAR( 30), ' +
         '@cLottable08  NVARCHAR( 30), ' +
         '@cLottable09  NVARCHAR( 30), ' +
         '@cLottable10  NVARCHAR( 30), ' +
         '@cLottable11  NVARCHAR( 30), ' +
         '@cLottable12  NVARCHAR( 30), ' +
         '@dLottable13  DATETIME, ' +
         '@dLottable14  DATETIME, ' +
         '@dLottable15  DATETIME, ' +
         '@cAltSKU      NVARCHAR( 20), ' +
         '@nTotalRec    INT  OUTPUT '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility,
         @cInquiry_LOC= @cInquiry_LOC,
         @cInquiry_ID = @cInquiry_ID,
         @cInquiry_SKU= @cInquiry_SKU,
         @cLottable01 = @cTempLottable01,
         @cLottable02 = @cTempLottable02,
         @cLottable03 = @cTempLottable03,
         @dLottable04 = @dTempLottable04,
         @dLottable05 = @dTempLottable05,
         @cLottable06 = @cTempLottable06,
         @cLottable07 = @cTempLottable07,
         @cLottable08 = @cTempLottable08,
         @cLottable09 = @cTempLottable09,
         @cLottable10 = @cTempLottable10,
         @cLottable11 = @cTempLottable11,
         @cLottable12 = @cTempLottable12,
         @dLottable13 = @dTempLottable13,
         @dLottable14 = @dTempLottable14,
         @dLottable15 = @dTempLottable15,
         @cAltSKU     = @cAltSKU,
         @nTotalRec   = @nTempTotalRec OUTPUT
   END

   --delete from traceinfo where tracename = '628_1'
   --insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5, step1, step2, step3, step4, step5) values
   --('628_1', getdate(), @cFacility, @cStorerKey, @cInquiry_LOC, @cInquiry_ID, @cInquiry_SKU, @cLottable08, @cLOT, @cLOC, @cID, @cSKU)

   SET @cSQL = ''
   SET @cSQL =
   '    SELECT TOP 1  ' +
   '       @cLOT = LLI.LOT, ' +
   '       @cLOC = LLI.LOC, ' +
   '       @cID = LLI.ID,   ' +
   '       @cSKU = LLI.SKU,   ' +
   '       @nMQTY_Alloc = ISNULL( SUM( LLI.QTYAllocated), 0),  ' +
   '       @nMQTY_Pick  = ISNULL( SUM( LLI.QTYPicked), 0),   ' +
   '       @nMQTY_Avail = ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0), ' +
   '       @nMQty_TTL = ISNULL( SUM( LLI.Qty), 0), ' +
   '       @nMQty_RPL = ISNULL( SUM( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END), 0), ' +
   '       @nMQty_PMV = ISNULL( SUM( LLI.PendingMoveIN), 0) ' +
   CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +
   '    FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' +
   '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC) ' +
   '    JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT) ' +
   '    JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU) ' +
   '    WHERE LOC.Facility = @cFacility ' +
   '    AND  (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) ' +
   '    AND   LLI.StorerKey = @cStorerKey ' +
   '    AND ( (ISNULL( @cInquiry_LOC, '''') = '''') OR ( LLI.LOC = @cInquiry_LOC)) ' +
   '    AND ( (ISNULL( @cInquiry_ID, '''') = '''') OR ( LLI.ID = @cInquiry_ID)) ' +
   '    AND ( (ISNULL( @cInquiry_SKU, '''') = '''') OR ( SKU.ALTSKU = @cAltSKU)) ' --+
   --'    AND  (LLI.SKU + LLI.LOC + LLI.ID' +
   --CASE WHEN @cWhere1 = '' THEN '' ELSE ' + ' + @cWhere1 END  + ') > ' +
   --'         (@cSKU + @cLOC + @cID' + CASE WHEN @cWhere2 = '' THEN '' ELSE + ' + ' + @cWhere2 END + ') '

   IF ISNULL( @cInquiry_LOC, '') <> ''
   BEGIN
      SET @cSQL = @cSQL +
      '    AND  (LLI.LOC + LLI.ID + LLI.SKU' +
      CASE WHEN @cWhere1 = '' THEN '' ELSE ' + ' + @cWhere1 END  + ') > ' +
      '         (@cLOC + @cID + @cSKU' + CASE WHEN @cWhere2 = '' THEN '' ELSE + ' + ' + @cWhere2 END + ') ' +
      CASE WHEN @cGroupBy = '' THEN ' GROUP BY LLI.LOC, LLI.ID, LLI.SKU, LLI.LOT ' ELSE ' GROUP BY ' + 'LLI.LOC, LLI.ID, LLI.SKU, ' + @cGroupBy + ', LLI.LOT' END +
      CASE WHEN @cOrderBy = '' THEN ' ORDER BY LLI.LOC, LLI.ID, LLI.SKU, LLI.LOT ' ELSE ' ORDER BY ' + 'LLI.LOC, LLI.ID, LLI.SKU, ' + @cOrderBy + ', LLI.LOT' END
   END
   ELSE IF ISNULL( @cInquiry_ID, '') <> ''
   BEGIN
      SET @cSQL = @cSQL +
      '    AND  (LLI.ID + LLI.LOC + LLI.SKU' +
      CASE WHEN @cWhere1 = '' THEN '' ELSE ' + ' + @cWhere1 END  + ') > ' +
      '         (@cID + @cLOC + @cSKU' + CASE WHEN @cWhere2 = '' THEN '' ELSE + ' + ' + @cWhere2 END + ') ' +
      CASE WHEN @cGroupBy = '' THEN ' GROUP BY LLI.ID, LLI.LOC, LLI.SKU, LLI.LOT ' ELSE ' GROUP BY ' + 'LLI.ID, LLI.LOC, LLI.SKU, ' + @cGroupBy + ', LLI.LOT' END +
      CASE WHEN @cOrderBy = '' THEN ' ORDER BY LLI.ID, LLI.LOC, LLI.SKU, LLI.LOT ' ELSE ' ORDER BY ' + 'LLI.ID, LLI.LOC, LLI.SKU, ' + @cOrderBy + ', LLI.LOT' END
   END
   ELSE  -- IF ISNULL( @cInquiry_SKU, '') <> ''
   BEGIN
      SET @cSQL = @cSQL +
      '    AND  (LLI.SKU + LLI.LOC + LLI.ID' +
      CASE WHEN @cWhere1 = '' THEN '' ELSE ' + ' + @cWhere1 END  + ') > ' +
      '         (@cSKU + @cLOC + @cID' + CASE WHEN @cWhere2 = '' THEN '' ELSE + ' + ' + @cWhere2 END + ') ' +
      CASE WHEN @cGroupBy = '' THEN ' GROUP BY LLI.SKU, LLI.LOC, LLI.ID, LLI.LOT ' ELSE ' GROUP BY ' + 'LLI.SKU, LLI.LOC, LLI.ID, ' + @cGroupBy + ', LLI.LOT' END +
      CASE WHEN @cOrderBy = '' THEN ' ORDER BY LLI.SKU, LLI.LOC, LLI.ID, LLI.LOT ' ELSE ' ORDER BY ' + 'LLI.SKU, LLI.LOC, LLI.ID, ' + @cOrderBy + ', LLI.LOT' END
   END

   SET @cSQLParam =
      '@cStorerKey   NVARCHAR( 15) , ' +
      '@cFacility    NVARCHAR( 5) , ' +
      '@cInquiry_LOC NVARCHAR( 10) , ' +
      '@cInquiry_ID  NVARCHAR( 18) , ' +
      '@cInquiry_SKU NVARCHAR( 20) , ' +
      '@cLOT         NVARCHAR( 10)  OUTPUT, ' +
      '@cLOC         NVARCHAR( 10)  OUTPUT, ' +
      '@cID          NVARCHAR( 18)  OUTPUT, ' +
      '@cSKU         NVARCHAR( 20)  OUTPUT, ' +
      '@nMQTY_Alloc  INT            OUTPUT, ' +
      '@nMQTY_Pick   INT            OUTPUT, ' +
      '@nMQTY_Avail  INT            OUTPUT, ' +
      '@nMQty_TTL    INT            OUTPUT, ' +
      '@nMQty_RPL    INT            OUTPUT, ' +
      '@nMQty_PMV    INT            OUTPUT, ' +
      '@cLottable01  NVARCHAR( 18)  OUTPUT, ' +
      '@cLottable02  NVARCHAR( 18)  OUTPUT, ' +
      '@cLottable03  NVARCHAR( 18)  OUTPUT, ' +
      '@dLottable04  DATETIME       OUTPUT, ' +
      '@dLottable05  DATETIME       OUTPUT, ' +
      '@cLottable06  NVARCHAR( 30)  OUTPUT, ' +
      '@cLottable07  NVARCHAR( 30)  OUTPUT, ' +
      '@cLottable08  NVARCHAR( 30)  OUTPUT, ' +
      '@cLottable09  NVARCHAR( 30)  OUTPUT, ' +
      '@cLottable10  NVARCHAR( 30)  OUTPUT, ' +
      '@cLottable11  NVARCHAR( 30)  OUTPUT, ' +
      '@cLottable12  NVARCHAR( 30)  OUTPUT, ' +
      '@dLottable13  DATETIME       OUTPUT, ' +
      '@dLottable14  DATETIME       OUTPUT, ' +
      '@dLottable15  DATETIME       OUTPUT, ' +
      '@cAltSKU      NVARCHAR( 20)  OUTPUT  '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @cStorerKey  = @cStorerKey,
      @cFacility   = @cFacility,
      @cInquiry_LOC= @cInquiry_LOC,
      @cInquiry_ID = @cInquiry_ID,
      @cInquiry_SKU= @cInquiry_SKU,
      @cLOT        = @cTempLOT         OUTPUT,
      @cLOC        = @cTempLOC         OUTPUT,
      @cID         = @cTempID          OUTPUT,
      @cSKU        = @cTempSKU         OUTPUT,
      @nMQTY_Alloc = @nMQTY_Alloc      OUTPUT,
      @nMQTY_Pick  = @nMQTY_Pick       OUTPUT,
      @nMQTY_Avail = @nMQTY_Avail      OUTPUT,
      @nMQty_TTL   = @nMQty_TTL        OUTPUT,
      @nMQty_RPL   = @nMQty_RPL        OUTPUT,
      @nMQTY_PMV   = @nMQTY_PMV        OUTPUT,
      @cLottable01 = @cTempLottable01  OUTPUT,
      @cLottable02 = @cTempLottable02  OUTPUT,
      @cLottable03 = @cTempLottable03  OUTPUT,
      @dLottable04 = @dTempLottable04  OUTPUT,
      @dLottable05 = @dTempLottable05  OUTPUT,
      @cLottable06 = @cTempLottable06  OUTPUT,
      @cLottable07 = @cTempLottable07  OUTPUT,
      @cLottable08 = @cTempLottable08  OUTPUT,
      @cLottable09 = @cTempLottable09  OUTPUT,
      @cLottable10 = @cTempLottable10  OUTPUT,
      @cLottable11 = @cTempLottable11  OUTPUT,
      @cLottable12 = @cTempLottable12  OUTPUT,
      @dLottable13 = @dTempLottable13  OUTPUT,
      @dLottable14 = @dTempLottable14  OUTPUT,
      @dLottable15 = @dTempLottable15  OUTPUT,
      @cAltSKU     = @cAltSKU

      -- Validate if any result
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 181002
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No more record'
         SET @nTotalRec = -1
         GOTO Quit
      END

   --delete from traceinfo where tracename = '628_2'
   --insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5, step1, step2, step3, step4, step5) values
   --('628_2', getdate(), @cFacility, @cStorerKey, @cInquiry_LOC, @cInquiry_ID, @cInquiry_SKU, @cLottable08, @cTempLOT, @cTempLOC, @cTempID, @cTempSKU)

      -- Assign to actual
      SET @cLOC        = @cTempLOC
      SET @cID         = @cTempID
      SET @cSKU        = @cTempSKU
      SET @cLOT        = @cTempLOT
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
      -- SQLstatement need filter lottable meaning lottable is setup to display, whether this record has value or not
      SET @cHasLottable  = CASE WHEN @cWhere2 <> '' THEN '1' ELSE '' END
      SET @nTotalRec = @nTempTotalRec

      -- Get stock info
      SELECT
         @cSKUDescr = SKU.Descr,
         @cMUOM_Desc = Pack.PackUOM3,
         @cPUOM_Desc =
            CASE @cPUOM
               WHEN '2' THEN Pack.PackUOM1 -- Case
               WHEN '3' THEN Pack.PackUOM2 -- Inner pack
               WHEN '6' THEN Pack.PackUOM3 -- Master unit
               WHEN '1' THEN Pack.PackUOM4 -- Pallet
               WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
               WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
            END,
         @nPUOM_Div = CAST( IsNULL(
         CASE @cPUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END, 1) AS INT)
      FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.SKU = @cSKU
      AND   SKU.StorerKey = @cStorerKey

      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_Alloc = 0
         SET @nPQTY_Avail = 0
         SET @nPQTY_PMV = 0
         SET @nPQTY_TTL = 0
         SET @nPQTY_RPL = 0
      END
      ELSE
      BEGIN
         -- Calc QTY in preferred UOM
         SET @nPQTY_Avail = CAST(@nMQTY_Avail AS INT) / @nPUOM_Div
         SET @nPQTY_Alloc = CAST(@nMQTY_Alloc AS INT) / @nPUOM_Div
         SET @nPQTY_PMV   = CAST(@nMQTY_PMV   AS INT) / @nPUOM_Div
         SET @nPQTY_TTL   = CAST(@nMQTY_TTL   AS INT) / @nPUOM_Div
         SET @nPQTY_RPL   = CAST(@nMQTY_RPL   AS INT) / @nPUOM_Div
         SET @nPQTY_Pick  = CAST(@nMQTY_Pick  AS INT) / @nPUOM_Div

         -- Calc the remaining in master unit
         SET @nMQTY_Avail = CAST(@nMQTY_Avail as INT)  % @nPUOM_Div
         SET @nMQTY_Alloc = CAST(@nMQTY_Alloc as INT)  % @nPUOM_Div
         SET @nMQTY_PMV   = CAST(@nMQTY_PMV   as INT)  % @nPUOM_Div
         SET @nMQTY_TTL   = CAST(@nMQTY_TTL   as INT)  % @nPUOM_Div
         SET @nMQTY_RPL   = CAST(@nMQTY_RPL   as INT)  % @nPUOM_Div
         SET @nMQTY_Pick  = CAST(@nMQTY_Pick  as INT)  % @nPUOM_Div
      END


   QUIT:

GO