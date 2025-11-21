SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_523ExtValidSP10                                 */  
/*                                                                      */
/* Purpose: Validate Qty PWY cannot exceed home loc qty.                */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2020-12-15 1.0  James     WMS-15820. Created                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtValidSP10] (  
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

   DECLARE @nQtyLocationLimit    INT
   DECLARE @nLLI_Qty             INT
   DECLARE @nLLI_QtyPicked       INT
   DECLARE @nLLI_PendingMoveIn   INT
   DECLARE @nQtyLocAvail         INT
   DECLARE @cPickLoc             NVARCHAR( 10)
   
   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 3
      BEGIN
         SELECT TOP 1 @cPickLoc = Loc
         FROM dbo.SKUxLOC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   Sku = @cSKU
         AND   LocationType = 'PICK'
         ORDER BY 1
         
         SELECT @nQtyLocationLimit = QtyLocationLimit
         FROM dbo.SKUxLOC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU
         AND   Loc = @cPickLoc
         
         IF @nQty > @nQtyLocationLimit
         BEGIN
            SET @nErrNo = 161501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Qty Exceeded
            GOTO Quit
         END
            
         SELECT @nLLI_Qty = ISNULL( SUM( Qty), 0),
                @nLLI_QtyPicked = ISNULL( SUM( QtyPicked), 0),
                @nLLI_PendingMoveIn = ISNULL( SUM( PendingMoveIN), 0)
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU
         AND   Loc = @cPickLoc
         
         SET @nQtyLocAvail = @nQtyLocationLimit - ( @nLLI_Qty - @nLLI_QtyPicked + @nLLI_PendingMoveIn)
         
         IF @nQtyLocAvail > 0
         BEGIN
            IF @nQty > @nQtyLocAvail
            BEGIN
               SET @nErrNo = 161502
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Qty Exceeded
               GOTO Quit
            END
         END
      END
   END
    
   QUIT:
 

GO