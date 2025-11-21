SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_523ExtValidSP06                                 */  
/* Purpose: Check if qty to putaway + qty available on loc cannot over  */
/*          SKUxLOC.QtyLocationLimit                                    */  
/*                                                                      */
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2017-07-24 1.0  James     WMS9905. Created                           */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtValidSP06] (  
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

   DECLARE @nQtyAval    INT
   DECLARE @nQtyLocationLimit INT

   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 4
      BEGIN
         SELECT @nQtyLocationLimit = QtyLocationLimit,
                @nQtyAval = (QTY - QTYAllocated - QTYPicked )
         FROM dbo.SKUxLOC SL WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.Loc = LOC.Loc)
         WHERE SL.Sku = @cSKU
         AND   SL.Loc = @cSuggestedLOC
         AND   SL.StorerKey = @cStorerKey
         AND   LOC.Facility = @cFacility

         IF ( @nQty + ISNULL( @nQtyAval, 0)) > ISNULL( @nQtyLocationLimit, 0)
         BEGIN
            SET @nErrNo = 142251
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Over Loc Max
            GOTO Quit
         END
      END
   END
    
   QUIT:
 

GO