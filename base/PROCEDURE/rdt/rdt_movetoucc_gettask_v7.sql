SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_MoveToUCC_GetTask_V7                            */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Move to ucc get move get task                               */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-02-17 1.0  James      WMS-11360. Created                        */
/* 2023-03-10 1.1  Ung        WMS-21506 Fix MoveToUCCGetTaskSP          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_MoveToUCC_GetTask_V7] (
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR(3), 
   @nStep           INT, 
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cFacility       NVARCHAR( 5), 
   @cType           NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10), 
   @cToID           NVARCHAR( 18), 
   @cFromLOC        NVARCHAR( 10), 
   @cFromID         NVARCHAR( 18), 
   @cUCC            NVARCHAR( 20), 
   @cSKU            NVARCHAR( 20) OUTPUT,
   @nQTY            INT           OUTPUT,
   @nTotalRec       INT           OUTPUT,
   @cLottableCode   NVARCHAR( 30) OUTPUT,
   @cLottable01     NVARCHAR( 18) OUTPUT,
   @cLottable02     NVARCHAR( 18) OUTPUT,  
   @cLottable03     NVARCHAR( 18) OUTPUT,  
   @dLottable04     DATETIME      OUTPUT,  
   @dLottable05     DATETIME      OUTPUT,  
   @cLottable06     NVARCHAR( 30) OUTPUT, 
   @cLottable07     NVARCHAR( 30) OUTPUT, 
   @cLottable08     NVARCHAR( 30) OUTPUT, 
   @cLottable09     NVARCHAR( 30) OUTPUT, 
   @cLottable10     NVARCHAR( 30) OUTPUT, 
   @cLottable11     NVARCHAR( 30) OUTPUT,
   @cLottable12     NVARCHAR( 30) OUTPUT,
   @dLottable13     DATETIME      OUTPUT,
   @dLottable14     DATETIME      OUTPUT,
   @dLottable15     DATETIME      OUTPUT,
   @tExtGetTask     VARIABLETABLE READONLY, 
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cMoveToUCCGetTaskSP  NVARCHAR( 20) = ''
   DECLARE @cSelect     NVARCHAR( MAX)
   DECLARE @cFrom       NVARCHAR( MAX)
   DECLARE @cWhere1     NVARCHAR( MAX)
   DECLARE @cWhere2     NVARCHAR( MAX)
   DECLARE @cGroupBy    NVARCHAR( MAX)
   DECLARE @cOrderBy    NVARCHAR( MAX)

   DECLARE @cTempSKU          NVARCHAR( 20)
   DECLARE @cTempLOC          NVARCHAR( 10)
   DECLARE @cTempID           NVARCHAR( 18)
   DECLARE @nTempQTY          INT
   DECLARE @nTempTotalRec     INT
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
   DECLARE @nMultiStorer      INT = 0
   
   SET @nErrNo = 0 -- Require if calling GetTask multiple times (NEXTSKU then NEXTLOC)
   SET @cErrMsg = ''

   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
      SET @nMultiStorer = 1

   SET @cMoveToUCCGetTaskSP = rdt.RDTGetConfig( @nFunc, 'MoveToUCCGetTaskSP', @cStorerKey)
      
   IF @cMoveToUCCGetTaskSP <> '' AND 
      EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cMoveToUCCGetTaskSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cMoveToUCCGetTaskSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cType, @cToLoc, @cToID, @cFromLoc, @cFromID, @cUCC, ' + 
         ' @cSKU        OUTPUT,  @nQTY        OUTPUT, @nTotalRec   OUTPUT, @cLottableCode OUTPUT, ' + 
         ' @cLottable01 OUTPUT,  @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' + 
         ' @cLottable06 OUTPUT,  @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
         ' @cLottable11 OUTPUT,  @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
         ' @tExtGetTask,         @nErrNo      OUTPUT, @cErrMsg     OUTPUT'

      SET @cSQLParam =
         ' @nMobile         INT, ' +
         ' @nFunc           INT, ' +
         ' @cLangCode       NVARCHAR( 3), ' +
         ' @nStep           INT, ' +
         ' @nInputKey       INT, ' +
         ' @cStorerKey      NVARCHAR( 15), ' +
         ' @cFacility       NVARCHAR( 5),  ' +
         ' @cType           NVARCHAR( 10),  ' +
         ' @cToLOC          NVARCHAR( 10), ' +
         ' @cToID           NVARCHAR( 18), ' +
         ' @cFromLOC        NVARCHAR( 10), ' +
         ' @cFromID         NVARCHAR( 18), ' +
         ' @cUCC            NVARCHAR( 20), ' +
         ' @cSKU            NVARCHAR( 20) OUTPUT, ' +
         ' @nQTY            INT           OUTPUT, ' +
         ' @nTotalRec       INT           OUTPUT, ' +
         ' @cLottableCode   NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable01     NVARCHAR( 18) OUTPUT, ' +
         ' @cLottable02     NVARCHAR( 18) OUTPUT, ' + 
         ' @cLottable03     NVARCHAR( 18) OUTPUT, ' + 
         ' @dLottable04     DATETIME      OUTPUT, ' + 
         ' @dLottable05     DATETIME      OUTPUT, ' + 
         ' @cLottable06     NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable07     NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable08     NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable09     NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable10     NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable11     NVARCHAR( 30) OUTPUT, ' +
         ' @cLottable12     NVARCHAR( 30) OUTPUT, ' +
         ' @dLottable13     DATETIME      OUTPUT, ' +
         ' @dLottable14     DATETIME      OUTPUT, ' +
         ' @dLottable15     DATETIME      OUTPUT, ' +
         ' @tExtGetTask     VariableTable READONLY, ' +
         ' @nErrNo          INT           OUTPUT, ' +
         ' @cErrMsg         NVARCHAR( 20) OUTPUT ' 

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cType, @cToLoc, @cToID, @cFromLoc, @cFromID, @cUCC, 
         @cSKU        OUTPUT,  @nQTY        OUTPUT, @nTotalRec   OUTPUT, @cLottableCode OUTPUT, 
         @cLottable01 OUTPUT,  @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,  
         @cLottable06 OUTPUT,  @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, 
         @cLottable11 OUTPUT,  @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, 
         @tExtGetTask,         @nErrNo      OUTPUT, @cErrMsg     OUTPUT 

      GOTO Quit
   END

   -- Standard get task

   -- Assign to temp
   SET @cTempSKU = @cSKU
   SET @cTempLOC = @cFromLOC
   SET @cTempID  = @cFromID
   SET @nTempQTY = 0
   SET @nTempTotalRec = @nTotalRec
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

   -- Get SKU info
   SELECT TOP 1 @cTempLottableCode = LottableCode
   FROM dbo.SKU WITH (NOLOCK)
   WHERE (( @nMultiStorer = 1 AND StorerKey = StorerKey) OR 
          ( @nMultiStorer = 0 AND StorerKey = @cStorerKey))
   AND   SKU = @cTempSKU

   SET @nTempQTY = 0
      
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

   SET @cSQL = ''
   SET @cSQL = 
   '    SELECT @nTotalRec = COUNT( DISTINCT LA.LOT), ' + 
   '           @nQTY = ISNULL( SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - 
                                    ( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) ' + 
   CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END + 
   '    FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' + 
   '    JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT) ' + 
   '    WHERE (( @nMultiStorer = 1 AND LLI.StorerKey = LLI.StorerKey) OR 
               ( @nMultiStorer = 0 AND LLI.StorerKey = @cStorerKey)) ' + 
   '    AND LLI.LOC = @cFromLOC ' + 
   '    AND (( ISNULL( @cFromID, '''') = '''') OR ( LLI.ID = @cFromID)) ' + 
   '    AND LLI.SKU = @cSKU ' +
   '    AND LLI.QTY > 0 ' +
   CASE WHEN @cType = '' THEN '' ELSE ' AND ' + @cWhere1 + '>' + @cWhere2 END +
   CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
   ' HAVING SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - 
               ( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0 ' +
   CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END 

   SET @cSQLParam = 
      '@cStorerKey   NVARCHAR( 15) , ' +  
      '@cFromLOC     NVARCHAR( 10) , ' +  
      '@cFromID      NVARCHAR( 18) , ' +
      '@cSKU         NVARCHAR( 20) , ' +  
      '@nQTY         INT           OUTPUT, ' + 
      '@nTotalRec    INT           OUTPUT, ' +
      '@cLottable01  NVARCHAR( 18) OUTPUT, ' +  
      '@cLottable02  NVARCHAR( 18) OUTPUT, ' +  
      '@cLottable03  NVARCHAR( 18) OUTPUT, ' +  
      '@dLottable04  DATETIME      OUTPUT, ' +  
      '@dLottable05  DATETIME      OUTPUT, ' +  
      '@cLottable06  NVARCHAR( 30) OUTPUT, ' + 
      '@cLottable07  NVARCHAR( 30) OUTPUT, ' + 
      '@cLottable08  NVARCHAR( 30) OUTPUT, ' + 
      '@cLottable09  NVARCHAR( 30) OUTPUT, ' + 
      '@cLottable10  NVARCHAR( 30) OUTPUT, ' + 
      '@cLottable11  NVARCHAR( 30) OUTPUT, ' + 
      '@cLottable12  NVARCHAR( 30) OUTPUT, ' + 
      '@dLottable13  DATETIME      OUTPUT, ' + 
      '@dLottable14  DATETIME      OUTPUT, ' + 
      '@dLottable15  DATETIME      OUTPUT, ' + 
      '@nMultiStorer INT '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
      @cStorerKey  = @cStorerKey,  
      @cFromLOC    = @cTempLOC,  
      @cFromID     = @cTempID,
      @cSKU        = @cTempSKU,  
      @nQTY        = @nTempQTY        OUTPUT,  
      @nTotalRec   = @nTempTotalRec   OUTPUT,
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
      @nMultiStorer = @nMultiStorer

   -- Assign to actual
   SET @cSKU = @cTempSKU
   SET @nQTY = @nTempQTY 
   SET @nTotalRec = @nTempTotalRec
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


Quit:

GO