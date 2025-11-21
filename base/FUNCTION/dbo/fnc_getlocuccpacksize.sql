SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: fnc_GetLocUccPackSize                              */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 05-04-2012   Shong         Created                                   */
/* 26-07-2012   ChewKP        Get PackSize by favorable UCC (ChewKP01)  */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_GetLocUccPackSize](
   @cStorerKey   NVARCHAR( 15) = '',	
   @cSKU         NVARCHAR( 20), 
   @cLoc         NVARCHAR( 10)  
) RETURNS INT AS
BEGIN
	DECLARE @nNoOfPackSize  INT, 
	        @nPackSize      INT
	
	SET @nPackSize = 0 
	SET @nNoOfPackSize = 0
	
	SELECT @nNoOfPackSize = COUNT(DISTINCT UCC.Qty)
	FROM   UCC WITH (NOLOCK) 
	JOIN   LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.Lot = UCC.Lot AND
	       LOTxLOCxID.Loc = UCC.LOC   
	WHERE  UCC.StorerKey = @cStorerKey 
	AND    UCC.SKU = @cSKU 
	AND    UCC.LOC = @cLoc 
	AND    UCC.[STATUS] < '6' 
	AND    LOTxLOCxID.Qty > 0 
	 
	IF @nNoOfPackSize = 1
	BEGIN
		SELECT TOP 1 @nPackSize =  UCC.Qty 
		FROM   UCC WITH (NOLOCK) 
	   JOIN   LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.Lot = UCC.Lot AND
	          LOTxLOCxID.Loc = UCC.LOC   
	   WHERE  UCC.StorerKey = @cStorerKey 
	   AND    UCC.SKU = @cSKU 
	   AND    UCC.LOC = @cLoc 
	   AND    UCC.[STATUS] < '6' 
	   AND    LOTxLOCxID.Qty > 0  
	   GOTO RETURN_FNC
	END
	IF @nNoOfPackSize > 1
	BEGIN
	   SELECT TOP 1 @nPackSize =  UCC.Qty 
	   FROM   UCC WITH (NOLOCK) 
   	JOIN   LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.Lot = UCC.Lot AND
   	       LOTxLOCxID.Loc = UCC.LOC   
   	WHERE  UCC.StorerKey = @cStorerKey 
   	AND    UCC.SKU = @cSKU 
   	AND    UCC.LOC = @cLoc 
   	AND    UCC.[STATUS] < '6' 
   	AND    LOTxLOCxID.Qty > 0 
   	GROUP BY UCC.Qty -- (ChewKP01)
   	ORder By Count(UCC.UCCNo) desc -- (ChewKP01)
	   GOTO RETURN_FNC	
	END 
	IF @nNoOfPackSize = 0
	BEGIN
		SELECT TOP 1 @nPackSize =  UCC.Qty 
		FROM   UCC WITH (NOLOCK) 
	   JOIN   SKUxLOC WITH (NOLOCK) 
	       ON SKUxLOC.StorerKey = UCC.StorerKey AND 
	          SKUxLOC.SKU = UCC.SKU AND 
	          SKUxLOC.Loc = UCC.LOC   
	   WHERE  UCC.StorerKey = @cStorerKey 
	   AND    UCC.SKU = @cSKU 
	   AND    UCC.LOC = @cLoc 
	   AND    UCC.[STATUS] < '6' 	    
	   AND    SKUxLOC.Qty > 0 
		ORDER BY UCC.Qty   
	   GOTO RETURN_FNC	
	END 
	
	
	RETURN_FNC:
	RETURN @nPackSize 
END

GO