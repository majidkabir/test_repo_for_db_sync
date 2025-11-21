SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_523ExtValidSP08                                 */  
/* Purpose: Validate Final LOC.                                         */
/*          1. If SuggestedLOC = 'NONE', prompt error                   */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2017-02-10 1.0  Chermaine WMS-11813 Created                          */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_523ExtValidSP08] (  
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


DECLARE @lottable01  NVARCHAR( 20)

   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 4
      BEGIN
         IF @cSuggestedLOC = 'NONE'
         BEGIN
            SET @nErrNo = 111751
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Loc
            GOTO Quit
         END
         ELSE
         BEGIN
         	--if zoneCategory = 'NOMIXLOT01',Do not allow user to mix up lotattribute01
         	IF EXISTS ( SELECT TOP 1 1 FROM loc l (NOLOCK)
                        JOIN pickzone pz (NOLOCK) ON l.Facility = pz.facility AND l.PickZone = pz.PickZone
                        WHERE pz.zonecategory = 'NOMIXLOT01'
                        AND l.Facility = @cFacility
                        AND l.Loc = @cFinalLOC)
            BEGIN
            	--if not empty
            	IF NOT EXISTS (SELECT loc FROM lotxlocxid WHERE id = @cFromID AND sku = @cSKU AND loc = @cFinalLOC AND storerkey = @cStorerKey
            	GROUP BY Loc
      	      HAVING SUM((QTY - QtyAllocated - QtyPicked - QtyReplen - PendingMoveIN)) = 0 )
      	      BEGIN
      	      	DECLARE @cFinalLocLot01 NVARCHAR ( 20)
      	      	DECLARE @cFinalLocSKU   NVARCHAR ( 20)
      	      	DECLARE @cToPutLot01 NVARCHAR ( 20)
      	      	DECLARE @cToPutSKU   NVARCHAR ( 20)
      	      	
      	      	--FinalLoc storing which SKU  	      	
      	      	SELECT 
      	      	   @cFinalLocLot01 = la.Lottable01,
      	      	   @cFinalLocSKU = la.Sku
                  FROM lotxlocxid l (NOLOCK)
                  JOIN lotAttribute la (NOLOCK)
                  ON l.StorerKey = la.StorerKey AND l.Lot = la.Lot AND l.Sku = la.Sku
                  WHERE l.StorerKey = @cStorerKey
                  AND l.loc = @cFinalLOC
                  GROUP BY la.Lottable01,la.Sku
                  HAVING SUM((QTY - QtyAllocated - QtyPicked - QtyReplen - PendingMoveIN)) <> 0
                  
                  SELECT 
                     @cToPutLot01 = la.Lottable01,
                     @cToPutSKU = la.Sku
                  FROM lotxlocxid l (NOLOCK)
                  JOIN lotAttribute la (NOLOCK)
                  ON l.StorerKey = la.StorerKey
                  AND l.Lot = la.Lot
                  AND l.Sku = la.Sku
                  WHERE l.StorerKey = @cStorerKey
                  AND l.ID = @cFromID
                  AND l.Sku = @cSKU
                  AND l.loc = @cFinalLOC
                  
                  IF NOT ((@cFinalLocSKU = @cToPutSKU AND @cFinalLocLot01 = @cToPutLot01) OR (@cFinalLocSKU <> @cToPutSKU AND @cFinalLocLot01 <> @cToPutLot01))
                  BEGIN
      	      		SET @nErrNo = 148052
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DiffLottable01
                     GOTO Quit
      	      	END
      	      	--IF EXISTS (            	               	   
            	 --    SELECT * FROM (
              --          --search which lottable01 in FinalLoc
              --          SELECT la.Lottable01
              --          FROM lotxlocxid l (NOLOCK)
              --          JOIN lotAttribute la (NOLOCK)
              --          ON l.StorerKey = la.StorerKey AND l.Lot = la.Lot AND l.Sku = la.Sku
              --          WHERE l.StorerKey = @cStorerKey
              --          AND l.loc = @cFinalLOC
              --          GROUP BY la.Lottable01
              --          HAVING SUM((QTY - QtyAllocated - QtyPicked - QtyReplen - PendingMoveIN)) <> 0
            	 --    ) finalLot
              --      WHERE finalLot.Lottable01 NOT IN (
              --        	   --serch which lottable01 need to putaway
              --                SELECT la.Lottable01
              --                FROM lotxlocxid l (NOLOCK)
              --                JOIN lotAttribute la (NOLOCK)
              --                ON l.StorerKey = la.StorerKey
              --                AND l.Lot = la.Lot
              --                AND l.Sku = la.Sku
              --                WHERE l.StorerKey = @cStorerKey
              --                AND l.ID = @cFromID
              --                AND l.Sku = @cSKU
              --                AND l.loc = @cFinalLOC
              --      )
      	      	--)
      	      	
               END
            END
         END
      END
   END
    
   QUIT:
 

GO