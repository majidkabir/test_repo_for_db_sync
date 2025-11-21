SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLCart_Confirm_Order01_Lottable                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 14-08-2019 1.0  Ung         WMS-10044 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Confirm_Order01_Lottable] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR(5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cType           NVARCHAR( 10) -- LOC = confirm LOC, CLOSETOTE/SHORTTOTE = confirm tote
   ,@cDPLKey         NVARCHAR( 10)
   ,@cCartID         NVARCHAR( 10) 
   ,@cToteID         NVARCHAR( 20) -- Required for confirm tote
   ,@cLOC            NVARCHAR( 10)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cNewToteID      NVARCHAR( 20) -- For close tote with balance
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
   ,@cLottableCode   NVARCHAR( 30) 
   ,@cLottable01     NVARCHAR( 18)  
   ,@cLottable02     NVARCHAR( 18)  
   ,@cLottable03     NVARCHAR( 18)  
   ,@dLottable04     DATETIME  
   ,@dLottable05     DATETIME  
   ,@cLottable06     NVARCHAR( 30) 
   ,@cLottable07     NVARCHAR( 30) 
   ,@cLottable08     NVARCHAR( 30) 
   ,@cLottable09     NVARCHAR( 30) 
   ,@cLottable10     NVARCHAR( 30) 
   ,@cLottable11     NVARCHAR( 30)
   ,@cLottable12     NVARCHAR( 30)
   ,@dLottable13     DATETIME
   ,@dLottable14     DATETIME
   ,@dLottable15     DATETIME
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
   DECLARE @nRowRef        INT
   DECLARE @nPTLKey        INT
   DECLARE @nQTY_PTL       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Task      INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
   DECLARE @nSystemQTY     INT
   DECLARE @nNewSystemQTY  INT
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cWhere         NVARCHAR( MAX)
                           
   DECLARE @cActToteID        NVARCHAR( 20)
   DECLARE @cPosition         NVARCHAR( 10)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cPickDetailKey    NVARCHAR( 10)
   DECLARE @cTaskDetailKey    NVARCHAR( 10)
   DECLARE @cNewTaskDetailKey NVARCHAR( 10)

   DECLARE @cUpdatePickDetail NVARCHAR( 1)
   DECLARE @cUpdateTaskDetail NVARCHAR( 1)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)

   DECLARE @curPTL   CURSOR
   DECLARE @curPD    CURSOR
   DECLARE @curTD    CURSOR

   -- Get storer config
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   SET @cUpdateTaskDetail = rdt.rdtGetConfig( @nFunc, 'UpdateTaskDetail', @cStorerKey)
   SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus <> '3'     -- 3=Pick in progress
      SET @cPickConfirmStatus = '5'  -- 5=Pick confirm
   
   SET @nQTY_Bal = @nQTY

   /***********************************************************************************************

                                                CONFIRM LOC 

   ***********************************************************************************************/
   IF @cType = 'LOC' 
   BEGIN
      -- Confirm entire LOC
      SET @cSQL = 
         ' SELECT PTLKey, DevicePosition, ExpectedQTY, SourceKey ' + 
         ' FROM PTL.PTLTran WITH (NOLOCK) ' + 
         ' WHERE DeviceProfileLogKey = @cDPLKey ' + 
            ' AND LOC = @cLOC ' + 
            ' AND SKU = @cSKU ' + 
            ' AND Status <> ''9'' '
            
      EXEC rdt.rdt_PTLCart_Confirm_Order01_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'PTLTran', 
         @cOrderKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
         @curPTL OUTPUT
         
      FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY, @cOrderKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get tote
         SELECT @cActToteID = ToteID FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND Position = @cPosition
         
         -- Transaction at order level
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_PTLCart_Confirm -- For rollback or commit only our own transaction
         
         -- Confirm PTLTran
         UPDATE PTL.PTLTran SET
            Status = '9', 
            QTY = ExpectedQTY, 
            DropID = @cActToteID, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE(), 
            TrafficCop = NULL
         WHERE PTLKey = @nPTLKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 139601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO RollBackTran
         END

         -- Event log
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '3', -- Picking
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cOrderKey     = @cOrderKey,
            @cSKU          = @cSKU,
            @cLocation     = @cLOC,
            @nQTY          = @nExpectedQTY,
            @cDropID       = @cActToteID,
            @cRefNo1       = @cType,
            @cRefNo2       = @cDPLKey,
            @cRefNo3       = @nPTLKey,
            @cRefNo4       = @cPosition,
            @cRefNo5       = @cCartID

         -- Update PickDetail
         IF @cUpdatePickDetail = '1'
         BEGIN
            -- Dynamic lottable
            SET @cWhere = ''
            IF @cLottableCode <> ''
               EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 4, 'LA',   
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
                  @cWhere   OUTPUT,  
                  @nErrNo   OUTPUT,  
                  @cErrMsg  OUTPUT  

            SET @cSQL = 
               ' SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0) ' + 
               ' FROM Orders O WITH (NOLOCK) ' + 
                  ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                  ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE O.OrderKey = @cOrderKey ' + 
                  ' AND PD.LOC = @cLOC ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.Status < @cPickConfirmStatus ' + 
                  ' AND PD.Status <> ''4'' ' + 
                  ' AND PD.QTY > 0 ' + 
                  ' AND PD.UOM NOT IN (''1'', ''2'') ' + 
                  ' AND O.Status <> ''CANC'' ' + 
                  ' AND O.SOStatus <> ''CANC'' ' + 
                  CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END                 
               
               SET @cSQLParam =   
                  ' @cOrderKey   NVARCHAR( 10), ' +   
                  ' @cLOC        NVARCHAR( 10), ' +   
                  ' @cSKU        NVARCHAR( 15), ' +   
                  ' @cPickConfirmStatus NVARCHAR( 1), ' +   
                  ' @cLottable01 NVARCHAR( 18), ' +   
                  ' @cLottable02 NVARCHAR( 18), ' +   
                  ' @cLottable03 NVARCHAR( 18), ' +   
                  ' @dLottable04 DATETIME,      ' +   
                  ' @dLottable05 DATETIME,      ' +   
                  ' @cLottable06 NVARCHAR( 30), ' +   
                  ' @cLottable07 NVARCHAR( 30), ' +   
                  ' @cLottable08 NVARCHAR( 30), ' +   
                  ' @cLottable09 NVARCHAR( 30), ' +   
                  ' @cLottable10 NVARCHAR( 30), ' +   
                  ' @cLottable11 NVARCHAR( 30), ' +   
                  ' @cLottable12 NVARCHAR( 30), ' +   
                  ' @dLottable13 DATETIME,      ' +   
                  ' @dLottable14 DATETIME,      ' +   
                  ' @dLottable15 DATETIME,      ' + 
                  ' @nQTY_PD     INT OUTPUT     '  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
               @cOrderKey, @cLOC, @cSKU, @cPickConfirmStatus, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
               @nQTY_PD OUTPUT
      
            -- Check PickDetail changed
            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
               SET @nErrNo = 139602
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END            

            -- Loop PickDetail
            SET @cSQL = 
               ' SELECT PD.PickDetailKey, QTY ' + 
               ' FROM Orders O WITH (NOLOCK) ' + 
                  ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                  ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE O.OrderKey = @cOrderKey ' + 
                  ' AND PD.LOC = @cLOC ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.Status < @cPickConfirmStatus ' + 
                  ' AND PD.Status <> ''4'' ' + 
                  ' AND PD.QTY > 0 ' + 
                  ' AND PD.UOM NOT IN (''1'', ''2'') ' + 
                  ' AND O.Status <> ''CANC'' ' + 
                  ' AND O.SOStatus <> ''CANC'' '

            IF CURSOR_STATUS( 'variable', '@curPD') IN (0, 1)
               DEALLOCATE @curPD

            EXEC rdt.rdt_PTLCart_Confirm_Order01_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'LA', 
               @cOrderKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
               @curPD OUTPUT

            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Confirm PickDetail
               UPDATE PickDetail SET
                  Status = @cPickConfirmStatus, 
                  DropID = @cActToteID, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 139603
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
            END
         END

         -- Update TaskDetail
         IF @cUpdateTaskDetail = '1'
         BEGIN
            -- Loop TaskDetail
            SET @cSQL = 
               ' SELECT TD.TaskDetailKey ' + 
               ' FROM TaskDetail TD WITH (NOLOCK) ' + 
                  ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = TD.LOT) ' + 
               ' WHERE TD.TaskType = ''FPP'' ' + 
                  ' AND TD.StorerKey = @cStorerKey ' + 
                  ' AND TD.OrderKey = @cOrderKey ' + 
                  ' AND TD.FromLOC = @cLOC ' + 
                  ' AND TD.SKU = @cSKU ' + 
                  ' AND TD.Status = ''3'' '
            
            IF CURSOR_STATUS( 'variable', '@curTD') IN (0, 1)
               DEALLOCATE @curTD

            EXEC rdt.rdt_PTLCart_Confirm_Order01_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'LA', 
               @cOrderKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
               @curTD OUTPUT

            FETCH NEXT FROM @curTD INTO @cTaskDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE TaskDetail SET
                  Status = '9', 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 139630
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curTD INTO @cTaskDetailKey
            END
         END
         
         -- Commit order level
         COMMIT TRAN rdt_PTLCart_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY, @cOrderKey
      END
   END


   /***********************************************************************************************

                                                CONFIRM TOTE 

   ***********************************************************************************************/
   -- Confirm tote
   IF @cType <> 'LOC'
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_PTLCart_Confirm -- For rollback or commit only our own transaction
      
      -- Close with QTY or short 
      IF (@cType = 'CLOSETOTE' AND @nQTY > 0) OR
         (@cType = 'SHORTTOTE')
      BEGIN
         -- Get tote info
         SELECT 
            @cPosition = Position, 
            @cOrderKey = OrderKey
         FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
         WHERE CartID = @cCartID 
            AND ToteID = @cToteID

         SET @nExpectedQTY = NULL

         -- PTLTran
         SET @cSQL = 
            ' SELECT PTLKey, ExpectedQTY ' + 
            ' FROM PTL.PTLTran WITH (NOLOCK) ' + 
            ' WHERE DeviceProfileLogKey = @cDPLKey ' + 
               ' AND LOC = @cLOC ' + 
               ' AND SKU = @cSKU ' + 
               ' AND DevicePosition = @cPosition ' + 
               ' AND Status <> ''9'' '

         EXEC rdt.rdt_PTLCart_Confirm_Order01_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'PTLTran', 
            @cOrderKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
            @curPTL OUTPUT

         FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @nExpectedQTY IS NULL
               SET @nExpectedQTY = @nQTY_PTL
            
            -- Exact match
            IF @nQTY_PTL = @nQTY_Bal
            BEGIN
               -- Confirm PTLTran
               UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                  Status = '9', 
                  QTY = ExpectedQTY, 
                  DropID = @cToteID, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 139604
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END

               -- Event log
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '3', -- Picking
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerkey,
                  @cOrderKey     = @cOrderKey,
                  @cSKU          = @cSKU,
                  @cLocation     = @cLOC,
                  @nQTY          = @nExpectedQTY,
                  @cDropID       = @cToteID,
                  @cRefNo1       = @cType,
                  @cRefNo2       = @cDPLKey,
                  @cRefNo3       = @nPTLKey,
                  @cRefNo4       = @cPosition,
                  @cRefNo5       = @cCartID
      
               SET @nQTY_Bal = 0 -- Reduce balance
            END
            
            -- PTLTran have less
      		ELSE IF @nQTY_PTL < @nQTY_Bal
            BEGIN
               -- Confirm PickDetail
               UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                  Status = '9',
                  QTY = ExpectedQTY, 
                  DropID = @cToteID, 
                  EditDate = GETDATE(), 
                  EditWho  = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 139605
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                  GOTO RollBackTran
               END

               -- Event log
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '3', -- Picking
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerkey,
                  @cOrderKey     = @cOrderKey,
                  @cSKU          = @cSKU,
                  @cLocation     = @cLOC,
                  @nQTY          = @nExpectedQTY,
                  @cDropID       = @cToteID,
                  @cRefNo1       = @cType,
                  @cRefNo2       = @cDPLKey,
                  @cRefNo3       = @nPTLKey,
                  @cRefNo4       = @cPosition,
                  @cRefNo5       = @cCartID

               SET @nQTY_Bal = @nQTY_Bal - @nQTY_PTL -- Reduce balance
            END
            
            -- PTLTran have more
      		ELSE IF @nQTY_PTL > @nQTY_Bal
            BEGIN
               -- Short pick
               IF @cType = 'SHORTTOTE' AND @nQTY_Bal = 0 -- Don't need to split
               BEGIN
                  -- Confirm PTLTran
                  UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                     Status = '9',
                     QTY = 0, 
                     DropID = @cToteID, 
                     TrafficCop = NULL, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME() 
                  WHERE PTLKey = @nPTLKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 139606
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                     GOTO RollBackTran
                  END

                  -- Event log
                  EXEC RDT.rdt_STD_EventLog
                     @cActionType   = '3', -- Picking
                     @nMobileNo     = @nMobile,
                     @nFunctionID   = @nFunc,
                     @cFacility     = @cFacility,
                     @cStorerKey    = @cStorerkey,
                     @cOrderKey     = @cOrderKey,
                     @cSKU          = @cSKU,
                     @cLocation     = @cLOC,
                     @nQTY          = @nExpectedQTY,
                     @cDropID       = @cToteID,
                     @cRefNo1       = @cType,
                     @cRefNo2       = @cDPLKey,
                     @cRefNo3       = @nPTLKey,
                     @cRefNo4       = @cPosition,
                     @cRefNo5       = @cCartID
               END
               ELSE
               BEGIN -- Have balance, need to split
                  -- Create new a PTLTran to hold the balance
                  INSERT INTO PTL.PTLTran (
                     ExpectedQty, QTY, TrafficCop, 
                     IPAddress, DeviceID, DevicePosition, Status, PTLType, DropID, OrderKey, Storerkey, SKU, LOC, LOT, Remarks, 
                     DeviceProfileLogKey, ArchiveCop, SourceKey, ConsigneeKey, CaseID, LightUp, LightMode, LightSequence, UOM, RefPTLKey, 
                     Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                     Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                     Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
                  SELECT 
                     @nQTY_PTL - @nQTY_Bal, @nQTY_PTL - @nQTY_Bal, NULL, 
                     IPAddress, DeviceID, DevicePosition, Status, PTLType, '', OrderKey, Storerkey, SKU, LOC, LOT, Remarks, 
                     DeviceProfileLogKey, ArchiveCop, SourceKey, ConsigneeKey, CaseID, LightUp, LightMode, LightSequence, UOM, RefPTLKey, 
                     Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                     Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                     Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
                  FROM PTL.PTLTran WITH (NOLOCK) 
         			WHERE PTLKey = @nPTLKey			            
                  IF @@ERROR <> 0
                  BEGIN
         				SET @nErrNo = 139607
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PTL Fail
                     GOTO RollBackTran
                  END
         
                  -- Confirm orginal PTLTran with exact QTY
                  UPDATE PTL.PTLTran WITH (ROWLOCK) SET 
                     Status = '9',
                     ExpectedQty = @nQTY_Bal, 
                     QTY = @nQTY_Bal, 
                     DropID = @cToteID, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME(), 
                     Trafficcop = NULL
                  WHERE PTLKey = @nPTLKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 139608
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                     GOTO RollBackTran
                  END

                  -- Event log
                  EXEC RDT.rdt_STD_EventLog
                     @cActionType   = '3', -- Picking
                     @nMobileNo     = @nMobile,
                     @nFunctionID   = @nFunc,
                     @cFacility     = @cFacility,
                     @cStorerKey    = @cStorerkey,
                     @cOrderKey     = @cOrderKey,
                     @cSKU          = @cSKU,
                     @cLocation     = @cLOC,
                     @nQTY          = @nExpectedQTY,
                     @cDropID       = @cToteID,
                     @cRefNo1       = @cType,
                     @cRefNo2       = @cDPLKey,
                     @cRefNo3       = @nPTLKey,
                     @cRefNo4       = @cPosition,
                     @cRefNo5       = @cCartID

                  SET @nQTY_Bal = 0 -- Reduce balance
               END
            END
            
            -- Exit condition
            IF @cType = 'CLOSETOTE' AND @nQTY_Bal = 0
               BREAK
            
            FETCH NEXT FROM @curPTL INTO @nPTLKey, @nQTY_PTL
         END
               
         -- PickDetail
         IF @cUpdatePickDetail = '1'
         BEGIN            
            -- Dynamic lottable
            SET @cWhere = ''
            IF @cLottableCode <> ''
               EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 4, 'LA',   
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
                  @cWhere   OUTPUT,  
                  @nErrNo   OUTPUT,  
                  @cErrMsg  OUTPUT  

            SET @cSQL = 
               ' SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0) ' + 
               ' FROM Orders O WITH (NOLOCK) ' + 
                  ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                  ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE O.OrderKey = @cOrderKey ' + 
                  ' AND PD.LOC = @cLOC ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.Status < @cPickConfirmStatus ' + 
                  ' AND PD.Status <> ''4'' ' + 
                  ' AND PD.QTY > 0 ' + 
                  ' AND PD.UOM NOT IN (''1'', ''2'') ' + 
                  ' AND O.Status <> ''CANC'' ' + 
                  ' AND O.SOStatus <> ''CANC'' ' + 
                  CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END                 
               
            SET @cSQLParam =   
               ' @cOrderKey   NVARCHAR( 10), ' +   
               ' @cLOC        NVARCHAR( 10), ' +   
               ' @cSKU        NVARCHAR( 15), ' +   
               ' @cPickConfirmStatus NVARCHAR( 1), ' +   
               ' @cLottable01 NVARCHAR( 18), ' +   
               ' @cLottable02 NVARCHAR( 18), ' +   
               ' @cLottable03 NVARCHAR( 18), ' +   
               ' @dLottable04 DATETIME,      ' +   
               ' @dLottable05 DATETIME,      ' +   
               ' @cLottable06 NVARCHAR( 30), ' +   
               ' @cLottable07 NVARCHAR( 30), ' +   
               ' @cLottable08 NVARCHAR( 30), ' +   
               ' @cLottable09 NVARCHAR( 30), ' +   
               ' @cLottable10 NVARCHAR( 30), ' +   
               ' @cLottable11 NVARCHAR( 30), ' +   
               ' @cLottable12 NVARCHAR( 30), ' +   
               ' @dLottable13 DATETIME,      ' +   
               ' @dLottable14 DATETIME,      ' +   
               ' @dLottable15 DATETIME,      ' + 
               ' @nQTY_PD     INT OUTPUT     '  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
               @cOrderKey, @cLOC, @cSKU, @cPickConfirmStatus, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
               @nQTY_PD OUTPUT

            -- Check PickDetail changed
            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
               SET @nErrNo = 139609
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
               GOTO RollBackTran
            END
            
            -- For calculation
            SET @nQTY_Bal = @nQTY -- @nQTY_PD --@nQTY -- (ChewKP01) 
         
            -- Get PickDetail candidate
            SET @cSQL = 
               ' SELECT PickDetailKey, QTY ' + 
               ' FROM Orders O WITH (NOLOCK) ' + 
                  ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                  ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE O.OrderKey = @cOrderKey ' + 
                  ' AND PD.LOC = @cLOC ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.Status < @cPickConfirmStatus ' + 
                  ' AND PD.Status <> ''4'' ' + 
                  ' AND PD.QTY > 0 ' + 
                  ' AND PD.UOM NOT IN (''1'', ''2'') ' + 
                  ' AND O.Status <> ''CANC'' ' + 
                  ' AND O.SOStatus <> ''CANC'' '

            EXEC rdt.rdt_PTLCart_Confirm_Order01_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'LA', 
               @cOrderKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
               @curPD OUTPUT

            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD 
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Exact match
               IF @nQTY_PD = @nQTY_Bal
               BEGIN
                  -- Confirm PickDetail
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                     Status = @cPickConfirmStatus,
                     DropID = @cToteID, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME() 
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 139610
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END
         
                  SET @nQTY_Bal = 0 -- Reduce balance
               END
               
               -- PickDetail have less
         		ELSE IF @nQTY_PD < @nQTY_Bal
               BEGIN
                  -- Confirm PickDetail
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                     Status = @cPickConfirmStatus,
                     DropID = @cToteID, 
                     EditDate = GETDATE(), 
                     EditWho  = SUSER_SNAME() 
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 139611
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                     GOTO RollBackTran
                  END
         
                  SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
               END
               
               -- PickDetail have more
         		ELSE IF @nQTY_PD > @nQTY_Bal
               BEGIN
                  -- Short pick
                  IF @cType = 'SHORTTOTE' AND @nQTY_Bal = 0 -- Don't need to split
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        Status = '4',
                        DropID = @cToteID, 
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME(),
                        TrafficCop = NULL
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 139612
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                  END
                  ELSE
                  BEGIN -- Have balance, need to split
         
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
                        SET @nErrNo = 139613
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
                        GOTO RollBackTran
                     END
            
                     -- Create new a PickDetail to hold the balance
                     INSERT INTO dbo.PickDetail (
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, 
                        UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
                        ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
                        PickDetailKey, 
                        QTY, 
                        TrafficCop,
                        OptimizeCop)
                     SELECT 
                        CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, 
                        UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 
                        CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                        EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
                        @cNewPickDetailKey, 
                        @nQTY_PD - @nQTY_Bal, -- QTY
                        NULL, -- TrafficCop
                        '1'   -- OptimizeCop
                     FROM dbo.PickDetail WITH (NOLOCK) 
            			WHERE PickDetailKey = @cPickDetailKey			            
                     IF @@ERROR <> 0
                     BEGIN
            				SET @nErrNo = 139614
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
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
                           SET @nErrNo = 139615
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                           GOTO RollBackTran
                        END
                     END
                     
                     -- Change orginal PickDetail with exact QTY (with TrafficCop)
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        QTY = @nQTY_Bal, 
                        DropID = @cToteID, 
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME(), 
                        Trafficcop = NULL
                     WHERE PickDetailKey = @cPickDetailKey 
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 139616
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END
            
                     -- Confirm orginal PickDetail with exact QTY
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        Status = @cPickConfirmStatus,
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME() 
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 139617
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END

                     -- Short pick
                     IF @cType = 'SHORTTOTE'
                     BEGIN
                        -- Confirm PickDetail
                        UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                           Status = '4',
                           DropID = @cToteID, 
                           EditDate = GETDATE(), 
                           EditWho  = SUSER_SNAME(),
                           TrafficCop = NULL
                        WHERE PickDetailKey = @cNewPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 139629
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                           GOTO RollBackTran
                        END
                     END
                     
                     SET @nQTY_Bal = 0 -- Reduce balance
                  END
               END
         
               -- Exit condition
               IF @cType = 'CLOSETOTE' AND @nQTY_Bal = 0
                  BREAK
         
               FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD 
            END 
         END

         -- Update TaskDetail
         IF @cUpdateTaskDetail = '1'
         BEGIN
            -- For calculation
            SET @nQTY_Bal = @nQTY

            -- Loop TaskDetail
            SET @cSQL = 
               ' SELECT TD.TaskDetailKey, TD.QTY, TD.SystemQTY ' + 
               ' FROM TaskDetail TD WITH (NOLOCK) ' + 
                  ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = TD.LOT) ' + 
               ' WHERE TD.TaskType = ''FPP'' ' + 
                  ' AND TD.StorerKey = @cStorerKey ' + 
                  ' AND TD.OrderKey = @cOrderKey ' + 
                  ' AND TD.FromLOC = @cLOC ' + 
                  ' AND TD.SKU = @cSKU ' + 
                  ' AND TD.Status = ''3'' '
            
            IF CURSOR_STATUS( 'variable', '@curTD') IN (0, 1)
               DEALLOCATE @curTD

            EXEC rdt.rdt_PTLCart_Confirm_Order01_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'LA', 
               @cOrderKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
               @curTD OUTPUT

            FETCH NEXT FROM @curTD INTO @cTaskDetailKey, @nQTY_Task, @nSystemQTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Exact match
               IF @nQTY_Task <= @nQTY
               BEGIN
                  UPDATE TaskDetail SET
                     Status = '9', 
                     QTY = @nQTY,
                     EditDate = GETDATE(), 
                     EditWho = SUSER_SNAME(), 
                     TrafficCop = NULL
                  WHERE TaskDetailKey = @cTaskDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 139631
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
                     GOTO RollBackTran
                  END
               END
               
               -- TaskDetail have more
               ELSE 
               BEGIN
                  -- Short pick
                  IF @cType = 'SHORTTOTE'
                  BEGIN
                     -- Confirm TaskDetail
                     UPDATE dbo.TaskDetail SET 
                        Status = '9',
                        QTY = @nQTY, 
                        EndTime = GETDATE(),
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME(),
                        TrafficCop = NULL
                     WHERE TaskDetailKey = @cTaskDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 139632
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
                        GOTO RollBackTran
                     END
                  END
                  ELSE
                  BEGIN
                     -- Get new TaskDetailKey
                     SET @bSuccess = 1
                     EXECUTE dbo.nspg_getkey
                        'TaskDetailKey'
                        , 10
                        , @cNewTaskDetailKey OUTPUT
                        , @bSuccess  OUTPUT
                        , @nErrNo    OUTPUT
                        , @cErrMsg   OUTPUT
                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 139633
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
                        GOTO RollBackTran
                     END
                     
                     -- Calc SystemQTY
                     IF @nQTY <= @nSystemQTY
                     BEGIN
                        SET @nNewSystemQTY = @nSystemQTY - @nQTY
                        SET @nSystemQTY = @nQTY
                     END
                     ELSE
                        SET @nNewSystemQTY = 0
                     
                     -- Insert TaskDetail
                     INSERT INTO TaskDetail (
                        TaskDetailKey, RefTaskKey, ListKey, Status, UserKey, ReasonKey, DropID, QTY, SystemQTY, ToLOC, ToID, 
                        TaskType, Storerkey, Sku, LOT, UOM, UOMQTY, FromLOC, LogicalFromLOC, FromID, LogicalToLOC, CaseID, PickMethod, StatusMsg, Priority, SourcePriority, HoldKey, UserPosition, UserKeyOverRide, SourceType, SourceKey, PickDetailKey, OrderKey, OrderLineNumber, WaveKey, Message01, Message02, Message03, LoadKey, AreaKey, GroupKey)
                     SELECT
                        @cNewTaskDetailKey, @cTaskDetailKey, '', '3', UserKey, '', '', (@nQTY_Task - @nQTY), @nNewSystemQTY, ToLOC, ToID, 
                        TaskType, Storerkey, Sku, LOT, UOM, UOMQTY, FromLOC, LogicalFromLOC, FromID, LogicalToLOC, CaseID, PickMethod, StatusMsg, Priority, SourcePriority, HoldKey, UserPosition, UserKeyOverRide, SourceType, SourceKey, PickDetailKey, OrderKey, OrderLineNumber, WaveKey, Message01, Message02, Message03, LoadKey, AreaKey, GroupKey
                     FROM TaskDetail WITH (NOLOCK)
                     WHERE TaskDetailKey = @cTaskDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 139634
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS Task Fail
                        GOTO RollBackTran
                     END
               
                     -- Update Task
                     UPDATE dbo.TaskDetail SET
                        Status = '9', -- Picked, 
                        QTY = @nQTY, 
                        EndTime = GETDATE(),
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME(), 
                        Trafficcop = NULL
                     WHERE TaskDetailKey = @cTaskDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 139635
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
                        GOTO RollBackTran
                     END
                  END
               END

               -- Exit condition
               IF @cType = 'CLOSETOTE' AND @nQTY_Bal = 0
                  BREAK

               FETCH NEXT FROM @curTD INTO @cTaskDetailKey, @nQTY_Task, @nSystemQTY
            END
         END
      END
      
      -- Update new tote
      IF @cType = 'CLOSETOTE' AND @cNewToteID <> ''
      BEGIN
         -- Get RowRef
         SELECT @nRowRef = RowRef FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID = @cToteID
         
         -- Change Tote on rdtPTLCartLog
         UPDATE rdt.rdtPTLCartLog SET
            ToteID = @cNewToteID
         WHERE RowRef = @nRowRef 
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 139618
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
            GOTO RollBackTran
         END
      END
      
      -- Auto short all subsequence tote
      IF @cType = 'SHORTTOTE'
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'AutoShortRemainTote', @cStorerKey) = '1'
         BEGIN
            SET @cSQL = 
               ' SELECT PTLKey, DevicePosition, ExpectedQTY, OrderKey ' + 
               ' FROM PTL.PtlTran WITH (NOLOCK) ' + 
               ' WHERE DeviceProfileLogKey = @cDPLKey ' + 
                  ' AND LOC = @cLOC ' + 
                  ' AND SKU = @cSKU ' + 
                  ' AND Status <> ''9'' '
      
            IF CURSOR_STATUS( 'variable', '@curPD') IN (0, 1)
               DEALLOCATE @curPTL

            EXEC rdt.rdt_PTLCart_Confirm_Order01_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'PTLTran', 
               @cOrderKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
               @curPTL OUTPUT

            FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY, @cOrderKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get tote
               SELECT @cActToteID = ToteID FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND Position = @cPosition
               
               -- Confirm PTLTran
               UPDATE PTL.PTLTran SET
                  Status = '9', 
                  QTY = 0, 
                  DropID = @cActToteID, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 139619
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END

               -- Event log
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '3', -- Picking
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerkey,
                  @cOrderKey     = @cOrderKey,
                  @cSKU          = @cSKU,
                  @cLocation     = @cLOC,
                  @nQTY          = @nExpectedQTY,
                  @cDropID       = @cToteID,
                  @cRefNo1       = @cType,
                  @cRefNo2       = @cDPLKey,
                  @cRefNo3       = @nPTLKey,
                  @cRefNo4       = @cPosition,
                  @cRefNo5       = @cCartID

               -- Update PickDetail
               IF @cUpdatePickDetail = '1'
               BEGIN
                  -- Dynamic lottable
                  SET @cWhere = ''
                  IF @cLottableCode <> ''
                     EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 4, 'LA',   
                        @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
                        @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
                        @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
                        @cWhere   OUTPUT,  
                        @nErrNo   OUTPUT,  
                        @cErrMsg  OUTPUT  

                  SET @cSQL = 
                     ' SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0) ' + 
                     ' FROM Orders O WITH (NOLOCK) ' + 
                        ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                        ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                     ' WHERE O.OrderKey = @cOrderKey ' + 
                        ' AND PD.LOC = @cLOC ' + 
                        ' AND PD.SKU = @cSKU ' + 
                        ' AND PD.Status < @cPickConfirmStatus ' + 
                        ' AND PD.Status <> ''4'' ' + 
                        ' AND PD.QTY > 0 ' + 
                        ' AND PD.UOM NOT IN (''1'', ''2'') ' + 
                        ' AND O.Status <> ''CANC'' ' + 
                        ' AND O.SOStatus <> ''CANC'' ' + 
                        CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END                 
                     
                  SET @cSQLParam =   
                     ' @cOrderKey   NVARCHAR( 10), ' +   
                     ' @cLOC        NVARCHAR( 10), ' +   
                     ' @cSKU        NVARCHAR( 15), ' +   
                     ' @cPickConfirmStatus NVARCHAR( 1), ' +   
                     ' @cLottable01 NVARCHAR( 18), ' +   
                     ' @cLottable02 NVARCHAR( 18), ' +   
                     ' @cLottable03 NVARCHAR( 18), ' +   
                     ' @dLottable04 DATETIME,      ' +   
                     ' @dLottable05 DATETIME,      ' +   
                     ' @cLottable06 NVARCHAR( 30), ' +   
                     ' @cLottable07 NVARCHAR( 30), ' +   
                     ' @cLottable08 NVARCHAR( 30), ' +   
                     ' @cLottable09 NVARCHAR( 30), ' +   
                     ' @cLottable10 NVARCHAR( 30), ' +   
                     ' @cLottable11 NVARCHAR( 30), ' +   
                     ' @cLottable12 NVARCHAR( 30), ' +   
                     ' @dLottable13 DATETIME,      ' +   
                     ' @dLottable14 DATETIME,      ' +   
                     ' @dLottable15 DATETIME,      ' + 
                     ' @nQTY_PD     INT OUTPUT     '  

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
                     @cOrderKey, @cLOC, @cSKU, @cPickConfirmStatus, 
                     @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
                     @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
                     @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
                     @nQTY_PD OUTPUT

                  -- Get PickDetail tally PTLTran
                  IF @nQTY_PD <> @nExpectedQTY
                  BEGIN
                     SET @nErrNo = 139620
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                     GOTO RollBackTran
                  END
                  
                  -- Loop PickDetail
                  SET @cSQL = 
                     ' SELECT PickDetailKey ' + 
                     ' FROM Orders O WITH (NOLOCK) ' + 
                        ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                        ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                     ' WHERE O.OrderKey = @cOrderKey ' + 
                        ' AND PD.LOC = @cLOC ' + 
                        ' AND PD.SKU = @cSKU ' + 
                        ' AND PD.Status < @cPickConfirmStatus ' + 
                        ' AND PD.Status <> ''4'' ' + 
                        ' AND PD.QTY > 0 ' + 
                        ' AND PD.UOM NOT IN (''1'', ''2'') ' + 
                        ' AND O.Status <> ''CANC'' ' +  
                        ' AND O.SOStatus <> ''CANC'' '

                  IF CURSOR_STATUS( 'variable', '@curPD') IN (0, 1)
                     DEALLOCATE @curPD
                           
                  EXEC rdt.rdt_PTLCart_Confirm_Order01_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'LA', 
                     @cOrderKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
                     @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                     @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                     @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
                     @curPD OUTPUT

                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE PickDetail SET
                        Status = '4', 
                        DropID = @cActToteID, 
                        EditWho = SUSER_SNAME(), 
                        EditDate = GETDATE()
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 139621
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  END
               END

               -- Update TaskDetail
               IF @cUpdateTaskDetail = '1'
               BEGIN
                  -- Loop TaskDetail
                  SET @cSQL = 
                     ' SELECT TD.TaskDetailKey ' + 
                     ' FROM TaskDetail TD WITH (NOLOCK) ' + 
                        ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = TD.LOT) ' + 
                     ' WHERE TD.TaskType = ''FPP'' ' + 
                        ' AND TD.StorerKey = @cStorerKey ' + 
                        ' AND TD.OrderKey = @cOrderKey ' + 
                        ' AND TD.FromLOC = @cLOC ' + 
                        ' AND TD.SKU = @cSKU ' + 
                        ' AND TD.Status = ''3'' '
                  
                  IF CURSOR_STATUS( 'variable', '@curTD') IN (0, 1)
                     DEALLOCATE @curTD

                  EXEC rdt.rdt_PTLCart_Confirm_Order01_LottableCursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'LA', 
                     @cOrderKey, @cPickConfirmStatus, @cDPLKey, @cLOC, @cSKU, @nQTY, @cPosition, @cLottableCode, 
                     @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                     @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                     @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
                     @curTD OUTPUT

                  FETCH NEXT FROM @curTD INTO @cTaskDetailKey
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     UPDATE TaskDetail SET
                        Status = '9', 
                        QTY = @nQTY,
                        EditDate = GETDATE(), 
                        EditWho = SUSER_SNAME(), 
                        TrafficCop = NULL
                     WHERE TaskDetailKey = @cTaskDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 139636
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curTD INTO @cTaskDetailKey
                  END
               END
               
               FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY, @cOrderKey
            END
         END
      END

      COMMIT TRAN rdt_PTLCart_Confirm
   END
      
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO