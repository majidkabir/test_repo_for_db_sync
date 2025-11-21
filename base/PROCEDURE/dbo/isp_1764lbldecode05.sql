SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_1764LblDecode05                                 */
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
/* 12-07-2019  1.0  James       WMS9812 Created                         */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_1764LblDecode05]
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
   DECLARE @cUCCL01        NVARCHAR(18)
   DECLARE @cUCCL07        NVARCHAR(30)

   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cTaskUCCNo     NVARCHAR( 20)
   DECLARE @cTaskUOM       NVARCHAR( 5)
   DECLARE @cTaskLOT       NVARCHAR( 10)
   DECLARE @cTaskLOC       NVARCHAR( 10)
   DECLARE @cTaskID        NVARCHAR( 18)
   DECLARE @cTaskSKU       NVARCHAR( 20)
   DECLARE @nTaskQTY       INT
   DECLARE @nTaskSystemQTY INT
   DECLARE @cTaskL01       NVARCHAR(18)
   DECLARE @cTaskL07       NVARCHAR(30)

   DECLARE @cActUOM        NVARCHAR( 5)
   DECLARE @cActTaskDetailKey NVARCHAR( 10)

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
   DECLARE @curPD          CURSOR
   DECLARE @cLottable      NVARCHAR( 10)
   DECLARE @cCode          NVARCHAR( 2)
   DECLARE @cLong          NVARCHAR( 20)
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @nFunc          INT

   SELECT @nFunc = Func
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE UserName = sUser_sName()

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

   SET @n_ErrNo = 0
   SET @c_ErrMsg = 0

   SET @cActUCCNo = @c_LabelNo
   SET @cTaskDetailKey = @c_oFieled10

   -- Check double scan
   IF EXISTS( SELECT 1 FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE UCCNo = @cActUCCNo)
   BEGIN
      SET @n_ErrNo = 141901
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
      SET @n_ErrNo = 141902
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

      SET @n_ErrNo = 141903
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Not an UCC
      RETURN
   END

   -- Check multi SKU UCC
   IF @nRowCount > 1
   BEGIN
      SET @n_ErrNo = 141904
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
      SET @n_ErrNo = 141905
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Bad UCC Status
      RETURN
   END

   -- Check UCC LOC match
   IF @cTaskLOC <> @cUCCLOC
   BEGIN
      SET @n_ErrNo = 141906
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCLOCNotMatch
      RETURN
   END

   -- Check UCC ID match
   IF @cTaskID <> @cUCCID
   BEGIN
      SET @n_ErrNo = 141907
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCIDNotMatch
      RETURN
   END

   -- Check UCC QTY match
   IF @nTaskQTY <> @nUCCQTY
   BEGIN
      SET @n_ErrNo = 141908
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCQTYNotMatch
      RETURN
   END

   -- Check SKU match
   IF @cTaskSKU <> @cUCCSKU
   BEGIN
      SET @n_ErrNo = 141909
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCSKUNotMatch
      RETURN
   END

   CREATE TABLE #TaskLOT (
   RowRef         INT IDENTITY(1,1) NOT NULL,
   Lottable       NVARCHAR( 10)  NOT NULL,
   LottableValue  NVARCHAR( 30)  NULL,
   ErrMsg         NVARCHAR( 20)  NULL)

   CREATE TABLE #UCCLOT (
   RowRef         INT IDENTITY(1,1) NOT NULL,
   Lottable       NVARCHAR( 10)  NOT NULL,
   LottableValue  NVARCHAR( 30)  NULL,
   ErrMsg         NVARCHAR( 20)  NULL)

   DECLARE @curSwapChkLot CURSOR
   SET @curSwapChkLot = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Code, LEFT( Long, 20) FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE ListName = 'SwapChkLot'
   AND   StorerKey = @c_Storerkey
   AND   Code2 = @nFunc
   ORDER BY 1
   OPEN @curSwapChkLot
   FETCH NEXT FROM @curSwapChkLot INTO @cCode, @cLong
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @cLottable = 'Lottable' + RIGHT( '00'+ISNULL( @cCode, ''), 2)

      IF NOT EXISTS ( SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'LOTAttribute' AND COLUMN_NAME = @cLottable)
      BEGIN
         SET @n_ErrNo = 141910
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Bad LottaSetup
         RETURN
      END      
      
      -- Insert value to temp table
      SET @cSQL = 
         ' INSERT INTO #TaskLOT (Lottable, LottableValue, ErrMsg) ' + 
         ' SELECT @cCode, @cLottable, @cLong ' + 
         ' FROM dbo.LOTAttribute WITH (NOLOCK) ' + 
         ' WHERE Lot = @cLot ' 
      SET @cSQLParam =
         ' @cLot         NVARCHAR( 10), ' + 
         ' @cCode        NVARCHAR( 2),  ' + 
         ' @cLottable    NVARCHAR( 10), ' +
         ' @cLong        NVARCHAR( 20)  ' 
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
         @cTaskLot, 
         @cCode, 
         @cLottable,
         @cLong

      SET @cSQL = 
         ' INSERT INTO #UCCLOT (Lottable, LottableValue, ErrMsg) ' + 
         ' SELECT @cCode, @cLottable, @cLong ' + 
         ' FROM dbo.LOTAttribute WITH (NOLOCK) ' + 
         ' WHERE Lot = @cLot ' 
      SET @cSQLParam =
         ' @cLot         NVARCHAR( 10), ' + 
         ' @cCode        NVARCHAR( 2),  ' + 
         ' @cLottable    NVARCHAR( 10), ' +
         ' @cLong        NVARCHAR( 20)  ' 
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
         @cUCCLot, 
         @cCode, 
         @cLottable,
         @cLong

      FETCH NEXT FROM @curSwapChkLot INTO @cCode, @cLong
   END

   SET @c_ErrMsg = ''
   SELECT TOP 1 @c_ErrMsg = T.ErrMsg
   FROM #TaskLOT T 
   JOIN #UCCLOT U ON ( T.Lottable = U.Lottable)
   WHERE T.LottableValue <> U.LottableValue
   ORDER BY 1

   IF @@ROWCOUNT <> 0
   BEGIN
      SET @n_ErrNo = 141911
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
         AND PD.QTY > 0)
   BEGIN
      SET @n_ErrNo = 141912
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
   SAVE TRAN isp_1764LblDecode05

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
            SET @n_ErrNo = 141913
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
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
      AND PD.LOT = @cTaskLOT
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
      WHERE StorerKey = @c_StorerKey 
         AND RefNo = @cTaskUCCNo

   -- Check PickDetail changed
   IF @nQTY <> @nTaskSystemQTY
   BEGIN
      SET @n_ErrNo = 141914
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --PKDtl changed
      GOTO RollBackTran
   END

   -- 2. UCC is not allocated
   IF EXISTS( SELECT TOP 1 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @c_StorerKey AND UCCNo = @cActUCCNo AND Status = '1')
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
               SET @n_ErrNo = 141915
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
      END
      ELSE
      BEGIN
         IF @cTaskUOM = '2'
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
               SET @n_ErrNo = @@ERROR
               IF @n_ErrNo <> 0
               BEGIN
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
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
               SET @n_ErrNo = @@ERROR
               IF @n_ErrNo <> 0
               BEGIN
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
            END         
         END
      END

      -- Actual
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '3', -- 3=Allocated
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE StorerKey = @c_StorerKey
         AND UCCNo = @cActUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @n_ErrNo = 141916
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      -- Task
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '1', -- 1=Received
         EditDate = GETDATE(),
         EditWho = 'rdt.' + SUSER_SNAME()
      WHERE StorerKey = @c_StorerKey
         AND UCCNo = @cTaskUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @n_ErrNo = 141917
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD UCC Fail
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
         SET @n_ErrNo = 141918
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
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
            SET @n_ErrNo = 141919
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPDPackDtlFail
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
   WHERE UCC.StorerKey = @c_StorerKey
      AND PD.StorerKey = @c_StorerKey
      AND UCC.UCCNo = @cActUCCNo
      AND UCC.Status = '3'
      AND PD.Status = '0'
      AND PD.QTY > 0

   -- Get actual PickDetail info
   SET @nRowCount = @@ROWCOUNT

   -- 3. UCC on other PickDetail
   IF @nRowCount > 0
   BEGIN
      SELECT @cActTaskDetailKey = TaskDetailKey FROM @tActPD

      -- Get actual task   
      SELECT @cActUOM = UOM
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
         WHERE StorerKey = @c_StorerKey 
            AND RefNo = @cActUCCNo

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
               SET @n_ErrNo = 141920
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
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
               SET @n_ErrNo = 141921
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
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
            SET @n_ErrNo = @@ERROR
            IF @n_ErrNo <> 0
            BEGIN
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
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
            SET @n_ErrNo = @@ERROR
            IF @n_ErrNo <> 0
            BEGIN
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
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
            SET @n_ErrNo = @@ERROR
            IF @n_ErrNo <> 0
            BEGIN
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
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
            SET @n_ErrNo = @@ERROR
            IF @n_ErrNo <> 0
            BEGIN
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
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
         SET @n_ErrNo = 141922
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD TKDtl Fail
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
         SET @n_ErrNo = 141923
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
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
            SET @n_ErrNo = 141924
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPDPackDtlFail
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
            SET @n_ErrNo = 141925
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPDPackDtlFail
            GOTO RollBackTran
         END
      END
      
      GOTO CommitTran
   END
   ELSE
   BEGIN
      -- Get actual PickDetail
      INSERT INTO @tActPD (PickDetailKey, TaskDetailKey, LOT, QTY)
      SELECT PD.PickDetailKey, PD.TaskDetailKey, PD.LOT, PD.QTY
      FROM PickDetail PD WITH (NOLOCK)
         JOIN UCC WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
      WHERE UCC.StorerKey = @c_StorerKey
         AND PD.StorerKey = @c_StorerKey
         AND UCC.UCCNo = @cTaskUCCNo
         AND UCC.Status = '3'
         AND PD.Status = '0'
         AND PD.QTY > 0

      --SELECT @cActTaskDetailKey = TaskDetailKey FROM @tActPD
      SELECT @cActTaskDetailKey = TaskDetailKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND CaseID = @cActUCCNo


      -- Get actual task   
      SELECT @cActUOM = UOM
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
         WHERE StorerKey = @c_StorerKey 
            AND RefNo = @cActUCCNo

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
               SET @n_ErrNo = 141920
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
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
            SET @n_ErrNo = @@ERROR
            IF @n_ErrNo <> 0
            BEGIN
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
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
            SET @n_ErrNo = @@ERROR
            IF @n_ErrNo <> 0
            BEGIN
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
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
         SET @n_ErrNo = 141922
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD TKDtl Fail
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
         SET @n_ErrNo = 141923
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD TKDtl Fail
         GOTO RollBackTran
      END
      --select '@cActTaskDetailKey', @cActTaskDetailKey, '@cTaskUCCNo', @cTaskUCCNo
      --select '@cTaskDetailKey', @cTaskDetailKey, '@cActUCCNo', @cActUCCNo
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
            SET @n_ErrNo = 141924
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPDPackDtlFail
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
            SET @n_ErrNo = 141925
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPDPackDtlFail
            GOTO RollBackTran
         END
      END
      
      GOTO CommitTran
   END

   -- PickDetail not found
   SET @n_ErrNo = 141926
   SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --No PKDtl Found
   GOTO RollBackTran

CommitTran:
   -- Log UCC swap
   IF @cTaskUCCNo <> @cActUCCNo
   BEGIN
      DECLARE @cTaskUCCStatus NVARCHAR(1)
      SELECT @cTaskUCCStatus = Status FROM UCC WITH (NOLOCK) WHERE UCCNo = @cTaskUCCNo AND StorerKey = @c_StorerKey
      
      INSERT INTO rdt.SwapUCC (Func, UCC, NewUCC, ReplenGroup, UCCStatus, NewUCCStatus)
      VALUES (1764, @cTaskUCCNo, @cActUCCNo, @cTaskDetailKey, @cTaskUCCStatus, @cUCCStatus)
   END

   SET @c_oFieled01 = @cUCCSKU
   SET @c_oFieled05 = @nUCCQTY
   SET @c_oFieled08 = @cActUCCNo

   COMMIT TRAN isp_1764LblDecode05
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN isp_1764LblDecode05
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END -- End Procedure


GO