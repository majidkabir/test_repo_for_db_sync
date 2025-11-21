SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1764SwapUCC05                                         */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Swap ucc. Allow non ucc                                           */
/*                                                                            */
/* Called from:                                                               */
/*                                                                            */
/* Exceed version: 5.4                                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 2021-01-29  1.0  James       WMS-15656. Created                            */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764SwapUCC05]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cTaskdetailKey   NVARCHAR( 10),
   @cBarcode         NVARCHAR( 60),
   @cSKU             NVARCHAR( 20)  OUTPUT, 
   @cUCC             NVARCHAR( 20)  OUTPUT, 
   @nUCCQTY          INT            OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount      INT
   DECLARE @nTranCount     INT

   DECLARE @cActUCCNo      NVARCHAR( 20)
   DECLARE @cUCCSKU        NVARCHAR( 20)
   DECLARE @cUCCLOT        NVARCHAR( 10)
   DECLARE @cUCCLOC        NVARCHAR( 10)
   DECLARE @cUCCID         NVARCHAR( 18)
   DECLARE @cUCCStatus     NVARCHAR( 1)
   -- DECLARE @nUCCQTY        INT
   DECLARE @cUCCL01        NVARCHAR(18)
   DECLARE @cUCCL07        NVARCHAR(30)

   DECLARE @cStorerKey     NVARCHAR( 20)
   DECLARE @cTaskUCCNo     NVARCHAR( 20)
   DECLARE @cTaskUOM       NVARCHAR( 5)
   DECLARE @cTaskLOT       NVARCHAR( 10)
   DECLARE @cTaskLOC       NVARCHAR( 10)
   DECLARE @cTaskID        NVARCHAR( 18)
   DECLARE @cTaskSKU       NVARCHAR( 20)
   DECLARE @nTaskQTY       INT
   DECLARE @nTaskSystemQTY INT
   DECLARE @nTaskPendingMoveIn INT
   DECLARE @cTaskSuggestedLOC  NVARCHAR( 10)
   DECLARE @cTaskL01       NVARCHAR(18)
   DECLARE @cTaskL07       NVARCHAR(30)

   DECLARE @cActUOM        NVARCHAR( 5)
   DECLARE @cActTaskDetailKey NVARCHAR( 10)
   DECLARE @nActPendingMoveIn INT

   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nCartonNo      INT
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @cActPickSlipNo NVARCHAR( 10)
   DECLARE @nActCartonNo   INT
   DECLARE @cActLabelNo    NVARCHAR( 20)
   DECLARE @cActLabelLine  NVARCHAR( 5)

   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @nQTY           INT
   DECLARE @nIsMultiSKUUCC INT = 0
   DECLARE @curPD          CURSOR

   DECLARE @tTaskPD TABLE
   (
      PickDetailKey NVARCHAR( 10) NOT NULL,
      QTY           INT           NOT NULL
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )

   DECLARE @tActPD TABLE
   (
      PickDetailKey NVARCHAR( 10) NOT NULL,
      TaskDetailKey NVARCHAR( 10) NOT NULL,
      LOT           NVARCHAR( 10) NOT NULL,
      QTY           INT           NOT NULL
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )

   SET @nTranCount = @@TRANCOUNT
   SET @cActUCCNo = @cBarcode
   SET @cUCC = @cBarcode
   
   IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.LOC)
               WHERE TD.TaskDetailKey = @cTaskdetailKey
               AND   LOC.Putawayzone='LULUCP')
      GOTO Fail

   -- Check double scan
   IF EXISTS( SELECT 1 FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE UCCNo = @cActUCCNo)
   BEGIN
      SET @nErrNo = 163001
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
      GOTO Fail
   END

   -- Get task info
   SELECT
      @cStorerKey = StorerKey, 
      @cTaskUCCNo = CaseID,
      @cTaskUOM = UOM,
      @cTaskLOT = LOT,
      @cTaskLOC = FromLOC,
      @cTaskID = FromID,
      @cTaskSKU = SKU,
      @nTaskQTY = QTY,
      @nTaskSystemQTY = SystemQTY, 
      @nTaskPendingMoveIn = PendingMoveIn
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 163002
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadTaskDtlKey
      GOTO Fail
   END

   -- Get UCC record
   SELECT @nRowCount = COUNT( 1)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cActUCCNo
      AND StorerKey = @cStorerkey

   -- Check label scanned is UCC
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 163003
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not an UCC
      GOTO Fail
   END
   
   -- Check multi SKU UCC
   IF @nRowCount > 1
   BEGIN
      --SET @nErrNo = 163004
      --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi SKU UCC
      --GOTO Fail
      SET @nIsMultiSKUUCC = 1
   END
   
   -- Get scanned UCC info
   IF @nIsMultiSKUUCC = 0
      SELECT
         @cUCCSKU = SKU,
         @nUCCQTY = QTY,
         @cUCCLOT = LOT,
         @cUCCLOC = LOC,
         @cUCCID = ID,
         @cUCCStatus = Status
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @cActUCCNo
      AND   StorerKey = @cStorerkey
   ELSE
   BEGIN
      SELECT
         @cUCCLOC = LOC,
         @cUCCID = ID,
         @cUCCStatus = STATUS,
         @nUCCQTY = SUM( QTY)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @cActUCCNo
      AND   StorerKey = @cStorerkey
      GROUP BY LOC, Id, [Status]
      
      SELECT TOP 1 @cUCCSKU = SKU
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @cActUCCNo
      AND   StorerKey = @cStorerkey
   END
   
   DECLARE @cCode    NVARCHAR(10)
   DECLARE @cChkLoc  NVARCHAR(1)
   DECLARE @cChkID   NVARCHAR(1)
   DECLARE @cChkSKU  NVARCHAR(1)
   DECLARE @cChkL01  NVARCHAR(1)
   DECLARE @cChkL02  NVARCHAR(1)
   DECLARE @cChkL03  NVARCHAR(1)
   DECLARE @cChkL07  NVARCHAR(1)
   DECLARE @cTaskL02 NVARCHAR(18)
   DECLARE @cTaskL03 NVARCHAR(18)
   DECLARE @cUCCL02  NVARCHAR(18)
   DECLARE @cUCCL03  NVARCHAR(18)

   
   SET @cChkLoc = ''
   SET @cChkID = ''
   SET @cChkSKU = ''
   SET @cChkL01 = ''
   SET @cChkL02 = ''
   SET @cChkL03 = ''
   SET @cChkL07 = ''

   DECLARE CUR_CHK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT Code 
   FROM dbo.CODELKUP WITH (NOLOCK) 
   WHERE ListName = 'NKSDCTMRF' 
   AND StorerKey = @cStorerKey
   AND Short = '1'
   OPEN CUR_CHK
   FETCH NEXT FROM CUR_CHK INTO @cCode
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @cCode = 'LOC' SET @cChkLoc = '1'
      IF @cCode = 'ID'  SET @cChkID  = '1'
      IF @cCode = 'SKU' SET @cChkSKU = '1'
      IF @cCode = 'L01' SET @cChkL01 = '1'
      IF @cCode = 'L02' SET @cChkL02 = '1'
      IF @cCode = 'L03' SET @cChkL03 = '1'
      IF @cCode = 'L04' SET @cChkL07 = '1'

      FETCH NEXT FROM CUR_CHK INTO @cCode
   END
   CLOSE CUR_CHK
   DEALLOCATE CUR_CHK

   -- Check UCC status
   IF @cUCCStatus NOT IN ('1', '3')
   BEGIN
      SET @nErrNo = 163005
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad UCC Status
      GOTO Fail
   END

   -- Check UCC LOC match
   IF @cTaskLOC <> @cUCCLOC AND @cChkLoc = '1'
   BEGIN
      SET @nErrNo = 163006
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCLOCNotMatch
      GOTO Fail
   END

   -- Check UCC ID match
   IF @cTaskID <> @cUCCID AND @cChkID = '1'
   BEGIN
      SET @nErrNo = 163007
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCIDNotMatch
      GOTO Fail
   END

   -- Check UCC QTY match
   IF @nTaskQTY <> @nUCCQTY
   BEGIN
      SET @nErrNo = 163008
      SET @cErrMsg = @nUCCQTY--rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCQTYNotMatch
      GOTO Fail
   END

   IF @nIsMultiSKUUCC = 0
   BEGIN
      -- Check SKU match
      IF @cTaskSKU <> @cUCCSKU AND @cChkSKU = '1' 
      BEGIN
         SET @nErrNo = 163009
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCSKUNotMatch
         GOTO Fail
      END
   
      -- Get L07
      SELECT @cTaskL01 = Lottable01,
             @cTaskL02 = Lottable02,
             @cTaskL03 = Lottable03,
             @cTaskL07 = Lottable07
      FROM LotAttribute WITH (NOLOCK)
      WHERE LOT = @cTaskLOT

      SELECT @cUCCL01 = Lottable01,
             @cUCCL02 = Lottable02,
             @cUCCL03 = Lottable03,
             @cUCCL07 = Lottable07
      FROM LotAttribute WITH (NOLOCK)
      WHERE LOT = @cUCCLOT

      -- Check UCC L01 match (james01)
      IF @cTaskL01 <> @cUCCL01 AND @cChkL01 = '1'
      BEGIN
         SET @nErrNo = 163010
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCL01NotMatch
         GOTO Fail
      END

      -- Check UCC L01 match (james01)
      IF @cTaskL02 <> @cUCCL02 AND @cChkL02 = '1'
      BEGIN
         SET @nErrNo = 163011
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCL02NotMatch
         GOTO Fail
      END

      -- Check UCC L01 match (james01)
      IF @cTaskL03 <> @cUCCL03 AND @cChkL03 = '1'
      BEGIN
         SET @nErrNo = 163012
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCL03NotMatch
         GOTO Fail
      END

         -- Check UCC L07 match
      IF @cTaskL07 <> @cUCCL07 AND @cChkL07 = '1'
      BEGIN
         SET @nErrNo = 163013
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCL07NotMatch
         GOTO Fail
      END
   END
   
   -- Check UCC taken by other task
   IF EXISTS( SELECT TOP 1 1
      FROM UCC WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
      WHERE UCC.StorerKey = @cStorerkey
         AND PD.StorerKey = @cStorerkey
         AND UCC.UCCNo = @cActUCCNo
         AND PD.Status > '0'
         AND PD.QTY > 0)
   BEGIN
      SET @nErrNo = 163014
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCTookByOther
      GOTO Fail
   END


/*--------------------------------------------------------------------------------------------------

                                                Swap UCC

--------------------------------------------------------------------------------------------------*/
/*
   Scenario:
   1. UCC on own PickDetail      not swap
   2. UCC is not alloc           swap
   3. UCC on other PickDetail    swap
*/
   DECLARE @cUCCToBeSwap   NVARCHAR(20)
   DECLARE @cUCCToBeSwapStatus NVARCHAR(1)
   SET @cUCCToBeSwap = ''
   SET @cUCCToBeSwapStatus = ''

   BEGIN TRAN
   SAVE TRAN rdt_1764SwapUCC05

   -- 1. UCC on own PickDetail
   IF EXISTS( SELECT TOP 1 1 FROM PickDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey AND DropID = @cActUCCNo AND Status = '0' AND QTY > 0)
   BEGIN
/*
      -- Update PickDetail
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         Status = '3', -- Pick in-progress
         TrafficCop = NULL,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE TaskDetailKey = @cTaskDetailKey
         AND DropID = @cActUCCNo
         AND Status = '0'
         AND QTY > 0
*/
      -- Loop PickDetail
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey
         FROM PickDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey
            AND DropID = @cActUCCNo
            AND Status = '0'
            AND QTY > 0
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Update PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            Status = '3', -- Pick in-progress
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0 OR @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 163015
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END
      GOTO CommitTran
   END

   -- Get task's PickDetail
   INSERT INTO @tTaskPD (PickDetailKey, QTY)
   SELECT PD.PickDetailKey, PD.QTY
   FROM PickDetail PD WITH (NOLOCK)
   WHERE PD.TaskDetailKey = @cTaskDetailKey
      AND ((@nIsMultiSKUUCC = 1) OR (@nIsMultiSKUUCC = 0 AND PD.LOT = @cTaskLOT))
      AND PD.LOC = @cTaskLOC
      AND PD.ID = @cTaskID
      AND PD.DropID = @cTaskUCCNo
      AND PD.Status = '0'
      AND PD.QTY > 0

   -- Get task's PickDetail info
   SELECT @nQTY = ISNULL( SUM( QTY), 0) FROM @tTaskPD

   -- Get task's PackDetail
   SET @cPickSlipNo = ''
   IF @cTaskUOM = '2'
      SELECT
         @cPickSlipNo = PickSlipNo,
         @nCartonNo = CartonNo,
         @cLabelNo = LabelNo,
         @cLabelLine = LabelLine
      FROM PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerkey
         AND RefNo = @cTaskUCCNo


   -- Check PickDetail changed
   --IF @nQTY <> @nTaskSystemQTY
   IF @nQTY = 0
   BEGIN
      SET @nErrNo = 163016
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
      GOTO RollBackTran
   END

   -- 2. UCC is not allocated
   IF EXISTS( SELECT TOP 1 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @cStorerkey AND UCCNo = @cActUCCNo AND Status = '1')
   BEGIN
      -- Don't need to swap LOT
      IF @cTaskLOT = @cUCCLOT
      BEGIN
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cActUCCNo,
               Status = '3', -- Pick in-progress
               TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho = 'rdt.' + SUSER_SNAME()
            FROM dbo.PickDetail PD
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 163017
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
      END
      ELSE
      BEGIN
         -- Unallocate
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               QTY = 0,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Reallocate
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               Status = '3', -- Pick in-progress
               LOT = @cUCCLOT,
               DropID = @cActUCCNo,
               QTY = @nQTY,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END
      END

      -- Actual
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '3', -- 3=Allocated
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cActUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 163018
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      -- Task
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '1', -- 1=Received
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cTaskUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 163019
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      -- Task
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         CaseID = @cActUCCNo,
         LOT = @cUCCLOT,
         TrafficCop = NULL,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 163020
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END

      -- Booking
      IF @cTaskLOT <> @cUCCLOT
      BEGIN
         IF @nTaskPendingMoveIn > 0
         BEGIN
            SELECT @cTaskSuggestedLOC = SuggestedLOC FROM dbo.RFPutaway WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey 
            
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
               ,'' --FromLOC  
               ,'' --FromID  
               ,'' --SuggLOC  
               ,'' --Storer  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cTaskDetailKey = @cTaskDetailKey
            IF @nErrNo <> 0
               GOTO RollbackTran

            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'  
               ,@cTaskLOC --FromLOC  
               ,@cTaskID  --FromID  
               ,@cTaskSuggestedLOC --SuggLOC  
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cSKU = @cTaskSKU
               ,@nPutawayQTY = @nTaskQTY
               ,@cFromLOT = @cUCCLOT
               ,@cTaskDetailKey = @cTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
               GOTO RollbackTran
         END
      END

      -- Task
      IF @cPickSlipNo <> ''
      BEGIN
         UPDATE PackDetail SET
            RefNo = @cActUCCNo
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND LabelLine = @cLabelLine
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 163021
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail
            GOTO RollBackTran
         END
      END

      GOTO CommitTran
   END

   -- Get actual PickDetail
   INSERT INTO @tActPD (PickDetailKey, TaskDetailKey, LOT, QTY)
   SELECT PD.PickDetailKey, PD.TaskDetailKey, PD.LOT, PD.QTY
   FROM PickDetail PD WITH (NOLOCK)
      JOIN UCC WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
   WHERE UCC.StorerKey = @cStorerkey
      AND PD.StorerKey = @cStorerkey
      AND UCC.UCCNo = @cActUCCNo
      AND UCC.Status = '3'
      AND PD.Status = '0'
      AND PD.QTY > 0

   -- Get actual PickDetail info
   SET @nRowCount = @@ROWCOUNT
   SELECT @cActTaskDetailKey = TaskDetailKey FROM @tActPD

   -- Get actual task
   SELECT 
      @cActUOM = UOM, 
      @nActPendingMoveIn = PendingMoveIn
   FROM TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cActTaskDetailKey

   -- Get actual PackDetail
   SET @cActPickSlipNo = ''
   IF @cActUOM = '2'
      SELECT
         @cActPickSlipNo = PickSlipNo,
         @nActCartonNo = CartonNo,
         @cActLabelNo = LabelNo,
         @cActLabelLine = LabelLine
      FROM PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerkey
         AND RefNo = @cActUCCNo

   -- 3. UCC on other PickDetail
   IF @nRowCount > 0
   BEGIN
      -- Don't need to swap LOT
      IF @cTaskLOT = @cUCCLOT
      BEGIN
         -- Task
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cActUCCNo,
               Status = '3', -- Pick in-progress
               TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho = 'rdt.' + SUSER_SNAME()
            FROM dbo.PickDetail PD
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 163022
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Actual
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cTaskUCCNo,
               Status = '0',
               TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho = 'rdt.' + SUSER_SNAME()
            FROM dbo.PickDetail PD
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 163023
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
      END
      ELSE
      BEGIN
         -- Unallocate
         -- Task
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               QTY = 0,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Actual
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               QTY = 0,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Reallocate
         -- Task
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               Status = '3', -- Pick in-progress
               LOT = @cUCCLOT,
               DropID = @cActUCCNo,
               QTY = @nQTY,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END

         -- Actual
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               Status = '0',
               LOT = @cTaskLOT,
               DropID = @cTaskUCCNo,
               QTY = @nQTY,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END
      END

      -- Task
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         LOT = @cUCCLOT,
         CaseID = @cActUCCNo,
         TrafficCop = NULL,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 163024
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END

      -- Actual
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         LOT = @cTaskLOT,
         CaseID = @cTaskUCCNo,
         TrafficCop = NULL,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE TaskDetailKey = @cActTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 163025
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END

      -- Booking
      IF @cTaskLOT <> @cUCCLOT
      BEGIN
         IF @nTaskPendingMoveIn > 0
         BEGIN
            SELECT @cTaskSuggestedLOC = SuggestedLOC FROM dbo.RFPutaway WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey 
            
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
               ,'' --FromLOC  
               ,'' --FromID  
               ,'' --SuggLOC  
               ,'' --Storer  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cTaskDetailKey = @cTaskDetailKey
            IF @nErrNo <> 0
               GOTO RollbackTran

            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'  
               ,@cTaskLOC --FromLOC  
               ,@cTaskID  --FromID  
               ,@cTaskSuggestedLOC --SuggLOC  
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cSKU = @cTaskSKU
               ,@nPutawayQTY = @nTaskQTY
               ,@cFromLOT = @cUCCLOT
               ,@cTaskDetailKey = @cTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
               GOTO RollbackTran
         END

         IF @nActPendingMoveIn > 0
         BEGIN
            DECLARE @cActSuggestedLOC NVARCHAR( 10)
            SELECT @cActSuggestedLOC = SuggestedLOC FROM dbo.RFPutaway WITH (NOLOCK) WHERE TaskDetailKey = @cActTaskDetailKey 
            
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'  
               ,'' --FromLOC  
               ,'' --FromID  
               ,'' --SuggLOC  
               ,'' --Storer  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cTaskDetailKey = @cActTaskDetailKey  
            IF @nErrNo <> 0
               GOTO RollbackTran
               
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'  
               ,@cUCCLOC --FromLOC  
               ,@cUCCID  --FromID  
               ,@cActSuggestedLOC --SuggLOC  
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
               ,@cSKU = @cUCCSKU
               ,@nPutawayQTY = @nUCCQTY
               ,@cFromLOT = @cTaskLOT
               ,@cTaskDetailKey = @cActTaskDetailKey
               ,@nFunc = 0
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
               GOTO RollbackTran
         END
      END

      -- Task
      IF @cPickSlipNo <> ''
      BEGIN
         UPDATE PackDetail WITH (ROWLOCK) SET
            RefNo = @cActUCCNo
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND LabelLine = @cLabelLine
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 163026
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail
            GOTO RollBackTran
         END
      END

      -- Actual
      IF @cActPickSlipNo <> ''
      BEGIN
         UPDATE PackDetail WITH (ROWLOCK) SET
            RefNo = @cTaskUCCNo
         WHERE PickSlipNo = @cActPickSlipNo
            AND CartonNo = @nActCartonNo
            AND LabelNo = @cActLabelNo
            AND LabelLine = @cActLabelLine
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 163027
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail
            GOTO RollBackTran
         END
      END

      GOTO CommitTran
   END

   -- PickDetail not found
   SET @nErrNo = 132628
   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PKDtl Found
   GOTO RollBackTran

CommitTran:
   -- Log UCC swap
   IF @cTaskUCCNo <> @cActUCCNo
   BEGIN
      DECLARE @cTaskUCCStatus NVARCHAR(1)
      SELECT @cTaskUCCStatus = Status FROM UCC WITH (NOLOCK) WHERE UCCNo = @cTaskUCCNo AND StorerKey = @cStorerkey

      INSERT INTO rdt.SwapUCC (Func, UCC, NewUCC, ReplenGroup, UCCStatus, NewUCCStatus)
      VALUES (1764, @cTaskUCCNo, @cActUCCNo, @cTaskDetailKey, @cTaskUCCStatus, @cUCCStatus)
   END

   SET @cSKU = @cUCCSKU
   SET @nUCCQTY = @nUCCQTY
   SET @cUCC = @cActUCCNo

   COMMIT TRAN rdt_1764SwapUCC05
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764SwapUCC05
Fail:
   SET @nUCCQTY = 0 
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO