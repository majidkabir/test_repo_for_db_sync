SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdt_628Inquiry01                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Inquiry customised rule stored proc                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2018-04-23 1.0  James    WMS4458. Created                            */
/* 2018-07-12 1.1  James    INC0300607-Add HasLottable variable(james01)*/
/* 2019-03-25 1.2  James    WMS8359-Bug fix on record count wrong when  */
/*                          no lottable code setup (james02)            */
/* 2019-08-30 1.3  James    WMS-10415 Remove Qty hold and replace       */
/*                          with Pendingmovein (james03)                */
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_628Inquiry01] (    
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
    
   DECLARE @nPUOM_Div   INT,
           @nQty_Hold   INT,
           @cLot        NVARCHAR( 10),
           @cExecStatements   NVARCHAR( 2000), 
           @cExecArguments    NVARCHAR( 2000)


   -- Get total record
   SET @nTotalRec = 0

   SET @cExecStatements = N'SELECT @nTotalRec = COUNT( 1) FROM ( ' + 
      CASE WHEN @cInquiry_LOC <> '' THEN ' SELECT LLI.ID, LLI.SKU '
      WHEN @cInquiry_ID <> '' THEN ' SELECT LLI.LOC, LLI.SKU '
      WHEN @cInquiry_SKU <> '' THEN ' SELECT LLI.LOC, LLI.ID ' END 
   
   SELECT @cExecStatements = @cExecStatements + 
      ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' + 
      ' JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC) ' +
      ' WHERE LLI.StorerKey = ''' + RTRIM(@cStorerKey)  + ''' ' +
      ' AND   LOC.Facility = ''' + @cFacility + ''' ' + 
      ' AND ( LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) ' 

   SELECT @cExecStatements = @cExecStatements + 
      CASE WHEN @cInquiry_LOC <> '' THEN ' AND LLI.LOC = ''' + @cInquiry_LOC + ''' '
      WHEN @cInquiry_ID <> '' THEN ' AND LLI.ID = ''' + @cInquiry_ID + ''' '
      WHEN @cInquiry_SKU <> '' THEN ' AND LLI.SKU = ''' + @cInquiry_SKU + ''' ' END 

   SELECT @cExecStatements = @cExecStatements + 
   CASE WHEN @cInquiry_LOC <> '' THEN ' GROUP BY LLI.ID, LLI.SKU) A '
   WHEN @cInquiry_ID <> '' THEN ' GROUP BY LLI.LOC, LLI.SKU) A '
   WHEN @cInquiry_SKU <> '' THEN ' GROUP BY LLI.LOC, LLI.ID) A ' END 

   SET @cExecArguments = N'@nTotalRec            INT    OUTPUT ' 

   EXEC sp_ExecuteSql @cExecStatements
                     , @cExecArguments
                     , @nTotalRec          OUTPUT

   IF @nTotalRec = 0
   BEGIN
      SET @nErrNo = 60682
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No record'
      GOTO Quit
   END

   -- (james02)
   -- Get sku lottable code
   SELECT TOP 1 @cLottableCode = SKU.LottableCode
   FROM dbo.SKU SKU WITH (NOLOCK)
   JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
   WHERE SKU.StorerKey = @cStorerKey
   AND   ( ( @cInquiry_LOC = '') OR ( LLI.LOC = @cInquiry_LOC))
   AND   ( ( @cInquiry_ID = '') OR ( LLI.ID = @cInquiry_ID))
   AND   ( ( @cInquiry_SKU = '') OR ( LLI.SKU = @cInquiry_SKU))
   ORDER BY 1 DESC   -- Not blank

   IF NOT EXISTS ( SELECT 1 FROM rdt.rdtLottableCode WITH (NOLOCK)
                   WHERE LottableCode = @cLottableCode
                   AND   Function_ID = @nFunc
                   AND   StorerKey = @cStorerkey)
      SET @cLottableCode = ''

   -- Get stock info
   IF @cInquiry_LOC <> '' SET @cLOC = @cInquiry_LOC
   IF @cInquiry_ID <> '' SET @cID = @cInquiry_ID
   IF @cInquiry_SKU <> '' SET @cSKU = @cInquiry_SKU

   -- If no lottablecode setup then no need get Lot to show
   SET @cExecStatements = N' SELECT TOP 1 ' + CASE WHEN ISNULL( @cLottableCode, '') <> '' THEN '@cLOT = LLI.LOT, ' ELSE '' END

   SET @cExecStatements = @cExecStatements + 
   CASE WHEN @cInquiry_LOC <> '' THEN ' @cID = LLI.ID, @cSKU = LLI.SKU, '
   WHEN @cInquiry_ID <> '' THEN ' @cLOC = LLI.LOC, @cSKU = LLI.SKU, '
   WHEN @cInquiry_SKU <> '' THEN ' @cLOC = LLI.LOC, @cID = LLI.ID, ' END 

   SET @cExecStatements = @cExecStatements + 
   ' @nMQTY_Alloc = ISNULL( SUM( LLI.QTYAllocated), 0), ' +
   ' @nMQTY_Pick  = ISNULL( SUM( LLI.QTYPicked), 0), ' +
   ' @nMQTY_Avail = ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0), ' + 
   ' @nMQty_TTL = ISNULL( SUM( LLI.Qty), 0), ' +
   ' @nMQty_RPL = CASE WHEN ISNULL( SUM( LLI.QtyReplen), 0) < 0 THEN 0 ELSE ISNULL( SUM( LLI.QtyReplen), 0) END, ' + 
   ' @nMQty_PMV = ISNULL( SUM( LLI.PendingMoveIN), 0) ' + 
   ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' + 
   ' JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC) ' + 
   ' WHERE LLI.StorerKey = ''' + RTRIM(@cStorerKey)  + ''' ' +
   ' AND   LOC.Facility = ''' + RTRIM(@cFacility)  + ''' ' +
   ' AND ( LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) '

   SET @cExecStatements = @cExecStatements + 
   CASE WHEN @cInquiry_LOC <> '' THEN ' AND LLI.LOC = ''' + @cInquiry_LOC + ''' '
   WHEN @cInquiry_ID <> '' THEN ' AND LLI.ID = ''' + @cInquiry_ID + ''' '
   WHEN @cInquiry_SKU <> '' THEN ' AND LLI.SKU = ''' + @cInquiry_SKU + ''' ' END 

   SET @cExecStatements = @cExecStatements + 
   CASE WHEN @cInquiry_LOC <> '' THEN ' AND (( @cType = '''') OR ( LLI.ID + LLI.SKU > ''' + @cID + ''' + ''' + '' + @cSKU + ''' ))'
   WHEN @cInquiry_ID <> '' THEN ' AND (( @cType = '''') OR ( LLI.LOC + LLI.SKU > ''' + @cLOC + ''' + ''' + '' + @cSKU + ''' ))'
   WHEN @cInquiry_SKU <> '' THEN ' AND (( @cType = '''') OR ( LLI.LOC + LLI.ID > ''' + @cLOC + ''' + ''' + '' + @cID + ''' ))' END

   SET @cExecStatements = @cExecStatements + 
   CASE WHEN @cInquiry_LOC <> '' THEN ' GROUP BY ' + CASE WHEN ISNULL( @cLottableCode, '') <> '' THEN 'LLI.LOT, ' ELSE '' END + 'LLI.ID, LLI.SKU ORDER BY LLI.ID + LLI.SKU '
   WHEN @cInquiry_ID <> '' THEN ' GROUP BY ' + CASE WHEN ISNULL( @cLottableCode, '') <> '' THEN 'LLI.LOT, ' ELSE '' END + ' LLI.LOC, LLI.SKU ORDER BY LLI.LOC + LLI.SKU '
   WHEN @cInquiry_SKU <> '' THEN ' GROUP BY ' + CASE WHEN ISNULL( @cLottableCode, '') <> '' THEN 'LLI.LOT, ' ELSE '' END + 'LLI.LOC, LLI.ID ORDER BY LLI.LOC + LLI.ID ' END 

   SET @cExecArguments = N'@cLOT          NVARCHAR( 10)  OUTPUT, ' + 
                          '@cLOC          NVARCHAR( 10)  OUTPUT, ' + 
                          '@cID           NVARCHAR( 18)  OUTPUT, ' + 
                          '@cSKU          NVARCHAR( 20)  OUTPUT, ' + 
                          '@nMQTY_Alloc   INT            OUTPUT, ' +
                          '@nMQTY_Pick    INT            OUTPUT, ' +
                          '@nMQTY_Avail   INT            OUTPUT, ' +
                          '@nMQTY_TTl     INT            OUTPUT, ' +
                          '@nMQTY_RPL     INT            OUTPUT, ' +
                          '@nMQTY_PMV     INT            OUTPUT, ' +
                          '@cType         NVARCHAR( 10) '

   EXEC sp_ExecuteSql @cExecStatements
                     , @cExecArguments
                     , @cLOT           OUTPUT
                     , @cLOC           OUTPUT
                     , @cID            OUTPUT
                     , @cSKU           OUTPUT
                     , @nMQTY_Alloc    OUTPUT
                     , @nMQTY_Pick     OUTPUT
                     , @nMQTY_Avail    OUTPUT
                     , @nMQTY_TTL      OUTPUT
                     , @nMQTY_RPL      OUTPUT
                     , @nMQTY_PMV      OUTPUT
                     , @cType

   -- Validate if any result
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 60683
      SET @cErrMsg = rdt.rdtgetmessage( 60683, @cLangCode, 'DSP') --'No record'
   END

   SELECT
      @cSKUDescr = SKU.Descr,
      @cLottableCode = SKU.LottableCode, 
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
   JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PackKey = PACK.PackKey)
   WHERE SKU.StorerKey = @cStorerKey
   AND   SKU.SKU = @cSKU

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

   SELECT @cLottable01 = Lottable01,
          @cLottable02 = Lottable02,
          @cLottable03 = Lottable03,
          @dLottable04 = Lottable04,
          @dLottable05 = Lottable05,
          @cLottable06 = Lottable06,
          @cLottable07 = Lottable07,
          @cLottable08 = Lottable08,
          @cLottable09 = Lottable09,
          @cLottable10 = Lottable10,
          @cLottable11 = Lottable11,
          @cLottable12 = Lottable12,
          @dLottable13 = Lottable13,
          @dLottable14 = Lottable14,
          @dLottable15 = Lottable15
   FROM dbo.LOTAttribute WITH (NOLOCK)
   WHERE LOT = @cLot

   QUIT:

GO