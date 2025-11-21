SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispANFRPFDecode                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Decode Label No Scanned                                     */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 24-01-2014  1.0  Ung         SOS296465 Created                       */
/* 20-06-2014  1.1  Ung         SOS314511 UCC hold by ID                */
/* 27-06-2014  1.2  Chee        Bug Fix - Update UCC.PickDetailKey for  */
/*                              pickdetail delete trigger (Chee01)      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispANFRPFDecode]
   @c_LabelNo          NVARCHAR(40),
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),
   @c_POKey            NVARCHAR(10),
	@c_LangCode	        NVARCHAR(3),
	@c_oFieled01        NVARCHAR(20) OUTPUT,
	@c_oFieled02        NVARCHAR(20) OUTPUT,
   @c_oFieled03        NVARCHAR(20) OUTPUT,
   @c_oFieled04        NVARCHAR(20) OUTPUT,
   @c_oFieled05        NVARCHAR(20) OUTPUT,
   @c_oFieled06        NVARCHAR(20) OUTPUT,
   @c_oFieled07        NVARCHAR(20) OUTPUT,
   @c_oFieled08        NVARCHAR(20) OUTPUT,
   @c_oFieled09        NVARCHAR(20) OUTPUT,
   @c_oFieled10        NVARCHAR(20) OUTPUT,
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT      OUTPUT,
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount      INT

   DECLARE @cUCCNo         NVARCHAR( 20)
   DECLARE @cUCCSKU        NVARCHAR( 20)
   DECLARE @cUCCLOT        NVARCHAR( 10)
   DECLARE @cUCCLOC        NVARCHAR( 10)
   DECLARE @cUCCID         NVARCHAR( 18)
   DECLARE @cUCCStatus     NVARCHAR( 1)
   DECLARE @nUCCQTY        INT

   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @cID            NVARCHAR( 18)
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @cCaseID        NVARCHAR( 20)
   DECLARE @cLoseUCC       NVARCHAR( 1)

   -- (Chee01)
   DECLARE
      @cUCCPickDetailKey        NVARCHAR(18),
      @cUCCOrderKey             NVARCHAR(10),
      @cUCCOrderLineNumber      NVARCHAR(5),
      @cPickDetailKeyToBeSwap   NVARCHAR(18),
      @cOrderKeyToBeSwap        NVARCHAR(10),
      @cOrderLineNumberToBeSwap NVARCHAR(5)

   SET @n_ErrNo = 0
   SET @c_ErrMsg = 0

   SET @cDropID = @c_oFieled09
   SET @cTaskDetailKey = @c_oFieled10

   -- Check double scan
   IF EXISTS( SELECT 1 FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE UCCNo = @c_LabelNo)
   BEGIN
      SET @n_ErrNo = 84551
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCC scanned
      RETURN
   END

   -- Get task info
   SELECT
      @cCaseID = CaseID,
      @cLOT = LOT,
      @cLOC = FromLOC,
      @cID = FromID
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ROWCOUNT = 0
   BEGIN
      SET @n_ErrNo = 84553
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --BadTaskDtlKey
      RETURN
   END

   -- Get LOC info
   SELECT @cLoseUCC = LoseUCC FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC

   IF @cLoseUCC = '1' -- DPP
   BEGIN
      SET @c_oFieled01 = @c_LabelNo -- SKU
      SET @c_oFieled05 = 0          -- UCC QTY
      SET @c_oFieled08 = ''         -- UCC QTY
      
      RETURN
   END
   ELSE
   BEGIN
      -- Get UCC record
      SELECT @nRowCount = COUNT( 1)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @c_LabelNo
         AND StorerKey = @c_Storerkey

      -- Check label scanned is UCC
      IF @nRowCount = 0
      BEGIN
         SET @c_oFieled01 = '' -- SKU
         SET @c_oFieled05 = 0  -- UCC QTY
         SET @c_oFieled08 = '' -- UCC QTY
   
         SET @n_ErrNo = 84569
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Not an UCC
         RETURN
      END
   END

   -- Check multi SKU UCC
   IF @nRowCount > 1
   BEGIN
      SET @n_ErrNo = 84552
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Multi SKU UCC
      RETURN
   END

   -- Get scanned UCC info
   SELECT
      @cUCCNo = UCCNo,
      @cUCCSKU = SKU,
      @nUCCQTY = QTY,
      @cUCCLOT = LOT,
      @cUCCLOC = LOC,
      @cUCCID = ID,
      @cUCCStatus = Status,
      @cUCCPickDetailKey   = PickDetailKey,   -- (Chee01)
      @cUCCOrderKey        = OrderKey,        -- (Chee01)
      @cUCCOrderLineNumber = OrderLineNumber  -- (Chee01)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @c_LabelNo
      AND StorerKey = @c_Storerkey

   -- Check UCC status
   IF @cUCCStatus NOT IN ('1', '3')
   BEGIN
      SET @n_ErrNo = 84554
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Bad UCC Status
      RETURN
   END

   -- Check UCC LOC match
   IF @cLOC <> @cUCCLOC
   BEGIN
      SET @n_ErrNo = 84555
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCLOCNotMatch
      RETURN
   END

   -- Check UCC ID match
   IF @cID <> @cUCCID
   BEGIN
      SET @n_ErrNo = 84556
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCIDNotMatch
      RETURN
   END

   -- Check UCC LOT match
   IF @cLOT <> @cUCCLOT
   BEGIN
      SET @n_ErrNo = 84557
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCLOTNotMatch
      RETURN
   END

   -- Get UCC hold by ID
   IF EXISTS( SELECT TOP 1 1 FROM InventoryHold WITH (NOLOCK) WHERE ID = @cUCCID AND ID <> '' AND Hold = '1')
   BEGIN
      IF @cCaseID = @c_LabelNo
      BEGIN
         SET @c_oFieled01 = @cUCCSKU
         SET @c_oFieled05 = @nUCCQTY
         SET @c_oFieled08 = @cUCCNo
      END
      ELSE
      BEGIN
         SET @n_ErrNo = 84570
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --HOLD UCC diff
      END
      RETURN
   END

   -- Get suggested UCC QTY
   DECLARE @nSuggQTY INT
   SELECT TOP 1
      @nSuggQTY = UCC.QTY
   FROM PickDetail PD WITH (NOLOCK)
      JOIN UCC WITH (NOLOCK) ON (PD.DropID = UCC.UCCNo)
   WHERE TaskDetailKey = @cTaskDetailKey
      AND PD.Status = '0'
      AND PD.QTY > 0
   ORDER BY PD.PickDetailKey

   -- Check UCC on task
   IF @@ROWCOUNT = 0
   BEGIN
      SET @n_ErrNo = 84558
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Over replenish
      RETURN
   END

   -- Check UCC QTY match
   IF @nSuggQTY <> @nUCCQTY
   BEGIN
      SET @n_ErrNo = 84559
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCQTYNotMatch
      RETURN
   END

   -- Check UCC taken by other task
   IF EXISTS( SELECT TOP 1 1
      FROM UCC WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
      WHERE UCC.StorerKey = @c_StorerKey
         AND PD.StorerKey = @c_StorerKey
         AND UCC.UCCNo = @cUCCNo
         AND PD.Status > '0'
         AND PD.QTY > 0)
   BEGIN
      SET @n_ErrNo = 84560
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCTookByOther
      RETURN
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
   DECLARE @cUCCToBeSwap NVARCHAR(20)
   DECLARE @cUCCToBeSwapStatus NVARCHAR(1)
   SET @cUCCToBeSwap = ''
   SET @cUCCToBeSwapStatus = ''

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdtANFRPFDecode

   -- 1. UCC on own PickDetail
   IF EXISTS( SELECT TOP 1 1 FROM PickDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey AND DropID = @cUCCNo AND Status = '0' AND QTY > 0)
   BEGIN
      -- Update PickDetail
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         Status = '3', -- Pick in-progress
         TrafficCop = NULL,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE TaskDetailKey = @cTaskDetailKey
         AND DropID = @cUCCNo
         AND Status = '0'
         AND QTY > 0
      IF @@ERROR <> 0 OR @@ROWCOUNT = 0
      BEGIN
         SET @n_ErrNo = 84561
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
         GOTO RollBackTran
      END
      GOTO CommitTran
   END

   -- Get UCC on PickDetail can be swap
   SELECT TOP 1
      @cUCCToBeSwap = UCC.UCCNo,
      @cUCCToBeSwapStatus = UCC.Status,
      @cPickDetailKeyToBeSwap   = PD.PickDetailKey,   -- (Chee01)
      @cOrderKeyToBeSwap        = PD.OrderKey,        -- (Chee01)
      @cOrderLineNumberToBeSwap = PD.OrderLineNumber  -- (Chee01)
   FROM PickDetail PD WITH (NOLOCK)
      JOIN UCC WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
   WHERE PD.TaskDetailKey = @cTaskDetailKey
      AND PD.Status = '0'
      AND PD.QTY > 0
      AND UCC.StorerKey = @c_StorerKey
      AND UCC.LOT = @cUCCLOT
      AND UCC.LOC = @cUCCLOC
      AND UCC.ID = @cUCCID
      AND UCC.QTY = @nUCCQTY
      AND UCC.Status IN ('1', '3')
   IF @cUCCToBeSwap = ''
   BEGIN
      SET @n_ErrNo = 84562
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --No UCC to Swap
      GOTO RollBackTran
   END

   -- 2. UCC is not allocated
   IF EXISTS( SELECT TOP 1 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @c_StorerKey AND UCCNo = @cUCCNo AND Status = '1')
   BEGIN
      -- Update PickDetail
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         DropID = @cUCCNo,
         Status = '3', -- Pick in-progress
         TrafficCop = NULL,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      FROM dbo.PickDetail PD
      WHERE TaskDetailKey = @cTaskDetailKey
         AND PD.DropID = @cUCCToBeSwap
      IF @@ERROR <> 0 OR @@ROWCOUNT = 0
      BEGIN
         SET @n_ErrNo = 84563
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
         GOTO RollBackTran
      END

      -- Update scanned UCC
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '3',
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME(),
         PickDetailKey   = @cPickDetailKeyToBeSwap,   -- (Chee01)
         OrderKey        = @cOrderKeyToBeSwap,        -- (Chee01)
         OrderLineNumber = @cOrderLineNumberToBeSwap  -- (Chee01)
      WHERE StorerKey = @c_StorerKey
         AND UCCNo = @cUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @n_ErrNo = 84564
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      -- Update UCC to be swap
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '1',
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME(),
         PickDetailKey   = '',  -- (Chee01)
         OrderKey        = '',  -- (Chee01)
         OrderLineNumber = ''   -- (Chee01)
      WHERE StorerKey = @c_StorerKey
         AND UCCNo = @cUCCToBeSwap
      IF @@ERROR <> 0
      BEGIN
         SET @n_ErrNo = 84565
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

--    -- Update TaskDetail.CaseID (Chee01)
--    UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
--       CaseID = @cUCCNo,
--       TrafficCop = NULL,
--       EditDate = GETDATE(),
--       EditWho = 'rdt.' + SUSER_SNAME()
--    WHERE CaseID = @cUCCToBeSwap
--      AND StorerKey = @c_StorerKey
--      AND TaskType = 'RPF'
--    IF @@ERROR <> 0
--    BEGIN
--       SET @n_ErrNo = 84572
--       SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD TKDtl Fail
--       GOTO RollBackTran
--    END

      GOTO CommitTran
   END

   -- 3. UCC on other PickDetail
   IF EXISTS( SELECT TOP 1 1
      FROM UCC WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
      WHERE UCC.StorerKey = @c_StorerKey
         AND PD.StorerKey = @c_StorerKey
         AND UCC.UCCNo = @cUCCNo
         AND UCC.Status = '3'
         AND PD.Status = '0'
         AND PD.QTY > 0)
   BEGIN
      -- Update PickDetail, swap UCC
      UPDATE PickDetail WITH (ROWLOCK) SET
         DropID =
            CASE WHEN DropID = @cUCCNo THEN @cUCCToBeSwap
                 WHEN DropID = @cUCCToBeSwap THEN @cUCCNo
            END,
         TrafficCop = NULL,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      FROM dbo.PickDetail
      WHERE StorerKey = @c_StorerKey
         AND DropID IN (@cUCCNo, @cUCCToBeSwap)
      IF @@ERROR <> 0 OR @@ROWCOUNT < 2
      BEGIN
         SET @n_ErrNo = 84566
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
         GOTO RollBackTran
      END

      -- Update PickDetail
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         Status = '3', -- Pick in-progress
         TrafficCop = NULL,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE TaskDetailKey = @cTaskDetailKey
         AND DropID = @cUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @n_ErrNo = 84567
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
         GOTO RollBackTran
      END

      -- Update UCC, swap PickDetailKey (Chee01)
      UPDATE UCC WITH (ROWLOCK) SET
         PickDetailKey =
            CASE WHEN PickDetailKey = @cUCCPickDetailKey THEN @cPickDetailKeyToBeSwap
                 WHEN PickDetailKey = @cPickDetailKeyToBeSwap THEN @cUCCPickDetailKey
            END,
         OrderKey =
            CASE WHEN OrderKey = @cUCCOrderKey THEN @cOrderKeyToBeSwap
                 WHEN OrderKey = @cOrderKeyToBeSwap THEN @cUCCOrderKey
            END,
         OrderLineNumber =
            CASE WHEN OrderLineNumber = @cUCCOrderLineNumber THEN @cOrderLineNumberToBeSwap
                 WHEN OrderLineNumber = @cOrderLineNumberToBeSwap THEN @cUCCOrderLineNumber
            END,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      FROM dbo.UCC
      WHERE StorerKey = @c_StorerKey
         AND UCCNo IN (@cUCCNo, @cUCCToBeSwap)
      IF @@ERROR <> 0
      BEGIN
         SET @n_ErrNo = 84571
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
         GOTO RollBackTran
      END

--    -- Update TaskDetail.CaseID (Chee01)
--    UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
--       CaseID =
--          CASE WHEN CaseID = @cUCCNo THEN @cUCCToBeSwap
--                 WHEN CaseID = @cUCCToBeSwap THEN @cUCCNo
--            END,
--       TrafficCop = NULL,
--       EditDate = GETDATE(),
--       EditWho = 'rdt.' + SUSER_SNAME()
--    WHERE CaseID IN (@cUCCNo, @cUCCToBeSwap)
--      AND StorerKey = @c_StorerKey
--      AND TaskType = 'RPF'
--    IF @@ERROR <> 0
--    BEGIN
--       SET @n_ErrNo = 84573
--       SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD TKDtl Fail
--       GOTO RollBackTran
--    END

      GOTO CommitTran
   END

   -- PickDetail not found
   SET @n_ErrNo = 84568
   SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --No PKDtl Found
   GOTO RollBackTran

CommitTran:
   -- Log UCC swap
   IF @cUCCToBeSwap <> ''
      INSERT INTO rdt.SwapUCC (Func, UCC, NewUCC, ReplenGroup, UCCStatus, NewUCCStatus)
      VALUES (1764, @cUCCToBeSwap, @cUCCNo, @cTaskDetailKey, @cUCCToBeSwapStatus, @cUCCStatus)

   SET @c_oFieled01 = @cUCCSKU
   SET @c_oFieled05 = @nUCCQTY
   SET @c_oFieled08 = @cUCCNo

   COMMIT TRAN rdtANFRPFDecode
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdtANFRPFDecode
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END -- End Procedure


GO