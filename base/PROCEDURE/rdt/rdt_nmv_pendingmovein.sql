SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_NMV_PendingMoveIn                                     */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Update rdt.rdtNMV, to lock / unlock location                      */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 07-05-2014  1.0  Ung      SOS309834. Created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_NMV_PendingMoveIn] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cType            NVARCHAR( 10), -- LOCK / UNLOCK
   @cTaskDetailKey   NVARCHAR( 10),
   @cFromLOC         NVARCHAR( 10),
   @cFromID          NVARCHAR( 18),
   @cSuggestedLOC    NVARCHAR( 10),
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowRef INT

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_NMV_PendingMoveIn -- For rollback or commit only our own transaction

   IF @cType = 'LOCK'
   BEGIN
      -- Lock location
      INSERT INTO RFPutawayNMV (FromLOC, FromID, SuggestedLOC, TaskDetailKey)
      VALUES (@cFromLOC, @cFromID, @cSuggestedLOC, @cTaskDetailKey)
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         -- SET @nErrNo = 78101
         -- SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD NMV FAIL
        GOTO RollbackTran
      END
   END

   IF @cType = 'UNLOCK'
   BEGIN
      IF ISNULL( @cUserName    , '') = '' AND
         ISNULL( @cSuggestedLOC, '') = '' AND
         ISNULL( @cFromID      , '') = '' AND
         ISNULL( @cFromLOC     , '') = ''
      BEGIN
         SET @nErrNo = 88251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL ALL REC!!!
         GOTO RollBackTran
      END
      
      DECLARE @curNMV CURSOR
      SET @curNMV = CURSOR FOR
         SELECT RowRef
         FROM RFPutawayNMV WITH (NOLOCK)
         WHERE  AddWho        = CASE WHEN @cUserName = ''      THEN AddWho        ELSE @cUserName      END
            AND FromLOC       = CASE WHEN @cFromLOC = ''       THEN FromLOC       ELSE @cFromLOC       END 
            AND FromID        = CASE WHEN @cFromID = ''        THEN FromID        ELSE @cFromID        END 
            AND SuggestedLOC  = CASE WHEN @cSuggestedLOC = ''  THEN SuggestedLOC  ELSE @cSuggestedLOC  END
            AND TaskDetailKey = CASE WHEN @cTaskDetailKey = '' THEN TaskDetailKey ELSE @cTaskDetailKey END
      OPEN @curNMV
      FETCH NEXT FROM @curNMV INTO @nRowRef
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
         DELETE RFPutawayNMV WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 88251
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL NMV FAIL
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curNMV INTO @nRowRef
      END
   END

   COMMIT TRAN rdt_NMV_PendingMoveIn -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_NMV_PendingMoveIn -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO