SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PutawayBySKU_Confirm                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 07-12-2016  1.0  Ung      WMS-751 Created                            */
/* 28-06-2019  1.1  James    WMS-9392 Add ExtendedPABySKUCfmSP (james01)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_PutawayBySKU_Confirm] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cUserName     NVARCHAR( 18), 
   @cStorerKey    NVARCHAR( 15), 
   @cFacility     NVARCHAR( 5), 
   @cLOT          NVARCHAR( 10), 
   @cLOC          NVARCHAR( 10), 
   @cID           NVARCHAR( 18), 
   @cSKU          NVARCHAR( 20), 
   @nQTY          INT, 
   @cFinalLOC     NVARCHAR( 10), 
   @cSuggestedLOC NVARCHAR( 10), 
   @cLabelType    NVARCHAR( 20), 
   @cUCC          NVARCHAR( 20), 
   @nPABookingKey INT           OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @tPABySKU       VariableTable
   DECLARE @cExtendedPABySKUCfmSP NVARCHAR(20)

   -- Get extended ExtendedPltBuildCfmSP
   SET @cExtendedPABySKUCfmSP = rdt.rdtGetConfig( @nFunc, 'ExtendedPABySKUCfmSP', @cStorerKey)
   IF @cExtendedPABySKUCfmSP = '0'
      SET @cExtendedPABySKUCfmSP = ''  

   -- Extended putaway
   IF @cExtendedPABySKUCfmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPABySKUCfmSP AND type = 'P')
      BEGIN
         INSERT INTO @tPABySKU (Variable, Value) VALUES 
            ('@cUserName',       @cUserName),
            ('@cLOT',            @cLOT),
            ('@cLOC',            @cLOC),
            ('@cID',             @cID),
            ('@cSKU',            @cSKU),
            ('@cQty',            CAST( @nQty AS NVARCHAR( 5))),
            ('@cFinalLOC',       @cFinalLOC) ,
            ('@cSuggestedLOC',   @cSuggestedLOC),
            ('@cLabelType',      @cLabelType),
            ('@cUCC',            @cUCC)

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPABySKUCfmSP) +
            ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @tPABySKU, @nPABookingKey OUTPUT,' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,                  ' +
            '@nFunc           INT,                  ' +
            '@cLangCode       NVARCHAR( 3),         ' +
            '@cStorerKey      NVARCHAR( 15),        ' +
            '@cFacility       NVARCHAR( 5),         ' + 
            '@tPABySKU        VariableTable READONLY, ' +
            '@nPABookingKey   INT           OUTPUT, ' +
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @tPABySKU, @nPABookingKey OUTPUT,
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Fail
      END
   END
   ELSE
   BEGIN
      DECLARE @cAutoAssignPickLOC NVARCHAR( 1)
      SET @cAutoAssignPickLOC = rdt.RDTGetConfig( @nFunc, 'AutoAssignPickLOC', @cStorerKey)

      -- Handling transaction
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_PutawayBySKU_Confirm -- For rollback or commit only our own transaction
   
      -- Auto assign pick location
      IF @cAutoAssignPickLOC = '1'
      BEGIN
         EXEC rdt.rdt_PutawayBySKU_AssignPickLOC @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, 
            @cSKU, 
            @cSuggestedLOC, 
            @cFinalLOC, 
            @nErrNo  OUTPUT, 
            @cErrMsg OUTPUT 
         IF @nErrNo <> 0 
            GOTO RollBackTran 
      END
   
      -- Execute putaway process
      EXEC rdt.rdt_Putaway @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility,
         @cLOT,
         @cLOC,
         @cID,
         @cStorerKey,
         @cSKU,
         @nQTY,
         @cFinalLOC,
         @cLabelType,   -- optional
         @cUCC,         -- optional
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      -- Unlock current session suggested LOC
      IF @nPABookingKey <> 0
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --FromLOC
            ,'' --FromID
            ,'' --SuggLOC
            ,'' --Storer
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0  
            GOTO RollBackTran
      
         SET @nPABookingKey = 0
      END

      COMMIT TRAN rdt_PutawayBySKU_Confirm -- Only commit change made here
      GOTO Quit

      RollBackTran:
         ROLLBACK TRAN rdt_PutawayBySKU_Confirm -- Only rollback change made here
      Quit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
      Fail:
   END
END

GO