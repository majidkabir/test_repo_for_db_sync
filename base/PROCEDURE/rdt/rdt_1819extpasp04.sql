SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP04                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 19-01-2016  1.0  Ung      SOS361304 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP04] (
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
   DECLARE @cPalletType       NVARCHAR(10)
   DECLARE @cPAType           NVARCHAR(10)
   DECLARE @cPutawayZone      NVARCHAR(10)
   DECLARE @cPAStrategyKey    NVARCHAR(10)
   DECLARE @cSKU              NVARCHAR(20)
   DECLARE @cSUSR1            NVARCHAR(18)
   DECLARE @cCountryCode      NVARCHAR(10)
   DECLARE @nQTYPicked        INT
   DECLARE @cSuggPALogicalLOC NVARCHAR(10)

   SET @cSuggLOC = ''
   SET @cSuggPALogicalLOC = ''
   
   -- Get pallet info
   SELECT TOP 1 
      @cSKU = SKU, 
      @nQTYPicked = QTYPicked
   FROM LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
      AND LLI.LOC = @cFromLOC 
      AND LLI.ID = @cID 
      AND LLI.QTY > 0
   ORDER BY LLI.QTYPicked DESC

   -- Determine pallet type
   IF @nQTYPicked > 0
      SET @cPalletType = 'PACK&HOLD'
   ELSE 
      SET @cPalletType = 'NORMAL'

   -- Get SKU info
   SELECT 
      @cSUSR1 = SUSR1, 
      @cPutawayZone = PutawayZone
   FROM SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND SKU = @cSKU

   -- Outbound pallet (pack and hold)
   IF @cPalletType = 'PACK&HOLD'
   BEGIN
      -- Get putaway strategy
      DECLARE @cUDF01 NVARCHAR(10)
      DECLARE @cUDF02 NVARCHAR(10)
      DECLARE @cUDF03 NVARCHAR(10)
      DECLARE @cUDF04 NVARCHAR(10)
      DECLARE @cUDF05 NVARCHAR(10)
      DECLARE @tPutawayZone TABLE 
      (
         PutawayZone NVARCHAR(10) NOT NULL
      )
      
      -- Determine putaway type
      IF @cSUSR1 = 'HUB'
         SET @cPAType = 'P&H HUB'
      IF @cSUSR1 = 'IFC'
         SET @cPAType = 'P&H IFC'
         
      SELECT 
         @cUDF01 = LEFT( ISNULL( UDF01, ''), 10), 
         @cUDF02 = LEFT( ISNULL( UDF02, ''), 10), 
         @cUDF03 = LEFT( ISNULL( UDF03, ''), 10), 
         @cUDF04 = LEFT( ISNULL( UDF04, ''), 10), 
         @cUDF05 = LEFT( ISNULL( UDF05, ''), 10)
      FROM CodeLkup WITH (NOLOCK)
      WHERE ListName = 'RDTExtPA'
         AND Code = @cPAType
         AND StorerKey = @cStorerKey
      
      -- Build putawayzone table
      IF @cUDF01 <> '' INSERT INTO @tPutawayZone (PutawayZone) VALUES (@cUDF01)
      IF @cUDF02 <> '' INSERT INTO @tPutawayZone (PutawayZone) VALUES (@cUDF02)
      IF @cUDF03 <> '' INSERT INTO @tPutawayZone (PutawayZone) VALUES (@cUDF03)
      IF @cUDF04 <> '' INSERT INTO @tPutawayZone (PutawayZone) VALUES (@cUDF04)
      IF @cUDF05 <> '' INSERT INTO @tPutawayZone (PutawayZone) VALUES (@cUDF05)
      
      -- Get ship to
      SELECT TOP 1 
         @cCountryCode = O.M_ISOCntryCode
      FROM PickDetail PD WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE LOC.Facility = @cFacility
         AND PD.StorerKey = @cStorerKey
         AND PD.ID = @cID 
         AND PD.Status = '5'
         AND PD.QTY > 0

      -- Find a friend in Pack&Hold that fit MaxPallet
      IF @cSuggLOC = ''
         SELECT TOP 1 
            @cSuggLOC = LOC.LOC, 
            @cSuggPALogicalLOC = LOC.PALogicalLoc
         FROM PickDetail PD WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOT = PD.LOT AND LLI.LOC = PD.LOC AND LLI.ID = PD.ID)
            JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            JOIN @tPutawayZone t ON (t.PutawayZone = LOC.PutawayZone)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationCategory = 'PACK&HOLD'
            AND PD.StorerKey = @cStorerKey
            AND PD.Status = '5'
            AND PD.QTY > 0
            AND O.M_ISOCntryCode = @cCountryCode
         GROUP BY LOC.PALogicalLoc, LOC.LOC, LOC.MaxPallet
         HAVING LOC.MaxPallet > 0                           -- MaxPallet is setup
            AND COUNT( DISTINCT LLI.ID) < LOC.MaxPallet     -- Not yet reach MaxPallet
         ORDER BY LOC.PALogicalLoc, LOC.LOC
         
      IF @cSuggLOC = ''
      BEGIN
         -- Find a friend in Pack&Hold (first friend)
         SELECT TOP 1 
            @cSuggLOC = LOC.LOC, 
            @cSuggPALogicalLOC = LOC.PALogicalLoc
         FROM PickDetail PD WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            JOIN @tPutawayZone t ON (t.PutawayZone = LOC.PutawayZone)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationCategory = 'PACK&HOLD'
            AND PD.StorerKey = @cStorerKey
            AND PD.Status = '5'
            AND PD.QTY > 0
            AND O.M_ISOCntryCode = @cCountryCode
         ORDER BY LOC.PALogicalLoc, LOC.LOC
         
         -- Find empty LOC, after the friend
         SELECT TOP 1 @cSuggLOC = LOC.LOC
         FROM LOC WITH (NOLOCK)
            JOIN @tPutawayZone t ON (t.PutawayZone = LOC.PutawayZone)
            LEFT JOIN SKUxLOC SL WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LOC.LocationCategory = 'PACK&HOLD'
            AND ((LOC.PALogicalLOC > @cSuggPALogicalLOC)
              OR (LOC.PALogicalLOC = @cSuggPALogicalLOC AND LOC.LOC > @cSuggLOC))
         GROUP BY LOC.PALogicalLoc, LOC.LOC
         HAVING SUM( SL.QTY) = 0 OR SUM( SL.QTY) IS NULL
         ORDER BY LOC.PALogicalLoc, LOC.LOC
      END
   END
      
   -- Inbound pallet
   IF @cPalletType = 'NORMAL'
   BEGIN
      -- Determine putaway type
      IF @cSUSR1 = 'HUB'
         SET @cPAType = 'PALLET'
      IF @cSUSR1 = 'IFC'
      BEGIN
         IF @cPutawayZone = 'INT'    SET @cPAType = 'CASEINT'
         IF @cPutawayZone = 'NONINT' SET @cPAType = 'CASENON'
      END

      -- Get putaway strategy
      SELECT @cPAStrategyKey = ISNULL( Short, '')
      FROM CodeLkup WITH (NOLOCK)
      WHERE ListName = 'RDTExtPA'
         AND Code = @cPAType
         AND StorerKey = @cStorerKey
   
      -- Check blank putaway strategy
      IF @cPAStrategyKey = ''
      BEGIN
         SET @nErrNo = 59751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- StrategyNotSet
         GOTO Quit
      END
   
      -- Check putaway strategy valid
      IF NOT EXISTS( SELECT 1 FROM PutawayStrategy WITH (NOLOCK) WHERE PutawayStrategyKey = @cPAStrategyKey)
      BEGIN
         SET @nErrNo = 59752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- BadStrategyKey
         GOTO Quit
      END
      
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
         , @c_PAStrategyKey   = @cPAStrategyKey
         , @n_PABookingKey    = @nPABookingKey     OUTPUT

      -- Lock suggested location
      IF @cSuggLOC <> '' 
      BEGIN
         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_1819ExtPASP04 -- For rollback or commit only our own transaction
         
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
   
         COMMIT TRAN rdt_1819ExtPASP04 -- Only commit change made here
      END
   END
   
   IF @cSuggLOC = ''
   BEGIN
      SET @cPickAndDropLOC = ''
      SET @nErrNo = 59753
   END
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtPASP04 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO