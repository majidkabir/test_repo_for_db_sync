SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_513SuggestLOC15                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Find friend, find empty then find dedicated loc             */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2021-10-28  1.0  James       WMS-18148. Created                      */
/* 2022-09-22  1.1  yeekung     WMS-20795 Add LocQty Sorted(yeekung01)  */
/************************************************************************/

CREATE   PROC [RDT].[rdt_513SuggestLOC15] (
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

   DECLARE @cSuggestedLoc        NVARCHAR( 10) = ''
   DECLARE @cLottable03          NVARCHAR( 18) = ''
   DECLARE @cStyle               NVARCHAR( 10) = ''
   DECLARE @cPAZone              NVARCHAR( 10) = ''
   DECLARE @cSuggestedLocDesc    NVARCHAR( 60) = ''
   DECLARE @cSuggestedDesc       NVARCHAR( 60) = ''
   DECLARE @cSuggestedLocQ       NVARCHAR( 10) = ''
   DECLARE @cSuggestedLocSKU     NVARCHAR( 10) = ''
   DECLARE @cSuggestedLocSKUQ    NVARCHAR( 10) = ''
   DECLARE @nCount               INT = 0

   DECLARE @tSuggestLocInfo TABLE
   (
      Loc      NVARCHAR( 10),
      LocDesc  NVARCHAR( 60),
      LocQ     INT,
      LocSKU   INT,
      SKUQ     INT,
      Seq      INT
   )

   DECLARE @tPutawayZone  TABLE ( PutawayZone       NVARCHAR( 10))
   DECLARE @tLocationRoom TABLE ( LocationRoom      NVARCHAR( 30))
   DECLARE @tLocationFlag TABLE ( LocationFlag      NVARCHAR( 10))

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
      INSERT INTO @tPutawayZone ( PutawayZone )
      SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE LISTNAME = 'LULUPAZONE' AND Storerkey = @cStorerkey

      INSERT INTO @tLocationRoom ( LocationRoom )
      SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE LISTNAME = 'SUGLOCROOM' AND Storerkey = @cStorerkey

      INSERT INTO @tLocationFlag ( LocationFlag )
      SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE LISTNAME = 'SUGLOCFLAG' AND Storerkey = @cStorerkey

      SELECT TOP 1 @cLottable03 = LA.Lottable03
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
      WHERE LLI.Loc = @cFromLoc
      AND   (( ISNULL( @cFromID, '') = '') OR ( LLI.Id = @cFromID))
      AND   LLI.Sku = @cSKU
      AND   LLI.Storerkey = @cStorerkey
      ORDER BY 1

      -- Find friend
      INSERT INTO @tSuggestLocInfo (Loc,LocDesc,LocQ,LocSKU,SKUQ,Seq)
      SELECT TOP 3 LOC.LOC, ISNULL(LOC.Descr,''),0,0, Sum(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS  LocQty,1 --(yeekung01)
      FROM dbo.LotxLocxID LLI WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
      WHERE LLI.Storerkey = @cStorerkey
      AND   LLI.SKU = @cSKU
      AND ( LLI.Qty - LLI.QtyPicked) > 0
      AND   LOC.Facility  = @cFacility
      AND   LOC.LocationType IN ( 'PICK', 'DYNPPICK')
      AND   LOC.LocationFlag <> 'HOLD'
      AND   LOC.LOC <> @cFromLoc
      AND   LA.Lottable03 = @cLottable03
      AND   EXISTS ( SELECT 1 FROM @tPutawayZone P WHERE P.PutawayZone = LOC.PutawayZone)
      AND   EXISTS ( SELECT 1 FROM @tLocationRoom R WHERE R.LocationRoom = LOC.LocationRoom)
      AND   EXISTS ( SELECT 1 FROM @tLocationFlag F WHERE F.LocationFlag = LOC.LocationFlag)
      GROUP BY LOC.PALogicalLoc, LOC.LogicalLocation, LOC.LOC,LOC.Descr
      ORDER BY LocQty,LOC.PALogicalLoc, LOC.LogicalLocation, LOC.LOC --(yeekung01)

     -- Find empty
      IF (SELECT COUNT( 1) FROM @tSuggestLocInfo) < 3
      BEGIN
         SELECT @cStyle = Style
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerkey
         AND   Sku = @cSKU

         SET @cStyle = SUBSTRING( @cStyle, 1, 2)

         DECLARE @cCurPAZone  CURSOR
         SET @cCurPAZone = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT Code
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'LULUPAZONE'
         AND   Storerkey = @cStorerkey
         AND   Short = @cStyle
         ORDER BY 1
         OPEN @cCurPAZone
         FETCH NEXT FROM @cCurPAZone INTO @cPAZone
         WHILE @@FETCH_STATUS = 0
         BEGIN
            INSERT INTO @tSuggestLocInfo (Loc,LocDesc,LocQ,LocSKU,SKUQ,Seq)
            SELECT TOP 3 LOC.LOC, ISNULL(LOC.Descr,''),0,0, Sum(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)  AS  LocQty,2 --(yeekung01)
            FROM dbo.LOC WITH (NOLOCK)
            LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            WHERE LOC.Facility = @cFacility
            AND   LOC.LocationType IN ( 'PICK', 'DYNPPICK')
            AND   LOC.LocationFlag <> 'HOLD'
            AND   LOC.LOC <> @cFromLoc
            AND   LOC.PutawayZone = @cPAZone
            AND   EXISTS ( SELECT 1 FROM @tLocationRoom R WHERE R.LocationRoom = LOC.LocationRoom)
            AND   EXISTS ( SELECT 1 FROM @tLocationFlag F WHERE F.LocationFlag = LOC.LocationFlag)
            GROUP BY  LOC.PALogicalLoc, LOC.LogicalLocation, LOC.LOC, LOC.Descr
            HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
               AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
            ORDER BY LocQty,LOC.PALogicalLoc, LOC.LogicalLocation, LOC.LOC --(yeekung01)
                     
            IF (SELECT COUNT(1) FROM @tSuggestLocInfo) > 0
               BREAK

            FETCH NEXT FROM @cCurPAZone INTO @cPAZone
         END
      END

      IF (SELECT COUNT( 1) FROM @tSuggestLocInfo) < 3
      BEGIN
         -- Suggest any empty loc in DPP
         INSERT INTO @tSuggestLocInfo (Loc,LocDesc,LocQ,LocSKU,SKUQ,Seq)
         SELECT TOP 3 LOC.LOC, ISNULL(LOC.Descr,''),0,0, Sum(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)  AS  LocQty,3 --(yeekung01)
         FROM dbo.LOC WITH (NOLOCK)
         LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
         AND   LOC.LocationType = 'DYNPPICK'
         AND   LOC.LocationFlag <> 'HOLD'
         AND   LOC.LOC <> @cFromLoc
         AND   EXISTS ( SELECT 1 FROM @tLocationRoom R WHERE R.LocationRoom = LOC.LocationRoom)
         AND   EXISTS ( SELECT 1 FROM @tLocationFlag F WHERE F.LocationFlag = LOC.LocationFlag)
         GROUP BY LOC.PALogicalLoc, LOC.LogicalLocation, LOC.LOC, LOC.Descr
         HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
            AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
         ORDER BY LocQty, LOC.PALogicalLoc, LOC.LogicalLocation, LOC.LOC  --(yeekung01)
      END
   END

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

   	DECLARE @curSuggestLoc CURSOR
   	SET @curSuggestLoc = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LOC, LocDesc, LocQ, LocSKU, SKUQ
         FROM @tSuggestLocInfo
         ORDER BY seq,LocQ

      OPEN @curSuggestLoc
      FETCH NEXT FROM @curSuggestLoc INTO @cSuggestedLoc, @cSuggestedLocDesc, @cSuggestedLocQ, @cSuggestedLocSKU, @cSuggestedLocSKUQ
      WHILE @nCount < 4
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
               SET @cOutField03 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSuggestedLocQ + SPACE (5-LEN(@cSuggestedLocQ))+'/ ' + @cSuggestedLocSKU + SPACE (7-LEN(@cSuggestedLocSKU))+ '/ ' + @cSuggestedLocSKUQ  ELSE '' END
               SET @cOutField04 = ''
            END
            IF @nCount = 2
            BEGIN
               SET @cOutField05 = CASE WHEN @@FETCH_STATUS = 0 THEN '2) ' + @cSuggestedDesc ELSE '' END
               SET @cOutField06 = CASE WHEN @@FETCH_STATUS = 0 THEN 'LocQ / LocSku / SkuQ'    ELSE '' END
               SET @cOutField07 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSuggestedLocQ + SPACE (5-LEN(@cSuggestedLocQ))+'/ ' + @cSuggestedLocSKU + SPACE (7-LEN(@cSuggestedLocSKU))+ '/ ' + @cSuggestedLocSKUQ  ELSE '' END
               SET @cOutField08 = ''
            END
            IF @nCount = 3
            BEGIN
               SET @cOutField09 = CASE WHEN @@FETCH_STATUS = 0 THEN '3) ' + @cSuggestedDesc ELSE '' END
               SET @cOutField10 = CASE WHEN @@FETCH_STATUS = 0 THEN 'LocQ / LocSku / SkuQ'    ELSE '' END
               SET @cOutField11 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSuggestedLocQ + SPACE (5-LEN(@cSuggestedLocQ))+'/ ' + @cSuggestedLocSKU + SPACE (7-LEN(@cSuggestedLocSKU))+ '/ ' + @cSuggestedLocSKUQ  ELSE '' END
               SET @cOutField12 = ''
            END
            SET @nCount = @nCount + 1
            FETCH NEXT FROM @curSuggestLoc INTO @cSuggestedLoc, @cSuggestedLocDesc, @cSuggestedLocQ, @cSuggestedLocSKU, @cSuggestedLocSKUQ
         END
         ELSE
            BREAK
      END
   END
Quit:

END

GO