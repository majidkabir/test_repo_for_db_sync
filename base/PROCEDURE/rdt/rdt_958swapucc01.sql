SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_958SwapUCC01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author    Purposes                                         */
/* 05-07-2022 1.0  Ung       WMS-19982 Created                                */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_958SwapUCC01]
   @nMobile            INT,
   @nFunc              INT,
   @cLangCode          NVARCHAR( 3),
   @nStep              INT,
   @nInputKey          INT,
   @cFacility          NVARCHAR( 5),
   @cStorerKey         NVARCHAR( 15),
   @cPickSlipNo        NVARCHAR( 20),
   @cLOC               NVARCHAR( 10),
   @cSuggSKU           NVARCHAR( 20),
   @nSuggQTY           INT,
   @cActUCCNo          NVARCHAR( 20),          
   @cTaskUCCNo         NVARCHAR( 20)  OUTPUT,
   @nErrNo             INT            OUTPUT,
   @cErrMsg            NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount      INT
   DECLARE @nTranCount     INT
   DECLARE @nQTY           INT

   DECLARE @cActPDKey      NVARCHAR( 10)
   DECLARE @cActOrderKey   NVARCHAR( 10)
   DECLARE @cActOrderLine  NVARCHAR( 10)
   DECLARE @cActUCCSKU     NVARCHAR( 20)
   DECLARE @cActUCCLOT     NVARCHAR( 10)
   DECLARE @cActUCCLOC     NVARCHAR( 10)
   DECLARE @cActUCCID      NVARCHAR( 18)
   DECLARE @cActUCCStatus  NVARCHAR( 1)
   DECLARE @nActUCCQTY     INT

   DECLARE @cTaskPDKey     NVARCHAR( 10)
   DECLARE @cTaskOrderKey  NVARCHAR( 10)
   DECLARE @cTaskOrderLine NVARCHAR( 10)
   DECLARE @cTaskSKU       NVARCHAR( 20)
   DECLARE @cTaskLOT       NVARCHAR( 10)
   DECLARE @cTaskLOC       NVARCHAR( 10)
   DECLARE @cTaskID        NVARCHAR( 18)
   DECLARE @nTaskQTY       INT

   SET @nTranCount = @@TRANCOUNT

/*
   Pick task:
   UCC to pick (with PickDetail.DropID = UCCNo)

   Actual UCC scanned:
   UCC free from alloc
   UCC with alloc

   All scenarios:
   0. UCC to pick = UCC taken, no swap
   1. UCC to pick, swap UCC free
   2. UCC to pick, swap UCC with alloc
*/

/*
   check alloc UCC LOT different from PickDetail.LOT
   check alloc UCC ID different from PickDetail.ID
*/


   -- 0. UCC to pick = UCC taken, no swap
   IF @cTaskUCCNo = @cActUCCNo
   BEGIN
      GOTO Quit
   END

   -- Get UCC record
   SELECT @nRowCount = COUNT( 1)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cActUCCNo
      AND StorerKey = @cStorerkey

   -- Check label scanned is UCC
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 188201
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not an UCC
      GOTO Fail
   END

   -- Check multi SKU UCC
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 188202
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi SKU UCC
      GOTO Fail
   END

   -- Get pick task info
   SELECT
      @cTaskPDKey = PickDetailKey,
      @cTaskOrderKey = OrderKey,
      @cTaskOrderLine = OrderLineNumber,
      @cTaskLOT = LOT,
      @cTaskLOC = LOC,
      @cTaskID = ID,
      @cTaskSKU = SKU,
      @nTaskQTY = QTY
   FROM dbo.PickDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerkey
      AND DropID = @cTaskUCCNo
      AND Status = '0'
      AND QTY > 0
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 188203
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad PickTask
      GOTO Fail
   END

   -- Get scanned UCC info
   SELECT
      @cActUCCSKU = SKU,
      @nActUCCQTY = QTY,
      @cActUCCLOT = LOT,
      @cActUCCLOC = LOC,
      @cActUCCID = ID,
      @cActUCCStatus = Status
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cActUCCNo
      AND StorerKey = @cStorerkey

   -- Check UCC status
   IF @cActUCCStatus NOT IN ('1', '3')
   BEGIN
      SET @nErrNo = 188204
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad UCC Status
      GOTO Fail
   END

   -- Check UCC LOC match
   IF @cTaskLOC <> @cActUCCLOC
   BEGIN
      SET @nErrNo = 188205
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCLOCNotMatch
      GOTO Fail
   END

   -- Check UCC ID match
   IF @cTaskID <> @cActUCCID
   BEGIN
      SET @nErrNo = 188219
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCIDNotMatch
      GOTO Fail
   END

   -- Check SKU match
   IF @cTaskSKU <> @cActUCCSKU
   BEGIN
      SET @nErrNo = 188206
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCSKUNotMatch
      GOTO Fail
   END

   -- Check UCC QTY match
   IF @nTaskQTY <> @nActUCCQTY
   BEGIN
      SET @nErrNo = 188207
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCQTYNotMatch
      GOTO Fail
   END

   -- Check UCC taken by other (PickDetail)
   IF EXISTS( SELECT TOP 1 1
      FROM UCC WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
      WHERE UCC.StorerKey = @cStorerkey
         AND PD.StorerKey = @cStorerkey
         AND UCC.UCCNo = @cActUCCNo
         AND PD.Status > '0'
         AND PD.QTY > 0)
   BEGIN
      SET @nErrNo = 188208
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCTookByOther
      GOTO Fail
   END


/*--------------------------------------------------------------------------------------------------

                                                Swap UCC

--------------------------------------------------------------------------------------------------*/
   DECLARE @cTaskUCCType   NVARCHAR(10) = 'PICK'
   DECLARE @cActUCCType    NVARCHAR(10)

   BEGIN TRAN
   SAVE TRAN rdt_958SwapUCC01

   -- Get actual UCC type
   SET @cActUCCType = ''
   IF @cActUCCStatus = '1'
      SET @cActUCCType = 'FREE'
   ELSE IF @cActUCCStatus = '3'
      SET @cActUCCType = 'PICK'

   -- Check actual UCC type
   IF @cActUCCType = ''
   BEGIN
      SET @nErrNo = 188209
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ActUCCTypeFail
      GOTO RollBackTran
   END

   -- 1. UCC to pick, swap UCC free
   IF @cTaskUCCType = 'PICK' AND @cActUCCType = 'FREE'
   BEGIN
      -- Don't need to swap LOT
      IF @cTaskLOT = @cActUCCLOT
      BEGIN
         -- Update PickDetail
         UPDATE dbo.PickDetail SET
            DropID = @cActUCCNo,
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         FROM dbo.PickDetail PD
         WHERE PickDetailKey = @cTaskPDKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- Unallocate
         UPDATE PickDetail SET
            QTY = 0,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cTaskPDKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END

         -- Reallocate
         UPDATE PickDetail SET
            LOT = @cActUCCLOT,
            DropID = @cActUCCNo,
            QTY = @nActUCCQTY,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cTaskPDKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END

      -- Actual
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '3', -- 3=Allocated
         OrderKey = @cTaskOrderKey,
         OrderLineNumber = @cTaskOrderLine,
         PickDetailKey = @cTaskPDKey,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cActUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 188210
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      -- Task
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '1', -- 1=Received
         OrderKey = '',
         OrderLineNumber = '',
         PickDetailKey = '',
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cTaskUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 188211
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      GOTO CommitTran
   END

   -- 2. UCC to pick, swap UCC with alloc
   ELSE IF @cTaskUCCType = 'PICK' AND @cActUCCType = 'PICK'
   BEGIN
      -- Get actual pick task info
      SELECT
         @cActPDKey = PickDetailKey,
         @cActOrderKey = OrderKey,
         @cActOrderLine = OrderLineNumber
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerkey
         AND DropID = @cActUCCNo
         AND Status = '0'
         AND QTY > 0
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 188212
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad PickTask
         GOTO Fail
      END

      -- Don't need to swap LOT
      IF @cTaskLOT = @cActUCCLOT
      BEGIN
         -- Task
         -- Update PickDetail
         UPDATE dbo.PickDetail SET
            DropID = @cActUCCNo,
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         FROM dbo.PickDetail PD
         WHERE PickDetailKey = @cTaskPDKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         -- Actual
         -- Update PickDetail
         UPDATE dbo.PickDetail SET
            DropID = @cTaskUCCNo,
            TrafficCop = NULL,
            EditDate = GETDATE(),
            EditWho = 'rdt.' + SUSER_SNAME()
         FROM dbo.PickDetail PD
         WHERE PickDetailKey = @cActPDKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- Unallocate
         -- Task
         UPDATE PickDetail SET
            QTY = 0,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cTaskPDKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END

         -- Actual
         UPDATE PickDetail SET
            QTY = 0,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cActPDKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END

         -- Reallocate
         -- Task
         UPDATE PickDetail SET
            LOT = @cActUCCLOT,
            DropID = @cActUCCNo,
            QTY = @nActUCCQTY,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cTaskPDKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END

         -- Actual
         UPDATE PickDetail SET
            LOT = @cTaskLOT,
            DropID = @cTaskUCCNo,
            QTY = @nTaskQTY,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cActPDKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END

      -- Actual
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '3', -- 3=Allocated
         OrderKey = @cTaskOrderKey,
         OrderLineNumber = @cTaskOrderLine,
         PickDetailKey = @cTaskPDKey,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cActUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 188213
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      -- Task
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '3', -- 3=Allocated
         OrderKey = @cActOrderKey,
         OrderLineNumber = @cActOrderLine,
         PickDetailKey = @cActPDKey,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cTaskUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 188214
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      GOTO CommitTran
   END

   -- Data error (not in the 3 scenarios)
   ELSE
   BEGIN
      SET @nErrNo = 188215
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Data error
      GOTO RollBackTran
   END

CommitTran:
   -- Log UCC swap
   IF @cTaskUCCNo <> @cActUCCNo
   BEGIN
      DECLARE @cTaskUCCStatus NVARCHAR(1)
      SELECT @cTaskUCCStatus = Status FROM UCC WITH (NOLOCK) WHERE UCCNo = @cTaskUCCNo AND StorerKey = @cStorerkey

      INSERT INTO rdt.SwapUCC (Func, UCC, NewUCC, ReplenGroup, UCCStatus, NewUCCStatus)
      VALUES (1764, @cTaskUCCNo, @cActUCCNo, @cTaskPDKey, @cTaskUCCStatus, @cActUCCStatus)
   END

   -- Successful swapped, return actual UCC
   SET @cTaskUCCNo = @cActUCCNo

   COMMIT TRAN rdt_958SwapUCC01
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_958SwapUCC01
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO