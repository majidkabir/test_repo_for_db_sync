SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513SuggestLOC09                                       */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Find a friend (same SKU)                                          */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 13-07-2018  1.0  Ung         WMS-5684 Created                              */
/* 03-08-2018  1.1  Ung         WMS-5684 Filter by LOC have stock             */
/******************************************************************************/

CREATE PROC [RDT].[rdt_513SuggestLOC09] (
   @nMobile         INT,                  
   @nFunc           INT,                  
   @cLangCode       NVARCHAR( 3),         
   @cStorerKey      NVARCHAR( 15),        
   @cFacility       NVARCHAR(  5),        
   @cFromLOC        NVARCHAR( 10),        
   @cFromID         NVARCHAR( 18),        
   @cSKU            NVARCHAR( 20),        
   @nQTY            INT,                  
   @cToID           NVARCHAR( 18),        
   @cToLOC          NVARCHAR( 10),        
   @cType           NVARCHAR( 10),        
   @nPABookingKey   INT           OUTPUT,  
   @cOutField01     NVARCHAR( 20) OUTPUT, 
   @cOutField02     NVARCHAR( 20) OUTPUT, 
   @cOutField03     NVARCHAR( 20) OUTPUT, 
   @cOutField04     NVARCHAR( 20) OUTPUT, 
   @cOutField05     NVARCHAR( 20) OUTPUT, 
   @cOutField06     NVARCHAR( 20) OUTPUT, 
   @cOutField07     NVARCHAR( 20) OUTPUT, 
   @cOutField08     NVARCHAR( 20) OUTPUT, 
   @cOutField09     NVARCHAR( 20) OUTPUT, 
   @cOutField10     NVARCHAR( 20) OUTPUT, 
   @cOutField11     NVARCHAR( 20) OUTPUT, 
   @cOutField12     NVARCHAR( 20) OUTPUT, 
   @cOutField13     NVARCHAR( 20) OUTPUT, 
   @cOutField14     NVARCHAR( 20) OUTPUT, 
   @cOutField15     NVARCHAR( 20) OUTPUT, 
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @cType = 'LOCK'
   BEGIN
      DECLARE @cLottable02 NVARCHAR(18)
      DECLARE @cHostWHCode NVARCHAR(10)
      DECLARE @fCube       FLOAT
      DECLARE @fSTDCube    FLOAT

      DECLARE @tPutawayZone TABLE
      (
         PutawayZone NVARCHAR( 10) NOT NULL PRIMARY KEY CLUSTERED
      )
      
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''   
   
      -- Check lottable value define on code lookup
      IF EXISTS( SELECT 1
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LLI.LOC = @cFromLOC
            AND LLI.ID = @cFromID
            AND LLI.SKU = @cSKU
            AND ( 
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable01' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable01) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable02' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable02) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable03' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable03) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable04' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable04) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable05' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable05) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable06' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable06) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable07' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable07) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable08' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable08) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable09' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable09) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable10' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable10) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable11' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable11) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable12' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable12) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable13' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable13) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable14' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable14) OR
               EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTTBL' AND Code = 'Lottable15' AND StorerKey = @cStorerKey AND Code2 = @nFunc AND UDF01 = LA.Lottable15)
            ))
      BEGIN
         -- Get putaway zone
         INSERT INTO @tPutawayZone
         SELECT Code
         FROM CodeLKUP WITH (NOLOCK) 
         WHERE ListName = 'RDTPAZone'
            AND StorerKey = @cStorerKey
            AND Code2 = @nFunc
      
         -- Find a friend (same SKU) with min QTY
         SELECT TOP 1
            @cOutField01 = LOC.LOC
         FROM dbo.LOC WITH (NOLOCK) 
            JOIN @tPutawayZone t ON (t.PutawayZone = LOC.PutawayZone)
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationFlag <> 'HOLD'
            AND LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND LOC.LOC <> @cFromLOC
         GROUP BY LOC.LOC
         HAVING SUM( LLI.QTY - LLI.QTYPicked) > 0
         ORDER BY SUM( LLI.QTY - LLI.QTYPicked)
      END
         
      IF @cOutField01 = ''
         SET @nErrNo = -1
   END
   
Quit:

END

GO