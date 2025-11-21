SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_CtnRcvSuggLoc01                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next SKU to Pack                                        */
/*                                                                      */
/* Called from: rdtfnc_SortAndPack                                      */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 14-Dec-2012 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_CtnRcvSuggLoc01] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @c_Storerkey               NVARCHAR( 15),
   @c_SKU                     NVARCHAR( 20),
   @c_ReceiptKey              NVARCHAR( 10),
   @c_FromLoc                 NVARCHAR( 10),
   @c_ToLoc                   NVARCHAR( 10),
   @c_FromID                  NVARCHAR( 18),
   @c_ToID                    NVARCHAR( 18),
   @n_QtyReceived             INT,
	@c_oFieled01               NVARCHAR( 20)      OUTPUT,
	@c_oFieled02               NVARCHAR( 20)      OUTPUT,
   @c_oFieled03               NVARCHAR( 20)      OUTPUT,
   @c_oFieled04               NVARCHAR( 20)      OUTPUT,
   @c_oFieled05               NVARCHAR( 20)      OUTPUT,
   @c_oFieled06               NVARCHAR( 20)      OUTPUT,
   @c_oFieled07               NVARCHAR( 20)      OUTPUT,
   @c_oFieled08               NVARCHAR( 20)      OUTPUT,
   @c_oFieled09               NVARCHAR( 20)      OUTPUT,
   @c_oFieled10               NVARCHAR( 20)      OUTPUT,
	@c_oFieled11               NVARCHAR( 20)      OUTPUT,
	@c_oFieled12               NVARCHAR( 20)      OUTPUT,
   @c_oFieled13               NVARCHAR( 20)      OUTPUT,
   @c_oFieled14               NVARCHAR( 20)      OUTPUT,
   @c_oFieled15               NVARCHAR( 20)      OUTPUT, 
   @bSuccess                  INT               OUTPUT,
   @nErrNo                    INT               OUTPUT,
   @cErrMsg                   NVARCHAR( 20)      OUTPUT   -- screen limitation, 20 char max

)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cFacility      NVARCHAR( 5), 
        @cSuggestedLoc  NVARCHAR( 10), 
        @nLoop          INT, 
        @nQty           INT 
/*
Suggest location logical:

Search the location with same SKU from all location and sort by available qty (qty - qtyallocated - qtypicked), location flag not in ('hold', 'damage'), Loc.HostWHCode ='RECEIVED'.
If the number of suggested location > 5, then only show first 5 locations on screen and sort by available qty. 
Rules:

	RDT allow user scan other location rather than suggested loc.
	Only find those locations with the same SKU that user scanned.
	All location in current Facility should be search, not only limit to pick location.
	Don't show empty location if any.
	If itÆs first time operation receiving one SKU, then the suggested loc will be blank.
	RDT donÆt consider those qty not yet finalize receipt, just search and show current inventory balance only.
	Still finalize on Exceed, RDT don't finalize automatically.
	Move the saving of ReceiptDetail to putaway suggest loc screen, after scanned toloc, system go back to SKU screen for next SKU receiving and putaway.
	Setup a RDT storerconfig and prompt option screen to alert RDT user when they keyed in or scanned loc wasn't one of 5 suggested location that RDT showed to avoid wrong scanning.
	If TolocÆs Loc.HostWHCode <>'RECEIVED', then prompt error message.

*/
   SELECT @cFacility = Facility 
   FROM rdt.rdtMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @nLoop = 1
   DECLARE @curLook4Loc CURSOR
   SET @curLook4Loc = CURSOR FOR 
   SELECT TOP 5 
          LOC.LOC, SUM(LLI.QTY - LLI.QTYAllocated - LLI.QtyPicked)
   FROM dbo.LOC LOC WITH (NOLOCK) 
      JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
   WHERE LOC.Facility = @cFacility
   AND   LOC.LocationFlag NOT IN ('HOLD', 'DAMAGE') 
   AND   LOC.HostWHCode IN ('RECEIVED', 'PUTAWAY')
   AND   LLI.StorerKey = @c_StorerKey
   AND   LLI.SKU = @c_SKU
   AND   (LLI.QTY - LLI.QTYAllocated - LLI.QtyPicked) > 0
   GROUP BY LOC.LOC
   ORDER BY 2 
   OPEN @curLook4Loc
   FETCH NEXT FROM @curLook4Loc INTO @cSuggestedLoc, @nQty
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @nLoop = 1
         SET @c_oFieled01 = @cSuggestedLoc
      IF @nLoop = 2
         SET @c_oFieled02 = @cSuggestedLoc
      IF @nLoop = 3
         SET @c_oFieled03 = @cSuggestedLoc
      IF @nLoop = 4
         SET @c_oFieled04 = @cSuggestedLoc
      IF @nLoop = 5
         SET @c_oFieled05 = @cSuggestedLoc
      IF @nLoop >= 5
         BREAK
      
      SET @nLoop = @nLoop + 1
      FETCH NEXT FROM @curLook4Loc INTO @cSuggestedLoc, @nQty
   END
   CLOSE @curLook4Loc
   DEALLOCATE @curLook4Loc
   
   -- If inventory is new then will return blank suggested loc
   -- Look in RD to find a fren
   IF ISNULL(@c_oFieled01, '') = ''
   BEGIN
      SELECT TOP 1 @cSuggestedLoc = ToLoc 
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey
      AND   ReceiptKey = @c_ReceiptKey
      AND   SKU = @c_SKU
      AND   BeforeReceivedQty > 0
      
      SET @c_oFieled01 = @cSuggestedLoc
   END
Quit:
END

GO