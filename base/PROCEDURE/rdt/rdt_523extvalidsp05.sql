SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_523ExtValidSP05                                 */  
/* Purpose: Validate Final LOC.                                         */
/*          1. If locationtype = 'PICK', prompt error                   */  
/*          2. If locationtype <> 'PICK', pass                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2018-11-19 1.0  ChewKP    WMS-6885. Created                          */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtValidSP05] (  
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT, 
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cFacility       NVARCHAR( 5),  
   @cFromLOC        NVARCHAR( 10), 
   @cFromID         NVARCHAR( 18), 
   @cSKU            NVARCHAR( 20), 
   @nQty            INT,  
   @cSuggestedLOC   NVARCHAR( 10), 
   @cFinalLOC       NVARCHAR( 10), 
   @cOption         NVARCHAR( 1),  
   @nErrNo          INT           OUTPUT,  
   @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  

   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @cPutawayZone NVARCHAR(10)

   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 4
      BEGIN
         SELECT TOP 1 @cPutawayZone = LA.Lottable06
         FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
         INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot AND LA.StorerKey = LLI.StorerKey 
         WHERE LLI.StorerKey = @cStorerKey 
         AND LLI.SKU = @cSKU 
         AND LLI.Loc = @cFromLOC
         AND LLI.ID  = @cFromID 
         AND LLI.QTY > 0 
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOlOCK) 
                         WHERE Facility = @cFacility
                         AND PutawayZone = @cPutawayZone
                         AND Loc = @cFinalLOC ) 
         BEGIN
               SET @nErrNo = 131901
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LocNotSameZone
               GOTO Quit
         END
         
      END
   END
    
   QUIT:
 

GO