SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispVFRPFDecode                                      */
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
/* 11-03-2013  1.0  Ung         SOS272437. Created                      */
/* 22-09-2014  1.1  Ung         SOS321202 UCC loc only allow scan UCC   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispVFRPFDecode]
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
   
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cPickMethod    NVARCHAR( 1)
   DECLARE @cUOM           NVARCHAR( 10)
   DECLARE @nQTY_PD        INT

   DECLARE @cUCCNo         NVARCHAR( 20)
   DECLARE @cUCCSKU        NVARCHAR( 20)
   DECLARE @cUCCLOT        NVARCHAR( 10)
   DECLARE @cUCCLOC        NVARCHAR( 10)
   DECLARE @cUCCID         NVARCHAR( 18)
   DECLARE @nUCCQTY        INT
   DECLARE @nPickQTY       INT

   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cTaskType      NVARCHAR( 10)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @cID            NVARCHAR( 18)
   DECLARE @nSystemQTY     INT
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @cLoseUCC       NVARCHAR( 1)

   SET @n_ErrNo = 0
   SET @c_ErrMsg = 0
   
   SET @cDropID = @c_oFieled09
   SET @cTaskDetailKey = @c_oFieled10

   -- Get task info
   SELECT 
      @cWaveKey = WaveKey, 
      @cTaskType = TaskType, 
      @cUOM = UOM, 
      @cLOT = LOT, 
      @cLOC = FromLOC,
      @cID = FromID, 
      @nSystemQTY = SystemQTY
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ROWCOUNT = 0
   BEGIN
      SET @n_ErrNo = 80602
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
         AND Status = '1'
      
      -- Check label scanned is UCC
      IF @nRowCount = 0
      BEGIN
         SET @c_oFieled01 = '' -- SKU
         SET @c_oFieled05 = 0  -- UCC QTY
         SET @c_oFieled08 = '' -- UCC QTY
   
         SET @n_ErrNo = 80618
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Not an UCC
         RETURN
      END
   END

   -- Check multi SKU UCC
   IF @nRowCount > 1
   BEGIN
      SET @n_ErrNo = 80601
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Multi SKU UCC
      RETURN
   END

   -- Get UCC info
   SELECT 
      @cUCCNo = UCCNo, 
      @cUCCSKU = SKU, 
      @nUCCQTY = QTY, 
      @nPickQTY = QTY, 
      @cUCCLOT = LOT,
      @cUCCLOC = LOC, 
      @cUCCID = ID
   FROM dbo.UCC WITH (NOLOCK) 
   WHERE UCCNo = @c_LabelNo 
      AND StorerKey = @c_Storerkey
      AND Status = '1'

   -- Check UCC LOC match
   IF @cLOC <> @cUCCLOC
   BEGIN
      SET @n_ErrNo = 80603
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCLOCNotMatch
      RETURN
   END

   -- Check UCC ID match
   IF @cID <> @cUCCID
   BEGIN
      SET @n_ErrNo = 80604
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCIDNotMatch
      RETURN
   END

   -- Check UCC LOT match
   IF @cLOT <> @cUCCLOT
   BEGIN
      SET @n_ErrNo = 80605
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCLOTNotMatch
      RETURN
   END

   -- Check double scan
   IF EXISTS( SELECT 1 FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE UCCNo = @cUCCNo)
   BEGIN
      SET @n_ErrNo = 80616
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCC scanned
      RETURN
   END
   
   -- Check over pick (means existing scanned UCC already fulfill QTY, should not allow new scan UCC)
   IF (SELECT ISNULL( SUM( QTY), 0) 
      FROM rdt.rdtRPFLog WITH (NOLOCK) 
      WHERE TaskDetailKey = @cTaskDetailKey 
         AND DropID = @cDropID) > @nSystemQTY
   BEGIN
      SET @n_ErrNo = 80617
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Over replenish
      RETURN
   END
   
   -- Ignore full pallet replen, pallet ID could scan more then once (FromID-->ToLOC ESC FromID-->ToLOC...)
   IF @cDropID = '' 
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey AND DropID = @cUCCNo)
         RETURN
   END
   
/*--------------------------------------------------------------------------------------------------

                                    Stamp PickDetail.DropID

--------------------------------------------------------------------------------------------------*/
   DECLARE @tPD TABLE
   (
      PickDetailKey NVARCHAR(10) NOT NULL,
      QTY           INT      NOT NULL
   )

   SET @cPickMethod = CASE WHEN @cUOM = '2' THEN 'F' -- full case 
                           WHEN @cUOM = '6' THEN 'C' -- conso case 
                           WHEN @cUOM = '7' THEN 'L' -- loose case
                           ELSE ''
                      END

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdtVFRPFDecode

   DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.OrderKey, PD.PickDetailKey, PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.TaskDetailKey = @cTaskDetailKey
         AND PD.QTY > 0
         AND PD.Status = '0'
         AND PD.DropID = ''

   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cOrderKey, @cPickDetailKey, @nQTY_PD
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Exact match
      IF @nQTY_PD = @nPickQty
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = @cUCCNo, 
            -- Status = '3', -- Pick in-progress
            PickMethod = @cPickMethod, 
            TrafficCop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 80606
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         INSERT INTO @tPD (PickDetailKey, QTY) VALUES (@cPickDetailKey, @nPickQty)
         SET @nPickQty = 0 -- Reduce balance
         BREAK
      END

      -- PickDetail have less
      ELSE IF @nQTY_PD < @nPickQty
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = @cUCCNo, 
            -- Status = '3', -- Pick in-progress
            PickMethod = @cPickMethod, 
            TrafficCop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 80607
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         INSERT INTO @tPD (PickDetailKey, QTY) VALUES (@cPickDetailKey, @nPickQty)
         SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance
      END

      -- PickDetail have more, need to split
      ELSE IF @nQTY_PD > @nPickQty
      BEGIN
         -- Get new PickDetailkey
         DECLARE @cNewPickDetailKey NVARCHAR( 10)
         EXECUTE dbo.nspg_GetKey
            'PICKDETAILKEY',
            10 ,
            @cNewPickDetailKey OUTPUT,
            @b_success         OUTPUT,
            @n_ErrNo            OUTPUT,
            @c_ErrMsg           OUTPUT
         IF @b_success <> 1
         BEGIN
            SET @n_ErrNo = 80608
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --GetKey Fail
            GOTO RollBackTran
         END

         -- Create a new PickDetail to hold the balance
         INSERT INTO dbo.PickDetail (
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
            DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
            PickDetailKey,
            Status, 
            QTY,
            TrafficCop,
            OptimizeCop)
         SELECT
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
            DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
            @cNewPickDetailKey,
            '0', 
            @nQTY_PD - @nPickQty, -- QTY
            NULL, --TrafficCop
            '1'   --OptimizeCop
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 80609
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --INS PKDtl Fail
            GOTO RollBackTran
         END

         -- Change original PickDetail with exact QTY (with TrafficCop)
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            QTY = @nPickQty,
            DropID = @cUCCNo, 
            -- Status = '3', -- Pick in-progress
            PickMethod = @cPickMethod, 
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 80610
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         -- Pick confirm original line
         /*
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            Status = '5'
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 80611
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END
         */

         INSERT INTO @tPD (PickDetailKey, QTY) VALUES (@cPickDetailKey, @nPickQty)
         SET @nPickQty = 0 -- Reduce balance
         BREAK
      END
      FETCH NEXT FROM @curPD INTO @cOrderKey, @cPickDetailKey, @nQTY_PD
   END
   -- select * from @tPD

   -- Full case must fully offset
   IF @cUOM = '2' AND @nPickQty <> 0
   BEGIN
      SET @n_ErrNo = 80612
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --FC NotFullyALC
      GOTO RollBackTran
   END

   -- Conso case must fully offset
   IF @cUOM = '6' AND @nPickQty <> 0
   BEGIN
      SET @n_ErrNo = 80613
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --CS NotFullyALC
      GOTO RollBackTran
   END
   
   -- Loose case must partly offset and partly available
   IF @cUOM = 7
   BEGIN
      IF @nPickQty = 0 OR @nPickQty = @nUCCQTY
      BEGIN
         SET @n_ErrNo = 80614
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --LC Not Alloc
         GOTO RollBackTran
      END
      
      -- Get QTYAvail
      DECLARE @nQTYAvail INT
      SELECT @nQTYAvail = ISNULL( SUM( QTY-QTYAllocated-QTYPicked), 0)
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE LOT = @cUCCLOT
         AND LOC = @cUCCLOC
         AND ID = @cUCCID
            
      -- Check QTYAvail not enough
      IF @nQTYAvail < @nPickQty --Balance
      BEGIN
         -- Check if other wave allocated the same UCC. If yes, replen together
         EXEC ispVFRPFDecodeLstCtn @c_LangCode
            ,@cTaskDetailKey
            ,@cUCCNo
            ,@nPickQty  OUTPUT
            ,@n_ErrNo   OUTPUT
            ,@c_ErrMsg  OUTPUT
         IF @n_ErrNo <> 0
            GOTO RollBackTran
            
         IF @nQTYAvail < @nPickQty
         BEGIN
            SET @n_ErrNo = 80615
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --LC NoQTYAvail
            GOTO RollBackTran         
         END
      END
   END
      
   SET @c_oFieled01 = @cUCCSKU
   SET @c_oFieled05 = @nUCCQTY
   SET @c_oFieled08 = @cUCCNo
   
   COMMIT TRAN rdtVFRPFDecode
   GOTO Quit
   
RollBackTran:
      ROLLBACK TRAN rdtVFRPFDecode
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END -- End Procedure


GO