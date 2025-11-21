SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP22                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 08-May-2017  1.0  James    WMS1862. Created                          */
/* 14-May-2017  1.1  James    WMS8863. Enhancement on getting suggested */
/*                            loc (james01)                             */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP22] (
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

   DECLARE @nTranCount           INT,
           @cLogicalLocation     NVARCHAR( 10),
           @cPAZone1             NVARCHAR( 20),
           @cPAZone2             NVARCHAR( 20),
           @cPAZone3             NVARCHAR( 20),
           @cPAZone4             NVARCHAR( 20),
           @cPAZone5             NVARCHAR( 20)
   
   DECLARE @cPalletType       NVARCHAR(15)  

   SELECT 
      @cPAZone1 = V_String13,
      @cPAZone2 = V_String14,
      @cPAZone3 = V_String15,
      @cPAZone4 = V_String16,
      @cPAZone5 = V_String17
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   CREATE TABLE #PAZone (
   RowRef  INT IDENTITY(1,1) NOT NULL,
   PAZone  NVARCHAR(10)  NULL)

   IF ISNULL( @cPAZone1, '') <> ''
      INSERT INTO #PAZone (PAZone) VALUES (@cPAZone1)

   IF ISNULL( @cPAZone2, '') <> ''
      INSERT INTO #PAZone (PAZone) VALUES (@cPAZone2)
   
   IF ISNULL( @cPAZone3, '') <> ''
      INSERT INTO #PAZone (PAZone) VALUES (@cPAZone3)

   IF ISNULL( @cPAZone4, '') <> ''
      INSERT INTO #PAZone (PAZone) VALUES (@cPAZone4)

   IF ISNULL( @cPAZone5, '') <> ''
      INSERT INTO #PAZone (PAZone) VALUES (@cPAZone5)

   -- Check blank putaway strategy
   IF NOT EXISTS ( SELECT 1 FROM #PAZone)
   BEGIN
      SET @nErrNo = 134151
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No PA Zone
      GOTO Quit
   END

   -- Half pallet type  
   IF LEFT( @cID, 2) = 'BT'  
      SET @cPalletType = 'HalfPallet'  
   ELSE
      SET @cPalletType = 'FullPallet'  

   SELECT TOP 1 @cSuggLOC = LOC.LOC, @cLogicalLocation = LOC.LogicalLocation
   FROM dbo.LOC LOC WITH (NOLOCK) 
   JOIN #PAZone PAZONE ON ( LOC.Putawayzone = PAZone.PAZone)
   LEFT OUTER JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
   AND   LOC.Locationflag <> 'HOLD'
   AND   LOC.Locationflag <> 'DAMAGE'
   AND   LOC.Status <> 'HOLD'
   AND   LOC.LOC <> @cFromLOC
   AND   ( ( @cPalletType = 'FullPallet' AND LOC.LocationHandling <> 'BT') OR 
           ( @cPalletType = 'HalfPallet' AND LOC.LocationHandling = 'BT'))
   GROUP BY LOC.LogicalLocation, LOC.LOC 
   -- Empty LOC (suggest LOC should refer to on Hand field not available field)
   --HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) = 0 
   HAVING ISNULL( SUM( LLI.Qty - LLI.QtyPicked), 0) = 0 
   ORDER BY LOC.LogicalLocation, LOC.Loc 

   -- Check suggest loc
   IF @cSuggLOC = ''
   BEGIN
      SET @nErrNo = 134152 -- No Suggest Loc
      GOTO Quit
   END
   
   -- Lock suggested location
   IF @cSuggLOC <> '' 
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP22 -- For rollback or commit only our own transaction
         
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
   
      COMMIT TRAN rdt_1819ExtPASP22 -- Only commit change made here
   END
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1819ExtPASP22 -- Only rollback change made here
   Fail:
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
END


GO