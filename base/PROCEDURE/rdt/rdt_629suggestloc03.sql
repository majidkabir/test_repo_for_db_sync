SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_629SuggestLoc03                                       */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2021-01-21  1.0  yeekung   WMS-20075. Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_629SuggestLoc03] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cStorerkey      NVARCHAR( 15),
   @cType           NVARCHAR( 10),
   @cFromLOC        NVARCHAR( 10),
   @cFromID         NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQty            INT,
   @cToID           NVARCHAR( 18),
   @cToLoc          NVARCHAR( 10),
   @cLottableCode   NVARCHAR( 30),
   @cLottable01     NVARCHAR( 18),
   @cLottable02     NVARCHAR( 18),
   @cLottable03     NVARCHAR( 18),
   @dLottable04     DATETIME,
   @dLottable05     DATETIME,
   @cLottable06     NVARCHAR( 30),
   @cLottable07     NVARCHAR( 30),
   @cLottable08     NVARCHAR( 30),
   @cLottable09     NVARCHAR( 30),
   @cLottable10     NVARCHAR( 30),
   @cLottable11     NVARCHAR( 30),
   @cLottable12     NVARCHAR( 30),
   @dLottable13     DATETIME,
   @dLottable14     DATETIME,
   @dLottable15     DATETIME,
   @cSuggestedLOC   NVARCHAR( 10) OUTPUT,
   @nPABookingKey   INT           OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserName   NVARCHAR( 18)

   SELECT @cUserName = @cUserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cSuggestedLOC = ''
   IF @cType = 'LOCK'
   BEGIN
      DECLARE @cSQL        NVARCHAR( MAX)
      DECLARE @cSQLParam   NVARCHAR( MAX)
      DECLARE @i           INT
      DECLARE @cLottableNo NVARCHAR( 2)
      
      DECLARE @cSuggLOC          NVARCHAR( 10) = ''
      DECLARE @cCode             NVARCHAR( 30)
      DECLARE @cShort            NVARCHAR( 30)
      DECLARE @cUDF01            NVARCHAR( 30)
      DECLARE @cUDF02            NVARCHAR( 30)
      DECLARE @cPutawayZone      NVARCHAR( MAX) = ''
      DECLARE @cHostWHCode       NVARCHAR( MAX) = ''
      DECLARE @cLottable         NVARCHAR( MAX) = ''
      DECLARE @cLocationCategory NVARCHAR( MAX) = ''

      DECLARE @cFromHostWHCode   NVARCHAR( 10)
      DECLARE @cFromPutawayZone  NVARCHAR( 10)
      DECLARE @cFromLocationCategory  NVARCHAR( 10)

      -- Get LOC info
      SELECT 
         @cFromHostWHCode = HostWHCode, 
         @cFromPutawayZone = PutawayZone,
         @cFromLocationCategory =LocationCategory
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cFromLOC
   
      -- Get lottable
      SELECT TOP 1
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
      WHERE LLI.LOC = @cFromLOC
         AND LLI.ID = @cFromID
         AND LLI.SKU = @cSKU
         AND LLI.StorerKey = @cStorerKey
         AND LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) > 0
               
      -- Loop codelkup, 2 TIMES
      SET @i = 1
      WHILE @i < 3 AND @cSuggestedLOC = ''
      BEGIN
         SET @cPutawayZone = ''
         SET @cHostWHCode  = ''
         SET @cLottable    = ''
         SET @cLocationCategory = ''
         
         DECLARE @curCodeLKUP CURSOR
         SET @curCodeLKUP = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT Code, ISNULL( Short, ''), UDF01, UDF02
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'SUGLoc629'
               AND StorerKey = @cStorerKey
               AND CAST( Code2 AS INT) = @i
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

            IF @cCode = 'LocationCategory'
            BEGIN
                IF @cShort = 'Y'
                  SET @cLocationCategory = ' AND LOC.LocationCategory = @cFromLocationCategory' 
               ELSE If @cUDF01 <> ''
                  SET @cLocationCategory = ' AND LOC.LocationCategory IN (' + @cUDF01 + ') ' 
               ELSE If @cUDF02 <> ''
                  SET @cLocationCategory = ' AND LOC.LocationCategory NOT IN (' + @cUDF02 + ') ' 
            END
            FETCH NEXT FROM @curCodeLKUP INTO @cCode, @cShort, @cUDF01, @cUDF02
         END

         SET @cSQL = 'SELECT TOP 1 ' +
               ' @cSuggestedLOC = LOC.LOC ' + 
            ' FROM dbo.LOC WITH (NOLOCK) ' + 
               ' JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC) ' + 
               ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT) ' + 
            ' WHERE LOC.Facility = @cFacility ' + 
               ' AND LLI.StorerKey = @cStorerKey ' + 
               ' AND LLI.SKU = @cSKU ' + 
               ' AND LOC.LOC <> @cFromLOC ' + 
               ' AND LOC.LocationFlag <> ''HOLD'' ' + 
               @cHostWHCode + 
               @cPutawayZone + 
               @cLottable + 
               @cLocationCategory +
            ' GROUP BY LOC.LOC ' + 
            ' HAVING SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn) > 0 ' +
            ' ORDER BY SUM( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated + LLI.PendingMoveIn),LOC.LOC '
      
         SET @cSQLParam = 
            ' @cFacility        NVARCHAR( 5),  ' + 
            ' @cStorerKey       NVARCHAR( 15), ' + 
            ' @cSKU             NVARCHAR( 20), ' + 
            ' @cFromLOC         NVARCHAR( 10), ' + 
            ' @cFromHostWHCode  NVARCHAR( 10), ' + 
            ' @cFromPutawayZone NVARCHAR( 10), ' + 
            ' @cFromLocationCategory NVARCHAR(10), '+
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
            ' @cSuggestedLOC    NVARCHAR( 10) OUTPUT '

         EXEC sp_executeSQL @cSQL, @cSQLParam 
            ,@cFacility
            ,@cStorerKey
            ,@cSKU
            ,@cFromLOC
            ,@cFromHostWHCode
            ,@cFromPutawayZone
            ,@cFromLocationCategory
            ,@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05    
            ,@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10    
            ,@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15  
            ,@cSuggestedLOC OUTPUT

         IF @cSuggestedLOC <> ''
            BREAK
            
         SET @i = @i + 1
      END
   END

   Quit:
END

GO