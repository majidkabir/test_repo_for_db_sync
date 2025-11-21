SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdt_SKUStyle_Inquiry                                */    
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 23-05-2019 1.0  Ung      WMS-9078 Created                            */
/* 10-06-2021 1.1 Chermaine WMS-17188 Add Custom sql (cc01)             */
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_SKUStyle_Inquiry] (    
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cStorerkey      NVARCHAR( 15),
   @cPUOM           NVARCHAR( 1),
   @cStyle          NVARCHAR( 20),
   @cLOT            NVARCHAR( 10)  OUTPUT, 
   @cLOC            NVARCHAR( 10)  OUTPUT,
   @cID             NVARCHAR( 18)  OUTPUT, 
   @cSKU            NVARCHAR( 20)  OUTPUT,
   @cSKUDescr       NVARCHAR( 60)  OUTPUT,
   @nTotalRec       INT            OUTPUT,
   @nMQTY_TTL       INT            OUTPUT,
   @nMQTY_Hold      INT            OUTPUT,
   @nMQTY_Alloc     INT            OUTPUT,
   @nMQTY_Pick      INT            OUTPUT,
   @nMQTY_RPL       INT            OUTPUT,
   @nMQTY_Avail     INT            OUTPUT,
   @nPQTY_TTL       INT            OUTPUT,
   @nPQTY_Hold      INT            OUTPUT,
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
   @nErrNo          INT            OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT  
) AS    
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF   
   
   DECLARE @nPUOM_Div INT
   DECLARE @cTempLOT  NVARCHAR( 10)
   DECLARE @cTempSKU  NVARCHAR( 20)
   
   SET @cTempLOT = @cLOT
   SET @cTempSKU = @cSKU
   
   --(cc01)
   DECLARE
      @cTotalCountSQL   NVARCHAR( 1000),
      @cSQLArguements   NVARCHAR( 1000),
      @cSQL             NVARCHAR( 2000),
      @cExecArguments   NVARCHAR( 1000),

      @cCustom          NVARCHAR( 10)

   SET @cCustom = rdt.RDTGetConfig( @nFunc, 'LocTypeLookup', @cStorerkey)  
   

   -- Get total records
   IF @nTotalRec = 0
   BEGIN
      --SELECT @nTotalRec = COUNT( 1)
      --FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      --   JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
      --   JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
      --   JOIN dbo.SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
      --   JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (LLI.StorerKey = SL.StorerKey AND LLI.SKU = SL.SKU AND LLI.LOC = SL.LOC)
      --WHERE LOC.Facility = @cFacility
      --   AND SL.LocationType IN ('PICK', 'CASE')
      --   AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
      --   AND SKU.StorerKey = @cStorerKey
      --   AND SKU.Style = @cStyle
      
       SET @cTotalCountSQL = N'SELECT @nTotalRec = COUNT( 1) '  
                        + ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) '
                        + ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC) '
                        + ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT) '
                        + ' JOIN dbo.SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU) '
                          
                       + CASE WHEN @cCustom = '0' THEN ' JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (LLI.StorerKey = SL.StorerKey AND LLI.SKU = SL.SKU AND LLI.LOC = SL.LOC) ' ELSE '' END 
                       
                        + ' WHERE LOC.Facility = @cFacility '
                        + ' AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) '
                        + ' AND SKU.StorerKey = @cStorerKey '
                        + ' AND SKU.Style = @cStyle '
                        + CASE WHEN @cCustom = '0' THEN ' AND SL.LocationType IN (''PICK'', ''CASE'') '  ELSE 'AND LOC.LocationType IN (''PICK'') ' END
                        
       SET @cSQLArguements= N'@nTotalRec    INT    OUTPUT' 
                        + ' ,@cFacility     NVARCHAR(5)' 
                        + ' ,@cStorerKey    NVARCHAR(15)'  
                        + ' ,@cStyle        NVARCHAR(20)'  
                      
    
      EXEC sp_ExecuteSQL @cTotalCountSQL  
                     ,@cSQLArguements  
                     ,@nTotalRec    OUTPUT
                     ,@cFacility  
                     ,@cStorerKey  
                     ,@cStyle   
                        
         

      IF @nTotalRec = 0
      BEGIN
         SET @nErrNo = 139001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No record
         GOTO Quit
      END
   END

   -- Get next record
   --SELECT TOP 1 
   --   @cLOT = LLI.LOT, 
   --   @cLOC = LLI.LOC, 
   --   @cID = LLI.ID, 
   --   @cSKU = LLI.SKU, 
   --   @nMQTY_Alloc = SUM( LLI.QTYAllocated), 
   --   @nMQTY_Pick  = SUM( LLI.QTYPicked), 
   --   @nMQTY_Avail = SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 
   --   @nMQty_TTL = SUM( LLI.Qty), 
   --   @nMQty_RPL = SUM( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)
   --FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   --   JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
   --   JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
   --   JOIN dbo.SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
   --   JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (LLI.StorerKey = SL.StorerKey AND LLI.SKU = SL.SKU AND LLI.LOC = SL.LOC)
   --WHERE LOC.Facility = @cFacility
   --   AND SL.LocationType IN ('PICK', 'CASE')
   --   AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
   --   AND LLI.StorerKey = @cStorerKey
   --   AND SKU.Style = @cStyle
   --   AND (LOC.LOC > @cLOC 
   --   OR  (LOC.LOC = @cLOC AND SKU.SKU > @cSKU) 
   --   OR  (LOC.LOC = @cLOC AND SKU.SKU = @cSKU AND LLI.ID > @cID) 
   --   OR  (LOC.LOC = @cLOC AND SKU.SKU = @cSKU AND LLI.ID = @cID AND LLI.LOT > @cLOT))
   --GROUP BY LLI.LOC, LLI.SKU, LLI.ID, LLI.LOT
   --ORDER BY LLI.LOC, LLI.SKU, LLI.ID, LLI.LOT

   SET @cSQL = N'SELECT TOP 1 '  
            + ' @cLOT = LLI.LOT, '
            + ' @cLOC = LLI.LOC, '
            + ' @cID = LLI.ID, '
            + ' @cSKU = LLI.SKU, ' 
            + ' @nMQTY_Alloc = SUM( LLI.QTYAllocated), '
            + ' @nMQTY_Pick  = SUM( LLI.QTYPicked), '
            + ' @nMQTY_Avail = SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), '
            + ' @nMQty_TTL = SUM( LLI.Qty), '
            + ' @nMQty_RPL = SUM( CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) '
            + ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) '
            + ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC) '
            + ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT) '
            + ' JOIN dbo.SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU) '
                          
            + CASE WHEN @cCustom = '0' THEN ' JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (LLI.StorerKey = SL.StorerKey AND LLI.SKU = SL.SKU AND LLI.LOC = SL.LOC) '  ELSE '' END
            
            + ' WHERE LOC.Facility = @cFacility '
            + CASE WHEN @cCustom = '0' THEN ' AND SL.LocationType IN (''PICK'', ''CASE'') '  ELSE 'AND LOC.LocationType IN (''PICK'') ' END
            + ' AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) '
            + ' AND LLI.StorerKey = @cStorerKey '
            + ' AND SKU.Style = @cStyle '
            + ' AND (LOC.LOC > @cLOC ' 
            + ' OR  (LOC.LOC = @cLOC AND SKU.SKU > @cSKU) ' 
            + ' OR  (LOC.LOC = @cLOC AND SKU.SKU = @cSKU AND LLI.ID > @cID) ' 
            + ' OR  (LOC.LOC = @cLOC AND SKU.SKU = @cSKU AND LLI.ID = @cID AND LLI.LOT > @cLOT)) '
            + ' GROUP BY LLI.LOC, LLI.SKU, LLI.ID, LLI.LOT '
            + ' ORDER BY LLI.LOC, LLI.SKU, LLI.ID, LLI.LOT '
            
   SET @cExecArguments= N'@cLOT          NVARCHAR(10)   OUTPUT' 
                     + ' ,@cLOC           NVARCHAR(10)   OUTPUT' 
                     + ' ,@cID            NVARCHAR(18)   OUTPUT'  
                     + ' ,@cSKU           NVARCHAR(20)   OUTPUT'  
                     + ' ,@nMQTY_Alloc    INT   OUTPUT'
                     + ' ,@nMQTY_Pick     INT   OUTPUT'
                     + ' ,@nMQTY_Avail    INT   OUTPUT'
                     + ' ,@nMQty_TTL      INT   OUTPUT'
                     + ' ,@nMQty_RPL      INT   OUTPUT'
                     + ' ,@cFacility      NVARCHAR(5)' 
                     + ' ,@cStorerKey     NVARCHAR(15)'  
                     + ' ,@cStyle         NVARCHAR(20)'
  
    
   EXEC sp_ExecuteSQL @cSQL  
                  ,@cExecArguments  
                  ,@cLOT   OUTPUT
                  ,@cLOC   OUTPUT
                  ,@cID    OUTPUT
                  ,@cSKU   OUTPUT
                  ,@nMQTY_Alloc  OUTPUT
                  ,@nMQTY_Pick   OUTPUT 
                  ,@nMQTY_Avail  OUTPUT 
                  ,@nMQty_TTL    OUTPUT
                  ,@nMQty_RPL    OUTPUT
                  ,@cFacility 
                  ,@cStorerKey
                  ,@cStyle    


   -- Check result
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 139002
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more record
      SET @nTotalRec = -1
      GOTO Quit
   END

   -- Get SKU info
   IF @cSKU <> @cTempSKU
      SELECT 
         @cLottableCode = LottableCode, 
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
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

   -- Get lottable
   IF @cLOT <> @cTempLOT
      SELECT 
         @cLottable01 = Lottable01,  
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
      FROM LOTAttribute WITH (NOLOCK)
      WHERE LOT = @cLOT
      
   SET @nMQTY_Hold = 0
      
   -- Hold by LOC
   IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC AND Facility = @cFacility AND LocationFlag = 'HOLD')
      SELECT @nMQTY_Hold = QTY
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE LOC = @cLOC
         AND LOT = @cLOT
         AND ID = @cID

   -- Hold by LOT
   ELSE IF EXISTS (SELECT 1 FROM dbo.InventoryHold WITH (NOLOCK) WHERE LOT = @cLOT AND Hold = '1')
      SELECT @nMQTY_Hold = QTY
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE LOC = @cLOC
         AND LOT = @cLOT
         AND ID = @cID
   
   -- Hold by ID
   ELSE IF EXISTS (SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cID AND Status = 'HOLD')
      SELECT @nMQTY_Hold = QTY
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE LOC = @cLOC
         AND LOT = @cLOT
         AND ID = @cID

   SET @nMQTY_Avail = @nMQTY_Avail - @nMQTY_Hold
      
   IF @cPUOM = '6' OR -- When preferred UOM = master unit
      @nPUOM_Div = 0 -- UOM not setup
   BEGIN
      SET @cPUOM_Desc = ''
      SET @nPQTY_Alloc = 0
      SET @nPQTY_Avail = 0
      SET @nPQTY_Hold = 0 
      SET @nPQTY_TTL = 0 
      SET @nPQTY_RPL = 0 
   END
   ELSE
   BEGIN
      -- Calc QTY in preferred UOM
      SET @nPQTY_Avail = CAST(@nMQTY_Avail AS INT) / @nPUOM_Div  
      SET @nPQTY_Alloc = CAST(@nMQTY_Alloc AS INT) / @nPUOM_Div  
      SET @nPQTY_Hold  = CAST(@nMQTY_Hold  AS INT) / @nPUOM_Div  
      SET @nPQTY_TTL   = CAST(@nMQTY_TTL   AS INT) / @nPUOM_Div  
      SET @nPQTY_RPL   = CAST(@nMQTY_RPL   AS INT) / @nPUOM_Div  
      SET @nPQTY_Pick  = CAST(@nMQTY_Pick  AS INT) / @nPUOM_Div  

      -- Calc the remaining in master unit
      SET @nMQTY_Avail = CAST(@nMQTY_Avail as INT)  % @nPUOM_Div
      SET @nMQTY_Alloc = CAST(@nMQTY_Alloc as INT)  % @nPUOM_Div
      SET @nMQTY_Hold  = CAST(@nMQTY_Hold  as INT)  % @nPUOM_Div   
      SET @nMQTY_TTL   = CAST(@nMQTY_TTL   as INT)  % @nPUOM_Div   
      SET @nMQTY_RPL   = CAST(@nMQTY_RPL   as INT)  % @nPUOM_Div   
      SET @nMQTY_Pick  = CAST(@nMQTY_Pick  as INT)  % @nPUOM_Div   
   END
      
Quit:

END

GO