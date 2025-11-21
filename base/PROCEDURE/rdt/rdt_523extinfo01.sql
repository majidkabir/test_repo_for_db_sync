SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_523ExtInfo01                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: H&M Japan display qty on hand for the suggested loc         */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2015-10-29 1.0  James    SOS353560 Created                           */    
/* 2016-12-07 1.1  Ung      WMS-751 Change parameter                    */
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_523ExtInfo01]    
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT, 
   @nAfterStep      INT, 
   @nInputKey       INT,                
   @cStorerKey      NVARCHAR( 15), 
   @cFacility       NVARCHAR( 5),  
   @cLOC            NVARCHAR( 10), 
   @cID             NVARCHAR( 18), 
   @cSKU            NVARCHAR( 20), 
   @nQTY            INT,  
   @cSuggestedLOC   NVARCHAR( 10),  
   @cFinalLOC       NVARCHAR( 10), 
   @cOption         NVARCHAR( 1), 
   @cExtendedInfo1  NVARCHAR( 20) OUTPUT
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
      IF @nAfterStep = 4  -- Suggest LOC, final LOC
      BEGIN
         DECLARE @nQty_QOH INT
         SET @nQty_QOH = 0
         
         SELECT @nQty_QOH = ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked), 0) 
         FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU
            AND LLI.LOC = @cSuggestedLOC
      
         SET @cExtendedInfo1 = 'QTY ON HAND: ' + CAST( @nQty_QOH AS NVARCHAR( 5))
      END
   END
   
Quit:
    
END

GO