SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLCart_Assign_BatchTotes                             */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 06-05-2015 1.0  Ung      SOS336312 Created                                 */
/* 28-08-2015 1.1  Ung      SOS349752 Add DefaultToteIDAsPos                  */
/* 10-06-2016 1.2  Ung      SOS370927 Change PickDetail.Notes to PickSlipNo   */
/* 08-08-2017 1.3  Ung      WMS-2305 Add PickConfirmStatus                    */
/* 14-08-2017 1.4  Ung      WMS-2671 Add MultiPickerBatch                     */
/* 04-01-2018 1.5  Ung      WMS-3012 Prompt case ID reuse                     */
/* 26-01-2018 1.6  Ung      Change to PTL.Schema                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Assign_BatchTotes] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5), 
   @cStorerKey       NVARCHAR( 15),  
   @cCartID          NVARCHAR( 10),
   @cPickZone        NVARCHAR( 10),
   @cMethod          NVARCHAR( 1),
   @cPickSeq         NVARCHAR( 1),
   @cDPLKey          NVARCHAR( 10),
   @cType            NVARCHAR( 15), --POPULATE-IN/POPULATE-OUT/CHECK
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,   
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,   
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,   
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,   
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,   
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT, 
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT, 
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT, 
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT, 
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT, 
   @nScn             INT           OUTPUT,
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @cErrMsg1    NVARCHAR(20)

   DECLARE @cBatchKey   NVARCHAR(20)
   DECLARE @cOrderKey   NVARCHAR(10)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @cToteID     NVARCHAR(20)
   DECLARE @nTotalOrder INT
   DECLARE @nTotalTote  INT
   DECLARE @nRowRef     BIGINT

   SET @nTranCount = @@TRANCOUNT
      
   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get work info
      SET @cBatchKey = ''
      SELECT TOP 1 @cBatchKey = BatchKey FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID
      SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID <> ''

		-- Prepare next screen var
		SET @cOutField01 = @cCartID
		SET @cOutField02 = @cPickZone
		SET @cOutField03 = @cBatchKey
		SET @cOutField04 = '' -- OrderKey
		SET @cOutField05 = '' -- Position
		SET @cOutField06 = '' -- ToteID
		SET @cOutField07 = CAST( @nTotalOrder AS NVARCHAR(5))
		SET @cOutField08 = CAST( @nTotalTote AS NVARCHAR(5))

      IF @cBatchKey = ''
      BEGIN
         -- Enable disable field
         SET @cFieldAttr03 = ''  -- BatchKey
         SET @cFieldAttr06 = 'O' -- ToteID

   	   EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
      END
      ELSE
      BEGIN
         SET @cFieldAttr03 = 'O' -- BatchKey
         SET @cFieldAttr06 = 'O'  -- ToteID

         IF @nTotalOrder > @nTotalTote
         BEGIN
            -- Get tote not yet assign
            SELECT TOP 1 
               @cOrderKey = OrderKey, 
               @cPosition = Position
            FROM rdt.rdtPTLCartLog WITH (NOLOCK)
            WHERE CartID = @cCartID
               AND ToteID = ''
            ORDER BY RowRef 

      		-- Prepare next screen var
      		SET @cOutField04 = @cOrderKey
      		SET @cOutField05 = @cPosition 

            -- Enable field
            IF rdt.rdtGetConfig( @nFunc, 'DefaultToteIDAsPos', @cStorerKey) = '1'
            BEGIN
               SET @cToteID = @cPosition
               SET @cOutField06 = @cToteID
            END
            ELSE
            BEGIN
               SET @cFieldAttr06 = ''   -- ToteID
            END
         END
      END
		
		-- Go to batch totes screen
		SET @nScn = 4181
   END
      
   IF @cType = 'POPULATE-OUT'
   BEGIN
      -- Enable field
      SET @cFieldAttr03 = '' -- BatchKey
      SET @cFieldAttr06 = '' -- ToteID

		-- Go to cart screen
   END

   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      DECLARE @cCheckBatchUsed NVARCHAR( 1)
      DECLARE @cMultiPickerBatch NVARCHAR( 1)
      DECLARE @cPickConfirmStatus NVARCHAR( 1)
      DECLARE @cIPAddress NVARCHAR(40)
      DECLARE @cLOC NVARCHAR(10)
      DECLARE @cSKU NVARCHAR(20)
      DECLARE @nQTY INT
      DECLARE @curPD CURSOR
      
      SET @cCheckBatchUsed = rdt.rdtGetConfig( @nFunc, 'CheckBatchUsed', @cStorerKey)
      SET @cMultiPickerBatch = rdt.RDTGetConfig( @nFunc, 'MultiPickerBatch', @cStorerKey)
      SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
      IF @cPickConfirmStatus = '0'
         SET @cPickConfirmStatus = '5'

      IF @cMultiPickerBatch = '1'
         SET @cPickZone = ''

      -- Screen mapping
      SET @cBatchKey = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cOrderKey = @cOutField04
      SET @cPosition = @cOutField05
      SET @cToteID   = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END

      -- Get storer config
      DECLARE @cDefaultToteIDAsPos NVARCHAR(1)
      SET @cDefaultToteIDAsPos = rdt.rdtGetConfig( @nFunc, 'DefaultToteIDAsPos', @cStorerKey)

      -- BatchKey field enabled
      IF @cFieldAttr03 = ''
      BEGIN
   		-- Check blank
   		IF @cBatchKey = '' 
         BEGIN
            SET @nErrNo = 54101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
            GOTO Quit
         END

         -- Check BatchKey valid
         IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND Status < @cPickConfirmStatus AND PickSlipNo = @cBatchKey)
         BEGIN
            SET @nErrNo = 54102
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad BatchKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Check BatchKey used
         IF @cCheckBatchUsed = '1'
         BEGIN
            IF EXISTS( SELECT TOP 1 1 FROM PTL.PTLTran WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SourceKey = @cBatchKey AND Status = '9')
            BEGIN
               SET @nErrNo = 54122
               SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch used
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '54122', @cErrMsg1
               SET @nErrNo = 0
            END
         END
         
         -- Check BatchKey assigned
         IF @cMultiPickerBatch <> '1'
         BEGIN
            IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND BatchKey = @cBatchKey AND AddWho <> SUSER_SNAME())
            BEGIN
               SET @nErrNo = 54103
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch Assigned
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
               SET @cOutField03 = ''
               GOTO Quit
            END
         END

         -- Assign order
         IF NOT EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID)
         BEGIN
            DECLARE @cChkFacility  NVARCHAR(5)
            DECLARE @cChkStorerKey NVARCHAR(15)
            DECLARE @cChkStatus    NVARCHAR(10)
            DECLARE @cChkSOStatus  NVARCHAR(10)
            SET @cChkFacility = ''
            SET @cChkStorerKey = ''
            SET @cChkStatus = ''
            SET @cChkSOStatus = ''
            SET @nTotalOrder = 0
            SET @nTotalTote = 0
   
            DECLARE @curBatch CURSOR
            SET @curBatch = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT DISTINCT OrderKey 
               FROM PickDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
                  AND Status <> '4'
                  AND Status < @cPickConfirmStatus
                  AND PickSlipNo = @cBatchKey
               ORDER BY OrderKey

            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN
            SAVE TRAN rdt_PTLCart_Assign_BatchTotes     

            OPEN @curBatch
            FETCH NEXT FROM @curBatch INTO @cOrderKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get order info
               SELECT 
                  @cChkFacility = Facility, 
                  @cChkStorerKey = StorerKey, 
                  @cChkStatus = Status, 
                  @cChkSOStatus = SOStatus
               FROM Orders WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
               
               -- Check order valid
               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 54104
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
                  GOTO RollBackTran
               END
         
               -- Check storer
               IF @cStorerKey <> @cChkStorerKey
               BEGIN
                  SET @nErrNo = 54105
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
                  GOTO RollBackTran
               END
         
               -- Check facility
               IF @cFacility <> @cChkFacility
               BEGIN
                  SET @nErrNo = 54106
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
                  GOTO RollBackTran
               END
                     
               -- Check order CANC
               IF @cChkStatus = 'CANC' OR @cChkSOStatus = 'CANC' 
               BEGIN
                  SET @nErrNo = 54107
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
                  GOTO RollBackTran
               END
               
               -- Check order status
               IF @cChkStatus = '0'
               BEGIN
                  SET @nErrNo = 54108
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order NotAlloc
                  GOTO RollBackTran
               END
               
               -- Check order status
               IF @cChkStatus >= '5'
               BEGIN
                  SET @nErrNo = 54109
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order picked
                  GOTO RollBackTran
               END
         
               -- Check order assigned
               IF @cPickZone = ''
                  SELECT @nErrNo = 1
                  FROM rdt.rdtPTLCartLog WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
               ELSE
                  SELECT @nErrNo = 1
                  FROM rdt.rdtPTLCartLog WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                     AND (PickZone = @cPickZone OR PickZone = '')
               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 54110
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderAssigned
                  GOTO RollBackTran
               END
         
               -- Check order have task
               SET @nErrNo = 1
               IF @cPickZone = ''
                  SELECT @nErrNo = 0
                  FROM Orders O WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  WHERE PD.OrderKey = @cOrderKey
                     AND PD.Status <> '4'
                     AND PD.Status < @cPickConfirmStatus
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC'
                     AND O.SOStatus <> 'CANC'
               ELSE 
                  SELECT @nErrNo = 0 
                  FROM Orders O WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                  WHERE PD.OrderKey = @cOrderKey
                     AND PD.Status <> '4'
                     AND PD.Status < @cPickConfirmStatus
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC'
                     AND O.SOStatus <> 'CANC'
                     AND LOC.PickZone = @cPickZone
               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 54111
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order no task
                  GOTO RollBackTran
               END
   
               -- Get position not yet assign
               SET @cPosition = ''
               SELECT TOP 1
                  @cPosition = DP.DevicePosition
               FROM dbo.DeviceProfile DP WITH (NOLOCK)
               WHERE DP.DeviceType = 'CART'
                  AND DP.DeviceID = @cCartID
                  AND NOT EXISTS( SELECT 1
                     FROM rdt.rdtPTLCartLog PCLog WITH (NOLOCK)
                     WHERE CartID = @cCartID
                        AND PCLog.Position = DP.DevicePosition)
               ORDER BY DP.DevicePosition
   
               -- Check position blank
               IF @cPosition = ''
               BEGIN
                  SET @nErrNo = 54112
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition
                  GOTO RollBackTran
               END
   
               -- Tote ID as position
               IF @cDefaultToteIDAsPos = '1'
                  SET @cToteID = @cPosition
   
               -- Save assign
               INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, BatchKey, OrderKey, StorerKey)
               VALUES (@cCartID, @cPosition, @cToteID, @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cBatchKey, @cOrderKey, @cStorerKey)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 54113
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
                  GOTO RollBackTran
               END
   
               IF @cDefaultToteIDAsPos = '1'
               BEGIN
                  -- Get position info
                  SELECT @cIPAddress = IPAddress
                  FROM DeviceProfile WITH (NOLOCK)
                  WHERE DeviceType = 'CART'
                     AND DeviceID = @cCartID
                     AND DevicePosition = @cPosition
                  
                  DECLARE @nPTLTranCreated INT
                  SET @nPTLTranCreated = 0
                  
                  -- Insert PTLTran
                  IF @cPickZone = ''
                     SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT PD.LOC, PD.SKU, SUM( PD.QTY)
                        FROM Orders O WITH (NOLOCK) 
                           JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                        WHERE O.OrderKey = @cOrderKey
                           AND PD.Status <> '4'
                           AND PD.Status < @cPickConfirmStatus
                           AND PD.QTY > 0
                           AND O.Status <> 'CANC' 
                           AND O.SOStatus <> 'CANC'
                        GROUP BY PD.LOC, PD.SKU
                  ELSE
                     SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT LOC.LOC, PD.SKU, SUM( PD.QTY)
                        FROM Orders O WITH (NOLOCK) 
                           JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                           JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                        WHERE O.OrderKey = @cOrderKey
                           AND PD.Status <> '4'
                           AND PD.Status < @cPickConfirmStatus
                           AND PD.QTY > 0
                           AND O.Status <> 'CANC' 
                           AND O.SOStatus <> 'CANC'
                           AND LOC.PickZone = @cPickZone
                        GROUP BY LOC.LOC, PD.SKU
                  
                  OPEN @curPD
                  FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     INSERT INTO PTL.PTLTran (
                        IPAddress, DeviceID, DevicePosition, Status, PTLType, 
                        DeviceProfileLogKey, DropID, OrderKey, Storerkey, SKU, LOC, ExpectedQTY, QTY, SourceKey)
                     VALUES (
                        @cIPAddress, @cCartID, @cPosition, '0', 'CART',
                        @cDPLKey, '', @cOrderKey, @cStorerKey, @cSKU, @cLOC, @nQTY, 0, @cBatchKey)
               
                     IF @@ERROR <> ''
                     BEGIN
                        SET @nErrNo = 54114
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
                        GOTO RollBackTran
                     END
                     
                     SET @nPTLTranCreated = 1
                     FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
                  END

                  -- Get PackTask 
                  SET @nRowRef = 0
                  SELECT @nRowRef = RowRef
                  FROM PackTask WITH (NOLOCK) 
                  WHERE TaskBatchNo = @cBatchKey 
                     AND OrderKey = @cOrderKey 
                     AND DevicePosition = ''
                  
                  -- Update PackTask 
                  IF @nRowRef > 0
                  BEGIN
                     UPDATE PackTask SET
                        DevicePosition = @cPosition, 
                        EditDate = GETDATE(), 
                        EditWho = SUSER_SNAME()
                     WHERE RowRef = @nRowRef
                     IF @@ERROR <> ''
                     BEGIN
                        SET @nErrNo = 54120
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --UPD PTask Fail
                        GOTO RollBackTran
                     END
                  END
                  
                  IF @nPTLTranCreated = 1
                     SET @nTotalTote = @nTotalTote + 1
               END
   
               SET @nTotalOrder = @nTotalOrder + 1
                  
               FETCH NEXT FROM @curBatch INTO @cOrderKey
            END
   
            COMMIT TRAN rdt_PTLCart_Assign_BatchTotes
         END

         -- Clear earlier assigned 
         IF @nErrNo <> 0 AND @nTotalOrder > 0
         BEGIN
            DELETE rdt.rdtPTLCartLog WHERE CartID = @cCartID AND BatchKey = @cBatchKey AND AddWho = SUSER_SNAME()
            GOTO Quit
         END
         
         -- Check empty batch
         IF @nTotalOrder = 0
         BEGIN
            SET @nErrNo = 54115
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch No Task!
            GOTO Quit
         END

         -- Get tote not yet assign
         SET @cOrderKey = ''
         SET @cPosition = ''
         SELECT TOP 1 
            @cOrderKey = OrderKey, 
            @cPosition = Position, 
            @cToteID = CASE WHEN @cDefaultToteIDAsPos = '1' THEN Position ELSE '' END
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE CartID = @cCartID
            AND ToteID = ''
         ORDER BY RowRef 
         
         -- Prepare current screen var
         SET @cOutField03 = @cBatchKey
         SET @cOutField04 = @cOrderKey
         SET @cOutField05 = @cPosition
         SET @cOutField06 = '' -- ToteID
         SET @cOutField07 = CAST( @nTotalOrder AS NVARCHAR(5))
         SET @cOutField08 = CAST( @nTotalTote AS NVARCHAR(5))

         -- Enable / Disable field
         SET @cFieldAttr03 = 'O' -- BatchKey
         SET @cFieldAttr06 = CASE WHEN @cDefaultToteIDAsPos = '1' THEN 'O' ELSE '' END -- ToteID
         
         -- Remain in current screen
         SET @nErrNo = -1
         GOTO Quit
      END

      -- ToteID field enabled
      IF @cFieldAttr06 = ''
      BEGIN
         -- Check blank tote
         IF @cToteID = ''
         BEGIN
            SET @nErrNo = 54116
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- ToteID
            SET @cOutField06 = ''
            GOTO Quit
         END
   
         -- Check tote assigned
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLCartLog WITH (NOLOCK)
            WHERE CartID = @cCartID
               AND ToteID = @cToteID)
         BEGIN
            SET @nErrNo = 54117
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- ToteID
            SET @cOutField06 = ''
            GOTO Quit
         END
         SET @cOutField06 = @cToteID
      
         -- Get position info
         SELECT @cIPAddress = IPAddress
         FROM DeviceProfile WITH (NOLOCK)
         WHERE DeviceType = 'CART'
            AND DeviceID = @cCartID
            AND DevicePosition = @cPosition
   
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN rdt_PTLCart_Assign_BatchTotes
         
         -- Save assign
         UPDATE rdt.rdtPTLCartLog SET
            ToteID = @cToteID
         WHERE CartID = @cCartID
            AND OrderKey = @cOrderKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 54118
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
            GOTO RollBackTran
         END
   
         -- Insert PTLTran
         IF @cPickZone = ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.LOC, PD.SKU, SUM( PD.QTY)
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE O.OrderKey = @cOrderKey
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
               GROUP BY PD.LOC, PD.SKU
         ELSE
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LOC.LOC, PD.SKU, SUM( PD.QTY)
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE O.OrderKey = @cOrderKey
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC' 
                  AND O.SOStatus <> 'CANC'
                  AND LOC.PickZone = @cPickZone
               GROUP BY LOC.LOC, PD.SKU
         
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            INSERT INTO PTL.PTLTran (
               IPAddress, DeviceID, DevicePosition, Status, PTLType, 
               DeviceProfileLogKey, DropID, OrderKey, Storerkey, SKU, LOC, ExpectedQTY, QTY, SourceKey)
            VALUES (
               @cIPAddress, @cCartID, @cPosition, '0', 'CART',
               @cDPLKey, '', @cOrderKey, @cStorerKey, @cSKU, @cLOC, @nQTY, 0, @cBatchKey)
      
            IF @@ERROR <> ''
            BEGIN
               SET @nErrNo = 54119
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
         END

         -- Get PackTask 
         SET @nRowRef = 0
         SELECT @nRowRef = RowRef
         FROM PackTask WITH (NOLOCK) 
         WHERE TaskBatchNo = @cBatchKey 
            AND OrderKey = @cOrderKey 
            AND DevicePosition = ''
         
         -- Update PackTask 
         IF @nRowRef > 0
         BEGIN
            UPDATE PackTask SET
               DevicePosition = @cPosition, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE RowRef = @nRowRef
            IF @@ERROR <> ''
            BEGIN
               SET @nErrNo = 54121
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --UPD PTask Fail
               GOTO RollBackTran
            END
         END
   
         COMMIT TRAN rdt_PTLCart_Assign_BatchTotes
      END

      -- Get Total
      SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID <> ''

      -- Check finish assign
      IF @nTotalOrder > 0 AND @nTotalOrder = @nTotalTote
      BEGIN
         -- Enable field
         SET @cFieldAttr03 = '' -- BatchKey
         SET @cFieldAttr06 = '' -- ToteID
         
         GOTO Quit
      END

      -- Get tote not yet assign
      SELECT TOP 1 
         @cOrderKey = OrderKey, 
         @cPosition = Position
      FROM rdt.rdtPTLCartLog WITH (NOLOCK)
      WHERE CartID = @cCartID
         AND ToteID = ''
      ORDER BY RowRef 

      -- Prepare current screen var
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cPosition
      SET @cOutField06 = '' -- ToteID
      SET @cOutField07 = CAST( @nTotalOrder AS NVARCHAR(5))
      SET @cOutField08 = CAST( @nTotalTote AS NVARCHAR(5))
      
      -- Stay in current page
      SET @nErrNo = -1 
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Assign_BatchTotes

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO