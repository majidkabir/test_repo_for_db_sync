SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtPA08                                      */
/*                                                                      */
/* Purpose: Get suggested loc                                           */
/*                                                                      */
/* Called from: rdtfnc_PutawayBySKU                                     */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 11-Sep-2017  1.0  James    WMS1891. Created                          */
/* 28-Aug-2018  1.1  SPChin   INC0288601 - Enhancement                  */
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA08] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5), 
   @cLOC             NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cLOT             NVARCHAR( 10),
   @cUCC             NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQty             INT,          
   @cSuggestedLOC    NVARCHAR( 10) OUTPUT,  
   @nPABookingKey    INT           OUTPUT,  
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSKUGrade         NVARCHAR( 18),
           @cLogicalLocation  NVARCHAR( 10),
           @cPickZone         NVARCHAR( 10)

   SET @cSuggestedLOC = ''

   IF ISNULL( @cUCC, '') <> ''
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND   UCCNo = @cUCC
                      AND   [Status] = '1') 

      BEGIN
         SET @nErrNo = 114551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid uccno'
         GOTO Quit
      END  

      IF EXISTS ( SELECT 1 FROM dbo.UCC (NOLOCK) 
                  WHERE STORERKEY = @cStorerKey 
                  AND   UCCNo = @cUCC 
                  GROUP BY UCCNo 
                  HAVING COUNT( DISTINCT SKU) > 1)
      BEGIN
         SET @nErrNo = 114552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Mix sku ucc'
         GOTO Quit
      END 

      IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                      WHERE STORERKEY = @cStorerKey 
                      AND   UCCNo = @cUCC   
                      AND   SKU = @cSKU)
      BEGIN
         SET @nErrNo = 114553
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Uccsku x match'
         GOTO Quit
      END 

      IF EXISTS ( SELECT 1 FROM dbo.LotAttribute LA WITH (NOLOCK) 
                  JOIN dbo.UCC UCC WITH (NOLOCK) ON ( LA.LOT = UCC.LOT)
                  WHERE UCC.Storerkey = @cStorerKey 
                  AND   UCC.UCCNo = @cUCC
                  AND   UCC.Loc = @cLOC
                  GROUP BY LA.LOT
                  HAVING COUNT( DISTINCT LA.Lottable01) > 1)
      BEGIN
         SET @nErrNo = 114554
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Mix sku grade'
         GOTO Quit
      END 
   END

   SELECT @cSKUGrade = Lottable01
   FROM dbo.LotAttribute WITH (NOLOCK)
   WHERE Lot = @cLOT

   IF ISNULL( @cSKUGrade, '') = ''
   BEGIN
      SET @nErrNo = 114555
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv sku grade'
      GOTO Quit
   END 

   IF @cSKUGrade = 'A'
   BEGIN
      -- If the SKU do not setup the pick face loc for Grade A 
      --(SKUXLOC.locationType = ÆPICKÆ, LOC.LocationType = ÆDYNPPICKÆ and LOC.LocationHandling=Æ3Æ and 
      --(LOC.Facility=RDT defaulted facility or fromloc.facility)), 
   --then show error: æNo Home locÆ, if setup pick face loc, then suggect this loc
      SELECT TOP 1 @cSuggestedLOC = SL.LOC
      FROM dbo.SKUxLOC SL WITH (NOLOCK) 
      JOIN LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
      WHERE SL.StorerKey = @cStorerKey
      AND   SL.SKU = @cSKU
      AND   SL.LocationType = 'PICK'
      AND   LOC.LocationType = 'DYNPPICK' 
      AND   LOC.LocationHandling = '3'
      AND   LOC.Facility = @cFacility
      ORDER BY LOC.LogicalLocation, loc.Loc

      IF ISNULL( @cSuggestedLOC, '') = ''
      BEGIN
         SET @nErrNo = 114556
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No home loc'
         GOTO Quit
      END 
   END
   ELSE  -- @cSKUGrade = 'B'
   BEGIN
      --INC0288601 Exchange Search SuggestedLoc method
      --check if got DPP loc for Grade B (SKUXLOC.locationType = ÆPICKÆ, LOC.LocationType=Æ DYNPPICKÆ 
      --and LOC.LocationHandling=Æ4Æ ), if yes, suggest this loc
      SELECT TOP 1 @cSuggestedLOC = SL.LOC
      FROM dbo.SKUxLOC SL WITH (NOLOCK) 
      JOIN LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
      WHERE SL.StorerKey = @cStorerKey
      AND   SL.SKU = @cSKU
      AND   SL.LocationType = 'PICK'
      AND   LOC.LocationType = 'DYNPPICK' 
      AND   LOC.LocationHandling = '4'
      AND   LOC.Facility = @cFacility
      ORDER BY LOC.LogicalLocation, loc.Loc      

      IF ISNULL( @cSuggestedLOC, '') = ''
      BEGIN
         --INC0288601 Exchange Search SuggestedLoc method
         --check lotxlocxid if got LOC(LOC.LocationType = ÆDYNPPICKÆ and LOC.LocationHandling=Æ4Æ 
         --and LOC.Facility=RDT defaulted facility) for SKU+lottable01(B), if yes, suggest this loc
         SELECT TOP 1 @cSuggestedLOC = LLI.LOC
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
         WHERE LLI.StorerKey = @cStorerKey
         AND   LLI.SKU = @cSKU
         AND   LOC.LocationType = 'DYNPPICK' 
         AND   LOC.LocationHandling= '4'
         AND   LOC.Facility = @cFacility 
         AND   LA.Lottable01 = @cSKUGrade
         ORDER BY LOC.LogicalLocation, loc.Loc
      
         IF ISNULL( @cSuggestedLOC, '') = ''
         BEGIN
            --if no, RDT auto assign an empty loc(LOC.LocationType=ÆDYNPPICKÆ and LOC.LocationHandling=Æ4Æ 
            --and lotxlocxid.Qty=0 and (LOC.Facility=RDT defaulted facility or fromloc.facility))
            SELECT TOP 1 @cSuggestedLOC = LOC.LOC
            FROM dbo.LOC LOC WITH (NOLOCK) 
            LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
            AND   LOC.LocationType = 'DYNPPICK'
            AND   LOC.LocationHandling = '4'
            AND   NOT EXISTS ( SELECT 1 FROM dbo.SKUxLOC SL WITH (NOLOCK) WHERE SL.LOC = LOC.LOC AND SL.LocationType <> 'PICK')
            GROUP BY LOC.LogicalLocation, LOC.LOC
            -- Empty LOC
            HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) = 0 
            ORDER BY LOC.LogicalLocation, loc.Loc
         END
      END
   END

   IF ISNULL( @cSuggestedLOC, '') = ''
   BEGIN
      SET @nErrNo = 114557
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No suggest loc'
      GOTO Quit
   END 

   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   ELSE
   BEGIN
      -- Reserve the suggested loc
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cLOC
         ,@cID
         ,@cSuggestedLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU          = @cSKU
         ,@nPutawayQTY   = @nQTY
         ,@cFromLOT      = @cLOT
         ,@cUCCNo        = @cUCC
         ,@nPABookingKey = @nPABookingKey OUTPUT

      IF @nErrNo <> 0
         GOTO Quit
   END

   QUIT:

END

GO