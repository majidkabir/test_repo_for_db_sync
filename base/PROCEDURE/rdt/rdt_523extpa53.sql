SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: 'rdt_523ExtPA53                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Find LOC based on code lookup                               */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2023-05-06  1.0  Ung         WMS-21484 Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtPA53] (
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
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
   DECLARE @cSQL              NVARCHAR( MAX)
   DECLARE @cSQLParam         NVARCHAR( MAX)
   DECLARE @cWhere            NVARCHAR( MAX)
   
   DECLARE @cType             NVARCHAR( 30)
   DECLARE @cUDF01            NVARCHAR( 60)
   DECLARE @cUDF02            NVARCHAR( 60)
   DECLARE @cUDF03            NVARCHAR( 60)
   DECLARE @cUDF04            NVARCHAR( 60)
   DECLARE @cUDF05            NVARCHAR( 60)

   DECLARE @cSuggLOC          NVARCHAR( 10) = ''
   DECLARE @cMinQTYLOC        NVARCHAR( 10)
   DECLARE @cLOCAisle         NVARCHAR( 10)

   DECLARE @curCodeLKUP       CURSOR
   
   -- Common params
   SET @cSQLParam = 
      ' @cFacility   NVARCHAR( 5),  ' + 
      ' @cStorerKey  NVARCHAR( 15), ' + 
      ' @cLOC        NVARCHAR( 10), ' + 
      ' @cSKU        NVARCHAR( 20), ' + 
      ' @cUDF01      NVARCHAR( 60), ' +
      ' @cUDF02      NVARCHAR( 60), ' +
      ' @cUDF03      NVARCHAR( 60), ' +
      ' @cUDF04      NVARCHAR( 60), ' +
      ' @cUDF05      NVARCHAR( 60), ' + 
      ' @cSuggLOC    NVARCHAR( 10) OUTPUT, ' + 
      ' @cLOCAisle   NVARCHAR( 10) = ''''  '

   /*-------------------------------------------------------------------------------
                                    Find match location
   -------------------------------------------------------------------------------*/
   SET @curCodeLKUP = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT Long, UDF01, UDF02, UDF03, UDF04, UDF05
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = '523SugLoc'
         AND StorerKey = @cStorerKey
         AND Short = @cFacility
      ORDER BY Code
   OPEN @curCodeLKUP
   FETCH NEXT FROM @curCodeLKUP INTO @cType, @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @cSuggLOC = ''
      
      -- Build filters
      SET @cWhere = ''
      IF @cUDF01 <> '' SET @cWhere = @cWhere + ' AND LOC.LocationCategory = @cUDF01' 
      IF @cUDF02 <> '' SET @cWhere = @cWhere + ' AND LOC.PutawayZone = @cUDF02' 
      IF @cUDF03 <> '' SET @cWhere = @cWhere + ' AND LOC.LocationType = @cUDF03' 
      IF @cUDF04 <> '' SET @cWhere = @cWhere + ' AND LOC.LocationFlag = @cUDF04' 
      IF @cUDF05 <> '' SET @cWhere = @cWhere + ' AND LOC.LocLevel = @cUDF05' 
      
      -- Find a friend (SKU) with min QTY
      IF @cType = '1'
      BEGIN
         SET @cSQL = 'SELECT TOP 1 ' +
               ' @cSuggLOC = LOC.LOC ' + 
            ' FROM dbo.LOC WITH (NOLOCK) ' + 
               ' JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) ' + 
            ' WHERE LOC.Facility = @cFacility ' + 
               ' AND LLI.StorerKey = @cStorerKey ' + 
               ' AND LLI.SKU = @cSKU ' + 
               ' AND LOC.LOC <> @cLOC ' + 
               ' AND LOC.LocationFlag <> ''HOLD'' ' + 
               @cWhere + 
            ' GROUP BY LOC.LOC ' + 
            ' HAVING SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn) > 0 ' +
            ' ORDER BY SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn) '

         EXEC sp_executeSQL @cSQL, @cSQLParam 
            ,@cFacility
            ,@cStorerKey
            ,@cLOC  
            ,@cSKU
            ,@cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05
            ,@cSuggLOC OUTPUT
      END 
      
      -- Find a friend (SKU) with min QTY, then find an empty LOC within same aisle / next aisle
      ELSE IF @cType IN ('2', '3')
      BEGIN
         -- Find a friend (SKU) with min QTY
         SET @cMinQTYLOC = ''
         SET @cSQL = 'SELECT TOP 1 ' +
               ' @cSuggLOC = LOC.LOC ' + 
            ' FROM dbo.LOC WITH (NOLOCK) ' + 
               ' JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) ' + 
            ' WHERE LOC.Facility = @cFacility ' + 
               ' AND LLI.StorerKey = @cStorerKey ' + 
               ' AND LLI.SKU = @cSKU ' + 
               ' AND LOC.LOC <> @cLOC ' + 
               ' AND LOC.LocationFlag <> ''HOLD'' ' + 
               ' AND LOC.LOCAisle <> '''' ' + 
               @cWhere + 
            ' GROUP BY LOC.LOC ' + 
            ' HAVING SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn) > 0 ' +
            ' ORDER BY SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn) '

         EXEC sp_executeSQL @cSQL, @cSQLParam 
            ,@cFacility
            ,@cStorerKey
            ,@cLOC  
            ,@cSKU
            ,@cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05
            ,@cMinQTYLOC OUTPUT

         -- Then find an empty LOC within same aisle
         IF @cMinQTYLOC <> ''
         BEGIN
            -- Determine aisle
            IF @cType = '2' SET @cWhere = @cWhere + ' AND LOC.LOCAisle = @cLOCAisle ' -- Current aisle
            IF @cType = '3' SET @cWhere = @cWhere + ' AND LOC.LOCAisle > @cLOCAisle ' -- Next aisle
            
            -- Get LOC info
            SELECT @cLOCAisle = LOCAisle FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cMinQTYLOC
            
            SET @cSQL = 'SELECT TOP 1 ' +
                  ' @cSuggLOC = LOC.LOC ' + 
               ' FROM dbo.LOC WITH (NOLOCK) ' + 
                  ' LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) ' + 
               ' WHERE LOC.Facility = @cFacility ' + 
                  ' AND LOC.LOC <> @cLOC ' + 
                  ' AND LOC.LocationFlag <> ''HOLD'' ' + 
                  ' AND LOC.LOCAisle <> '''' ' + 
                  @cWhere + 
               ' GROUP BY LOC.LogicalLocation, LOC.LOC ' + 
               ' HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0 ' + 
                  ' AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0 ' + 
               ' ORDER BY LOC.LogicalLocation, LOC.LOC '
            
            EXEC sp_executeSQL @cSQL, @cSQLParam 
               ,@cFacility
               ,@cStorerKey
               ,@cLOC  
               ,@cSKU
               ,@cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05
               ,@cSuggLOC  OUTPUT
               ,@cLOCAisle
         END
      END 
      
      -- Find an empty LOC
      ELSE IF @cType = '4'
      BEGIN
         SET @cSQL = 'SELECT TOP 1 ' +
               ' @cSuggLOC = LOC.LOC ' + 
            ' FROM dbo.LOC WITH (NOLOCK) ' + 
               ' LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) ' + 
            ' WHERE LOC.Facility = @cFacility ' + 
               ' AND LOC.LOC <> @cLOC ' + 
               ' AND LOC.LocationFlag <> ''HOLD'' ' + 
               @cWhere + 
            ' GROUP BY LOC.LogicalLocation, LOC.LOC ' + 
            ' HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0 ' + 
               ' AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0 ' + 
            ' ORDER BY LOC.LogicalLocation, LOC.LOC '
         
         EXEC sp_executeSQL @cSQL, @cSQLParam 
            ,@cFacility
            ,@cStorerKey
            ,@cLOC  
            ,@cSKU
            ,@cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05
            ,@cSuggLOC  OUTPUT
      END
      
      IF @cSuggLOC <> ''
         BREAK
      
      FETCH NEXT FROM @curCodeLKUP INTO @cType, @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05
   END
      
   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA53 -- For rollback or commit only our own transaction

   IF @cSuggLOC <> ''
   BEGIN
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cLOC
         ,@cID
         ,@cSuggLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU          = @cSKU
         ,@nPutawayQTY   = @nQTY
         ,@cFromLOT      = @cLOT
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @cSuggestedLOC = @cSuggLOC

      COMMIT TRAN rdt_523ExtPA53 -- Only commit change made here
   END
   GOTO Quit   

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA53 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO