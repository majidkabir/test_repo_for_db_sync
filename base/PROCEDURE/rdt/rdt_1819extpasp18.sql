SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP18                                   */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 02-Aug-2018  1.0  ChewKP   WMS-5802 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP18] (
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
   DECLARE @cPutawayZone      NVARCHAR(10)
          ,@dLLILottable04    DATETIME
          ,@dLottable04       DATETIME
          ,@cSKU              NVARCHAR(20) 
  
    SELECT TOP 1 @dLottable04 = LA.Lottable04 
               ,@cSKU        = LLI.SKU 
   FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
   INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot AND LA.StorerKey = LLI.StorerKey 
   WHERE LLI.StorerKey = @cStorerKey 
   AND LLI.Loc = @cFromLOC
   AND LLI.ID  = @cID 
   AND LLI.QTY > 0 
   ORDER BY LA.Lottable04 DESC
   
   SELECT TOP 1 @dLLILottable04 = LA.Lottable04 
   FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
   INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot AND LA.StorerKey = LLI.StorerKey 
   WHERE LLI.StorerKey = @cStorerKey 
   AND LLI.SKU = @cSKU 
   AND LLI.Loc <> @cFromLOC
   AND LLI.ID  <> @cID 
   AND LLI.QTY > 0 
   ORDER BY LA.Lottable04 DESC
   
  
   
    IF @dLLILottable04 > @dLottable04
   BEGIN
      
      SELECT @cSuggLOC = Loc 
      FROM dbo.SKUxLOC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU 
      AND LocationType = 'PICK'
      
      IF ISNULL(@cSuggLOC,'')  = '' 
      BEGIN
         -- Suggest LOC
        EXEC @nErrNo = [dbo].[nspRDTPASTD]
           @c_userid          = 'RDT'
         , @c_storerkey       = @cStorerKey
         , @c_lot             = ''
         , @c_sku             = ''
         , @c_id              = @cID
         , @c_fromloc         = @cFromLOC
         , @n_qty             = 0
         , @c_uom             = '' -- not used
         , @c_packkey         = '' -- optional, if pass-in SKU
         , @n_putawaycapacity = 0
         , @c_final_toloc     = @cSuggLOC          OUTPUT
         , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT
         , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT

         -- Check suggest loc
         IF @cSuggLOC = ''
         BEGIN
            SET @nErrNo = -1
            GOTO Quit
         END
      END
      
      
   END
   ELSE
   BEGIN
       -- Suggest LOC
       EXEC @nErrNo = [dbo].[nspRDTPASTD]
           @c_userid          = 'RDT'
         , @c_storerkey       = @cStorerKey
         , @c_lot             = ''
         , @c_sku             = ''
         , @c_id              = @cID
         , @c_fromloc         = @cFromLOC
         , @n_qty             = 0
         , @c_uom             = '' -- not used
         , @c_packkey         = '' -- optional, if pass-in SKU
         , @n_putawaycapacity = 0
         , @c_final_toloc     = @cSuggLOC          OUTPUT
         , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT
         , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT

         -- Check suggest loc
         IF @cSuggLOC = ''
         BEGIN
            SET @nErrNo = -1
            GOTO Quit
         END
   END

   -- Lock suggested location
   IF @cSuggLOC <> '' 
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP18 -- For rollback or commit only our own transaction
      
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

      COMMIT TRAN rdt_1819ExtPASP18 -- Only commit change made here
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtPASP18 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END


GO