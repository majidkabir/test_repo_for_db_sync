SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP01                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 09-06-2015  1.0  Ung      SOS336606. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP01] (
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
   DECLARE @cLOT             NVARCHAR(10)
   DECLARE @cLottable06      NVARCHAR(30)
   DECLARE @cShort           NVARCHAR(10)
   
   SET @cSuggLOC = ''
   SET @cPickAndDropLOC = ''
   
   -- Get ID info
   SELECT TOP 1 @cLOT = LOT FROM LOTxLOCxID WITH (NOLOCK) WHERE ID = @cID AND QTY > 0
   SELECT @cLottable06 = Lottable06 FROM LotAttribute WITH (NOLOCK) WHERE LOT = @cLOT
   
   -- Get BONDED/UNBONDED
   SELECT @cShort = Short
   FROM CodeLKUP WITH (NOLOCK)
	WHERE Listname = 'BONDFAC'
   	AND StorerKey = @cStorerKey
   	AND Code = @cLottable06

   -- BONDED will go into ASRS. Don't need to suggest induct-in location
   IF @cShort = 'BONDED'
      GOTO Quit
      
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

   -- Lock suggested location
   IF @cSuggLOC <> '' 
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP01 -- For rollback or commit only our own transaction
               
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

      COMMIT TRAN rdt_1819ExtPASP01 -- Only commit change made here
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtPASP01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO