SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_898ExtUpd03                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Called from: rdtfnc_UCCReceive                                       */
/*              Release the pallet position after pallet closed         */
/*                                                                      */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 22-02-2017  1.0  James     WMS1073. Created                          */
/* 07-11-2019  1.1  James     Delete record from RDTTempUCC table       */
/*                            instead of update tasktype/status(james01)*/
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898ExtUpd03]
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
   
   DECLARE @cStorerKey     NVARCHAR( 15)
          ,@cPickMethod    NVARCHAR( 10)
          ,@cTaskDetailKey NVARCHAR( 10)
          ,@nInputKey      INT
          ,@nRowref        INT
          ,@nTranCount     INT

   SELECT @nInputKey = InputKey,
          @cStorerKey = StorerKey
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_898ExtUpd03 -- For rollback or commit only our own transaction

   IF @nStep = 12 -- Close pallet
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cOption NOT IN ('2', '3')
            GOTO Quit

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
                  SET @nErrNo = 106351
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FinalizeRDFail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
            END
         END
         ELSE 
         BEGIN
            SET @nErrNo = 106352
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No RD Finalize
            GOTO RollBackTran
         END

         IF @cOption = '3' -- Generate putaway task
         BEGIN
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
                  SET @nErrNo = 106353
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
                  SET @nErrNo = 106354
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
                  GOTO RollBackTran
               END
            END
         END

         -- Release pallet position
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT R.Rowref 
         FROM rdt.rdtTempUCC R WITH (NOLOCK)
         JOIN dbo.UCC U WITH (NOLOCK) ON ( R.UCCNo = U.UCCNo)
         WHERE U.StorerKey = @cStorerKey
         AND   U.ID = @cToID
         AND   U.Status = '1'
         AND   R.TaskType = '1'
         AND   R.PickSlipNo = @cReceiptKey
         OPEN CUR_LOOP
         FETCH NEXT FROM CUR_LOOP INTO @nRowref
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            DELETE FROM RDT.RDTTempUCC WHERE Rowref = @nRowref
            --UPDATE rdt.RDTTempUCC WITH (ROWLOCK) SET 
            --   TaskType = '9'
            --WHERE Rowref = @nRowref

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 106355
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close pallet err
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               GOTO RollBackTran
            END

            FETCH NEXT FROM CUR_LOOP INTO @nRowref
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP
      END
   END
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_898ExtUpd03 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO