SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP51                                   */
/* Created by :Vikas                                                    */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev      Author   Purposes                               */
/* 2024-3-4    1.0.0    VPA235   UWP-15946 Unliver VNA&PnD PA Strategy  */
/*                                                                      */
/*                                                                      */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1819ExtPASP51] (
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
   
   DECLARE @nTranCount       INT
   
   SET @cSuggLOC = ''
   SET @cPickAndDropLOC = ''
   
   -- Suggest LOC
   EXEC @nErrNo = [dbo].[nspRDTPASTD]
       @c_userid          = 'RDT'
      ,@c_storerkey       = @cStorerKey
      ,@c_lot             = ''
      ,@c_sku             = ''
      ,@c_id              = @cID
      ,@c_fromloc         = @cFromLOC
      ,@n_qty             = 0
      ,@c_uom             = '' -- not used
      ,@c_packkey         = '' -- optional, if pass-in SKU
      ,@n_putawaycapacity = 0
      ,@c_final_toloc     = @cSuggLOC          OUTPUT
      ,@c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT
      ,@c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT

   -- Check suggest loc
   IF @cSuggLOC = ''
   BEGIN
      SET @nErrNo = -1
      GOTO Quit
   END
   
   -- Lock suggested location
   IF @cSuggLOC <> '' 
   BEGIN
      -- Get LOC aisle
      DECLARE 
         @cLOCAisle  NVARCHAR(10),
         @cLOCCat    NVARCHAR(10),
         @cPAZone    NVARCHAR(10),
         @cPAPNDReq  NVARCHAR(10)

      SELECT 
         @cLOCAisle = LOCAisle
         ,@cLOCCat=LocationCategory
         ,@cPAZone =PutawayZone 
      FROM LOC WITH (NOLOCK) 
      WHERE LOC = @cSuggLOC

      -- Check PND Required
      SELECT TOP 1 
         @cPAPNDReq = Short 
      FROM CODELKUP WITH (NOLOCK) 
      WHERE Code = @cPAZone   -- Putaway Zone
        AND UDF01 = @cLOCCat   --LOC Category
        AND LISTNAME = 'PAPNDQREQ'
        AND code2 = @cFacility  
        AND (Storerkey  =@cStorerKey OR Storerkey='')                      
      
      IF @cPAPNDReq <> 1
      BEGIN
        SET @cPAPNDReq=0
      END
            
      -- Get PND
      SET @cPickAndDropLOC = ''
   /*
      SELECT TOP 1 @cPickAndDropLOC = Code
      FROM dbo.CodeLKUP C WITH (NOLOCK)
      WHERE C.ListName = 'PND'
         AND C.StorerKey = @cStorerKey
         AND C.Code2 = @cLOCAisle
         AND C.Short = 'IN'
   */
      SELECT TOP 1 @cPickAndDropLOC = LOC.LOC
      FROM LOC WITH (NOLOCK)
      WHERE 
         Facility = @cFacility
         AND LOCAisle = @cLOCAisle
         AND LocationCategory IN ('PND', 'PND_IN')
         AND NOT EXISTS( SELECT 1
                   FROM LOC L2 WITH (NOLOCK)
                   INNER JOIN LOTxLOCxID LLI WITH (NOLOCK) 
                      ON (LLI.LOC = L2.LOC
                      AND (LLI.LOC = L2.LOC AND (LLI.QTY > 0 OR LLI.PendingMoveIN > 0)))
                   WHERE LOC.LOC = L2.LOC
                      AND L2.Facility = @cFacility
                      AND L2.LOCAisle = @cLOCAisle
                      AND LocationCategory IN ('PND', 'PND_IN')
                   GROUP BY L2.LOC, L2.MaxPallet
                   HAVING COUNT(DISTINCT LLI.ID) >= L2.MaxPallet )
         ORDER BY LOC.PALogicalLoc, LOC.LOC

      IF @cPickAndDropLOC = '' AND @cPAPNDReq = 1
      BEGIN
        SET @nErrNo = 74204
        SET @cErrMsg = '74204 No PnD LOC'
        GOTO Quit
      END
   
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP51 -- For rollback or commit only our own transaction

      SET @nPABookingKey = 0
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

      COMMIT TRAN rdt_1819ExtPASP51 -- Only commit change made here
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtPASP51 -- Only rollback change made here

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO