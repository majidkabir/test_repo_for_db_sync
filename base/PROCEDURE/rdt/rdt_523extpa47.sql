SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: 'rdt_523ExtPA47                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Find friend, find empty then find dedicated loc             */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2022-05-10  1.0  Ung         WMS-19575 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA47] (
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
   DECLARE @cPutawayZone      NVARCHAR( MAX) = ''
   DECLARE @cHostWHCode       NVARCHAR( MAX) = ''
   DECLARE @cLottable         NVARCHAR( MAX) = ''
   DECLARE @cOrderBy          NVARCHAR( MAX) = ''
   
   DECLARE @cSuggLOC          NVARCHAR( 10) = ''
   DECLARE @cCode             NVARCHAR( 30)
   DECLARE @cShort            NVARCHAR( 30)
   DECLARE @cUDF01            NVARCHAR( 30)
   DECLARE @cUDF02            NVARCHAR( 30)
   DECLARE @cUDF03            NVARCHAR( 30)
   DECLARE @cLottableNo       NVARCHAR( 2)

   DECLARE @cFromHostWHCode   NVARCHAR( 10)
   DECLARE @cFromPutawayZone  NVARCHAR( 10)
   DECLARE @cLottable01       NVARCHAR( 18)
   DECLARE @cLottable02       NVARCHAR( 18)
   DECLARE @cLottable03       NVARCHAR( 18)
   DECLARE @dLottable04       DATETIME     
   DECLARE @dLottable05       DATETIME     
   DECLARE @cLottable06       NVARCHAR( 30)
   DECLARE @cLottable07       NVARCHAR( 30)
   DECLARE @cLottable08       NVARCHAR( 30)
   DECLARE @cLottable09       NVARCHAR( 30)
   DECLARE @cLottable10       NVARCHAR( 30)
   DECLARE @cLottable11       NVARCHAR( 30)
   DECLARE @cLottable12       NVARCHAR( 30)
   DECLARE @dLottable13       DATETIME     
   DECLARE @dLottable14       DATETIME     
   DECLARE @dLottable15       DATETIME     
   DECLARE @curCodeLKUP       CURSOR
   
   SET @cSuggLOC = ''

   -- Get LOC info
   SELECT 
      @cFromHostWHCode = HostWHCode, 
      @cFromPutawayZone = PutawayZone
   FROM dbo.LOC WITH (NOLOCK)
   WHERE LOC = @cLOC

   -- Get lottable
   SELECT TOP 1
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
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
   WHERE LLI.LOC = @cLOC
      AND LLI.ID = @cID
      AND LLI.SKU = @cSKU
      AND LLI.StorerKey = @cStorerKey
      AND LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) > 0
            
   /*-------------------------------------------------------------------------------
                                    Find match location
   -------------------------------------------------------------------------------*/
   SET @curCodeLKUP = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT Code, ISNULL( Short, ''), UDF01, UDF02
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'SUGLoc523'
         AND StorerKey = @cStorerKey
         AND Code2 = '01'
   OPEN @curCodeLKUP
   FETCH NEXT FROM @curCodeLKUP INTO @cCode, @cShort, @cUDF01, @cUDF02
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @cCode = 'HostWHCode'
      BEGIN
         IF @cShort = 'Y'
            SET @cHostWHCode = ' AND LOC.HostWHCode = @cFromHostWHCode ' 
         ELSE If @cUDF01 <> ''
            SET @cHostWHCode = ' AND LOC.HostWHCode IN (' + @cUDF01 + ') ' 
         ELSE If @cUDF02 <> ''
            SET @cHostWHCode = ' AND LOC.HostWHCode NOT IN (' + @cUDF02 + ') ' 
      END 
      
      IF @cCode = 'PutawayZone'
      BEGIN
         IF @cShort = 'Y'
            SET @cPutawayZone = ' AND LOC.PutawayZone = @cFromPutawayZone ' 
         ELSE If @cUDF01 <> ''
            SET @cPutawayZone = ' AND LOC.PutawayZone IN (' + @cUDF01 + ') ' 
         ELSE If @cUDF02 <> ''
            SET @cPutawayZone = ' AND LOC.PutawayZone NOT IN (' + @cUDF02 + ') ' 
      END 
      
      IF @cCode LIKE 'Lottable%'
      BEGIN
         SET @cLottableNo = RIGHT( @cCode, 2)
         IF @cShort = 'Y'
         BEGIN
            IF @cLottableNo IN ('04', '05', '13', '14', '15')
               SET @cLottable = @cLottable + ' AND LA.Lottable' + @cLottableNo + ' = @dLottable' + @cLottableNo
            ELSE
               SET @cLottable = @cLottable + ' AND LA.Lottable' + @cLottableNo + ' = @cLottable' + @cLottableNo
         END
         ELSE If @cUDF01 <> ''
            SET @cLottable = @cLottable + ' AND LA.Lottable' + @cLottableNo + ' IN (' + @cUDF01 + ') ' 
         ELSE If @cUDF02 <> ''
            SET @cLottable = @cLottable + ' AND LA.Lottable' + @cLottableNo + ' NOT IN (' + @cUDF02 + ') ' 
      END
      FETCH NEXT FROM @curCodeLKUP INTO @cCode, @cShort, @cUDF01, @cUDF02
   END

   SET @cSQL = 'SELECT TOP 1 ' +
         ' @cSuggLOC = LOC.LOC ' + 
      ' FROM dbo.LOC WITH (NOLOCK) ' + 
         ' JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) ' + 
         ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT) ' + 
      ' WHERE LOC.Facility = @cFacility ' + 
         ' AND LLI.StorerKey = @cStorerKey ' + 
         ' AND LLI.SKU = @cSKU ' + 
         ' AND LOC.LOC <> @cLOC ' + 
         ' AND LOC.LocationFlag <> ''HOLD'' ' + 
         @cHostWHCode + 
         @cPutawayZone + 
         @cLottable + 
      ' GROUP BY LOC.LOC ' + 
      ' HAVING SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn) > 0 ' +
      ' ORDER BY SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn) '

   SET @cSQLParam = 
      ' @cFacility        NVARCHAR( 5),  ' + 
      ' @cStorerKey       NVARCHAR( 15), ' + 
      ' @cSKU             NVARCHAR( 20), ' + 
      ' @cLOC         NVARCHAR( 10), ' + 
      ' @cFromHostWHCode  NVARCHAR( 10), ' + 
      ' @cFromPutawayZone NVARCHAR( 10), ' + 
      ' @cLottable01      NVARCHAR( 18), ' +    
      ' @cLottable02      NVARCHAR( 18), ' +    
      ' @cLottable03      NVARCHAR( 18), ' +    
      ' @dLottable04      DATETIME,      ' +    
      ' @dLottable05      DATETIME,      ' +    
      ' @cLottable06      NVARCHAR( 30), ' +    
      ' @cLottable07      NVARCHAR( 30), ' +    
      ' @cLottable08      NVARCHAR( 30), ' +    
      ' @cLottable09      NVARCHAR( 30), ' +    
      ' @cLottable10      NVARCHAR( 30), ' +    
      ' @cLottable11      NVARCHAR( 30), ' +    
      ' @cLottable12      NVARCHAR( 30), ' +    
      ' @dLottable13      DATETIME,      ' +    
      ' @dLottable14      DATETIME,      ' +    
      ' @dLottable15      DATETIME,      ' +  
      ' @cSuggLOC         NVARCHAR( 10) OUTPUT '

   EXEC sp_executeSQL @cSQL, @cSQLParam 
      ,@cFacility
      ,@cStorerKey
      ,@cSKU
      ,@cLOC
      ,@cFromHostWHCode
      ,@cFromPutawayZone
      ,@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05    
      ,@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10    
      ,@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15  
      ,@cSuggLOC OUTPUT

   /*-------------------------------------------------------------------------------
                                  Find empty location
   -------------------------------------------------------------------------------*/
   IF @cSuggLOC = ''
   BEGIN
      SET @cPutawayZone = ''
      SET @cHostWHCode  = ''
      SET @cOrderBy     = ''
      
      SET @curCodeLKUP = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT Code, ISNULL( Short, ''), UDF01, UDF02, UDF03
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'EmtpySug'
            AND StorerKey = @cStorerKey
            AND Code2 = '523'
      OPEN @curCodeLKUP
      FETCH NEXT FROM @curCodeLKUP INTO @cCode, @cShort, @cUDF01, @cUDF02, @cUDF03
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @cCode = 'HostWHCode'
         BEGIN
            IF @cShort = 'Y'
               SET @cHostWHCode = ' AND LOC.HostWHCode = @cFromHostWHCode ' 
            ELSE If @cUDF01 <> ''
               SET @cHostWHCode = ' AND LOC.HostWHCode IN (' + @cUDF01 + ') ' 
            ELSE If @cUDF02 <> ''
               SET @cHostWHCode = ' AND LOC.HostWHCode NOT IN (' + @cUDF02 + ') ' 

            IF @cUDF03 <> ''
            BEGIN
               IF @cUDF03 = '1'
                  SET @cOrderBy = @cOrderBy + ', LOC.HostWHCode'
                IF @cUDF03 = '2'
                  SET @cOrderBy = @cOrderBy + ', LOC.HostWHCode DESC'
            END
         END 
         
         IF @cCode = 'PutawayZone'
         BEGIN
            IF @cShort = 'Y'
               SET @cPutawayZone = ' AND LOC.PutawayZone = @cFromPutawayZone ' 
            ELSE If @cUDF01 <> ''
               SET @cPutawayZone = ' AND LOC.PutawayZone IN (' + @cUDF01 + ') ' 
            ELSE If @cUDF02 <> ''
               SET @cPutawayZone = ' AND LOC.PutawayZone NOT IN (' + @cUDF02 + ') ' 
               
            IF @cUDF03 <> ''
            BEGIN
               IF @cUDF03 = '1'
                  SET @cOrderBy = @cOrderBy + ', LOC.PutawayZone'
                IF @cUDF03 = '2'
                  SET @cOrderBy = @cOrderBy + ', LOC.PutawayZone DESC'
            END
         END 

         FETCH NEXT FROM @curCodeLKUP INTO @cCode, @cShort, @cUDF01, @cUDF02, @cUDF03
      END
      
      IF @cOrderBy <> ''
      BEGIN
         SET @cOrderBy = SUBSTRING( @cOrderBy, 3, LEN( @cOrderBy)) -- Remove leading ', '
         SET @cOrderBy = 'ORDER BY ' + @cOrderBy
      END

      SET @cSQL = 'SELECT TOP 1 ' +
            ' @cSuggLOC = LOC.LOC ' + 
         ' FROM dbo.LOC WITH (NOLOCK) ' + 
            ' LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) ' + 
         ' WHERE LOC.Facility = @cFacility ' + 
            ' AND LOC.LOC <> @cLOC ' + 
            ' AND LOC.LocationFlag <> ''HOLD'' ' + 
            @cHostWHCode + 
            @cPutawayZone + 
         ' GROUP BY LOC.LOC, LOC.HostWHCode, LOC.PutawayZone ' + 
         ' HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0 ' + 
            ' AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0 ' + 
         @cOrderBy 

      SET @cSQLParam = 
         ' @cFacility        NVARCHAR( 5),  ' + 
         ' @cStorerKey       NVARCHAR( 15), ' + 
         ' @cSKU             NVARCHAR( 20), ' + 
         ' @cLOC             NVARCHAR( 10), ' + 
         ' @cFromHostWHCode  NVARCHAR( 10), ' + 
         ' @cFromPutawayZone NVARCHAR( 10), ' + 
         ' @cSuggLOC         NVARCHAR( 10) OUTPUT '

      EXEC sp_executeSQL @cSQL, @cSQLParam 
         ,@cFacility
         ,@cStorerKey
         ,@cSKU
         ,@cLOC
         ,@cFromHostWHCode
         ,@cFromPutawayZone
         ,@cSuggLOC OUTPUT
   END
      
   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA46 -- For rollback or commit only our own transaction

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

      COMMIT TRAN rdt_523ExtPA46 -- Only commit change made here
   END
   GOTO Quit   

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA46 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO