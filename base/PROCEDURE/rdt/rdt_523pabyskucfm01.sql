SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523PABySKUCfm01                                 */
/*                                                                      */
/* Purpose: use suggested id as id to confirm putaway                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2019-06-27  1.0  James    WMS-9392 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_523PABySKUCfm01] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @tPABySKU        VariableTable READONLY,
   @nPABookingKey   INT           OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success INT
   DECLARE @c_outstring NVARCHAR( 255)

   DECLARE @cPA_StorerKey NVARCHAR( 15)
   DECLARE @cPA_SKU   NVARCHAR( 20)
   DECLARE @cPA_LOT   NVARCHAR( 10)
   DECLARE @nPA_QTY   INT
   DECLARE @cPackKey  NVARCHAR( 10)
   DECLARE @cPackUOM3 NVARCHAR( 10)

   DECLARE 
      @cUserName     NVARCHAR( 18), 
      @cLOT          NVARCHAR( 10), 
      @cLOC          NVARCHAR( 10), 
      @cID           NVARCHAR( 18), 
      @cSKU          NVARCHAR( 20), 
      @cQTY          NVARCHAR( 5), 
      @nQTY          INT, 
      @nPutawayQTY   INT, 
      @cFinalLOC     NVARCHAR( 10), 
      @cSuggestedLOC NVARCHAR( 10), 
      @cLabelType    NVARCHAR( 20), 
      @cUCC          NVARCHAR( 20),
      @cSuggID       NVARCHAR( 18)


   -- Variable mapping
   SELECT @cUserName = Value FROM @tPABySKU WHERE Variable = '@cUserName'
   SELECT @cLOT = Value FROM @tPABySKU WHERE Variable = '@cLOT'
   SELECT @cLOC = Value FROM @tPABySKU WHERE Variable = '@cLOC'
   SELECT @cID = Value FROM @tPABySKU WHERE Variable = '@cID'
   SELECT @cSKU = Value FROM @tPABySKU WHERE Variable = '@cSKU'
   SELECT @cQty = Value FROM @tPABySKU WHERE Variable = '@cQty'
   SELECT @cFinalLOC = Value FROM @tPABySKU WHERE Variable = '@cFinalLOC'
   SELECT @cSuggestedLOC = Value FROM @tPABySKU WHERE Variable = '@cSuggestedLOC'
   SELECT @cLabelType = Value FROM @tPABySKU WHERE Variable = '@cLabelType'
   SELECT @cUCC = Value FROM @tPABySKU WHERE Variable = '@cUCC'

   SET @nPutawayQTY = CAST( @cQty AS INT)

   SET @cSuggID = ''
   SELECT @cSuggID = ID 
   FROM dbo.RFPutaway WITH (NOLOCK) 
   WHERE SuggestedLOC = @cSuggestedLOC 
   AND   SKU = @cSKU
   AND   FromLoc = @cLOC
   AND   FromID = @cID
   AND   AddWho = @cUserName

   DECLARE @cAutoAssignPickLOC NVARCHAR( 1)
   SET @cAutoAssignPickLOC = rdt.RDTGetConfig( @nFunc, 'AutoAssignPickLOC', @cStorerKey)

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523PABySKUCfm01 -- For rollback or commit only our own transaction
   
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

   -- Get PackKey, UOM
   SELECT @cPackKey = PackKey FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   SELECT @cPackUOM3 = PackUOM3 FROM Pack WITH (NOLOCK) WHERE PackKey = @cPackKey
   
   DECLARE @curPutaway CURSOR 
   SET @curPutaway = CURSOR FOR
      SELECT 
         StorerKey, SKU, LOT, 
         (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END))
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = CASE WHEN @cStorerKey = '' THEN StorerKey ELSE @cStorerKey END
         AND SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END
         AND LOT = CASE WHEN @cLOT = '' THEN LOT ELSE @cLOT END
         AND LOC = @cLOC
         AND ID  = @cID
         AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0
      ORDER BY LOT

   OPEN @curPutaway
   FETCH NEXT FROM @curPutaway INTO @cPA_StorerKey, @cPA_SKU, @cPA_LOT, @nPA_QTY

   SET @nQTY = @nPutawayQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @nQTY < @nPA_QTY
         SET @nPA_QTY = @nQTY

      EXEC rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode, 
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
         @cSourceType = 'rdt_Putaway', 
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility, 
         @cFromLOC    = @cLOC, 
         @cToLOC      = @cFinalLOC, 
         @cFromID     = @cID,       -- NULL means not filter by ID. Blank is a valid ID
         @cToID       = @cSuggID,   -- NULL means not changing ID. Blank consider a valid ID
         @cSKU        = @cPA_SKU, 
         @nQTY        = @nPA_QTY, 
         @cFromLOT    = @cPA_LOT

      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @nQTY = @nQTY - @nPA_QTY
      IF @nQTY = 0
         BREAK
         
      FETCH NEXT FROM @curPutaway INTO @cPA_StorerKey, @cPA_SKU, @cPA_LOT, @nPA_QTY
   END
   CLOSE @curPutaway
   DEALLOCATE @curPutaway

   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '4', -- Putaway
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey,
      @cLocation     = @cLOC,
      @cToLocation   = @cFinalLOC,
      @cID           = @cID,
      @cToID         = @cSuggID,
      @cSKU          = @cSKU,
      @cUOM          = @cPackUOM3,
      @nQTY          = @nPutawayQTY,
      @cLOT          = @cLOT, 
      @cRefNo3       = @cUCC

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

   COMMIT TRAN rdt_523PABySKUCfm01 -- Only commit change made here
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_523PABySKUCfm01 -- Only rollback change made here
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
END

GO