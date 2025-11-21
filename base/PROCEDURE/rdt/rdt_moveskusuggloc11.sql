SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_MoveSKUSuggLoc11                                */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2022-09-07  1.0  James       WMS-20594. Created                      */
/************************************************************************/

CREATE   PROC [RDT].[rdt_MoveSKUSuggLoc11] (
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

   DECLARE @cSuggLOC       NVARCHAR(10) = ''
   DECLARE @cPutawayZone   NVARCHAR( 10) = ''
   DECLARE @cStyle         NVARCHAR( 20) = ''
   DECLARE @cSKUGroup      NVARCHAR( 10) = ''
   
   IF @cType = 'UNLOCK'
      GOTO Quit

   IF @cType = 'LOCK'
   BEGIN
   	SELECT @cPutawayZone = PutawayZone
   	FROM dbo.LOC WITH (NOLOCK)
   	WHERE LOC = @cFromLoc
   	AND   Facility = @cFacility
   	
   	SELECT 
   	   @cStyle = Style, 
   	   @cSKUGroup = SKUGROUP
   	FROM dbo.SKU WITH (NOLOCK)
   	WHERE StorerKey = @cStorerkey
   	AND   Sku = @cSKU
   	
   	IF EXISTS ( SELECT 1 FROM dbo.SKUxLOC WITH (NOLOCK)
   	            WHERE Loc = @cFromLoc
   	            AND   LocationType = 'PICK')
      BEGIN
         -- Same SKU in DPBulk
         SELECT TOP 1 @cSuggLOC = LOC.LOC
         FROM dbo.LOC LOC WITH (NOLOCK)
         JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
         AND   LOC.LOC <> @cFromLOC
         AND   LOC.PutawayZone = @cPutawayZone
         AND   LOC.LocationType = 'DPBulk'
         AND   SL.StorerKey = @cStorerKey
         AND   SL.SKU = @cSKU
         GROUP BY LOC.PALogicalLOC, LOC.LOC
         HAVING SUM( ISNULL( SL.QTY, 0) - ISNULL( SL.QTYPicked, 0)) > 0
         ORDER BY LOC.PALogicalLOC, LOC.LOC

         IF @cSuggLOC <> ''
            GOTO Quit

         -- Any Loc with the same article 
         SELECT TOP 1 @cSuggLOC = LOC.LOC
         FROM dbo.LOC LOC WITH (NOLOCK)
         JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (SL.StorerKey = SKU.StorerKey AND SL.Sku = SKU.Sku)
         WHERE LOC.Facility = @cFacility
         AND   LOC.LOC <> @cFromLOC
         AND   LOC.PutawayZone = @cPutawayZone
         AND   LOC.LocationType = 'DPBulk'
         AND   SL.StorerKey = @cStorerKey
         AND   SKU.Style = @cStyle
         GROUP BY LOC.PALogicalLOC, LOC.LOC
         HAVING SUM( ISNULL( SL.QTY, 0) - ISNULL( SL.QTYPicked, 0)) > 0
         ORDER BY LOC.PALogicalLOC, LOC.LOC

         IF @cSuggLOC <> ''
            GOTO Quit

         -- Find empty LOC
         SELECT TOP 1 @cSuggLOC = LOC.LOC
         FROM dbo.LOC LOC WITH (NOLOCK)
         LEFT JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
         AND   LOC.LOC <> @cFromLOC
         AND   LOC.PutawayZone = @cPutawayZone
         AND   LOC.LocationType = 'DPBulk'
         GROUP BY LOC.PALogicalLOC, LOC.LOC
         HAVING SUM( ISNULL( SL.QTY, 0) - ISNULL( SL.QTYPicked, 0)) = 0
         ORDER BY LOC.PALogicalLOC, LOC.LOC

         IF @cSuggLOC <> ''
            GOTO Quit
      END
      ELSE
      BEGIN
         -- Same SKU in DPBulk
         SELECT TOP 1 @cSuggLOC = LOC.LOC
         FROM dbo.LOC LOC WITH (NOLOCK)
         JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
         AND   LOC.LOC <> @cFromLOC
         AND   LOC.PutawayZone = @cPutawayZone
         AND   LOC.LocationType = 'DPBulk'
         AND   SL.StorerKey = @cStorerKey
         AND   SL.SKU = @cSKU
         GROUP BY LOC.PALogicalLOC, LOC.LOC
         HAVING SUM( ISNULL( SL.QTY, 0) - ISNULL( SL.QTYPicked, 0)) > 0
         ORDER BY SUM( ISNULL( SL.QTY, 0) - ISNULL( SL.QTYPicked, 0)) DESC, LOC.PALogicalLOC, LOC.LOC

         IF @cSuggLOC <> ''
            GOTO Quit

         -- Any Loc with the same article 
         SELECT TOP 1 @cSuggLOC = LOC.LOC
         FROM dbo.LOC LOC WITH (NOLOCK)
         JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (SL.StorerKey = SKU.StorerKey AND SL.Sku = SKU.Sku)
         WHERE LOC.Facility = @cFacility
         AND   LOC.LOC <> @cFromLOC
         AND   LOC.PutawayZone = @cPutawayZone
         AND   LOC.LocationType = 'DPBulk'
         AND   SL.StorerKey = @cStorerKey
         AND   SKU.Style = @cStyle
         GROUP BY LOC.PALogicalLOC, LOC.LOC
         HAVING SUM( ISNULL( SL.QTY, 0) - ISNULL( SL.QTYPicked, 0)) > 0
         ORDER BY SUM( ISNULL( SL.QTY, 0) - ISNULL( SL.QTYPicked, 0)) DESC, LOC.PALogicalLOC, LOC.LOC

         IF @cSuggLOC <> ''
            GOTO Quit

         -- Find empty LOC
         --SELECT TOP 1 @cSuggLOC = LOC.LOC
         --FROM dbo.LOC LOC WITH (NOLOCK)
         --LEFT JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         --WHERE LOC.Facility = @cFacility
         --AND   LOC.LOC <> @cFromLOC
         --AND   LOC.PutawayZone = @cPutawayZone
         --AND   LOC.LocationType = 'DPBulk'
         --GROUP BY LOC.PALogicalLOC, LOC.LOC
         --HAVING SUM( ISNULL( SL.QTY, 0) - ISNULL( SL.QTYPicked, 0)) = 0
         --ORDER BY LOC.PALogicalLOC, LOC.LOC

         --IF @cSuggLOC <> ''
         --   GOTO Quit

         -- Find empty LOC
         SELECT TOP 1 @cSuggLOC = LOC.LOC 
         FROM dbo.LOC LOC WITH (NOLOCK) 
         LEFT JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (SL.LOC = LOC.LOC) 
         WHERE LOC.Facility = @cFacility 
         AND   LOC.LOC <> @cFromLOC 
         AND   LOC.LocationType = 'DPBulk' 
	      -- ToLoc.PutawayZone = FromLoc.PutawayZone
         AND   LOC.PutawayZone = ( SELECT DISTINCT LOC.PutawayZone 
                                   FROM dbo.LOC LOC WITH (NOLOCK) 
				  			              LEFT JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (SL.LOC = LOC.LOC) 
							              WHERE SL.StorerKey = @cStorerKey  
								           AND   SL.SKU = @cSKU
								           AND   SL.LocationType = 'PICK')
         GROUP BY LOC.PALogicalLOC, LOC.LOC 
         HAVING SUM( ISNULL( SL.QTY, 0) - ISNULL( SL.QTYPicked, 0)) = 0 
         ORDER BY LOC.PALogicalLOC, LOC.LOC 

         IF @cSuggLOC <> '' 
            Goto Quit
      
        IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                    WHERE LISTNAME = 'DPBulkADI' 
                    AND   Long = @cSKUGroup 
                    --AND   Short = @cPutawayZone  --Remove condition
                    AND   Storerkey = 'ADIDAS') 
        BEGIN 
           -- Find empty LOC 
           SELECT TOP 1 @cSuggLOC = LOC.LOC 
           FROM dbo.LOC LOC WITH (NOLOCK) 
           LEFT JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (SL.LOC = LOC.LOC) 
		     LEFT JOIN dbo.CODELKUP C WITH (NOLOCK) on (LOC.PickZone = C.Short and SL.StorerKey = C.StorerKey)
           WHERE LOC.Facility = @cFacility 
           AND   LOC.LOC <> @cFromLOC 
           AND   LOC.LocationType = 'DPBulk' 
           AND   LOC.PutawayZone <> @cPutawayZone 
		     AND	  C.Long = @cSKUGroup				 --Add SKUGroup
		     AND   SL.StorerKey = @cStorerKey		 --Add StorerKey
           GROUP BY LOC.PALogicalLOC, LOC.LOC 
           HAVING SUM( ISNULL( SL.QTY, 0) - ISNULL( SL.QTYPicked, 0)) = 0 
           ORDER BY LOC.PALogicalLOC, LOC.LOC 
        
            IF @cSuggLOC = ''
            BEGIN
               IF @cSKUGroup = '01' AND @cPutawayZone = 'ADITIER02' 
                  SET @cSuggLOC = 'ADITIER01'
            END
            
            IF @cSuggLOC <> ''
               GOTO Quit
         END
      END
      
      Quit:
      IF @cSuggLOC <> ''
      BEGIN
      	SET @cOutField01 = 'SUGGESTED LOCATION:'
      	SET @cOutField02 = @cSuggLOC
      END
   END
   


END

GO