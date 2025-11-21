SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP10                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 29-03-2018  1.0  Ung      WMS-4160 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP10] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10)  OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT,
   @nPABookingKey    INT            OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT, 
   @cToFacility      NVARCHAR( 5) = '' -- For Exceed IQC
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKU           NVARCHAR(20)
   DECLARE @cPackKey       NVARCHAR(10)
   DECLARE @cSKUZone       NVARCHAR(10)
   DECLARE @cBUSR10        NVARCHAR(30)
   DECLARE @cItemClass     NVARCHAR(10)
   DECLARE @cLottable02    NVARCHAR(18)
   DECLARE @cUDF05         NVARCHAR(60)
   DECLARE @nPallet        INT
   DECLARE @nPalletHi      INT
   DECLARE @nQTY           INT

   SET @cSuggLOC = ''

   -- Check pallet booked (thru FN598 container receiving)
   SELECT 
      @cSuggLOC = SuggestedLOC, 
      @nPABookingKey = PABookingKey
   FROM RFPutaway WITH (NOLOCK)
   WHERE FromLOC = @cFromLOC
      AND FromID = @cID
      
   -- Pallet was booked
   IF @cSuggLOC <> ''
      GOTO Quit
   
   -- For Exceed IQC
   IF @cToFacility = ''
   BEGIN
      DECLARE @n_IsRDT INT  
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT       
      IF @n_IsRDT = 1
         SELECT @cToFacility = Code FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'PNGPAFAC' AND StorerKey = @cStorerKey

      IF @cToFacility = ''
         SET @cToFacility = @cFacility
   END
   
   -- Get pallet info (1 pallet 1 SKU)
   SELECT TOP 1 
      @cSKU = LLI.SKU, 
      @cPackKey = SKU.PackKey,
      @cSKUZone = SKU.PutawayZone, 
      @cLottable02 = LA.Lottable02, 
      @cBUSR10 = SKU.BUSR10, 
      @cItemClass = SKU.ItemClass, 
      @nPallet = Pallet, 
      @nPalletHi = PalletHi
   FROM LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
      JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
   WHERE LOC.Facility = @cFacility
      AND LLI.StorerKey = @cStorerKey 
      AND LLI.ID = @cID
      AND LLI.QTY > 0

   -- Check pallet valid
   IF @@ROWCOUNT = 0
   BEGIN
      SET @cSuggLOC = ''
      SET @nErrNo = 122201
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
   END

   -- Get pallet QTY
   SELECT @nQTY = SUM( LLI.QTY) 
   FROM LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
      AND LLI.ID = @cID
      AND LLI.StorerKey = @cStorerKey 
      AND LLI.SKU = @cSKU
      AND LLI.QTY > 0

   -- Pallet is setup
   IF @nPallet > 0 AND @nPalletHi > 0
   BEGIN
      -- QTY less then 1 layer
      IF @nQTY < (@nPallet / @nPalletHi)
      BEGIN
         SET @nErrNo = 122202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY too little
         GOTO Quit
      END
   END
   
   -- Find empty location, in SKU own area
   IF @cBUSR10 <> '' -- SKU own area
   BEGIN
      -- Double with 1 slot empty
      SELECT TOP 1 
         @cSuggLOC = LOC.LOC
      FROM LOC WITH (NOLOCK) 
         JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
      WHERE LOC.Facility = @cToFacility
         AND LOC.LocationGroup = @cBUSR10
         AND LOC.LocationType = 'OTHER'
         AND LOC.LocationFlag <> 'HOLD'
         AND LOC.LocationCategory = 'DOUBLE'
         AND LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LA.Lottable02 = @cLottable02
         AND (LLI.QTY > 0 OR LLI.PendingMoveIn > 0)
      GROUP BY LOC.PALogicalLOC, LOC.LOC 
      HAVING COUNT( DISTINCT LLI.ID) = 1
      ORDER BY LOC.PALogicalLOC, LOC.LOC DESC

      IF @cSuggLOC <> ''
         GOTO Quit

      -- Single / double bin
      SELECT TOP 1 
         @cSuggLOC = LOC.LOC
      FROM LOC WITH (NOLOCK) 
         LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cToFacility
         AND LOC.LocationGroup = @cBUSR10
         AND LOC.LocationType = 'OTHER'
         AND LOC.LocationFlag <> 'HOLD'
      GROUP BY LOC.PALogicalLOC, LOC.LOC
      HAVING SUM( ISNULL( LLI.QTY, 0)) = 0 
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
      ORDER BY LOC.PALogicalLOC, LOC.LOC DESC
         
      IF @cSuggLOC <> ''
         GOTO Quit
   END

   -- Putaway to DOUBLE priority
   SET @cUDF05 = ''
   SELECT @cUDF05 = UDF05
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'ItemClass'
      AND StorerKey = @cStorerKey
      AND Code = @cItemClass

   IF @cUDF05 = 'D'
   BEGIN
      -- Double with 1 slot empty
      SELECT TOP 1 
         @cSuggLOC = LOC.LOC
      FROM LOC WITH (NOLOCK) 
         JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
      WHERE LOC.Facility = @cToFacility
         AND LOC.LocationType = 'OTHER'
         AND LOC.LocationFlag <> 'HOLD'
         AND LOC.LocationCategory = 'DOUBLE'
         AND LOC.SectionKey = @cStorerKey
         AND LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LA.Lottable02 = @cLottable02
         AND (LLI.QTY > 0 OR LLI.PendingMoveIn > 0)
      GROUP BY LOC.PALogicalLOC, LOC.LOC 
      HAVING COUNT( DISTINCT LLI.ID) = 1
      ORDER BY LOC.PALogicalLOC, LOC.LOC DESC

      IF @cSuggLOC <> ''
         GOTO Quit
         
      -- Empty double
      SELECT TOP 1 
         @cSuggLOC = LOC.LOC
      FROM LOC WITH (NOLOCK) 
         LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cToFacility
         AND LOC.LocationType = 'OTHER'
         AND LOC.LocationFlag <> 'HOLD'
         AND LOC.LocationCategory = 'DOUBLE'
         AND LOC.SectionKey = @cStorerKey
      GROUP BY LOC.PALogicalLOC, LOC.LOC
      HAVING SUM( ISNULL( LLI.QTY, 0)) = 0 
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
      ORDER BY LOC.PALogicalLOC, LOC.LOC DESC
      
      IF @cSuggLOC <> ''
         GOTO Quit
   END

   -- Putaway to SKU.PutawayZone
   -- Double with 1 slot empty
   SELECT TOP 1 
      @cSuggLOC = LOC.LOC
   FROM LOC WITH (NOLOCK) 
      JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cToFacility
      AND LOC.LocationType = 'OTHER'
      AND LOC.LocationFlag <> 'HOLD'
      AND LOC.LocationCategory = 'DOUBLE'
      AND LOC.PutawayZone = @cSKUZone
      AND (LLI.QTY > 0 OR LLI.PendingMoveIn > 0)
   GROUP BY LOC.PALogicalLOC, LOC.LOC 
   HAVING COUNT( DISTINCT LLI.ID) = 1
   ORDER BY LOC.PALogicalLOC, LOC.LOC DESC
   
   IF @cSuggLOC <> ''
      GOTO Quit

   -- Single / double bin
   SELECT TOP 1 
      @cSuggLOC = LOC.LOC
   FROM LOC WITH (NOLOCK) 
      LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cToFacility
      AND LOC.LocationType = 'OTHER'
      AND LOC.LocationFlag <> 'HOLD'
      AND LOC.PutawayZone = @cSKUZone
   GROUP BY LOC.PALogicalLOC, LOC.LOC
   HAVING SUM( ISNULL( LLI.QTY, 0)) = 0 
      AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
   ORDER BY LOC.PALogicalLOC, LOC.LOC DESC


Quit:
   IF @cSuggLOC = ''
      SET @nErrNo = -1 -- Alloc continue with manual putaway
   ELSE
   BEGIN
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cFromLOC
         ,@cID
         ,@cSuggLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@nPABookingKey = @nPABookingKey OUTPUT
   END
END

GO