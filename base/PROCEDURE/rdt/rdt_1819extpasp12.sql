SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP12                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 08-May-2017  1.0  James    WMS4315. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP12] (
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
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKU  NVARCHAR( 20),           
           @cPAStrategyKey NVARCHAR( 10),
           @cDivision      NVARCHAR( 30),
           @cUDF01         NVARCHAR( 60),
           @cUDF02         NVARCHAR( 60),
           @cUDF03         NVARCHAR( 60),
           @cUDF04         NVARCHAR( 60),
           @cUDF05         NVARCHAR( 60),
           @cPutawayZone   NVARCHAR( 10)
           
   DECLARE @nTranCount  INT

   -- 1 pallet only 1 division
   IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.SKU = SKU.SKU AND LLI.StorerKey = SKU.StorerKey)
               WHERE LLI.LOC = @cFromLoc
               AND   LLI.ID = @cID
               AND   LLI.Qty > 0
               AND   LLI.StorerKey = @cStorerKey
               GROUP BY LLI.ID
               HAVING COUNT( DISTINCT SKU.BUSR7) > 1)
   BEGIN
      SET @nErrNo = 122451
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix Division
      GOTO Quit
   END

   -- Check if pallet exists in >1 loc
   IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN dbo.LOC LOC ON ( LLI.LOC = LOC.LOC)
               WHERE LLI.ID = @cID
               AND   LLI.Qty > 0
               AND   LLI.StorerKey = @cStorerKey
               AND   LOC.Facility = @cFacility
               GROUP BY ID
               HAVING COUNT( DISTINCT LLI.LOC) > 1)

   BEGIN
      SET @nErrNo = 122452
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID In >1 Loc
      GOTO Quit
   END

   SELECT TOP 1 @cSKU = SKU
   FROM dbo.LOTxLOCxID WITH (NOLOCK)
   WHERE LOC = @cFromLoc
   AND   ID = @cID
   AND   Qty > 0
   AND   StorerKey = @cStorerKey
   ORDER BY 1

   SELECT @cDivision = BUSR7
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU

   SELECT @cUDF01 = UDF01, 
          @cUDF02 = UDF02, 
          @cUDF03 = UDF03, 
          @cUDF04 = UDF04, 
          @cUDF05 = UDF05
   FROM dbo.CodeLkup WITH (NOLOCK)
   WHERE ListName = 'RDTExtPA'
      AND Code = 'Division'
      AND code2 = @cDivision
      AND StorerKey = @cStorerKey

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
      SET @nErrNo = 122453
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No PA Zone
      GOTO Quit
   END
    --select * from #PAZone
   -- Look for loc with same style (sku.itemclass)
   --SELECT TOP 1 @cSuggLOC = LOC.LOC, @cPutawayZone = LOC.Putawayzone
   --FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   --JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.SKU = SKU.SKU AND LLI.StorerKey = SKU.StorerKey)
   --JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   --JOIN #PAZone PAZONE ON ( LOC.Putawayzone = PAZone.PAZone)
   --WHERE LLI.StorerKey = @cStorerKey
   --AND   LOC.Facility = @cFacility   
   --AND   LLI.LOC <> @cFromLOC
   --GROUP BY LOC.Putawayzone, LOC.LOC
   --HAVING ISNULL( SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
   --      (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)), 0) > 0
   --ORDER BY LOC.Putawayzone, LOC.Loc

   -- Look for empty loc
   --IF ISNULL( @cSuggLOC, '') = ''
      SELECT TOP 1 @cSuggLOC = LOC.LOC, @cPutawayZone = LOC.Putawayzone
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

      --IF suser_sname() = 'jameswong'
      --begin
      --   select '@cErrMsg', @cSuggLOC
      --   goto Quit
      --end
   IF ISNULL( @cSuggLOC, '') <> ''
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP12 -- For rollback or commit only our own transaction

      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cFromLOC
         ,@cID
         ,@cSuggLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@nPABookingKey = @nPABookingKey OUTPUT

      IF @nErrNo <> 0
         ROLLBACK TRAN rdt_1819ExtPASP12 -- Only rollback change made here
      
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

   END
Quit:

END


GO