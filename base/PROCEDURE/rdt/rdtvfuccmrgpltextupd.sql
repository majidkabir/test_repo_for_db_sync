SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtVFUCCMrgPltExtUpd                                */
/* Copyright: IDS                                                       */
/* Purpose: Customize checking for UCC merge pallet                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Ver  Author   Purposes                                    */
/* 2012-09-19 1.0  Ung      SOS256003 Created                           */
/* 2013-10-28 1.1  Shong    Performance Tuning                          */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFUCCMrgPltExtUpd]
   @nMobile      INT,
   @nFunc        INT,
   @nStep        INT,
   @cLangCode    NVARCHAR( 3), 
   @cStorerKey   NVARCHAR( 15), 
   @cLOC         NVARCHAR( 10), 
   @cFromID      NVARCHAR( 20), 
   @cToID        NVARCHAR( 20), 
   @cOption      NVARCHAR( 1),
   @cUCCNo       NVARCHAR( 20), 
   @nErrNo       INT  OUTPUT, 
   @cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT

   SET @nErrNo = 0
   SET @cErrMsg = ''
   
   IF (@nStep = 2 AND @cOption = '1') OR -- ToID. 1=Merge pallet, 2=No
       @nStep = 3                        -- UCC
   BEGIN
      -- Check From ID not close pallet
      IF NOT EXISTS (SELECT 1 FROM DropID WITH (NOLOCK) WHERE DropID = @cFromID AND Status = '9')
      BEGIN
         SET @nErrNo = 77101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FrIDNotClosePL
         GOTO Quit
      END
      
      -- Check To ID not close pallet
      IF NOT EXISTS (SELECT 1 FROM DropID WITH (NOLOCK) WHERE DropID = @cToID AND Status = '9')
      BEGIN
         SET @nErrNo = 77102
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToIDNotClosePL
         GOTO Quit
      END
      
      -- Check From ID contain multi SKU UCC
      IF EXISTS( SELECT 1 
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND LOC = @cLOC
            AND ID = @cFromID 
            AND Status = '1'
         GROUP BY UCCNo
         HAVING COUNT( 1) > 1)
      BEGIN
         SET @nErrNo = 77103
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FrID MixSKUUCC
         GOTO Quit
      END
      
      -- Check To ID contain multi SKU UCC
      IF EXISTS( SELECT 1 
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND LOC = @cLOC
            AND ID = @cToID 
            AND Status = '1'
         GROUP BY UCCNo
         HAVING COUNT( 1) > 1)
      BEGIN
         SET @nErrNo = 77104
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToID MixSKUUCC
         GOTO Quit
      END
      
      -- Merge by pallet
      IF @cUCCNo = '' 
      BEGIN
         -- Check FromID and ToID UCC with same SKU but different QTY
         IF EXISTS( SELECT 1 
            FROM dbo.UCC F WITH (NOLOCK) 
               JOIN dbo.UCC T WITH (NOLOCK) ON (F.SKU = T.SKU)
            WHERE F.StorerKey = @cStorerKey AND F.LOC = @cLOC AND F.ID = @cFromID
               AND T.StorerKey = @cStorerKey AND T.LOC = @cLOC AND T.ID = @cToID
               AND F.Status = '1'
               AND T.Status = '1'
               AND F.QTY <> T.QTY)
         BEGIN
            SET @nErrNo = 77105
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultipleUCCQty
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         -- Get UCC info
         DECLARE @nQTY INT
         DECLARE @cSKU NVARCHAR(20)
         SELECT 
            @cSKU = SKU, 
            @nQTY = QTY 
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE UCCNo = @cUCCNo
         
         -- Check ToID UCC with same SKU but different QTY
         IF EXISTS( SELECT 1 
            FROM dbo.UCC WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND LOC = @cLOC
               AND ID = @cToID 
               AND Status = '1'
               AND SKU = @cSKU
               AND QTY <> @nQTY)
         BEGIN
            SET @nErrNo = 77106
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultipleUCCQty
            GOTO Quit
         END
      END
   END
   
   IF (@nStep = 4 AND @cOption = '1') --Putaway ToID. 1=Yes, 2=No
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtVFUCCMrgPltExtUpd -- For rollback or commit only our own transaction

      -- Get pallet info
      DECLARE @cReceiptKey NVARCHAR(10)
      SET @cReceiptKey = ''
      SELECT @cReceiptKey = R.ReceiptKey  
      FROM dbo.Receipt R WITH (NOLOCK) 
         JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
      WHERE R.StorerKey = @cStorerKey
         AND RD.ToID = @cToID 
         AND RD.FinalizeFlag <> 'Y'
         AND RD.QTYReceived <> RD.BeforeReceivedQTY
      
      -- Finalize pallet
      IF @cReceiptKey <> ''
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
            UPDATE dbo.ReceiptDetail WITH (ROWLOCK) 
            SET
               FinalizeFlag = 'Y',
               QTYReceived = BeforeReceivedQTY, 
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()  
            WHERE ReceiptKey = @cReceiptKey
               AND ReceiptLineNumber = @cReceiptLineNumber
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 77107
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FinalizeRDFail
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curRD INTO @cReceiptLineNumber
         END
      END
      
      -- Generate putaway task
      IF NOT EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND TaskType = 'PAF' AND FromID = @cToID)
      BEGIN
         DECLARE @cTaskDetailKey NVARCHAR( 10)
         DECLARE @cPickMethod NVARCHAR(10)

         -- Get PickMethod (1 SKU 1 QTY = FP, the rest = PP)
         SET @cPickMethod = ''
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
            SET @nErrNo = 77108
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
            GOTO RollBackTran
         END

         -- Insert putaway task
         INSERT INTO TaskDetail (
            TaskDetailKey, Storerkey, TaskType, Fromloc, FromID, PickMethod, Status, Priority, SourcePriority, SourceType, SourceKey, TrafficCop)
         VALUES (
            @cTaskDetailKey, @cStorerKey, 'PAF', @cLOC, @cToID, @cPickMethod, '0', '5', '5', 'rdtVFUCCMrgPltExtUpd', @cReceiptKey, NULL)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 77109
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
            GOTO RollBackTran
         END
      END

      COMMIT TRAN rdtVFUCCMrgPltExtUpd -- Only commit change made here
   END

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdtVFUCCMrgPltExtUpd -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO