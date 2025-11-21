SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_523ExtInfo05                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2020-12-15 1.0  James    WMS-15820. Created                          */
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_523ExtInfo05]    
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
   
   DECLARE @nQtyLocationLimit    INT
   DECLARE @nLLI_Qty             INT
   DECLARE @nLLI_QtyPicked       INT
   DECLARE @nLLI_PendingMoveIn   INT
   DECLARE @cPickLoc             NVARCHAR( 10)
   
   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
      IF @nAfterStep = 3  -- QTY PWY, QTY ACT
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
         
         SELECT @nLLI_Qty = ISNULL( SUM( Qty), 0),
                @nLLI_QtyPicked = ISNULL( SUM( QtyPicked), 0),
                @nLLI_PendingMoveIn = ISNULL( SUM( PendingMoveIN), 0)
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU
         AND   Loc = @cPickLoc

         SET @cExtendedInfo1 = 'Qty Loc Avail: ' +  
            CAST( @nQtyLocationLimit - ( @nLLI_Qty - @nLLI_QtyPicked + @nLLI_PendingMoveIn) AS NVARCHAR( 5))
      END
   END
   
Quit:
    
END

GO