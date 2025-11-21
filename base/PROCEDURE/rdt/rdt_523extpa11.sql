SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtPA11                                      */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*                                                                      */
/* Called from: rdtfnc_PutawayBySKU                                     */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 09-Jul-2017  1.0  James    WMS1862. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA11] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5), 
   @cLOC             NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cLOT             NVARCHAR( 10),
   @cUCC             NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQty             INT,          
   @cSuggestedLOC    NVARCHAR( 10) OUTPUT,  
   @nPABookingKey    INT           OUTPUT,  
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE 
           @cPAType  NVARCHAR( 10),
           @cPAStrategyKey NVARCHAR( 10),
           @cStockType     NVARCHAR( 30),
           @cDivision      NVARCHAR( 30),
           @cTerm          NVARCHAR( 10),
           @cLottable02    NVARCHAR( 18),
           @cLottable06    NVARCHAR( 30),
           @cUDF01         NVARCHAR( 60),
           @cUDF02         NVARCHAR( 60),
           @cUDF03         NVARCHAR( 60),
           @cUDF04         NVARCHAR( 60),
           @cUDF05         NVARCHAR( 60),
           @cStyle         NVARCHAR( 10),
           @cPutawayZone   NVARCHAR( 10),
           @nTerm          INT,
           @dLottable05    DATETIME,
           @dLottable13    DATETIME
           

   SET @cTerm = ''

   DECLARE @nTranCount  INT

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA11 -- For rollback or commit only our own transaction

   -- 1 pallet only 1 division
   IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.SKU = SKU.SKU AND LLI.StorerKey = SKU.StorerKey)
               WHERE LLI.LOC = @cLoc
               AND   LLI.ID = @cID
               AND   LLI.Qty > 0
               AND   LLI.StorerKey = @cStorerKey
               GROUP BY LLI.ID
               HAVING COUNT( DISTINCT SKU.BUSR7) > 1)
   BEGIN
      SET @nErrNo = 114051
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix Division
      GOTO RollBackTran
   END

   -- 1 pallet only 1 stock type
   IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
               WHERE LLI.LOC = @cLoc
               AND   LLI.ID = @cID
               AND   LLI.Qty > 0
               AND   LLI.StorerKey = @cStorerKey
               GROUP BY LLI.ID
               HAVING COUNT( DISTINCT LA.Lottable06) > 1)
   BEGIN
      SET @nErrNo = 114052
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix Stock Type
      GOTO RollBackTran
   END

   SELECT @cDivision = BUSR7,
          @cStyle = Itemclass
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU

   SELECT @cLottable02 = Lottable02,
          @dLottable05 = Lottable05, 
          @cLottable06 = Lottable06, 
          @dLottable13 = Lottable13
   FROM dbo.LOTAttribute WITH (NOLOCK)
   WHERE LOT = @cLOT

   -- Determine stock type
   IF @cLottable02 = '01000'
   BEGIN
      IF ISNULL( @cLottable06, '') = ''
         SET @cStockType = 'NORMAL'
      ELSE
         SET @cStockType =  @cLottable06
   END
   ELSE--   IF @cLottable02 = '01PMO'
      SET @cStockType = 'PMO'
   
   SET @nTerm = DATEDIFF( d, @dLottable05, @dLottable13)

   IF @cStockType = 'NORMAL'
   BEGIN
      IF @nTerm <= 60
      BEGIN
         SET @cTerm = 'INLINE'
      END
      ELSE IF ( @nTerm > 60 AND @nTerm < 366)
         SET @cTerm = 'CLOSEOUT'
      ELSE
         SET @cTerm = 'DEADSTOCK'

      IF ISNULL( @cStockType, '') = ''
      BEGIN
         SET @nErrNo = 114053
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Stock Type
         GOTO RollBackTran
      END
   END

   SELECT @cPAStrategyKey = ISNULL( Short, ''),
          @cUDF01 = UDF01, 
          @cUDF02 = UDF02, 
          @cUDF03 = UDF03, 
          @cUDF04 = UDF04, 
          @cUDF05 = UDF05
   FROM dbo.CodeLkup WITH (NOLOCK)
   WHERE ListName = 'RDTExtPA'
      AND ( ( ISNULL( @cTerm, '') = '') OR ( Code = @cTerm))
      AND code2 = @cDivision
      AND Long = @cStockType
      AND StorerKey = @cStorerKey

   -- Check blank putaway strategy
   IF @cPAStrategyKey = ''
   BEGIN
      SET @nErrNo = 114054
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- StrategyNotSet
      GOTO RollBackTran
   END

   CREATE TABLE #PAZone (
   RowRef  INT IDENTITY(1,1) NOT NULL,
   PAZone  NVARCHAR(10)  NULL)

   IF ISNULL( @cUDF01, '') <> ''
      INSERT INTO #PAZone (PAZone) VALUES (@cUDF01)

   IF ISNULL( @cUDF02, '') <> ''
      INSERT INTO #PAZone (PAZone) VALUES (@cUDF02)
   
   IF ISNULL( @cUDF03, '') <> ''
      INSERT INTO #PAZone (PAZone) VALUES (@cUDF03)

   IF ISNULL( @cUDF04, '') <> ''
      INSERT INTO #PAZone (PAZone) VALUES (@cUDF04)

   IF ISNULL( @cUDF05, '') <> ''
      INSERT INTO #PAZone (PAZone) VALUES (@cUDF05)

   -- Check blank putaway strategy
   IF NOT EXISTS ( SELECT 1 FROM #PAZone)
   BEGIN
      SET @nErrNo = 114055
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No PA Zone
      GOTO RollBackTran
   END
    --select * from #PAZone
   -- Look for loc with same style (sku.itemclass)
   SELECT TOP 1 @cSuggestedLOC = LOC.LOC, @cPutawayZone = LOC.Putawayzone
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.SKU = SKU.SKU AND LLI.StorerKey = SKU.StorerKey)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   JOIN #PAZone PAZONE ON ( LOC.Putawayzone = PAZone.PAZone)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LOC.Facility = @cFacility   
   AND   LLI.LOC <> @cLoc
   AND   SKU.ItemClass = @cStyle
   GROUP BY LOC.Putawayzone, LOC.LOC
   HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
         (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) > 0
   ORDER BY LOC.Putawayzone, LOC.Loc

   -- Look for empty loc
   IF ISNULL( @cSuggestedLOC, '') = ''
      SELECT TOP 1 @cSuggestedLOC = LOC.LOC, @cPutawayZone = LOC.Putawayzone
      FROM dbo.LOC LOC WITH (NOLOCK) 
      JOIN #PAZone PAZONE ON ( LOC.Putawayzone = PAZone.PAZone)
      LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
      AND   LOC.Locationflag <> 'HOLD'
      AND   LOC.Locationflag <> 'DAMAGE'
      AND   LOC.Status <> 'HOLD'
      GROUP BY LOC.Putawayzone, LOC.LOC 
      -- Empty LOC
      HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) = 0 
      ORDER BY LOC.Putawayzone, LOC.Loc 

   IF ISNULL( @cSuggestedLOC, '') <> ''
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cLoc
         ,@cID
         ,@cSuggestedLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA11 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO