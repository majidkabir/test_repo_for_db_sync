SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtVFUCCRcvExtUpdate                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Check UCC scan to ID have same SKU, QTY, L02                */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 12-09-2012  1.0  Ung       SOS255639. Created                        */
/* 2013-10-28  1.1  Shong     Performance Tuning                        */  
/* 2014-04-09  1.2  Ung       SOS308791 Add cross dock ASN              */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFUCCRcvExtUpdate]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cReceiptKey  NVARCHAR( 10)
   ,@cPOKey       NVARCHAR( 10)
   ,@cLOC         NVARCHAR( 10)
   ,@cToID        NVARCHAR( 18)
   ,@cLottable01  NVARCHAR( 18)
   ,@cLottable02  NVARCHAR( 18)
   ,@cLottable03  NVARCHAR( 18)
   ,@dLottable04  DATETIME
   ,@cUCC         NVARCHAR( 20)
   ,@cSKU         NVARCHAR( 20)
   ,@nQTY         INT
   ,@cParam1      NVARCHAR( 20) OUTPUT
   ,@cParam2      NVARCHAR( 20) OUTPUT
   ,@cParam3      NVARCHAR( 20) OUTPUT
   ,@cParam4      NVARCHAR( 20) OUTPUT
   ,@cParam5      NVARCHAR( 20) OUTPUT
   ,@cOption      NVARCHAR( 1)
   ,@nErrNo       INT       OUTPUT
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cUCCSKU        NVARCHAR( 20)
   DECLARE @nUCCQTY        INT
   DECLARE @nTranCount     INT
   
   SET @cUCCSKU = ''
   SET @nUCCQTY = 0

   -- Get Receipt info
   DECLARE @cDocType NVARCHAR(1)
   SELECT 
      @cStorerKey = StorerKey, 
      @cDocType = DocType
   FROM dbo.Receipt WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey
      
   IF @nStep = 3 -- To ID
   BEGIN
      IF @cDocType = 'A' AND LEFT( @cToID, 1) <> 'P'
      BEGIN
         SET @nErrNo = 81905
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid format
      END
   END

   IF @nStep = 12 -- Close pallet
   BEGIN
      IF @cDocType = 'X' AND @cOption = '3' -- Finalize and generate putaway task
      BEGIN
         SET @nErrNo = 81907
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not for XD ASN
         GOTO Quit
      END
      
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtVFUCCRcvExtUpdate -- For rollback or commit only our own transaction

      IF @cOption = '3' -- Finalize and generate putaway task
      BEGIN
         -- Finalize pallet
         IF EXISTS( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey 
               AND ToID = @cToID 
               AND FinalizeFlag <> 'Y'
               AND QTYReceived <> BeforeReceivedQTY)
         BEGIN
            -- Loop ReceiptDetail of pallet
            DECLARE @cReceiptLineNumber NVARCHAR(5)
            DECLARE @curRD CURSOR
            SET @curRD = CURSOR FOR 
               SELECT ReceiptLineNumber
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
                  AND ToID = @cToID
            OPEN @curRD
            FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Finalize ReceiptDetail
               UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET
                  FinalizeFlag = 'Y',
                  QTYReceived = BeforeReceivedQTY, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME() 
               WHERE ReceiptKey = @cReceiptKey
                  AND ReceiptLineNumber = @cReceiptLineNumber
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 81901
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FinalizeRDFail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
            END
         END
         ELSE 
         BEGIN
            SET @nErrNo = 81906
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No RD Finalize
            GOTO RollBackTran
         END
                  
         -- Generate putaway task
         IF NOT EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND TaskType = 'PAF' AND FromID = @cToID)
         BEGIN
            -- Get PickMethod (1 SKU 1 QTY = FP, the rest = PP)
            SELECT @cPickMethod = CASE WHEN COUNT( DISTINCT SKU) = 1 THEN 'FP' ELSE 'PP' END
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND ToID = @cToID
               AND BeforeReceivedQTY > 0
            IF @cPickMethod = 'FP'
               SELECT @cPickMethod = CASE WHEN COUNT( DISTINCT QTY) = 1 THEN 'FP' ELSE 'PP' END
               FROM dbo.UCC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey 
                  AND ReceiptKey = @cReceiptKey
                  AND LOC = @cLOC
                  AND ID = @cToID
               
            -- Get new TaskDetailKey
            DECLARE @nSuccess INT
         	SET @nSuccess = 1
         	EXECUTE dbo.nspg_getkey
         		'TASKDETAILKEY'
         		, 10
         		, @cTaskDetailKey OUTPUT
         		, @nSuccess       OUTPUT
         		, @nErrNo         OUTPUT
         		, @cErrMsg        OUTPUT
            IF @nSuccess <> 1
            BEGIN
               SET @nErrNo = 81902
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
               GOTO Fail
            END

            -- Insert putaway task
            INSERT INTO TaskDetail (
               TaskDetailKey, Storerkey, TaskType, Fromloc, FromID, PickMethod, Status, Priority, SourcePriority, SourceType, SourceKey, TrafficCop)
            VALUES (
               @cTaskDetailKey, @cStorerKey, 'PAF', @cLOC, @cToID, @cPickMethod, '0', '5', '5', 'rdtVFUCCRcvExtUpdate', @cReceiptKey, NULL)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 81903
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
               GOTO RollBackTran
            END
         END
      END

      -- Get pallet SKU
      SELECT TOP 1
         @cUCCSKU = SKU
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND ToID = @cToID

      -- Get UCC QTY
      SELECT TOP 1
         @nUCCQTY = QTY
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cUCCSKU
         AND ID = @cToID
         AND Status = '1'

      -- Delete rdtUCCSwapLog
      IF @cUCCSKU <> '' AND @nUCCQTY <> 0
      BEGIN
         -- Release the LOC
         DELETE rdt.rdtUCCSwapLog
         WHERE ReceiptKey = @cReceiptKey
            AND SKU = @cUCCSKU
            AND QTY = @nUCCQTY
            -- Check if any UCC swapped, assigned LOC, but not yet receive to pallet. If not found, then only release LOC
            AND NOT EXISTS( 
               SELECT TOP 1 1 FROM UCC WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
                  AND Status = '0' 
                  AND UserDefined05 = @cReceiptKey
                  AND UserDefined06 = rdt.rdtUCCSwapLog.LOC)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81904
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelSwapLogFail
            GOTO Quit
         END
      END

      COMMIT TRAN rdtVFUCCRcvExtUpdate -- Only commit change made here
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdtVFUCCRcvExtUpdate -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END -- End Procedure

GO