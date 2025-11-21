SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_Move_PickDetail                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT common move                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2013-03-29 1.0  Ung      SOS259759 Move QTY Alloc                    */
/* 2013-11-06 1.1  TLTING   deadlock tune                               */
/* 2015-04-30 1.2  Ung      SOS339417 Performance tuning MoveQTYAlloc   */
/*                          SOS315975 Add MoveQTYPick                   */
/* 2016-03-24 1.3  Ung      SOS366906 Add UCC MoveQTYAlloc without task */
/* 2019-03-27 1.4  James    Allow move qty alloc/picked on UCC (james01)*/
/************************************************************************/

CREATE  PROCEDURE [RDT].[rdt_Move_PickDetail] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3),
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cMoveQTYAlloc NVARCHAR( 5),
   @cMoveQTYPick  NVARCHAR( 5),
   @cLOT          NVARCHAR( 10), -- FromLOT
   @cLOC          NVARCHAR( 10), -- FromLOC
   @cID           NVARCHAR( 18), -- FromID
   @cToLOC        NVARCHAR( 10),
   @cToID         NVARCHAR( 18), -- NULL means not changing ID. Blank ID is a valid ID
   @cSKU          NVARCHAR( 20), -- Either SKU or UCC only
   @cUCC          NVARCHAR( 20), --
   @nBal_Avail    INT,           -- For move by SKU or UCC, QTY must have value
   @nBal_Alloc    INT,
   @nBal_Pick     INT,
   @nLLI_QTY      INT, 
   @nLLI_Alloc    INT, 
   @nLLI_Pick     INT, 
   @nPD_Alloc     INT           OUTPUT,
   @nPD_Pick      INT           OUTPUT,
   @cMoveRefKey   NVARCHAR( 10) OUTPUT, 
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT, 
   @cTaskDetailKey NVARCHAR( 10) = '',
   @cOrderKey     NVARCHAR( 10) = '',
   @cDropID       NVARCHAR( 20) = '',
   @cCaseID       NVARCHAR( 20) = '' 
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @nQTYtoMove     INT
   DECLARE @nPD_QTY        INT
   DECLARE @cPickDetailKey NVARCHAR(10)
   DECLARE @cPDStatus      NVARCHAR(1)
   DECLARE @cPDStatusStart NVARCHAR(1)
   DECLARE @cPDStatusEnd   NVARCHAR(1)
   DECLARE @curPD CURSOR

   SET @cMoveRefKey = ''
   SET @nPD_Alloc = 0
   SET @nPD_Pick  = 0

   -- Calc PickDetail.Status range
   IF @cMoveQTYAlloc = '1' AND @cMoveQTYPick = '1'
      SELECT @cPDStatusStart = '0', @cPDStatusEnd = '5'
   ELSE IF @cMoveQTYAlloc = '1'
      SELECT @cPDStatusStart = '0', @cPDStatusEnd = '3'
   ELSE
      SELECT @cPDStatusStart = '5', @cPDStatusEnd = '5'

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN                    -- Begin our own transaction
   SAVE TRAN rdt_Move_PickDetail -- For rollback or commit only our own transaction

   -- Get new MoveRefKey
   EXECUTE dbo.nspg_GetKey
      'MOVEREFKEY',
      10 ,
      @cMoveRefKey OUTPUT,
      @bSuccess    OUTPUT,
      @nErrNo      OUTPUT,
      @cErrMsg     OUTPUT
   IF @bSuccess <> 1
   BEGIN
      SET @nErrNo = 80659
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
      GOTO RollBackTran
   END

   -- Move by LOC or ID alone
   IF @cSKU IS NULL AND
      @cUCC IS NULL
   BEGIN
      -- Loop affected PickDetail
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE LOT = @cLOT
            AND LOC = @cLOC
            AND ID = @cID
            AND Status BETWEEN @cPDStatusStart AND @cPDStatusEnd
            AND Status <> '4'
            AND QTY > 0         
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Stamp MoreRefKey
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            MoveRefKey = @cMoveRefKey,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 80651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END
   END

   -- Move by SKU or UCC
   IF @cSKU IS NOT NULL OR
      @cUCC IS NOT NULL
   BEGIN
      -- Move by UCC
      IF @cUCC IS NOT NULL
      BEGIN
         -- Get UCC's PickDetail
         IF @cTaskDetailKey <> ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey, Status, QTY
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID = @cID
                  AND Status BETWEEN @cPDStatusStart AND @cPDStatusEnd
                  AND Status <> '4'
                  AND QTY > 0
                  AND TaskDetailKey = @cTaskDetailKey

         ELSE IF @cCaseID <> ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey, Status, QTY
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID = @cID
                  AND Status BETWEEN @cPDStatusStart AND @cPDStatusEnd
                  AND Status <> '4'
                  AND QTY > 0
                  AND CaseID = @cCaseID

         ELSE IF @cDropID <> ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey, Status, QTY
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID = @cID
                  AND Status BETWEEN @cPDStatusStart AND @cPDStatusEnd
                  AND Status <> '4'
                  AND QTY > 0
                  AND DropID = @cDropID

         ELSE IF @cDropID = ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey, Status, QTY
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID = @cID
                  AND Status BETWEEN @cPDStatusStart AND @cPDStatusEnd
                  AND Status <> '4'
                  AND QTY > 0
                  AND DropID = @cUCC
      END
      
      -- Move by SKU
      IF @cSKU IS NOT NULL
      BEGIN
         -- Get affected PickDetail
         IF @cTaskDetailKey <> ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey, Status, QTY
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID = @cID
                  AND Status BETWEEN @cPDStatusStart AND @cPDStatusEnd
                  AND Status <> '4'
                  AND QTY > 0
                  AND TaskDetailKey = @cTaskDetailKey
         
         ELSE IF @cOrderKey <> ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey, Status, QTY
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID = @cID
                  AND Status BETWEEN @cPDStatusStart AND @cPDStatusEnd
                  AND Status <> '4'
                  AND QTY > 0
                  AND OrderKey = @cOrderKey

         ELSE IF @cCaseID <> ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey, Status, QTY
            FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID = @cID
                  AND Status BETWEEN @cPDStatusStart AND @cPDStatusEnd
                  AND Status <> '4'
                  AND QTY > 0
                  AND CaseID = @cCaseID

         ELSE IF @cDropID <> ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey, Status, QTY
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID = @cID
                  AND Status BETWEEN @cPDStatusStart AND @cPDStatusEnd
                  AND Status <> '4'
                  AND QTY > 0
                  AND DropID = @cDropID
         
         ELSE
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey, Status, QTY
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID = @cID
                  AND Status BETWEEN @cPDStatusStart AND @cPDStatusEnd
                  AND Status <> '4'
                  AND QTY > 0
      END
      
      -- Loop affected PickDetail
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cPDStatus, @nPD_QTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @cPDStatus = '5'
            SET @nQTYToMove = @nBal_Pick
         ELSE
            SET @nQTYToMove = @nBal_Alloc
         
         IF @nQTYToMove > 0
         BEGIN
            -- Exact match
            IF @nPD_QTY = @nQTYToMove
            BEGIN
               -- Unalloc affected PickDetail
               UPDATE dbo.PickDetail with (ROWLOCK) SET
                  MoveRefKey = @cMoveRefKey,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 80654
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
   
               IF @cPDStatus = '5'
               BEGIN
                  SET @nBal_Pick = @nBal_Pick - @nPD_QTY
                  SET @nPD_Pick = @nPD_Pick + @nPD_QTY
               END
               ELSE
               BEGIN
                  SET @nBal_Alloc = @nBal_Alloc - @nPD_QTY
                  SET @nPD_Alloc = @nPD_Alloc + @nPD_QTY
               END
            END
   
            -- PickDetail have less
            ELSE IF @nPD_QTY < @nQTYToMove
            BEGIN
               -- Unalloc affected PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  MoveRefKey = @cMoveRefKey,
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 80655
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
   
               IF @cPDStatus = '5'
               BEGIN
                  SET @nBal_Pick = @nBal_Pick - @nPD_QTY
                  SET @nPD_Pick = @nPD_Pick + @nPD_QTY
               END
               ELSE
               BEGIN
                  SET @nBal_Alloc = @nBal_Alloc - @nPD_QTY
                  SET @nPD_Alloc = @nPD_Alloc + @nPD_QTY
               END
            END
   
            -- PickDetail have more, need to split
            ELSE IF @nPD_QTY > @nQTYToMove
            BEGIN
               -- Get new PickDetailkey
               DECLARE @cNewPickDetailKey NVARCHAR( 10)
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @cNewPickDetailKey OUTPUT,
                  @bSuccess          OUTPUT,
                  @nErrNo            OUTPUT,
                  @cErrMsg           OUTPUT
               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 80656
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
                  GOTO RollBackTran
               END
   
               -- Create a new PickDetail to hold the balance
               INSERT INTO dbo.PickDetail (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
                  DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, Status,
                  PickDetailKey,
                  QTY,
                  TrafficCop,
                  OptimizeCop)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
                  DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, Status,
                  @cNewPickDetailKey,
                  @nPD_QTY - @nQTYToMove, -- QTY
                  NULL, --TrafficCop
                  '1'   --OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 80657
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
                  GOTO RollBackTran
               END
   
               -- Change original PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nQTYToMove,
                  MoveRefKey = @cMoveRefKey,
                  EditDate = GETDATE(),
                  EditWho = SUSER_SNAME(),
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 80658
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
   
               IF @cPDStatus = '5'
               BEGIN
                  SET @nBal_Pick = @nBal_Pick - @nQTYToMove
                  SET @nPD_Pick = @nPD_Pick + @nQTYToMove
               END
               ELSE
               BEGIN
                  SET @nBal_Alloc = @nBal_Alloc - @nQTYToMove
                  SET @nPD_Alloc = @nPD_Alloc + @nQTYToMove
               END
            END
         END
         
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cPDStatus, @nPD_QTY
      END
   END

   COMMIT TRAN rdt_Move_PickDetail -- Only commit change made in rdt_Move_Test
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Move_PickDetail -- Only rollback change made in rdt_Move_Test
Quit:
   -- Commit until the level we started
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
Fail:

GO