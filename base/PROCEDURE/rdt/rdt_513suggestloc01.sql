SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513SuggestLOC01                                       */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 15-12-2015  1.0  Ung         SOS358873 Created                             */
/* 27-09-2019  1.1  Ung         WMS-10655 Totally new logic                   */
/* 10-11-2021  1.2  James       WMS-18325 Change sorting (james01)            */
/*                              Change Min Loc definition                     */
/******************************************************************************/

CREATE PROC [RDT].[rdt_513SuggestLOC01] (
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
      DECLARE @cPutawayZone NVARCHAR(10)
      DECLARE @fCube       FLOAT
      DECLARE @fSTDCube    FLOAT
      DECLARE @cSuggLOC    NVARCHAR(10) = ''
      
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
   
      -- Get move stock PutawayZone
      SELECT @cPutawayZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC
   
      -- Get move stock lottables
      SELECT TOP 1 
         @cLottable02 = LA.Lottable02
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
      WHERE LLI.LOC = @cFromLOC
         AND LLI.ID = @cFromID
         AND LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LLI.QTY - LLI.QTYPicked > 0
   
      -- Check location have multi L02
      IF EXISTS( SELECT 1 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
         WHERE LLI.LOC = @cFromLOC
            AND LLI.ID = @cFromID
            AND LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND LLI.QTY - LLI.QTYPicked > 0
            AND LA.Lottable02 <> @cLottable02)
      BEGIN
         SET @nErrNo = 59051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multiple L02
         GOTO Quit
      END

      -- Find a friend (same putawayzone, L02, SKU)
      IF @cSuggLOC = ''
      BEGIN
         IF EXISTS( SELECT 1 FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#tFriendLOC1'))
            DROP TABLE #tFriendLOC1

         SELECT DISTINCT LOC.LOC
         INTO #tFriendLOC1
         FROM dbo.LOC WITH (NOLOCK) 
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cPutawayZone 
            AND LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND LOC.LOC <> @cFromLOC
            AND LA.Lottable02 = @cLottable02
         GROUP BY LOC.PALogicalLOC, LOC.LOC, LOC.LocAisle

         -- Find a friend with min QTY
         IF @@ROWCOUNT > 0
         BEGIN
            SELECT TOP 1
               @cSuggLOC = SL.LOC
            FROM #tFriendLOC1 F
               JOIN SKUxLOC SL WITH (NOLOCK) ON (F.LOC = SL.LOC)
            GROUP BY SL.LOC
            ORDER BY SUM( SL.QTY-SL.QTYPicked-SL.QtyAllocated), SL.Loc
         END
      END
      
      -- Find a friend (same putawayzone, L02, style, color)
      IF @cSuggLOC = ''
      BEGIN
         -- Get SKU info
         DECLARE @cStyle NVARCHAR( 20) 
         DECLARE @cColor NVARCHAR( 10) 
         DECLARE @cItemClass NVARCHAR( 10) 
         SELECT 
            @cStyle = Style, 
            @cColor = Color, 
            @cItemClass = ISNULL( ItemClass, '')
         FROM SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU

         IF EXISTS( SELECT 1 FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#tFriendLOC2'))
            DROP TABLE #tFriendLOC2

         SELECT DISTINCT LOC.LOC
         INTO #tFriendLOC2
         FROM dbo.LOC WITH (NOLOCK) 
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
            JOIN dbo.SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cPutawayZone 
            AND LLI.StorerKey = @cStorerKey
            AND SKU.Style = @cStyle
            AND SKU.Color = @cColor
            AND LOC.LOC <> @cFromLOC
            AND LA.Lottable02 = @cLottable02
         GROUP BY LOC.PALogicalLOC, LOC.LOC, LOC.LocAisle

         -- Find a friend with min QTY
         IF @@ROWCOUNT > 0
         BEGIN
            SELECT TOP 1
               @cSuggLOC = SL.LOC
            FROM #tFriendLOC2 F
               JOIN SKUxLOC SL WITH (NOLOCK) ON (F.LOC = SL.LOC)
            GROUP BY SL.LOC
            ORDER BY SUM( SL.QTY-SL.QTYPicked-SL.QtyAllocated), SL.Loc
         END
      END

      -- Find a friend (same putawayzone, L02, style)
      IF @cSuggLOC = ''
      BEGIN
         IF EXISTS( SELECT 1 FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#tFriendLOC3'))
            DROP TABLE #tFriendLOC3

         SELECT DISTINCT LOC.LOC
         INTO #tFriendLOC3
         FROM dbo.LOC WITH (NOLOCK) 
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
            JOIN dbo.SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cPutawayZone 
            AND LLI.StorerKey = @cStorerKey
            AND SKU.Style = @cStyle
            AND LOC.LOC <> @cFromLOC
            AND LA.Lottable02 = @cLottable02
         GROUP BY LOC.PALogicalLOC, LOC.LOC, LOC.LocAisle

         -- Find a friend with min QTY
         IF @@ROWCOUNT > 0
         BEGIN
            SELECT TOP 1
               @cSuggLOC = SL.LOC
            FROM #tFriendLOC3 F
               JOIN SKUxLOC SL WITH (NOLOCK) ON (F.LOC = SL.LOC)
            GROUP BY SL.LOC
            ORDER BY SUM( SL.QTY-SL.QTYPicked-SL.QtyAllocated), SL.Loc
         END
      END

      -- Find a friend (same putawayzone, L02, ItemClass)
      IF @cSuggLOC = ''
      BEGIN
         IF EXISTS( SELECT 1 FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#tFriendLOC4'))
            DROP TABLE #tFriendLOC4

         SELECT DISTINCT LOC.LOC
         INTO #tFriendLOC4
         FROM dbo.LOC WITH (NOLOCK) 
            JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
            JOIN dbo.SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
         WHERE LOC.Facility = @cFacility
            AND LOC.PutawayZone = @cPutawayZone 
            AND LLI.StorerKey = @cStorerKey
            AND ISNULL( SKU.ItemClass, '') = @cItemClass
            AND LOC.LOC <> @cFromLOC
            AND LA.Lottable02 = @cLottable02
         GROUP BY LOC.PALogicalLOC, LOC.LOC, LOC.LocAisle

         -- Find a friend with min QTY
         IF @@ROWCOUNT > 0
         BEGIN
            SELECT TOP 1
               @cSuggLOC = SL.LOC
            FROM #tFriendLOC4 F
               JOIN SKUxLOC SL WITH (NOLOCK) ON (F.LOC = SL.LOC)
            GROUP BY SL.LOC
            ORDER BY SUM( SL.QTY-SL.QTYPicked-SL.QtyAllocated), SL.Loc
         END
      END
      
      IF @cSuggLOC = ''
         SET @nErrNo = -1
      ELSE
         SET @cOutField01 = @cSuggLOC
   END
   
Quit:

END

GO