SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/******************************************************************************/  
/* Store procedure: rdt_513SuggestLOC02                                       */  
/* Copyright      : LFLogistics                                               */  
/*                                                                            */  
/* Purpose:                                                                   */  
/*                                                                            */  
/* Date        Rev  Author   Purposes                                         */  
/* 26-02-2016  1.0  Chew     SOS#363166 Created                               */  
/* 25-04-2017  1.1  Ung      WMS-1708 Change hardcode zones to configurable   */
/* 26-11-2018  1.2  ChewKP   WMS-6986 (ChewKP01)                              */
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_513SuggestLOC02] (  
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
      DECLARE @cSuggToLoc NVARCHAR(10) 
            , @cMaterial NVARCHAR(9) 
            , @cPutawayZone NVARCHAR(10) 
        
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      
      SELECT @cPutawayZone = PutawayZone 
      FROM dbo.LOC WITH (NOLOCK) 
      WHERE Loc = @cFromLoc 
     
      
      SET @cMaterial = SUBSTRING(@cSKU,1,9)
      
      SELECT TOP 1 @cSuggToLoc = Loc.Loc 
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      INNER JOIN  dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc 
      GROUP BY Loc.Loc, Loc.Facility, Loc.PutawayZone, LLI.SKU
      HAVING Loc.Facility = @cFacility
      -- AND Loc.PutawayZone = 'NIKEA'
      --AND Loc.PutawayZone IN (
      --   SELECT Short FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Code = 'LV1' AND StorerKey = @cStorerKey AND Code2 = @nFunc)
      AND Loc.PutawayZone = @cPutawayZone
      AND LLI.SKU = @cSKU
      AND SUM(LLI.Qty) > 0 
      --AND SUM(LLI.Qty) + @nQTY <= 144
      AND Loc.Loc <> @cFromLoc
      ORDER BY Loc.Loc
      
      IF ISNULL( @cSuggToLoc , '' ) = ''
      BEGIN


         SELECT TOP 1 @cSuggToLoc = Loc.Loc 
         FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
         INNER JOIN  dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc 
         GROUP BY Loc.Loc, Loc.Facility, Loc.PutawayZone, SUBSTRING(LLI.SKU,1,9)
         HAVING Loc.Facility = @cFacility
         -- AND Loc.PutawayZone = 'NIKEA'
         --AND Loc.PutawayZone IN (
         --   SELECT Short FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Code = 'LV2' AND StorerKey = @cStorerKey AND Code2 = @nFunc)
         AND Loc.PutawayZone = @cPutawayZone
         AND SUBSTRING(LLI.SKU,1,9) = @cMaterial
         AND SUM(LLI.Qty) > 0 
         --AND SUM(LLI.Qty) + @nQTY <= 144
         AND Loc.Loc <> @cFromLoc
         ORDER BY SUM(LLI.Qty-LLI.QtyAllocated-LLI.QtyPicked), Loc.Loc
         
         IF ISNULL( @cSuggToLoc , '' ) = ''
         BEGIN
            
            SELECT TOP 1 @cSuggToLoc = Loc.Loc 
            FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
            INNER JOIN  dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc 
            GROUP BY Loc.Loc, Loc.Facility, Loc.PutawayZone, SUBSTRING(LLI.SKU,1,9)
            HAVING Loc.Facility = @cFacility
            -- AND Loc.PutawayZone IN ( 'MEZ2_750', 'GF2_1500' ) 
            --AND Loc.PutawayZone IN (
            --   SELECT Short FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Code = 'LV3' AND StorerKey = @cStorerKey AND Code2 = @nFunc)
            AND Loc.PutawayZone = @cPutawayZone
            AND SUBSTRING(LLI.SKU,1,9) = @cMaterial
            AND SUM(LLI.Qty) > 0 
            --AND SUM(LLI.Qty) + 13 <= 144
            AND Loc.Loc <> @cFromLoc
            ORDER BY SUM(LLI.Qty-LLI.QtyAllocated-LLI.QtyPicked), Loc.Loc
         
            
         END
         
         
      END
      
      
     
      IF @cSuggToLoc = ''  
      BEGIN
         SET @cOutField01 = ''
         SET @nErrNo = -1  
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cSuggToLoc
      END
   END  
     
Quit:  
  
END  

GO