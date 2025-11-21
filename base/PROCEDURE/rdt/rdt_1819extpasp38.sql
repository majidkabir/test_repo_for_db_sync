SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP38                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2022-03-15  1.0  yeekung    WMS-19197. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP38] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10)  OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT,
   @nPABookingKey    INT            OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cLOT              NVARCHAR( 10)
   DECLARE @cPutawayZone      NVARCHAR( 10)
   DECLARE @cHostWHCode       NVARCHAR( 10)
   DECLARE @cLocAisle         NVARCHAR( 10)
   DECLARE @cLocLevel         NVARCHAR( 10)
   DECLARE @cLoc              NVARCHAR( 10)

   SELECT TOP 1 @cSKU=SKU
   FROM LOTXLOCXID LLI (NOLOCK)
   JOIN LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LLI.LOC = @cFromLOC 
   AND   LLI.ID = @cID 
   AND   LLI.QTY > 0


   SELECT @cLocAisle=LOC.locAisle,
          @cLocLevel=LOC.loclevel
   FROM skuxloc SKULOC(Nolock)
   JOIN loc LOC(nolock) on LOC.loc=SKULOC.loc
   WHERE SKULOC.storerkey =@cStorerkey 
      AND SKULOC.sku =@cSKU 
      AND SKULOC.locationtype ='PICK'
   
   SET @cSuggLOC = ''

   DECLARE @cCurPickLoc CURSOR

   SET @cCurPickLoc = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
   SELECT LOC
   FROM LOC LOC WITH (NOLOCK) 
   WHERE LOC.Facility = @cFacility
   AND   LOC.LocLevel>=2
   AND   LOC.locaisle >= @cLocAisle
   ORDER BY Loc.loc,Loc.LocAisle

   OPEN @cCurPickLoc  
   FETCH NEXT FROM @cCurPickLoc INTO @cLoc  
   WHILE @@FETCH_STATUS = 0    
   BEGIN 
      IF NOT EXISTS(SELECT 1
                FROM SKUXLOC (NOLOCK)
                WHERE LOC=@cLoc
                AND storerkey=@cStorerkey
                AND QTY-QTYallocated-QtyPicked>0)
      BEGIN
         SET @cSuggLOC=@cLoc
         BREAK;
      END

      FETCH NEXT FROM @cCurPickLoc INTO @cLoc  
   END
   CLOSE @cCurPickLoc  
   DEALLOCATE @cCurPickLoc
      

   -- Lock suggested location
   IF @cSuggLOC <> '' 
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP38 -- For rollback or commit only our own transaction
      
      IF @cFitCasesInAisle <> 'Y'
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cID
            ,@cSuggLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      -- Lock PND location
      IF @cPickAndDropLOC <> ''
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cID
            ,@cPickAndDropLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      COMMIT TRAN rdt_1819ExtPASP38 -- Only commit change made here
      
      GOTO Quit

      RollBackTran:
         ROLLBACK TRAN rdt_1819ExtPASP38 -- Only rollback change made here
      Quit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
   END
   
   Fail:

END

GO