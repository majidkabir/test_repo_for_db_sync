SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLCart_Confirm_Order                           */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Close working batch                                         */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 25-05-2015 1.0  Ung         SOS336312 Created                        */
/* 27-07-2017 1.1  ChewKP      WMS-2536 - Cater Ecom Picking.           */
/*                             Add PickDetailStatus (ChewKP01)          */
/* 14-08-2018 1.2  James       WMS5770-Add eventlog (james01)           */
/* 05-09-2018 1.3  Ung         WMS-6239 Add ShortPickUpdateOrderStatus  */
/* 17-12-2018 1.4  ChewKP      WMS-7091 Add EventLog (ChewKP02)         */
/* 24-09-2018 1.5  James       WMS7751-Remove OD.loadkey (james02)      */
/* 2020-07-27 1.6  Chermaine   WMS-14428 Add ExtUpdSP to move cancel    */
/*                             orderto statging loc (cc01)              */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Confirm_Order] (
    @nMobile    INT
   ,@nFunc      INT
   ,@cLangCode  NVARCHAR( 3)
   ,@nStep      INT
   ,@nInputKey  INT
   ,@cFacility  NVARCHAR(5)
   ,@cStorerKey NVARCHAR( 15)
   ,@cType      NVARCHAR( 10) -- LOC = confirm LOC, CLOSETOTE/SHORTTOTE = confirm tote
   ,@cDPLKey    NVARCHAR( 10)
   ,@cCartID    NVARCHAR( 10) 
   ,@cToteID    NVARCHAR( 20) -- Required for confirm tote
   ,@cLOC       NVARCHAR( 10)
   ,@cSKU       NVARCHAR( 20)
   ,@nQTY       INT
   ,@cNewToteID NVARCHAR( 20) -- For close tote with balance
   ,@nErrNo     INT           OUTPUT
   ,@cErrMsg    NVARCHAR(250) OUTPUT
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
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
                           
   DECLARE @cActToteID     NVARCHAR( 20)
   DECLARE @cPosition      NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
          ,@cDelOrderKey   NVARCHAR( 10) 
          ,@cPickConfirmStatus NVARCHAR(1)
          ,@cUserName      NVARCHAR( 18)

   DECLARE @cUpdatePTLTranEcom  NVARCHAR(1)
   DECLARE @cUpdatePickDetail NVARCHAR(1)
   DECLARE @cShortPickUpdateOrderStatus NVARCHAR(1)    
   DECLARE @cMoveAdjExpQty NVARCHAR=(1)      --(cc01)

   DECLARE @curPTL CURSOR
   DECLARE @curPD  CURSOR
   DECLARE @curPTLCanc  CURSOR

   DECLARE @tOrders TABLE
   (
      OrderKey NVARCHAR( 10) NOT NULL, 
      PRIMARY KEY CLUSTERED (OrderKey)
   )

   -- Get storer config
   SET @cUpdatePickDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)

   -- (ChewKP01) 
   SET @cUpdatePTLTranEcom = rdt.rdtGetConfig( @nFunc, 'UpdatePTLTranEcom', @cStorerKey)

   SET @cShortPickUpdateOrderStatus = rdt.RDTGetConfig( @nFunc, 'ShortPickUpdateOrderStatus', @cStorerKey)

   SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus <> '3'     -- 3=Pick in progress
      SET @cPickConfirmStatus = '5'  -- 5=Pick confirm
      
   SET @cMoveAdjExpQty = rdt.rdtGetConfig( @nFunc, 'MoveAdjExpQty', @cStorerKey)  --(cc01)
   
   SET @nQTY_Bal = @nQTY

   SELECT @cUserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   /***********************************************************************************************

                                                CONFIRM LOC 

   ***********************************************************************************************/
   

   IF @cType = 'LOC' 
   BEGIN
      -- Confirm entire LOC
      SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PTLKey, DevicePosition, ExpectedQTY, OrderKey
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceProfileLogKey = @cDPLKey
            AND LOC = @cLOC
            AND SKU = @cSKU
            AND Status <> '9'
      OPEN @curPTL
      FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY, @cOrderKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get tote
         SELECT @cActToteID = ToteID FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND Position = @cPosition
         
         -- Transaction at order level
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_PTLCart_Confirm_Order -- For rollback or commit only our own transaction
         
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
            SET @nErrNo = 54601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO RollBackTran
         END
         ELSE
         BEGIN
           -- Event log
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '3', -- Picking
               @cUserID       = @cUserName,
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
               --AND PD.Status < '4'
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
                           SET @nErrNo = 54622
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                           GOTO RollBackTran
                        END
                        
                        IF @cMoveAdjExpQty = '1'   --(cc01)
                        BEGIN
                        	IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE listName ='WSMove2Loc' AND code =@cFacility AND  ISNULL(Long,'') <> '')
                        	BEGIN
                        		DECLARE @cToLOC NVARCHAR(20)
                        		SELECT @cToLOC = Long FROM CODELKUP WITH (NOLOCK) WHERE listName ='WSMove2Loc' AND code =@cFacility AND  ISNULL(Long,'') <> ''
                        		
                        		EXECUTE rdt.rdt_Move  
                                 @nMobile      = @nMobile,  
                                 @cLangCode    = @cLangCode,  
                                 @nErrNo       = @nErrNo  OUTPUT,  
                                 @cErrMsg      = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max  
                                 @cSourceType  = 'rdt_PTLCart_Confirm_Order',  
                                 @cStorerKey   = @cStorerKey,  
                                 @cFacility    = @cFacility,  
                                 @cFromLOC     = @cLoc,  
                                 @cToLOC       = @cToLOC,  
                                 @cFromID      = NULL,     -- NULL means not filter by ID. Blank is a valid ID  
                                 @cToID        = NULL,       -- NULL means not changing ID. Blank consider a valid ID  
                                 @cSKU         = @cSKU,  
                                 @nQTY         = @nExpectedQTY,  
                                 @nFunc     = @nFunc       
         
                              IF @nErrNo <> 0
                              BEGIN
                                 SET @nErrNo = @nErrNo
                                 SET @cErrMsg = @cErrMsg
                                 GOTO RollBackTran
                              END 
                           END
                        END
                     END
                                             
               END
               ELSE
               BEGIN
                  SET @nErrNo = 54602
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                  GOTO RollBackTran
               END
            END
            
            -- Loop PickDetail
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE O.OrderKey = @cOrderKey
                  AND LOC = @cLOC
                  AND SKU = @cSKU
                  --AND PD.Status < '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
            OPEN @curPD
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
                  SET @nErrNo = 54603
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
            END
         END
         
         
         -- EventLog - (ChewKP02) 
         EXEC RDT.rdt_STD_EventLog
           @cActionType = '3', 
           @cUserID     = '',
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerkey,
           @cLocation   = @cLOC,
           @cSKU        = @cSKU,
           @cDeviceID   = @cCartID,
           @cDevicePosition = @cPosition,
           @cDropID     = @cActToteID,
           @nQty        = @nExpectedQTY,
           @cOrderKey   = @cOrderKey, 
           @nStep       = @nStep
           
           
         -- Commit order level
         COMMIT TRAN rdt_PTLCart_Confirm_Order
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
                  SET @nErrNo = 54624
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
      SAVE TRAN rdt_PTLCart_Confirm_Order -- For rollback or commit only our own transaction
      
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
         SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PTLKey, ExpectedQTY
            FROM PTL.PTLTran WITH (NOLOCK)
            WHERE DeviceProfileLogKey = @cDPLKey
               AND LOC = @cLOC
               AND SKU = @cSKU
               AND DevicePosition = @cPosition
               AND Status <> '9'    
         OPEN @curPTL
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
                  SET @nErrNo = 54604
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END
               ELSE
               BEGIN
                  -- Event log
                  EXEC RDT.rdt_STD_EventLog
                     @cActionType   = '3', -- Picking
                     @cUserID       = @cUserName,
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
                  SET @nErrNo = 54605
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                  GOTO RollBackTran
               END
               ELSE
               BEGIN
                  -- Event log
                  EXEC RDT.rdt_STD_EventLog
                     @cActionType   = '3', -- Picking
                     @cUserID       = @cUserName,
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
                     SET @nErrNo = 54606
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                     GOTO RollBackTran
                  END
                  ELSE
                  BEGIN
                     -- Event log
                     EXEC RDT.rdt_STD_EventLog
                        @cActionType   = '3', -- Picking
                        @cUserID       = @cUserName,
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
               END
               ELSE
               BEGIN -- Have balance, need to split
                  -- Create new a PTLTran to hold the balance
                  INSERT INTO PTL.PTLTran (
                     ExpectedQty, QTY, TrafficCop, 
                     IPAddress, DeviceID, DevicePosition, Status, PTLType, DropID, OrderKey, Storerkey, SKU, LOC, LOT, Remarks, 
                     DeviceProfileLogKey, ArchiveCop, SourceKey, ConsigneeKey, CaseID, LightUp, LightMode, LightSequence, UOM, RefPTLKey)
                  SELECT 
                     @nQTY_PTL - @nQTY_Bal, @nQTY_PTL - @nQTY_Bal, NULL, 
                     IPAddress, DeviceID, DevicePosition, Status, PTLType, '', OrderKey, Storerkey, SKU, LOC, LOT, Remarks, 
                     DeviceProfileLogKey, ArchiveCop, SourceKey, ConsigneeKey, CaseID, LightUp, LightMode, LightSequence, UOM, RefPTLKey
                  FROM PTL.PTLTran WITH (NOLOCK) 
         			WHERE PTLKey = @nPTLKey			            
                  IF @@ERROR <> 0
                  BEGIN
         				SET @nErrNo = 54607
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
                     SET @nErrNo = 54608
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTL Fail
                     GOTO RollBackTran
                  END
                  ELSE
                  BEGIN
                     -- Event log
                     EXEC RDT.rdt_STD_EventLog
                        @cActionType   = '3', -- Picking
                        @cUserID       = @cUserName,
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

                  SET @nQTY_Bal = 0 -- Reduce balance
               END
            END
            
            -- EventLog - (ChewKP02) 
            EXEC RDT.rdt_STD_EventLog
              @cActionType = '3', 
              @cUserID     = '',
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerkey,
              @cLocation   = @cLOC,
              @cSKU        = @cSKU,
              @cDeviceID   = @cCartID,
              @cDevicePosition = @cPosition,
              @cDropID     = @cToteID,
              @nQty        = @nQTY_PTL,
              @cOrderKey   = @cOrderKey, 
              @nStep       = @nStep
              
            
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
               --AND PD.Status < '4'
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
                           SET @nErrNo = 54623
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                           GOTO RollBackTran
                        END
                        
                     END
                                           
               END
               ELSE
               BEGIN
                  SET @nErrNo = 54609
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                  GOTO RollBackTran
               END
            END
            
            -- For calculation
            SET @nQTY_Bal = @nQTY -- @nQTY_PD --@nQTY -- (ChewKP01) 
         
            -- Get PickDetail candidate
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT PickDetailKey, QTY
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE O.OrderKey = @cOrderKey
                  AND LOC = @cLOC
                  AND SKU = @cSKU
                  --AND PD.Status < '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
            OPEN @curPD
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
                     SET @nErrNo = 54610
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
                     SET @nErrNo = 54611
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
                        SET @nErrNo = 54612
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     
                     IF @cShortPickUpdateOrderStatus = '1'
                        IF NOT EXISTS( SELECT 1 FROM @tOrders WHERE OrderKey = @cOrderKey)
                           INSERT INTO @tOrders (OrderKey) VALUES (@cOrderKey)                                       
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
                        SET @nErrNo = 54613
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
            				SET @nErrNo = 54614
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
                        GOTO RollBackTran
                     END
            
                     -- Get PickDetail info
                     DECLARE @cOrderLineNumber NVARCHAR( 5)
                     DECLARE @cLoadkey NVARCHAR( 10)

                     SELECT 
                        @cOrderLineNumber = OD.OrderLineNumber, 
                        @cLoadkey = O.Loadkey
                     FROM dbo.PickDetail PD WITH (NOLOCK) 
                        INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
                        INNER JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
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
                        SET @nErrNo = 54615
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
                        SET @nErrNo = 54616
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
                        SET @nErrNo = 54617
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
                           SET @nErrNo = 54629
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                           GOTO RollBackTran
                        END

                        IF @cShortPickUpdateOrderStatus = '1'
                           IF NOT EXISTS( SELECT 1 FROM @tOrders WHERE OrderKey = @cOrderKey)
                              INSERT INTO @tOrders (OrderKey) VALUES (@cOrderKey)                  
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
                     SET @nErrNo = 54624
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
            SET @nErrNo = 54618
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
            GOTO RollBackTran
         END
      END
      
      -- Auto short all subsequence tote
      IF @cType = 'SHORTTOTE'
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'AutoShortRemainTote', @cStorerKey) = '1'
         BEGIN
            SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PTLKey, DevicePosition, ExpectedQTY, OrderKey
               FROM PTL.PtlTran WITH (NOLOCK)
               WHERE DeviceProfileLogKey = @cDPLKey
                  AND LOC = @cLOC
                  AND SKU = @cSKU
                  AND Status <> '9'
      
            OPEN @curPTL
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
                  SET @nErrNo = 54619
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
                  GOTO RollBackTran
               END
               ELSE
               BEGIN
                  -- Event log
                  EXEC RDT.rdt_STD_EventLog
                     @cActionType   = '3', -- Picking
                     @cUserID       = @cUserName,
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
                     --AND PD.Status < '4'
                     AND PD.Status < @cPickConfirmStatus
                     AND PD.Status <> '4'
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC'
                  IF @nQTY_PD <> @nExpectedQTY
                  BEGIN
                     SET @nErrNo = 54620
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
                     GOTO RollBackTran
                  END
                  
                  -- Loop PickDetail
                  SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PickDetailKey
                     FROM Orders O WITH (NOLOCK) 
                        JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                     WHERE O.OrderKey = @cOrderKey
                        AND LOC = @cLOC
                        AND SKU = @cSKU
                        --AND PD.Status < '4'
                        AND PD.Status < @cPickConfirmStatus
                        AND PD.Status <> '4'
                        AND PD.QTY > 0
                        AND O.Status <> 'CANC' 
                        AND O.SOStatus <> 'CANC'
                  OPEN @curPD
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
                        SET @nErrNo = 54621
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
                  END

                  IF @cShortPickUpdateOrderStatus = '1'
                     IF NOT EXISTS( SELECT 1 FROM @tOrders WHERE OrderKey = @cOrderKey)
                        INSERT INTO @tOrders (OrderKey) VALUES (@cOrderKey)  
               END
               
               FETCH NEXT FROM @curPTL INTO @nPTLKey, @cPosition, @nExpectedQTY, @cOrderKey
            END
         END
      END

      COMMIT TRAN rdt_PTLCart_Confirm_Order
   END
   
   -- Short pick, change order status = 3
   IF @cShortPickUpdateOrderStatus = '1'
   BEGIN
      -- Short pick orders found
      IF EXISTS( SELECT TOP 1 1 FROM @tOrders)
      BEGIN
         DECLARE @cStatus NVARCHAR( 10)
         DECLARE @cSOStatus NVARCHAR( 10)
         DECLARE @cECOM_SINGLE_Flag NVARCHAR( 1)
         DECLARE @curOrder CURSOR
         
         SET @curOrder = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT OrderKey FROM @tOrders
         OPEN @curOrder
         FETCH NEXT FROM @curOrder INTO @cOrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Get Order info
            SELECT 
               @cStatus = Status, 
               @cECOM_SINGLE_Flag = ECOM_SINGLE_Flag
            FROM Orders WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey 
            
            IF @cStatus <> '3'
            BEGIN
               /*
               -- Get SOStatus
               SET @cSOStatus = ''
               SELECT @cSOStatus = LEFT( Code, 10)
               FROM CodeLKUP WITH (NOLOCK) 
               WHERE ListName = 'SOSTSBLOCK' 
                  AND StorerKey = @cStorerKey
                  AND UDF04 = @cECOM_SINGLE_Flag
               
               -- Check SOStatus valid
               IF @cSOStatus = ''
               BEGIN
                  SET @nErrNo = 54627
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SOStatus blank
                  GOTO RollBackTran
               END
               */
               
               UPDATE Orders SET
                  Status = '3', 
                  -- SOStatus = @cSOStatus, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME()
               WHERE OrderKey = @cOrderKey
               SET @nErrNo = @@ERROR 
               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 54628
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Order Fail
                  GOTO RollbackTran
               END
            
               FETCH NEXT FROM @curOrder INTO @cOrderKey
            END
            
            FETCH NEXT FROM @curOrder INTO @cOrderKey
         END
      END
   END
      
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Confirm_Order -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO