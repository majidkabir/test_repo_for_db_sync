SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLCart_GetTask_LOCSKU_Lottable                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 15-01-2018  1.0  Ung         WMS-3549 Created                        */
/* 26-01-2018  1.1  Ung         Change to PTL.Schema                    */
/* 28-11-2018  1.2  Ung         INC0457739 Fix skip task                */
/* 03-09-2021  1.3  Ung         WMS-17793 Fix skip task                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_GetTask_LOCSKU_Lottable] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR(3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR(5)
   ,@cStorerKey      NVARCHAR(15)
   ,@cType           NVARCHAR(20)  -- LOC/CURRENTTOTE/NEXTTOTE
   ,@cLight          NVARCHAR(1)   -- 0 = no light, 1 = use light
   ,@cCartID         NVARCHAR(10)
   ,@cPickZone       NVARCHAR(10)
   ,@cMethod         NVARCHAR(10)
   ,@cPickSeq        NVARCHAR(10)
   ,@cToteID         NVARCHAR(20)
   ,@cDPLKey         NVARCHAR(10)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(20)  OUTPUT
   ,@cLOC            NVARCHAR(10)  OUTPUT
   ,@cSKU            NVARCHAR(20)  OUTPUT
   ,@cSKUDescr       NVARCHAR(60)  OUTPUT
   ,@nTotalPOS       INT           OUTPUT
   ,@nTotalQTY       INT           OUTPUT
   ,@nToteQTY        INT           OUTPUT
   ,@cLottableCode   NVARCHAR( 30) OUTPUT 
   ,@cLottable01     NVARCHAR( 18) OUTPUT  
   ,@cLottable02     NVARCHAR( 18) OUTPUT  
   ,@cLottable03     NVARCHAR( 18) OUTPUT  
   ,@dLottable04     DATETIME      OUTPUT  
   ,@dLottable05     DATETIME      OUTPUT  
   ,@cLottable06     NVARCHAR( 30) OUTPUT 
   ,@cLottable07     NVARCHAR( 30) OUTPUT 
   ,@cLottable08     NVARCHAR( 30) OUTPUT 
   ,@cLottable09     NVARCHAR( 30) OUTPUT 
   ,@cLottable10     NVARCHAR( 30) OUTPUT 
   ,@cLottable11     NVARCHAR( 30) OUTPUT
   ,@cLottable12     NVARCHAR( 30) OUTPUT
   ,@dLottable13     DATETIME      OUTPUT
   ,@dLottable14     DATETIME      OUTPUT
   ,@dLottable15     DATETIME      OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   DECLARE @cSelect   NVARCHAR( MAX)
   DECLARE @cWhere    NVARCHAR( MAX)
   DECLARE @cWhere1   NVARCHAR( MAX)
   DECLARE @cWhere2   NVARCHAR( MAX)
   DECLARE @cGroupBy  NVARCHAR( MAX)
   DECLARE @cOrderBy  NVARCHAR( MAX)
   DECLARE @bSuccess INT
   DECLARE @nQTY     INT

   DECLARE @cTempLogicalLOC NCHAR( 18)
   DECLARE @cTempLOC        NCHAR( 10)
   DECLARE @cTempSKU        NCHAR( 20)
   DECLARE @nTempQTY        INT
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

   DECLARE @cGetNextLOC NVARCHAR(1)
   DECLARE @cGetNextSKU NVARCHAR(1)

   -- For LOC
   IF @cType = 'LOC' 
   BEGIN
      -- Use light and for LOC
      IF @cLight = '1' 
         -- Off all lights
         /*
         EXEC dbo.isp_DPC_TerminateAllLight
             @cStorerKey
            ,@cCartID
            ,@bSuccess    OUTPUT
            ,@nErrNo      OUTPUT
            ,@cErrMsg     OUTPUT
         */
         EXEC PTL.isp_PTL_TerminateModule    
             @cStorerKey    
            ,@nFunc    
            ,@cCartID    
            ,'0'    
            ,@bSuccess    OUTPUT    
            ,@nErrNo      OUTPUT    
            ,@cErrMsg     OUTPUT    
   
      -- Get task in same LOC, next SKU
      /*
      IF @nStep = 3 -- SKU (skip task)
         -- Get task in same LOC, next SKU
         SELECT TOP 1
            @cLOC = PTL.LOC,
            @cSKU = PTL.SKU, 
            @nQTY = PTL.ExpectedQTY
         FROM PTL.PTLTran PTL WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)
         WHERE PTL.DeviceProfileLogKey = @cDPLKey
            AND PTL.Status = '0'
            AND PTL.LOC = @cLOC
            AND PTL.SKU > @cSKU
         ORDER BY LOC.LOC, PTL.SKU      
      ELSE
         SELECT TOP 1
            @cLOC = PTL.LOC,
            @cSKU = PTL.SKU, 
            @nQTY = PTL.ExpectedQTY
         FROM PTL.PTLTran PTL WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)
         WHERE PTL.DeviceProfileLogKey = @cDPLKey
            AND PTL.Status = '0'
            AND PTL.LOC = @cLOC
         ORDER BY LOC.LOC, PTL.SKU
   
      IF @@ROWCOUNT = 0
      BEGIN
         -- Get task for next LOC
         SELECT TOP 1
            @cLOC = PTL.LOC,
            @cSKU = PTL.SKU, 
            @nQTY = PTL.ExpectedQTY
         FROM PTL.PTLTran PTL WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)
         WHERE PTL.DeviceProfileLogKey = @cDPLKey
            AND PTL.Status = '0'
            AND PTL.LOC > @cLOC
         ORDER BY LOC.LOC, PTL.SKU
   
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 54751
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NoTask!'
            GOTO Quit
         END
      END
      */

      -- Assign to temp
      SET @cTempLOC = @cLOC
      SET @cTempSKU = @cSKU
      SET @nTempQTY = 0
      SET @cTempLogicalLOC = ''
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

      SET @cGetNextLOC = ''
      SET @cGetNextSKU = ''
      
      IF @cTempLOC = '' SET @cGetNextLOC = 'Y'
      IF @cTempSKU = '' SET @cGetNextSKU = 'Y'        

      IF @nStep = 3 -- SKU (skip task)
         SET @cGetNextSKU = 'Y' -- Get task in same LOC, next SKU

      WHILE (1=1)
      BEGIN
         -- Get next LOC
         IF @cGetNextLOC = 'Y'
         BEGIN
            -- Get LOC info
            IF @cTempLOC <> ''
               SELECT @cTempLogicalLOC = LogicalLocation FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cTempLOC
            
            SELECT TOP 1
               @cTempLogicalLOC = LOC.LogicalLocation, 
               @cTempLOC = LOC.LOC
            FROM PTL.PTLTran PTL WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)
            WHERE PTL.DeviceProfileLogKey = @cDPLKey
               AND PTL.Status = '0'
               AND (LOC.LogicalLocation > @cTempLogicalLOC
                OR (LOC.LogicalLocation = @cTempLogicalLOC AND LOC.LOC > @cTempLOC))
            ORDER BY LOC.LogicalLocation, LOC.LOC
            
            IF @@ROWCOUNT = 0
               BREAK

            SET @cGetNextLOC = 'N'
            SET @cGetNextSKU = 'Y'
            SET @cTempSKU = ''
         END
   
         -- Get next SKU
         IF @cGetNextSKU = 'Y'
         BEGIN
            SELECT TOP 1
               @cTempSKU = PTL.SKU, 
               @cTempLottableCode = LottableCode
            FROM PTL.PTLTran PTL WITH (NOLOCK)
               JOIN dbo.SKU WITH (NOLOCK) ON (SKU.StorerKey = PTL.StorerKey AND SKU.SKU = PTL.SKU)
            WHERE PTL.DeviceProfileLogKey = @cDPLKey
               AND PTL.Status = '0'
               AND PTL.LOC = @cTempLOC
               AND PTL.SKU > @cTempSKU
            ORDER BY PTL.SKU
            
            IF @@ROWCOUNT = 0
            BEGIN
               SET @cGetNextLOC = 'Y'
               SET @cGetNextSKU = 'N'
               SET @cTempSKU = ''
               CONTINUE
            END
            
            SELECT @nTempQTY = 0, 
               @cTempLottable01 = '', @cTempLottable02 = '', @cTempLottable03 = '',    @dTempLottable04 = NULL,  @dTempLottable05 = NULL,
               @cTempLottable06 = '', @cTempLottable07 = '', @cTempLottable08 = '',    @cTempLottable09 = '',    @cTempLottable10 = '',
               @cTempLottable11 = '', @cTempLottable12 = '', @dTempLottable13 = NULL,  @dTempLottable14 = NULL,  @dTempLottable15 = NULL
         END
   
         -- Get next lottable
         IF @nTempQTY = 0
         BEGIN
            -- Get lottable filter
            EXEC rdt.rdt_Lottable_GetNextSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 4, @cTempLottableCode, 'PTL', 
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

            SET @cSQL = 
               ' SELECT TOP 1 ' + 
                  ' @nQTY = ISNULL( SUM( PTL.ExpectedQTY), 0) ' + 
                  CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END + 
               ' FROM PTL.PTLTran PTL WITH (NOLOCK) ' + 
               ' WHERE PTL.DeviceProfileLogKey = @cDPLKey ' + 
                  ' AND PTL.Status = ''0'' ' + 
                  ' AND PTL.LOC = @cLOC ' + 
                  ' AND PTL.SKU = @cSKU ' + 
                  CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END + 
                  CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END + 
               CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +
               CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END 

            SET @cSQLParam = 
               '@cDPLKey     NVARCHAR( 10), ' + 
               '@cLOC        NVARCHAR( 10), ' + 
               '@cSKU        NVARCHAR( 15), ' + 
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
               @cDPLKey     = @cDPLKey, 
               @cLOC        = @cTempLOC,  
               @cSKU        = @cTempSKU,  
               @nQTY        = @nTempQTY        OUTPUT,  
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

            IF @nTempQTY > 0
               BREAK
            ELSE
               SELECT 
                  @cGetNextLOC = 'N', @cGetNextSKU = 'Y', 
                  @cTempLottable01 = '', @cTempLottable02 = '', @cTempLottable03 = '',    @dTempLottable04 = NULL,  @dTempLottable05 = NULL,
                  @cTempLottable06 = '', @cTempLottable07 = '', @cTempLottable08 = '',    @cTempLottable09 = '',    @cTempLottable10 = '',
                  @cTempLottable11 = '', @cTempLottable12 = '', @dTempLottable13 = NULL,  @dTempLottable14 = NULL,  @dTempLottable15 = NULL
         END
      END

      IF @nTempQTY = 0
      BEGIN
         SET @nErrNo = 102052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
         GOTO Quit
      END

      -- Assign to actual
      SET @cLOC = @cTempLOC
      SET @cSKU = @cTempSKU
      SET @nQTY = @nTempQTY 
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

      -- Get SKU description
      DECLARE @cDispStyleColorSize  NVARCHAR( 20)
      SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)
      
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
         
      ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDispStyleColorSize AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cDispStyleColorSize) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKUDescr OUTPUT '
         SET @cSQLParam =
            ' @nMobile    INT,           ' +
            ' @nFunc      INT,           ' +
            ' @cLangCode  NVARCHAR( 3),  ' +
            ' @nStep      INT,           ' +
            ' @nInputKey  INT,           ' +
            ' @cFacility  NVARCHAR( 5),  ' +
            ' @cStorerKey NVARCHAR( 15), ' +
            ' @cDPLKey    NVARCHAR(10),  ' +
            ' @cCartID    NVARCHAR(10),  ' +
            ' @cPickZone  NVARCHAR(10),  ' +
            ' @cMethod    NVARCHAR(10),  ' +
            ' @cLOC       NVARCHAR(10),  ' +
            ' @cSKU       NVARCHAR(20),  ' +
            ' @cToteID    NVARCHAR(20),  ' +
            ' @nErrNo     INT          OUTPUT, ' +
            ' @cErrMsg    NVARCHAR(20) OUTPUT, ' +
            ' @cSKUDescr  NVARCHAR(60) OUTPUT  '
      
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKUDescr OUTPUT
      END
      
      -- Get total order, QTY
      /*
      SELECT
         @nTotalPOS = COUNT( DISTINCT DevicePosition),
         @nTotalQTY = SUM( ExpectedQTY)
      FROM PTL.PTLTran WITH (NOLOCK)
   	WHERE DeviceProfileLogKey = @cDPLKey
   	  AND SKU = @cSKU
   	  AND LOC = @cLOC
   	  AND Status = '0'
   	*/
      SET @cSQL = 
         ' SELECT ' + 
            ' @nTotalPOS = COUNT( DISTINCT DevicePosition), ' + 
            ' @nTotalQTY = SUM( ExpectedQTY) ' + 
         ' FROM PTL.PTLTran WITH (NOLOCK) ' + 
      	' WHERE DeviceProfileLogKey = @cDPLKey ' + 
      	  ' AND SKU = @cSKU ' + 
      	  ' AND LOC = @cLOC ' + 
      	  ' AND Status = ''0'' ' 

      -- Get lottable filter
      EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 4, 'PTLTran', 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @cWhere   OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      -- Lottable filter
      IF @cWhere <> '' 
         SET @cSQL = @cSQL + ' AND ' + @cWhere

      SET @cSQLParam = 
         ' @cDPLKey     NVARCHAR( 10), ' + 
         ' @cLOC        NVARCHAR( 10), ' + 
         ' @cSKU        NVARCHAR( 15), ' + 
         ' @cLottable01 NVARCHAR( 18), ' + 
         ' @cLottable02 NVARCHAR( 18), ' + 
         ' @cLottable03 NVARCHAR( 18), ' + 
         ' @dLottable04 DATETIME,      ' + 
         ' @dLottable05 DATETIME,      ' + 
         ' @cLottable06 NVARCHAR( 30), ' + 
         ' @cLottable07 NVARCHAR( 30), ' + 
         ' @cLottable08 NVARCHAR( 30), ' + 
         ' @cLottable09 NVARCHAR( 30), ' + 
         ' @cLottable10 NVARCHAR( 30), ' + 
         ' @cLottable11 NVARCHAR( 30), ' + 
         ' @cLottable12 NVARCHAR( 30), ' + 
         ' @dLottable13 DATETIME,      ' + 
         ' @dLottable14 DATETIME,      ' + 
         ' @dLottable15 DATETIME,      ' +
         ' @nTotalPOS   INT OUTPUT,    ' + 
         ' @nTotalQTY   INT OUTPUT     '
      
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cDPLKey, @cLOC, @cSKU, 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
         @nTotalPOS OUTPUT, 
         @nTotalQTY OUTPUT

      GOTO Quit
   END
   
   -- Get position
   DECLARE @cPosition NVARCHAR(10)
   SELECT @cPosition = Position FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID = @cToteID
   
   -- For tote
   IF @cType = 'CURRENTTOTE'
   BEGIN
      -- Get current task QTY
      /*
      SELECT @nToteQTY = ISNULL( SUM( PTL.ExpectedQTY), 0)
      FROM PTL.PTLTran PTL WITH (NOLOCK)
         JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)
      WHERE PTL.DeviceProfileLogKey = @cDPLKey
         AND PTL.Status = '0'
         AND PTL.LOC = @cLOC
         AND PTL.SKU = @cSKU
         AND DevicePosition = @cPosition
      */
      SET @cSQL = 
         ' SELECT @nToteQTY = ISNULL( SUM( PTL.ExpectedQTY), 0) ' + 
         ' FROM PTL.PTLTran PTL WITH (NOLOCK) ' + 
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC) ' + 
         ' WHERE PTL.DeviceProfileLogKey = @cDPLKey ' + 
            ' AND PTL.Status = ''0'' ' + 
            ' AND PTL.LOC = @cLOC ' + 
            ' AND PTL.SKU = @cSKU ' + 
            ' AND DevicePosition = @cPosition '
         
      -- Get lottable filter
      EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 4, 'PTL', 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @cWhere   OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT
   
      -- Lottable filter
      IF @cWhere <> '' 
         SET @cSQL = @cSQL + ' AND ' + @cWhere

--insert into a (field, value) values ('@cWhere', @cWhere)
--insert into a (field, value) values ('@cSQL', @cSQL)

      SET @cSQLParam = 
         ' @cDPLKey     NVARCHAR( 10), ' + 
         ' @cLOC        NVARCHAR( 10), ' + 
         ' @cSKU        NVARCHAR( 15), ' + 
         ' @cPosition   NVARCHAR( 20), ' + 
         ' @cLottable01 NVARCHAR( 18), ' + 
         ' @cLottable02 NVARCHAR( 18), ' + 
         ' @cLottable03 NVARCHAR( 18), ' + 
         ' @dLottable04 DATETIME,      ' + 
         ' @dLottable05 DATETIME,      ' + 
         ' @cLottable06 NVARCHAR( 30), ' + 
         ' @cLottable07 NVARCHAR( 30), ' + 
         ' @cLottable08 NVARCHAR( 30), ' + 
         ' @cLottable09 NVARCHAR( 30), ' + 
         ' @cLottable10 NVARCHAR( 30), ' + 
         ' @cLottable11 NVARCHAR( 30), ' + 
         ' @cLottable12 NVARCHAR( 30), ' + 
         ' @dLottable13 DATETIME,      ' + 
         ' @dLottable14 DATETIME,      ' + 
         ' @dLottable15 DATETIME,      ' +
         ' @nToteQTY    INT OUTPUT     '
      
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cDPLKey, @cLOC, @cSKU, @cPosition, 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
         @nToteQTY OUTPUT

--insert into a (field, value) values ('@nToteQTY', CAST( @nToteQTY AS NVARCHAR(5)))
   END
   
   -- For tote
   IF @cType = 'NEXTTOTE'
   BEGIN
      -- Get next task exist
      /*
      IF NOT EXISTS( SELECT 1 
         FROM PTL.PTLTran PTL WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)
         WHERE PTL.DeviceProfileLogKey = @cDPLKey
            AND PTL.Status = '0'
            AND (PTL.LOC > @cLOC
             OR (PTL.LOC = @cLOC AND SKU > @cSKU))
            AND DevicePosition = @cPosition)
         SET @nErrNo = -1 -- No task
      */
      DECLARE @nRowCount   INT
      DECLARE @cLogicalLOC NVARCHAR( 18)
      
      SET @nRowCount = 0

      -- Get LOC info
      SELECT @cLogicalLOC = LogicalLocation FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC
      
      SET @cSQL = 
         ' SELECT TOP 1 @nRowCount = 1 ' + 
         ' FROM PTL.PTLTran PTL WITH (NOLOCK) ' + 
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC) ' + 
         ' WHERE PTL.DeviceProfileLogKey = @cDPLKey ' + 
            ' AND DevicePosition = @cPosition ' + 
            ' AND PTL.Status = ''0'' ' + 
            ' AND (LOC.LogicalLocation > @cLogicalLOC ' + 
            '  OR (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC) ' + 
            '  OR (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC = @cLOC AND SKU > @cSKU) '

      -- Get lottable filter
      EXEC rdt.rdt_Lottable_GetNextSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 4, @cLottableCode, 'PTL', 
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

      -- Lottable filter
      IF @cWhere1 = '' 
         SET @cSQL = @cSQL + ') ' 
      ELSE
         SET @cSQL = @cSQL + 
            '  OR (PTL.LOC = @cLOC AND SKU = @cSKU AND ' + @cWhere1 + ' > ' + @cWhere2 + ' )) '

 --insert into a (field, value) values ('@cWhere1', @cWhere1)
 --insert into a (field, value) values ('@cWhere2', @cWhere2)
 --insert into a (field, value) values ('@cSQL', @cSQL)

      SET @cSQLParam = 
         ' @cDPLKey     NVARCHAR( 10), ' + 
         ' @cLogicalLOC NVARCHAR( 18), ' + 
         ' @cLOC        NVARCHAR( 10), ' + 
         ' @cSKU        NVARCHAR( 15), ' + 
         ' @cPosition   NVARCHAR( 20), ' + 
         ' @cLottable01 NVARCHAR( 18), ' + 
         ' @cLottable02 NVARCHAR( 18), ' + 
         ' @cLottable03 NVARCHAR( 18), ' + 
         ' @dLottable04 DATETIME,      ' + 
         ' @dLottable05 DATETIME,      ' + 
         ' @cLottable06 NVARCHAR( 30), ' + 
         ' @cLottable07 NVARCHAR( 30), ' + 
         ' @cLottable08 NVARCHAR( 30), ' + 
         ' @cLottable09 NVARCHAR( 30), ' + 
         ' @cLottable10 NVARCHAR( 30), ' + 
         ' @cLottable11 NVARCHAR( 30), ' + 
         ' @cLottable12 NVARCHAR( 30), ' + 
         ' @dLottable13 DATETIME,      ' + 
         ' @dLottable14 DATETIME,      ' + 
         ' @dLottable15 DATETIME,      ' +
         ' @nRowCount   INT OUTPUT     '
      
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cDPLKey, @cLogicalLOC, @cLOC, @cSKU, @cPosition, 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
         @nRowCount OUTPUT
         
      IF @nRowCount = 0
         SET @nErrNo = -1 -- No task

-- insert into a (field, value) values ('@nRowCount', CAST( @nRowCount AS NVARCHAR(5)))
   END
   
Quit:

END

GO