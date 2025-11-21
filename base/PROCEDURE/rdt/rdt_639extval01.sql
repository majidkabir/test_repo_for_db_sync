SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
         
/******************************************************************************/          
/* Store procedure: rdt_639ExtVal01                                           */          
/* Copyright      : LF Logistics                                              */          
/*                                                                            */          
/* Purpose: Validate lottable                                                 */          
/*                                                                            */          
/* Date         Author    Ver.  Purposes                                      */          
/* 2020-02-21   James     1.0   WMS-12070. Created                            */        
/******************************************************************************/          
          
CREATE PROCEDURE [RDT].[rdt_639ExtVal01]            
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR(3), 
   @nStep           INT, 
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR(15), 
   @cFacility       NVARCHAR(5), 
   @cToLOC          NVARCHAR(10), 
   @cToID           NVARCHAR(18), 
   @cFromLOC        NVARCHAR(10), 
   @cFromID         NVARCHAR(18), 
   @cSKU            NVARCHAR(20), 
   @nQTY            INT, 
   @cUCC            NVARCHAR(20), 
   @cLottable01     NVARCHAR(18),
   @cLottable02     NVARCHAR(18),
   @cLottable03     NVARCHAR(18),
   @dLottable04     DATETIME,
   @dLottable05     DATETIME,
   @cLottable06     NVARCHAR(18),
   @cLottable07     NVARCHAR(18),
   @cLottable08     NVARCHAR(18),
   @cLottable09     NVARCHAR(18),
   @cLottable10     NVARCHAR(18),
   @cLottable11     NVARCHAR(18),
   @cLottable12     NVARCHAR(18),
   @dLottable13     DATETIME,
   @dLottable14     DATETIME,
   @dLottable15     DATETIME,   
   @tExtValidVar    VARIABLETABLE READONLY, 
   @nErrNo          INT OUTPUT, 
   @cErrMsg         NVARCHAR(20) OUTPUT        
AS          
BEGIN          
   SET NOCOUNT ON          
   SET QUOTED_IDENTIFIER OFF          
   SET ANSI_NULLS OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF          
          
   DECLARE @cCode       NVARCHAR( 10)
   DECLARE @cNotes      NVARCHAR( 60)
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @nCnt        INT

   IF @nStep = 6 -- QTY
   BEGIN          
      IF @nInputKey = 1 -- ESC          
      BEGIN        
         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.LOT = LA.Lot)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
                     WHERE LLI.StorerKey = @cStorerKey
                     AND   LLI.Loc = @cFromLOC
                     AND   (( ISNULL( @cFromID, '') = '') OR ( LLI.ID = @cFromID))   
                     AND   LOC.Facility = @cFacility  
                     GROUP BY LOC.LOC 
                     HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0  
                     AND COUNT( DISTINCT LA.Lottable01) > 1) 
         BEGIN
            SET @nErrNo = 148501
            SET @cErrMsg = SUBSTRING( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP'), 7, 14) --Mix Lottable01
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.LOT = LA.Lot)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
                     WHERE LLI.StorerKey = @cStorerKey
                     AND   LLI.Loc = @cFromLOC
                     AND   (( ISNULL( @cFromID, '') = '') OR ( LLI.ID = @cFromID))   
                     AND   LOC.Facility = @cFacility  
                     GROUP BY LOC.LOC 
                     HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0  
                     AND COUNT( DISTINCT LA.Lottable08) > 1)
         BEGIN
            SET @nErrNo = 148502
            SET @cErrMsg = SUBSTRING( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP'), 7, 14) --Mix Lottable08
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.LOT = LA.Lot)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
                     WHERE LLI.StorerKey = @cStorerKey
                     AND   LLI.Loc = @cFromLOC
                     AND   (( ISNULL( @cFromID, '') = '') OR ( LLI.ID = @cFromID))   
                     AND   LOC.Facility = @cFacility  
                     GROUP BY LOC.LOC 
                     HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0  
                     AND COUNT( DISTINCT LA.Lottable09) > 1)
         BEGIN
            SET @nErrNo = 148503
            SET @cErrMsg = SUBSTRING( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP'), 7, 14) --Mix Lottable09
            GOTO Quit
         END

         DECLARE @curCK CURSOR  
         SET @curCK = CURSOR FOR
            SELECT Code, Notes
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE ListName = 'UALOTTABLE'
            AND   StorerKey = @cStorerKey
            AND   code2 = @nFunc
            ORDER BY 1
            OPEN @curCK
            FETCH NEXT FROM @curCK INTO @cCode, @cNotes 
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF CAST( @cCode AS INT) IN (1, 2, 3, 6, 7, 8, 9, 10, 11, 12)
               BEGIN
                  SET @nCnt = 1
                  SET @cSQL = ''
                  SET @cSQL = 
                  ' IF ISNULL( @cNotes, '''') <> ISNULL( @cLottable' + @cCode + ', ''''' + ') ' + 
                  '    SET @nCnt = 0 ' 
                  SET @cSQLParam = 
                     '@cNotes          NVARCHAR( 60), ' +  
                     '@cLottable01     NVARCHAR( 18), ' +
                     '@cLottable02     NVARCHAR( 18), ' +
                     '@cLottable03     NVARCHAR( 18), ' +
                     '@dLottable04     DATETIME,      ' +
                     '@dLottable05     DATETIME,      ' +
                     '@cLottable06     NVARCHAR( 18), ' +
                     '@cLottable07     NVARCHAR( 18), ' +
                     '@cLottable08     NVARCHAR( 18), ' +
                     '@cLottable09     NVARCHAR( 18), ' +
                     '@cLottable10     NVARCHAR( 18), ' +
                     '@cLottable11     NVARCHAR( 18), ' +
                     '@cLottable12     NVARCHAR( 18), ' +
                     '@dLottable13     DATETIME,      ' +
                     '@dLottable14     DATETIME,      ' +
                     '@dLottable15     DATETIME,      ' +
                     '@nCnt            INT OUTPUT     ' 
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
                     @cNotes      = @cNotes,  
                     @cLottable01 = @cLottable01,
                     @cLottable02 = @cLottable02,
                     @cLottable03 = @cLottable03,
                     @dLottable04 = @dLottable04,
                     @dLottable05 = @dLottable05,
                     @cLottable06 = @cLottable06,
                     @cLottable07 = @cLottable07,
                     @cLottable08 = @cLottable08,
                     @cLottable09 = @cLottable09,
                     @cLottable10 = @cLottable10,
                     @cLottable11 = @cLottable11,
                     @cLottable12 = @cLottable12,
                     @dLottable13 = @dLottable13,
                     @dLottable14 = @dLottable14,
                     @dLottable15 = @dLottable15,
                     @nCnt        = @nCnt       OUTPUT

                  IF @nCnt = 0
                  BEGIN
                     SET @nErrNo = 148504
                     SET @cErrMsg = SUBSTRING( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP'), 7, 14) --Invalid Lottable
                     SET @cErrMsg = RTRIM( @cErrMsg) + @cCode
                     GOTO Quit
                  END
               END
               FETCH NEXT FROM @curCK INTO @cCode, @cNotes
            END            
      END          
   END          
          
Quit:          
          
END          

GO