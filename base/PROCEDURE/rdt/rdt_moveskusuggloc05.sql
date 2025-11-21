SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_MoveSKUSuggLoc05                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Get suggested loc to move                                   */  
/*                                                                      */  
/* Called from: rdtfnc_Move_SKU                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 12-05-2016  1.0  James       SOS369604 - Created                     */  
/* 23-01-2017  1.1  James       Enhance find suggest loc logic (james01)*/
/* 05-06-2017  1.2  James       WMS2106-Enhance find suggested loc      */  
/*                              logic (james02)                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_MoveSKUSuggLoc05] (  
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
  
   DECLARE @cSuggestedLoc  NVARCHAR( 10),  
           @nLoop          INT,  
           @nQTYAvail      INT  
  
   IF @cType = 'LOCK'  
   BEGIN  
      -- Suggest location logical:  
      -- Get pick loc. If no pick loc assigned then show error     
     
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cToLOC = ''  
  
      -- Find a friend  
      SELECT TOP 1 @cToLOC = SL.LOC  
      FROM dbo.SKUxLOC SL WITH (NOLOCK)  
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)  
      JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.LOC = LLI.LOC)  
      WHERE SL.StorerKey = @cStorerkey  
      AND   SL.SKU = @cSKU  
      AND   SL.LocationType IN ('PICK', 'CASE')  
      AND   LOC.Facility = @cFacility  
      AND   LOC.LOC <> @cFromLoc  
      AND   LOC.Locationflag <> 'HOLD'  
      AND   LOC.Locationflag <> 'DAMAGE'  
      AND   LOC.Status <> 'HOLD'  
        
      -- Look for empty pick faces of the same sku previously lived there (james02)  
      IF ISNULL( @cToLOC, '') = ''  
         SELECT TOP 1 @cToLOC = LOC.LOC  
         FROM dbo.LOC LOC WITH (NOLOCK)   
         LEFT OUTER JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)  
         WHERE SL.StorerKey = @cStorerkey  
         AND   SL.SKU = @cSKU
         AND   LOC.Facility = @cFacility  
         AND   LOC.LOC <> @cFromLoc  
         AND   LOC.Locationflag <> 'HOLD'  
         AND   LOC.Locationflag <> 'DAMAGE'  
         AND   LOC.Status <> 'HOLD'           
         AND   LOC.CommingleSKU <> '1'  
         GROUP BY LOC.PALogicalLoc, LOC.LOC   
         HAVING SUM(SL.Qty - SL.QtyPicked) = 0 OR SUM(SL.Qty - SL.QtyPicked) IS NULL   
         ORDER BY LOC.PALogicalLoc, LOC.LOC  
           
      -- Look for new pick loc in P08 and P10.  
      IF ISNULL( @cToLOC, '') = ''  
         SELECT TOP 1 @cToLOC = LOC.LOC  
         FROM dbo.LOC LOC WITH (NOLOCK)  
         JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.LOC = LLI.LOC)  
         WHERE LOC.Facility = @cFacility  
         AND   ( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0  
         AND   LOC.LOC <> @cFromLoc  
         AND   LOC.PUTAWAYZONE IN ('P08', 'P10')  
         AND   LOC.Locationflag <> 'HOLD'  
         AND   LOC.Locationflag <> 'DAMAGE'  
         AND   LOC.Status <> 'HOLD'       
         GROUP BY LLI.QtyPicked, LOC.LOC, LOC.LogicalLocation, LLI.Qty   
         HAVING SUM(LLI.Qty - LLI.QtyPicked) < '2' OR SUM(LLI.Qty - LLI.QtyPicked) IS NULL       
         AND LLI.Qty < '3'  
         ORDER BY LOC.LogicalLocation, LOC.LOC  
  
      -- If inventory is new then will return blank suggested loc  
      -- Then show message 'NO LOC - SEE_SUPV'                    
      IF ISNULL( @cToLOC, '') = ''  
         SET @cOutField01 = ' NO LOC - SEE_SUPV'  
      ELSE  
      BEGIN  
         SET @cOutField01 = 'SUGGESTED LOCATION:'  
         SET @cOutField02 = @cToLOC  
      END  
   END  
     
Quit:  
  
END

GO