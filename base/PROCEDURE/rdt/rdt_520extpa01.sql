SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_520ExtPA01                                      */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Customized PA logic for Granite                              */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 20-11-2024   1.0  CYU027    FCR-1205 Created                           */
/************************************************************************/

CREATE   PROC [RDT].[rdt_520ExtPA01] (
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
   @cPickAndDropLoc  NVARCHAR( 10) OUTPUT,
   @nPABookingKey    INT           OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @nTranCount             INT,
            @bDebugFlag             BIT = 0,
            @n_PalletCube           DECIMAL(15,5)

   SET @nTranCount = @@TRANCOUNT


   SET @cSuggestedLOC = ''

   -- Get book loc info
   SELECT @cSuggestedLOC = SuggestedLoc
         ,@nPABookingKey = PABookingKey
   FROM RFPUTAWAY WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND FromLoc = @cLoc
      AND FromID = @cID
      AND SKU = @cSKU

   IF @bDebugFlag = 1
      SELECT 'Get booking data', @cSuggestedLOC as SuggtLoc, @nPABookingKey as PABookingKey

   IF ISNULL(@cSuggestedLOC,'') <> ''  -- Found booking data
      GOTO Quit

   -- STEP 1 Find True Friend
   IF ISNULL(@cSuggestedLOC,'') = ''
   BEGIN

      IF OBJECT_ID('tempdb..#LocationTypeList') IS NOT NULL
         DROP TABLE #LocationTypeList

      CREATE TABLE #LocationTypeList (Value nvarchar (10))
      DECLARE @SQL NVARCHAR(max)
      DECLARE @SQLParam NVARCHAR(MAX)
      DECLARE @index INT = 1
      DECLARE @cLocationType NVARCHAR( 10)

      WHILE (@index < 6)
      BEGIN
         SET @SQL =
                     ' SELECT @cLocationType = UDF0'+ CONVERT(NVARCHAR(1),@index)+' FROM CODELKUP (NOLOCK)' +
                     ' WHERE LISTNAME = ''EXTPA_FLTR'' ' +
                    ' AND Code = ''LOC.LocationType'' ' +
                    ' AND code2 = @nFunc ' +
                    ' AND Storerkey = @cStorerKey' +
                    ' AND ' + CONVERT(NVARCHAR(1),@index)+ ' IS NOT NULL'+
                     ' AND ' + CONVERT(NVARCHAR(1),@index)+ ' <> '''' '

         SET @SQLParam = '@nFunc  INT , @cStorerKey  NVARCHAR( 15), @cLocationType NVARCHAR( 10) OUTPUT'

         EXEC sp_ExecuteSQL @SQL,@SQLParam, @nFunc, @cStorerKey, @cLocationType OUTPUT

         IF ISNULL(@cLocationType,'') <> ''
         BEGIN
            INSERT INTO #LocationTypeList(Value) VALUES (@cLocationType)
            IF @bDebugFlag = 1
               SELECT 'Get LocationType', @cLocationType as LocationType
         END


         SET  @index = @index + 1
      END


      IF NOT EXISTS( SELECT 1 FROM #LocationTypeList )
      BEGIN
         IF @bDebugFlag = 1
            SELECT 'No LocationType Found, Quit'

         GOTO Quit
      END

      SELECT @n_PalletCube = (SKU.STDCUBE * @nQty)
         FROM SKU SKU WITH (NOLOCK)
      WHERE SKU = @cSKU
--             JOIN LOTxLOCxID LLI (NOLOCK) ON SKU.StorerKey = LLI.StorerKey AND SKU.Sku = LLI.SKU
--       WHERE LLI.LOC = @cLOC
--         AND   LLI.ID  = @cID
--         AND   LLI.Qty > 0

      IF @bDebugFlag = 1
         SELECT 'Calculate cubic', @n_PalletCube as cubic

      IF @bDebugFlag = 1
         SELECT 'Start STEP 1'

      -- STEP 1 Find a true friend (SKU, LocationCategory)
      SELECT TOP 1
         @cSuggestedLOC = LOC.LOC
      FROM LOC (NOLOCK)
         JOIN LOTxLOCxID LLI (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN SKU (NOLOCK) ON ( SKU.StorerKey = LLI.StorerKey AND SKU.SKU = LLI.SKU)
      WHERE LOC.Facility = @cFacility
         AND LOC.LocationType in (SELECT * FROM #LocationTypeList)
         AND LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         GROUP BY LOC.CubicCapacity, LOC.LOC, LOC.Floor, LOC.Logicallocation
         HAVING ISNULL(SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn), 0) > 0  -- Not Empty
         AND MAX( LOC.CubicCapacity) -
             SUM( ( ISNULL(LLI.Qty, 0) - ISNULL(LLI.QtyAllocated, 0) - ISNULL( LLI.QtyPicked,0) + ISNULL( LLI.PendingMoveIn,0)) * ISNULL( SKU.STDCUBE,1)) >=
                  CAST( @n_PalletCube AS NVARCHAR( 20)) --check capacity
      ORDER BY
         LOC.Floor, LOC.Logicallocation, LOC.loc

   END

   -- STEP 2 Find Friend
   IF ISNULL(@cSuggestedLOC,'') = ''
   BEGIN

      IF @bDebugFlag = 1
         SELECT 'Start STEP 2'

      SELECT TOP 1
         @cSuggestedLOC = LOC.LOC
      FROM LOC (NOLOCK)
              LEFT JOIN LOTxLOCxID LLI (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND LOC.LocationType in (SELECT * FROM #LocationTypeList)
         AND LOC.PutawayZone IN (
            SELECT DISTINCT(LOC.PutawayZone)  -- SELECT ZONES WITH SAME SKU
            FROM LOC (NOLOCK)
               JOIN LOTxLOCxID LLI (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LOC.LocationType in (SELECT * FROM #LocationTypeList)
               AND LLI.StorerKey = @cStorerKey
               AND LLI.SKU = @cSKU
            GROUP BY LOC.loc,LOC.PutawayZone
            HAVING ISNULL(SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn), 0) > 0
         )
      GROUP BY LOC.LOC, LOC.Floor, LOC.Logicallocation
      HAVING ISNULL(SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn),0) = 0 --empty location
         AND MAX( LOC.CubicCapacity) >= CAST( @n_PalletCube AS NVARCHAR( 20)) -- check capacity
      ORDER BY
         LOC.Floor, LOC.Logicallocation, LOC.loc
   END

   -- STEP 3 Find Any Empty
   IF ISNULL(@cSuggestedLOC,'') = ''
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'Start STEP 3'

      SELECT TOP 1
         @cSuggestedLOC = LOC.LOC
      FROM LOC (NOLOCK)
         LEFT JOIN LOTxLOCxID LLI (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
        AND LOC.LocationType in (SELECT * FROM #LocationTypeList)
      GROUP BY LOC.Floor, LOC.LOC, LOC.Logicallocation
      HAVING ISNULL(SUM((LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn), 0) = 0 --empty location
         AND MAX( LOC.CubicCapacity) >= CAST( @n_PalletCube AS NVARCHAR( 20)) -- check capacity
      ORDER BY
         LOC.Floor, LOC.Logicallocation, LOC.loc
   END

      -- Found & Lock
   IF @cSuggestedLOC <> ''
   BEGIN
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_520ExtPA01 -- For rollback or commit only our own transaction

      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cLOC
         ,@cID
         ,@cSuggestedLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU          = @cSKU
         ,@nPutawayQTY   = @nQTY
         ,@cFromLOT      = @cLOT
         ,@cUCCNo        = @cUCC
         ,@nPABookingKey = @nPABookingKey OUTPUT

      IF @nErrNo <> 0
         GOTO RollBackTran

      IF @bDebugFlag = 1
         SELECT 'LOCK LOC', @nPABookingKey as PABookingKey, @cSuggestedLOC as SuggestedLOC

      COMMIT TRAN rdt_520ExtPA01 -- Only commit change made here
   END
   ELSE
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'No SuggtLoc Found, return -1'

      SET @nErrNo = -1
      GOTO Quit
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_520ExtPA01 -- Only rollback change made here

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

         -- No loc found finally
      IF ISNULL(@cSuggestedLOC,'') = '' 
         SET @nErrNo = -1 -- No suggested LOC, and allow continue.

END --END SP

GO