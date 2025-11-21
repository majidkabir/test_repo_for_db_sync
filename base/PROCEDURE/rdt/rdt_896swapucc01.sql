SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_896SwapUCC01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-08-23 1.0  Ung        WMS-20562 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_896SwapUCC01] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cStorerKey   NVARCHAR( 15), 
   @cFacility    NVARCHAR( 5),  
   @cBarcode     NVARCHAR( 60), 
   @cRPLKey      NVARCHAR( 10), 
   @cFromLOC     NVARCHAR( 10)  OUTPUT, 
   @cFromID      NVARCHAR( 18)  OUTPUT, 
   @cReplenKey   NVARCHAR( 10)  OUTPUT, -- Compulsory, the task selected after swap
   @cSKU         NVARCHAR( 20)  OUTPUT, -- In FromLOC, FromID mode, SKU is blank
   @nQTY         INT            OUTPUT, -- In FromLOC, FromID mode, QTY is 0
   @cUCCNo       NVARCHAR( 20)  OUTPUT, -- Actual UCC scanned
   @cToID        NVARCHAR( 18)  OUTPUT, 
   @cToLOC       NVARCHAR( 10)  OUTPUT, 
   @cLottable01  NVARCHAR( 18)  OUTPUT, 
   @cLottable02  NVARCHAR( 18)  OUTPUT, 
   @cLottable03  NVARCHAR( 18)  OUTPUT, 
   @dLottable04  DATETIME       OUTPUT, 
   @dLottable05  DATETIME       OUTPUT, 
   @cLottable06  NVARCHAR( 30)  OUTPUT, 
   @cLottable07  NVARCHAR( 30)  OUTPUT, 
   @cLottable08  NVARCHAR( 30)  OUTPUT, 
   @cLottable09  NVARCHAR( 30)  OUTPUT, 
   @cLottable10  NVARCHAR( 30)  OUTPUT, 
   @cLottable11  NVARCHAR( 30)  OUTPUT, 
   @cLottable12  NVARCHAR( 30)  OUTPUT, 
   @dLottable13  DATETIME       OUTPUT, 
   @dLottable14  DATETIME       OUTPUT, 
   @dLottable15  DATETIME       OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cActUCCNo         NVARCHAR( 20)
   DECLARE @cActUCCLOT        NVARCHAR( 10)
   DECLARE @cActUCCLOC        NVARCHAR( 10)
   DECLARE @cActUCCID         NVARCHAR( 18)
   DECLARE @cActUCCSKU        NVARCHAR( 20)
   DECLARE @cActUCCStatus     NVARCHAR( 1)
   DECLARE @nActUCCQTY        INT

   DECLARE @cTaskUCCNo        NVARCHAR( 20)
   DECLARE @cTaskLOT          NVARCHAR( 10)
   DECLARE @cTaskToLOC        NVARCHAR( 10)
   DECLARE @cTaskToID         NVARCHAR( 18)
   DECLARE @cTaskUCCStatus    NVARCHAR(1)
   DECLARE @nTaskUCCQTY       INT
   DECLARE @nTaskQTYReplen    INT
   DECLARE @nTaskPendingMoveIn INT

   DECLARE @cNewPickDetailKey NVARCHAR( 10)
   DECLARE @cPickDetailKey    NVARCHAR( 10)
   DECLARE @cLOT              NVARCHAR( 10)
   DECLARE @nQTY_Bal          INT
   DECLARE @curPD             CURSOR

   DECLARE @tTaskPD TABLE
   (
      PickDetailKey NVARCHAR( 10) NOT NULL,
      LOT           NVARCHAR( 10) NOT NULL,
      QTY           INT           NOT NULL
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )
   
   DECLARE @tActPD TABLE
   (
      PickDetailKey NVARCHAR( 10) NOT NULL,
      LOT           NVARCHAR( 10) NOT NULL,
      QTY           INT           NOT NULL
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )
         
   -- Get actual UCC info
   SELECT 
      @cActUCCNo = @cUCCNo, 
      @cActUCCLOT = LOT, 
      @cActUCCLOC = LOC,
      @cActUCCID = ID, 
      @cActUCCSKU = SKU, 
      @nActUCCQTY = QTY, 
      @cActUCCStatus = Status
   FROM dbo.UCC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cUCCNo

/*--------------------------------------------------------------------------------------------------
                                                Swap UCC
--------------------------------------------------------------------------------------------------*/
/*
   Task dispatched:
   Specified task
   Any task in the FromLOC and, FromID

   Actual UCC scanned:
   UCC free from alloc
   UCC with alloc
   UCC with replen

   All scenarios:
   1. Specified task, UCC is on the task, no swap
   2. Any task in FromLOC and FromID, UCC is on those tasks, no swap
   
   3. Task UCC, swap with free UCC 
      3.1 No swap LOT
      3.2 Swap LOT
   4. Task UCC, swap with alloc UCC 
      4.1 No swap LOT
      4.2 Swap LOT
   5. Task UCC, swap with replen UCC (only happen under specified task mode)
      5.1 No swap LOT
      5.2 Swap LOT

   Note:
   Step 1 and 2 is basically getting a task
   Step 3, 4, 5 is the swap logic
*/

   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_896SwapUCC01 -- For rollback or commit only our own transaction

   -- 1. Specified task, UCC is on the task, no swap
   IF @cRPLKey <> ''
   BEGIN
      -- Get task info
      SELECT 
         @cReplenKey = ReplenishmentKey, 
         @cTaskUCCNo = RefNo, 
         @cTaskLOT = LOT, 
         @cTaskToLOC = ToLOC, 
         @cTaskToID = ToID, 
         @nTaskPendingMoveIn = ISNULL( PendingMoveIn, 0), 
         @nTaskQTYReplen = ISNULL( QTYReplen, 0)
      FROM dbo.Replenishment WITH (NOLOCK)
      WHERE ReplenishmentKey = @cRPLKey
      
      -- UCC on task
      IF @cTaskUCCNo = @cActUCCNo
         GOTO Quit
   END

   -- 2. Any task in FromLOC and FromID, UCC is on those tasks, no swap
   ELSE
   BEGIN
      SET @cReplenKey = ''

      -- Get task info (match UCCNo)
      SELECT @cReplenKey = ReplenishmentKey
      FROM dbo.Replenishment WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND FromLOC = @cFromLOC
         AND ID = @cFromID
         AND RefNo = @cUCCNo
         AND Confirmed = 'N'
      
      -- UCC on task
      IF @cReplenKey <> ''
         GOTO Quit
   
      -- Find a task (match FromLOC, FromID, SKU, QTY)
      SELECT TOP 1 
         @cReplenKey = ReplenishmentKey, 
         @cTaskUCCNo = RefNo, 
         @cTaskLOT = LOT, 
         @cTaskToLOC = ToLOC, 
         @cTaskToID = ToID, 
         @nTaskPendingMoveIn = ISNULL( PendingMoveIn, 0), 
         @nTaskQTYReplen = ISNULL( QTYReplen, 0)
      FROM dbo.Replenishment WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND FromLOC = @cFromLOC
         AND ID = @cFromID
         AND SKU = @cActUCCSKU
         AND QTY = @nActUCCQTY
         AND Confirmed = 'N'
         AND RefNo <> ''
      ORDER BY CASE WHEN LOT = @cActUCCLOT THEN 1 ELSE 2 END
      
      -- Check matching task
      IF @cReplenKey = ''
      BEGIN
         SET @nErrNo = 190651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Replen task
         GOTO Quit
      END
   END

   -- Get task UCC info
   SELECT 
      @cTaskUCCStatus = Status, 
      @nTaskUCCQTY = QTY
   FROM dbo.UCC WITH (NOLOCK) 
   WHERE UCCNo = @cTaskUCCNo 
      AND StorerKey = @cStorerkey
      
   -- Check UCC valid
   EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT
      ,@cTaskUCCNo -- UCC
      ,@cStorerKey
      ,'134'    -- 1=Received, 3=Alloc, 4=Replen
      ,@cChkLOC = @cFromLOC
      ,@cChkID  = @cFromID
      ,@cChkSKU = @cActUCCSKU
      ,@nChkQTY = @nActUCCQTY
   IF @nErrNo <> 0
      GOTO Quit

   -- Check UCC QTY
   IF rdt.rdtGetConfig( 0, 'UCCWithDynamicCaseCNT', @cStorerKey) = '1'
   BEGIN
      IF @nTaskUCCQTY <> @nActUCCQTY
      BEGIN
         SET @nErrNo = 190652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC QTY Diff
         GOTO Quit
      END
   END

   -- 3. task UCC, swap with free UCC 
   IF @cActUCCStatus = '1'
   BEGIN
      -- NO swap LOT
      IF @cTaskLOT = @cActUCCLOT
      BEGIN
         -- Task
         UPDATE dbo.Replenishment SET
            RefNo = @cActUCCNo,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME(), 
            ArchiveCop = NULL
         WHERE ReplenishmentKey = @cReplenKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 190653
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
            GOTO RollBackTran
         END
      END
      
      -- Swap LOT
      ELSE
      BEGIN
         -- Task
         UPDATE dbo.Replenishment SET
            LOT = @cActUCCLOT, 
            RefNo = @cActUCCNo,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME(), 
            ArchiveCop = NULL
         WHERE ReplenishmentKey = @cReplenKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 190654
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
            GOTO RollBackTran
         END
         
         -- Locking
         IF @nTaskQTYReplen > 0
         BEGIN
            -- Task
            UPDATE dbo.LOTxLOCxID SET
               QTYReplen = QTYReplen - @nTaskQTYReplen, 
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE LOT = @cTaskLOT
               AND LOC = @cFromLOC
               AND ID = @cFromID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 190655
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd LLI Fail
               GOTO RollBackTran
            END

            -- Actual
            UPDATE dbo.LOTxLOCxID SET
               QTYReplen = QTYReplen + @nTaskQTYReplen, 
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE LOT = @cActUCCLOT
               AND LOC = @cFromLOC
               AND ID = @cFromID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 190656
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd LLI Fail
               GOTO RollBackTran
            END
         END
         
         -- Booking
         IF @nTaskPendingMoveIn > 0
         BEGIN
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
               ,'' --FromLOC
               ,'' --FromID
               ,'' --SuggLOC
               ,'' --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cUCCNo = @cTaskUCCNo
            IF @nErrNo <> 0
               GOTO RollbackTran

            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'
               ,@cFromLOC --FromLOC
               ,@cFromID  --FromID
               ,@cTaskToLOC --SuggLOC
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU = @cActUCCSKU
               ,@nPutawayQTY = @nActUCCQTY
               ,@cFromLOT = @cActUCCLOT
               ,@cToID = @cTaskToID
               ,@cUCCNo = @cActUCCNo
               ,@nFunc = @nFunc
            IF @nErrNo <> 0
            GOTO RollBackTran
         END
      END

      -- Task
      UPDATE dbo.UCC SET
         Status = '1', -- 1=Received
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cTaskUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 190657
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      -- Actual
      UPDATE dbo.UCC SET
         Status = '4', -- 4=Replen
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cActUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 190658
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END
      
      GOTO CommitTran
   END

   DECLARE @cAllowOverAllocations NVARCHAR( 1) = '0'
   DECLARE @bSuccess INT = 0
   EXECUTE nspGetRight
      @cFacility,             -- Facility
      @cStorerKey,            -- Storerkey
      '',                     -- SKU
      'ALLOWOVERALLOCATIONS', -- ConfigKey
      @bSuccess              OUTPUT,
      @cAllowOverAllocations OUTPUT,
      0, -- @n_err                 OUTPUT,
      '' -- @c_errmsg              OUTPUT
   IF @bSuccess <> 1
   BEGIN
      SET @nErrNo = 190659
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspGetRight
      GOTO Quit
   END
      
   -- 4. task UCC, swap with alloc UCC
   IF @cActUCCStatus = '3'
   BEGIN
      -- Replenish LOT could be partially or fully overallocated in pick face (have PickDetail)
      IF @cAllowOverAllocations = '1' AND
         (SELECT QTY-QTYAllocated-QTYPicked FROM dbo.LOT WITH (NOLOCK) WHERE LOT = @cTaskLOT) < @nTaskUCCQTY 
      BEGIN
         -- Get task PickDetail
         SET @nQTY_Bal = @nTaskUCCQTY
         SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PD.PickDetailKey, PD.LOT, PD.QTY
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.StorerKey = @cStorerkey
               AND PD.LOT = @cTaskLOT
               AND PD.LOC = @cTaskToLOC
               AND PD.Status = '0'
               AND PD.QTY > 0
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cLOT, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @nQTY <= @nQTY_Bal
            BEGIN
               INSERT INTO @tTaskPD (PickDetailKey, LOT, QTY) VALUES (@cPickDetailKey, @cLOT, @nQTY)
               SET @nQTY_Bal = @nQTY_Bal - @nQTY
            END
            ELSE
            BEGIN
               -- Get new PickDetailkey
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @cNewPickDetailKey OUTPUT,
                  @bSuccess          OUTPUT,
                  @nErrNo            OUTPUT,
                  @cErrMsg           OUTPUT
               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 190660
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_GetKey
                  GOTO RollBackTran
               END
      
               -- Create new a PickDetail to hold the balance
               INSERT INTO dbo.PickDetail (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                  PickDetailKey,
                  Status, 
                  QTY,
                  TrafficCop,
                  OptimizeCop)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                  CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                  @cNewPickDetailKey,
                  Status, 
                  @nQTY - @nQTY_Bal, -- QTY
                  NULL, -- TrafficCop
                  '1'   -- OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
      			WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
      				SET @nErrNo = 190661
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
                  GOTO RollBackTran
               END
      
               -- Split RefKeyLookup
               IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
               BEGIN
                  -- Insert into
                  INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
                  SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                  FROM RefKeyLookup WITH (NOLOCK) 
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 190662
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RefKeyFail
                     GOTO RollBackTran
                  END
               END
      
               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nQTY_Bal,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 190663
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END

               INSERT INTO @tTaskPD (PickDetailKey, LOT, QTY) VALUES (@cPickDetailKey, @cLOT, @nQTY_Bal)
               SET @nQTY_Bal = 0
            END
            
            IF @nQTY_Bal = 0
               BREAK
         
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cLOT, @nQTY
         END
      END

      -- Get actual PickDetail
      INSERT INTO @tActPD (PickDetailKey, LOT, QTY)
      SELECT PD.PickDetailKey, PD.LOT, PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN UCC WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)
      WHERE UCC.StorerKey = @cStorerkey
         AND PD.StorerKey = @cStorerkey
         AND UCC.UCCNo = @cActUCCNo
         AND UCC.Status = '3'
         AND PD.Status = '0'
         AND PD.QTY > 0
            
      -- Check PickDetail changed
      IF @nActUCCQTY <> (SELECT ISNULL( SUM( QTY), 0) FROM @tActPD)
      BEGIN
         SET @nErrNo = 190664
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
         GOTO RollBackTran
      END

      -- NO swap LOT
      IF @cTaskLOT = @cActUCCLOT
      BEGIN
         -- Task
         UPDATE dbo.Replenishment SET
            RefNo = @cActUCCNo,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME(), 
            ArchiveCop = NULL
         WHERE ReplenishmentKey = @cReplenKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 190665
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
            GOTO RollBackTran
         END
         
         -- Actual
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update PickDetail
            UPDATE dbo.PickDetail SET
               DropID = @cTaskUCCNo,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME(),
               TrafficCop = NULL
            FROM dbo.PickDetail PD
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 190666
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
      END
      
      -- Swap LOT
      ELSE
      BEGIN
         -- Unallocate (task)
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail SET
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
         
         -- Unallocate (actual)
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail SET
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

         -- Reallocate (task)
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail SET
               LOT = @cActUCCLOT,
               -- DropID = @cActUCCNo,
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

         -- Reallocate (actual)
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail SET
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
         
         -- Task
         UPDATE dbo.Replenishment SET
            LOT = @cActUCCLOT, 
            RefNo = @cActUCCNo,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME(), 
            ArchiveCop = NULL
         WHERE ReplenishmentKey = @cReplenKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 190667
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
            GOTO RollBackTran
         END
         
         -- Locking
         IF @nTaskQTYReplen > 0
         BEGIN
            -- Task
            UPDATE dbo.LOTxLOCxID SET
               QTYReplen = QTYReplen - @nTaskQTYReplen, 
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE LOT = @cTaskLOT
               AND LOC = @cFromLOC
               AND ID = @cFromID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 190668
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd LLI Fail
               GOTO RollBackTran
            END

            -- Actual
            UPDATE dbo.LOTxLOCxID SET
               QTYReplen = QTYReplen + @nTaskQTYReplen, 
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE LOT = @cActUCCLOT
               AND LOC = @cFromLOC
               AND ID = @cFromID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 190669
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd LLI Fail
               GOTO RollBackTran
            END
         END
         
         -- Booking
         IF @nTaskPendingMoveIn > 0
         BEGIN
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
               ,'' --FromLOC
               ,'' --FromID
               ,'' --SuggLOC
               ,'' --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cUCCNo = @cTaskUCCNo
            IF @nErrNo <> 0
               GOTO RollbackTran

            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'
               ,@cFromLOC --FromLOC
               ,@cFromID  --FromID
               ,@cTaskToLOC --SuggLOC
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU = @cActUCCSKU
               ,@nPutawayQTY = @nActUCCQTY
               ,@cFromLOT = @cActUCCLOT
               ,@cToID = @cTaskToID
               ,@cUCCNo = @cActUCCNo
               ,@nFunc = @nFunc
            IF @nErrNo <> 0
            GOTO RollBackTran
         END
      END

      -- Task
      UPDATE dbo.UCC SET
         Status = '3', -- 3=Allocated
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cTaskUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 190670
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      -- Actual
      UPDATE dbo.UCC SET
         Status = '4', -- 4=Replen
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cActUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 190671
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END
   END

   -- 5. task UCC, swap with replen UCC (only happen under specified task mode)
   IF @cActUCCStatus = '4'
   BEGIN
      -- Get actual replen
      DECLARE @cActReplenKey  NVARCHAR( 10) = ''
      DECLARE @cActToLOC      NVARCHAR( 10)
      DECLARE @cActToID       NVARCHAR( 18)
      DECLARE @nActQTYReplen  INT 
      DECLARE @nActPendingMoveIn INT
      SELECT 
         @cActReplenKey = ReplenishmentKey, 
         @cActToLOC = ToLOC, 
         @cActToID = ToID, 
         @nActQTYReplen = QTYReplen, 
         @nActPendingMoveIn = PendingMoveIn  
      FROM dbo.Replenishment WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND FromLOC = @cFromLOC
         AND ID = @cFromID
         AND SKU = @cActUCCSKU
         AND QTY = @nActUCCQTY
         AND Confirmed = 'N'
         AND RefNo = @cActUCCNo
     
      -- Check actual task valid
      IF @cActReplenKey = ''
      BEGIN
         SET @nErrNo = 190672
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Replen task
         GOTO RollBackTran
      END
      
      -- Task
      UPDATE dbo.Replenishment SET
         RefNo = @cActUCCNo,
         LOT = @cActUCCLOT, 
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME(), 
         ArchiveCop = NULL
      WHERE ReplenishmentKey = @cReplenKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 190673
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
         GOTO RollBackTran
      END
      
      -- Actual
      UPDATE dbo.Replenishment SET
         RefNo = @cTaskUCCNo,
         LOT = @cTaskLOT, 
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME(), 
         ArchiveCop = NULL
      WHERE ReplenishmentKey = @cActReplenKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 190674
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
         GOTO RollBackTran
      END
      
      -- Swap LOT
      IF @cTaskLOT <> @cActUCCLOT
      BEGIN
         -- Replenish LOT could be partially or fully overallocated in pick face (have PickDetail)
         IF @cAllowOverAllocations = '1'
         BEGIN
            -- Task
            IF (SELECT QTY-QTYAllocated-QTYPicked FROM dbo.LOT WITH (NOLOCK) WHERE LOT = @cTaskLOT) < @nTaskUCCQTY 
            BEGIN
               -- Get task PickDetail
               SET @nQTY_Bal = @nTaskUCCQTY
               SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT PD.PickDetailKey, PD.LOT, PD.QTY
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  WHERE PD.StorerKey = @cStorerkey
                     AND PD.LOT = @cTaskLOT
                     AND PD.LOC = @cTaskToLOC
                     AND PD.Status = '0'
                     AND PD.QTY > 0
               OPEN @curPD
               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cLOT, @nQTY
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  IF @nQTY <= @nQTY_Bal
                  BEGIN
                     INSERT INTO @tTaskPD (PickDetailKey, LOT, QTY) VALUES (@cPickDetailKey, @cLOT, @nQTY)
                     SET @nQTY_Bal = @nQTY_Bal - @nQTY
                  END
                  ELSE
                  BEGIN
                     -- Get new PickDetailkey
                     EXECUTE dbo.nspg_GetKey
                        'PICKDETAILKEY',
                        10 ,
                        @cNewPickDetailKey OUTPUT,
                        @bSuccess          OUTPUT,
                        @nErrNo            OUTPUT,
                        @cErrMsg           OUTPUT
                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 190675
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_GetKey
                        GOTO RollBackTran
                     END
            
                     -- Create new a PickDetail to hold the balance
                     INSERT INTO dbo.PickDetail (
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                        UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                        ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                        PickDetailKey,
                        Status, 
                        QTY,
                        TrafficCop,
                        OptimizeCop)
                     SELECT
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                        UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                        CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                        @cNewPickDetailKey,
                        Status, 
                        @nQTY - @nQTY_Bal, -- QTY
                        NULL, -- TrafficCop
                        '1'   -- OptimizeCop
                     FROM dbo.PickDetail WITH (NOLOCK)
            			WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
            				SET @nErrNo = 190676
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
                        GOTO RollBackTran
                     END
            
                     -- Split RefKeyLookup
                     IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
                     BEGIN
                        -- Insert into
                        INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
                        SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                        FROM RefKeyLookup WITH (NOLOCK) 
                        WHERE PickDetailKey = @cPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 190677
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RefKeyFail
                           GOTO RollBackTran
                        END
                     END
            
                     -- Change orginal PickDetail with exact QTY (with TrafficCop)
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                        QTY = @nQTY_Bal,
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME(),
                        Trafficcop = NULL
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 190678
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END

                     INSERT INTO @tTaskPD (PickDetailKey, LOT, QTY) VALUES (@cPickDetailKey, @cLOT, @nQTY_Bal)
                     SET @nQTY_Bal = 0
                  END
                  
                  IF @nQTY_Bal = 0
                     BREAK
               
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cLOT, @nQTY
               END
            END

            -- Actual
            IF (SELECT QTY-QTYAllocated-QTYPicked FROM dbo.LOT WITH (NOLOCK) WHERE LOT = @cActUCCLOT) < @nActUCCQTY 
            BEGIN
               -- Get task PickDetail
               SET @nQTY_Bal = @nActUCCQTY
               SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT PD.PickDetailKey, PD.LOT, PD.QTY
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  WHERE PD.StorerKey = @cStorerkey
                     AND PD.LOT = @cActUCCLOT
                     AND PD.LOC = @cActToLOC
                     AND PD.Status = '0'
                     AND PD.QTY > 0
               OPEN @curPD
               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cLOT, @nQTY
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  IF @nQTY <= @nQTY_Bal
                  BEGIN
                     INSERT INTO @tActPD (PickDetailKey, LOT, QTY) VALUES (@cPickDetailKey, @cLOT, @nQTY)
                     SET @nQTY_Bal = @nQTY_Bal - @nQTY
                  END
                  ELSE
                  BEGIN
                     -- Get new PickDetailkey
                     EXECUTE dbo.nspg_GetKey
                        'PICKDETAILKEY',
                        10 ,
                        @cNewPickDetailKey OUTPUT,
                        @bSuccess          OUTPUT,
                        @nErrNo            OUTPUT,
                        @cErrMsg           OUTPUT
                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 190679
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_GetKey
                        GOTO RollBackTran
                     END
            
                     -- Create new a PickDetail to hold the balance
                     INSERT INTO dbo.PickDetail (
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                        UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                        ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                        PickDetailKey,
                        Status, 
                        QTY,
                        TrafficCop,
                        OptimizeCop)
                     SELECT
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                        UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                        CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                        @cNewPickDetailKey,
                        Status, 
                        @nQTY - @nQTY_Bal, -- QTY
                        NULL, -- TrafficCop
                        '1'   -- OptimizeCop
                     FROM dbo.PickDetail WITH (NOLOCK)
            			WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
            				SET @nErrNo = 190680
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
                        GOTO RollBackTran
                     END
            
                     -- Split RefKeyLookup
                     IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
                     BEGIN
                        -- Insert into
                        INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
                        SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                        FROM RefKeyLookup WITH (NOLOCK) 
                        WHERE PickDetailKey = @cPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 190681
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RefKeyFail
                           GOTO RollBackTran
                        END
                     END
            
                     -- Change orginal PickDetail with exact QTY (with TrafficCop)
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                        QTY = @nQTY_Bal,
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME(),
                        Trafficcop = NULL
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 190682
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END

                     INSERT INTO @tActPD (PickDetailKey, LOT, QTY) VALUES (@cPickDetailKey, @cLOT, @nQTY_Bal)
                     SET @nQTY_Bal = 0
                  END
                  
                  IF @nQTY_Bal = 0
                     BREAK
               
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cLOT, @nQTY
               END
            END
         END
         
         -- Unallocate (task)
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail SET
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
         
         -- Unallocate (actual)
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail SET
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

         -- Reallocate (task)
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM @tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail SET
               LOT = @cActUCCLOT,
               -- DropID = @cActUCCNo,
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

         -- Reallocate (actual)
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM @tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail SET
               LOT = @cTaskLOT,
               -- DropID = @cTaskUCCNo,
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
         
         -- Locking
         IF @nTaskQTYReplen > 0 OR @nActQTYReplen > 0
         BEGIN
            -- Task
            UPDATE dbo.LOTxLOCxID SET
               QTYReplen = QTYReplen - @nTaskQTYReplen + @nActQTYReplen, 
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE LOT = @cTaskLOT
               AND LOC = @cFromLOC
               AND ID = @cFromID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 190683
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd LLI Fail
               GOTO RollBackTran
            END

            -- Actual
            UPDATE dbo.LOTxLOCxID SET
               QTYReplen = QTYReplen - @nActQTYReplen + @nTaskQTYReplen, 
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE LOT = @cActUCCLOT
               AND LOC = @cFromLOC
               AND ID = @cFromID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 190684
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd LLI Fail
               GOTO RollBackTran
            END
         END
         
         -- Booking (task)
         IF @nTaskPendingMoveIn > 0
         BEGIN
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
               ,'' --FromLOC
               ,'' --FromID
               ,'' --SuggLOC
               ,'' --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cUCCNo = @cTaskUCCNo
            IF @nErrNo <> 0
               GOTO RollbackTran

            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'
               ,@cFromLOC --FromLOC
               ,@cFromID  --FromID
               ,@cTaskToLOC --SuggLOC
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU = @cActUCCSKU -- @cTaskUCCSKU is not declare, anyway same as @cActUCCSKU
               ,@nPutawayQTY = @nTaskUCCQTY
               ,@cFromLOT = @cActUCCLOT
               ,@cToID = @cTaskToID
               ,@cUCCNo = @cActUCCNo
               ,@nFunc = @nFunc
            IF @nErrNo <> 0
            GOTO RollBackTran
         END

         -- Booking (actual)
         IF @nActPendingMoveIn > 0
         BEGIN
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
               ,'' --FromLOC
               ,'' --FromID
               ,'' --SuggLOC
               ,'' --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cUCCNo = @cActUCCNo
            IF @nErrNo <> 0
               GOTO RollbackTran

            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'
               ,@cFromLOC --FromLOC
               ,@cFromID  --FromID
               ,@cActToLOC --SuggLOC
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU = @cActUCCSKU
               ,@nPutawayQTY = @nActUCCQTY
               ,@cFromLOT = @cTaskLOT
               ,@cToID = @cActToID
               ,@cUCCNo = @cTaskUCCNo
               ,@nFunc = @nFunc
            IF @nErrNo <> 0
            GOTO RollBackTran
         END
      END
   END

CommitTran:
   -- Log UCC swap
   IF @cTaskUCCNo <> @cActUCCNo
   BEGIN
      INSERT INTO rdt.SwapUCC (Func, UCC, NewUCC, ReplenGroup, UCCStatus, NewUCCStatus)
      VALUES (@nFunc, @cTaskUCCNo, @cActUCCNo, @cReplenKey, @cTaskUCCStatus, @cActUCCStatus)
   END

   COMMIT TRAN rdt_896SwapUCC01
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_896SwapUCC01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO