SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_743ExtPASP03                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 11-Sep-2017 1.0  James    WMS2885. Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_743ExtPASP03] (
   @nMobile          INT,                  
   @nFunc            INT,                  
   @cLangCode        NVARCHAR( 3),         
   @cUserName        NVARCHAR( 18),        
   @cStorerKey       NVARCHAR( 15),        
   @cFacility        NVARCHAR( 5),          
   @cFromLOC         NVARCHAR( 10),        
   @cID              NVARCHAR( 18),        
   @cSuggLOC         NVARCHAR( 10) OUTPUT,  
   @cPickAndDropLOC  NVARCHAR( 10) OUTPUT,  
   @cFitCasesInAisle NVARCHAR( 1)  OUTPUT,  
   @nPABookingKey    INT           OUTPUT,  
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cSKUGrade      NVARCHAR( 18)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cPickZone      NVARCHAR( 10)
   

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_743ExtPASP03 -- For rollback or commit only our own transaction

   SET @cSuggLOC = ''

   IF EXISTS ( SELECT 1 FROM LOTxLOCxID LLI WITH (NOLOCK) 
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
               WHERE LLI.StorerKey = @cStorerKey
               AND   LLI.ID = @cID
               AND   LLI.LOC = @cFromLOC
               AND   LOC.Facility = @cFacility
               GROUP BY LLI.LOT
               HAVING COUNT( DISTINCT LA.Lottable01) > 1
               AND ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0)
   BEGIN
      SET @nErrNo = 114651
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Mix grade id'
      GOTO ROLLBACKTRAN
   END 

   IF EXISTS ( SELECT 1 
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LLI.LOT = LA.LOT
               WHERE LLI.StorerKey = @cStorerKey
               AND   LLI.ID = @cID
               AND   LLI.LOC = @cFromLOC
               AND   LOC.Facility = @cFacility   
               AND   ISNULL( LA.Lottable01, '') = ''
               GROUP BY LLI.LOT
               HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0)
   BEGIN
      SET @nErrNo = 114652
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv sku grade'
      GOTO ROLLBACKTRAN
   END 

   DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT LLI.Lot, LLI.SKU
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LLI.LOT = LA.LOT
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.ID = @cID
   AND   LLI.LOC = @cFromLOC
   AND   LOC.Facility = @cFacility
   GROUP BY LLI.Lot, LLI.SKU
   HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0
   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @cLot, @cSKU
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SELECT @cSKUGrade = Lottable01
      FROM dbo.LotAttribute WITH (NOLOCK)
      WHERE Lot = @cLOT

      IF @cSKUGrade = 'A'
      BEGIN
         -- If the SKU do not setup the pick face loc for Grade A 
         --(SKUXLOC.locationType = ÆPICKÆ, LOC.LocationType = ÆDYNPPICKÆ and LOC.LocationHandling=Æ3Æ and 
         --(LOC.Facility=RDT defaulted facility or fromloc.facility)), 
         --then show error: æNo Home locÆ, if setup pick face loc, then suggect this loc
         SELECT TOP 1 @cSuggLOC = SL.LOC
         FROM dbo.SKUxLOC SL WITH (NOLOCK) 
         JOIN LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
         WHERE SL.StorerKey = @cStorerKey
         AND   SL.SKU = @cSKU
         AND   SL.LocationType = 'PICK'
         AND   LOC.LocationType = 'DYNPPICK' 
         AND   LOC.LocationHandling = '3'
         AND   LOC.Facility = @cFacility
         ORDER BY LOC.LogicalLocation, loc.Loc
      END
      ELSE  -- @cSKUGrade = 'B'
      BEGIN
         -- Check if same sku already setup a home location for A grade product
         SELECT TOP 1 @cPickZone = LOC.PickZone 
         FROM dbo.SKUxLOC SL WITH (NOLOCK) 
         JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC 
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LLI.LOT = LA.LOT 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
         WHERE LLI.StorerKey = @cStorerKey
         AND   LLI.SKU = @cSKU
         AND   LA.LOTTABLE01 = 'A'
         AND   LOC.LocationHandling = '3'
         AND   LOC.Facility = @cFacility
         GROUP BY LOC.PickZone
         HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0
         ORDER BY 1

         IF ISNULL( @cPickZone, '') <> ''
            -- If same sku already setup a home location for A grade product 
            -- Then suggest an empty loc in the same pickzone with A grade product
            -- but locationhandling = '4'
            SELECT TOP 1 @cSuggLOC = LOC.LOC
            FROM dbo.LOC LOC WITH (NOLOCK) 
            LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
            AND   LOC.LocationType = 'DYNPPICK'
            AND   LOC.LocationHandling = '4'
            AND   LOC.PickZone = @cPickZone
            AND   NOT EXISTS ( SELECT 1 FROM dbo.SKUxLOC SL WITH (NOLOCK) WHERE SL.LOC = LOC.LOC AND SL.LocationType <> 'PICK')
            GROUP BY LOC.LogicalLocation, LOC.LOC
            -- Empty LOC
            HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) = 0 
            ORDER BY LOC.LogicalLocation, LOC.LOC

         IF ISNULL( @cSuggLOC, '') = ''
         BEGIN
            --check lotxlocxid if got LOC(LOC.LocationType = ÆDYNPPICKÆ and LOC.LocationHandling=Æ4Æ 
            --and LOC.Facility=RDT defaulted facility) for SKU+lottable01(B), if yes, suggest this loc
            SELECT TOP 1 @cSuggLOC = LLI.LOC
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

            IF ISNULL( @cSuggLOC, '') = ''
            BEGIN
               --check if got DPP loc for Grade B (SKUXLOC.locationType = ÆPICKÆ, LOC.LocationType=Æ DYNPPICKÆ 
               --and LOC.LocationHandling=Æ4Æ ), if yes, suggest this loc
               SELECT TOP 1 @cSuggLOC = SL.LOC
               FROM dbo.SKUxLOC SL WITH (NOLOCK) 
               JOIN LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
               WHERE SL.StorerKey = @cStorerKey
               AND   SL.SKU = @cSKU
               AND   SL.LocationType = 'PICK'
               AND   LOC.LocationType = 'DYNPPICK' 
               AND   LOC.LocationHandling = '4'
               AND   LOC.Facility = @cFacility
               ORDER BY LOC.LogicalLocation, loc.Loc

               IF ISNULL( @cSuggLOC, '') = ''
               BEGIN
                  --if no, RDT auto assign an empty loc(LOC.LocationType=ÆDYNPPICKÆ and LOC.LocationHandling=Æ4Æ 
                  --and lotxlocxid.Qty=0 and (LOC.Facility=RDT defaulted facility or fromloc.facility))
                  SELECT TOP 1 @cSuggLOC = LOC.LOC
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
      END

      IF ISNULL( @cSuggLOC, '') = ''
      BEGIN
         SET @nErrNo = 114653
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No home loc'
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP
         GOTO Quit
      END 
      BEGIN
         SET @nPABookingKey = 0
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cID
            ,@cSuggLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@cSKU
            ,@nPABookingKey = @nPABookingKey OUTPUT

         IF @nErrNo <> 0
         BEGIN
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP
            GOTO RollBackTran
         END
      END

      FETCH NEXT FROM CUR_LOOP INTO @cLot, @cSKU
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   GOTO Quit  
  
   ROLLBACKTRAN:  
      ROLLBACK TRAN rdt_743ExtPASP03  
  
   QUIT:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN
END

GO