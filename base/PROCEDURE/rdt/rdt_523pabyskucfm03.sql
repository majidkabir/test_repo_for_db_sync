SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523PABySKUCfm03                                 */
/*                                                                      */
/* Purpose: Swap LOT before move                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2020-05-23  1.0  Ung      WMS-12633 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_523PABySKUCfm03] (
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

   DECLARE @nTranCount  INT
   DECLARE @cSwapLOT    NVARCHAR( 1)
   DECLARE @cChkQuality NVARCHAR( 10)
   DECLARE @cITrnKey    NVARCHAR( 10)
   DECLARE @cLLI_LOT    NVARCHAR( 10)
   DECLARE @nLLI_QTY    INT
   DECLARE @nPA_QTY     INT

   DECLARE @cUserName   NVARCHAR( 18) 
   DECLARE @cLOT        NVARCHAR( 10)
   DECLARE @cLOC        NVARCHAR( 10)
   DECLARE @cID         NVARCHAR( 18)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nQTY        INT
   DECLARE @cFinalLOC   NVARCHAR( 10)
   DECLARE @cLabelType  NVARCHAR( 20) 
   DECLARE @cUCC        NVARCHAR( 20)
   
   -- Variable mapping
   SELECT @cUserName  = Value FROM @tPABySKU WHERE Variable = '@cUserName'
   SELECT @cLOT       = Value FROM @tPABySKU WHERE Variable = '@cLOT'
   SELECT @cLOC       = Value FROM @tPABySKU WHERE Variable = '@cLOC'
   SELECT @cID        = Value FROM @tPABySKU WHERE Variable = '@cID'
   SELECT @cSKU       = Value FROM @tPABySKU WHERE Variable = '@cSKU'
   SELECT @nQTY       = Value FROM @tPABySKU WHERE Variable = '@cQTY'
   SELECT @cFinalLOC  = Value FROM @tPABySKU WHERE Variable = '@cFinalLOC'
   SELECT @cLabelType = Value FROM @tPABySKU WHERE Variable = '@cLabelType'
   SELECT @cUCC       = Value FROM @tPABySKU WHERE Variable = '@cUCC'

   SET @nTranCount = @@TRANCOUNT

   -- Check move allowed 
   EXEC rdt.rdt_UAMoveCheck @nMobile, @nFunc, @cLangCode, 3, 1, @cStorerKey, @cFacility
      ,@cLOC 
      ,@cFinalLOC 
      ,'P' -- Type
      ,@cSwapLOT     OUTPUT
      ,@cChkQuality  OUTPUT
      ,@nErrNo       OUTPUT
      ,@cErrMsg      OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523PABySKUCfm03 -- For rollback or commit only our own transaction   

   -- Loop LLI
	DECLARE @curLLI CURSOR
	IF @cLOT = ''
		SET @curLLI = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
			SELECT LOT, (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END))
			FROM LOTxLOCxID WITH (NOLOCK)
			WHERE LOC = @cLOC
				AND ID = @cID
				AND StorerKey = @cStorerKey
				AND SKU = @cSKU
            AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0
   ELSE
		SET @curLLI = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
			SELECT LOT, (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END))
			FROM LOTxLOCxID WITH (NOLOCK)
			WHERE LOT = @cLOT
			   AND LOC = @cLOC
				AND ID = @cID
            AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0
   OPEN @curLLI
   FETCH NEXT FROM @curLLI INTO @cLLI_LOT, @nLLI_QTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Decide QTY to putaway
      IF @nQTY > @nLLI_QTY
         SET @nPA_QTY = @nLLI_QTY
      ELSE
         SET @nPA_QTY = @nQTY
      
      -- Swap lottables
      IF @cSwapLOT = '1'
      BEGIN
         EXEC rdt.rdt_UATransfer @nMobile, @nFunc, @cLangCode, 3, 1, @cStorerKey, @cFacility
            ,@cLOC
            ,@cID
            ,@cLLI_LOT
            ,@cSKU
            ,@nPA_QTY
            ,@cChkQuality
            ,@cITrnKey OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO RollbackTran
            
         -- Get new LOT
         SELECT @cLLI_LOT = LOT FROM ITrn WITH (NOLOCK)WHERE ITrnKey = @cITrnKey
      END
      
      -- Execute putaway process
      EXEC rdt.rdt_Putaway @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility,
         @cLLI_LOT,
         @cLOC,
         @cID,
         @cStorerKey,
         @cSKU,
         @nPA_QTY,
         @cFinalLOC,
         @cLabelType,   -- optional
         @cUCC,         -- optional
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran
      
      /*
      -- Execute move process
      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode, 
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
         @cSourceType = 'rdt_523PABySKUCfm03', 
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility, 
         @cFromLOC    = @cLOC, 
         @cToLOC      = @cFinalLOC, 
         @cFromID     = @cID, 
         @cToID       = NULL,  -- NULL means not changing ID
         @nFunc       = @nFunc,
         @cSKU        = @cSKU,
         @nQTY        = @nPA_QTY,
         @cFromLOT    = @cLLI_LOT
      IF @nErrNo <> 0
         GOTO RollBackTran
      */
      
      SET @nQTY = @nQTY - @nPA_QTY
      IF @nQTY = 0
         BREAK
   
      FETCH NEXT FROM @curLLI INTO @cLLI_LOT, @nLLI_QTY
   END

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

   COMMIT TRAN rdt_523PABySKUCfm03 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523PABySKUCfm03 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO