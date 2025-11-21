SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1762ExtUpd01                                    */
/* Purpose: TM Case Putaway, Extended Update for HK ANF                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-06-27   Ung       1.0   Created                                 */
/* 2014-08-25   Ung       1.1   SOS317842 Unlock PendingMoveIn          */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1762ExtUpd01]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cStorerKey      NVARCHAR( 15)
   DECLARE @cSKU            NVARCHAR( 20)
   DECLARE @cStatus         NVARCHAR( 10)
   DECLARE @cCaseID         NVARCHAR( 20)
   DECLARE @cToLOC          NVARCHAR( 10)
   DECLARE @cSourceType     NVARCHAR( 30)
   DECLARE @cTransferKey    NVARCHAR( 10)
   DECLARE @cTransferLineNo NVARCHAR( 5)
         , @cModuleName     NVARCHAR(30)
         , @cAlertMessage   NVARCHAR( 255)
         , @b_Success       INT

   -- Get task info
   SELECT
      @cStorerKey = StorerKey,
      @cSKU = SKU,
      @cStatus = Status,
      @cCaseID = CaseID,
      @cToLOC = ToLOC,
      @cSourceType = SourceType,
      @cTransferKey = LEFT( SourceKey, 10),
      @cTransferLineNo = SUBSTRING( SourceKey, 11, 5)
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1762ExtUpd01 -- For rollback or commit only our own transaction

   -- TM Replen From
   IF @nFunc = 1762
   BEGIN
      IF @nStep = 3 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Finalize transfer
            IF @cSourceType = 'RPF' AND @cCaseID <> '' AND @cStatus = '9'
            BEGIN
               IF EXISTS( SELECT TOP 1 1
                  FROM TransferDetail WITH (NOLOCK)
                  WHERE TransferKey = @cTransferKey
                     AND TransferLineNumber = @cTransferLineNo
                     AND FromStorerKey = @cStorerKey
                     AND UserDefine01 = @cCaseID
                     AND Status <> '9')
               BEGIN
                  -- Finalize TransferDetail
                  UPDATE TransferDetail SET
                     Status = '9',
                     ToLOC = @cToLOC, -- TM Case Putaway allow overwrite ToLOC
                     FromLoc = @cToLoc,
                     ToID    = '',
                     FromID  = '',
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE()
                  WHERE TransferKey = @cTransferKey
                     AND TransferLineNumber = @cTransferLineNo
                  SET @nErrNo = @@ERROR
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END
               END

               -- Unlock suggested location
               -- Note: cannot use rdt_Putaway_PendingMoveIn due to FromID changed
               IF EXISTS( SELECT TOP 1 1 FROM RFPutaway (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND CaseID = @cCaseID)
               BEGIN
                  DECLARE @cLOT NVARCHAR( 10)
                  DECLARE @cLOC NVARCHAR( 10)
                  DECLARE @cID  NVARCHAR( 18)
                  DECLARE @nQTY INT
                  DECLARE @nRowRef INT
                  DECLARE @curPending CURSOR

                  SET @curPending = CURSOR FOR
                     SELECT LOT, SuggestedLOC, QTY, RowRef
                     FROM dbo.RFPutaway WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND SKU = @cSKU
                        AND CaseID = @cCaseID
                        AND FromID = 'HOLD_001' -- Original ID
                  OPEN @curPending
                  FETCH NEXT FROM @curPending INTO @cLOT, @cLOC, @cID, @nQTY, @nRowRef

                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     IF EXISTS (SELECT 1
                        FROM dbo.LOTxLOCxID WITH (NOLOCK)
                        WHERE LOT = @cLOT
                        AND LOC = @cLOC
                        AND ID = @cID)
                     BEGIN  
                        UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET
                           PendingMoveIn = CASE WHEN PendingMoveIn - @nQTY >= 0 THEN PendingMoveIn - @nQTY ELSE 0 END
                        WHERE Lot = @cLOT
                           AND Loc = @cLOC
                           AND ID  = @cID
                        SET @nErrNo = @@ERROR
                        IF @nErrNo <> 0
                        BEGIN
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                           GOTO RollBackTran
                        END
                     END

                     DELETE dbo.RFPutaway WITH (ROWLOCK)
                     WHERE  RowRef = @nRowRef
                     SET @nErrNo = @@ERROR
                     IF @nErrNo <> 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curPending INTO @cLOT, @cLOC, @cID, @nQTY, @nRowRef
                  END
               END
            END
         END
      END

      IF @nStep = 5 -- Reason
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Finalize transfer
            IF @cSourceType = 'RPF' AND @cCaseID <> '' AND @cStatus = '9'
            BEGIN
               IF EXISTS( SELECT TOP 1 1
                  FROM TransferDetail WITH (NOLOCK)
                  WHERE TransferKey = @cTransferKey
                     AND TransferLineNumber = @cTransferLineNo
                     AND FromStorerKey = @cStorerKey
                     AND UserDefine01 = @cCaseID
                     AND Status <> '9')
               BEGIN
                  -- Finalize TransferDetail
                  UPDATE TransferDetail SET
                     Status = '9',
                     ToLOC = @cToLOC, -- TM Case Putaway allow overwrite ToLOC
                     FromLoc = @cToLoc,
                     ToID    = '',
                     FromID  = '',
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE()
                  WHERE TransferKey = @cTransferKey
                     AND TransferLineNumber = @cTransferLineNo
                  IF @@ERROR <> 0
                     GOTO RollBackTran
               END
            END
         END
      END

      /*
      IF NOT EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                 WHERE StorerKey = @cStorerKey
                 AND SUBSTRING(SourceKey,1,10)  = @cTransferKey
                 AND Status < '9' )
      BEGIN
             IF EXISTS ( SELECT 1 FROM TransferDetail WITH (NOLOCK)
                         WHERE TransferKey = @cTransferKey
                         AND Status < '9' )
             BEGIN
                -- Generate Supervisor Alert
                SELECT @cModuleName = 'PA'

                SET @cAlertMessage = 'Exception Occurs for Transfer. TransferKey : ' + @cTransferKey

                EXEC nspLogAlert
                        @c_modulename       = @cModuleName
                      , @c_AlertMessage     = @cAlertMessage
                      , @n_Severity         = '5'
                      , @b_success          = @b_success     OUTPUT
                      , @n_err              = @nErrNo        OUTPUT
                      , @c_errmsg           = @cErrMsg       OUTPUT
                      , @c_Activity	        = 'PA'
                      , @c_Storerkey	     = @cStorerKey
                      , @c_SKU	           = ''
                      , @c_UOM	           = ''
                      , @c_UOMQty	        = ''
                      , @c_Qty	           = 0
                      , @c_Lot	           = ''
                      , @c_Loc	           = ''
                      , @c_ID	              = ''
                      , @c_TaskDetailKey	  = ''
                      , @c_UCCNo	           = ''
             END
      END
      */
   END

   COMMIT TRAN rdt_1762ExtUpd01 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1762ExtUpd01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO