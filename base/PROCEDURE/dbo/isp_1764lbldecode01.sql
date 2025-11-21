SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_1764LblDecode01                                 */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Decode UCC No Scanned in VNA                                */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 29-05-2017  1.0  Chew        WMS-1998 Created                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_1764LblDecode01]
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

   DECLARE @cActUCCNo      NVARCHAR( 20)
   DECLARE @cUCCSKU        NVARCHAR( 20)
   DECLARE @cUCCLOT        NVARCHAR( 10)
   DECLARE @cUCCLOC        NVARCHAR( 10)
   DECLARE @cUCCID         NVARCHAR( 18)
   DECLARE @cUCCStatus     NVARCHAR( 1)
   DECLARE @nUCCQTY        INT
   
   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cTaskUCCNo     NVARCHAR( 20)
   DECLARE @cTaskUOM       NVARCHAR( 5)
   DECLARE @cTaskLOT       NVARCHAR( 10)
   DECLARE @cTaskLOC       NVARCHAR( 10)
   DECLARE @cTaskID        NVARCHAR( 18)
   DECLARE @cTaskSKU       NVARCHAR( 20)
   DECLARE @nTaskQTY       INT
   DECLARE @nTaskSystemQTY INT
   DECLARE @cDropID        NVARCHAR(20)
   DECLARE @nQTY           INT
   
   DECLARE @tTaskPD TABLE
   (
      PickDetailKey NVARCHAR( 10) NOT NULL,
      QTY           INT           NOT NULL
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )

   SET @n_ErrNo = 0
   SET @c_ErrMsg = 0

   SET @cActUCCNo = @c_LabelNo
   SET @cTaskDetailKey = @c_oFieled10

   -- Check double scan
   IF EXISTS( SELECT 1 FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE UCCNo = @cActUCCNo)
   BEGIN
      SET @n_ErrNo = 110401
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCC scanned
      RETURN
   END

   -- Get task info
   SELECT
      @cTaskUCCNo = CaseID,
      @cTaskUOM = UOM, 
      @cTaskLOT = LOT,
      @cTaskLOC = FromLOC,
      @cTaskID = FromID, 
      @cTaskSKU = SKU, 
      @nTaskQTY = QTY, 
      @nTaskSystemQTY = SystemQTY
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   IF @@ROWCOUNT = 0
   BEGIN
      SET @n_ErrNo = 110402
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --BadTaskDtlKey
      RETURN
   END

   -- Get UCC record
   SELECT @nRowCount = COUNT( 1)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cActUCCNo
    AND StorerKey = @c_Storerkey

   -- Check label scanned is UCC
   IF @nRowCount = 0
   BEGIN
      SET @c_oFieled01 = '' -- SKU
      SET @c_oFieled05 = 0  -- UCC QTY
      SET @c_oFieled08 = '' -- UCC QTY

      SET @n_ErrNo = 110403
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Not an UCC
      RETURN
   END

   -- Check multi SKU UCC
   IF @nRowCount > 1
   BEGIN
      SET @n_ErrNo = 110404
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Multi SKU UCC
      RETURN
   END

   -- Get scanned UCC info
   SELECT
      @cUCCSKU = SKU,
      @nUCCQTY = QTY,
      @cUCCLOT = LOT,
      @cUCCLOC = LOC,
      @cUCCID = ID,
      @cUCCStatus = Status
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cActUCCNo
      AND StorerKey = @c_Storerkey

   -- Check UCC status
   IF @cUCCStatus NOT IN ('1', '3')
   BEGIN
      SET @n_ErrNo = 110405
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Bad UCC Status
      RETURN
   END

   -- Check UCC LOC match
   IF @cTaskLOC <> @cUCCLOC
   BEGIN
      SET @n_ErrNo = 110406
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCLOCNotMatch
      RETURN
   END

   -- Check UCC ID match
   IF @cTaskID <> @cUCCID
   BEGIN
      SET @n_ErrNo = 110407
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCIDNotMatch
      RETURN
   END
   
   -- Check UCC Lot match 
   IF @cTaskLot <> @cUCCLot 
   BEGIN
      SET @n_ErrNo = 110412
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCIDNotMatch
      RETURN
   END

   -- Check SKU match
   IF @cTaskSKU <> @cUCCSKU
   BEGIN
      SET @n_ErrNo = 110408
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCSKUNotMatch
      RETURN
   END

   -- Check UCC taken by other task
   IF EXISTS( SELECT TOP 1 1
      FROM UCC WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
      WHERE UCC.StorerKey = @c_StorerKey
         AND PD.StorerKey = @c_StorerKey
         AND UCC.UCCNo = @cActUCCNo
         AND PD.Status > '0'
         AND PD.QTY > 0 )
   BEGIN
      SET @n_ErrNo = 110409
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCTookByOther
      RETURN
   END

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN isp_1764LblDecode01

   -- 1. UCC on own PickDetail
   IF EXISTS( SELECT TOP 1 1 FROM PickDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey AND Status = '0' AND QTY > 0 )
   BEGIN
      -- Update PickDetail
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         --Status = '3', -- Pick in-progress
		   DropID = CASE WHEN DropID = '' THEN @cActUCCNo Else DropID END, -- Stamp UCCNo to PickDetail.DropID if empty
         TrafficCop = NULL,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE TaskDetailKey = @cTaskDetailKey
         AND Status = '0'
         AND QTY > 0
      IF @@ERROR <> 0 OR @@ROWCOUNT = 0
      BEGIN
         SET @n_ErrNo = 110410
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
         GOTO RollBackTran
      END
      --GOTO CommitTran
   END

/*
   -- Get task's PickDetail
   INSERT INTO @tTaskPD (PickDetailKey, QTY)
   SELECT PD.PickDetailKey, PD.QTY
   FROM PickDetail PD WITH (NOLOCK)
   WHERE PD.TaskDetailKey = @cTaskDetailKey
      AND PD.LOT = @cTaskLOT
      AND PD.LOC = @cTaskLOC
      AND PD.ID = @cTaskID
      AND PD.DropID = @cTaskUCCNo
      AND PD.Status = '0'
      AND PD.QTY > 0

   -- Get task's PickDetail info
   SELECT @nQTY = ISNULL( SUM( QTY), 0 ) FROM @tTaskPD

   -- Check PickDetail changed
   IF @nQTY <> @nTaskSystemQTY
   BEGIN
      SET @n_ErrNo = 110411
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --PKDtl changed
      GOTO RollBackTran
   END
*/   
   SET @c_oFieled01 = @cUCCSKU
   SET @c_oFieled05 = @nUCCQTY
   SET @c_oFieled08 = @cActUCCNo

   -- Get actual PickDetail info
   SET @nRowCount = @@ROWCOUNT

CommitTran:
   COMMIT TRAN isp_1764LblDecode01
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN isp_1764LblDecode01
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END -- End Procedure




 SET QUOTED_IDENTIFIER OFF

GO