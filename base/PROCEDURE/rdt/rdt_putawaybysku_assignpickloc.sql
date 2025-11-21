SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PutawayBySKU_AssignPickLOC                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 07-12-2016  1.0  Ung      WMS-751 Created                            */
/************************************************************************/

CREATE PROC [RDT].[rdt_PutawayBySKU_AssignPickLOC] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerKey    NVARCHAR( 15), 
   @cFacility     NVARCHAR( 5), 
   @cSKU          NVARCHAR( 20), 
   @cSuggestedLOC NVARCHAR( 10), 
   @cFinalLOC     NVARCHAR( 10), 
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
   DECLARE @cFinalLOCFacility NVARCHAR( 5)
   DECLARE @cLocationType     NVARCHAR( 10)
   DECLARE @cLoseID           NVARCHAR( 1)

   SET @nTranCount = @@TRANCOUNT

   -- Get FinalLOC info
   SELECT
      @cFinalLOCFacility = Facility, 
      @cLocationType = LocationType,
      @cLoseID = LoseID
   FROM dbo.LOC WITH (NOLOCK)
   WHERE LOC = @cFinalLOC

	-- Check pick face exists  
   IF @cLocationType = 'PICK'
   BEGIN
   	IF EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cSuggestedLOC AND LocationType = 'PICK') AND @cSuggestedLOC <> @cFinalLOC
   	BEGIN
         SET @nErrNo = 103901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AldyHvPickLoc
         GOTO Quit
   	END
   END
   
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PutawayBySKU_AssignPickLOC -- For rollback or commit only our own transaction

   -- Check SKU has pick face setup in this facility
   IF NOT EXISTS( SELECT 1
      FROM dbo.SKUxLOC SL WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
      WHERE SL.StorerKey = @cStorerKey
         AND SL.SKU = @cSKU
         AND SL.LocationType IN ('CASE', 'PICK')
         AND LOC.Facility = @cFinalLOCFacility)
   BEGIN
      -- Set pick face LOC must loseID (checked in ntrSKUxLOCAdd)
      IF @cLoseID <> '1'
      BEGIN
         UPDATE LOC SET 
            LoseID = '1' 
         WHERE LOC = @cFinalLOC
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      IF EXISTS( SELECT 1 FROM dbo.SKUxLOC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND LOC = @cFinalLOC)
      BEGIN
         UPDATE SKUxLOC SET
            LocationType = 'PICK'
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND LOC = @cFinalLOC
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
      ELSE
      BEGIN
         INSERT INTO dbo.SKUxLOC (StorerKey, SKU, LOC, LocationType)
         VALUES (@cStorerKey, @cSKU, @cFinalLOC, 'PICK')
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
   END

   COMMIT TRAN rdt_PutawayBySKU_AssignPickLOC -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PutawayBySKU_AssignPickLOC -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO