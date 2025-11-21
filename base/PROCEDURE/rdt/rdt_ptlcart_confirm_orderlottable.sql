SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLCart_Confirm_OrderLottable                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 04-01-2018 1.0  Ung         WMS-3549 Created                         */
/* 26-01-2018 1.1  Ung         Change to PTL.Schema                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Confirm_OrderLottable] (
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
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cWhere         NVARCHAR( MAX)
   
   DECLARE @nRowRef        INT
   DECLARE @nPTLKey        INT
   DECLARE @nQTY_PTL       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
                           
   DECLARE @cActToteID     NVARCHAR( 20)
   DECLARE @cPosition      NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cDelOrderKey   NVARCHAR( 10) 

   DECLARE @cPickConfirmStatus   NVARCHAR(1)
   DECLARE @cUpdatePickDetail    NVARCHAR(1)
   DECLARE @cUpdatePTLTranEcom   NVARCHAR(1)
          
   DECLARE @curPTL CURSOR
   DECLARE @curPD  CURSOR
   DECLARE @curPTLCanc  CURSOR

   -- Get storer config
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   SET @cUpdatePTLTranEcom = rdt.rdtGetConfig( @nFunc, 'UpdatePTLTranEcom', @cStorerKey)
   SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus <> '3'     -- 3=Pick in progress
      SET @cPickConfirmStatus = '5'  -- 5=Pick confirm
   
   SET @nQTY_Bal = @nQTY

   /***********************************************************************************************

                                                CONFIRM LOC 

   ***********************************************************************************************/
   -- Confirm entire LOC
   IF @cType = 'LOC' 
   BEGIN
      /*
      SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PTLKey, DevicePosition, ExpectedQTY, OrderKey
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceProfileLogKey = @cDPLKey
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND Status <> '9'
      OPEN @curPTL
      */
      SET @cSQL = 
         ' SELECT PTLKey, DevicePosition, ExpectedQTY, OrderKey ' + 
         ' FROM PTL.PTLTran WITH (NOLOCK) ' + 
         ' WHERE DeviceProfileLogKey = @cDPLKey ' + 
            ' AND LOC = @cLOC ' + 
            ' AND SKU = @cSKU ' + 
            ' AND Status <> ''9'' '
            
      EXEC rdt.rdt_PTLCart_Confirm_OrderLottable_Cursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'PTLTran', 
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
            SET @nErrNo = 172401
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO RollBackTran
         END
         
         -- Update PickDetail
         IF @cUpdatePickDetail = '1'
         BEGIN
            -- Get PickDetail tally PTLTran
            SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
            FROM Orders O WITH (NOLOCK) 
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            WHERE O.OrderKey = @cOrderKey
               AND LOC = @cLOC
               AND SKU = @cSKU
               AND PD.Status < @cPickConfirmStatus
               AND PD.Status <> '4'
               AND PD.QTY > 0
               AND O.Status <> 'CANC' 
               AND O.SOStatus <> 'CANC'

            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
               -- (ChewKP01) 
               IF @cUpdatePTLTranEcom = '1' AND EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                                                         WHERE OrderKey = @cOrderKey
                                                         AND Status = 'CANC'
                                                         AND SOStatus = 'CANC' ) 
               BEGIN
                  IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                                  INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
                                  WHERE PD.OrderKey = @cOrderKey
                                  AND PD.SKU = @cSKU
                                  AND PD.Loc = @cLoc
                                  AND O.Status = 'CANC'
                                  AND O.SOStatus = 'CANC' ) 
                  BEGIN
                     -- UPDATE PTLTran
                     UPDATE PTL.PTLTran WITH (ROWLOCK) 
                     SET ExpectedQty = @nQTY_PD
                        ,Remarks     = 'Adjust ExpectedQty: ' + CAST ( @nExpectedQTY AS NVARCHAR(5) ) 
                     WHERE StorerKey = @cStorerKey
                     AND OrderKey    = @cOrderKey
                     AND Loc         = @cLoc
                     AND SKU         = @cSKU 
                     AND DeviceProfileLogKey = @cDPLKey
                     AND PTLKey      = @nPTLKey
                     
                     IF @@ERROR <> 0 
                     BEGIN
                        SET @nErrNo = 172402
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                        GOTO RollBackTran
                     END                        
                  END
               END
               ELSE
               BEGIN
                  SET @nErrNo = 172403
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                  GOTO RollBackTran
               END
            END
            
            -- Loop PickDetail
            /*
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE O.OrderKey = @cOrderKey
                  AND LOC = @cLOC
                  AND SKU = @cSKU
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
            OPEN @curPD
            */
            SET @cSQL = 
               ' SELECT PD.PickDetailKey ' + 
               ' FROM Orders O WITH (NOLOCK) ' + 
                  ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                  ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' + 
                  ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE PD.OrderKey = @cOrderKey ' + 
                  ' AND PD.LOC = @cLOC ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.Status < @cPickConfirmStatus ' + 
                  ' AND PD.Status <> ''4''' + 
                  ' AND PD.QTY > 0' + 
                  ' AND O.Status <> ''CANC'' ' + 
                  ' AND O.SOStatus <> ''CANC'' '

            IF CURSOR_STATUS( 'variable', '@curPD') IN (0, 1)
               DEALLOCATE @curPD

            EXEC rdt.rdt_PTLCart_Confirm_OrderLottable_Cursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'LA', 
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
                  Status = @cPickConfirmStatus, 
                  DropID = @cActToteID, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 172404
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
            END
         END
         
         -- Commit order level
         COMMIT TRAN rdt_PTLCart_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         
         FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY, @cOrderKey
      END

      -- UPDATE PTLTtran.Status = '9' for Cancel Order
      IF @cUpdatePTLTranEcom = '1'
      BEGIN
         SET @nPTLKey = 0 

         SET @curPTLCanc = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PTLTran.PTLKey, PTLTran.OrderKey
         FROM PTL.PTLTran PTLTran WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PTLTran.OrderKey
         WHERE PTLTran.DeviceProfileLogKey = @cDPLKey
            --AND LOC = @cLOC
            --AND SKU = @cSKU
            AND PTLTran.Status <> '9'
            AND O.Status = 'CANC'
            AND O.SOStatus = 'CANC' 
         OPEN @curPTLCanc
         FETCH NEXT FROM @curPTLCanc INTO @nPTLKey, @cDelOrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PTL.PTLTran WITH (ROWLOCK) 
            SET Status = '9'
              , Remarks = 'Order Cancelled'
            WHERE PTLKey = @nPTLKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 172405
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curPTLCanc INTO @nPTLKey, @cDelOrderKey
         END
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
         /*
         SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PTLKey, ExpectedQTY
            FROM PTL.PTLTran WITH (NOLOCK)
            WHERE DeviceProfileLogKey = @cDPLKey
               AND LOC = @cLOC
               AND SKU = @cSKU
               AND DevicePosition = @cPosition
               AND Status <> '9'    
         OPEN @curPTL
         */
         SET @cSQL = 
            ' SELECT PTLKey, ExpectedQTY ' + 
            ' FROM PTL.PTLTran WITH (NOLOCK) ' + 
            ' WHERE DeviceProfileLogKey = @cDPLKey ' + 
               ' AND LOC = @cLOC ' + 
               ' AND SKU = @cSKU ' + 
               ' AND DevicePosition = @cPosition ' + 
               ' AND Status <> ''9'' '

         EXEC rdt.rdt_PTLCart_Confirm_OrderLottable_Cursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'PTLTran', 
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
                  SET @nErrNo = 172406
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END
      
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
                  SET @nErrNo = 172407
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                  GOTO RollBackTran
               END
      
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
                     SET @nErrNo = 172408
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                     GOTO RollBackTran
                  END
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
         				SET @nErrNo = 172409
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
                     SET @nErrNo = 172410
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                     GOTO RollBackTran
                  END
         
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
            -- Get PickDetail tally PTLTran
            SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
            FROM Orders O WITH (NOLOCK) 
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            WHERE O.OrderKey = @cOrderKey
               AND LOC = @cLOC
               AND SKU = @cSKU
               AND PD.Status < @cPickConfirmStatus
               AND PD.Status <> '4'
               AND PD.QTY > 0
               AND O.Status <> 'CANC' 
               AND O.SOStatus <> 'CANC'

            IF @nQTY_PD <> @nExpectedQTY
            BEGIN
                -- (ChewKP01) 
               IF @cUpdatePTLTranEcom = '1' AND EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                                                         WHERE OrderKey = @cOrderKey
                                                         AND Status = 'CANC'
                                                         AND SOStatus = 'CANC' ) 
               BEGIN
                  IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                                  INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey 
                                  WHERE PD.OrderKey = @cOrderKey
                                  AND PD.SKU = @cSKU
                                  AND PD.Loc = @cLoc
                                  AND O.Status = 'CANC'
                                  AND O.SOStatus = 'CANC' ) 
                  BEGIN
                     -- UPDATE PTLTran
                     UPDATE PTL.PTLTran WITH (ROWLOCK) 
                     SET ExpectedQty = @nQTY_PD
                        ,Remarks     = 'Adjust ExpectedQty: ' + CAST ( @nExpectedQTY AS NVARCHAR(5)  ) 
                     WHERE StorerKey = @cStorerKey
                     AND OrderKey    = @cOrderKey
                     AND Loc         = @cLoc
                     AND SKU         = @cSKU 
                     AND DropID      = @cToteID 
                     AND DeviceProfileLogKey = @cDPLKey
                     --AND PTLKey      = @nPTLKey
                     
                     IF @@ERROR <> 0 
                     BEGIN
                        SET @nErrNo = 172411
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                        GOTO RollBackTran
                     END
                  END
               END
               ELSE
               BEGIN
                  SET @nErrNo = 172412
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                  GOTO RollBackTran
               END
            END
            
            -- For calculation
            SET @nQTY_Bal = @nQTY -- @nQTY_PD --@nQTY -- (ChewKP01) 
         
            -- Get PickDetail candidate
            /*
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT PickDetailKey, QTY
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE O.OrderKey = @cOrderKey
                  AND LOC = @cLOC
                  AND SKU = @cSKU
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
            OPEN @curPD
            */
            SET @cSQL = 
               ' SELECT PD.PickDetailKey, PD.QTY ' + 
               ' FROM Orders O WITH (NOLOCK) ' + 
                  ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)' + 
                  ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE O.OrderKey = @cOrderKey ' + 
                  ' AND PD.LOC = @cLOC ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.Status < @cPickConfirmStatus ' + 
                  ' AND PD.Status <> ''4'' ' + 
                  ' AND PD.QTY > 0 ' + 
                  ' AND O.Status <> ''CANC'' ' +  
                  ' AND O.SOStatus <> ''CANC'' '

            EXEC rdt.rdt_PTLCart_Confirm_OrderLottable_Cursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'LA', 
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
                     SET @nErrNo = 172413
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
                     SET @nErrNo = 172414
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
                        SET @nErrNo = 172415
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
                        SET @nErrNo = 172416
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
            				SET @nErrNo = 172417
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
                        GOTO RollBackTran
                     END
            
                     -- Get PickDetail info
                     DECLARE @cOrderLineNumber NVARCHAR( 5)
                     DECLARE @cLoadkey NVARCHAR( 10)
                     SELECT 
                        @cOrderLineNumber = OD.OrderLineNumber, 
                        @cLoadkey = OD.Loadkey
                     FROM dbo.PickDetail PD WITH (NOLOCK) 
                        INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
                     WHERE PD.PickDetailkey = @cPickDetailKey
                     
                     -- Get PickSlipNo
                     DECLARE @cPickSlipNo NVARCHAR(10)
                     SET @cPickSlipNo = ''
                     SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
                     IF @cPickSlipNo = ''
                        SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey
                     
                     -- Insert into 
                     INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                     VALUES (@cNewPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 172418
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                        GOTO RollBackTran
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
                        SET @nErrNo = 172419
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END
            
                     -- Confirm orginal PickDetail with exact QTY
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        Status = '5',
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME() 
                     WHERE PickDetailKey = @cPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 172420
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
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

         -- UPDATE PTLTtran.Status = '9' for Cancel Order
         IF @cUpdatePTLTranEcom = '1'
         BEGIN
            SET @nPTLKey = 0 

            SET @curPTLCanc = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PTLTran.PTLKey, PTLTran.OrderKey
            FROM PTL.PTLTran PTLTran WITH (NOLOCK)
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PTLTran.OrderKey
            WHERE PTLTran.DeviceProfileLogKey = @cDPLKey
               --AND LOC = @cLOC
               --AND SKU = @cSKU
               AND PTLTran.Status <> '9'
               AND O.Status = 'CANC'
               AND O.SOStatus = 'CANC' 
            OPEN @curPTLCanc
            FETCH NEXT FROM @curPTLCanc INTO @nPTLKey, @cDelOrderKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE PTL.PTLTran WITH (ROWLOCK) 
               SET Status = '9'
                 , Remarks = 'Order Cancelled'
               WHERE PTLKey = @nPTLKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 172421
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curPTLCanc INTO @nPTLKey, @cDelOrderKey
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
            SET @nErrNo = 172422
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
            GOTO RollBackTran
         END
      END
      
      -- Auto short all subsequence tote
      IF @cType = 'SHORTTOTE'
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'AutoShortRemainTote', @cStorerKey) = '1'
         BEGIN
            /*
            SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PTLKey, DevicePosition, ExpectedQTY, OrderKey
               FROM PTL.PTLTran WITH (NOLOCK)
               WHERE DeviceProfileLogKey = @cDPLKey
                  AND LOC = @cLOC
                  AND SKU = @cSKU
                  AND Status <> '9'
            OPEN @curPTL
            */
            SET @cSQL = 
               ' SELECT PTLKey, DevicePosition, ExpectedQTY, OrderKey ' + 
               ' FROM PTL.PTLTran WITH (NOLOCK) ' + 
               ' WHERE DeviceProfileLogKey = @cDPLKey ' + 
                  ' AND LOC = @cLOC ' + 
                  ' AND SKU = @cSKU ' + 
                  ' AND Status <> ''9'' '

            EXEC rdt.rdt_PTLCart_Confirm_OrderLottable_Cursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'PTLTran', 
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
                  SET @nErrNo = 172423
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END
               
               -- Update PickDetail
               IF @cUpdatePickDetail = '1'
               BEGIN
                  -- Get PickDetail tally PTLTran
                  SELECT @nQTY_PD = ISNULL( SUM( PD.QTY), 0)
                  FROM Orders O WITH (NOLOCK) 
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE O.OrderKey = @cOrderKey
                     AND LOC = @cLOC
                     AND SKU = @cSKU
                     AND PD.Status < @cPickConfirmStatus
                     AND PD.Status <> '4'
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC'
                  IF @nQTY_PD <> @nExpectedQTY
                  BEGIN
                     SET @nErrNo = 172424
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                     GOTO RollBackTran
                  END
                  
                  -- Loop PickDetail
                  /*
                  SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PickDetailKey
                     FROM Orders O WITH (NOLOCK) 
                        JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                     WHERE O.OrderKey = @cOrderKey
                        AND LOC = @cLOC
                        AND SKU = @cSKU
                        AND PD.Status < @cPickConfirmStatus
                        AND PD.Status <> '4'
                        AND PD.QTY > 0
                        AND O.Status <> 'CANC' 
                        AND O.SOStatus <> 'CANC'
                  OPEN @curPD
                  */
                  SET @cSQL = 
                     ' SELECT PickDetailKey ' + 
                     ' FROM Orders O WITH (NOLOCK) ' + 
                        ' JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) ' + 
                        ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
                     ' WHERE O.OrderKey = @cOrderKey ' + 
                        ' AND LOC = @cLOC ' + 
                        ' AND SKU = @cSKU ' + 
                        ' AND PD.Status < @cPickConfirmStatus ' + 
                        ' AND PD.Status <> ''4'' ' + 
                        ' AND PD.QTY > 0 ' + 
                        ' AND O.Status <> ''CANC'' ' + 
                        ' AND O.SOStatus <> ''CANC'' ' 

                  IF CURSOR_STATUS( 'variable', '@curPD') IN (0, 1)
                     DEALLOCATE @curPD
                        
                  EXEC rdt.rdt_PTLCart_Confirm_OrderLottable_Cursor @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSQL, 'LA', 
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
                        SET @nErrNo = 172425
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
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