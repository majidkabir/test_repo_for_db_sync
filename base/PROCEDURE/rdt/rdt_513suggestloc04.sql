SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513SuggestLOC04                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*          1. Find a friend (same SKU, same L03)                       */
/*          2. Find empty LOC                                           */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 08-03-2017  1.0  James       WMS-1217 Created                        */
/* 19-03-2020  1.1  TLTING01    remove hardcode index                   */  
/* 06-04-2020  1.2  Ung         LWP-76 Performance tuning               */
/* 26-01-2021  1.3  Chermaine   WMS-16150 return 3 loc                  */
/*                              and add codelkup (cc01)                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_513SuggestLOC04] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerkey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cFromLoc      NVARCHAR( 10),
   @cFromID       NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cToID         NVARCHAR( 18),
   @cToLOC        NVARCHAR( 10),
   @cType         NVARCHAR( 10), -- LOCK/UNLOCK
   @nPABookingKey INT           OUTPUT,
   @cOutField01   NVARCHAR( 20) OUTPUT,
   @cOutField02   NVARCHAR( 20) OUTPUT,
   @cOutField03   NVARCHAR( 20) OUTPUT,
   @cOutField04   NVARCHAR( 20) OUTPUT,
   @cOutField05   NVARCHAR( 20) OUTPUT,
   @cOutField06   NVARCHAR( 20) OUTPUT,
   @cOutField07   NVARCHAR( 20) OUTPUT,
   @cOutField08   NVARCHAR( 20) OUTPUT,
   @cOutField09   NVARCHAR( 20) OUTPUT,
   @cOutField10   NVARCHAR( 20) OUTPUT,
   @cOutField11   NVARCHAR( 20) OUTPUT,
   @cOutField12   NVARCHAR( 20) OUTPUT,
   @cOutField13   NVARCHAR( 20) OUTPUT,
   @cOutField14   NVARCHAR( 20) OUTPUT,
   @cOutField15   NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   --(cc01)
   DECLARE @cSuggestedLoc        NVARCHAR( 10)
   DECLARE @cSuggestedLocDesc    NVARCHAR( 60)
   DECLARE @cSuggestedDesc       NVARCHAR( 60)
   DECLARE @cSuggestedLocQ       NVARCHAR( 10)
   DECLARE @cSuggestedLocSKU     NVARCHAR( 10)
   DECLARE @cSuggestedLocSKUQ    NVARCHAR( 10)
   DECLARE @nCount               INT
   DECLARE @nRow                 INT
   
   DECLARE @tSuggestLocInfo TABLE  
   (  
      Loc      NVARCHAR( 10),
      LocDesc  NVARCHAR( 60),
      LocQ     INT,
      LocSKU   INT,
      SKUQ     INT,
      Seq      INT 
   )
   
   SET @nCount = 1
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''
   SET @cOutField07 = ''
   SET @cOutField08 = ''
   SET @cOutField09 = ''
   SET @cOutField10 = ''
   SET @cOutField11 = ''
   SET @cOutField12 = ''

   IF @cType = 'LOCK'
   BEGIN
      SET @cSuggestedLOC = ''

      -- Get lottables
      DECLARE @cLottable02 NVARCHAR( 18)
      DECLARE @cLottable03 NVARCHAR( 18)
      
      SELECT TOP 1 
         @cLottable02 = LA.Lottable02, 
         @cLottable03 = LA.Lottable03
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
      WHERE LLI.LOC = @cFromLOC
         AND LLI.ID = @cFromID
         AND LLI.StorerKey = @cStorerkey
         AND LLI.SKU = @cSKU
         AND LLI.QTY - LLI.QTYPicked > 0
      
      IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'NOMIXLOT02' AND Code = @cLottable02 AND StorerKey = @cStorerKey)
      BEGIN
      	-- Find a friend (same SKU, same group of L02)
         INSERT INTO @tSuggestLocInfo (Loc,LocDesc,LocQ,LocSKU,SKUQ,Seq)----(cc01)
         SELECT LOC.LOC, ISNULL(LOC.Descr,''),0,0, Sum(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked),1--(cc01)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
         WHERE LOC.Facility = @cFacility
            AND LLI.StorerKey = @cStorerkey
            AND LLI.SKU = @cSKU
            AND (LLI.QTY - LLI.QTYPicked > 0 OR LLI.PendingMoveIn > 0)
            AND EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'NOMIXLOT02' AND Code = LA.Lottable02 AND StorerKey = @cStorerKey)
            AND EXISTS (SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE Listname = 'SUGLOCROOM' and StorerKey = @cStorerKey AND code = LOC.LocationRoom) --(cc01)
            AND EXISTS (SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE Listname = 'SUGLOCFLAG' and StorerKey = @cStorerKey AND code = LOC.LocationFlag) --(cc01)
            AND LA.Lottable03 = @cLottable03
            AND LOC.LocationType = 'DYNPPICK'
            AND LOC.LOC <> @cFromLoc
         GROUP BY LOC.LOC,LOC.Descr
      END  
      ELSE
      BEGIN
      	-- Find a friend (same SKU, diff group of L02)
         INSERT INTO @tSuggestLocInfo (Loc,LocDesc,LocQ,LocSKU,SKUQ,Seq)----(cc01)
         SELECT LOC.LOC, ISNULL(LOC.Descr,''),0,0, Sum(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked),1--(cc01)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
         WHERE LOC.Facility = @cFacility
            AND LLI.StorerKey = @cStorerkey
            AND LLI.SKU = @cSKU
            AND (LLI.QTY - LLI.QTYPicked > 0 OR LLI.PendingMoveIn > 0)
            AND LA.Lottable02 NOT IN (SELECT Code FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'NOMIXLOT02' AND StorerKey = @cStorerKey)
            AND EXISTS (SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE Listname = 'SUGLOCROOM' and StorerKey = @cStorerKey AND code = LOC.LocationRoom) --(cc01)
            AND EXISTS (SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE Listname = 'SUGLOCFLAG' and StorerKey = @cStorerKey AND code = LOC.LocationFlag) --(cc01)
            AND LA.Lottable03 = @cLottable03
            AND LOC.LocationType = 'DYNPPICK'
            AND LOC.LOC <> @cFromLoc
         GROUP BY LOC.LOC,LOC.Descr
      END
      
      IF (SELECT COUNT(*) FROM @tSuggestLocInfo) < 3
      BEGIN
         INSERT INTO @tSuggestLocInfo (Loc,LocDesc,LocQ,LocSKU,SKUQ,Seq)----(cc01)
         SELECT TOP 3 LOC.LOC, ISNULL(LOC.Descr,''),0,0, Sum(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked),2--(cc01)
         FROM dbo.LOC WITH (NOLOCK)
            LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationType = 'DYNPPICK'
            AND LOC.LocationCategory = 'MEZZ'
            AND LOC.LOC <> @cFromLoc
            AND EXISTS (SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE Listname = 'SUGLOCROOM' and StorerKey = @cStorerKey AND code = LOC.LocationRoom) --(cc01)
            AND EXISTS (SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE Listname = 'SUGLOCFLAG' and StorerKey = @cStorerKey AND code = LOC.LocationFlag) --(cc01)
         GROUP BY LOC.PALogicalLoc,LOC.LOC,LOC.Descr
         HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
            AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
         ORDER BY LOC.PALogicalLoc, LOC.LOC
      END
      
      --(cc01)
      IF NOT EXISTS (SELECT 1 FROM @tSuggestLocInfo)
      BEGIN
      	SET @cOutField01 = '< No Suggestion >'
      END
      ELSE
      BEGIN
      	UPDATE @tSuggestLocInfo set
         locSKU = aa.locSKU
         FROM @tSuggestLocInfo tsli 
         JOIN (
            SELECT COUNT(DISTINCT LLI.SKU) AS locSKU,suggestLoc.Loc
            FROM @tSuggestLocInfo suggestLoc
            JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON (suggestLoc.Loc = LLI.Loc)
            WHERE ( (LLI.Qty) - (LLI.QtyAllocated) - (LLI.QtyPicked)) > 0
            GROUP BY suggestLoc.Loc
         )aa
         ON tsli.loc = aa.loc

         UPDATE @tSuggestLocInfo set
         locQ = aa.locQ
         FROM @tSuggestLocInfo tsli 
         JOIN (
            SELECT sum(Qty - QtyAllocated - QtyPicked) AS locQ,suggestLoc.Loc
            FROM @tSuggestLocInfo suggestLoc
            JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON (suggestLoc.Loc = LLI.Loc)
            WHERE LLI.Qty > 0
            Group BY suggestLoc.Loc
         )aa
         ON tsli.loc = aa.loc
         
         --SELECT @nRow = COUNT(1) FROM @tSuggestLocInfo
      
         
   	   DECLARE @curSuggestLoc CURSOR
   	   SET @curSuggestLoc = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LOC, LocDesc, LocQ, LocSKU, SKUQ
            FROM @tSuggestLocInfo
            ORDER BY seq,LocQ
         
         OPEN @curSuggestLoc      
         FETCH NEXT FROM @curSuggestLoc INTO @cSuggestedLoc, @cSuggestedLocDesc, @cSuggestedLocQ, @cSuggestedLocSKU, @cSuggestedLocSKUQ   
         WHILE @nCount < 4   --AND @nCount <= @nRow
         BEGIN      
            -- Get suggest loc info      
            IF @@FETCH_STATUS = 0     
            BEGIN       
            	IF @cSuggestedLocDesc = ''
            	BEGIN
            		SET @cSuggestedDesc = @cSuggestedLoc
            	END
            	ELSE
               BEGIN
               	SET @cSuggestedDesc = @cSuggestedLocDesc
               END
            	 
               IF @nCount = 1      
               BEGIN      
                  SET @cOutField01 = CASE WHEN @@FETCH_STATUS = 0 THEN '1) ' + @cSuggestedDesc ELSE '' END      
                  SET @cOutField02 = CASE WHEN @@FETCH_STATUS = 0 THEN 'LocQ / LocSku / SkuQ'    ELSE '' END      
                  --SET @cOutField03 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSuggestedLocQ + ' / ' +  @cSuggestedLocSKU + ' / ' + @cSuggestedLocSKUQ ELSE '' END   
                  SET @cOutField03 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSuggestedLocQ + SPACE (5-LEN(@cSuggestedLocQ))+'/ ' + @cSuggestedLocSKU + SPACE (7-LEN(@cSuggestedLocSKU))+ '/ ' + @cSuggestedLocSKUQ  ELSE '' END   
                  SET @cOutField04 = ''       
               END      
               IF @nCount = 2      
               BEGIN      
                  SET @cOutField05 = CASE WHEN @@FETCH_STATUS = 0 THEN '2) ' + @cSuggestedDesc ELSE '' END     
                  SET @cOutField06 = CASE WHEN @@FETCH_STATUS = 0 THEN 'LocQ / LocSku / SkuQ'    ELSE '' END     
                  --SET @cOutField07 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSuggestedLocQ + ' / ' +  @cSuggestedLocSKU + ' / ' + @cSuggestedLocSKUQ ELSE '' END     
                  SET @cOutField07 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSuggestedLocQ + SPACE (5-LEN(@cSuggestedLocQ))+'/ ' + @cSuggestedLocSKU + SPACE (7-LEN(@cSuggestedLocSKU))+ '/ ' + @cSuggestedLocSKUQ  ELSE '' END  
                  SET @cOutField08 = ''     
               END      
               IF @nCount = 3      
               BEGIN      
                  SET @cOutField09 = CASE WHEN @@FETCH_STATUS = 0 THEN '3) ' + @cSuggestedDesc ELSE '' END       
                  SET @cOutField10 = CASE WHEN @@FETCH_STATUS = 0 THEN 'LocQ / LocSku / SkuQ'    ELSE '' END       
                  --SET @cOutField11 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSuggestedLocQ + ' / ' +  @cSuggestedLocSKU + ' / ' + @cSuggestedLocSKUQ ELSE '' END  
                  SET @cOutField11 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSuggestedLocQ + SPACE (5-LEN(@cSuggestedLocQ))+'/ ' + @cSuggestedLocSKU + SPACE (7-LEN(@cSuggestedLocSKU))+ '/ ' + @cSuggestedLocSKUQ  ELSE '' END 
                  SET @cOutField12 = ''     
               END      
               SET @nCount = @nCount + 1      
               FETCH NEXT FROM @curSuggestLoc INTO @cSuggestedLoc, @cSuggestedLocDesc, @cSuggestedLocQ, @cSuggestedLocSKU, @cSuggestedLocSKUQ      
            END  
            ELSE  
               BREAK; 
         END
      END
   END
   
   IF @cType = 'UNLOCK'
   BEGIN
      -- Unlock current session suggested LOC
      IF @nPABookingKey <> 0
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --FromLOC
            ,'' --FromID
            ,'' --SuggestedLOC
            ,'' --Storer
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0  
            GOTO Quit  
      END
   END

Quit:

END

GO