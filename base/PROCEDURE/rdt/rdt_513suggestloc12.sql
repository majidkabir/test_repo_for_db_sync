SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513SuggestLOC12                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Show 1st Loc asc order: Min (LotxLocxID.Loc)                */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 22-10-2020  1.0  Chermaine   WMS-15504 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_513SuggestLOC12] (
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
      SKUQ     INT 
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
   	INSERT INTO @tSuggestLocInfo (Loc,LocDesc,LocQ,LocSKU,SKUQ)
      SELECT 
         LOC.LOC, ISNULL(LOC.Descr,''),0,0, Sum(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      LEFT JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      LEFT JOIN codelkup CLK WITH (NOLOCK) ON (LLI.StorerKey = CLK.storerKey AND LOC.LocationType = CLK.code)
      LEFT JOIN codelkup CL WITH (NOLOCK) ON (LLI.StorerKey = CL.storerKey AND LOC.LocationFlag = CL.code) 
      WHERE LLI.Storerkey = @cStorerkey 
      AND LLI.SKU = @cSKU
      AND ( LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0 
      AND LOC.Facility  = @cFacility  
      AND CLK.listName = 'SUGLOCTYPE'
      AND CL.listName = 'SUGLOCFLAG'
      AND LOC.Loc <> @cFromLoc
      GROUP BY LOC.LOC,LOC.Descr
      
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
            ORDER BY LocQ
         
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

Quit:

END

GO