SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PutawayByDropID_Confirm                         */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Move Drop ID to LOC                                         */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2023-10-13  1.0  Ung      WMS-23390 Created                          */
/* 2024-01-22  1.1  Ung      WMS-24657 Fix dbo.sys.objects              */
/************************************************************************/

CREATE   PROC [rdt].[rdt_PutawayByDropID_Confirm] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),  
   @cDropID          NVARCHAR( 20), 
   @cSuggLOC         NVARCHAR( 10), 
   @cPickAndDropLOC  NVARCHAR( 10), 
   @cToLOC           NVARCHAR( 10), 
   @nPABookingKey    INT           OUTPUT, 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cConfirmSP  NVARCHAR( 20)

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get storer config
   SET @cConfirmSP = rdt.rdtGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''  

   /***********************************************************************************************
                                             Custom confirm
   ***********************************************************************************************/
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' + 
            ' @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nPABookingKey, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,                    ' +
            '@nFunc           INT,                    ' +
            '@cLangCode       NVARCHAR( 3),           ' +
            '@nStep           INT,                    ' +
            '@nInputKey       INT,                    ' +
            '@cStorerKey      NVARCHAR( 15),          ' +
            '@cFacility       NVARCHAR( 5),           ' + 
            '@cDropID         NVARCHAR( 20),          ' +
            '@cSuggLOC        NVARCHAR( 10),          ' +
            '@cPickAndDropLOC NVARCHAR( 10),          ' +
            '@cToLOC          NVARCHAR( 10),          ' +  
            '@nPABookingKey   INT,                    ' + 
            '@nErrNo          INT           OUTPUT,   ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT    '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
            @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nPABookingKey, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END
   
   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
   DECLARE @cMoveQTYAlloc NVARCHAR( 1)
   DECLARE @cMoveQTYPick  NVARCHAR( 1)
   DECLARE @cToID         NVARCHAR( 18)

   -- Storer config
   SET @cMoveQTYAlloc = rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cMoveQTYPick = rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)

   -- Get LoseID
   DECLARE @cLoseID NVARCHAR(1)
   SELECT @cLoseID = @cLoseID FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLOC

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PutawayByDropID_Confirm -- For rollback or commit only our own transaction

   -- Loop drop ID
   IF @cMoveQTYAlloc = '1' OR @cMoveQTYPick = '1'
   BEGIN
      DECLARE @cLOT        NVARCHAR( 10)
      DECLARE @cLOC        NVARCHAR( 10)
      DECLARE @cID         NVARCHAR( 18)
      DECLARE @cSKU        NVARCHAR( 20)
      DECLARE @nQTY        INT
      DECLARE @nQTYAlloc   INT
      DECLARE @nQTYPick    INT
      DECLARE @cStatus     NVARCHAR( 10)
      DECLARE @curPD       CURSOR
      
      SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT LOT, LOC, ID, SKU, QTY, Status 
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND DropID = @cDropID
            AND Status = '5'
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cLOT, @cLOC, @cID, @cSKU, @nQTY, @cStatus
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @cLoseID = '1'
            SET @cToID = ''
         ELSE
            SET @cToID = @cID
            
         IF @cStatus = '5'
         BEGIN
            SET @nQTYAlloc = 0
            SET @nQTYPick = @nQTY
         END
         ELSE
         BEGIN
            SET @nQTYAlloc = @nQTY
            SET @nQTYPick = 0
         END

         -- Execute move process
         EXECUTE rdt.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode, 
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
            @cSourceType = 'rdt_PutawayByDropID_Confirm', 
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility, 
            @cFromLOC    = @cLOC, 
            @cToLOC      = @cToLOC, 
            @cFromID     = @cID, 
            @cToID       = @cToID,  -- NULL means not changing ID
            @cSKU        = @cSKU, 
            @nQTY        = @nQTY, 
            @nQTYAlloc   = @nQTYAlloc,
            @nQTYPick    = @nQTYPick,
            @cDropID     = @cDropID, 
            @cFromLOT    = @cLOT, 
            @nFunc       = @nFunc
         IF @nErrNo <> 0
            GOTO RollBackTran
            
         FETCH NEXT FROM @curPD INTO @cLOT, @cLOC, @cID, @cSKU, @nQTY, @cStatus
      END
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

   COMMIT TRAN rdt_PutawayByDropID_Confirm -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PutawayByDropID_Confirm -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO